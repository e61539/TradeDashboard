import Combine
import SwiftUI

struct BuyLowView: View {
    let baseURL: String
    let apiKey: String
    let symbols: [String]

    private let refreshTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    @State private var statuses: [BuyLowStatus] = []
    @State private var errorMessage = ""
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BuyLow Logs")
                    .font(.title2)
                    .bold()

                Spacer()

                Text("Auto 10s")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(isLoading ? "Refreshing" : "Refresh") {
                    loadEntries()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isLoading)
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

                        highlightedMessage(status.message)
                            .font(.system(size: 19))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)
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
        guard !isLoading else { return }

        isLoading = true
        errorMessage = ""

        APIClient.shared.fetchBuyLowStatuses(baseURL: baseURL, apiKey: apiKey, symbols: symbols) { statuses, error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error {
                    self.errorMessage = error
                    return
                }

                self.statuses = statuses ?? []
            }
        }
    }

    private func color(for status: String) -> Color {
        switch status.uppercased() {
        case "READY":
            return .green
        case "BLOCKED":
            return .orange
        case "CHECK":
            return .red
        default:
            return .secondary
        }
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
