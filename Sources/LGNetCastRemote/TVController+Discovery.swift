import Foundation

// MARK: - Device Discovery

extension TVController {

    func discover() async {
        isRecovering    = true   // 검색 중엔 헬스 루프의 자동 재탐색을 멈춘다
        defer { isRecovering = false }
        isScanning      = true
        ssdpDone        = false
        portScanned     = 0
        portTotal       = 0
        portLog         = []
        verifyDone      = 0
        verifyTotal     = 0
        discoveredDevices = []
        statusMessage   = "네트워크 검색 중..."

        let ssdp        = SSDPDiscovery()
        let preferredIP = tvIP

        // Run SSDP and port scan concurrently, collect all candidates
        async let ssdpCandidates = ssdp.discover(includePortScan: false)
        async let scanCandidates = ssdp.portScanOnly { [weak self] done, total, ip, open in
            Task { @MainActor [weak self] in
                self?.portScanned = done
                self?.portTotal   = total
                self?.portLog.append((ip: ip, open: open))
            }
        }

        var seen: [String: SSDPCandidate] = [:]
        for c in await ssdpCandidates { seen[c.ip] = seen[c.ip] ?? c }
        ssdpDone = true
        for c in await scanCandidates { seen[c.ip] = seen[c.ip] ?? c }

        var candidates = Array(seen.values)
        candidates = mergePreferredCandidate(preferredIP, into: candidates)

        let devices        = await buildDevices(from: candidates)
        let orderedDevices = orderDevices(devices, preferredIP: preferredIP)

        discoveredDevices = orderedDevices
        isScanning        = false

        if orderedDevices.isEmpty {
            statusMessage = "기기를 찾지 못했습니다"
            return
        }

        let verifiedCount = orderedDevices.filter { $0.verified }.count
        statusMessage = "기기 \(orderedDevices.count)개 발견 (LG TV 후보 \(verifiedCount)개) — 인증 확인 중..."

        // 표시용 판정(verified)은 휴리스틱일 뿐 — 실제 채택은 AuthReq 세션 획득까지 통과해야 한다.
        let tvIPs    = orderedDevices.filter { $0.kind == .lgTV }.map(\.ip)
        let otherIPs = orderedDevices.filter { $0.kind == .unknown }.map(\.ip)

        if pin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let first = tvIPs.first {
                tvIP = first
                await requestPIN()
            }
            return
        }

        if await adoptFirstAuthenticated(tvIPs + otherIPs) {
            statusMessage = "기기 \(orderedDevices.count)개 발견 — \(tvIP) 연결됨 ✓"
        } else {
            statusMessage = "기기 \(orderedDevices.count)개 발견 — 인증되는 TV 없음 (PIN 확인)"
        }
    }

    /// 자동 재탐색: SSDP(M-SEARCH) 만 돌려 LGE 후보부터 시도한다.
    @discardableResult
    func discoverAndConnect() async -> Bool {
        let candidates = await SSDPDiscovery().discover(includePortScan: false)
        return await adoptFirstAuthenticated(candidates.map(\.ip))
    }

    /// 후보를 순서대로 8080 핑(800ms) → AuthReq 로 확인해 처음 세션을 준 IP 를 채택·저장한다.
    /// 아무도 통과하지 못하면 tvIP 는 원래 값 그대로 둔다(프린터 등을 저장하지 않음).
    func adoptFirstAuthenticated(_ ips: [String]) async -> Bool {
        guard !pin.isEmpty else { return false }
        var tried = Set<String>()
        for ip in ips where tried.insert(ip).inserted {
            guard await isPortOpen(ip: ip, timeoutMs: 800) else { continue }
            if case .session(let sessionID) = await authenticate(ip: ip) {
                tvIP            = ip
                connectionState = .connected(session: sessionID)
                statusMessage   = "연결됨 ✓ (\(ip))"
                autoReconnect   = true
                healthMisses    = 0
                saveState()
                return true
            }
        }
        return false
    }

    func selectDevice(_ device: TVDevice) {
        tvIP            = device.ip
        connectionState = .disconnected
        autoReconnect   = false   // 사용자가 고른 IP 를 자동 재탐색이 덮어쓰지 않게
        statusMessage   = "IP 선택됨: \(device.ip)"
        saveState()
    }

    // MARK: - Helpers

    func buildDevices(from candidates: [SSDPCandidate]) async -> [TVDevice] {
        var devices: [TVDevice] = []
        verifyTotal = candidates.count
        verifyDone  = 0

        await withTaskGroup(of: TVDevice?.self) { group in
            for candidate in candidates {
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    let (reachable, verified, label, kind) = await self.verifyLGTV(
                        ip: candidate.ip, location: candidate.location, server: candidate.server
                    )
                    guard reachable else { return nil }

                    let displayName: String
                    switch kind {
                    case .lgTV:
                        let suffix = label.isEmpty ? "" : "  \(label)"
                        displayName = "\(candidate.ip)  [LG TV 확인]\(suffix)"
                    case .printer: displayName = "\(candidate.ip)  \(label)"
                    case .unknown: displayName = "\(candidate.ip)  [후보 기기]"
                    }
                    return TVDevice(ip: candidate.ip, name: displayName,
                                   verified: verified, kind: kind)
                }
            }
            for await device in group {
                verifyDone += 1
                if let device { devices.append(device) }
            }
        }
        return devices
    }

    func orderDevices(_ devices: [TVDevice], preferredIP: String) -> [TVDevice] {
        Dictionary(grouping: devices, by: \.ip)
            .values
            .compactMap { group in
                group.sorted {
                    $0.verified != $1.verified ? $0.verified : $0.name < $1.name
                }.first
            }
            .sorted {
                if $0.verified != $1.verified { return $0.verified }
                let lp = $0.ip == preferredIP, rp = $1.ip == preferredIP
                if lp != rp { return lp }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    func mergePreferredCandidate(_ preferredIP: String,
                                  into candidates: [SSDPCandidate]) -> [SSDPCandidate] {
        guard !preferredIP.isEmpty,
              !candidates.contains(where: { $0.ip == preferredIP }) else { return candidates }
        return candidates + [SSDPCandidate(ip: preferredIP, location: "", server: "")]
    }
}
