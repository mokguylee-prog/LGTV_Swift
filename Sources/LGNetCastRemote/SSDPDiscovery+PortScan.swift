import Foundation
import Darwin

// MARK: - Port scan

extension SSDPDiscovery {

    func portScan(
        onProgress: (@Sendable (Int, Int, String, Bool) -> Void)? = nil
    ) async -> [SSDPCandidate] {
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
            var iterator     = ips.makeIterator()
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

    nonisolated func checkPort(ip: String, port: Int32) async -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { close(sock) }

        let flags = fcntl(sock, F_GETFL, 0)
        _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)

        var addr = sockaddr_in()
        addr.sin_family      = sa_family_t(AF_INET)
        addr.sin_port        = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = inet_addr(ip)
        addr.sin_zero        = (0,0,0,0,0,0,0,0)

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

    func addPortScanTask(
        ip: String,
        to group: inout TaskGroup<(SSDPCandidate?, String)>
    ) {
        group.addTask { [self] in
            let open = await self.checkPort(ip: ip, port: Self.tvPort)
            return (open ? SSDPCandidate(ip: ip, location: "", server: "") : nil, ip)
        }
    }

    // MARK: - Local subnet discovery

    func localSubnets() -> [String] {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [] }
        defer { freeifaddrs(ifaddr) }

        var subnets: [String] = []
        var ptr = ifaddr
        while let ifa = ptr {
            defer { ptr = ifa.pointee.ifa_next }
            guard ifa.pointee.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name  = String(cString: ifa.pointee.ifa_name)
            let flags = Int32(ifa.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0 else { continue }
            guard !name.hasPrefix("utun"), !name.hasPrefix("awdl"),
                  !name.hasPrefix("llw") else { continue }

            var ipChars = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            ifa.pointee.ifa_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
                var addr = sin.pointee.sin_addr
                inet_ntop(AF_INET, &addr, &ipChars, socklen_t(INET_ADDRSTRLEN))
            }
            let ip = String(cString: ipChars)
            guard ip != "127.0.0.1", !ip.isEmpty, !ip.hasPrefix("169.254.") else { continue }
            let parts = ip.split(separator: ".")
            guard parts.count == 4 else { continue }
            let subnet = "\(parts[0]).\(parts[1]).\(parts[2])"
            if !subnets.contains(subnet) { subnets.append(subnet) }
        }
        return subnets
    }
}
