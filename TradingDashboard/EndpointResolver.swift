import Foundation
import Network
import Combine

@MainActor
final class EndpointResolver: ObservableObject {
    static let shared = EndpointResolver()

    enum Route: String {
        case lan = "LAN"
        case tailscale = "Tailscale"
        case publicIP = "Public"
        case unknown = "Unknown"
    }

    @Published private(set) var activeHost: String
    @Published private(set) var activeRoute: Route
    @Published private(set) var dashboardBaseURL: String
    @Published private(set) var tradeBaseURL: String

    private var lastRefresh: Date?
    private let cacheSeconds: TimeInterval = 30

    private init() {
        let host = AppConfig.localHost
        self.activeHost = host
        self.activeRoute = .unknown
        self.dashboardBaseURL = "http://\(host):\(AppConfig.dashboardPort)"
        self.tradeBaseURL = "http://\(host):\(AppConfig.tradePort)"
    }

    func refreshIfNeeded() async {
        if let lastRefresh, Date().timeIntervalSince(lastRefresh) < cacheSeconds {
            return
        }
        await refresh()
    }

    func refresh() async {
        let route = await resolveRoute()
        apply(route: route)
        lastRefresh = Date()
    }

    private func apply(route: Route) {
        let newHost: String

        switch route {
        case .lan:
            newHost = AppConfig.localHost
        case .tailscale:
            newHost = AppConfig.tailscaleHost
        case .publicIP:
            newHost = AppConfig.publicHost
        case .unknown:
            newHost = AppConfig.tailscaleHost
        }

        if newHost == activeHost && route == activeRoute {
            return
        }

        activeHost = newHost
        activeRoute = route
        dashboardBaseURL = "http://\(activeHost):\(AppConfig.dashboardPort)"
        tradeBaseURL = "http://\(activeHost):\(AppConfig.tradePort)"
    }

    private func resolveRoute() async -> Route {
        if await NetworkChecker.canConnect(host: AppConfig.localHost, port: AppConfig.dashboardPort) {
            return .lan
        }

        if await NetworkChecker.canConnect(host: AppConfig.tailscaleHost, port: AppConfig.dashboardPort) {
            return .tailscale
        }

        if AppConfig.allowPublicFallback,
           await NetworkChecker.canConnect(host: AppConfig.publicHost, port: AppConfig.dashboardPort) {
            return .publicIP
        }

        return .tailscale
    }
}
