import SwiftUI

// MARK: - Hex color (local)

private extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(
            red:   Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8)  & 0xFF) / 255,
            blue:  Double( v        & 0xFF) / 255
        )
    }
}

// MARK: - WheelView

struct WheelView: View {
    @EnvironmentObject var tv: TVController
    @State private var version: Int = 1

    var body: some View {
        VStack(spacing: 0) {
            // 버전 토글
            HStack(spacing: 4) {
                ForEach([1, 2], id: \.self) { v in
                    Button("V\(v)") { withAnimation(.easeInOut(duration: 0.2)) { version = v } }
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 44, height: 24)
                        .background(version == v ? Color(white: 0.28) : Color(white: 0.14))
                        .foregroundColor(version == v ? .white : Color(white: 0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .buttonStyle(.plain)
                }
            }
            .padding(.top, 14)

            Spacer()

            if version == 1 {
                // V1: 항공 트림 휠
                HStack(spacing: 0) {
                    Spacer()
                    CylinderWheelControl(label: "소리", upKey: .volUp, downKey: .volDown)
                    Spacer()
                    CylinderWheelControl(label: "채널", upKey: .chUp,  downKey: .chDown)
                    Spacer()
                }
            } else {
                // V2: 항공 다이얼 회전판
                HStack(spacing: 0) {
                    Spacer()
                    DialWheelControl(label: "소리", upKey: .volUp, downKey: .volDown)
                    Spacer()
                    DialWheelControl(label: "채널", upKey: .chUp,  downKey: .chDown)
                    Spacer()
                }
            }

            Spacer()
        }
        .frame(width: 418, height: 560)
        .background(Color(hex: "0d0d0d"))
    }
}

// ============================================================
// MARK: - V1: 항공 트림 휠 (리얼 스타일 + 가속도)
// ============================================================

private struct CylinderWheelControl: View {
    let label: String
    let upKey:   LGKey
    let downKey: LGKey

    @EnvironmentObject var tv: TVController

    @State private var stripeOffset: CGFloat = 0
    @State private var lastTranslation: CGFloat = 0
    @State private var pendingDrag: CGFloat = 0
    @State private var flashText: String = ""
    @State private var flashOpacity: Double = 0

    // 가속도: 최근 이벤트 속도를 추적
    @State private var lastEventTime: Date = Date()
    @State private var smoothVelocity: CGFloat = 0   // px/s (EMA 평활)

    // 기본 스텝: 22px마다 키 1회. 가속 시 최소 4px까지 수축
    private let basePx: CGFloat = 22
    private let minPx:  CGFloat = 4

    var body: some View {
        VStack(spacing: 12) {
            // 위 방향 힌트
            Image(systemName: "chevron.up")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(white: 0.38))

            TrimWheelBody(stripeOffset: stripeOffset)
                .frame(width: 118, height: 220)
                .gesture(dragGesture)
                .overlay(
                    Text(flashText)
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundColor(Color(white: 1).opacity(flashOpacity))
                        .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
                        .allowsHitTesting(false)
                )

            // 아래 방향 힌트
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(white: 0.38))

            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(white: 0.58))
        }
    }

    // MARK: 드래그 + 가속도 처리

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let delta = v.translation.height - lastTranslation
                lastTranslation = v.translation.height

                // ── 속도 계산 (EMA 평활) ──────────────────────────────────
                let now = Date()
                let dt  = CGFloat(now.timeIntervalSince(lastEventTime))
                lastEventTime = now
                let instantV = dt > 0 ? abs(delta) / dt : 0
                // EMA α=0.35: 급격한 스파이크 완화, 반응성 유지
                smoothVelocity = smoothVelocity * 0.65 + instantV * 0.35

                // ── 유효 스텝 px (가속도 적용) ────────────────────────────
                // 속도 0~600 px/s → 스텝 basePx~minPx 선형 보간
                let speedRatio = min(smoothVelocity / 600, 1.0)
                let effectivePx = basePx - (basePx - minPx) * speedRatio

                // ── 시각 회전 ─────────────────────────────────────────────
                stripeOffset = (stripeOffset + delta).truncatingRemainder(dividingBy: 26)
                pendingDrag += delta

                // ── 키 전송 ───────────────────────────────────────────────
                while pendingDrag <= -effectivePx {
                    pendingDrag += effectivePx
                    flash("+")
                    Task { await tv.sendKey(upKey) }
                }
                while pendingDrag >= effectivePx {
                    pendingDrag -= effectivePx
                    flash("−")
                    Task { await tv.sendKey(downKey) }
                }
            }
            .onEnded { _ in
                lastTranslation = 0
                pendingDrag     = 0
                // 관성 감쇠: 속도를 0으로 서서히 복귀
                withAnimation(.easeOut(duration: 0.4)) { smoothVelocity = 0 }
            }
    }

    private func flash(_ sign: String) {
        flashText = sign
        withAnimation(.easeIn(duration: 0.04))  { flashOpacity = 0.85 }
        withAnimation(.easeOut(duration: 0.40).delay(0.04)) { flashOpacity = 0 }
    }
}

