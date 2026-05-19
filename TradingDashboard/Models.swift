import Foundation

// MARK: - Quote API

nonisolated struct QuoteDataPayload: Codable {
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

nonisolated struct QuoteResponse: Codable {
    let symbol: String
    let data: QuoteDataPayload
}

// MARK: - Trading API

nonisolated struct PreviewResponse: Decodable, Identifiable {
    var id: String { preview_id }

    let ok: Bool?
    let preview_id: String
    let confirm_code: String
    let symbol: String?
    let side: String?
    let qty: Int?
    let expires_in_sec: Int?
    let acct: String?
    let estimatedPrice: Double?
    let suggestedLimitPrice: Double?
    let estimatedNotional: Double?
    let cashAfterOrder: Double?
    let status: String?
    let message: String?
    let broker_result: BrokerResult?

    enum CodingKeys: String, CodingKey {
        case ok
        case preview_id
        case confirm_code
        case symbol
        case side
        case qty
        case expires_in_sec
        case acct
        case estimatedPrice = "estimated_price"
        case riskEstPrice = "risk_est_price"
        case estPrice = "est_price"
        case suggestedLimitPrice = "suggested_limit_price"
        case riskPriceLimit = "risk_price_limit"
        case limitPrice = "limit_price"
        case estimatedNotional = "estimated_notional"
        case riskEstNotional = "risk_est_notional"
        case cashAfterOrder = "cash_after_order"
        case freeCashAfterOrder = "free_cash_after_order"
        case status
        case message
        case broker_result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        ok = try container.decodeIfPresent(Bool.self, forKey: .ok)
        preview_id = try container.decode(String.self, forKey: .preview_id)
        confirm_code = try container.decode(String.self, forKey: .confirm_code)
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
        side = try container.decodeIfPresent(String.self, forKey: .side)
        qty = try container.decodeIfPresent(Int.self, forKey: .qty)
        expires_in_sec = try container.decodeIfPresent(Int.self, forKey: .expires_in_sec)
        acct = try container.decodeIfPresent(String.self, forKey: .acct)
        estimatedPrice = Self.decodeDouble(container, .estimatedPrice)
            ?? Self.decodeDouble(container, .riskEstPrice)
            ?? Self.decodeDouble(container, .estPrice)
        suggestedLimitPrice = Self.decodeDouble(container, .suggestedLimitPrice)
            ?? Self.decodeDouble(container, .riskPriceLimit)
            ?? Self.decodeDouble(container, .limitPrice)
        estimatedNotional = Self.decodeDouble(container, .estimatedNotional)
            ?? Self.decodeDouble(container, .riskEstNotional)
        cashAfterOrder = Self.decodeDouble(container, .cashAfterOrder)
            ?? Self.decodeDouble(container, .freeCashAfterOrder)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        broker_result = try container.decodeIfPresent(BrokerResult.self, forKey: .broker_result)
    }

    private static func decodeDouble(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> Double? {
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let text = try? container.decodeIfPresent(String.self, forKey: key) {
            return Double(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}

nonisolated struct BrokerResult: Codable {
    let message: String?
    let order_id: String?
    let risk_est_price: Double?
    let risk_price_source: String?
    let risk_price_limit: Double?
    let risk_est_notional: Double?
    let risk_max_notional: Double?
    let mode: String?
}

nonisolated struct ConfirmResult: Codable {
    let ok: Bool
    let preview_id: String?
    let symbol: String?
    let side: String?
    let qty: Int?
    let status: String?
    let broker_result: BrokerResult?
}

// MARK: - UI Models

nonisolated struct QuoteLine: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

nonisolated struct SymbolStatus: Identifiable {
    let id = UUID()
    let symbol: String
    let status: String
    let detail: String
    let lines: [QuoteLine]
    let lastPrice: Double?
}

// MARK: - Trend Rider Watchlist API

nonisolated struct TrendWatchlistItem: Decodable, Identifiable {
    var id: String { symbol }

    let symbol: String
    let score: Double?
    let status: String?
    let action: String?
    let actionHint: String?
    let badgeClass: String?
    let priority: Int?
    let last: Double?
    let close: Double?
    let previousClose: Double?
    let sma20: Double?
    let sma50: Double?
    let fromHighPct: Double?
    let cooldownReason: String?
    let cooldownEffect: String?
    let reasons: [String]
    let reasonCodes: [String]
    let buyEnabled: Bool?
    let visible: Bool?
    let dataAvailable: Bool?

    enum CodingKeys: String, CodingKey {
        case symbol
        case score
        case status
        case action
        case actionHint = "action_hint"
        case badgeClass = "badge_class"
        case priority
        case last
        case close
        case previousClose = "previous_close"
        case previousCloseCamel = "previousClose"
        case prevClose = "prev_close"
        case sma20
        case sma50
        case fromHighPct = "from_high_pct"
        case cooldownReason = "cooldown_reason"
        case cooldownEffect = "cooldown_effect"
        case reasons
        case reasonCodes = "reason_codes"
        case buyEnabled = "buy_enabled"
        case visible
        case dataAvailable = "data_available"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        symbol = try container.decode(String.self, forKey: .symbol)
        score = Self.decodeDouble(container, .score)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        action = try container.decodeIfPresent(String.self, forKey: .action)
        actionHint = try container.decodeIfPresent(String.self, forKey: .actionHint)
        badgeClass = try container.decodeIfPresent(String.self, forKey: .badgeClass)
        priority = Self.decodeInt(container, .priority)
        last = Self.decodeDouble(container, .last)
        close = Self.decodeDouble(container, .close)
        previousClose = Self.decodeDouble(container, .previousClose)
            ?? Self.decodeDouble(container, .previousCloseCamel)
            ?? Self.decodeDouble(container, .prevClose)
        sma20 = Self.decodeDouble(container, .sma20)
        sma50 = Self.decodeDouble(container, .sma50)
        fromHighPct = Self.decodeDouble(container, .fromHighPct)
        cooldownReason = try container.decodeIfPresent(String.self, forKey: .cooldownReason)
        cooldownEffect = try container.decodeIfPresent(String.self, forKey: .cooldownEffect)
        reasons = try container.decodeIfPresent([String].self, forKey: .reasons) ?? []
        reasonCodes = try container.decodeIfPresent([String].self, forKey: .reasonCodes) ?? []
        buyEnabled = try container.decodeIfPresent(Bool.self, forKey: .buyEnabled)
        visible = try container.decodeIfPresent(Bool.self, forKey: .visible)
        dataAvailable = try container.decodeIfPresent(Bool.self, forKey: .dataAvailable)
    }

    private static func decodeDouble(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> Double? {
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let text = try? container.decodeIfPresent(String.self, forKey: key) {
            return Double(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private static func decodeInt(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> Int? {
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let text = try? container.decodeIfPresent(String.self, forKey: key) {
            return Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}

nonisolated struct TrendWatchlistResponse: Decodable {
    let ok: Bool?
    let generatedAt: String?
    let symbols: [String]
    let items: [TrendWatchlistItem]
    let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case ok
        case generatedAt = "generated_at"
        case symbols
        case watchlistSymbols = "watchlist_symbols"
        case etfUniverse = "etf_universe"
        case items
        case watchlist
        case trendWatchlist = "trend_watchlist"
        case etfs
        case watchlistEtfs = "watchlist_etfs"
        case rankings
        case warnings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        ok = try container.decodeIfPresent(Bool.self, forKey: .ok)
        generatedAt = try container.decodeIfPresent(String.self, forKey: .generatedAt)
        items = try container.decodeIfPresent([TrendWatchlistItem].self, forKey: .items)
            ?? container.decodeIfPresent([TrendWatchlistItem].self, forKey: .watchlist)
            ?? container.decodeIfPresent([TrendWatchlistItem].self, forKey: .trendWatchlist)
            ?? container.decodeIfPresent([TrendWatchlistItem].self, forKey: .etfs)
            ?? container.decodeIfPresent([TrendWatchlistItem].self, forKey: .watchlistEtfs)
            ?? container.decodeIfPresent([TrendWatchlistItem].self, forKey: .rankings)
            ?? []
        symbols = try container.decodeIfPresent([String].self, forKey: .watchlistSymbols)
            ?? container.decodeIfPresent([String].self, forKey: .symbols)
            ?? container.decodeIfPresent([String].self, forKey: .etfUniverse)
            ?? items.map(\.symbol)
        warnings = try container.decodeIfPresent([String].self, forKey: .warnings) ?? []
    }
}

nonisolated struct PendingTrade: Identifiable {
    let id = UUID()
    let symbol: String
    let side: String
    let qty: Int
}

// MARK: - Positions / Account API

nonisolated struct Position: Codable, Identifiable {
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

nonisolated struct PositionsSummary: Codable {
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

nonisolated struct PositionsResponse: Codable {
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

nonisolated struct AccountSnapshot {
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

// MARK: - Capital Readiness API

nonisolated struct CapitalReadiness: Codable {
    let generatedAt: String
    let mode: String
    let schwabCashAvailable: Double
    let schwabBudgetRemaining: Double
    let merrillReserveAvailable: Double
    let merrillReserveConfigured: Bool
    let manualActionRequired: Bool
    let blockedSymbols: [BlockedSymbol]
    let isStale: Bool?

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case mode
        case schwabCashAvailable = "schwab_cash_available"
        case schwabBudgetRemaining = "schwab_budget_remaining"
        case merrillReserveAvailable = "merrill_reserve_available"
        case merrillReserveConfigured = "merrill_reserve_configured"
        case manualActionRequired = "manual_action_required"
        case blockedSymbols = "blocked_symbols"
        case isStale = "is_stale"
    }
}

nonisolated struct BlockedSymbol: Codable, Identifiable {
    var id: String { symbol }

    let symbol: String
    let updatedAt: String?
    let blockReason: String
    let targetPrice: Double
    let currentPrice: Double
    let distanceToTargetPct: Double
    let suggestedFundingNeeded: Double
    let suggestedSourceAccount: String
    let suggestedSourceHolding: String
    let manualActionRequired: Bool

    enum CodingKeys: String, CodingKey {
        case symbol
        case updatedAt = "updated_at"
        case blockReason = "block_reason"
        case targetPrice = "target_price"
        case currentPrice = "current_price"
        case distanceToTargetPct = "distance_to_target_pct"
        case suggestedFundingNeeded = "suggested_funding_needed"
        case suggestedSourceAccount = "suggested_source_account"
        case suggestedSourceHolding = "suggested_source_holding"
        case manualActionRequired = "manual_action_required"
    }
}

// MARK: - BuyLow API

nonisolated struct BuyLowSummaryPayload: Decodable {
    let status: String?
    let rawStatus: String?
    let symbol: String?
    let displayText: String?
    let holdText: String?
    let passLine: String?
    let account: String?
    let brake: String?
    let cap: String?
    let capDetail: String?
    let why: String?
    let spread: String?
    let hold: String?
    let skip: String?
    let warn: String?
    let trigger: String?
    let signal: String?
    let finalQty: Double?
    let block: String?
    let ask: Double?
    let target: Double?
    let currentExposurePct: Double?
    let expCapPct: Double?
    let matchedSymbolLineCount: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case rawStatus = "raw_status"
        case symbol
        case displayText = "display_text"
        case holdText = "hold_text"
        case passLine = "pass_line"
        case account
        case brake
        case cap
        case capDetail = "cap_detail"
        case why
        case spread
        case hold
        case skip
        case warn
        case trigger
        case signal
        case finalQty = "final_qty"
        case block
        case ask
        case askPrice = "ask_price"
        case target
        case targetPrice = "target_price"
        case atrTarget = "atr_target"
        case currentExposurePct = "current_exposure_pct"
        case currentExposurePctCamel = "currentExposurePct"
        case exposurePct = "exposure_pct"
        case expCapPct = "exp_cap_pct"
        case expCapPctCamel = "expCapPct"
        case matchedSymbolLineCount = "matched_symbol_line_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        status = try container.decodeIfPresent(String.self, forKey: .status)
        rawStatus = try container.decodeIfPresent(String.self, forKey: .rawStatus)
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
        displayText = try container.decodeIfPresent(String.self, forKey: .displayText)
        holdText = try container.decodeIfPresent(String.self, forKey: .holdText)
        passLine = try container.decodeIfPresent(String.self, forKey: .passLine)
        account = try container.decodeIfPresent(String.self, forKey: .account)
        brake = try container.decodeIfPresent(String.self, forKey: .brake)
        cap = try container.decodeIfPresent(String.self, forKey: .cap)
        capDetail = try container.decodeIfPresent(String.self, forKey: .capDetail)
        why = try container.decodeIfPresent(String.self, forKey: .why)
        spread = try container.decodeIfPresent(String.self, forKey: .spread)
        hold = try container.decodeIfPresent(String.self, forKey: .hold)
        skip = try container.decodeIfPresent(String.self, forKey: .skip)
        warn = try container.decodeIfPresent(String.self, forKey: .warn)
        trigger = try container.decodeIfPresent(String.self, forKey: .trigger)
        signal = try container.decodeIfPresent(String.self, forKey: .signal)
        finalQty = Self.decodeDouble(container, .finalQty)
        block = try container.decodeIfPresent(String.self, forKey: .block)
        ask = Self.decodeDouble(container, .ask) ?? Self.decodeDouble(container, .askPrice)
        target = Self.decodeDouble(container, .target)
            ?? Self.decodeDouble(container, .targetPrice)
            ?? Self.decodeDouble(container, .atrTarget)
        currentExposurePct = Self.decodeDouble(container, .currentExposurePct)
            ?? Self.decodeDouble(container, .currentExposurePctCamel)
            ?? Self.decodeDouble(container, .exposurePct)
        expCapPct = Self.decodeDouble(container, .expCapPct)
            ?? Self.decodeDouble(container, .expCapPctCamel)
        matchedSymbolLineCount = Self.decodeInt(container, .matchedSymbolLineCount)
    }

    private static func decodeDouble(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> Double? {
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let text = try? container.decodeIfPresent(String.self, forKey: key) {
            return Double(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private static func decodeInt(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> Int? {
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let text = try? container.decodeIfPresent(String.self, forKey: key) {
            return Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}

nonisolated struct BuyLowSummaryResponse: Decodable {
    let ok: Bool
    let file: String?
    let path: String?
    let symbol: String?
    let summary: BuyLowSummaryPayload?
    let error: String?
    let reason: String?
    let display: Bool?
    let omit: Bool?
}

nonisolated struct BuyLowStatus: Identifiable {
    var id: String { symbol }

    let symbol: String
    let status: String
    let message: String
    let file: String?
    let currentExposurePct: Double?
    let expCapPct: Double?

    func markedStale() -> BuyLowStatus {
        let lastKnownMessage = message.hasPrefix("Last known: ")
            ? message
            : "Last known: \(message)"

        return BuyLowStatus(
            symbol: symbol,
            status: "STALE",
            message: lastKnownMessage,
            file: file,
            currentExposurePct: currentExposurePct,
            expCapPct: expCapPct
        )
    }
}

nonisolated struct BuyLowEntry: Codable, Identifiable {
    var id = UUID()
    let event: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case event
        case message
    }
}

nonisolated struct BuyLowResponse: Codable {
    let ok: Bool
    let count: Int
    let entries: [BuyLowEntry]
}
