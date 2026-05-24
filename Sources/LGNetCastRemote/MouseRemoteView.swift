import SwiftUI
import AppKit
import CoreGraphics

// MARK: - MouseRemoteView palette

private extension Color {
    static let mouseInnerBg   = Color("#111111")
    static let mouseEdge      = Color("#2c2c2c")
    static let mouseCaptionFg = Color("#b9b9b9")
}

// MARK: - MouseRemoteView

struct MouseRemoteView: View {
    @EnvironmentObject var tv: TVController
    var onExitMode: () -> Void = {}

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("#0b0b0b"))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.mouseEdge, lineWidth: 1))

            // Concentric ripple rings
            GeometryReader { geo in
                let cx   = geo.size.width  / 2
                let cy   = geo.size.height / 2
                let maxR = sqrt(cx * cx + cy * cy) + 16
                let count = 18

                ZStack {
                    ForEach(0..<count, id: \.self) { i in
                        let t = CGFloat(i) / CGFloat(count - 1)
                        let r = maxR * CGFloat(i + 1) / CGFloat(count)
                        let color: Color = t < 0.4
                            ? Color(red: 0.25, green: 0.55, blue: 1.00)
                            : Color(red: 0.45, green: 0.45, blue: 0.50)
                        let opacity = t < 0.4
                            ? Double(0.75 - t * 1.5)
                            : Double(0.40 - (t - 0.4) * 0.55)

                        Circle()
                            .stroke(color.opacity(opacity), lineWidth: 1.4)
                            .frame(width: r * 2, height: r * 2)
                            .position(x: cx, y: cy)
                    }
                    // Centre dot
                    Circle()
                        .fill(Color(red: 0.30, green: 0.60, blue: 1.00))
                        .frame(width: 10, height: 10)
                        .position(x: cx, y: cy)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Touch tracking layer (topmost)
            MouseTrackingPad(
                onMove:   sendMouseDelta,
                onClick:  { Task { await tv.sendMouseClick() } },
                onScroll: sendMouseWheel,
                onExit:   onExitMode
            )
        }
        .frame(width: 388, height: 430)
        .padding(15)
        .frame(width: 418)
        .background(Color.mouseInnerBg)
        .onAppear { Task { await tv.setMouseCursorVisible(true) } }
    }

    private func sendMouseDelta(_ rawX: CGFloat, _ rawY: CGFloat) {
        let dx = Int(rawX.rounded()), dy = Int(rawY.rounded())
        guard dx != 0 || dy != 0 else { return }
        Task { await tv.sendMouseMove(deltaX: dx, deltaY: dy) }
    }

    private func sendMouseWheel(_ rawY: CGFloat) {
        guard abs(rawY) >= 1 else { return }
        Task { await tv.sendMouseWheel(up: rawY > 0) }
    }
}
