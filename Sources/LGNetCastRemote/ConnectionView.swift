import SwiftUI

/// Connection setup panel — IP entry, PIN request, and device scan results.
struct ConnectionView: View {
    @EnvironmentObject var tv: TVController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // IP row
            HStack {
                Label("TV IP", systemImage: "network")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)
                TextField("예: 192.168.1.100", text: $tv.tvIP)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Button {
                    Task { await tv.discover() }
                } label: {
                    if tv.isScanning {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("검색", systemImage: "magnifyingglass")
                    }
                }
                .disabled(tv.isScanning)
                .controlSize(.small)
            }

            // Discovered devices list
            if !tv.discoveredDevices.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("발견된 기기")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    ForEach(tv.discoveredDevices) { device in
                        Button {
                            tv.selectDevice(device)
                        } label: {
                            HStack {
                                Image(systemName: device.verified ? "tv.fill" : "questionmark.circle")
                                    .foregroundColor(device.verified ? .accentColor : .secondary)
                                    .frame(width: 16)
                                Text(device.name)
                                    .font(.caption)
                                Spacer()
                                if device.ip == tv.tvIP {
                                    Image(systemName: "checkmark")
                                        .font(.caption2)
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(4)
                            .background(device.ip == tv.tvIP ? Color.accentColor.opacity(0.1) : Color.clear)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(6)
            }

            Divider()

            // PIN row
            HStack {
                Label("PIN", systemImage: "key.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)
                SecureField("PIN 입력", text: $tv.pin)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Button("PIN 요청") {
                    Task { await tv.requestPIN() }
                }
                .controlSize(.small)
                .help("TV 화면에 PIN을 표시합니다")
            }

            // Connect button
            Button {
                Task { await tv.connect() }
            } label: {
                HStack {
                    Spacer()
                    if case .connecting = tv.connectionState {
                        ProgressView().controlSize(.small)
                        Text("연결 중...")
                    } else {
                        Image(systemName: tv.connectionState.isConnected ? "checkmark.circle.fill" : "plug.fill")
                        Text(tv.connectionState.isConnected ? "재연결" : "연결")
                    }
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(tv.tvIP.isEmpty || tv.pin.isEmpty)

            // Status message
            HStack {
                Circle()
                    .fill(stateColor)
                    .frame(width: 7, height: 7)
                Text(tv.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
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
