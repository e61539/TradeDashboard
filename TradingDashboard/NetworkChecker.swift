import Foundation
import Network

nonisolated private final class ConnectionFinishState: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false

    nonisolated init() {}

    nonisolated func tryFinish() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !finished else { return false }
        finished = true
        return true
    }
}

enum NetworkChecker {
    static func canConnect(host: String, port: Int, timeout: TimeInterval = 0.5) async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: NWEndpoint.Port.IntegerLiteralType(port)),
                using: .tcp
            )

            let queue = DispatchQueue.global(qos: .utility)
            let finishState = ConnectionFinishState()

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if finishState.tryFinish() {
                        connection.cancel()
                        continuation.resume(returning: true)
                    }
                case .failed(_), .cancelled:
                    if finishState.tryFinish() {
                        connection.cancel()
                        continuation.resume(returning: false)
                    }
                default:
                    break
                }
            }

            connection.start(queue: queue)

            queue.asyncAfter(deadline: .now() + timeout) {
                if finishState.tryFinish() {
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }
}
