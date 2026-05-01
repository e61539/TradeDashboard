import Combine
import SwiftUI

struct BuyLowView: View {
    let baseURL: String
    let apiKey: String
    let symbols: [String]

    private let refreshTimer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

    @State private var statuses: [BuyLowStatus] = []
    @State private var errorMessage = ""
    @State private var loadingSymbols: Set<String> = []
    @State private var activeFetchCount = 0
    @State private var isFetchingLogs = false

    private var isLoading: Bool {
        isFetchingLogs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BuyLow Logs")
                    .font(.title2)
                    .bold()

                Spacer()

                Text("Auto 20s")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(isLoading ? "Refreshing" : "Refresh") {
                    loadEntries()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if isLoading && statuses.isEmpty {
                ProgressView("Loading logs...")
                    .font(.headline)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.headline)
                    .foregroundColor(.red)
            }

            if statuses.isEmpty && !isLoading && errorMessage.isEmpty {
                Text("No BuyLow logs")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            ForEach(statuses) { status in
                HStack(alignment: .top, spacing: 12) {
                    Text(status.symbol)
                        .font(.system(size: 22, weight: .bold))
                        .frame(width: 72, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(status.status)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(color(for: status.status))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        if isATRBlocked(status.status) {
                            Text(status.message)
                                .font(.system(size: 19))
                                .foregroundColor(atrDistanceColor(status.message))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            highlightedMessage(status.message)
                                .font(.system(size: 19))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear {
            loadEntries()
        }
        .onChange(of: baseURL) {
            loadEntries()
        }
        .onReceive(refreshTimer) { _ in
            loadEntries()
        }
    }

    private func loadEntries() {
        guard !isFetchingLogs else { return }

        let symbolsToLoad = symbols
        guard !symbolsToLoad.isEmpty else { return }

        isFetchingLogs = true
        activeFetchCount += symbolsToLoad.count
        loadingSymbols.formUnion(symbolsToLoad)
        errorMessage = ""

        for symbol in symbolsToLoad {
            APIClient.shared.fetchBuyLowStatus(baseURL: baseURL, apiKey: apiKey, symbol: symbol) { status, error in
                DispatchQueue.main.async {
                    self.loadingSymbols.remove(symbol)
                    self.activeFetchCount = max(0, self.activeFetchCount - 1)
                    if self.activeFetchCount == 0 {
                        self.isFetchingLogs = false
                    }

                    if let status {
                        let oldStatus = self.statuses.first { $0.symbol == symbol }
                        if let oldStatus, self.isTimeoutStatus(status) {
                            self.upsert(oldStatus.markedStale())
                        } else {
                            self.upsert(status)
                        }
                        return
                    }

                    let oldStatus = self.statuses.first { $0.symbol == symbol }
                    if let oldStatus, self.isTimeoutMessage(error) {
                        self.upsert(oldStatus.markedStale())
                    } else if let error {
                        self.errorMessage = "\(symbol): \(error)"
                    }
                }
            }
        }
    }

    private func upsert(_ status: BuyLowStatus) {
        statuses.removeAll { $0.symbol == status.symbol }
        statuses.append(status)
        statuses.sort { $0.symbol < $1.symbol }
    }

    private func isTimeoutMessage(_ message: String?) -> Bool {
        message?.localizedCaseInsensitiveContains("timeout") == true
            || message?.localizedCaseInsensitiveContains("timed out") == true
    }

    private func isTimeoutStatus(_ status: BuyLowStatus) -> Bool {
        status.status.localizedCaseInsensitiveContains("CHECK")
            && isTimeoutMessage(status.message)
    }

    private func color(for status: String) -> Color {
        let label = status.uppercased()

        if label.contains("ELIGIBLE") {
            return .green
        }
        if label.contains("BLOCKED") {
            return .orange
        }
        if label.contains("CHECK") {
            return .red
        }

        return .secondary
    }

    private func isATRBlocked(_ status: String) -> Bool {
        status.localizedCaseInsensitiveContains("BLOCKED(ATR)")
    }

    private func atrDistanceColor(_ message: String) -> Color {
        let regex = try? NSRegularExpression(pattern: #"([+-]?(?:\d+(?:\.\d+)?|\.\d+))%"#)
        let nsMessage = message as NSString
        let range = NSRange(location: 0, length: nsMessage.length)

        guard
            let match = regex?.firstMatch(in: message, range: range),
            match.numberOfRanges > 1,
            let value = Double(nsMessage.substring(with: match.range(at: 1)))
        else {
            return .secondary
        }

        if value <= 0 {
            return .green
        }
        if value <= 1 {
            return .orange
        }
        return .red
    }

    private func highlightedMessage(_ message: String) -> Text {
        let regex = try? NSRegularExpression(pattern: #"[+-]?(?:\d+(?:\.\d+)?|\.\d+)\s*%"#)
        let nsMessage = message as NSString
        let matches = regex?.matches(
            in: message,
            range: NSRange(location: 0, length: nsMessage.length)
        ) ?? []

        guard !matches.isEmpty else {
            return Text(message)
        }

        var text = Text("")
        var cursor = 0

        for match in matches {
            if match.range.location > cursor {
                text = text + Text(nsMessage.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            }

            let percent = nsMessage.substring(with: match.range)
            text = text + Text(percent)
                .fontWeight(.bold)
                .foregroundColor(.orange)

            cursor = match.range.location + match.range.length
        }

        if cursor < nsMessage.length {
            text = text + Text(nsMessage.substring(with: NSRange(location: cursor, length: nsMessage.length - cursor)))
        }

        return text
    }
}
