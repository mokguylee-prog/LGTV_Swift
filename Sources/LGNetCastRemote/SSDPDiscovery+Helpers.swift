import Foundation
import Darwin

// MARK: - SSDPDiscovery helpers

extension SSDPDiscovery {

    // MARK: Response collection

    func collectResponses(sock: Int32, timeout: TimeInterval) -> [SSDPCandidate] {
        var seen:   [String: SSDPCandidate] = [:]
        var buffer  = [UInt8](repeating: 0, count: 65536)
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            var fromAddr = sockaddr_in()
            var fromLen  = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = withUnsafeMutablePointer(to: &fromAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(sock, &buffer, buffer.count, 0, $0, &fromLen)
                }
            }
            guard n > 0 else {
                if errno == EAGAIN || errno == EWOULDBLOCK { continue }
                break
            }

            var ipChars = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &fromAddr.sin_addr, &ipChars, socklen_t(INET_ADDRSTRLEN))
            let ip = String(cString: ipChars)

            let text     = String(bytes: buffer[0..<n], encoding: .utf8) ?? ""
            let location = parseSSDPHeader("LOCATION", from: text)
            let server   = parseSSDPHeader("SERVER",   from: text)

            mergeCandidate(SSDPCandidate(ip: ip, location: location, server: server),
                           into: &seen)
        }
        return Array(seen.values)
    }

    // MARK: Header parsing

    func parseSSDPHeader(_ name: String, from text: String) -> String {
        let upper = name.uppercased() + ":"
        for line in text.components(separatedBy: "\r\n") {
            if line.uppercased().hasPrefix(upper) {
                return String(line.dropFirst(name.count + 1))
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }

    // MARK: UDP send

    func sendUDP(sock: Int32, message: String, dest: inout sockaddr_in) {
        guard let data = message.data(using: .utf8) else { return }
        data.withUnsafeBytes { ptr in
            withUnsafePointer(to: &dest) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    _ = sendto(sock, ptr.baseAddress, data.count, 0, $0,
                               socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }

    // MARK: Candidate merge

    func mergeCandidate(_ candidate: SSDPCandidate,
                        into found: inout [String: SSDPCandidate]) {
        guard let current = found[candidate.ip] else {
            found[candidate.ip] = candidate; return
        }
        found[candidate.ip] = SSDPCandidate(
            ip:       candidate.ip,
            location: current.location.isEmpty ? candidate.location : current.location,
            server:   current.server.isEmpty   ? candidate.server   : current.server
        )
    }

    // MARK: fd_set helper (macOS-specific)

    nonisolated func fdSet(_ fd: Int32, set: inout fd_set) {
        let intOffset = Int(fd) / 32
        let bitOffset = Int(fd) % 32
        withUnsafeMutableBytes(of: &set) { ptr in
            ptr.storeBytes(
                of: ptr.load(fromByteOffset: intOffset * 4, as: UInt32.self) | (1 << bitOffset),
                toByteOffset: intOffset * 4,
                as: UInt32.self
            )
        }
    }
}
