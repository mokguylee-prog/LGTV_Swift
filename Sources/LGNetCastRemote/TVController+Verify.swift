import Foundation

// MARK: - LG TV Verification

extension TVController {

    /// Returns (reachable, verified, label, kind) for the given IP.
    nonisolated func verifyLGTV(
        ip: String, location: String, server: String
    ) async -> (reachable: Bool, verified: Bool, label: String, kind: DeviceKind) {

        guard await isPortOpen(ip: ip, timeoutMs: 1200) else {
            return (false, false, "", .unknown)
        }

        let ssdpServerLooksLikeLG = looksLikeLGServer(server)

        // 1. UPnP device description XML from SSDP LOCATION URL
        if !location.isEmpty, let url = URL(string: location) {
            var req = URLRequest(url: url, timeoutInterval: 3)
            req.setValue("UDAP/2.0", forHTTPHeaderField: "User-Agent")
            if let (data, response) = try? await session.data(for: req) {
                let xml       = String(data: data, encoding: .utf8) ?? ""
                let mfr       = (parseTag("manufacturer",     from: xml) ?? "").uppercased()
                let devType   = (parseTag("deviceType",       from: xml) ?? "").uppercased()
                let modelName =  parseTag("modelName",        from: xml) ?? ""
                let friendly  =  parseTag("friendlyName",     from: xml) ?? ""
                let modelDesc =  parseTag("modelDescription", from: xml) ?? ""
                let nameBlob  = "\(modelName) \(friendly) \(modelDesc)".uppercased()
                let srvHeader = (response as? HTTPURLResponse)?
                                    .value(forHTTPHeaderField: "Server") ?? ""

                let mfrOK   = mfr.contains("LG")
                let tvHint  = devType.contains("TV") || devType.contains("MEDIARENDERER")
                           || nameBlob.contains("TV") || nameBlob.contains("LW5700")
                           || nameBlob.contains("SMART TV")
                let srvHasLG = ssdpServerLooksLikeLG || looksLikeLGServer(srvHeader)

                if (mfrOK && tvHint) || srvHasLG {
                    let label = [friendly, modelName].filter { !$0.isEmpty }.joined(separator: " / ")
                    return (true, true, label, .lgTV)
                }
            }
        }

        // 2. Root page header + body check
        if let url = URL(string: "http://\(ip):8080/") {
            var req = URLRequest(url: url, timeoutInterval: 2)
            req.setValue("iPhone", forHTTPHeaderField: "User-Agent")
            if let (data, response) = try? await session.data(for: req) {
                let srvHeader = (response as? HTTPURLResponse)?
                                    .value(forHTTPHeaderField: "Server") ?? ""
                if looksLikePrinter(srvHeader) {
                    return (true, false, "프린터: \(printerModel(from: srvHeader))", .printer)
                }
                if looksLikeLGServer(srvHeader) { return (true, true, "", .lgTV) }

                let text = (String(data: data, encoding: .utf8) ?? "").uppercased()
                if text.contains("HDCP") || text.contains("NETCAST") || text.contains("UDAP") {
                    return (true, true, "LG NetCast", .lgTV)
                }
                if text.contains("LG") { return (true, true, "", .lgTV) }
            }
        }

        if ssdpServerLooksLikeLG { return (true, true, "", .lgTV) }

        // 3. HDCP API endpoint (LG NetCast exclusive)
        if let url = URL(string: "http://\(ip):8080/hdcp/api") {
            var req = URLRequest(url: url, timeoutInterval: 2)
            req.setValue("iPhone", forHTTPHeaderField: "User-Agent")
            if let (_, resp) = try? await session.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode < 500 {
                return (true, true, "LG NetCast", .lgTV)
            }
        }

        return (true, false, "", .unknown)
    }

    // MARK: - Server string classifiers

    nonisolated func looksLikeLGServer(_ value: String) -> Bool {
        let u = value.uppercased()
        return u.contains("LG") || u.contains("NETCAST") || u.contains("UDAP")
    }

    nonisolated private func looksLikePrinter(_ value: String) -> Bool {
        let u = value.uppercased()
        return u.contains("HP HTTP") || u.contains("EPSON")   || u.contains("CANON")
            || u.contains("BROTHER") || u.contains("XEROX")   || u.contains("RICOH")
            || u.contains("LEXMARK") || u.contains("KYOCERA") || u.contains("PRINTER")
    }

    nonisolated private func printerModel(from server: String) -> String {
        for part in server.components(separatedBy: ";") {
            let t = part.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("HP "), t.count < 60 { return String(t.prefix(50)) }
        }
        return server.components(separatedBy: ";").first?
                     .trimmingCharacters(in: .whitespaces) ?? server
    }
}
