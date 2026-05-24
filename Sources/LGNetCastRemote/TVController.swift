import Foundation
import Combine
import Darwin

private let kPort = 8080

@MainActor
class TVController: ObservableObject {

    // MARK: - Published State

    @Published var tvIP: String = "172.30.1.82"
    @Published var pin: String = "SMKBWA"
    @Published var connectionState: ConnectionState = .disconnected
    @Published var discoveredDevices: [TVDevice] = []
    @Published var isScanning: Bool = false
    @Published var statusMessage: String = "연결 안됨"

    // 검색 진행 상황
    @Published var ssdpDone    = false
    @Published var portScanned = 0
    @Published var portTotal   = 0
    @Published var portLog: [(ip: String, open: Bool)] = []
    @Published var verifyDone  = 0
    @Published var verifyTotal = 0

    // MARK: - Internal

    let stateManager = StateManager()

    let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 5
        config.timeoutIntervalForResource = 10
        return URLSession(configuration: config)
    }()

    var baseURL: String { "http://\(tvIP):\(kPort)/hdcp/api" }

    // MARK: - Init

    init() {
        if let state = stateManager.load() {
            tvIP = state.tvIP
            pin  = state.pin
        }
        Task { await self.autoConnect() }
    }

    func autoConnect() async {
        guard !tvIP.isEmpty else { return }
        guard await isPortOpen(ip: tvIP) else {
            statusMessage = "TV에 연결할 수 없습니다 (\(tvIP))"
            return
        }
        if pin.isEmpty { await requestPIN() } else { await connect() }
    }

    // MARK: - Port check (non-blocking BSD socket + select)

    nonisolated func isPortOpen(ip: String, timeoutMs: Int = 2000) async -> Bool {
        await withCheckedContinuation { cont in
            Task.detached {
                let sock = socket(AF_INET, SOCK_STREAM, 0)
                guard sock >= 0 else { cont.resume(returning: false); return }
                defer { close(sock) }

                let flags = fcntl(sock, F_GETFL, 0)
                _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)

                var addr = sockaddr_in()
                addr.sin_family      = sa_family_t(AF_INET)
                addr.sin_port        = in_port_t(8080).bigEndian
                addr.sin_addr.s_addr = inet_addr(ip)
                addr.sin_zero        = (0,0,0,0,0,0,0,0)

                let ret = withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        Darwin.connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
                if ret == 0 { cont.resume(returning: true); return }
                guard errno == EINPROGRESS else { cont.resume(returning: false); return }

                var writeFDs = fd_set()
                let intOffset = Int(sock) / 32
                let bitOffset = Int(sock) % 32
                withUnsafeMutableBytes(of: &writeFDs) { ptr in
                    let cur = ptr.load(fromByteOffset: intOffset * 4, as: UInt32.self)
                    ptr.storeBytes(of: cur | (1 << bitOffset),
                                   toByteOffset: intOffset * 4, as: UInt32.self)
                }
                var tv = timeval(tv_sec: timeoutMs / 1000,
                                 tv_usec: Int32((timeoutMs % 1000) * 1000))
                let selected = select(sock + 1, nil, &writeFDs, nil, &tv)
                guard selected > 0 else { cont.resume(returning: false); return }

                var error: Int32 = 0
                var errorLen = socklen_t(MemoryLayout<Int32>.size)
                getsockopt(sock, SOL_SOCKET, SO_ERROR, &error, &errorLen)
                cont.resume(returning: error == 0)
            }
        }
    }

    // MARK: - Persistence

    func saveState() {
        stateManager.save(TVState(tvIP: tvIP, pin: pin))
    }

    // MARK: - Shared helpers (used by Auth, Keys, Mouse, Verify extensions)

    func post(url: URL, body: String, keepAlive: Bool = false,
              timeout: TimeInterval = 5) async throws -> (Data, URLResponse) {
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = "POST"
        req.setValue("application/atom+xml", forHTTPHeaderField: "Content-Type")
        req.setValue("application/atom+xml", forHTTPHeaderField: "Accept")
        req.setValue("iPhone",               forHTTPHeaderField: "User-Agent")
        req.setValue(keepAlive ? "Keep-Alive" : "close", forHTTPHeaderField: "Connection")
        req.httpBody = body.data(using: .utf8)
        return try await session.data(for: req)
    }

    nonisolated func parseTag(_ tag: String, from xml: String) -> String? {
        guard let start = xml.range(of: "<\(tag)>"),
              let end   = xml.range(of: "</\(tag)>") else { return nil }
        let value = String(xml[start.upperBound..<end.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func setError(_ msg: String) {
        connectionState = .error(msg)
        statusMessage   = msg
    }
}
