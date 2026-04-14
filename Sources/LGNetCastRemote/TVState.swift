import Foundation

struct TVState: Codable {
    var tvIP: String
    var pin: String
    var savedAt: String

    init(tvIP: String, pin: String) {
        self.tvIP = tvIP
        self.pin = pin
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        self.savedAt = formatter.string(from: Date())
    }
}

struct TVDevice: Identifiable {
    let id = UUID()
    let ip: String
    let name: String
    let verified: Bool
}

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected(session: String)
    case error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var session: String? {
        if case .connected(let s) = self { return s }
        return nil
    }

    var statusText: String {
        switch self {
        case .disconnected: return "연결 안됨"
        case .connecting:   return "연결 중..."
        case .connected:    return "연결됨 ✓"
        case .error(let m): return "오류: \(m)"
        }
    }

    var color: String {
        switch self {
        case .disconnected: return "gray"
        case .connecting:   return "orange"
        case .connected:    return "green"
        case .error:        return "red"
        }
    }
}
