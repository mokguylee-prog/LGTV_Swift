import Foundation

// MARK: - Device Discovery

extension TVController {

    func discover() async {
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
        if let sel = orderedDevices.first(where: { $0.ip == tvIP && $0.kind == .lgTV }) {
            statusMessage = "기기 \(orderedDevices.count)개 발견 (LG TV \(verifiedCount)개) - \(sel.ip) 선택됨"
        } else {
            statusMessage = "기기 \(orderedDevices.count)개 발견 (LG TV \(verifiedCount)개)"
        }

        if let first = discoveredDevices.first(where: { $0.verified && $0.kind == .lgTV }) {
            tvIP = first.ip
            saveState()
            if pin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await requestPIN()
            } else {
                await connect()
            }
        }
    }

    func selectDevice(_ device: TVDevice) {
        tvIP            = device.ip
        connectionState = .disconnected
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
