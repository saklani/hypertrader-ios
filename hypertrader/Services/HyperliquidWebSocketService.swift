import Foundation

/// Streams real-time mid prices from Hyperliquid via WebSocket.
/// Subscribe to `allMids` for sub-second price updates across all assets.
@Observable
@MainActor
final class HyperliquidWebSocketService {
    static let shared = HyperliquidWebSocketService()

    private(set) var mids: [String: String] = [:]
    private(set) var isConnected = false

    private var webSocket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private let urlSession = URLSession(configuration: .default)
    private let wsURL: URL

    private init() {
        wsURL = URL(string: "wss://api.hyperliquid-testnet.xyz/ws")!
    }

    // MARK: - Connect

    func connect() {
        guard webSocket == nil else { return }
        reconnectTask?.cancel()

        let ws = urlSession.webSocketTask(with: wsURL)
        ws.resume()
        webSocket = ws

        // Subscribe to allMids
        let subscribeMsg = """
        {"method":"subscribe","subscription":{"type":"allMids"}}
        """
        ws.send(.string(subscribeMsg)) { _ in }

        isConnected = true
        startReceiveLoop()
    }

    // MARK: - Disconnect

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        isConnected = false
    }

    // MARK: - Receive Loop

    private func startReceiveLoop() {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let ws = self?.webSocket else { break }
                do {
                    let message = try await ws.receive()
                    switch message {
                    case .string(let text):
                        self?.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self?.handleMessage(text)
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    // Connection lost
                    break
                }
            }
            // If we broke out of the loop, trigger reconnect
            if !Task.isCancelled {
                self?.webSocket = nil
                self?.isConnected = false
                self?.scheduleReconnect()
            }
        }
    }

    // MARK: - Message Handling

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let channel = json["channel"] as? String,
              channel == "allMids",
              let msgData = json["data"] as? [String: Any],
              let newMids = msgData["mids"] as? [String: String] else {
            return
        }
        mids = newMids
    }

    // MARK: - Reconnection

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            var delay: UInt64 = 1
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { break }
                self?.connect()
                if self?.isConnected == true { break }
                delay = min(delay * 2, 30)
            }
        }
    }
}
