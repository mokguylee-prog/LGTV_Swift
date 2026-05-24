import SwiftUI

// MARK: - V1: Cylinder trim-wheel with inertia

struct CylinderWheelControl: View {
    let label:    String
    let upKey:    LGKey
    let downKey:  LGKey
    let friction: CGFloat

    @EnvironmentObject var tv: TVController

    @State private var wheelOffset: CGFloat = 0
    @State private var flashText:   String  = ""
    @State private var flashOp:     Double  = 0

    @State private var lastDragY:   CGFloat = 0
    @State private var pendingKeys: CGFloat = 0
    @State private var posWin: [(y: CGFloat, t: Date)] = []

    @State private var scrollAcc: CGFloat = 0
    @State private var coastTask: Task<Void, Never>? = nil

    private let basePx: CGFloat = 22

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chevron.up")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(white: 0.38))

            TrimWheelBody(stripeOffset: wheelOffset)
                .frame(width: 118, height: 220)
                .gesture(drag)
                .overlay(ScrollWheelCatcher(onScroll: handleScroll))
                .overlay(
                    Text(flashText)
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundColor(Color(white: 1).opacity(flashOp))
                        .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
                        .allowsHitTesting(false)
                )

            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(white: 0.38))

            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(white: 0.58))
        }
        .onDisappear { coastTask?.cancel() }
    }

    // MARK: Drag gesture

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                coastTask?.cancel(); coastTask = nil

                let delta = v.translation.height - lastDragY
                lastDragY = v.translation.height
                wheelOffset += delta
                pendingKeys += delta

                while pendingKeys <= -basePx { pendingKeys += basePx; flash("+"); Task { await tv.sendKey(upKey) } }
                while pendingKeys >= basePx  { pendingKeys -= basePx; flash("−"); Task { await tv.sendKey(downKey) } }

                let now = Date()
                posWin.append((y: v.translation.height, t: now))
                posWin.removeAll { now.timeIntervalSince($0.t) > 0.12 }
            }
            .onEnded { _ in
                lastDragY   = 0
                pendingKeys = 0

                let now    = Date()
                let recent = posWin.filter { now.timeIntervalSince($0.t) <= 0.08 }
                let win    = recent.count >= 2 ? recent : posWin

                let vel: CGFloat
                if win.count >= 2, let first = win.first, let last = win.last {
                    let dt = CGFloat(last.t.timeIntervalSince(first.t))
                    vel = dt > 0.001 ? (last.y - first.y) / dt : 0
                } else { vel = 0 }
                posWin.removeAll()
                startCoast(velocity: vel, fr: friction)
            }
    }

    // MARK: Inertia loop

    private func startCoast(velocity: CGFloat, fr: CGFloat) {
        guard abs(velocity) > 5 else { return }
        coastTask = Task { @MainActor in
            var vel      = velocity
            var keyAccum = CGFloat(0)
            var lastTime = Date.now

            while !Task.isCancelled && abs(vel) > 0.5 {
                try? await Task.sleep(nanoseconds: 16_666_000)
                guard !Task.isCancelled else { break }

                let now  = Date.now
                let dt   = CGFloat(now.timeIntervalSince(lastTime))
                lastTime = now
                guard dt > 0.001 && dt < 0.1 else { continue }

                let decay = CGFloat(pow(Double(fr), Double(dt * 60.0)))
                let dist  = vel * dt

                wheelOffset += dist
                keyAccum    += dist

                while keyAccum <= -basePx { keyAccum += basePx; Task { await tv.sendKey(upKey) } }
                while keyAccum >= basePx  { keyAccum -= basePx; Task { await tv.sendKey(downKey) } }

                vel *= decay
            }
        }
    }

    // MARK: Scroll wheel

    private func handleScroll(_ delta: CGFloat) {
        coastTask?.cancel(); coastTask = nil
        scrollAcc += delta
        while scrollAcc >= 5  { scrollAcc -= 5; wheelOffset -= 15; flash("+"); Task { await tv.sendKey(upKey) } }
        while scrollAcc <= -5 { scrollAcc += 5; wheelOffset += 15; flash("−"); Task { await tv.sendKey(downKey) } }
    }

    private func flash(_ sign: String) {
        flashText = sign
        withAnimation(.easeIn(duration: 0.04))              { flashOp = 0.85 }
        withAnimation(.easeOut(duration: 0.40).delay(0.04)) { flashOp = 0 }
    }
}

