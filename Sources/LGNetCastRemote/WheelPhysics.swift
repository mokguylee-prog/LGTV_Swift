import AppKit
import Combine

// MARK: - InertiaEngine
//
// 120 Hz main-thread 물리 엔진 (SpinWheelControl 패턴 + Combine).
//
// ▸ tick PassthroughSubject → onReceive() 로 매 프레임 수신
//   onChange(of: frameCount) 방식은 SwiftUI 렌더 코얼레싱으로 프레임이 누락될 수 있음.
// ▸ Timer on RunLoop.main → 메인 스레드 보장, @State 안전.
// ▸ friction은 setFriction()으로 실시간 반영.

final class InertiaEngine: ObservableObject {

    /// 매 물리 프레임: 이동 거리(pt)를 방출. +아래/−위.
    let tick = PassthroughSubject<CGFloat, Never>()

    @Published private(set) var isRunning = false

    private var velocity: CGFloat = 0
    private var friction: CGFloat = 0.97
    private var lastTime: Date    = .now
    private var timer:    Timer?

    deinit { cancel() }

    // MARK: – API

    /// 관성 시작. velocity: pt/s.  threshold: 5 pt/s 이상이면 구동.
    func kick(velocity v: CGFloat, friction fr: CGFloat) {
        guard abs(v) > 5 else { cancel(); return }
        velocity = v
        friction = clamped(fr)
        lastTime = .now
        if !isRunning { arm() }
    }

    /// 슬라이더 이동 시 즉시 반영 (코스팅 중에도 적용).
    func setFriction(_ fr: CGFloat) { friction = clamped(fr) }

    /// 드래그 시작 등으로 즉시 정지.
    func cancel() {
        timer?.invalidate(); timer = nil
        velocity = 0; isRunning = false
    }

    // MARK: – Private

    private func clamped(_ fr: CGFloat) -> CGFloat { max(0.80, min(0.998, fr)) }

    private func arm() {
        isRunning = true
        // .common → UI 추적(드래그) 중에도 타이머 실행
        let t = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.step()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func step() {
        let now  = Date.now
        let dt   = min(CGFloat(now.timeIntervalSince(lastTime)), 0.05)
        lastTime = now
        guard dt > 0.0003 else { return }

        // SpinWheelControl 동일 공식: vel *= decay, dist = vel * dt
        let decay = CGFloat(pow(Double(friction), Double(dt * 60.0)))
        let dist  = velocity * dt
        velocity *= decay

        tick.send(dist)          // ← Combine PassthroughSubject: 매 프레임 즉시 방출

        if abs(velocity) < 1.0 { cancel() }
    }
}
