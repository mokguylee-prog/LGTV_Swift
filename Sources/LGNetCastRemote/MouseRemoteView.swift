import SwiftUI
import AppKit
import CoreGraphics

private extension Color {
    init(_ hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(
            red:   Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8)  & 0xFF) / 255,
            blue:  Double( v        & 0xFF) / 255
        )
    }

    static let mouseInnerBg   = Color("#111111")
    static let mouseEdge      = Color("#2c2c2c")
    static let mouseCaptionFg = Color("#b9b9b9")
}

struct MouseRemoteView: View {
    @EnvironmentObject var tv: TVController
    var onExitMode: () -> Void = {}   // 마우스 패드 모드 해제 콜백

    var body: some View {
        ZStack {
            // 배경
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("#0b0b0b"))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.mouseEdge, lineWidth: 1))

            // 동심원 물결 — 파란색(중앙) → 회색(외곽)으로 퍼져나가며 사각형을 채움
            GeometryReader { geo in
                let cx = geo.size.width  / 2
                let cy = geo.size.height / 2
                // 코너까지의 거리 + 여유분 → 원이 사각형을 완전히 채우도록
                let maxR = sqrt(cx * cx + cy * cy) + 16
                let count = 18

                ZStack {
                    ForEach(0..<count, id: \.self) { i in
                        let t = CGFloat(i) / CGFloat(count - 1)   // 0=안쪽, 1=바깥쪽
                        let r = maxR * CGFloat(i + 1) / CGFloat(count)
                        let color: Color = t < 0.4
                            ? Color(red: 0.25, green: 0.55, blue: 1.00)   // 파란색 계열
                            : Color(red: 0.45, green: 0.45, blue: 0.50)   // 회색 계열
                        let opacity = t < 0.4
                            ? Double(0.75 - t * 1.5)
                            : Double(0.40 - (t - 0.4) * 0.55)

                        Circle()
                            .stroke(color.opacity(opacity), lineWidth: 1.4)
                            .frame(width: r * 2, height: r * 2)
                            .position(x: cx, y: cy)
                    }

                    // 중앙 점
                    Circle()
                        .fill(Color(red: 0.30, green: 0.60, blue: 1.00))
                        .frame(width: 10, height: 10)
                        .position(x: cx, y: cy)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // 터치 트래킹 레이어 (최상단)
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
        .onAppear {
            Task { await tv.setMouseCursorVisible(true) }
        }
    }

    // rawX/rawY 는 TV 픽셀 단위 델타 — 추가 스케일 없이 그대로 전송
    private func sendMouseDelta(_ rawX: CGFloat, _ rawY: CGFloat) {
        let dx = Int(rawX.rounded())
        let dy = Int(rawY.rounded())
        guard dx != 0 || dy != 0 else { return }
        Task { await tv.sendMouseMove(deltaX: dx, deltaY: dy) }
    }

    private func sendMouseWheel(_ rawY: CGFloat) {
        guard abs(rawY) >= 1 else { return }
        Task { await tv.sendMouseWheel(up: rawY > 0) }
    }
}

private struct MouseTrackingPad: NSViewRepresentable {
    let onMove:   (CGFloat, CGFloat) -> Void
    let onClick:  () -> Void
    let onScroll: (CGFloat) -> Void
    let onExit:   () -> Void          // 마우스 패드 모드 해제

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onMove   = onMove
        view.onClick  = onClick
        view.onScroll = onScroll
        view.onExit   = onExit
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.onMove   = onMove
        nsView.onClick  = onClick
        nsView.onScroll = onScroll
        nsView.onExit   = onExit
    }

    final class TrackingView: NSView {
        var onMove:   (CGFloat, CGFloat) -> Void = { _, _ in }
        var onClick:  () -> Void = {}
        var onScroll: (CGFloat) -> Void = { _ in }
        var onExit:   () -> Void = {}

        private var trackingArea: NSTrackingArea?
        private var prevTVPos: CGPoint? = nil
        private var isInside = false

        // TV 해상도 고정 (1920×1080)
        private let tvW: CGFloat = 1920
        private let tvH: CGFloat = 1080

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.acceptsMouseMovedEvents = true
            window?.makeFirstResponder(self)
        }

        override func updateTrackingAreas() {
            if let trackingArea { removeTrackingArea(trackingArea) }
            let options: NSTrackingArea.Options = [
                .activeAlways, .inVisibleRect,
                .mouseMoved, .enabledDuringMouseDrag,
                .mouseEnteredAndExited
            ]
            let area = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
            addTrackingArea(area)
            trackingArea = area
            super.updateTrackingAreas()
        }

        // MARK: - 패드 좌표 → TV 좌표 변환
        // NSView: Y=0 하단 → TV: Y=0 상단 (1.0 - y/h 로 반전)

        private func tvPosition(for event: NSEvent) -> CGPoint {
            let p = convert(event.locationInWindow, from: nil)
            let w = max(bounds.width, 1)
            let h = max(bounds.height, 1)
            return CGPoint(
                x: (p.x / w) * tvW,
                y: (1.0 - p.y / h) * tvH
            )
        }

        // MARK: - PC 커서를 패드 중앙으로 이동
        // NSView(bottom-left) → NSScreen(bottom-left) → CGDisplay(top-left) 변환

        private func warpToPadCenter() {
            guard let win = window else { return }
            let center      = NSPoint(x: bounds.midX, y: bounds.midY)
            let winPoint    = convert(center, to: nil)
            let screenPoint = win.convertToScreen(NSRect(origin: winPoint, size: .zero)).origin
            let primaryMaxY = NSScreen.screens.first?.frame.maxY ?? NSScreen.main?.frame.height ?? 0
            let cgPoint     = CGPoint(x: screenPoint.x, y: primaryMaxY - screenPoint.y)
            CGWarpMouseCursorPosition(cgPoint)
            // 워프 후 진입 위치 재초기화 (중앙 = TV 정중앙)
            prevTVPos = CGPoint(x: tvW / 2, y: tvH / 2)
        }

        // MARK: - 이벤트

        override func mouseEntered(with event: NSEvent) {
            isInside  = true
            prevTVPos = tvPosition(for: event)
        }

        override func mouseExited(with event: NSEvent) {
            isInside  = false
            prevTVPos = nil
        }

        override func mouseMoved(with event: NSEvent) {
            guard isInside else { return }
            let cur = tvPosition(for: event)
            if let prev = prevTVPos {
                let dx = cur.x - prev.x
                let dy = cur.y - prev.y
                if dx != 0 || dy != 0 { onMove(dx, dy) }
            }
            prevTVPos = cur
        }

        override func mouseDragged(with event: NSEvent) {
            guard isInside else { return }
            let cur = tvPosition(for: event)
            if let prev = prevTVPos {
                let dx = cur.x - prev.x
                let dy = cur.y - prev.y
                if dx != 0 || dy != 0 { onMove(dx, dy) }
            }
            prevTVPos = cur
        }

        // 좌클릭: PC 커서를 패드 중앙으로 → TV 클릭 전송
        override func mouseDown(with event: NSEvent) {
            warpToPadCenter()
            onClick()
        }

        // 우클릭: PC 커서를 패드 중앙으로 이동 (TV 클릭 없음)
        override func rightMouseDown(with event: NSEvent) {
            warpToPadCenter()
        }

        // 휠(중간) 버튼 클릭: 마우스 패드 모드 해제
        override func otherMouseDown(with event: NSEvent) {
            DispatchQueue.main.async { self.onExit() }
        }

        override func scrollWheel(with event: NSEvent) {
            onScroll(event.scrollingDeltaY)
        }
    }
}
