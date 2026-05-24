import SwiftUI

// MARK: - SummaryBadge

struct SummaryBadge: View {
    let icon:  String
    let text:  String
    let color: Color

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption2).fontWeight(.semibold)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(color.opacity(0.13))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

// MARK: - ScanStepRow

enum StepState { case waiting, running, done }

struct ScanStepRow: View {
    let icon:   String
    let label:  String
    let detail: String
    let state:  StepState

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(bgColor).frame(width: 28, height: 28)
                if state == .running {
                    ProgressView().controlSize(.mini).scaleEffect(0.8)
                } else {
                    Image(systemName: state == .done ? "checkmark" : icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(fgColor)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption).fontWeight(.medium)
                    .foregroundColor(state == .waiting ? .secondary : .primary)
                Text(detail)
                    .font(.caption2).foregroundColor(.secondary).monospacedDigit()
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
    let device:     TVDevice
    let isSelected: Bool
    let onSelect:   () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(iconBg).frame(width: 36, height: 36)
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
                            .font(.caption).foregroundColor(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                Text(badgeLabel)
                    .font(.caption2).fontWeight(.semibold)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(badgeBg).foregroundColor(badgeFg)
                    .clipShape(Capsule())
                Image(systemName: "checkmark.circle.fill")
                    .font(.body).foregroundColor(.accentColor)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
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
        s = s.replacingOccurrences(of: "[후보 기기]",  with: "")
        s = s.replacingOccurrences(of: "LG NetCast",  with: "")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
