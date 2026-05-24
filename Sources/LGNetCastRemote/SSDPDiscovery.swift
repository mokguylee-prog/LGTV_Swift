import Foundation
import Darwin

// MARK: - SSDPCandidate

struct SSDPCandidate: Sendable {
    let ip:       String
    let location: String   // UPnP device description URL (LOCATION header)
    let server:   String   // SERVER header (used for LG identification)
}

// MARK: - SSDPDiscovery actor

actor SSDPDiscovery {

    static let multicastAddr = "239.255.255.250"
    static let ssdpPort: UInt16 = 1900
    static let bcastPort: UInt16 = 1990
    static let timeout: TimeInterval = 2.0
    static let receivePollTimeoutUsec: Int = 200_000
    static let tvPort: Int32 = 8080
    static let portScanConcurrency = 50

    static let ssdpTargets = [
        "urn:schemas-upnp-org:device:MediaRenderer:1",
        "upnp:rootdevice",
        "ssdp:all",
        "udap:rootservice",
    ]

    // MARK: - Public API

    func discover(includePortScan: Bool = true) async -> [SSDPCandidate] {
        var found: [String: SSDPCandidate] = [:]

        for c in await mSearch() { mergeCandidate(c, into: &found) }
        for c in await bSearch() { mergeCandidate(c, into: &found) }

        if includePortScan {
            for c in await portScan() { found[c.ip] = found[c.ip] ?? c }
        }

        return found.values.sorted {
            $0.ip.localizedStandardCompare($1.ip) == .orderedAscending
        }
    }

    func portScanOnly(
        onProgress: (@Sendable (Int, Int, String, Bool) -> Void)? = nil
    ) async -> [SSDPCandidate] {
        await portScan(onProgress: onProgress)
    }

    // MARK: - SSDP M-SEARCH (UDP multicast 239.255.255.250:1900)

    private func mSearch() async -> [SSDPCandidate] {
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return [] }
        defer { close(sock) }

        var reuse: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(sock, SOL_SOCKET, SO_REUSEPORT, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var tv = timeval(tv_sec: 0, tv_usec: Int32(Self.receivePollTimeoutUsec))
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var ttl: Int32 = 2
        setsockopt(sock, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, socklen_t(MemoryLayout<Int32>.size))

        var local = sockaddr_in()
        local.sin_family = sa_family_t(AF_INET); local.sin_port = 0
        local.sin_addr.s_addr = INADDR_ANY; local.sin_zero = (0,0,0,0,0,0,0,0)
        withUnsafePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                _ = bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        var membership = ip_mreq()
        membership.imr_multiaddr.s_addr = inet_addr(Self.multicastAddr)
        membership.imr_interface.s_addr = INADDR_ANY
        setsockopt(sock, IPPROTO_IP, IP_ADD_MEMBERSHIP,
                   &membership, socklen_t(MemoryLayout<ip_mreq>.size))

        var dest = sockaddr_in()
        dest.sin_family = sa_family_t(AF_INET)
        dest.sin_port = in_port_t(Self.ssdpPort).bigEndian
        dest.sin_addr.s_addr = inet_addr(Self.multicastAddr)
        dest.sin_zero = (0,0,0,0,0,0,0,0)

        for st in Self.ssdpTargets {
            let msg = "M-SEARCH * HTTP/1.1\r\nHOST: \(Self.multicastAddr):\(Self.ssdpPort)\r\n" +
                      "MAN: \"ssdp:discover\"\r\nMX: 3\r\nST: \(st)\r\nUSER-AGENT: UDAP/2.0\r\n\r\n"
            sendUDP(sock: sock, message: msg, dest: &dest)
        }

        return collectResponses(sock: sock, timeout: Self.timeout)
    }

    // MARK: - B-SEARCH (UDP broadcast 255.255.255.255:1990)

    private func bSearch() async -> [SSDPCandidate] {
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return [] }
        defer { close(sock) }

        var reuse: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(sock, SOL_SOCKET, SO_REUSEPORT, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var broadcast: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_BROADCAST,
                   &broadcast, socklen_t(MemoryLayout<Int32>.size))

        var tv = timeval(tv_sec: 0, tv_usec: Int32(Self.receivePollTimeoutUsec))
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var local = sockaddr_in()
        local.sin_family = sa_family_t(AF_INET); local.sin_port = 0
        local.sin_addr.s_addr = INADDR_ANY; local.sin_zero = (0,0,0,0,0,0,0,0)
        withUnsafePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                _ = bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        var dest = sockaddr_in()
        dest.sin_family = sa_family_t(AF_INET)
        dest.sin_port = in_port_t(Self.bcastPort).bigEndian
        dest.sin_addr.s_addr = INADDR_BROADCAST; dest.sin_zero = (0,0,0,0,0,0,0,0)

        for st in Self.ssdpTargets {
            let msg = "B-SEARCH * HTTP/1.1\r\nHOST: 255.255.255.255:\(Self.bcastPort)\r\n" +
                      "MAN: \"ssdp:discover\"\r\nMX: 3\r\nST: \(st)\r\nUSER-AGENT: UDAP/2.0\r\n\r\n"
            sendUDP(sock: sock, message: msg, dest: &dest)
        }

        return collectResponses(sock: sock, timeout: Self.timeout)
    }
}