// MARK: 트림 휠 본체 (리얼 항공 스타일)

private struct TrimWheelBody: View {
    let stripeOffset: CGFloat

    var body: some View {
        ZStack {
            // ── 1. 원통 바디 (가로 그라디언트 → 3D 금속 질감) ──────────────
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(
                    stops: [
                        .init(color: Color(white: 0.55), location: 0.00),  // 왼쪽 크롬 하이라이트
                        .init(color: Color(white: 0.32), location: 0.08),
                        .init(color: Color(white: 0.14), location: 0.30),
                        .init(color: Color(white: 0.06), location: 0.55),  // 중심 깊은 그림자
                        .init(color: Color(white: 0.10), location: 0.75),
                        .init(color: Color(white: 0.22), location: 0.92),
                        .init(color: Color(white: 0.38), location: 1.00),  // 오른쪽 반사
                    ],
                    startPoint: .leading, endPoint: .trailing
                ))

            // ── 2. 릿지 스트라이프 (하이라이트+그림자 쌍 → 돌출 릿지) ────────
            GeometryReader { geo in
                Canvas { ctx, size in
                    let ridgeSpacing: CGFloat = 13
                    let offset = stripeOffset.truncatingRemainder(dividingBy: ridgeSpacing)
                    var y = offset - ridgeSpacing * 2

                    var idx = 0
                    while y < size.height + ridgeSpacing {
                        let cy        = size.height / 2
                        let distRatio = min(abs(y - cy) / (cy + 10), 1.0)

                        // 릿지마다 4줄마다 앰버 악센트
                        let isAccent = (idx % 5 == 0)

                        // 하이라이트 (릿지 상단 면)
                        let hlOpacity = Double((1.0 - distRatio * 0.7) * (isAccent ? 0.90 : 0.60))
                        if hlOpacity > 0.02 {
                            let hlColor: Color = isAccent
                                ? Color(red: 0.95, green: 0.78, blue: 0.20)
                                : Color(white: 0.80)
                            var p = Path()
                            p.move(to: .init(x: 4, y: y))
                            p.addLine(to: .init(x: size.width - 4, y: y))
                            ctx.stroke(p, with: .color(hlColor.opacity(hlOpacity)), lineWidth: 2.2)
                        }

                        // 그림자 (릿지 하단 면) → 깊이감
                        let shOpacity = Double((1.0 - distRatio * 0.8) * 0.70)
                        if shOpacity > 0.02 {
                            var p = Path()
                            p.move(to: .init(x: 4, y: y + 3.5))
                            p.addLine(to: .init(x: size.width - 4, y: y + 3.5))
                            ctx.stroke(p, with: .color(Color.black.opacity(shOpacity)), lineWidth: 2.0)
                        }

                        y   += ridgeSpacing
                        idx += 1
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))

            // ── 3. 중앙 포커스 밴드 (파란 글로우) ────────────────────────────
            VStack(spacing: 2) {
                Capsule()
                    .fill(Color(red: 0.20, green: 0.50, blue: 1.00).opacity(0.25))
                    .frame(height: 18)
                    .padding(.horizontal, 8)
            }

            // ── 4. 왼쪽 크롬 엣지 하이라이트 ────────────────────────────────
            HStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(
                        colors: [Color(white: 1.0).opacity(0.18), Color(white: 1.0).opacity(0.00)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: 18)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))

            // ── 5. 테두리 ─────────────────────────────────────────────────
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [Color(white: 0.65), Color(white: 0.18), Color(white: 0.40)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        }
    }
}

