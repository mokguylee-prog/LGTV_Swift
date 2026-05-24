import SwiftUI
import Combine

// MARK: - V1: Cylinder trim-wheel

struct CylinderWheelControl: View {
    let label:    String
    let upKey:    LGKey
    let downKey:  LGKey
    @Binding var friction: CGFloat     // 0.90…0.98, 슬라이더 실시간 연결

    @EnvironmentObject var tv: TVController
    @StateObject private var engine = InertiaEngine()

    // Visual
    @State private var wheelOffset: CGFloat = 0
    @State private var flashText:   String  = ""
    @State private var flashOp:     Double  = 0

    // 드래그 중 키 누적
    @State private var lastDragY:   CGFloat = 0
    @State private var pendingKeys: CGFloat = 0

    // ── 속도 측정: delta-ring (이동 중인 샘플만 수집)
    // v.velocity.height는 macOS 마우스 드래그 시 0을 반환하는 경우가 있어
    // 직접 측정한 링 버퍼를 1차, OS 값을 2차 검증으로 사용.
    @State private var velRing: [(delta: CGFloat, t: Date)] = []

    // 관성 중 키 누적
    @State private var keyAccum:  CGFloat = 0
    @State private var scrollAcc: CGFloat = 0

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
        // ── 물리 프레임: PassthroughSubject → onReceive (프레임 누락 없음)
        .onReceive(engine.tick) { dist in
            wheelOffset += dist
            keyAccum    += dist
            while keyAccum <= -basePx { keyAccum += basePx; flash("+"); Task { await tv.sendKey(upKey)   } }
            while keyAccum >=  basePx { keyAccum -= basePx; flash("−"); Task { await tv.sendKey(downKey) } }
        }
        // ── 슬라이더 변경 → 진행 중 관성에 즉시 반영
        .onReceive(Just(friction)) { fr in
            engine.setFriction(fr)
        }
        .onDisappear { engine.cancel() }
    }

    // MARK: – Drag gesture

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if engine.isRunning { engine.cancel(); keyAccum = 0 }

                let now   = Date()
                let delta = v.translation.height - lastDragY
                lastDragY = v.translation.height

                // delta-ring: 실제로 움직인 샘플만 수집 (정지 샘플 배제)
                if abs(delta) > 0.2 {
                    velRing.append((delta: delta, t: now))
                }
                // 최근 100ms만 유지
                velRing.removeAll { now.timeIntervalSince($0.t) > 0.10 }

                wheelOffset += delta
                pendingKeys += delta
                while pendingKeys <= -basePx { pendingKeys += basePx; flash("+"); Task { await tv.sendKey(upKey)   } }
                while pendingKeys >=  basePx { pendingKeys -= basePx; flash("−"); Task { await tv.sendKey(downKey) } }
            }
            .onEnded { v in
                // ── 속도 계산 (1차: delta-ring, 2차: OS velocity)
                var vel: CGFloat = 0

                // 1차: 링 버퍼 — 이동 샘플만 포함, 정지 직전 이벤트 영향 없음
                if velRing.count >= 2,
                   let first = velRing.first, let last = velRing.last {
                    let span = CGFloat(last.t.timeIntervalSince(first.t))
                    if span > 0.001 {
                        let totalDelta = velRing.reduce(CGFloat(0)) { $0 + $1.delta }
                        vel = totalDelta / span
                    }
                } else if velRing.count == 1 {
                    // 단 하나의 샘플: 해당 delta를 짧은 시간 기준으로 추정
                    vel = velRing[0].delta / 0.008   // ~8ms 이벤트 간격 가정
                }

                // 2차: OS velocity — 링 버퍼보다 크면 OS 값 채택 (정밀할 경우 우선)
                if #available(macOS 14, *) {
                    let osVel = v.velocity.height
                    if abs(osVel) > abs(vel) { vel = osVel }
                }

                // 리셋
                keyAccum    = 0
                pendingKeys = 0
                lastDragY   = 0
                velRing.removeAll()

                engine.kick(velocity: vel, friction: friction)
            }
    }

    // MARK: – Mouse scroll wheel

    private func handleScroll(_ d: CGFloat) {
        engine.cancel()
        scrollAcc += d
        while scrollAcc >=  5 { scrollAcc -= 5; wheelOffset -= 15; flash("+"); Task { await tv.sendKey(upKey)   } }
        while scrollAcc <= -5 { scrollAcc += 5; wheelOffset += 15; flash("−"); Task { await tv.sendKey(downKey) } }
    }

    // MARK: – Flash

    private func flash(_ sign: String) {
        flashText = sign
        withAnimation(.easeIn(duration: 0.04))              { flashOp = 0.85 }
        withAnimation(.easeOut(duration: 0.40).delay(0.04)) { flashOp = 0 }
    }
}

// MARK: - Trim wheel body (Canvas ridges)

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
                    if cf * 0.93 > 0.02 {
                        var p = Path(); p.move(to: .init(x: 4, y: y)); p.addLine(to: .init(x: size.width-4, y: y))
                        ctx.stroke(p, with: .color(Color(white: 0.92).opacity(Double(cf*0.93))), lineWidth: 3.2)
                    }
                    if cf * 0.38 > 0.02 {
                        var p = Path(); p.move(to: .init(x: 4, y: y+3.5)); p.addLine(to: .init(x: size.width-4, y: y+3.5))
                        ctx.stroke(p, with: .color(Color(white: 0.40).opacity(Double(cf*0.38))), lineWidth: 1.8)
                    }
                    if cf * 0.97 > 0.02 {
                        var p = Path(); p.move(to: .init(x: 4, y: y+7.0)); p.addLine(to: .init(x: size.width-4, y: y+7.0))
                        ctx.stroke(p, with: .color(Color.black.opacity(Double(cf*0.97))), lineWidth: 4.8)
                    }
                    y += sp
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: r))

            VStack(spacing: 0) {
                LinearGradient(colors: [Color.black.opacity(0.88), Color.black.opacity(0.28), .clear],
                               startPoint: .top, endPoint: .bottom).frame(height: 50)
                Spacer()
                LinearGradient(colors: [.clear, Color.black.opacity(0.28), Color.black.opacity(0.88)],
                               startPoint: .top, endPoint: .bottom).frame(height: 50)
            }
            .clipShape(RoundedRectangle(cornerRadius: r))

            HStack {
                LinearGradient(colors: [Color(white: 1.0).opacity(0.14), .clear],
                               startPoint: .leading, endPoint: .trailing).frame(width: 22)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: r))

            RoundedRectangle(cornerRadius: r)
                .stroke(LinearGradient(
                    colors: [Color(white: 0.68), Color(white: 0.18), Color(white: 0.44)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
        }
    }
}
