import SwiftUI

struct BuyLowView: View {
    let baseURL: String
    let apiKey: String
    let symbols: [String]

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

                Button("Refresh") {
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

                        Text(status.message)
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
    }

    private func loadEntries() {
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
}