// MARK: - Trim wheel body (Canvas-drawn ridges)

private struct TrimWheelBody: View {
    let stripeOffset: CGFloat
    private let r: CGFloat = 3

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: r)
                .fill(LinearGradient(stops: [
                    .init(color: Color(white: 0.05), location: 0.00),
                    .init(color: Color(white: 0.70), location: 0.12),
                    .init(color: Color(white: 0.38), location: 0.22),
                    .init(color: Color(white: 0.14), location: 0.42),
                    .init(color: Color(white: 0.09), location: 0.58),
                    .init(color: Color(white: 0.20), location: 0.80),
                    .init(color: Color(white: 0.28), location: 0.92),
                    .init(color: Color(white: 0.06), location: 1.00),
                ], startPoint: .leading, endPoint: .trailing))

            Canvas { ctx, size in
                let sp   = CGFloat(19)
                let off  = stripeOffset.truncatingRemainder(dividingBy: sp)
                let half = size.height / 2
                var y    = off.truncatingRemainder(dividingBy: sp) - sp * 2
                while y < size.height + sp {
                    let d  = min(abs(y - half) / (half + 12), 1.0)
                    let cf = CGFloat(1.0 - d * 0.72)

                    let hlOp = Double(cf * 0.93)
                    if hlOp > 0.02 {
                        var p = Path(); p.move(to: CGPoint(x: 4, y: y)); p.addLine(to: CGPoint(x: size.width - 4, y: y))
                        ctx.stroke(p, with: .color(Color(white: 0.92).opacity(hlOp)), lineWidth: 3.2)
                    }
                    let midOp = Double(cf * 0.38)
                    if midOp > 0.02 {
                        var p = Path(); p.move(to: CGPoint(x: 4, y: y + 3.5)); p.addLine(to: CGPoint(x: size.width - 4, y: y + 3.5))
                        ctx.stroke(p, with: .color(Color(white: 0.40).opacity(midOp)), lineWidth: 1.8)
                    }
                    let shOp = Double(cf * 0.97)
                    if shOp > 0.02 {
                        var p = Path(); p.move(to: CGPoint(x: 4, y: y + 7.0)); p.addLine(to: CGPoint(x: size.width - 4, y: y + 7.0))
                        ctx.stroke(p, with: .color(Color.black.opacity(shOp)), lineWidth: 4.8)
                    }
                    y += sp
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: r))

            // Top / bottom fade vignette
            VStack(spacing: 0) {
                LinearGradient(colors: [Color.black.opacity(0.88), Color.black.opacity(0.28), .clear],
                               startPoint: .top, endPoint: .bottom).frame(height: 50)
                Spacer()
                LinearGradient(colors: [.clear, Color.black.opacity(0.28), Color.black.opacity(0.88)],
                               startPoint: .top, endPoint: .bottom).frame(height: 50)
            }
            .clipShape(RoundedRectangle(cornerRadius: r))

            // Left edge highlight
            HStack {
                LinearGradient(colors: [Color(white: 1.0).opacity(0.14), .clear],
                               startPoint: .leading, endPoint: .trailing).frame(width: 22)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: r))

            // Border
            RoundedRectangle(cornerRadius: r)
                .stroke(LinearGradient(
                    colors: [Color(white: 0.68), Color(white: 0.18), Color(white: 0.44)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
        }
    }
}
