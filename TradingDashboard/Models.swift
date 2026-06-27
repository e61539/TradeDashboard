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

// MARK: - Intelligence API

nonisolated struct MarketRegimeResponse: Decodable {
    let regime: String?
    let confidence: Double?
    let reason: String?
    let spyLast: Double?
    let spyPrevClose: Double?
    let spyDayChangePct: Double?

    enum CodingKeys: String, CodingKey {
        case regime
        case confidence
        case reason
        case spyLast = "spy_last"
        case spyPrevClose = "spy_prev_close"
        case spyDayChangePct = "spy_day_change_pct"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        regime = try container.decodeIfPresent(String.self, forKey: .regime)
        confidence = Self.decodeDouble(container, .confidence)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        spyLast = Self.decodeDouble(container, .spyLast)
        spyPrevClose = Self.decodeDouble(container, .spyPrevClose)
        spyDayChangePct = Self.decodeDouble(container, .spyDayChangePct)
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

nonisolated struct IntelligenceOpportunitiesResponse: Decodable {
    let generatedAt: String?
    let regime: MarketRegimeResponse?
    let opportunities: [IntelligenceOpportunity]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case regime
        case opportunities
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        generatedAt = try container.decodeIfPresent(String.self, forKey: .generatedAt)
        regime = try container.decodeIfPresent(MarketRegimeResponse.self, forKey: .regime)
        opportunities = try container.decodeIfPresent([IntelligenceOpportunity].self, forKey: .opportunities) ?? []
    }
}

// MARK: - Decision Actions API

nonisolated struct DecisionActionsResponse: Decodable {
    let generatedAt: String?
    let mode: String?
    let manualActionsOnly: Bool?
    let regime: MarketRegimeResponse?
    let cashAvailable: Double?
    let actions: [DecisionAction]
    let warnings: [String]
    let elapsedMs: Double?

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case mode
        case manualActionsOnly = "manual_actions_only"
        case regime
        case cashAvailable = "cash_available"
        case actions
        case warnings
        case elapsedMs = "elapsed_ms"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        generatedAt = try container.decodeIfPresent(String.self, forKey: .generatedAt)
        mode = try container.decodeIfPresent(String.self, forKey: .mode)
        manualActionsOnly = Self.decodeBool(container, .manualActionsOnly)
        regime = try container.decodeIfPresent(MarketRegimeResponse.self, forKey: .regime)
        cashAvailable = Self.decodeDouble(container, .cashAvailable)
        actions = try container.decodeIfPresent([DecisionAction].self, forKey: .actions) ?? []
        warnings = try container.decodeIfPresent([String].self, forKey: .warnings) ?? []
        elapsedMs = Self.decodeDouble(container, .elapsedMs)
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

    private static func decodeBool(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> Bool? {
        if let value = try? container.decodeIfPresent(Bool.self, forKey: key) {
            return value
        }
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
            return intValue != 0
        }
        if let text = try? container.decodeIfPresent(String.self, forKey: key) {
            let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["true", "yes", "1"].contains(normalized) {
                return true
            }
            if ["false", "no", "0"].contains(normalized) {
                return false
            }
        }
        return nil
    }
}

nonisolated struct DecisionAction: Decodable, Identifiable {
    var id: String { "\(type ?? "ACTION")-\(symbol ?? "UNKNOWN")-\(priority ?? "")-\(message ?? "")" }

    let priority: String?
    let type: String?
    let symbol: String?
    let score: Double?
    let message: String?
    let cashAvailable: Double?
    let last: Double?
    let capHeadroom: Double?

    enum CodingKeys: String, CodingKey {
        case priority
        case type
        case symbol
        case score
        case message
        case cashAvailable = "cash_available"
        case last
        case capHeadroom = "cap_headroom"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        priority = try container.decodeIfPresent(String.self, forKey: .priority)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol).map { $0.uppercased() }
        score = Self.decodeDouble(container, .score)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        cashAvailable = Self.decodeDouble(container, .cashAvailable)
        last = Self.decodeDouble(container, .last)
        capHeadroom = Self.decodeDouble(container, .capHeadroom)
    }

    private static func decodeDouble(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> Double? {
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
            return Double(intValue)
        }
        if let text = try? container.decodeIfPresent(String.self, forKey: key) {
            return Double(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}

typealias IntelligenceResponse = IntelligenceOpportunity

nonisolated struct IntelligenceOpportunity: Decodable, Identifiable {
    var id: String { symbol }

    let symbol: String
    let score: Double?
    let rating: String?
    let buyLowReady: Bool?
    let dataQuality: String?
    let firstStageThresholdPct: Double?
    let pullbackVsThresholdPct: Double?
    let distanceTo52WHighPct: Double?
    let opportunityReason: String?
    let riskReason: String?
    let dipPct: Double?
    let triggerPct: Double?
    let triggerReference: String?
    let targetPrice: Double?
    let triggerDescription: String?
    let targetDescription: String?
    let state: String?

    enum CodingKeys: String, CodingKey {
        case symbol
        case score
        case rating
        case buyLowReady = "buy_low_ready"
        case buyLowReadyCamel = "buyLowReady"
        case dataQuality = "data_quality"
        case dataQualityCamel = "dataQuality"
        case firstStageThresholdPct = "first_stage_threshold_pct"
        case firstStageThresholdPctCamel = "firstStageThresholdPct"
        case pullbackVsThresholdPct = "pullback_vs_threshold_pct"
        case pullbackVsThresholdPctCamel = "pullbackVsThresholdPct"
        case distanceTo52WHighPct = "distance_to_52w_high_pct"
        case distanceTo52WHighPctCamel = "distanceTo52wHighPct"
        case opportunityReason = "opportunity_reason"
        case opportunityReasonCamel = "opportunityReason"
        case riskReason = "risk_reason"
        case riskReasonCamel = "riskReason"
        case dipPct = "dip_pct"
        case dipPctCamel = "dipPct"
        case triggerPct = "trigger_pct"
        case triggerPctCamel = "triggerPct"
        case triggerReference = "trigger_reference"
        case triggerReferenceCamel = "triggerReference"
        case targetPrice = "target_price"
        case targetPriceCamel = "targetPrice"
        case triggerDescription = "trigger_description"
        case triggerDescriptionCamel = "triggerDescription"
        case targetDescription = "target_description"
        case targetDescriptionCamel = "targetDescription"
        case state
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        symbol = (try container.decode(String.self, forKey: .symbol)).uppercased()
        score = Self.decodeDouble(container, .score)
        rating = try container.decodeIfPresent(String.self, forKey: .rating)
        buyLowReady = Self.decodeBool(container, .buyLowReady) ?? Self.decodeBool(container, .buyLowReadyCamel)
        dataQuality = try container.decodeIfPresent(String.self, forKey: .dataQuality)
            ?? container.decodeIfPresent(String.self, forKey: .dataQualityCamel)
        firstStageThresholdPct = Self.decodeDouble(container, .firstStageThresholdPct)
            ?? Self.decodeDouble(container, .firstStageThresholdPctCamel)
        pullbackVsThresholdPct = Self.decodeDouble(container, .pullbackVsThresholdPct)
            ?? Self.decodeDouble(container, .pullbackVsThresholdPctCamel)
        distanceTo52WHighPct = Self.decodeDouble(container, .distanceTo52WHighPct)
            ?? Self.decodeDouble(container, .distanceTo52WHighPctCamel)
        opportunityReason = try container.decodeIfPresent(String.self, forKey: .opportunityReason)
            ?? container.decodeIfPresent(String.self, forKey: .opportunityReasonCamel)
        riskReason = try container.decodeIfPresent(String.self, forKey: .riskReason)
            ?? container.decodeIfPresent(String.self, forKey: .riskReasonCamel)
        dipPct = Self.decodeDouble(container, .dipPct)
            ?? Self.decodeDouble(container, .dipPctCamel)
        triggerPct = Self.decodeDouble(container, .triggerPct)
            ?? Self.decodeDouble(container, .triggerPctCamel)
        triggerReference = try container.decodeIfPresent(String.self, forKey: .triggerReference)
            ?? container.decodeIfPresent(String.self, forKey: .triggerReferenceCamel)
        targetPrice = Self.decodeDouble(container, .targetPrice)
            ?? Self.decodeDouble(container, .targetPriceCamel)
        triggerDescription = try container.decodeIfPresent(String.self, forKey: .triggerDescription)
            ?? container.decodeIfPresent(String.self, forKey: .triggerDescriptionCamel)
        targetDescription = try container.decodeIfPresent(String.self, forKey: .targetDescription)
            ?? container.decodeIfPresent(String.self, forKey: .targetDescriptionCamel)
        state = try container.decodeIfPresent(String.self, forKey: .state)
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

    private static func decodeBool(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> Bool? {
        if let value = try? container.decodeIfPresent(Bool.self, forKey: key) {
            return value
        }
        if let text = try? container.decodeIfPresent(String.self, forKey: key) {
            switch text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1", "ready":
                return true
            case "false", "no", "0", "watch":
                return false
            default:
                return nil
            }
        }
        return nil
    }
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
    let canTrade: Bool?
    let visible: Bool?
    let dataAvailable: Bool?
    let currentPrice: Double?
    let referencePrice: Double?
    let referenceSource: String?
    let dipPct: Double?
    let triggerPct: Double?
    let triggerReference: String?
    let targetPrice: Double?
    let triggerDescription: String?
    let targetDescription: String?

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
        case canTrade = "can_trade"
        case canTradeCamel = "canTrade"
        case visible
        case dataAvailable = "data_available"
        case currentPrice = "current_price"
        case currentPriceCamel = "currentPrice"
        case referencePrice = "reference_price"
        case referencePriceCamel = "referencePrice"
        case referenceSource = "reference_source"
        case referenceSourceCamel = "referenceSource"
        case dipPct = "dip_pct"
        case dipPctCamel = "dipPct"
        case triggerPct = "trigger_pct"
        case triggerPctCamel = "triggerPct"
        case triggerReference = "trigger_reference"
        case triggerReferenceCamel = "triggerReference"
        case targetPrice = "target_price"
        case targetPriceCamel = "targetPrice"
        case triggerDescription = "trigger_description"
        case triggerDescriptionCamel = "triggerDescription"
        case targetDescription = "target_description"
        case targetDescriptionCamel = "targetDescription"
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
        canTrade = Self.decodeBool(container, .canTrade) ?? Self.decodeBool(container, .canTradeCamel)
        visible = try container.decodeIfPresent(Bool.self, forKey: .visible)
        dataAvailable = try container.decodeIfPresent(Bool.self, forKey: .dataAvailable)
        currentPrice = Self.decodeDouble(container, .currentPrice)
            ?? Self.decodeDouble(container, .currentPriceCamel)
        dipPct = Self.decodeDouble(container, .dipPct)
            ?? Self.decodeDouble(container, .dipPctCamel)
        triggerPct = Self.decodeDouble(container, .triggerPct)
            ?? Self.decodeDouble(container, .triggerPctCamel)
        referencePrice = Self.decodeDouble(container, .referencePrice)
            ?? Self.decodeDouble(container, .referencePriceCamel)
        referenceSource = try container.decodeIfPresent(String.self, forKey: .referenceSource)
            ?? container.decodeIfPresent(String.self, forKey: .referenceSourceCamel)
        triggerReference = try container.decodeIfPresent(String.self, forKey: .triggerReference)
            ?? container.decodeIfPresent(String.self, forKey: .triggerReferenceCamel)
        targetPrice = Self.decodeDouble(container, .targetPrice)
            ?? Self.decodeDouble(container, .targetPriceCamel)
        triggerDescription = try container.decodeIfPresent(String.self, forKey: .triggerDescription)
            ?? container.decodeIfPresent(String.self, forKey: .triggerDescriptionCamel)
        targetDescription = try container.decodeIfPresent(String.self, forKey: .targetDescription)
            ?? container.decodeIfPresent(String.self, forKey: .targetDescriptionCamel)
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

    private static func decodeBool(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> Bool? {
        if let value = try? container.decodeIfPresent(Bool.self, forKey: key) {
            return value
        }
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
            return intValue != 0
        }
        if let text = try? container.decodeIfPresent(String.self, forKey: key) {
            let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["true", "yes", "1"].contains(normalized) {
                return true
            }
            if ["false", "no", "0"].contains(normalized) {
                return false
            }
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
    let manualActionRequired: Bool
    let blockedSymbols: [BlockedSymbol]
    let isStale: Bool?

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case mode
        case schwabCashAvailable = "schwab_cash_available"
        case schwabBudgetRemaining = "schwab_budget_remaining"
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
