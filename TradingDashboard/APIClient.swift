import Foundation

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private func apiErrorMessage(data: Data?, statusCode: Int) -> String {
        guard let data, !data.isEmpty else {
            return "HTTP \(statusCode)"
        }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = apiErrorMessage(from: object) {
                return message
            }
        }

        let body = String(data: data, encoding: .utf8) ?? ""
        return body.isEmpty ? "HTTP \(statusCode)" : body
    }

    private func apiErrorMessage(from object: [String: Any]) -> String? {
        for key in ["detail", "message", "error", "status"] {
            if let text = object[key] as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
            if let details = object[key] as? [String], !details.isEmpty {
                let joined = details
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
                if !joined.isEmpty {
                    return joined
                }
            }
        }

        for key in ["broker_result", "result"] {
            if let nested = object[key] as? [String: Any],
               let message = apiErrorMessage(from: nested) {
                return message
            }
        }

        return nil
    }

    func fetchMarketRegime(
        baseURL: String,
        apiKey: String,
        completion: @escaping (MarketRegimeResponse?, String?) -> Void
    ) {
        var components = URLComponents(string: "\(baseURL)/api/intelligence/regime")
        components?.queryItems = [
            URLQueryItem(name: "k", value: apiKey)
        ]

        guard let url = components?.url else {
            completion(nil, "Bad intelligence regime URL")
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

            guard (200...299).contains(http.statusCode) else {
                completion(nil, self.apiErrorMessage(data: data, statusCode: http.statusCode))
                return
            }

            guard let data else {
                completion(nil, "No intelligence regime response body")
                return
            }

            do {
                let decoded = try JSONDecoder().decode(MarketRegimeResponse.self, from: data)
                completion(decoded, nil)
            } catch {
                let body = String(data: data, encoding: .utf8) ?? ""
                completion(nil, "Intelligence regime decode error: \(error.localizedDescription). Body: \(body)")
            }
        }.resume()
    }

    func fetchIntelligenceOpportunities(
        baseURL: String,
        apiKey: String,
        completion: @escaping (IntelligenceOpportunitiesResponse?, String?) -> Void
    ) {
        var components = URLComponents(string: "\(baseURL)/api/intelligence/opportunities")
        components?.queryItems = [
            URLQueryItem(name: "k", value: apiKey)
        ]

        guard let url = components?.url else {
            completion(nil, "Bad intelligence opportunities URL")
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

            guard (200...299).contains(http.statusCode) else {
                completion(nil, self.apiErrorMessage(data: data, statusCode: http.statusCode))
                return
            }

            guard let data else {
                completion(nil, "No intelligence opportunities response body")
                return
            }

            do {
                let decoded = try JSONDecoder().decode(IntelligenceOpportunitiesResponse.self, from: data)
                completion(decoded, nil)
            } catch {
                let body = String(data: data, encoding: .utf8) ?? ""
                completion(nil, "Intelligence opportunities decode error: \(error.localizedDescription). Body: \(body)")
            }
        }.resume()
    }

    func fetchDecisionActions(
        baseURL: String,
        apiKey: String,
        completion: @escaping (DecisionActionsResponse?, String?) -> Void
    ) {
        var components = URLComponents(string: "\(baseURL)/api/decision/actions")
        components?.queryItems = [
            URLQueryItem(name: "k", value: apiKey)
        ]

        guard let url = components?.url else {
            completion(nil, "Bad decision actions URL")
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

            guard (200...299).contains(http.statusCode) else {
                completion(nil, self.apiErrorMessage(data: data, statusCode: http.statusCode))
                return
            }

            guard let data else {
                completion(nil, "No decision actions response body")
                return
            }

            do {
                let decoded = try JSONDecoder().decode(DecisionActionsResponse.self, from: data)
                completion(decoded, nil)
            } catch {
                let body = String(data: data, encoding: .utf8) ?? ""
                completion(nil, "Decision actions decode error: \(error.localizedDescription). Body: \(body)")
            }
        }.resume()
    }

    func fetchTrendWatchlist(
        baseURL: String,
        apiKey: String,
        completion: @escaping (TrendWatchlistResponse?, String?) -> Void
    ) {
        var components = URLComponents(string: "\(baseURL)/api/trend-rider/watchlist")
        components?.queryItems = [
            URLQueryItem(name: "k", value: apiKey)
        ]

        guard let url = components?.url else {
            completion(nil, "Bad Trend Rider watchlist URL")
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

            guard (200...299).contains(http.statusCode) else {
                completion(nil, self.apiErrorMessage(data: data, statusCode: http.statusCode))
                return
            }

            guard let data else {
                completion(nil, "No Trend Rider watchlist response body")
                return
            }

            do {
                let decoded = try JSONDecoder().decode(TrendWatchlistResponse.self, from: data)
                completion(decoded, nil)
            } catch {
                let body = String(data: data, encoding: .utf8) ?? ""
                completion(nil, "Trend Rider watchlist decode error: \(error.localizedDescription). Body: \(body)")
            }
        }.resume()
    }

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

            guard (200...299).contains(http.statusCode) else {
                completion(nil, self.apiErrorMessage(data: data, statusCode: http.statusCode))
                return
            }

            guard let data else {
                completion(nil, "No preview response body")
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

            guard (200...299).contains(http.statusCode) else {
                completion(nil, self.apiErrorMessage(data: data, statusCode: http.statusCode))
                return
            }

            guard let data else {
                completion(nil, "No confirm response body")
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

    func previewOrder(
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

            guard (200...299).contains(http.statusCode) else {
                completion(nil, self.apiErrorMessage(data: data, statusCode: http.statusCode))
                return
            }

            guard let data else {
                completion(nil, "No preview response body")
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

    func confirmOrder(
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

            guard (200...299).contains(http.statusCode) else {
                completion(nil, self.apiErrorMessage(data: data, statusCode: http.statusCode))
                return
            }

            guard let data else {
                completion(nil, "No confirm response body")
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
