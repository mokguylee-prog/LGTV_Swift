import SwiftUI

// MARK: - ConnectionWindowView

struct ConnectionWindowView: View {
    @EnvironmentObject var tv: TVController
    @State private var isPortLogExpanded = true

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
        .frame(
            minWidth:   400, idealWidth:  500, maxWidth:  .infinity,
            minHeight:  420, idealHeight: 560, maxHeight: .infinity
        )
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
                isPortLogExpanded = true
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
                    .font(.caption).fontWeight(.medium).foregroundColor(.secondary)
                Spacer()
                if !tv.isScanning, !tv.discoveredDevices.isEmpty {
                    deviceSummary
                }
            }

            if tv.isScanning {
                ScanProgressView(isPortLogExpanded: $isPortLogExpanded)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else if tv.discoveredDevices.isEmpty {
                Text("검색 버튼을 눌러 TV를 찾으세요")
                    .font(.caption).foregroundColor(.secondary)
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
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var deviceSummary: some View {
        HStack(spacing: 6) {
            SummaryBadge(icon: "tv.fill",       text: "TV \(deviceCount(.lgTV))",          color: .green)
            SummaryBadge(icon: "printer.fill",  text: "프린터 \(deviceCount(.printer))",    color: .orange)
            if deviceCount(.unknown) > 0 {
                SummaryBadge(icon: "questionmark.circle",
                             text: "후보 \(deviceCount(.unknown))", color: .secondary)
            }
        }
    }

    private func deviceCount(_ kind: DeviceKind) -> Int {
        tv.discoveredDevices.filter { $0.kind == kind }.count
    }

    // MARK: - PIN row

    private var pinRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Label("PIN", systemImage: "key.fill")
                    .font(.caption).foregroundColor(.secondary)
                    .frame(width: 54, alignment: .leading)
                SecureField("PIN 입력", text: $tv.pin)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Button("PIN 요청") { Task { await tv.requestPIN() } }
                    .controlSize(.small).frame(width: 70)
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
            Circle().fill(stateColor).frame(width: 7, height: 7)
            Text(tv.statusMessage)
                .font(.caption).foregroundColor(.secondary).lineLimit(1)
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
