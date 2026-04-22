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
    @State private var selectedQty: Int = 1
    @State private var positionsError: String = ""

    @State private var assetTotal: Double = 0
    @State private var cashAvailable: Double?
    @State private var settledCash: Double?
    @State private var buyingPower: Double?
    @State private var totalAccountValue: Double?
    @State private var pendingBuyNotional: Double?
    @State private var freeCashAfterPending: Double?

    let symbols = ["QQQ", "SPY", "GLD"]

    private var baseURL: String { endpointResolver.dashboardBaseURL }
    private var tradeBaseURL: String { endpointResolver.tradeBaseURL }
    private let tradeAPIKey = AppConfig.apiKey

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    topBar

                    NavigationLink {
                        BuyLowView()
                    } label: {
                        HStack {
                            Text("BuyLow Logs")
                                .font(.subheadline)
                                .bold()
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    qtyBar

                    if isLoading {
                        ProgressView("Loading...")
                    }

                    if !tradeMessage.isEmpty {
                        Text(tradeMessage)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }

                    quoteSection
                    accountSection
                    positionsSection
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
                    ? "Confirm Trade"
                    : "Confirm \(pendingTrade!.side.uppercased()) \(pendingTrade!.symbol)",
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

                Button("Confirm") {
                    placeOrder(symbol: trade.symbol, side: trade.side, qty: trade.qty)
                    pendingTrade = nil
                }
            } message: { trade in
                Text("Send a \(trade.side.uppercased()) order for \(trade.qty) share(s) of \(trade.symbol)?")
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

    private var quoteSection: some View {
        VStack(spacing: 8) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        Text(item.symbol)
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        HStack(spacing: 6) {
                            Button("Buy") {
                                pendingTrade = PendingTrade(symbol: item.symbol, side: "buy", qty: selectedQty)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(!AppConfig.enableTrading)

                            Button("Sell") {
                                pendingTrade = PendingTrade(symbol: item.symbol, side: "sell", qty: selectedQty)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(!AppConfig.enableTrading)
                        }
                    }

                    HStack(alignment: .top, spacing: 18) {
                        quoteMetric(item, label: "Last", short: "L")
                        quoteMetric(item, label: "Close", short: "C")
                        quoteMetric(item, label: "Day High", short: "H")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
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

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Account")
                .font(.title3)
                .bold()

            HStack {
                Text("Assets")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                moneyText(formatMoney(assetTotal), size: 14)
            }

            HStack {
                Text("Cash Available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                moneyText(formatOptionalMoney(cashAvailable), size: 14)
            }

            HStack {
                Text("Pending Buys")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                moneyText(formatOptionalMoney(pendingBuyNotional), color: .orange, size: 14)
            }

            HStack {
                Text("Free Cash")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                moneyText(formatOptionalMoney(freeCashAfterPending), color: .green, size: 14)
            }

            HStack {
                Text("Total")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                moneyText(formatOptionalMoney(totalAccountValue), size: 14)
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
                    .font(.caption)
                Spacer()
                Label("Cash", systemImage: "circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }

            HStack {
                Text("Buying Power")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                moneyText(formatOptionalMoney(buyingPower), size: 12)
            }

            HStack {
                Text("Settled Cash")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                moneyText(formatOptionalMoney(settledCash), size: 12)
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

    private var positionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Positions")
                .font(.headline)
                .bold()

            if !positionsError.isEmpty {
                Text(positionsError)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            ForEach(positions) { pos in
                HStack {
                    Text(pos.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(minWidth: 40, alignment: .leading)

                    Text("Qty \(formatQty(pos.qty))")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 0) {
                        Text(formatSigned(pos.gainLoss))
                            .foregroundColor((pos.gainLoss ?? 0) >= 0 ? .green : .red)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text(formatPercent(pos.gainLossPct))
                            .foregroundColor((pos.gainLoss ?? 0) >= 0 ? .green : .red)
                            .font(.system(size: 11))
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func loadAll() {
        fetchAllQuotes()
        fetchPositions()
    }

    private func fetchAllQuotes() {
        isLoading = true

        let oldPrices = Dictionary(uniqueKeysWithValues: items.compactMap { item in
            item.lastPrice.map { (item.symbol, $0) }
        })

        let group = DispatchGroup()
        var loadedItems: [SymbolStatus] = []

        for symbol in symbols {
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
                self.positions = snapshot.positions.sorted { $0.symbol < $1.symbol }

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

    private func formatPercent(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.2f%%", value)
    }
}

#Preview {
    ContentView()
}
