import Foundation

// MARK: - Authentication

extension TVController {

    /// Sends AuthKeyReq — makes the TV display its PIN on screen.
    func requestPIN() async {
        connectionState = .connecting
        statusMessage   = "PIN 요청 중..."

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
                autoReconnect   = false   // 사용자가 새 PIN 을 넣을 때까지 자동 재연결 보류
                statusMessage   = "TV 화면에서 PIN을 확인하세요"
                connectionState = .disconnected
            } else {
                setError("PIN 요청 실패")
            }
        } catch {
            setError(error.localizedDescription)
        }
    }

    /// Authenticates with PIN and stores the session token.
    func connect() async {
        guard !pin.isEmpty else { statusMessage = "PIN을 입력하세요"; return }

        connectionState = .connecting
        statusMessage   = "인증 중..."

        switch await authenticate(ip: tvIP) {
        case .session(let sessionID):
            connectionState = .connected(session: sessionID)
            statusMessage   = "연결됨 ✓"
            autoReconnect   = true
            healthMisses    = 0
            saveState()
        case .rejected:
            // TV 는 있는데 거부 = PIN 문제. 빨강으로만 표시하고 자동 재시도하지 않는다.
            setError("인증 실패 — PIN을 확인하세요")
        case .failed(let msg):
            // TV 가 안 잡힘(보통 꺼짐) — 회색으로 두고 헬스 루프가 다시 찾게 한다.
            connectionState = .disconnected
            statusMessage   = "TV 응답 없음 — \(msg)"
        }
    }

    enum AuthResult {
        case session(String)
        case rejected
        case failed(String)
    }

    /// Sends AuthReq to `ip` without touching controller state.
    /// 8080 이 열려 있어도 프린터 등일 수 있으므로, 세션을 받아야만 TV 로 본다.
    func authenticate(ip: String) async -> AuthResult {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <auth>
            <type>AuthReq</type>
            <value>\(pin)</value>
        </auth>
        """

        guard let url = URL(string: "http://\(ip):8080/hdcp/api/auth") else {
            return .failed("Invalid URL")
        }
        do {
            let (data, response) = try await post(url: url, body: xml)
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let text      = String(data: data, encoding: .utf8),
               let sessionID = parseTag("session", from: text) ?? parseTag("value", from: text) {
                return .session(sessionID)
            }
            return .rejected
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
