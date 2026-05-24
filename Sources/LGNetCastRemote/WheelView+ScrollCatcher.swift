import SwiftUI
import AppKit

// MARK: - ScrollWheelCatcher
// NSViewRepresentable that forwards scroll-wheel delta to a Swift closure.

struct ScrollWheelCatcher: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> CV {
        let v = CV(); v.cb = onScroll; return v
    }

    func updateNSView(_ n: CV, context: Context) { n.cb = onScroll }

    final class CV: NSView {
        var cb: (CGFloat) -> Void = { _ in }
        override func scrollWheel(with e: NSEvent) {
            let d = e.scrollingDeltaY
            if abs(d) > 0.1 { cb(d) }
        }
    }
}
