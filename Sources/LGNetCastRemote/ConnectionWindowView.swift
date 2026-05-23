import SwiftUI

struct ConnectionWindowView: View {
    @EnvironmentObject var tv: TVController
    @State private var isPortLogExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            ipRow
            Divider()
            deviceList
            Divider()
            pinRow
            Divider()
            statusBar
        }
        .frame(width: 400)
    }

    // MARK: - IP row

    private var ipRow: some View {
        HStack(spacing: 8) {
            Label("TV IP", systemImage: "network")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 54, alignment: .leading)
            TextField("예: 192.168.1.100", text: $tv.tvIP)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            Button {
                Task { await tv.discover() }
            } label: {
                if tv.isScanning {
                    ProgressView().controlSize(.small).frame(width: 60)
                } else {
                    Label("검색", systemImage: "magnifyingglass").frame(width: 60)
                }
            }
            .disabled(tv.isScanning)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Device list

    private var deviceList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("발견된 기기")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
                if !tv.isScanning, !tv.discoveredDevices.isEmpty {
                    deviceSummary
                }
            }

            if tv.isScanning {
                scanProgressView
            } else if tv.discoveredDevices.isEmpty {
                Text("검색 버튼을 눌러 TV를 찾으세요")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(tv.discoveredDevices) { device in
                            DeviceRow(device: device, isSelected: device.ip == tv.tvIP) {
                                tv.selectDevice(device)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 180)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var deviceSummary: some View {
        HStack(spacing: 6) {
            SummaryBadge(
                icon: "tv.fill",
                text: "TV \(deviceCount(.lgTV))",
                color: .green
            )
            SummaryBadge(
                icon: "printer.fill",
                text: "프린터 \(deviceCount(.printer))",
                color: .orange
            )
            if deviceCount(.unknown) > 0 {
                SummaryBadge(
                    icon: "questionmark.circle",
                    text: "후보 \(deviceCount(.unknown))",
                    color: .secondary
                )
            }
        }
    }

    private func deviceCount(_ kind: DeviceKind) -> Int {
        tv.discoveredDevices.filter { $0.kind == kind }.count
    }

    // MARK: - Scan progress

    private var scanProgressView: some View {
        let portDone     = tv.portTotal > 0 && tv.portScanned >= tv.portTotal
        let verifyActive = portDone && tv.verifyTotal > 0

        return VStack(alignment: .leading, spacing: 6) {
            ScanStepRow(
                icon: "antenna.radiowaves.left.and.right",
                label: "SSDP 검색",
                detail: tv.ssdpDone ? "완료" : "멀티캐스트 + 브로드캐스트",
                state: tv.ssdpDone ? .done : .running
            )
            ScanStepRow(
                icon: "network",
                label: "포트 스캔",
                detail: tv.portTotal > 0 ? "\(tv.portScanned) / \(tv.portTotal)" : "준비 중...",
                state: portDone ? .done : (tv.portTotal > 0 ? .running : .waiting)
            )
            ScanStepRow(
                icon: "shield.lefthalf.filled",
                label: "기기 확인",
                detail: verifyActive ? "\(tv.verifyDone) / \(tv.verifyTotal)" : "대기 중...",
                state: verifyActive ? .running : .waiting
            )

            // IP 스캔 로그
            if !tv.portLog.isEmpty {
                portLogView
            }
        }
        .padding(.vertical, 6)
    }

    private var portLogView: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Label("IP 스캔", systemImage: "list.bullet")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(tv.portScanned) / \(tv.portTotal)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isPortLogExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isPortLogExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help(isPortLogExpanded ? "IP 목록 줄이기" : "IP 목록 늘리기")
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(tv.portLog.enumerated()), id: \.offset) { idx, entry in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(entry.open ? Color.green : Color.secondary.opacity(0.3))
                                    .frame(width: 5, height: 5)
                                Text(entry.ip)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(entry.open ? .green : .secondary)
                                if entry.open {
                                    Text("응답")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.green)
                                }
                            }
                            .id(idx)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .frame(height: isPortLogExpanded ? 180 : 58)
                .background(Color.black.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onChange(of: tv.portLog.count) { _ in
                    if let last = tv.portLog.indices.last {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
        }
    }

    // MARK: - PIN row

    private var pinRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Label("PIN", systemImage: "key.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 54, alignment: .leading)
                SecureField("PIN 입력", text: $tv.pin)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Button("PIN 요청") {
                    Task { await tv.requestPIN() }
                }
                .controlSize(.small)
                .frame(width: 70)
                .help("TV 화면에 PIN을 표시합니다")
            }

            Button {
                Task { await tv.connect() }
            } label: {
                HStack {
                    Spacer()
                    if case .connecting = tv.connectionState {
                        ProgressView().controlSize(.small)
                        Text("연결 중...")
                    } else {
                        Image(systemName: tv.connectionState.isConnected
                              ? "checkmark.circle.fill" : "powerplug.fill")
                        Text(tv.connectionState.isConnected ? "재연결" : "연결")
                    }
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(tv.tvIP.isEmpty || tv.pin.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(stateColor)
                .frame(width: 7, height: 7)
            Text(tv.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    private var stateColor: Color {
        switch tv.connectionState {
        case .disconnected: return .gray
        case .connecting:   return .orange
        case .connected:    return .green
        case .error:        return .red
        }
    }
}

// MARK: - DeviceRow

private struct SummaryBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.13))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

// MARK: - ScanStepRow

private enum StepState { case waiting, running, done }

private struct ScanStepRow: View {
    let icon: String
    let label: String
    let detail: String
    let state: StepState

    var body: some View {
        HStack(spacing: 10) {
            // 상태 아이콘
            ZStack {
                Circle()
                    .fill(bgColor)
                    .frame(width: 28, height: 28)
                if state == .running {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: state == .done ? "checkmark" : icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(fgColor)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(state == .waiting ? .secondary : .primary)
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: state == .done)
    }

    private var bgColor: Color {
        switch state {
        case .waiting: return Color.secondary.opacity(0.08)
        case .running: return Color.accentColor.opacity(0.12)
        case .done:    return Color.green.opacity(0.12)
        }
    }

    private var fgColor: Color {
        switch state {
        case .waiting: return .secondary
        case .running: return .accentColor
        case .done:    return .green
        }
    }
}

// MARK: - DeviceRow

struct DeviceRow: View {
    let device: TVDevice
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(iconBg)
                        .frame(width: 36, height: 36)
                    Image(systemName: iconName)
                        .font(.system(size: 16))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.ip)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                    if !deviceLabel.isEmpty {
                        Text(deviceLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(badgeLabel)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(badgeBg)
                    .foregroundColor(badgeFg)
                    .clipShape(Capsule())

                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundColor(.accentColor)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isSelected
                          ? Color.accentColor.opacity(0.1)
                          : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }

    private var iconName: String {
        switch device.kind {
        case .lgTV:    return "tv.fill"
        case .printer: return "printer.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    private var iconBg: Color {
        switch device.kind {
        case .lgTV:    return Color.accentColor.opacity(0.12)
        case .printer: return Color.orange.opacity(0.12)
        case .unknown: return Color.secondary.opacity(0.08)
        }
    }

    private var iconColor: Color {
        switch device.kind {
        case .lgTV:    return .accentColor
        case .printer: return .orange
        case .unknown: return .secondary
        }
    }

    private var badgeLabel: String {
        switch device.kind {
        case .lgTV:    return "LG TV"
        case .printer: return "프린터"
        case .unknown: return "후보"
        }
    }

    private var badgeBg: Color {
        switch device.kind {
        case .lgTV:    return Color.green.opacity(0.15)
        case .printer: return Color.orange.opacity(0.15)
        case .unknown: return Color.secondary.opacity(0.12)
        }
    }

    private var badgeFg: Color {
        switch device.kind {
        case .lgTV:    return .green
        case .printer: return .orange
        case .unknown: return .secondary
        }
    }

    private var deviceLabel: String {
        var s = device.name
        if s.hasPrefix(device.ip) { s = String(s.dropFirst(device.ip.count)) }
        s = s.replacingOccurrences(of: "[LG TV 확인]", with: "")
        s = s.replacingOccurrences(of: "[후보 기기]", with: "")
        s = s.replacingOccurrences(of: "LG NetCast", with: "")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
