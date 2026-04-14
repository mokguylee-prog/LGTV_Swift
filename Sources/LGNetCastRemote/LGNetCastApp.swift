import SwiftUI
import AppKit

@main
struct LGNetCastApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var tv = TVController()

    var body: some Scene {

        // ── Full remote window ─────────────────────────────────────────────
        Window("LG NetCast 리모컨", id: "remote") {
            RemoteView()
                .environmentObject(tv)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

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
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 22, height: 22)
    }

    static let menuIcon: NSImage = {
        if let url = Bundle.module.url(forResource: "lg_menu_icon", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        return NSImage(systemSymbolName: "tv", accessibilityDescription: nil)!
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
            NSApp.applicationIconImage = icon
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false   // keep running when the remote window is closed
    }
}
