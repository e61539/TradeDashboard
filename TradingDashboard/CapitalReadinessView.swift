import SwiftUI

struct CapitalReadinessView: View {
    let baseURL: String
    let apiKey: String

    @State private var readiness: CapitalReadiness?
    @State private var errorMessage = ""
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header

                if isLoading {
                    ProgressView("Loading...")
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }

                if let readiness {
                    readinessSummary(readiness)

                    ForEach(readiness.blockedSymbols) { blocked in
                        blockedRow(blocked)
                    }
                } else if errorMessage.isEmpty && !isLoading {
                    Text("No funding action suggested")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Capital")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Refresh") {
                fetchCapitalReadiness()
            }
        }
        .onAppear {
            fetchCapitalReadiness()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Capital Readiness")
                .font(.title2)
                .bold()

            Spacer()

            Text("Advisory only")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func readinessSummary(_ readiness: CapitalReadiness) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if readiness.isStale == true {
                Text("Capital readiness data stale")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }

            summaryRow("Schwab budget", formatMoney(readiness.schwabBudgetRemaining))
            summaryRow("Merrill reserve available", formatMoney(readiness.merrillReserveAvailable))
            summaryRow(
                "Suggested manual transfer",
                formatMoney(suggestedManualTransfer(readiness)),
                color: .orange
            )

            if !readiness.merrillReserveConfigured {
                Text("Merrill reserve not configured")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            } else if readiness.blockedSymbols.isEmpty {
                Text("No funding action suggested")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func summaryRow(_ label: String, _ value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            moneyText(value, color: color, size: 17)
        }
    }

    private func blockedRow(_ blocked: BlockedSymbol) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(blocked.symbol) blocked by \(simplifiedBlockReason(blocked.blockReason))")
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 8)

                if blocked.manualActionRequired {
                    Text("Manual action required")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            Text("Current \(formatMoney(blocked.currentPrice)) | Target \(formatMoney(blocked.targetPrice)) | \(formatPercent(blocked.distanceToTargetPct))")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text("Suggested manual transfer: \(formatMoney(blocked.suggestedFundingNeeded)) from \(blocked.suggestedSourceHolding)")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func fetchCapitalReadiness() {
        isLoading = true

        APIClient.shared.fetchCapitalReadiness(baseURL: baseURL, apiKey: apiKey) { readiness, error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error {
                    self.errorMessage = error
                    self.readiness = nil
                    return
                }

                self.errorMessage = ""
                self.readiness = readiness
            }
        }
    }

    private func suggestedManualTransfer(_ readiness: CapitalReadiness) -> Double {
        readiness.blockedSymbols
            .filter { $0.manualActionRequired }
            .reduce(0) { $0 + $1.suggestedFundingNeeded }
    }

    private func simplifiedBlockReason(_ reason: String) -> String {
        let text = reason.lowercased()

        if text.contains("budget") || text.contains("effective_budget") {
            return "Schwab budget"
        }
        if text.contains("no_viable_size") || text.contains("0_shares") {
            return "no viable size"
        }
        if text.contains("atr") {
            return "ATR target"
        }
        if text.contains("cap") || text.contains("headroom") {
            return "cap/headroom"
        }
        if text.contains("spread") {
            return "spread"
        }

        return reason.replacingOccurrences(of: "_", with: " ")
    }

    private func moneyText(_ value: String, color: Color = .primary, size: CGFloat = 14) -> some View {
        Text(value)
            .font(.system(size: size, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private func formatMoney(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    private func formatPercent(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.2f%%", value)
    }
}

#Preview {
    NavigationStack {
        CapitalReadinessView(baseURL: "http://localhost:8000", apiKey: "preview")
    }
}
