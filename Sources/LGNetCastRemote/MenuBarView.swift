import SwiftUI

/// Compact popup shown in the macOS menu bar.
struct MenuBarView: View {
    @EnvironmentObject var tv: TVController
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 8) {

            // Status header
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(tv.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Divider()

            // Quick controls (only when connected)
            if tv.connectionState.isConnected {
                HStack(spacing: 6) {
                    QuickBtn("speaker.slash",  key: .mute,    tv: tv, repeatable: false, tint: .yellow)
                    QuickBtn("speaker.minus",  key: .volDown, tv: tv, tint: .white)
                    QuickBtn("speaker.plus",   key: .volUp,   tv: tv, tint: .white)
                    Divider().frame(height: 24)
                    QuickBtn("chevron.up",   label: "CH", key: .chUp,   tv: tv, tint: .blue)
                    QuickBtn("chevron.down", label: "CH", key: .chDown, tv: tv, tint: .blue)
                }
                .padding(.horizontal, 8)

                Divider()
            }

            // Action buttons
            Button("리모컨 열기") {
                openRemoteWindow()
            }
            .buttonStyle(MenuActionStyle())

            if !tv.connectionState.isConnected {
                Button("연결") {
                    Task { await tv.connect() }
                }
                .buttonStyle(MenuActionStyle())
            }

            Divider()

            // Auto-start toggle
            AutoStartToggleView()

            Divider()

            // About & Quit
            HStack {
                Text("LG NetCast Remote")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button("종료") { NSApp.terminate(nil) }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .frame(width: 220)
    }

    private var statusColor: Color {
        switch tv.connectionState {
        case .disconnected: return .gray
        case .connecting:   return .orange
        case .connected:    return .green
        case .error:        return .red
        }
    }

    private func openRemoteWindow() {
        let menuWindow = NSApp.keyWindow
        openWindow(id: "remote")
        NSApp.activate(ignoringOtherApps: true)
        dismiss()

        DispatchQueue.main.async {
            menuWindow?.close()
        }
    }
}

// MARK: - Sub-components

private struct QuickBtn: View {
    let icon: String
    let label: String?
    let key: LGKey
    let repeatable: Bool
    let tint: Color
    @ObservedObject var tv: TVController

    @State private var isPressed = false
    @State private var repeatTask: Task<Void, Never>?

    init(_ icon: String, label: String? = nil, key: LGKey, tv: TVController, repeatable: Bool = true, tint: Color = .primary) {
        self.icon = icon
        self.label = label
        self.key = key
        self.tv = tv
        self.repeatable = repeatable
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 1) {
            if let label {
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(tint)
            }
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(tint)
        }
        .frame(width: label != nil ? 38 : 28, height: 28)
        .background(isPressed ? tint.opacity(0.25) : Color.primary.opacity(0.06))
        .cornerRadius(6)
        .animation(.easeInOut(duration: 0.08), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed else { return }
                    isPressed = true
                    Task { await tv.sendKey(key) }
                    if repeatable { startRepeat() }
                }
                .onEnded { _ in
                    isPressed = false
                    stopRepeat()
                }
        )
    }

    private func startRepeat() {
        repeatTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)   // 0.5 s initial delay
            while !Task.isCancelled {
                await tv.sendKey(key)
                try? await Task.sleep(nanoseconds: 120_000_000) // 0.12 s interval
            }
        }
    }

    private func stopRepeat() {
        repeatTask?.cancel()
        repeatTask = nil
    }
}

private struct MenuActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(configuration.isPressed ? Color.primary.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
    }
}

private struct AutoStartToggleView: View {
    @State private var isOn = LaunchAgentManager().isInstalled

    var body: some View {
        Toggle("로그인 시 자동 시작", isOn: $isOn)
            .toggleStyle(.switch)
            .controlSize(.mini)
            .padding(.horizontal, 12)
            .onChange(of: isOn) { newVal in
                let mgr = LaunchAgentManager()
                let path = Bundle.main.executablePath ?? ProcessInfo.processInfo.arguments[0]
                if newVal {
                    try? mgr.install(appPath: path)
                } else {
                    try? mgr.remove()
                }
            }
    }
}
