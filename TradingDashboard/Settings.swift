import Foundation

enum AppConfig {
    static let localHost = "10.0.0.80"
    static let tailscaleHost = "100.77.12.97"
    static let publicHost = "YOUR_PUBLIC_IP_OR_HOSTNAME"

    static let dashboardPort = 8000
    static let tradePort = 8080

    static let enableTrading = true
    static let allowPublicFallback = false
    static let buyLowRequestTimeout: TimeInterval = 20

    static let apiKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "TRADE_API_KEY") as? String,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            fatalError("TRADE_API_KEY missing from target Info settings")
        }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }()
}
