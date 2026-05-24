import SwiftUI

// MARK: - Scan progress view

struct ScanProgressView: View {
    @EnvironmentObject var tv: TVController
    @Binding var isPortLogExpanded: Bool

    var body: some View {
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

            if !tv.portLog.isEmpty {
                PortLogView(isExpanded: $isPortLogExpanded)
                    .layoutPriority(1)
            }
        }
        .padding(.vertical, 6)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Port log view

struct PortLogView: View {
    @EnvironmentObject var tv: TVController
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Label("IP 스캔", systemImage: "list.bullet")
                    .font(.caption2).foregroundColor(.secondary)
                Spacer()
                Text("\(tv.portScanned) / \(tv.portTotal)")
                    .font(.caption2).foregroundColor(.secondary).monospacedDigit()
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help(isExpanded ? "IP 목록 줄이기" : "IP 목록 늘리기")
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
                                Spacer(minLength: 8)
                                Text(entry.open ? "열림" : "닫힘")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(entry.open ? .green : .secondary)
                            }
                            .id(idx)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .frame(
                    minHeight: isExpanded ? 220 : 58,
                    maxHeight: isExpanded ? .infinity : 58
                )
                .background(Color.black.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onChange(of: tv.portLog.count) { _ in
                    if let last = tv.portLog.indices.last {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
            .layoutPriority(1)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onChange(of: tv.isScanning) { scanning in
            if scanning { isExpanded = true }
        }
    }
}
