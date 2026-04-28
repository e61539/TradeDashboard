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

    private func fetchBuyLowStatus(
        baseURL: String,
        apiKey: String,
        symbol: String,
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
                let decoded = try JSONDecoder().decode(BuyLowSummaryResponse.self, from: data)

                guard decoded.ok else {
                    completion(nil, decoded.error ?? "BuyLow summary unavailable")
                    return
                }

                let summary = decoded.summary
                let status = BuyLowStatus(
                    symbol: symbol,
                    status: summary?.status ?? "UNKNOWN",
                    message: summary?.displayText ?? summary?.holdText ?? "No signal yet",
                    file: decoded.file
                )
                completion(status, nil)
            } catch {
                let body = String(data: data, encoding: .utf8) ?? ""
                completion(nil, "BuyLow summary decode error: \(error.localizedDescription). Body: \(body)")
            }
        }.resume()
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
