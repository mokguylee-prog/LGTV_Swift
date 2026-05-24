import SwiftUI

// MARK: - V2: Circular dial wheel

struct DialWheelControl: View {
    let label:   String
    let upKey:   LGKey
    let downKey: LGKey

    @EnvironmentObject var tv: TVController
    @State private var angleDeg:  Double  = 0
    @State private var lastTrans: CGFloat = 0
    @State private var pending:   CGFloat = 0
    @State private var flashText  = ""
    @State private var flashOp:   Double  = 0
    @State private var scrollAcc: CGFloat = 0
    @State private var velWin: [(v: CGFloat, t: Date)] = []

    private let basePx: CGFloat = 18
    private let minPx:  CGFloat = 4

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chevron.up")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(white: 0.38))

            DialShape(angleDeg: angleDeg)
                .frame(width: 150, height: 150)
                .gesture(drag)
                .overlay(ScrollWheelCatcher(onScroll: scroll))
                .overlay(
                    Text(flashText)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Color(white: 1).opacity(flashOp))
                        .allowsHitTesting(false)
                )

            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(white: 0.38))

            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(white: 0.58))
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let d  = v.translation.height - lastTrans
                lastTrans = v.translation.height

                let now = Date()
                let dt  = max(velWin.last.map { CGFloat(now.timeIntervalSince($0.t)) } ?? 0.016, 0.001)
                if d != 0 {
                    velWin.append((v: d / dt, t: now))
                    velWin.removeAll { now.timeIntervalSince($0.t) > 0.08 }
                }

                let sp = basePx - (basePx - minPx) * min(abs(velWin.last?.v ?? 0) / 600, 1.0)
                angleDeg += Double(d) * 0.8
                pending  += d

                while pending <= -sp { pending += sp; flash("+"); Task { await tv.sendKey(upKey) } }
                while pending >= sp  { pending -= sp; flash("−"); Task { await tv.sendKey(downKey) } }
            }
            .onEnded { _ in lastTrans = 0; pending = 0; velWin.removeAll() }
    }

    private func flash(_ s: String) {
        flashText = s
        withAnimation(.easeIn(duration: 0.04))              { flashOp = 0.85 }
        withAnimation(.easeOut(duration: 0.40).delay(0.04)) { flashOp = 0 }
    }

    private func scroll(_ d: CGFloat) {
        scrollAcc += d
        while scrollAcc >= 5  { scrollAcc -= 5; angleDeg -= 15; flash("+"); Task { await tv.sendKey(upKey) } }
        while scrollAcc <= -5 { scrollAcc += 5; angleDeg += 15; flash("−"); Task { await tv.sendKey(downKey) } }
    }
}

// MARK: - Dial shape (Canvas tick marks)

private struct DialShape: View {
    let angleDeg: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(stops: [
                    .init(color: Color(white: 0.30), location: 0),
                    .init(color: Color(white: 0.16), location: 1),
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().stroke(Color(white: 0.42), lineWidth: 1.5)

            GeometryReader { geo in
                let rr = geo.size.width / 2
                Canvas { ctx, _ in
                    for i in 0..<36 {
                        let a   = (Double(i) / 36) * 360 + angleDeg
                        let rad = a * Double.pi / 180
                        let maj = i % 9 == 0
                        let inn: CGFloat = maj ? rr * 0.72 : rr * 0.82
                        var p = Path()
                        p.move(to:    CGPoint(x: rr + cos(rad) * inn,       y: rr + sin(rad) * inn))
                        p.addLine(to: CGPoint(x: rr + cos(rad) * rr * 0.94, y: rr + sin(rad) * rr * 0.94))
                        ctx.stroke(p, with: .color(Color(white: maj ? 0.65 : 0.38)),
                                   lineWidth: maj ? 2 : 1)
                    }
                }
            }
            .clipShape(Circle())

            Circle()
                .fill(LinearGradient(stops: [
                    .init(color: Color(white: 0.22), location: 0),
                    .init(color: Color(white: 0.10), location: 1),
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(14)

            Capsule()
                .fill(Color(red: 0.30, green: 0.60, blue: 1.00))
                .frame(width: 3, height: 34)
                .offset(y: -24)
                .rotationEffect(.degrees(angleDeg))

            Circle()
                .fill(Color(white: 0.28))
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(Color(white: 0.50), lineWidth: 1))
        }
    }
}
