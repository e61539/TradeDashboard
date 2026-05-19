import SwiftUI

struct ContentView: View {
    @StateObject private var endpointResolver = EndpointResolver.shared

    @State private var items: [SymbolStatus] = []
    @State private var positions: [Position] = []
    @State private var isLoading = false
    @State private var timer: Timer?
    @State private var previousLastPrices: [String: Double] = [:]
    @State private var tradeMessage: String = ""
    @State private var pendingTrade: PendingTrade?
    @State private var orderPreview: PreviewResponse?
    @State private var selectedQty: Int = 1
    @State private var positionsError: String = ""
    @State private var trendWatchlistItems: [TrendWatchlistItem] = []
    @State private var trendWatchlistSymbols: [String] = []
    @State private var trendWatchlistError: String = ""
    @State private var expandedTrendSymbols: Set<String> = []

    @State private var assetTotal: Double = 0
    @State private var cashAvailable: Double?
    @State private var settledCash: Double?
    @State private var buyingPower: Double?
    @State private var totalAccountValue: Double?
    @State private var pendingBuyNotional: Double?
    @State private var freeCashAfterPending: Double?

    private let defaultSymbols = ["QQQ", "SPY", "GLD", "MSFT", "AAPL", "NVDA"]

    private var baseURL: String { endpointResolver.dashboardBaseURL }
    private var tradeBaseURL: String { endpointResolver.tradeBaseURL }
    private let tradeAPIKey = AppConfig.apiKey
    private var symbols: [String] {
        trendWatchlistSymbols.isEmpty ? defaultSymbols : trendWatchlistSymbols
    }
    private var ownedPositions: [Position] {
        positions
            .filter { $0.qty > 0 }
            .sorted { $0.symbol < $1.symbol }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    topBar

                    BuyLowView(baseURL: tradeBaseURL, apiKey: tradeAPIKey, symbols: symbols)

                    qtyBar

                    if isLoading {
                        ProgressView("Loading...")
                    }

                    if !tradeMessage.isEmpty {
                        Text(tradeMessage)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }

                    buyWatchlistSection
                    accountSection
                    sellOwnedPositionsSection
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await endpointResolver.refreshIfNeeded()
                    await MainActor.run {
                        loadAll()
                    }
                }

                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                    Task {
                        await endpointResolver.refreshIfNeeded()
                        await MainActor.run {
                            loadAll()
                        }
                    }
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
            .alert(
                pendingTrade == nil
                    ? "Preview Trade"
                    : "Preview \(pendingTrade!.side.uppercased()) \(pendingTrade!.symbol)",
                isPresented: Binding(
                    get: { pendingTrade != nil },
                    set: { newValue in
                        if !newValue { pendingTrade = nil }
                    }
                ),
                presenting: pendingTrade
            ) { trade in
                Button("Cancel", role: .cancel) {
                    pendingTrade = nil
                }

                Button("Preview") {
                    previewOrder(symbol: trade.symbol, side: trade.side, qty: trade.qty)
                    pendingTrade = nil
                }
            } message: { trade in
                Text("Preview a \(trade.side.uppercased()) order for \(trade.qty) share(s) of \(trade.symbol).")
            }
            .sheet(item: $orderPreview) { preview in
                orderPreviewSheet(preview)
            }
        }
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Trading Dashboard")
                    .font(.title2)
                    .bold()

                Spacer()

                NavigationLink {
                    CapitalReadinessView(baseURL: baseURL, apiKey: tradeAPIKey)
                } label: {
                    Text("Capital")
                }
                .buttonStyle(.bordered)

                Button("Refresh") {
                    Task {
                        await endpointResolver.refresh()
                        await MainActor.run {
                            loadAll()
                        }
                    }
                }
            }

            Text("Connection: \(endpointResolver.activeRoute.rawValue)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func orderPreviewSheet(_ preview: PreviewResponse) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("\((preview.side ?? "").uppercased()) \(preview.symbol ?? "")")
                    .font(.title2)
                    .bold()

                VStack(alignment: .leading, spacing: 8) {
                    previewRow("Estimated price", formatOptionalMoney(previewEstimatedPrice(preview)))
                    previewRow("Suggested limit", formatOptionalMoney(previewSuggestedLimit(preview)))
                    previewRow("Estimated notional", formatOptionalMoney(previewEstimatedNotional(preview)))
                    previewRow("Cash after order", formatOptionalMoney(preview.cashAfterOrder))
                    previewRow("Confirm code", preview.confirm_code)
                }

                if let message = preview.message ?? preview.broker_result?.message ?? preview.status, !message.isEmpty {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    confirmOrder(preview)
                } label: {
                    Text("Confirm Order")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Order Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Cancel") {
                    orderPreview = nil
                }
            }
        }
    }

    private func previewRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func previewEstimatedPrice(_ preview: PreviewResponse) -> Double? {
        preview.estimatedPrice ?? preview.broker_result?.risk_est_price
    }

    private func previewSuggestedLimit(_ preview: PreviewResponse) -> Double? {
        preview.suggestedLimitPrice ?? preview.broker_result?.risk_price_limit
    }

    private func previewEstimatedNotional(_ preview: PreviewResponse) -> Double? {
        preview.estimatedNotional ?? preview.broker_result?.risk_est_notional ?? preview.broker_result?.risk_max_notional
    }

    private var qtyBar: some View {
        HStack(spacing: 12) {
            Text("Qty")
                .font(.headline)

            Button("-") {
                if selectedQty > 1 {
                    selectedQty -= 1
                }
            }
            .buttonStyle(.bordered)

            Text("\(selectedQty)")
                .font(.headline)
                .frame(minWidth: 24)

            Button("+") {
                if selectedQty < 100 {
                    selectedQty += 1
                }
            }
            .buttonStyle(.bordered)

            Spacer()

            if AppConfig.enableTrading {
                Text("Trading Enabled")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
        }
    }

    private var buyWatchlistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Buy / Watchlist")
                .font(.title2)
                .bold()

            if !trendWatchlistError.isEmpty {
                Text(trendWatchlistError)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.symbol)
                                .font(.system(size: 22, weight: .bold))
                                .lineLimit(1)

                            Text(currentPriceText(item))
                                .font(.system(size: 19, weight: .semibold, design: .monospaced))
                                .foregroundColor(colorForLine(symbol: item.symbol, line: item.lines.first(where: { $0.label == "Last" }), currentLast: item.lastPrice))
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                        }

                        Spacer(minLength: 8)

                        Button("Buy") {
                            pendingTrade = PendingTrade(symbol: item.symbol, side: "buy", qty: selectedQty)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(!AppConfig.enableTrading)
                    }

                    if let trendItem = trendItem(for: item.symbol) {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .center, spacing: 8) {
                                trendBadge(
                                    text: trendStatusWithPriority(trendItem),
                                    color: trendDisplayColor(trendItem),
                                    prominent: true
                                )

                                Text(trendShortReason(trendItem))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)

                                Spacer(minLength: 0)
                            }

                            Text(trendMarketCondition(trendItem, quoteItem: item))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func quoteMetric(_ item: SymbolStatus, label: String, short: String) -> some View {
        let line = item.lines.first(where: { $0.label == label })

        return VStack(alignment: .leading, spacing: 2) {
            Text(short)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text(line?.value ?? "--")
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundColor(
                    label == "Last"
                        ? colorForLine(symbol: item.symbol, line: line, currentLast: item.lastPrice)
                        : .primary
                )
                .lineLimit(1)
                .minimumScaleFactor(0.95)
        }
        .frame(minWidth: 78, alignment: .leading)
    }

    private func trendBadge(text: String, color: Color, prominent: Bool = false) -> some View {
        Text(text)
            .font(.system(size: prominent ? 15 : 11, weight: .semibold))
            .foregroundColor(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, prominent ? 10 : 6)
            .padding(.vertical, prominent ? 6 : 3)
            .background(color.opacity(prominent ? 0.16 : 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func trendSummaryPill(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(color)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func trendMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(minWidth: 54, alignment: .leading)
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Account")
                .font(.title2)
                .bold()

            HStack {
                Text("Assets")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Spacer()
                moneyText(formatMoney(assetTotal), size: 21)
            }

            HStack {
                Text("Cash Available")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Spacer()
                moneyText(formatOptionalMoney(cashAvailable), size: 21)
            }

            HStack {
                Text("Pending Buys")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Spacer()
                moneyText(formatOptionalMoney(pendingBuyNotional), color: .orange, size: 21)
            }

            HStack {
                Text("Free Cash")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Spacer()
                moneyText(formatOptionalMoney(freeCashAfterPending), color: .green, size: 21)
            }

            HStack {
                Text("Total")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Spacer()
                moneyText(formatOptionalMoney(totalAccountValue), size: 21)
            }

            GeometryReader { geo in
                let total = max(assetTotal + (cashAvailable ?? 0), 0.01)
                let assetWidth = geo.size.width * CGFloat(assetTotal / total)
                let cashWidth = geo.size.width * CGFloat((cashAvailable ?? 0) / total)

                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: assetWidth)

                    Rectangle()
                        .fill(Color.green)
                        .frame(width: cashWidth)
                }
                .frame(height: 12)
                .clipShape(Capsule())
                .background(
                    Capsule().fill(Color(.systemGray5))
                )
            }
            .frame(height: 12)

            HStack {
                Label("Assets", systemImage: "circle.fill")
                    .foregroundColor(.blue)
                    .font(.headline)
                Spacer()
                Label("Cash", systemImage: "circle.fill")
                    .foregroundColor(.green)
                    .font(.headline)
            }

            HStack {
                Text("Buying Power")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                moneyText(formatOptionalMoney(buyingPower), size: 18)
            }

            HStack {
                Text("Settled Cash")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                moneyText(formatOptionalMoney(settledCash), size: 18)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func moneyText(_ value: String, color: Color = .primary, size: CGFloat = 14) -> some View {
        Text(value)
            .font(.system(size: size, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var sellOwnedPositionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sell / Owned Positions")
                .font(.title2)
                .bold()

            if !positionsError.isEmpty {
                Text(positionsError)
                    .font(.headline)
                    .foregroundColor(.red)
            }

            if ownedPositions.isEmpty && positionsError.isEmpty {
                Text("No owned positions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            ForEach(ownedPositions) { pos in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        Text(pos.symbol)
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Button("Sell") {
                            pendingTrade = PendingTrade(symbol: pos.symbol, side: "sell", qty: selectedQty)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!AppConfig.enableTrading)
                    }

                    HStack(alignment: .top, spacing: 14) {
                        positionMetric(label: "Qty", value: formatQty(pos.qty))
                        positionMetric(label: "Last", value: formatOptionalMoney(pos.marketPrice))
                        positionMetric(label: "52W", value: formatOptionalMoney(pos.week52High))
                        positionMetric(label: "From High%", value: formatCompactPercent(pos.distTo52WHighPct))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("G/L")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Text(formatSigned(pos.gainLoss))
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundColor((pos.gainLoss ?? 0) >= 0 ? .green : .red)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            Text(formatPercent(pos.gainLossPct))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor((pos.gainLoss ?? 0) >= 0 ? .green : .red)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(minWidth: 62, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func loadAll() {
        fetchTrendWatchlistAndQuotes()
        fetchPositions()
    }

    private func fetchTrendWatchlistAndQuotes() {
        isLoading = true

        APIClient.shared.fetchTrendWatchlist(baseURL: baseURL, apiKey: tradeAPIKey) { response, error in
            DispatchQueue.main.async {
                if let response {
                    self.trendWatchlistItems = response.items

                    let responseSymbols = response.symbols.isEmpty
                        ? response.items.map(\.symbol)
                        : response.symbols
                    let normalizedSymbols = self.uniqueSymbols(responseSymbols)
                    self.trendWatchlistSymbols = normalizedSymbols.isEmpty ? self.defaultSymbols : normalizedSymbols
                    self.trendWatchlistError = response.warnings.first ?? ""
                    self.fetchAllQuotes(for: self.symbols)
                    return
                }

                self.trendWatchlistError = "Trend watchlist: \(error ?? "unavailable")"
                if self.trendWatchlistSymbols.isEmpty {
                    self.trendWatchlistSymbols = self.defaultSymbols
                }
                self.fetchAllQuotes(for: self.symbols)
            }
        }
    }

    private func fetchAllQuotes(for symbolsToLoad: [String]) {
        isLoading = true

        let oldPrices = Dictionary(uniqueKeysWithValues: items.compactMap { item in
            item.lastPrice.map { (item.symbol, $0) }
        })

        let group = DispatchGroup()
        var loadedItems: [SymbolStatus] = []

        for symbol in symbolsToLoad {
            group.enter()
            fetchQuote(for: symbol) { result in
                if let result = result {
                    loadedItems.append(result)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.previousLastPrices = oldPrices
            self.items = loadedItems.sorted { $0.symbol < $1.symbol }
            self.isLoading = false
        }
    }

    private func uniqueSymbols(_ rawSymbols: [String]) -> [String] {
        var seen = Set<String>()
        var output: [String] = []

        for rawSymbol in rawSymbols {
            let symbol = rawSymbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if !symbol.isEmpty, !seen.contains(symbol) {
                seen.insert(symbol)
                output.append(symbol)
            }
        }

        return output
    }

    private func fetchQuote(for symbol: String, completion: @escaping (SymbolStatus?) -> Void) {
        guard
            let encodedKey = tradeAPIKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "\(baseURL)/api/quote/\(symbol)?k=\(encodedKey)")
        else {
            completion(SymbolStatus(symbol: symbol, status: "ERROR", detail: "Bad URL", lines: [], lastPrice: nil))
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error {
                completion(SymbolStatus(symbol: symbol, status: "ERROR", detail: error.localizedDescription, lines: [], lastPrice: nil))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(SymbolStatus(symbol: symbol, status: "ERROR", detail: "No HTTP response", lines: [], lastPrice: nil))
                return
            }

            guard let data = data, (200...299).contains(httpResponse.statusCode) else {
                completion(SymbolStatus(symbol: symbol, status: "ERROR", detail: "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)", lines: [], lastPrice: nil))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(QuoteResponse.self, from: data)
                let parsedLines = makeQuoteLines(from: decoded.data)

                completion(
                    SymbolStatus(
                        symbol: decoded.symbol,
                        status: "OK",
                        detail: "",
                        lines: parsedLines,
                        lastPrice: decoded.data.last
                    )
                )
            } catch {
                let bodyText = String(data: data, encoding: .utf8) ?? ""
                completion(SymbolStatus(symbol: symbol, status: "ERROR", detail: "Decode error: \(error.localizedDescription). Body: \(bodyText)", lines: [], lastPrice: nil))
            }
        }.resume()
    }

    private func fetchPositions() {
        APIClient.shared.fetchAccountSnapshot(baseURL: baseURL, apiKey: tradeAPIKey) { snapshot, error in
            DispatchQueue.main.async {
                if let error {
                    self.positionsError = error
                    self.positions = []
                    self.assetTotal = 0
                    self.cashAvailable = nil
                    self.settledCash = nil
                    self.buyingPower = nil
                    self.totalAccountValue = nil
                    self.pendingBuyNotional = nil
                    self.freeCashAfterPending = nil
                    return
                }

                guard let snapshot else {
                    self.positionsError = "No positions returned"
                    self.positions = []
                    self.assetTotal = 0
                    self.cashAvailable = nil
                    self.settledCash = nil
                    self.buyingPower = nil
                    self.totalAccountValue = nil
                    self.pendingBuyNotional = nil
                    self.freeCashAfterPending = nil
                    return
                }

                self.positionsError = ""
                self.positions = snapshot.positions

                let computedAssets = snapshot.positions.reduce(0.0) { $0 + ($1.marketValue ?? 0) }
                self.assetTotal = snapshot.assetTotal ?? computedAssets
                self.cashAvailable = snapshot.cashAvailable
                self.settledCash = snapshot.settledCash
                self.buyingPower = snapshot.buyingPower
                self.totalAccountValue = snapshot.totalAccountValue ?? (self.assetTotal + (self.cashAvailable ?? 0))
                self.pendingBuyNotional = snapshot.pendingBuyNotional
                self.freeCashAfterPending = snapshot.freeCashAfterPending
            }
        }
    }

    nonisolated private func makeQuoteLines(from data: QuoteDataPayload) -> [QuoteLine] {
        var lines: [QuoteLine] = []

        if let last = data.last {
            lines.append(QuoteLine(label: "Last", value: String(format: "%.2f", last)))
        }
        if let close = data.close {
            lines.append(QuoteLine(label: "Close", value: String(format: "%.2f", close)))
        }
        if let high = data.dailyHigh {
            lines.append(QuoteLine(label: "Day High", value: String(format: "%.2f", high)))
        }

        return lines
    }

    private func colorForLine(symbol: String, line: QuoteLine?, currentLast: Double?) -> Color {
        guard let line = line, line.label == "Last", let currentLast else {
            return .primary
        }

        guard let previous = previousLastPrices[symbol] else {
            return .primary
        }

        if currentLast > previous {
            return .green
        } else if currentLast < previous {
            return .red
        } else {
            return .primary
        }
    }

    private func trendItem(for symbol: String) -> TrendWatchlistItem? {
        trendWatchlistItems.first { $0.symbol.caseInsensitiveCompare(symbol) == .orderedSame }
    }

    private func currentPriceText(_ item: SymbolStatus) -> String {
        if let lastPrice = item.lastPrice {
            return formatMoney(lastPrice)
        }

        if let last = item.lines.first(where: { $0.label == "Last" })?.value {
            return "$\(last)"
        }

        return "--"
    }

    private func toggleTrendDetails(for symbol: String) {
        if expandedTrendSymbols.contains(symbol) {
            expandedTrendSymbols.remove(symbol)
        } else {
            expandedTrendSymbols.insert(symbol)
        }
    }

    private func trendAction(_ item: TrendWatchlistItem) -> String {
        item.action ?? item.actionHint ?? item.status ?? "NEUTRAL"
    }

    private func trendStatus(_ item: TrendWatchlistItem) -> String {
        item.status ?? "neutral"
    }

    private func trendDisplayStatus(_ item: TrendWatchlistItem) -> String {
        if isTrendBlocked(item) {
            return "BLOCKED"
        }

        switch trendAction(item).uppercased() {
        case "BUY_CANDIDATE":
            return "BUY CANDIDATE"
        default:
            return "HOLD"
        }
    }

    private func trendStatusWithPriority(_ item: TrendWatchlistItem) -> String {
        let status = trendDisplayStatus(item)
        guard let priority = item.priority else {
            return status
        }

        return "\(status) • P\(priority)"
    }

    private func trendDisplayColor(_ item: TrendWatchlistItem) -> Color {
        switch trendDisplayStatus(item) {
        case "BUY CANDIDATE":
            return .green
        case "BLOCKED":
            return .orange
        default:
            return .blue
        }
    }

    private func trendShortReason(_ item: TrendWatchlistItem) -> String {
        let rawReason = firstTrendReason(item)

        if isATRBlocked(item) {
            return "ATR Blocked"
        }

        if isNearHigh(item) {
            return "Near 52w High"
        }

        if trendAction(item).uppercased() == "BUY_CANDIDATE" || trendStatus(item).lowercased() == "strong" {
            return "Strong Trend"
        }

        if let rawReason {
            return conciseTrendText(rawReason)
        }

        return "Holding"
    }

    private func trendMarketCondition(_ item: TrendWatchlistItem, quoteItem: SymbolStatus) -> String {
        let action = trendAction(item).uppercased()
        let status = trendStatus(item).lowercased()
        let closeSuffix = trendCloseText(item, quoteItem: quoteItem).map { " • \($0)" } ?? ""

        if isCooldownActive(item) {
            return "Cooldown Active\(closeSuffix)"
        }

        if isNearHigh(item) {
            return "Near 52w High\(closeSuffix)"
        }

        if let fromHighPct = item.fromHighPct {
            if fromHighPct <= -12 {
                return "Pullback Candidate\(closeSuffix)"
            }
            if fromHighPct >= -5 && (status == "strong" || action == "BUY_CANDIDATE") {
                return "Breakout Watch\(closeSuffix)"
            }
        }

        if let score = item.score, score >= 80 {
            return "Extended\(closeSuffix)"
        }

        return "\(trendStrengthText(item))\(closeSuffix)"
    }

    private func trendCloseText(_ item: TrendWatchlistItem, quoteItem: SymbolStatus) -> String? {
        let quoteClose = quoteItem.lines.first { $0.label == "Close" }?.value

        if let close = item.previousClose ?? item.close {
            return String(format: "Prev Close %.2f", close)
        }

        guard let quoteClose else {
            return nil
        }

        return "Prev Close \(quoteClose)"
    }

    private func trendStrengthText(_ item: TrendWatchlistItem) -> String {
        if trendStatus(item).lowercased() == "strong" || (item.score ?? 0) >= 70 {
            return "Strong Trend"
        }

        if trendStatus(item).lowercased() == "weak" {
            return "Weak Trend"
        }

        return "Holding"
    }

    private func trendStrengthColor(_ item: TrendWatchlistItem) -> Color {
        switch trendStrengthText(item) {
        case "Strong Trend":
            return .green
        case "Weak Trend":
            return .red
        default:
            return .blue
        }
    }

    private func isTrendBlocked(_ item: TrendWatchlistItem) -> Bool {
        let action = trendAction(item).uppercased()
        let status = trendStatus(item).lowercased()

        return isATRBlocked(item)
            || action.contains("AVOID")
            || action.contains("COOLDOWN")
            || status.contains("avoid")
            || status.contains("cooldown")
    }

    private func isCooldownActive(_ item: TrendWatchlistItem) -> Bool {
        let text = ([item.cooldownReason, item.cooldownEffect].compactMap { $0 } + item.reasons + item.reasonCodes)
            .joined(separator: " ")
            .lowercased()

        return trendAction(item).uppercased().contains("COOLDOWN")
            || trendStatus(item).lowercased().contains("cooldown")
            || text.contains("cooldown")
    }

    private func isATRBlocked(_ item: TrendWatchlistItem) -> Bool {
        let text = ([item.cooldownReason, item.cooldownEffect].compactMap { $0 } + item.reasons + item.reasonCodes)
            .joined(separator: " ")
            .lowercased()

        return text.contains("atr")
    }

    private func isNearHigh(_ item: TrendWatchlistItem) -> Bool {
        guard let fromHighPct = item.fromHighPct else {
            return false
        }

        return abs(fromHighPct) <= 3
    }

    private func firstTrendReason(_ item: TrendWatchlistItem) -> String? {
        ([item.cooldownReason, item.cooldownEffect].compactMap { $0 } + item.reasons)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func conciseTrendText(_ value: String) -> String {
        let cleaned = value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: ":", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.localizedCaseInsensitiveContains("cooldown") {
            return "Cooldown Active"
        }

        if cleaned.localizedCaseInsensitiveContains("informational only")
            || cleaned.localizedCaseInsensitiveContains("details") {
            return "Holding"
        }

        if cleaned.count <= 28 {
            return cleaned.capitalized
        }

        return String(cleaned.prefix(25)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func trendColor(_ item: TrendWatchlistItem) -> Color {
        if let badgeClass = item.badgeClass {
            return trendClassColor(badgeClass)
        }

        switch trendAction(item).uppercased() {
        case "BUY_CANDIDATE":
            return .green
        case "HOLD_STRONG":
            return .blue
        case "HOLD_DEFENSIVE", "WAIT_FOR_COOLDOWN":
            return .orange
        case "AVOID_FOR_NOW":
            return .red
        default:
            return .secondary
        }
    }

    private func trendStatusColor(_ item: TrendWatchlistItem) -> Color {
        trendClassColor(trendStatus(item))
    }

    private func trendClassColor(_ value: String) -> Color {
        switch value.lowercased() {
        case "buy", "strong":
            return .green
        case "defensive", "cooldown":
            return .orange
        case "avoid", "weak":
            return .red
        case "neutral":
            return .secondary
        default:
            return .blue
        }
    }

    private func trendDetailLines(_ item: TrendWatchlistItem) -> [String] {
        var lines: [String] = []

        if let cooldownReason = item.cooldownReason, !cooldownReason.isEmpty {
            lines.append("Cooldown: \(cooldownReason)")
        }
        if let cooldownEffect = item.cooldownEffect, !cooldownEffect.isEmpty {
            lines.append("Effect: \(cooldownEffect)")
        }
        lines.append(contentsOf: item.reasons)

        if lines.isEmpty, item.dataAvailable == false {
            lines.append("No Trend Rider data available")
        }

        return lines
    }

    private func positionMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(minWidth: 58, alignment: .leading)
    }

    private func previewOrder(symbol: String, side: String, qty: Int) {
        tradeMessage = "Previewing \(side.uppercased()) \(symbol)..."

        APIClient.shared.previewOrder(
            tradeBaseURL: tradeBaseURL,
            apiKey: tradeAPIKey,
            symbol: symbol,
            side: side,
            qty: qty
        ) { preview, error in
            DispatchQueue.main.async {
                if let error {
                    self.tradeMessage = "Preview failed: \(error)"
                    return
                }

                guard let preview else {
                    self.tradeMessage = "Preview failed: no response"
                    return
                }

                self.tradeMessage = ""
                self.orderPreview = preview
            }
        }
    }

    private func confirmOrder(_ preview: PreviewResponse) {
        tradeMessage = "Confirming order..."

        APIClient.shared.confirmOrder(
            tradeBaseURL: tradeBaseURL,
            apiKey: tradeAPIKey,
            previewID: preview.preview_id,
            confirmCode: preview.confirm_code
        ) { result, error in
            DispatchQueue.main.async {
                self.orderPreview = nil

                if let error {
                    self.tradeMessage = "failed: \(error)"
                    return
                }

                guard let result else {
                    self.tradeMessage = "failed: no response"
                    return
                }

                let status = confirmDisplayStatus(result)
                let message = result.broker_result?.message
                self.tradeMessage = message.map { "\(status): \($0)" } ?? status
                self.loadAll()
            }
        }
    }

    private func confirmDisplayStatus(_ result: ConfirmResult) -> String {
        let status = (result.status ?? "").lowercased()

        if status.contains("submitted") || status.contains("accepted") || status.contains("filled") {
            return "submitted"
        }
        if status.contains("reject") {
            return "rejected"
        }
        if status.contains("expire") {
            return "expired"
        }

        return result.ok ? "submitted" : "failed"
    }

    private func placeOrder(symbol: String, side: String, qty: Int) {
        APIClient.shared.placeOrder(
            tradeBaseURL: tradeBaseURL,
            apiKey: tradeAPIKey,
            symbol: symbol,
            side: side,
            qty: qty
        ) { message in
            DispatchQueue.main.async {
                self.tradeMessage = message
                self.loadAll()
            }
        }
    }

    private func formatMoney(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    private func formatOptionalMoney(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "$%.2f", value)
    }

    private func formatQty(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }

    private func formatSigned(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%+.2f", value)
    }

    private func formatScore(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f", value)
    }

    private func formatOptionalInt(_ value: Int?) -> String {
        guard let value else { return "--" }
        return "\(value)"
    }

    private func formatOptionalBool(_ value: Bool?) -> String {
        guard let value else { return "--" }
        return value ? "Yes" : "No"
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.2f%%", value)
    }

    private func formatCompactPercent(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f%%", value)
    }
}

#Preview {
    ContentView()
}
