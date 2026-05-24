import Foundation
import Darwin

/// SSDP 응답에서 파싱한 후보 기기 정보
struct SSDPCandidate: Sendable {
    let ip: String
    let location: String   // UPnP 기기 설명 XML URL (LOCATION 헤더)
    let server: String     // SERVER 헤더 (LG 식별에 사용)
}

/// Discovers LG NetCast TVs via SSDP multicast, UDP broadcast, and TCP port scan.
actor SSDPDiscovery {

    private static let multicastAddr = "239.255.255.250"
    private static let ssdpPort: UInt16 = 1900
    private static let bcastPort: UInt16 = 1990
    private static let timeout: TimeInterval = 2.0
    private static let receivePollTimeoutUsec: Int = 200_000
    private static let tvPort: Int32 = 8080
    private static let portScanConcurrency = 50

    private static let ssdpTargets = [
        "urn:schemas-upnp-org:device:MediaRenderer:1",
        "upnp:rootdevice",
        "ssdp:all",
        "udap:rootservice",
    ]

    // MARK: - Public

    func discover(includePortScan: Bool = true) async -> [SSDPCandidate] {
        var found: [String: SSDPCandidate] = [:]

        for c in await mSearch() {
            mergeCandidate(c, into: &found)
        }

        for c in await bSearch() {
            mergeCandidate(c, into: &found)
        }

        if includePortScan {
            for c in await portScan() {
                found[c.ip] = found[c.ip] ?? c
            }
        }

        return found.values.sorted { $0.ip.localizedStandardCompare($1.ip) == .orderedAscending }
    }

    func portScanOnly(onProgress: (@Sendable (Int, Int, String, Bool) -> Void)? = nil) async -> [SSDPCandidate] {
        await portScan(onProgress: onProgress)
    }

    // MARK: - SSDP M-SEARCH (UDP multicast 239.255.255.250:1900)

    private func mSearch() async -> [SSDPCandidate] {
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return [] }
        defer { close(sock) }

        var reuse: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
#if os(macOS)
        setsockopt(sock, SOL_SOCKET, SO_REUSEPORT, &reuse, socklen_t(MemoryLayout<Int32>.size))
#endif

        var tv = timeval(tv_sec: 0, tv_usec: Int32(Self.receivePollTimeoutUsec))
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var ttl: Int32 = 2
        setsockopt(sock, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, socklen_t(MemoryLayout<Int32>.size))

        var local = sockaddr_in()
        local.sin_family = sa_family_t(AF_INET)
        local.sin_port = 0
        local.sin_addr.s_addr = INADDR_ANY
        local.sin_zero = (0,0,0,0,0,0,0,0)
        withUnsafePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                _ = bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        var membership = ip_mreq()
        membership.imr_multiaddr.s_addr = inet_addr(Self.multicastAddr)
        membership.imr_interface.s_addr = INADDR_ANY
        setsockopt(sock, IPPROTO_IP, IP_ADD_MEMBERSHIP, &membership, socklen_t(MemoryLayout<ip_mreq>.size))

        var dest = sockaddr_in()
        dest.sin_family = sa_family_t(AF_INET)
        dest.sin_port = in_port_t(Self.ssdpPort).bigEndian
        dest.sin_addr.s_addr = inet_addr(Self.multicastAddr)
        dest.sin_zero = (0,0,0,0,0,0,0,0)

        for st in Self.ssdpTargets {
            let msg = "M-SEARCH * HTTP/1.1\r\nHOST: \(Self.multicastAddr):\(Self.ssdpPort)\r\nMAN: \"ssdp:discover\"\r\nMX: 3\r\nST: \(st)\r\nUSER-AGENT: UDAP/2.0\r\n\r\n"
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
#if os(macOS)
        setsockopt(sock, SOL_SOCKET, SO_REUSEPORT, &reuse, socklen_t(MemoryLayout<Int32>.size))
#endif

        var broadcast: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcast, socklen_t(MemoryLayout<Int32>.size))

        var tv = timeval(tv_sec: 0, tv_usec: Int32(Self.receivePollTimeoutUsec))
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var local = sockaddr_in()
        local.sin_family = sa_family_t(AF_INET)
        local.sin_port = 0
        local.sin_addr.s_addr = INADDR_ANY
        local.sin_zero = (0,0,0,0,0,0,0,0)
        withUnsafePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                _ = bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        var dest = sockaddr_in()
        dest.sin_family = sa_family_t(AF_INET)
        dest.sin_port = in_port_t(Self.bcastPort).bigEndian
        dest.sin_addr.s_addr = INADDR_BROADCAST
        dest.sin_zero = (0,0,0,0,0,0,0,0)

        for st in Self.ssdpTargets {
            let msg = "B-SEARCH * HTTP/1.1\r\nHOST: 255.255.255.255:\(Self.bcastPort)\r\nMAN: \"ssdp:discover\"\r\nMX: 3\r\nST: \(st)\r\nUSER-AGENT: UDAP/2.0\r\n\r\n"
            sendUDP(sock: sock, message: msg, dest: &dest)
        }

        return collectResponses(sock: sock, timeout: Self.timeout)
    }

    // MARK: - Port scan fallback

    func portScan(onProgress: (@Sendable (Int, Int, String, Bool) -> Void)? = nil) async -> [SSDPCandidate] {
        let subnets = localSubnets()
        guard !subnets.isEmpty else { return [] }

        var seen: Set<String> = []
        let ips = subnets.flatMap { subnet in
            (1...254).compactMap { host -> String? in
                let ip = "\(subnet).\(host)"
                return seen.insert(ip).inserted ? ip : nil
            }
        }
        let total = ips.count

        return await withTaskGroup(of: (SSDPCandidate?, String).self) { group in
            var iterator = ips.makeIterator()
            let initialCount = min(Self.portScanConcurrency, ips.count)
            for _ in 0..<initialCount {
                guard let ip = iterator.next() else { break }
                addPortScanTask(ip: ip, to: &group)
            }

            var found: [SSDPCandidate] = []
            var done = 0
            while let (candidate, ip) = await group.next() {
                done += 1
                onProgress?(done, total, ip, candidate != nil)
                if let candidate { found.append(candidate) }
                if let nextIP = iterator.next() {
                    addPortScanTask(ip: nextIP, to: &group)
                }
            }

            return found
        }
    }

    // MARK: - Helpers

    /// SSDP 응답 패킷을 수신해 IP + LOCATION + SERVER 헤더를 파싱한다
    private func collectResponses(sock: Int32, timeout: TimeInterval) -> [SSDPCandidate] {
        var seen: [String: SSDPCandidate] = [:]
        var buffer = [UInt8](repeating: 0, count: 65536)
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            var fromAddr = sockaddr_in()
            var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = withUnsafeMutablePointer(to: &fromAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(sock, &buffer, buffer.count, 0, $0, &fromLen)
                }
            }
            guard n > 0 else {
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    continue
                }
                break
            }

            // 송신 IP 추출
            var ipChars = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &fromAddr.sin_addr, &ipChars, socklen_t(INET_ADDRSTRLEN))
            let ip = String(cString: ipChars)

            let text = String(bytes: buffer[0..<n], encoding: .utf8) ?? ""
            let location = parseSSDPHeader("LOCATION", from: text)
            let server   = parseSSDPHeader("SERVER",   from: text)

            mergeCandidate(SSDPCandidate(ip: ip, location: location, server: server), into: &seen)
        }
        return Array(seen.values)
    }

    /// "HEADER-NAME: value" 형식에서 값을 추출 (대소문자 무관)
    private func parseSSDPHeader(_ name: String, from text: String) -> String {
        let upper = name.uppercased() + ":"
        for line in text.components(separatedBy: "\r\n") {
            if line.uppercased().hasPrefix(upper) {
                return String(line.dropFirst(name.count + 1))
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }

    private func sendUDP(sock: Int32, message: String, dest: inout sockaddr_in) {
        guard let data = message.data(using: .utf8) else { return }
        data.withUnsafeBytes { ptr in
            withUnsafePointer(to: &dest) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    _ = sendto(sock, ptr.baseAddress, data.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }

    nonisolated private func checkPort(ip: String, port: Int32) async -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { close(sock) }

        let flags = fcntl(sock, F_GETFL, 0)
        _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = inet_addr(ip)
        addr.sin_zero = (0,0,0,0,0,0,0,0)

        let ret = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        if ret == 0 { return true }
        guard errno == EINPROGRESS else { return false }

        var writeFDs = fd_set()
        fdSet(sock, set: &writeFDs)
        var tv = timeval(tv_sec: 0, tv_usec: 300_000)

        let selected = select(sock + 1, nil, &writeFDs, nil, &tv)
        guard selected > 0 else { return false }

        var error: Int32 = 0
        var errorLen = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(sock, SOL_SOCKET, SO_ERROR, &error, &errorLen)
        return error == 0
    }

    private func addPortScanTask(
        ip: String,
        to group: inout TaskGroup<(SSDPCandidate?, String)>
    ) {
        group.addTask { [self] in
            let open = await self.checkPort(ip: ip, port: Self.tvPort)
            return (open ? SSDPCandidate(ip: ip, location: "", server: "") : nil, ip)
        }
    }

    private func mergeCandidate(_ candidate: SSDPCandidate, into found: inout [String: SSDPCandidate]) {
        guard let current = found[candidate.ip] else {
            found[candidate.ip] = candidate
            return
        }

        let merged = SSDPCandidate(
            ip: candidate.ip,
            location: current.location.isEmpty ? candidate.location : current.location,
            server: current.server.isEmpty ? candidate.server : current.server
        )
        found[candidate.ip] = merged
    }

    /// 모든 활성 IPv4 인터페이스에서 /24 서브넷 주소를 수집한다.
    private func localSubnets() -> [String] {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [] }
        defer { freeifaddrs(ifaddr) }

        var subnets: [String] = []
        var ptr = ifaddr
        while let ifa = ptr {
            defer { ptr = ifa.pointee.ifa_next }
            guard ifa.pointee.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: ifa.pointee.ifa_name)
            let flags = Int32(ifa.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0 else { continue }
            guard (flags & IFF_LOOPBACK) == 0 else { continue }
            guard !name.hasPrefix("utun"), !name.hasPrefix("awdl"), !name.hasPrefix("llw") else { continue }

            var ipChars = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            ifa.pointee.ifa_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
                var addr = sin.pointee.sin_addr
                inet_ntop(AF_INET, &addr, &ipChars, socklen_t(INET_ADDRSTRLEN))
            }
            let ip = String(cString: ipChars)
            guard ip != "127.0.0.1", !ip.isEmpty else { continue }
            guard !ip.hasPrefix("169.254.") else { continue }
            let parts = ip.split(separator: ".")
            guard parts.count == 4 else { continue }
            let subnet = "\(parts[0]).\(parts[1]).\(parts[2])"
            if !subnets.contains(subnet) {
                subnets.append(subnet)
            }
        }
        return subnets
    }

    // fd_set helpers (macOS-specific)
    nonisolated private func fdSet(_ fd: Int32, set: inout fd_set) {
        let intOffset = Int(fd) / 32
        let bitOffset = Int(fd) % 32
        withUnsafeMutableBytes(of: &set) { ptr in
            ptr.storeBytes(of: ptr.load(fromByteOffset: intOffset * 4, as: UInt32.self) | (1 << bitOffset),
                           toByteOffset: intOffset * 4, as: UInt32.self)
        }
    }
}
