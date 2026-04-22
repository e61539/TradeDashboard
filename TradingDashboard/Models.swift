import Foundation

// MARK: - Quote API

struct QuoteDataPayload: Codable {
    let last: Double?
    let close: Double?
    let dailyHigh: Double?
    let dailyLow: Double?
    let high52: Double?
    let low52: Double?

    enum CodingKeys: String, CodingKey {
        case last
        case close
        case dailyHigh = "daily_high"
        case dailyLow = "daily_low"
        case high52 = "high_52"
        case low52 = "low_52"
    }
}

struct QuoteResponse: Codable {
    let symbol: String
    let data: QuoteDataPayload
}

// MARK: - Trading API

struct PreviewResponse: Codable {
    let ok: Bool?
    let preview_id: String
    let confirm_code: String
    let symbol: String?
    let side: String?
    let qty: Int?
    let expires_in_sec: Int?
    let acct: String?
}

struct BrokerResult: Codable {
    let message: String?
    let order_id: String?
    let risk_est_price: Double?
    let risk_price_source: String?
    let risk_price_limit: Double?
    let risk_est_notional: Double?
    let risk_max_notional: Double?
    let mode: String?
}

struct ConfirmResult: Codable {
    let ok: Bool
    let preview_id: String?
    let symbol: String?
    let side: String?
    let qty: Int?
    let status: String?
    let broker_result: BrokerResult?
}

// MARK: - UI Models

struct QuoteLine: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

struct SymbolStatus: Identifiable {
    let id = UUID()
    let symbol: String
    let status: String
    let detail: String
    let lines: [QuoteLine]
    let lastPrice: Double?
}

struct PendingTrade: Identifiable {
    let id = UUID()
    let symbol: String
    let side: String
    let qty: Int
}

// MARK: - Positions / Account API

struct Position: Codable, Identifiable {
    var id: String { symbol }

    let symbol: String
    let qty: Double
    let avgCost: Double?
    let marketPrice: Double?
    let marketValue: Double?
    let costBasis: Double?
    let gainLoss: Double?
    let gainLossPct: Double?

    let week52High: Double?
    let week52Low: Double?
    let distTo52WHighDollar: Double?
    let distTo52WHighPct: Double?
    let distFrom52WLowDollar: Double?
    let distFrom52WLowPct: Double?

    enum CodingKeys: String, CodingKey {
        case symbol
        case qty
        case avgCost = "avg_cost"
        case marketPrice = "market_price"
        case marketValue = "market_value"
        case costBasis = "cost_basis"
        case gainLoss = "gain_loss"
        case gainLossPct = "gain_loss_pct"
        case week52High = "week52_high"
        case week52Low = "week52_low"
        case distTo52WHighDollar = "dist_to_52w_high_dollar"
        case distTo52WHighPct = "dist_to_52w_high_pct"
        case distFrom52WLowDollar = "dist_from_52w_low_dollar"
        case distFrom52WLowPct = "dist_from_52w_low_pct"
    }
}

struct PositionsSummary: Codable {
    let marketValue: Double?
    let costBasis: Double?
    let gainLoss: Double?
    let gainLossPct: Double?

    enum CodingKeys: String, CodingKey {
        case marketValue = "market_value"
        case costBasis = "cost_basis"
        case gainLoss = "gain_loss"
        case gainLossPct = "gain_loss_pct"
    }
}

struct PositionsResponse: Codable {
    let ok: Bool
    let count: Int
    let positions: [Position]
    let summary: PositionsSummary?

    let assetTotal: Double?
    let cashAvailable: Double?
    let settledCash: Double?
    let buyingPower: Double?
    let totalAccountValue: Double?
    let pendingBuyNotional: Double?
    let freeCashAfterPending: Double?

    enum CodingKeys: String, CodingKey {
        case ok
        case count
        case positions
        case summary
        case assetTotal = "asset_total"
        case cashAvailable = "cash_available"
        case settledCash = "settled_cash"
        case buyingPower = "buying_power"
        case totalAccountValue = "total_account_value"
        case pendingBuyNotional = "pending_buy_notional"
        case freeCashAfterPending = "free_cash_after_pending"
    }
}

struct AccountSnapshot {
    let positions: [Position]
    let summary: PositionsSummary?
    let assetTotal: Double?
    let cashAvailable: Double?
    let settledCash: Double?
    let buyingPower: Double?
    let totalAccountValue: Double?
    let pendingBuyNotional: Double?
    let freeCashAfterPending: Double?
}

// MARK: - BuyLow API

struct BuyLowEntry: Codable, Identifiable {
    var id = UUID()
    let event: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case event
        case message
    }
}

struct BuyLowResponse: Codable {
    let ok: Bool
    let count: Int
    let entries: [BuyLowEntry]
}
