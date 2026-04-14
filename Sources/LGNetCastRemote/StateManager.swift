import Foundation

/// Persists TV IP and PIN to ~/Library/Application Support/.
struct StateManager {

    private static let appName = "LG NetCast Remote"
    private static let fileName = "lg_remote_state.json"

    private var stateURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent(Self.appName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(Self.fileName)
    }

    func save(_ state: TVState) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: stateURL)
    }

    func load() -> TVState? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return try? JSONDecoder().decode(TVState.self, from: data)
    }
}
