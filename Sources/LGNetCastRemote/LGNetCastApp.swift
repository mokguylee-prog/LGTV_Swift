import SwiftUI
import AppKit

@main
struct LGNetCastApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var tv = TVController()

    private var appVersion: String {
        let ver  = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.6"
        let date = Bundle.main.infoDictionary?["CFBundleBuildDate"] as? String ?? "2026.05.25"
        return "v\(ver)  (\(date))"
    }

    var body: some Scene {

        // ── Full remote window ─────────────────────────────────────────────
        Window("LG NetCast 리모컨  \(appVersion)", id: "remote") {
            RemoteView()
                .environmentObject(tv)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        // ── Connection setup window ────────────────────────────────────────
        Window("TV 연결 설정", id: "connection") {
            ConnectionWindowView()
                .environmentObject(tv)
        }
        .windowResizability(.contentMinSize)
        .defaultPosition(.topTrailing)

        // ── Menu-bar extra ─────────────────────────────────────────────────
        MenuBarExtra {
            MenuBarView()
                .environmentObject(tv)
        } label: {
            MenuBarIcon()
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - MenuBar Icon

private struct MenuBarIcon: View {
    var body: some View {
        Image(nsImage: Self.menuIcon)
    }

    static let menuIcon: NSImage = {
        if let url = Bundle.module.url(forResource: "lg_menu_icon", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 20, height: 20)
            return img
        }
        let img = NSImage(systemSymbolName: "tv", accessibilityDescription: nil)!
        img.size = NSSize(width: 20, height: 20)
        return img
    }()
}

// MARK: - AppDelegate (background-only, no Dock icon)

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock — this is a menubar-only app
        NSApp.setActivationPolicy(.accessory)

        // 앱 아이콘을 번들의 LG 로고로 설정
        if let url = Bundle.module.url(forResource: "LGNetCast", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            let s = icon.size
            NSApp.applicationIconImage = icon.resized(to: NSSize(width: s.width * 0.49, height: s.height * 0.49))
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false   // keep running when the remote window is closed
    }
}

private extension NSImage {
    func resized(to newSize: NSSize) -> NSImage {
        let result = NSImage(size: newSize)
        result.lockFocus()
        draw(in: NSRect(origin: .zero, size: newSize),
             from: NSRect(origin: .zero, size: size),
             operation: .copy, fraction: 1.0)
        result.unlockFocus()
        return result
    }
}
