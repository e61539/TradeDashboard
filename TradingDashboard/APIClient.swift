import Foundation

final class APIClient {
    static let shared = APIClient()
    private init() {}

    func fetchAccountSnapshot(
        baseURL: String,
        apiKey: String,
        completion: @escaping (AccountSnapshot?, String?) -> Void
    ) {
        guard
            let encodedKey = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "\(baseURL)/api/positions?k=\(encodedKey)")
        else {
            completion(nil, "Bad positions URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error {
                completion(nil, error.localizedDescription)
                return
            }

            guard let http = response as? HTTPURLResponse else {
                completion(nil, "No HTTP response")
                return
            }

            guard let data, (200...299).contains(http.statusCode) else {
                completion(nil, "HTTP \(http.statusCode)")
                return
            }

            do {
                let decoded = try JSONDecoder().decode(PositionsResponse.self, from: data)

                let snapshot = AccountSnapshot(
                    positions: decoded.positions,
                    summary: decoded.summary,
                    assetTotal: decoded.assetTotal,
                    cashAvailable: decoded.cashAvailable,
                    settledCash: decoded.settledCash,
                    buyingPower: decoded.buyingPower,
                    totalAccountValue: decoded.totalAccountValue,
                    pendingBuyNotional: decoded.pendingBuyNotional,
                    freeCashAfterPending: decoded.freeCashAfterPending
                )

                completion(snapshot, nil)
            } catch {
                let body = String(data: data, encoding: .utf8) ?? ""
                completion(nil, "Decode error: \(error.localizedDescription). Body: \(body)")
            }
        }.resume()
    }

    func fetchCapitalReadiness(
        baseURL: String,
        apiKey: String,
        completion: @escaping (CapitalReadiness?, String?) -> Void
    ) {
        var components = URLComponents(string: "\(baseURL)/api/capital-readiness")
        components?.queryItems = [
            URLQueryItem(name: "k", value: apiKey)
        ]

        guard let url = components?.url else {
            completion(nil, "Bad capital readiness URL")
            return
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = AppConfig.buyLowRequestTimeout
        req.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")

        URLSession.shared.dataTask(with: req) { data, response, error in
            if let error {
                completion(nil, error.localizedDescription)
                return
            }

            guard let http = response as? HTTPURLResponse else {
                completion(nil, "No HTTP response")
                return
            }

            guard let data, (200...299).contains(http.statusCode) else {
                completion(nil, "HTTP \(http.statusCode)")
                return
            }

            do {
                let decoded = try JSONDecoder().decode(CapitalReadiness.self, from: data)
                completion(decoded, nil)
            } catch {
                let body = String(data: data, encoding: .utf8) ?? ""
                completion(nil, "Capital readiness decode error: \(error.localizedDescription). Body: \(body)")
            }
        }.resume()
    }

    func fetchBuyLowStatuses(
        baseURL: String,
        apiKey: String,
        symbols: [String],
        completion: @escaping ([BuyLowStatus]?, String?) -> Void
    ) {
        if symbols.isEmpty {
            completion([], nil)
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var statuses: [BuyLowStatus] = []
        var errors: [String] = []

        for symbol in symbols {
            group.enter()
            fetchBuyLowStatus(baseURL: baseURL, apiKey: apiKey, symbol: symbol) { status, error in
                lock.lock()
                if let status {
                    statuses.append(status)
                }
                if let error {
                    errors.append("\(symbol): \(error)")
                }
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .global(qos: .utility)) {
            if statuses.isEmpty, let firstError = errors.first {
                completion(nil, firstError)
            } else {
                completion(statuses.sorted { $0.symbol < $1.symbol }, nil)
            }
        }
    }

    func fetchBuyLowStatus(
        baseURL: String,
        apiKey: String,
        symbol: String,
        completion: @escaping (BuyLowStatus?, String?) -> Void
    ) {
        fetchBuyLowStatusAttempt(
            baseURL: baseURL,
            apiKey: apiKey,
            symbol: symbol,
            retryOnFailure: true,
            completion: completion
        )
    }

    private func fetchBuyLowStatusAttempt(
        baseURL: String,
        apiKey: String,
        symbol: String,
        retryOnFailure: Bool,
        completion: @escaping (BuyLowStatus?, String?) -> Void
    ) {
        var components = URLComponents(string: "\(baseURL)/api/logs/summary")
        components?.queryItems = [
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "search_files", value: "30")
        ]

        guard let url = components?.url else {
            completion(nil, "Bad BuyLow summary URL")
            return
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = AppConfig.buyLowRequestTimeout
        req.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")

        func fail(_ message: String) {
            guard retryOnFailure else {
                completion(nil, message)
                return
            }

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) {
                self.fetchBuyLowStatusAttempt(
                    baseURL: baseURL,
                    apiKey: apiKey,
                    symbol: symbol,
                    retryOnFailure: false,
                    completion: completion
                )
            }
        }

        URLSession.shared.dataTask(with: req) { data, response, error in
            if let error {
                fail(error.localizedDescription)
                return
            }

            guard let http = response as? HTTPURLResponse else {
                fail("No HTTP response")
                return
            }

            guard let data, (200...299).contains(http.statusCode) else {
                fail("HTTP \(http.statusCode)")
                return
            }

            do {
                let decoded = try JSONDecoder().decode(BuyLowSummaryResponse.self, from: data)

                guard decoded.ok else {
                    fail(decoded.error ?? "BuyLow summary unavailable")
                    return
                }

                let summary = decoded.summary
                let status = BuyLowStatus(
                    symbol: symbol,
                    status: self.buyLowDisplayStatus(summary),
                    message: self.buyLowDisplayMessage(summary),
                    file: decoded.file
                )
                completion(status, nil)
            } catch {
                let body = String(data: data, encoding: .utf8) ?? ""
                fail("BuyLow summary decode error: \(error.localizedDescription). Body: \(body)")
            }
        }.resume()
    }

    private func buyLowDisplayStatus(_ summary: BuyLowSummaryPayload?) -> String {
        guard let summary else { return "UNKNOWN" }

        let block = normalizedBlock(summary)
        if let finalQty = summary.finalQty, finalQty > 0, block == nil {
            return "READY | ELIGIBLE"
        }

        if let reason = blockReason(summary) {
            if reason == "ATR" || reason == "budget" || reason == "no size" {
                return "HOLD | BLOCKED(\(reason))"
            }

            if hasSignal(summary) || summary.finalQty == 0 {
                return "SIGNAL | BLOCKED(\(reason))"
            }

            return "HOLD | BLOCKED(\(reason))"
        }

        if hasSignal(summary), summary.finalQty == 0 {
            return "SIGNAL | BLOCKED(unknown)"
        }

        if summary.status?.localizedCaseInsensitiveContains("READY") == true {
            return "SIGNAL | BLOCKED(unknown)"
        }

        return summary.status ?? "UNKNOWN"
    }

    private func buyLowDisplayMessage(_ summary: BuyLowSummaryPayload?) -> String {
        guard let summary else { return "No signal yet" }

        if blockReason(summary) == "ATR" {
            if let (ask, target) = buyLowPrices(summary), target > 0 {
                let discrepancyPct = (ask - target) / target * 100
                return String(format: "Ask %.2f > Target %.2f (%+.1f%%)", ask, target, discrepancyPct)
            }
            return "ATR target not met"
        }

        if let reason = blockReason(summary), isBuySignalText(summary.displayText) {
            return summary.holdText ?? "Blocked(\(reason))"
        }

        if summary.finalQty == 0, hasSignal(summary), isBuySignalText(summary.displayText) {
            return summary.holdText ?? "Blocked"
        }

        return summary.displayText ?? summary.holdText ?? "No signal yet"
    }

    private func isBuySignalText(_ text: String?) -> Bool {
        text?.localizedCaseInsensitiveContains("BUY signal") == true
    }

    private func buyLowPrices(_ summary: BuyLowSummaryPayload) -> (ask: Double, target: Double)? {
        if let ask = summary.ask, let target = summary.target {
            return (ask, target)
        }

        let text = [
            summary.displayText,
            summary.holdText,
            summary.why,
            summary.hold,
            summary.skip,
            summary.warn,
            summary.trigger,
            summary.signal
        ]
            .compactMap { $0 }
            .joined(separator: " ")

        let ask = summary.ask ?? firstNumber(after: ["ask", "ask_price"], in: text)
        let target = summary.target ?? firstNumber(after: ["target", "target_price", "atr_target"], in: text)

        guard let ask, let target else { return nil }
        return (ask, target)
    }

    private func firstNumber(after labels: [String], in text: String) -> Double? {
        for label in labels {
            let escapedLabel = NSRegularExpression.escapedPattern(for: label)
            let pattern = #"(?i)\b"# + escapedLabel + #"\b\s*[:=]?\s*\$?([0-9]+(?:\.[0-9]+)?)"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }

            let nsText = text as NSString
            let range = NSRange(location: 0, length: nsText.length)
            if let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 {
                return Double(nsText.substring(with: match.range(at: 1)))
            }
        }

        return nil
    }

    private func blockReason(_ summary: BuyLowSummaryPayload) -> String? {
        let text = [
            normalizedBlock(summary),
            summary.why,
            summary.hold,
            summary.skip,
            summary.warn,
            summary.displayText,
            summary.holdText
        ]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

        guard !text.isEmpty else { return nil }

        if text.contains("atr") || text.contains("target not met") || text.contains("strict") {
            return "ATR"
        }
        if text.contains("budget") || text.contains("cash=0") || text.contains("budget=0") || text.contains("budget 0") {
            return "budget"
        }
        if text.contains("no_viable_size") || text.contains("no viable size") || text.contains("final_qty=0") {
            return "no size"
        }
        if text.contains("min_usd") || text.contains("min_qty") {
            return "min size"
        }
        if text.contains("cap") || text.contains("headroom") {
            return "cap"
        }
        if text.contains("spread") {
            return "spread"
        }

        return normalizedBlock(summary)
    }

    private func normalizedBlock(_ summary: BuyLowSummaryPayload) -> String? {
        let block = summary.block?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let block, !block.isEmpty, block.lowercased() != "none" else {
            return nil
        }
        return block
    }

    private func hasSignal(_ summary: BuyLowSummaryPayload) -> Bool {
        let signalText = [summary.signal, summary.trigger, summary.passLine]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " ")
            .lowercased()

        if !signalText.isEmpty && signalText != "none" {
            return true
        }

        return summary.status?.localizedCaseInsensitiveContains("READY") == true
    }

    func placeOrder(
        tradeBaseURL: String,
        apiKey: String,
        symbol: String,
        side: String,
        qty: Int,
        completion: @escaping (String) -> Void
    ) {
        previewOrder(
            tradeBaseURL: tradeBaseURL,
            apiKey: apiKey,
            symbol: symbol,
            side: side,
            qty: qty
        ) { preview, error in
            if let error {
                completion("Preview failed: \(error)")
                return
            }

            guard let preview else {
                completion("Preview failed: no response")
                return
            }

            self.confirmOrder(
                tradeBaseURL: tradeBaseURL,
                apiKey: apiKey,
                previewID: preview.preview_id,
                confirmCode: preview.confirm_code
            ) { result, error in
                if let error {
                    completion("Confirm failed: \(error)")
                    return
                }

                if let result, result.ok {
                    let msg = result.broker_result?.message ?? result.status ?? "order submitted"
                    completion(msg)
                } else {
                    completion("Confirm failed")
                }
            }
        }
    }

    private func previewOrder(
        tradeBaseURL: String,
        apiKey: String,
        symbol: String,
        side: String,
        qty: Int,
        completion: @escaping (PreviewResponse?, String?) -> Void
    ) {
        guard let url = URL(string: "\(tradeBaseURL)/v1/orders/preview") else {
            completion(nil, "Bad preview URL")
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        req.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "symbol": symbol,
            "side": side,
            "qty": qty
        ]

        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(nil, "Preview body encode failed")
            return
        }

        URLSession.shared.dataTask(with: req) { data, response, error in
            if let error {
                completion(nil, error.localizedDescription)
                return
            }

            guard let http = response as? HTTPURLResponse else {
                completion(nil, "No HTTP response")
                return
            }

            guard let data, (200...299).contains(http.statusCode) else {
                completion(nil, "HTTP \(http.statusCode)")
                return
            }

            do {
                let decoded = try JSONDecoder().decode(PreviewResponse.self, from: data)
                completion(decoded, nil)
            } catch {
                let body = String(data: data, encoding: .utf8) ?? ""
                completion(nil, "Preview decode error: \(error.localizedDescription). Body: \(body)")
            }
        }.resume()
    }

    private func confirmOrder(
        tradeBaseURL: String,
        apiKey: String,
        previewID: String,
        confirmCode: String,
        completion: @escaping (ConfirmResult?, String?) -> Void
    ) {
        guard let url = URL(string: "\(tradeBaseURL)/v1/orders/confirm") else {
            completion(nil, "Bad confirm URL")
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        req.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "preview_id": previewID,
            "confirm_code": confirmCode
        ]

        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(nil, "Confirm body encode failed")
            return
        }

        URLSession.shared.dataTask(with: req) { data, response, error in
            if let error {
                completion(nil, error.localizedDescription)
                return
            }

            guard let http = response as? HTTPURLResponse else {
                completion(nil, "No HTTP response")
                return
            }

            guard let data, (200...299).contains(http.statusCode) else {
                completion(nil, "HTTP \(http.statusCode)")
                return
            }

            do {
                let decoded = try JSONDecoder().decode(ConfirmResult.self, from: data)
                completion(decoded, nil)
            } catch {
                let body = String(data: data, encoding: .utf8) ?? ""
                completion(nil, "Confirm decode error: \(error.localizedDescription). Body: \(body)")
            }
        }.resume()
    }
}
