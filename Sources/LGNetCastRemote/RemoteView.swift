import SwiftUI

// MARK: - RemoteView

enum RemotePanelMode { case remote, shortcuts, mouse }

struct RemoteView: View {
    @EnvironmentObject var tv: TVController
    @Environment(\.openWindow) private var openWindow
    @State private var selectedMode: RemotePanelMode = .remote

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            HStack(spacing: 8) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 7, height: 7)
                Text(tv.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                modeButtons
                Button {
                    openWindow(id: "connection")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("연결 설정", systemImage: "network.badge.shield.half.filled")
                        .font(.caption)
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 0) { panelContent }
                        .padding(8)
                        .background(Color.bodyBg)
                        .overlay(Rectangle().stroke(Color.edge, lineWidth: 1)
                            .clipShape(RoundedRectangle(cornerRadius: 8)))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background(Color.appBg)
                .disabled(!tv.connectionState.isConnected)
                .opacity(tv.connectionState.isConnected ? 1 : 0.45)
            }
            .background(Color.appBg)
        }
        .frame(width: 480)
        .background(Color.appBg)
    }

    // MARK: - Mode bar

    private var modeButtons: some View {
        HStack(spacing: 4) {
            RemoteModeButton(title: "리모컨", systemImage: "rectangle.grid.3x2",
                             isSelected: selectedMode == .remote)    { selectMode(.remote) }
            RemoteModeButton(title: "휠",    systemImage: "dial.low",
                             isSelected: selectedMode == .shortcuts) { selectMode(.shortcuts) }
            RemoteModeButton(title: "패드",  systemImage: "cursorarrow",
                             isSelected: selectedMode == .mouse)     { selectMode(.mouse) }
        }
    }

    func selectMode(_ mode: RemotePanelMode) {
        selectedMode = mode
        Task { await tv.setMouseCursorVisible(mode == .mouse) }
    }

    private var stateColor: Color {
        switch tv.connectionState {
        case .disconnected: return .gray
        case .connecting:   return .orange
        case .connected:    return .green
        case .error:        return .red
        }
    }

    // MARK: - Panel switcher

    @ViewBuilder
    private var panelContent: some View {
        switch selectedMode {
        case .remote:    remoteContent
        case .shortcuts: WheelView().environmentObject(tv)
        case .mouse:
            MouseRemoteView(onExitMode: { selectMode(.remote) })
                .environmentObject(tv)
        }
    }

    var remoteContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            powerRow
            HStack(alignment: .top, spacing: 8) {
                leftSection
                rightSection
            }
        }
        .padding(15)
        .background(Color.innerBg)
    }

    // MARK: - Power row

    var powerRow: some View {
        HStack(alignment: .top, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                CircleBtn(
                    label: "PWR", code: K.POWER, diameter: 54,
                    fill: Color("#c72b24"), textFill: .white,
                    outline: Color("#6a201d"), activeFill: Color("#ab241e"),
                    fontSize: 12
                )
                SkinBtn(
                    label: "MUTE", code: K.MUTE,
                    width: 76, height: 34,
                    bg: .lightBg, fg: .lightFg,
                    border: .lightBorder, activeBg: .lightActiveBg
                )
                .padding(.leading, 15)
                .padding(.top, 10)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("LG")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.logoFg)
                Text("Windows Port")
                    .font(.system(size: 12))
                    .foregroundColor(.captionFg)
            }
            .padding(.top, 4)
        }
        .padding(.bottom, 20)
    }
}
