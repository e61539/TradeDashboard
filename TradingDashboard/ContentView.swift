import SwiftUI

private enum BTCPutHealthCheckError: LocalizedError {
    case badStatus(Int?)

    var errorDescription: String? {
        switch self {
        case .badStatus(let status):
            if let status {
                return "HTTP status \(status)"
            }
            return "No HTTP status returned"
        }
    }
}

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var endpointResolver = EndpointResolver.shared

    @State private var items: [SymbolStatus] = []
    @State private var positions: [Position] = []
    @State private var isLoading = false
    @State private var timer: Timer?
    @State private var previousLastPrices: [String: Double] = [:]
    @State private var tradeMessage: String = ""
    @State private var pendingTrade: PendingTrade?
    @State private var orderPreview: PreviewResponse?
    @State private var orderPreviewCreatedAt: Date?
    @State private var isConfirmingOrder = false
    @State private var selectedQty: Int = 1
    @State private var positionsError: String = ""
    @State private var trendWatchlistItems: [TrendWatchlistItem] = []
    @State private var trendWatchlistSymbols: [String] = []
    @State private var trendWatchlistError: String = ""
    @State private var expandedTrendSymbols: Set<String> = []
    @State private var marketRegime: MarketRegimeResponse?
    @State private var marketRegimeError: String = ""
    @State private var intelligenceOpportunities: [IntelligenceOpportunity] = []
    @State private var intelligenceError: String = ""
    @State private var decisionActions: DecisionActionsResponse?
    @State private var btcPutAlertMessage: String = ""
    @State private var btcPutStatusMessage: String = ""
    @State private var isCheckingBTCPutDashboard = false

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
    private var btcPutDashboardBaseURL: String {
        "http://\(AppConfig.localHost):\(AppConfig.btcPutDashboardPort)"
    }
    private var btcPutDashboardURL: URL? {
        URL(string: btcPutDashboardBaseURL)
    }
    private var btcPutHealthURL: URL? {
        URL(string: "\(btcPutDashboardBaseURL)/health")
    }
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
                    marketRegimeBanner
                    todaysGuidanceCard

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
            .alert("BTC Put Dashboard", isPresented: Binding(
                get: { !btcPutAlertMessage.isEmpty },
                set: { newValue in
                    if !newValue { btcPutAlertMessage = "" }
                }
            )) {
                Button("Open Anyway") {
                    btcPutAlertMessage = ""
                    openBTCPutDashboardDirectly()
                }

                Button("OK", role: .cancel) {
                    btcPutAlertMessage = ""
                }
            } message: {
                Text(btcPutAlertMessage)
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

                Button(isCheckingBTCPutDashboard ? "Checking..." : "BTC Put Dashboard") {
                    openBTCPutDashboard()
                }
                .buttonStyle(.bordered)
                .disabled(isCheckingBTCPutDashboard)

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

            if !btcPutStatusMessage.isEmpty {
                HStack(spacing: 8) {
                    Text(btcPutStatusMessage)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Button("Open Anyway") {
                        btcPutStatusMessage = ""
                        openBTCPutDashboardDirectly()
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    private func openBTCPutDashboard() {
        guard !isCheckingBTCPutDashboard else { return }
        guard let btcPutHealthURL, let btcPutDashboardURL else {
            btcPutAlertMessage = "BTC Put Dashboard URL is invalid."
            return
        }

        isCheckingBTCPutDashboard = true
        Task {
            var request = URLRequest(url: btcPutHealthURL)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 15
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            let start = Date()

            do {
                let session = btcPutHealthCheckSession()
                defer {
                    session.invalidateAndCancel()
                }

                let (_, response) = try await session.data(for: request)
                let elapsedMs = Date().timeIntervalSince(start) * 1000
                guard
                    let http = response as? HTTPURLResponse,
                    (200...299).contains(http.statusCode)
                else {
                    let status = (response as? HTTPURLResponse)?.statusCode
                    throw BTCPutHealthCheckError.badStatus(status)
                }

                NSLog(
                    "BTC Put Dashboard health check succeeded: %@ elapsed_ms=%.1f",
                    btcPutHealthURL.absoluteString,
                    elapsedMs
                )

                await MainActor.run {
                    isCheckingBTCPutDashboard = false
                    btcPutStatusMessage = ""
                    openURL(btcPutDashboardURL)
                }
            } catch {
                let elapsedMs = Date().timeIntervalSince(start) * 1000
                let detail = btcPutHealthCheckErrorMessage(error)
                NSLog(
                    "BTC Put Dashboard health check failed: %@ elapsed_ms=%.1f error=%@",
                    btcPutHealthURL.absoluteString,
                    elapsedMs,
                    detail
                )

                await MainActor.run {
                    isCheckingBTCPutDashboard = false
                    if isBTCPutHealthCheckTimeout(error) {
                        btcPutStatusMessage = "BTC Dashboard temporarily unavailable"
                        return
                    }

                    btcPutAlertMessage = """
                    Cannot reach BTC Put Dashboard health check.

                    Health: \(btcPutHealthURL.absoluteString)
                    Dashboard: \(btcPutDashboardBaseURL)
                    Error: \(detail)
                    Elapsed: \(String(format: "%.0f ms", elapsedMs))

                    If Safari can open the health URL, use Open Anyway.
                    """
                }
            }
        }
    }

    private func openBTCPutDashboardDirectly() {
        guard let btcPutDashboardURL else {
            btcPutAlertMessage = "BTC Put Dashboard URL is invalid."
            return
        }

        openURL(btcPutDashboardURL)
    }

    private func btcPutHealthCheckSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: config)
    }

    private func btcPutHealthCheckErrorMessage(_ error: Error) -> String {
        if let healthError = error as? BTCPutHealthCheckError {
            return healthError.localizedDescription
        }

        if let urlError = error as? URLError {
            return "\(urlError.localizedDescription) (URLError \(urlError.code.rawValue): \(urlError.code))"
        }

        return error.localizedDescription
    }

    private func isBTCPutHealthCheckTimeout(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .timedOut
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut
    }

    @ViewBuilder
    private var marketRegimeBanner: some View {
        if let marketRegime {
            HStack(alignment: .center, spacing: 6) {
                Text(marketRegimeBannerText(marketRegime))
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(regimeColor(marketRegime).opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(regimeColor(marketRegime).opacity(0.22), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if !marketRegimeError.isEmpty {
            Text("Intelligence unavailable")
                .font(.caption)
                .foregroundColor(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func orderPreviewSheet(_ preview: PreviewResponse) -> some View {
        let createdAt = orderPreviewCreatedAt ?? Date()

        return NavigationStack {
            TimelineView(.periodic(from: createdAt, by: 1)) { context in
                let previewExpired = isPreviewExpired(preview, createdAt: createdAt, now: context.date)
                let canConfirm = canConfirmPreview(preview) && !previewExpired && !isConfirmingOrder

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

                    Text(previewTimingText(preview, createdAt: createdAt, now: context.date))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(previewTimingColor(preview, createdAt: createdAt, now: context.date))

                    if let message = preview.message ?? preview.broker_result?.message ?? preview.status, !message.isEmpty {
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !canConfirmPreview(preview) {
                        Text("Preview unavailable")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.orange)
                    }

                    Spacer()

                    Button {
                        confirmOrder(preview)
                    } label: {
                        Text(isConfirmingOrder ? "Confirming..." : "Confirm Order")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canConfirm)
                }
                .padding()
            }
            .navigationTitle("Order Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Cancel") {
                    isConfirmingOrder = false
                    orderPreview = nil
                }
            }
        }
    }

    private var todaysGuidanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today's Guidance")
                    .font(.headline)
                    .bold()

                Spacer(minLength: 8)

                Text("Advisory only")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            if let decisionActions {
                HStack(spacing: 10) {
                    Text("Regime: \(guidanceRegimeText(decisionActions))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if let cashAvailable = decisionActions.cashAvailable {
                        Text("Cash: \(formatCompactMoney(cashAvailable))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }

                let topActions = Array(decisionActions.actions.prefix(3))
                if topActions.isEmpty {
                    Text("No guidance actions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(topActions) { action in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(guidanceActionTitle(action))
                                .font(.system(size: 14, weight: .semibold))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)

                            if let message = cleanText(action.message) {
                                Text(message)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            } else {
                Text("Guidance unavailable")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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

    private func isValidPreviewPrice(_ value: Double?) -> Bool {
        guard let value else {
            return false
        }
        return value.isFinite && value > 0
    }

    private func canConfirmPreview(_ preview: PreviewResponse) -> Bool {
        !preview.preview_id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !preview.confirm_code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && isValidPreviewPrice(previewEstimatedPrice(preview))
            && isValidPreviewPrice(previewSuggestedLimit(preview))
    }

    private func previewAgeSeconds(createdAt: Date, now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(createdAt)))
    }

    private func previewRemainingSeconds(_ preview: PreviewResponse, createdAt: Date, now: Date) -> Int? {
        guard let expiresIn = preview.expires_in_sec else {
            return nil
        }
        return expiresIn - previewAgeSeconds(createdAt: createdAt, now: now)
    }

    private func isPreviewExpired(_ preview: PreviewResponse, createdAt: Date?, now: Date = Date()) -> Bool {
        guard let createdAt, let remaining = previewRemainingSeconds(preview, createdAt: createdAt, now: now) else {
            return false
        }
        return remaining <= 0
    }

    private func previewTimingText(_ preview: PreviewResponse, createdAt: Date, now: Date) -> String {
        let age = previewAgeSeconds(createdAt: createdAt, now: now)
        if let remaining = previewRemainingSeconds(preview, createdAt: createdAt, now: now) {
            if remaining <= 0 {
                return "Preview expired. New preview required."
            }
            if remaining <= 10 {
                return "Preview age \(age)s • expires in \(remaining)s"
            }
            return "Preview age \(age)s • expires in \(remaining)s"
        }
        return "Preview age \(age)s"
    }

    private func previewTimingColor(_ preview: PreviewResponse, createdAt: Date, now: Date) -> Color {
        guard let remaining = previewRemainingSeconds(preview, createdAt: createdAt, now: now) else {
            return .secondary
        }
        return remaining <= 10 ? .orange : .secondary
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

            if !intelligenceError.isEmpty {
                Text("Intelligence unavailable")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 9) {
                    let intelligence = intelligenceOpportunity(for: item.symbol)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.symbol)
                                .font(.system(size: 25, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)

                            Text(currentPriceText(item))
                                .font(.system(size: 21, weight: .semibold))
                                .monospacedDigit()
                                .foregroundColor(colorForLine(symbol: item.symbol, line: item.lines.first(where: { $0.label == "Last" }), currentLast: item.lastPrice))
                                .lineLimit(1)
                                .minimumScaleFactor(0.86)
                        }
                        .layoutPriority(1)

                        Spacer(minLength: 4)

                        let canTrade = canTrade(item.symbol)

                        Button(canTrade ? "Buy" : "Watch Only") {
                            guard canTrade else { return }
                            pendingTrade = PendingTrade(symbol: item.symbol, side: "buy", qty: selectedQty)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(!AppConfig.enableTrading || !canTrade)
                    }

                    if let intelligence {
                        intelligenceSummaryRow(intelligence)
                    }

                    if let trendItem = trendItem(for: item.symbol) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(trendTriggerLineText(trendItem, quoteItem: item))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                                .monospacedDigit()

                            HStack(alignment: .center, spacing: 6) {
                                trendBadge(
                                    text: trendStatusWithPriority(trendItem),
                                    color: trendDisplayColor(trendItem),
                                    prominent: true
                                )

                                Text(trendShortReason(trendItem))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)

                                Spacer(minLength: 0)
                            }

                            if let target = trendTargetLineText(trendItem) {
                                Text(target)
                                    .font(.system(size: 15.5, weight: .medium))
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                            }
                        }
                    } else {
                        Text(trendCloseText(nil, quoteItem: item) ?? "Prev Close --")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 12)
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

    private func intelligenceSummaryRow(_ item: IntelligenceOpportunity) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("\(displayRating(item.rating)) · \(formatScore(item.score))")
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)

                trendBadge(
                    text: intelligenceStateLabel(item),
                    color: intelligenceStateColor(item),
                    prominent: false
                )
            }

            if let trigger = triggerLineText(item) {
                Text(trigger)
                    .font(.system(size: 14.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            if let target = targetLineText(item) {
                Text(target)
                    .font(.system(size: 14, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
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
        fetchMarketRegime()
        fetchIntelligenceOpportunities()
        fetchDecisionActions()
        fetchTrendWatchlistAndQuotes()
        fetchPositions()
    }

    private func fetchMarketRegime() {
        APIClient.shared.fetchMarketRegime(baseURL: baseURL, apiKey: tradeAPIKey) { response, error in
            DispatchQueue.main.async {
                if let response {
                    self.marketRegime = response
                    self.marketRegimeError = ""
                    return
                }

                self.marketRegime = nil
                self.marketRegimeError = error ?? "unavailable"
            }
        }
    }

    private func fetchIntelligenceOpportunities() {
        APIClient.shared.fetchIntelligenceOpportunities(baseURL: baseURL, apiKey: tradeAPIKey) { response, error in
            DispatchQueue.main.async {
                if let response {
                    self.intelligenceOpportunities = response.opportunities
                    self.intelligenceError = ""
                    if self.marketRegime == nil, let regime = response.regime {
                        self.marketRegime = regime
                    }
                    return
                }

                self.intelligenceOpportunities = []
                self.intelligenceError = error.map { "Intelligence: \($0)" } ?? "Intelligence unavailable"
            }
        }
    }

    private func fetchDecisionActions() {
        APIClient.shared.fetchDecisionActions(baseURL: baseURL, apiKey: tradeAPIKey) { response, _ in
            DispatchQueue.main.async {
                if let response {
                    self.decisionActions = response
                    if self.marketRegime == nil, let regime = response.regime {
                        self.marketRegime = regime
                    }
                    return
                }

                self.decisionActions = nil
            }
        }
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

            guard (200...299).contains(httpResponse.statusCode) else {
                completion(SymbolStatus(symbol: symbol, status: "ERROR", detail: httpErrorMessage(data: data, statusCode: httpResponse.statusCode), lines: [], lastPrice: nil))
                return
            }

            guard let data else {
                completion(SymbolStatus(symbol: symbol, status: "ERROR", detail: "No quote response body", lines: [], lastPrice: nil))
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

    private func httpErrorMessage(data: Data?, statusCode: Int) -> String {
        guard let data, !data.isEmpty else {
            return "HTTP \(statusCode)"
        }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["detail", "message", "error", "status"] {
                if let text = object[key] as? String {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        return trimmed
                    }
                }
            }
        }

        let body = String(data: data, encoding: .utf8) ?? ""
        return body.isEmpty ? "HTTP \(statusCode)" : body
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

    private func intelligenceOpportunity(for symbol: String) -> IntelligenceOpportunity? {
        intelligenceOpportunities.first { $0.symbol.caseInsensitiveCompare(symbol) == .orderedSame }
    }

    private func canTrade(_ symbol: String) -> Bool {
        guard let item = trendItem(for: symbol) else {
            return true
        }
        return item.canTrade ?? true
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

    private func displayRegime(_ regime: MarketRegimeResponse) -> String {
        let value = regime.regime?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else {
            return "UNKNOWN"
        }
        return value.replacingOccurrences(of: "_", with: " ").uppercased()
    }

    private func marketRegimeBannerText(_ regime: MarketRegimeResponse) -> String {
        "Market: \(displayRegime(regime)) | SPY \(formatSignedPercent(regime.spyDayChangePct)) | \(formatConfidencePercent(regime.confidence))"
    }

    private func guidanceRegimeText(_ response: DecisionActionsResponse) -> String {
        if let regime = response.regime {
            return displayRegime(regime)
        }
        if let marketRegime {
            return displayRegime(marketRegime)
        }
        return "UNKNOWN"
    }

    private func guidanceActionTitle(_ action: DecisionAction) -> String {
        let type = cleanText(action.type)?.replacingOccurrences(of: "_", with: " ").uppercased() ?? "ACTION"
        let symbol = cleanText(action.symbol)?.uppercased() ?? "--"
        let score = formatScore(action.score)
        return "\(type) \(symbol) · \(score)"
    }

    private func regimeColor(_ regime: MarketRegimeResponse) -> Color {
        let value = (regime.regime ?? "").lowercased()
        if value.contains("bull") || value.contains("risk_on") || value.contains("strong") {
            return .green
        }
        if value.contains("bear") || value.contains("defensive") || value.contains("risk_off") {
            return .orange
        }
        return .blue
    }

    private func percentColor(_ value: Double?) -> Color {
        guard let value else {
            return .secondary
        }
        if value > 0 {
            return .green
        }
        if value < 0 {
            return .red
        }
        return .secondary
    }

    private func displayRating(_ rating: String?) -> String {
        let value = rating?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else {
            return "UNRATED"
        }
        return value.replacingOccurrences(of: "_", with: " ").uppercased()
    }

    private func intelligenceStateLabel(_ item: IntelligenceOpportunity) -> String {
        if item.buyLowReady == true {
            return "READY"
        }

        if item.buyLowReady == false,
           let distance = item.distanceTo52WHighPct,
           let threshold = item.firstStageThresholdPct {
            if distance < threshold {
                return "NEAR HIGH"
            }
        }

        if let dataQuality = cleanText(item.dataQuality),
           dataQuality.uppercased() != "OK" {
            return "DATA ISSUE"
        }

        return "WATCH"
    }

    private func intelligenceStateColor(_ item: IntelligenceOpportunity) -> Color {
        switch intelligenceStateLabel(item) {
        case "READY":
            return .green
        case "NEAR HIGH":
            return .orange
        case "DATA ISSUE":
            return .red
        default:
            return .blue
        }
    }

    private func triggerLineText(_ item: IntelligenceOpportunity) -> String? {
        if let pullback = item.pullbackVsThresholdPct,
           let threshold = item.firstStageThresholdPct {
            return "Pullback \(formatCompactPercent(abs(pullback))) / \(formatCompactPercent(threshold)) trigger"
        }

        if let description = cleanText(item.triggerDescription) {
            return description
        }

        if let dip = item.dipPct, let trigger = item.triggerPct {
            let reference = cleanText(item.triggerReference).map { " · \($0)" } ?? ""
            return "Pullback \(formatCompactPercent(abs(dip))) / \(formatCompactPercent(trigger)) trigger\(reference)"
        }

        return oldPullbackTriggerText(item)
    }

    private func targetLineText(_ item: IntelligenceOpportunity) -> String? {
        if let description = cleanText(item.targetDescription) {
            return description
        }

        if let targetPrice = item.targetPrice {
            return "Target \(formatMoney(targetPrice))"
        }

        return nil
    }

    private func oldPullbackTriggerText(_ item: IntelligenceOpportunity) -> String? {
        guard let distance = item.distanceTo52WHighPct else {
            return nil
        }

        let trigger = item.firstStageThresholdPct ?? 3.0
        return "Pullback \(formatCompactPercent(abs(distance))) / \(formatCompactPercent(trigger)) trigger"
    }

    private func cleanText(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else {
            return nil
        }
        return trimmed
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

    private func trendTriggerLineText(_ item: TrendWatchlistItem, quoteItem: SymbolStatus) -> String {
        if let trigger = item.triggerPct,
           trigger > 0,
           let current = item.currentPrice,
           let reference = item.referencePrice,
           current > 0,
           reference > 0 {
            let referenceLabel = abbreviatedReference(
                cleanText(item.referenceSource) ?? cleanText(item.triggerReference)
            )
            let dipDollar = reference - current
            let distancePct = abs(dipDollar / reference * 100)
            let distanceDollar = formatMoney(abs(dipDollar))

            if dipDollar > 0.005 {
                return "Dip \(formatWatchlistPercent(distancePct)) / \(distanceDollar) below \(referenceLabel) / Trig \(formatWatchlistPercent(trigger))"
            }
            if dipDollar < -0.005 {
                return "Price \(formatWatchlistPercent(distancePct)) / \(distanceDollar) above \(referenceLabel) / Trig \(formatWatchlistPercent(trigger))"
            }
            return "Near \(referenceLabel) / Trig \(formatWatchlistPercent(trigger))"
        }

        if let description = cleanText(item.triggerDescription) {
            return abbreviateWatchlistText(description)
        }

        if let trigger = item.triggerPct, trigger > 0 {
            return "Trig \(formatWatchlistPercent(trigger))"
        }

        return trendMarketCondition(item, quoteItem: quoteItem)
    }

    private func trendTargetLineText(_ item: TrendWatchlistItem) -> String? {
        if let description = cleanText(item.targetDescription) {
            return abbreviateWatchlistText(description)
        }

        if let targetPrice = item.targetPrice, isTrendTargetSane(item) {
            return "Buy @ ~\(formatMoney(targetPrice))"
        }

        return nil
    }

    private func abbreviatedReference(_ text: String?) -> String {
        let value = cleanText(text) ?? "ref"
        let normalized = value.lowercased()

        if normalized == "prev close" || normalized == "previous close" {
            return "PC"
        }
        if normalized == "recent high" {
            return "RH"
        }
        if normalized == "52w high" || normalized == "52 week high" || normalized == "52-week high" {
            return "52H"
        }
        if normalized == "stage anchor" {
            return "SA"
        }
        if normalized == "breakout anchor" {
            return "BA"
        }

        return abbreviateWatchlistText(value)
    }

    private func abbreviateWatchlistText(_ text: String) -> String {
        var output = text
        let replacements = [
            "Previous Close": "PC",
            "Prev Close": "PC",
            "Recent High": "RH",
            "52W High": "52H",
            "52w High": "52H",
            "Stage Anchor": "SA",
            "Breakout Anchor": "BA",
            "Buy trigger around": "Buy @ ~",
            "Trigger": "Trig",
            "trigger": "trig"
        ]

        for (source, replacement) in replacements {
            output = output.replacingOccurrences(of: source, with: replacement)
        }

        return output
    }

    private func isTrendTargetSane(_ item: TrendWatchlistItem) -> Bool {
        guard
            let targetPrice = item.targetPrice,
            let referencePrice = item.referencePrice,
            let triggerPct = item.triggerPct,
            targetPrice > 0,
            referencePrice > 0,
            triggerPct > 0
        else {
            return false
        }

        let expectedTarget = referencePrice * (1 - triggerPct / 100)
        guard targetPrice <= referencePrice, expectedTarget > 0 else {
            return false
        }

        let tolerance = max(0.02, referencePrice * 0.002)
        return abs(targetPrice - expectedTarget) <= tolerance
    }

    private func trendCloseText(_ item: TrendWatchlistItem?, quoteItem: SymbolStatus) -> String? {
        let quoteClose = quoteItem.lines.first { $0.label == "Close" }?.value

        if let close = item?.previousClose ?? item?.close {
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
        guard canTrade(symbol) else {
            tradeMessage = "\(symbol) is watch only"
            return
        }

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

                guard self.canConfirmPreview(preview) else {
                    let message = preview.message ?? preview.broker_result?.message ?? preview.status
                    self.tradeMessage = message.map { "Preview unavailable: \($0)" } ?? "Preview unavailable"
                    self.orderPreview = nil
                    return
                }

                self.tradeMessage = ""
                self.isConfirmingOrder = false
                self.orderPreviewCreatedAt = Date()
                self.orderPreview = preview
            }
        }
    }

    private func confirmOrder(_ preview: PreviewResponse) {
        guard canConfirmPreview(preview) else {
            tradeMessage = "Preview unavailable"
            orderPreview = nil
            return
        }

        guard !isPreviewExpired(preview, createdAt: orderPreviewCreatedAt) else {
            tradeMessage = "Preview expired. New preview required."
            orderPreview = nil
            return
        }

        guard !isConfirmingOrder else {
            return
        }

        isConfirmingOrder = true
        tradeMessage = "Confirming order..."

        APIClient.shared.confirmOrder(
            tradeBaseURL: tradeBaseURL,
            apiKey: tradeAPIKey,
            previewID: preview.preview_id,
            confirmCode: preview.confirm_code
        ) { result, error in
            DispatchQueue.main.async {
                self.isConfirmingOrder = false
                self.orderPreview = nil

                if let error {
                    self.tradeMessage = self.confirmFailureMessage(error)
                    return
                }

                guard let result else {
                    self.tradeMessage = "failed: no response"
                    return
                }

                let status = confirmDisplayStatus(result)
                let message = result.broker_result?.message
                if status == "submitted" {
                    self.tradeMessage = "Order submitted"
                } else {
                    let detail = confirmDetailMessage(message ?? result.status)
                    self.tradeMessage = confirmFailureMessage(status: status, detail: detail)
                    if requiresNewPreview(status, detail) {
                        self.tradeMessage += ". New preview required."
                    }
                }
                self.loadAll()
            }
        }
    }

    private func confirmDisplayStatus(_ result: ConfirmResult) -> String {
        let text = [result.status, result.broker_result?.message]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

        if text.contains("duplicate") {
            return "duplicate"
        }
        if text.contains("reject") {
            return "rejected"
        }
        if text.contains("expire") {
            return "expired"
        }
        if text.contains("drift") || text.contains("price") || text.contains("quote") {
            return "price drift"
        }
        if result.ok && (text.contains("submitted") || text.contains("accepted") || text.contains("filled")) {
            return "submitted"
        }

        return result.ok ? "submitted" : "failed"
    }

    private func confirmFailureMessage(_ error: String) -> String {
        let status = confirmDisplayStatus(error)
        let detail = confirmDetailMessage(error)
        var message = confirmFailureMessage(status: status, detail: detail)
        if requiresNewPreview(status, error) {
            message += ". New preview required."
        }
        return message
    }

    private func confirmFailureMessage(status: String, detail: String?) -> String {
        let prefix: String
        switch status {
        case "duplicate":
            prefix = "Duplicate confirm"
        case "expired":
            prefix = "Preview expired"
        case "rejected":
            prefix = "Order rejected"
        case "price drift":
            prefix = "Price changed"
        default:
            prefix = "Confirm failed"
        }

        guard let detail, !detail.isEmpty else {
            return prefix
        }

        return "\(prefix): \(detail)"
    }

    private func confirmDetailMessage(_ text: String?) -> String? {
        guard let text else {
            return nil
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }

        return trimmed
    }

    private func confirmDisplayStatus(_ text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("duplicate") {
            return "duplicate"
        }
        if lower.contains("expire") {
            return "expired"
        }
        if lower.contains("reject") {
            return "rejected"
        }
        if lower.contains("drift") || lower.contains("price") || lower.contains("quote") {
            return "price drift"
        }
        return "failed"
    }

    private func requiresNewPreview(_ status: String, _ detail: String?) -> Bool {
        let text = "\(status) \(detail ?? "")".lowercased()
        return text.contains("expire")
            || text.contains("drift")
            || text.contains("price")
            || text.contains("quote")
    }

    private func formatMoney(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    private func formatOptionalMoney(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "$%.2f", value)
    }

    private func formatCompactMoney(_ value: Double) -> String {
        String(format: "$%.0f", value)
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

    private func formatSignedPercent(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%+.1f%%", value)
    }

    private func formatConfidencePercent(_ value: Double?) -> String {
        guard let value else { return "--" }
        let normalized = abs(value) <= 1 ? value * 100 : value
        return String(format: "%.0f%%", normalized)
    }

    private func formatScore(_ value: Double?) -> String {
        guard let value else { return "--" }
        let rounded = value.rounded()
        if abs(value - rounded) < 0.05 {
            return String(format: "%.0f", rounded)
        }
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

    private func formatWatchlistPercent(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.05 {
            return String(format: "%.0f%%", rounded)
        }
        return String(format: "%.1f%%", value)
    }
}

#Preview {
    ContentView()
}
