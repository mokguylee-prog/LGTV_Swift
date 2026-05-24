import SwiftUI
import AppKit
import CoreGraphics

// MARK: - MouseTrackingPad (NSViewRepresentable)

struct MouseTrackingPad: NSViewRepresentable {
    let onMove:   (CGFloat, CGFloat) -> Void
    let onClick:  () -> Void
    let onScroll: (CGFloat) -> Void
    let onExit:   () -> Void

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
}

// MARK: - TrackingView (NSView subclass)

final class TrackingView: NSView {
    var onMove:   (CGFloat, CGFloat) -> Void = { _, _ in }
    var onClick:  () -> Void = {}
    var onScroll: (CGFloat) -> Void = { _ in }
    var onExit:   () -> Void = {}

    private var trackingArea: NSTrackingArea?
    private var prevTVPos: CGPoint? = nil
    private var isInside = false

    // Fixed TV resolution
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
            .mouseEnteredAndExited,
        ]
        let area = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
        super.updateTrackingAreas()
    }

    // MARK: - Pad → TV coordinate mapping
    // NSView Y=0 at bottom; TV Y=0 at top → invert with (1 - y/h)

    private func tvPosition(for event: NSEvent) -> CGPoint {
        let p = convert(event.locationInWindow, from: nil)
        let w = max(bounds.width, 1)
        let h = max(bounds.height, 1)
        return CGPoint(x: (p.x / w) * tvW,
                       y: (1.0 - p.y / h) * tvH)
    }

    // MARK: - Warp PC cursor to pad centre

    private func warpToPadCenter() {
        guard let win = window else { return }
        let center      = NSPoint(x: bounds.midX, y: bounds.midY)
        let winPoint    = convert(center, to: nil)
        let screenPoint = win.convertToScreen(NSRect(origin: winPoint, size: .zero)).origin
        let primaryMaxY = NSScreen.screens.first?.frame.maxY ?? NSScreen.main?.frame.height ?? 0
        let cgPoint     = CGPoint(x: screenPoint.x, y: primaryMaxY - screenPoint.y)
        CGWarpMouseCursorPosition(cgPoint)
        prevTVPos = CGPoint(x: tvW / 2, y: tvH / 2)
    }

    // MARK: - Events

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
            let dx = cur.x - prev.x, dy = cur.y - prev.y
            if dx != 0 || dy != 0 { onMove(dx, dy) }
        }
        prevTVPos = cur
    }

    override func mouseDragged(with event: NSEvent) {
        guard isInside else { return }
        let cur = tvPosition(for: event)
        if let prev = prevTVPos {
            let dx = cur.x - prev.x, dy = cur.y - prev.y
            if dx != 0 || dy != 0 { onMove(dx, dy) }
        }
        prevTVPos = cur
    }

    // Left click: warp PC cursor → send TV click
    override func mouseDown(with event: NSEvent) {
        warpToPadCenter(); onClick()
    }

    // Right click: warp PC cursor only (no TV click)
    override func rightMouseDown(with event: NSEvent) {
        warpToPadCenter()
    }

    // Middle button: exit mouse pad mode
    override func otherMouseDown(with event: NSEvent) {
        DispatchQueue.main.async { self.onExit() }
    }

    override func scrollWheel(with event: NSEvent) {
        onScroll(event.scrollingDeltaY)
    }
}
