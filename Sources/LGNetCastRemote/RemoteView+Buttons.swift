import SwiftUI

// MARK: - SkinBtn

struct SkinBtn: View {
    let label:    String
    let code:     Int
    let width:    CGFloat
    let height:   CGFloat
    let bg:       Color
    let fg:       Color
    let border:   Color
    let activeBg: Color
    var fontSize: CGFloat = 10
    var radius:   CGFloat = 4

    @EnvironmentObject var tv: TVController
    @State private var hovered = false

    var body: some View {
        Button { Task { await tv.sendKeyCode(code) } } label: {
            Text(label)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(fg)
                .frame(width: width - 2, height: height - 2)
                .background(hovered ? activeBg : bg)
                .clipShape(RoundedRectangle(cornerRadius: max(radius - 1, 0)))
        }
        .buttonStyle(.plain)
        .frame(width: width, height: height)
        .background(border)
        .clipShape(RoundedRectangle(cornerRadius: radius))
        .onHover { hovered = $0 }
    }
}

// MARK: - CircleBtn

struct CircleBtn: View {
    let label:      String
    let code:       Int
    let diameter:   CGFloat
    let fill:       Color
    let textFill:   Color
    let outline:    Color
    let activeFill: Color
    var fontSize:   CGFloat = 11

    @EnvironmentObject var tv: TVController
    @State private var hovered = false

    var body: some View {
        Button { Task { await tv.sendKeyCode(code) } } label: {
            ZStack {
                Circle()
                    .fill(hovered ? activeFill : fill)
                    .overlay(Circle().stroke(outline, lineWidth: 1))
                    .frame(width: diameter - 4, height: diameter - 4)
                Text(label)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(textFill)
            }
        }
        .buttonStyle(.plain)
        .frame(width: diameter, height: diameter)
        .onHover { hovered = $0 }
    }
}

// MARK: - RemoteModeButton

struct RemoteModeButton: View {
    let title:       String
    let systemImage: String
    let isSelected:  Bool
    let action:      () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(isSelected
                            ? Color.accentColor.opacity(0.18)
                            : Color.primary.opacity(0.06))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Spacer helper

func gap(_ w: CGFloat) -> some View { Color.clear.frame(width: w) }
