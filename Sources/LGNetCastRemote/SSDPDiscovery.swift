import Foundation
import Darwin

// MARK: - SSDPCandidate

struct SSDPCandidate: Sendable {
    let ip:       String
    let location: String   // UPnP device description URL (LOCATION header)
    let server:   String   // SERVER header (used for LG identification)

    /// LG 기기 서명 — 실측: "... LGE_DLNA_SDK/1.5.0"
    var isLGE: Bool { server.uppercased().contains("LGE") }
}

// MARK: - SSDPDiscovery actor

actor SSDPDiscovery {

    static let multicastAddr = "239.255.255.250"
    static let ssdpPort: UInt16 = 1900
    static let timeout: TimeInterval = 2.5
    static let receivePollTimeoutUsec: Int = 300_000
    static let tvPort: Int32 = 8080
    static let portScanConcurrency = 50

    // upnp:rootdevice 가 응답이 적어 빠르다. 허탕이면 ssdp:all 로 넓게 훑는다.
    // B-SEARCH(255.255.255.255:1990) 와 udap:rootservice 는 42LW5700 이 응답하지 않아 뺐다.
    static let ssdpTargets = [
        "upnp:rootdevice",
        "ssdp:all",
    ]

    // MARK: - Public API

    /// SSDP 후보를 LGE 서명이 있는 것부터 돌려준다.
    func discover(includePortScan: Bool = true) async -> [SSDPCandidate] {
        var found: [String: SSDPCandidate] = [:]

        for st in Self.ssdpTargets {
            for c in mSearch(target: st) { mergeCandidate(c, into: &found) }
            if !found.isEmpty { break }
        }

        if includePortScan {
            for c in await portScan() { found[c.ip] = found[c.ip] ?? c }
        }

        return found.values.sorted {
            if $0.isLGE != $1.isLGE { return $0.isLGE }
            return $0.ip.localizedStandardCompare($1.ip) == .orderedAscending
        }
    }

    func portScanOnly(
        onProgress: (@Sendable (Int, Int, String, Bool) -> Void)? = nil
    ) async -> [SSDPCandidate] {
        await portScan(onProgress: onProgress)
    }

    // MARK: - SSDP M-SEARCH (UDP multicast 239.255.255.250:1900)

    /// 응답은 우리 임시 포트로 유니캐스트로 돌아오므로 멀티캐스트 그룹 가입은 필요 없다.
    private func mSearch(target st: String) -> [SSDPCandidate] {
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return [] }
        defer { close(sock) }

        var tv = timeval(tv_sec: 0, tv_usec: Int32(Self.receivePollTimeoutUsec))
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var ttl: Int32 = 2
        setsockopt(sock, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, socklen_t(MemoryLayout<Int32>.size))

        var dest = sockaddr_in()
        dest.sin_family = sa_family_t(AF_INET)
        dest.sin_port = in_port_t(Self.ssdpPort).bigEndian
        dest.sin_addr.s_addr = inet_addr(Self.multicastAddr)
        dest.sin_zero = (0,0,0,0,0,0,0,0)

        let msg = "M-SEARCH * HTTP/1.1\r\nHOST: \(Self.multicastAddr):\(Self.ssdpPort)\r\n" +
                  "MAN: \"ssdp:discover\"\r\nMX: 2\r\nST: \(st)\r\nUSER-AGENT: UDAP/2.0\r\n\r\n"
        sendUDP(sock: sock, message: msg, dest: &dest)

        return collectResponses(sock: sock, timeout: Self.timeout)
    }
}