// ============================================================
// MARK: - V2: 원형 다이얼 회전판
// ============================================================

private struct DialWheelControl: View {
    let label: String
    let upKey:   LGKey
    let downKey: LGKey

    @EnvironmentObject var tv: TVController

    @State private var angleDeg: Double  = 0
    @State private var lastTranslation: CGFloat = 0
    @State private var pendingDrag: CGFloat = 0
    @State private var flashText: String = ""
    @State private var flashOpacity: Double = 0

    @State private var lastEventTime: Date = Date()
    @State private var smoothVelocity: CGFloat = 0

    private let basePx: CGFloat = 18
    private let minPx:  CGFloat = 4

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chevron.up")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(white: 0.38))

            DialShape(angleDeg: angleDeg)
                .frame(width: 150, height: 150)
                .gesture(dragGesture)
                .overlay(
                    Text(flashText)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Color(white: 1).opacity(flashOpacity))
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

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let delta = v.translation.height - lastTranslation
                lastTranslation = v.translation.height

                let now = Date()
                let dt  = CGFloat(now.timeIntervalSince(lastEventTime))
                lastEventTime = now
                let instantV = dt > 0 ? abs(delta) / dt : 0
                smoothVelocity = smoothVelocity * 0.65 + instantV * 0.35

                let speedRatio  = min(smoothVelocity / 600, 1.0)
                let effectivePx = basePx - (basePx - minPx) * speedRatio

                angleDeg   += Double(delta) * 0.8
                pendingDrag += delta

                while pendingDrag <= -effectivePx { pendingDrag += effectivePx; flash("+"); Task { await tv.sendKey(upKey) } }
                while pendingDrag >= effectivePx  { pendingDrag -= effectivePx; flash("−"); Task { await tv.sendKey(downKey) } }
            }
            .onEnded { _ in lastTranslation = 0; pendingDrag = 0 }
    }

    private func flash(_ sign: String) {
        flashText = sign
        withAnimation(.easeIn(duration: 0.04))  { flashOpacity = 0.85 }
        withAnimation(.easeOut(duration: 0.40).delay(0.04)) { flashOpacity = 0 }
    }
}

private struct DialShape: View {
    let angleDeg: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    stops: [
                        .init(color: Color(white: 0.30), location: 0.0),
                        .init(color: Color(white: 0.16), location: 1.0),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            Circle().stroke(Color(white: 0.42), lineWidth: 1.5)

            GeometryReader { geo in
                let r = geo.size.width / 2
                Canvas { ctx, size in
                    let tickCount = 36
                    for i in 0..<tickCount {
                        let angle   = (Double(i) / Double(tickCount)) * 360.0 + angleDeg
                        let rad     = angle * Double.pi / 180.0
                        let isMajor = i % 9 == 0
                        let inner: CGFloat = isMajor ? r * 0.72 : r * 0.82
                        let outer: CGFloat = r * 0.94
                        var p = Path()
                        p.move(to: .init(x: r + cos(rad) * inner, y: r + sin(rad) * inner))
                        p.addLine(to: .init(x: r + cos(rad) * outer, y: r + sin(rad) * outer))
                        ctx.stroke(p,
                                   with: .color(Color(white: isMajor ? 0.65 : 0.38)),
                                   lineWidth: isMajor ? 2.0 : 1.0)
                    }
                }
            }
            .clipShape(Circle())

            Circle()
                .fill(LinearGradient(
                    stops: [
                        .init(color: Color(white: 0.22), location: 0.0),
                        .init(color: Color(white: 0.10), location: 1.0),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
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
