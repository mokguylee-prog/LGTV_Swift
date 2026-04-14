import Foundation

/// Installs / removes a LaunchAgent plist so the app auto-starts at login.
struct LaunchAgentManager {

    static let bundleID = "com.kadelee.lgnetcast.menubar"

    private static var plistURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library/LaunchAgents")
            .appendingPathComponent("\(bundleID).plist")
    }

    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: Self.plistURL.path)
    }

    func install(appPath: String) throws {
        let logDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs")
        let plist: [String: Any] = [
            "Label":           Self.bundleID,
            "ProgramArguments": [appPath],
            "RunAtLoad":       true,
            "KeepAlive":       false,
            "StandardOutPath": logDir.appendingPathComponent("lgnetcast_menubar.log").path,
            "StandardErrorPath": logDir.appendingPathComponent("lgnetcast_menubar_err.log").path
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let dir = Self.plistURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: Self.plistURL)

        // Load agent immediately
        let process = Process()
        process.launchPath = "/bin/launchctl"
        process.arguments = ["load", Self.plistURL.path]
        process.launch()
        process.waitUntilExit()
    }

    func remove() throws {
        guard isInstalled else { return }

        // Unload first
        let process = Process()
        process.launchPath = "/bin/launchctl"
        process.arguments = ["unload", Self.plistURL.path]
        process.launch()
        process.waitUntilExit()

        try FileManager.default.removeItem(at: Self.plistURL)
    }

    func toggle(appPath: String) {
        do {
            if isInstalled {
                try remove()
            } else {
                try install(appPath: appPath)
            }
        } catch {
            print("LaunchAgent error: \(error)")
        }
    }
}
