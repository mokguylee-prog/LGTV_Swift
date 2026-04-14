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

    // MARK: - Private

    private let stateManager = StateManager()
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        return URLSession(configuration: config)
    }()

    private var baseURL: String { "http://\(tvIP):\(kPort)/hdcp/api" }

    // MARK: - Init

    init() {
        if let state = stateManager.load() {
            tvIP = state.tvIP
            pin = state.pin
        }
        // 저장된 IP·PIN이 있으면 시작 시 자동 연결
        Task { await self.autoConnect() }
    }

    func autoConnect() async {
        guard !tvIP.isEmpty else { return }
        guard await isPortOpen(ip: tvIP) else {
            statusMessage = "TV에 연결할 수 없습니다 (\(tvIP))"
            return
        }
        if pin.isEmpty {
            // PIN이 없으면 TV 화면에 PIN 표시 요청
            await requestPIN()
        } else {
            // PIN이 있으면 바로 연결
            await connect()
        }
    }

    /// macOS에서 SO_SNDTIMEO는 connect()에 적용되지 않으므로
    /// non-blocking socket + select()로 타임아웃을 직접 제어한다.
    private func isPortOpen(ip: String, timeoutMs: Int = 2000) async -> Bool {
        await withCheckedContinuation { cont in
            Task.detached {
                let sock = socket(AF_INET, SOCK_STREAM, 0)
                guard sock >= 0 else { cont.resume(returning: false); return }
                defer { close(sock) }

                // Non-blocking 모드
                let flags = fcntl(sock, F_GETFL, 0)
                _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)

                var addr = sockaddr_in()
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = in_port_t(8080).bigEndian
                addr.sin_addr.s_addr = inet_addr(ip)
                addr.sin_zero = (0,0,0,0,0,0,0,0)

                let ret = withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        Darwin.connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
                if ret == 0 { cont.resume(returning: true); return }
                guard errno == EINPROGRESS else { cont.resume(returning: false); return }

                // select()로 연결 완료 대기
                var writeFDs = fd_set()
                let intOffset = Int(sock) / 32
                let bitOffset = Int(sock) % 32
                withUnsafeMutableBytes(of: &writeFDs) { ptr in
                    let cur = ptr.load(fromByteOffset: intOffset * 4, as: UInt32.self)
                    ptr.storeBytes(of: cur | (1 << bitOffset), toByteOffset: intOffset * 4, as: UInt32.self)
                }
                var tv = timeval(tv_sec: timeoutMs / 1000, tv_usec: Int32((timeoutMs % 1000) * 1000))
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

    // MARK: - Authentication

    /// Sends AuthKeyReq to display PIN on TV screen.
    func requestPIN() async {
        connectionState = .connecting
        statusMessage = "PIN 요청 중..."

        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <auth>
            <type>AuthKeyReq</type>
        </auth>
        """

        guard let url = URL(string: "\(baseURL)/auth") else {
            setError("Invalid URL"); return
        }

        do {
            let (_, response) = try await post(url: url, body: xml)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                statusMessage = "TV 화면에서 PIN을 확인하세요"
                connectionState = .disconnected
            } else {
                setError("PIN 요청 실패")
            }
        } catch {
            setError(error.localizedDescription)
        }
    }

    /// Authenticates with PIN and stores session token.
    func connect() async {
        guard !pin.isEmpty else { statusMessage = "PIN을 입력하세요"; return }

        connectionState = .connecting
        statusMessage = "인증 중..."

        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <auth>
            <type>AuthReq</type>
            <value>\(pin)</value>
        </auth>
        """

        guard let url = URL(string: "\(baseURL)/auth") else {
            setError("Invalid URL"); return
        }

        do {
            let (data, response) = try await post(url: url, body: xml)
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let text = String(data: data, encoding: .utf8),
               let sessionID = parseTag("session", from: text) {
                connectionState = .connected(session: sessionID)
                statusMessage = "연결됨 ✓"
                saveState()
            } else {
                setError("인증 실패 — PIN을 확인하세요")
            }
        } catch {
            setError(error.localizedDescription)
        }
    }

    // MARK: - Key Input

    @discardableResult
    func sendKey(_ key: LGKey) async -> Bool {
        return await sendKeyCode(key.code)
    }

    @discardableResult
    func sendKeyCode(_ code: Int) async -> Bool {
        if !connectionState.isConnected { await connect() }
        guard let sessionID = connectionState.session else { return false }

        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <command>
            <session>\(sessionID)</session>
            <type>HandleKeyInput</type>
            <value>\(code)</value>
        </command>
        """

        // Try both legacy endpoints for compatibility
        for endpoint in ["dtv_wifirc", "command"] {
            guard let url = URL(string: "\(baseURL)/\(endpoint)") else { continue }
            do {
                let (_, response) = try await post(url: url, body: xml, timeout: 3)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    return true
                }
            } catch { continue }
        }

        // Session likely expired
        connectionState = .disconnected
        statusMessage = "세션 만료 — 재연결..."
        await connect()
        return false
    }

    // MARK: - Device Discovery

    func discover() async {
        isScanning = true
        discoveredDevices = []
        statusMessage = "네트워크 검색 중..."

        let ssdp = SSDPDiscovery()
        let preferredIP = tvIP
        var candidates = await ssdp.discover(includePortScan: false)
        candidates = mergePreferredCandidate(preferredIP, into: candidates)

        var devices = await buildDevices(from: candidates)
        var orderedDevices = orderDevices(devices, preferredIP: preferredIP)

        if orderedDevices.isEmpty {
            statusMessage = "SSDP 응답 없음 - 로컬 네트워크 스캔 중..."
            candidates = await ssdp.discover(includePortScan: true)
            candidates = mergePreferredCandidate(preferredIP, into: candidates)
            devices = await buildDevices(from: candidates)
            orderedDevices = orderDevices(devices, preferredIP: preferredIP)
        }

        discoveredDevices = orderedDevices
        isScanning = false

        if orderedDevices.isEmpty {
            statusMessage = "기기를 찾지 못했습니다"
            return
        }
        if let bestCandidate = orderedDevices.first(where: { $0.verified }) ?? orderedDevices.first {
            if bestCandidate.verified {
                statusMessage = "LG TV 찾음: \(bestCandidate.ip)"
            } else {
                statusMessage = "접속 가능한 후보 기기 \(orderedDevices.count)개 발견"
            }
        } else {
            statusMessage = "\(orderedDevices.count)개 기기 발견"
        }

        // LG TV 확인되면 저장 후 자동 연결
        if let first = discoveredDevices.first(where: { $0.verified }), !pin.isEmpty {
            tvIP = first.ip
            saveState()
            await connect()
        }
    }

    func selectDevice(_ device: TVDevice) {
        tvIP = device.ip
        connectionState = .disconnected
        statusMessage = "IP 선택됨: \(device.ip)"
        saveState()
    }

    // MARK: - Helpers

    private func post(url: URL, body: String, timeout: TimeInterval = 5) async throws -> (Data, URLResponse) {
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = "POST"
        req.setValue("application/atom+xml", forHTTPHeaderField: "Content-Type")
        req.setValue("application/atom+xml", forHTTPHeaderField: "Accept")
        req.setValue("iPhone",               forHTTPHeaderField: "User-Agent")
        req.setValue("close",                forHTTPHeaderField: "Connection")
        req.httpBody = body.data(using: .utf8)
        return try await session.data(for: req)
    }

    private func parseTag(_ tag: String, from xml: String) -> String? {
        guard let start = xml.range(of: "<\(tag)>"),
              let end   = xml.range(of: "</\(tag)>") else { return nil }
        let value = String(xml[start.upperBound..<end.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func buildDevices(from candidates: [SSDPCandidate]) async -> [TVDevice] {
        var devices: [TVDevice] = []

        await withTaskGroup(of: TVDevice?.self) { group in
            for candidate in candidates {
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    let (reachable, verified, label) = await self.verifyLGTV(
                        ip: candidate.ip,
                        location: candidate.location,
                        server: candidate.server
                    )
                    guard reachable else { return nil }

                    let displayName: String
                    if verified {
                        let suffix = label.isEmpty ? "" : "  \(label)"
                        displayName = "\(candidate.ip)  [LG TV 확인]\(suffix)"
                    } else {
                        displayName = "\(candidate.ip)  [후보 기기]"
                    }
                    return TVDevice(ip: candidate.ip, name: displayName, verified: verified)
                }
            }

            for await device in group {
                if let device {
                    devices.append(device)
                }
            }
        }

        return devices
    }

    private func orderDevices(_ devices: [TVDevice], preferredIP: String) -> [TVDevice] {
        let grouped = Dictionary(grouping: devices, by: \.ip)

        return grouped.values
            .compactMap { group in
                group.sorted {
                    if $0.verified != $1.verified {
                        return $0.verified && !$1.verified
                    }
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }.first
            }
            .sorted {
                if $0.verified != $1.verified {
                    return $0.verified && !$1.verified
                }
                let leftPreferred = !$0.ip.isEmpty && $0.ip == preferredIP
                let rightPreferred = !$1.ip.isEmpty && $1.ip == preferredIP
                if leftPreferred != rightPreferred {
                    return leftPreferred
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    private func mergePreferredCandidate(_ preferredIP: String, into candidates: [SSDPCandidate]) -> [SSDPCandidate] {
        guard !preferredIP.isEmpty else { return candidates }
        guard !candidates.contains(where: { $0.ip == preferredIP }) else { return candidates }
        return candidates + [SSDPCandidate(ip: preferredIP, location: "", server: "")]
    }

    /// 포트 8080이 열려있으면 후보에 유지하고, LG TV 여부를 추가로 검증한다.
    private func verifyLGTV(ip: String, location: String, server: String) async -> (reachable: Bool, verified: Bool, label: String) {
        // 1. port 8080 연결 가능 여부 확인 (2초 타임아웃)
        guard await isPortOpen(ip: ip, timeoutMs: 2000) else { return (false, false, "") }

        let ssdpServerLooksLikeLG = looksLikeLGServer(server)

        // 2. SSDP LOCATION URL → UPnP 기기 설명 XML 파싱
        if !location.isEmpty, let url = URL(string: location) {
            var req = URLRequest(url: url, timeoutInterval: 3)
            req.setValue("UDAP/2.0", forHTTPHeaderField: "User-Agent")
            if let (data, response) = try? await session.data(for: req) {
                let xml        = String(data: data, encoding: .utf8) ?? ""
                let mfr        = (parseTag("manufacturer",    from: xml) ?? "").uppercased()
                let devType    = (parseTag("deviceType",      from: xml) ?? "").uppercased()
                let modelName  =  parseTag("modelName",       from: xml) ?? ""
                let friendly   =  parseTag("friendlyName",    from: xml) ?? ""
                let modelDesc  =  parseTag("modelDescription",from: xml) ?? ""
                let nameBlob   = "\(modelName) \(friendly) \(modelDesc)".uppercased()
                let responseServer = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Server") ?? ""

                let mfrOK   = mfr.contains("LG")
                let tvHint  = devType.contains("TV") || devType.contains("MEDIARENDERER")
                           || nameBlob.contains("TV") || nameBlob.contains("LW5700")
                           || nameBlob.contains("SMART TV")
                let srvHasLG = ssdpServerLooksLikeLG || looksLikeLGServer(responseServer)

                if (mfrOK && tvHint) || srvHasLG {
                    let label = [friendly, modelName].filter { !$0.isEmpty }.joined(separator: " / ")
                    return (true, true, label)
                }
            }
        }

        // 3. 루트 페이지 응답 헤더와 텍스트 확인
        if let url = URL(string: "http://\(ip):\(kPort)/") {
            var req = URLRequest(url: url, timeoutInterval: 2)
            req.setValue("iPhone", forHTTPHeaderField: "User-Agent")
            if let (data, response) = try? await session.data(for: req) {
                let responseServer = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Server") ?? ""
                if looksLikeLGServer(responseServer) {
                    return (true, true, "")
                }

                let text = (String(data: data, encoding: .utf8) ?? "").uppercased()
                if text.contains("LG") || text.contains("NETCAST") || text.contains("UDAP") {
                    return (true, true, "")
                }
            }
        }

        if ssdpServerLooksLikeLG {
            return (true, true, "")
        }

        // 4. HDCP API 엔드포인트 응답 확인 (LG NetCast 전용)
        if let url = URL(string: "http://\(ip):\(kPort)/hdcp/api") {
            var req = URLRequest(url: url, timeoutInterval: 2)
            req.setValue("iPhone", forHTTPHeaderField: "User-Agent")
            if let (_, resp) = try? await session.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode < 500 {
                return (true, true, "LG NetCast")
            }
        }

        // 5. 포트는 열려있지만 확인이 덜 된 경우도 후보로 유지
        return (true, false, "")
    }

    private func looksLikeLGServer(_ value: String) -> Bool {
        let upper = value.uppercased()
        return upper.contains("LG") || upper.contains("NETCAST") || upper.contains("UDAP")
    }

    private func setError(_ msg: String) {
        connectionState = .error(msg)
        statusMessage = msg
    }
}
