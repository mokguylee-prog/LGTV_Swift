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
               let text      = String(data: data, encoding: .utf8),
               let sessionID = parseTag("session", from: text) ?? parseTag("value", from: text) {
                connectionState = .connected(session: sessionID)
                statusMessage   = "연결됨 ✓"
                saveState()
            } else {
                setError("인증 실패 — PIN을 확인하세요")
            }
        } catch {
            setError(error.localizedDescription)
        }
    }
}
