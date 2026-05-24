import Foundation

// MARK: - Key Input

extension TVController {

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

        // Session likely expired — reconnect
        connectionState = .disconnected
        statusMessage   = "세션 만료 — 재연결..."
        await connect()
        return false
    }

    // MARK: - Legacy touch command (shared by Mouse extension)

    @discardableResult
    func sendLegacyTouchCommand(
        type:      String,
        fields:    String = "",
        keepAlive: Bool = false,
        timeout:   TimeInterval = 2
    ) async -> Bool {
        if !connectionState.isConnected { await connect() }
        guard let sessionID = connectionState.session else { return false }

        let fieldBlock = fields.isEmpty ? "" : "\n            \(fields)"
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <command>
            <session>\(sessionID)</session>
            <type>\(type)</type>\(fieldBlock)
        </command>
        """

        guard let url = URL(string: "\(baseURL)/dtv_wifirc") else { return false }
        do {
            let (_, response) = try await post(url: url, body: xml,
                                               keepAlive: keepAlive, timeout: timeout)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                return true
            }
        } catch { return false }
        return false
    }
}
