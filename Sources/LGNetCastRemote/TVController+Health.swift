import Foundation

// MARK: - Health check & auto recovery
//
// LGTV_Remocon(app_remote.c) 와 같은 규칙:
//   · 연결 중엔 1.5초마다 TCP 8080 핑, 3번 연속 실패하면 끊긴 것으로 본다.
//   · 끊기면 저장된 IP 를 먼저 보고, 없으면 SSDP 로 다시 찾는다(DHCP 로 IP 가 바뀜).
//   · TV 가 꺼져 있으면 3초 간격으로 계속 시도하고, 켜지면 알아서 물린다.
//   · PIN 거부(.error) 는 자동 재시도하지 않는다.

extension TVController {

    static let healthPeriod: Duration = .milliseconds(1500)
    static let healthTimeoutMs = 1800
    static let healthMissMax   = 3
    static let retryDelay: TimeInterval = 3

    func startHealthMonitor() {
        healthTask?.cancel()
        healthTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.healthPeriod)
                guard let self else { return }
                await self.healthTick()
            }
        }
    }

    private func healthTick() async {
        guard !isScanning, !isRecovering else { return }

        switch connectionState {
        case .connected:
            let ip = tvIP
            if await isPortOpen(ip: ip, timeoutMs: Self.healthTimeoutMs) {
                healthMisses = 0
                return
            }
            guard ip == tvIP, connectionState.isConnected else { return }
            healthMisses += 1
            guard healthMisses >= Self.healthMissMax else { return }

            healthMisses    = 0
            connectionState = .disconnected
            statusMessage   = "TV 연결 끊김 — 다시 찾는 중..."
            autoReconnect   = true
            await recover()

        case .disconnected where autoReconnect && !pin.isEmpty:
            guard Date() >= nextRetryAt else { return }
            await recover()

        default:
            return
        }
    }

    /// 저장된 IP 에 TV 가 있으면 그대로 인증, 없으면 SSDP 로 새 IP 를 찾는다.
    func recover() async {
        guard !isRecovering, !pin.isEmpty else { return }
        isRecovering = true
        defer { isRecovering = false }

        if !tvIP.isEmpty, await isPortOpen(ip: tvIP, timeoutMs: Self.healthTimeoutMs) {
            await connect()
        } else {
            statusMessage = "TV 찾는 중... (\(tvIP.isEmpty ? "IP 없음" : tvIP) 응답 없음)"
            if !(await discoverAndConnect()) {
                connectionState = .disconnected
                statusMessage   = "TV 꺼짐 또는 찾을 수 없음 — 자동 재시도 중"
            }
        }

        if !connectionState.isConnected {
            nextRetryAt = Date().addingTimeInterval(Self.retryDelay)
        }
    }
}
