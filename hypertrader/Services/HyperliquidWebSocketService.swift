import Foundation

// MARK: - Parsed Message (Sendable — safe to pass from background to main)

enum ParsedMessage: Sendable {
    case mids([String: String])
    case candle(HLCandle)
}

// MARK: - WebSocket Service

/// Streams real-time mid prices and candle data from Hyperliquid via WebSocket.
/// JSON parsing happens on a background thread; only property assignment runs on @MainActor.
@Observable
@MainActor
final class HyperliquidWebSocketService {
    static let shared = HyperliquidWebSocketService()

    private(set) var mids: [String: String] = [:]
    private(set) var candles: [HLCandle] = []
    private(set) var isConnected = false

    private var webSocket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private let urlSession = URLSession(configuration: .default)
    private let wsURL: URL

    // Track current candle subscription for reconnection
    private var subscribedCandleCoin: String?
    private var subscribedCandleInterval: String?

    private init() {
        wsURL = URL(string: "wss://api.hyperliquid-testnet.xyz/ws")!
    }

    // MARK: - Connect

    func connect() {
        guard webSocket == nil else { return }
        reconnectTask?.cancel()

        var request = URLRequest(url: wsURL)
        request.setValue("permessage-deflate", forHTTPHeaderField: "Sec-WebSocket-Extensions")
        let ws = urlSession.webSocketTask(with: request)
        ws.resume()
        webSocket = ws

        // Subscribe to allMids
        let subscribeMsg = #"{"method":"subscribe","subscription":{"type":"allMids"}}"#
        ws.send(.string(subscribeMsg)) { _ in }

        // Re-subscribe to candles if we had an active subscription
        if let coin = subscribedCandleCoin, let interval = subscribedCandleInterval {
            sendCandleSubscribe(ws: ws, coin: coin, interval: interval)
        }

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

    // MARK: - Candle Subscription

    func subscribeCandles(coin: String, interval: String) {
        if subscribedCandleCoin != nil {
            unsubscribeCandles()
        }

        subscribedCandleCoin = coin
        subscribedCandleInterval = interval

        guard let ws = webSocket else { return }
        sendCandleSubscribe(ws: ws, coin: coin, interval: interval)
    }

    func unsubscribeCandles() {
        if let coin = subscribedCandleCoin, let interval = subscribedCandleInterval, let ws = webSocket {
            let msg = "{\"method\":\"unsubscribe\",\"subscription\":{\"type\":\"candle\",\"coin\":\"\(coin)\",\"interval\":\"\(interval)\"}}"
            ws.send(.string(msg)) { _ in }
        }
        subscribedCandleCoin = nil
        subscribedCandleInterval = nil
        candles = []
    }

    private func sendCandleSubscribe(ws: URLSessionWebSocketTask, coin: String, interval: String) {
        let msg = "{\"method\":\"subscribe\",\"subscription\":{\"type\":\"candle\",\"coin\":\"\(coin)\",\"interval\":\"\(interval)\"}}"
        ws.send(.string(msg)) { _ in }
    }

    /// Set initial candle history (from REST snapshot).
    func setCandles(_ initialCandles: [HLCandle]) {
        candles = initialCandles
    }

    // MARK: - Receive Loop

    private func startReceiveLoop() {
        receiveTask?.cancel()
        let ws = webSocket
        receiveTask = Task.detached { [weak self] in
            // This runs on the background thread pool (Task.detached inherits no actor)
            while !Task.isCancelled {
                guard let ws else { break }
                do {
                    let message = try await ws.receive()
                    let text: String?
                    switch message {
                    case .string(let t):
                        text = t
                    case .data(let d):
                        text = String(data: d, encoding: .utf8)
                    @unknown default:
                        text = nil
                    }
                    // Parse on background thread (no actor hop)
                    if let text, let parsed = HyperliquidWebSocketService.parseMessage(text) {
                        // Hop to main thread only for the assignment
                        await self?.applyParsed(parsed)
                    }
                } catch {
                    break
                }
            }
            if !Task.isCancelled {
                await MainActor.run {
                    self?.webSocket = nil
                    self?.isConnected = false
                    self?.scheduleReconnect()
                }
            }
        }
    }

    // MARK: - Parsing (runs on background thread — no actor state accessed)

    /// Pure function: parses raw WebSocket JSON into a typed result.
    /// `nonisolated static` = no @MainActor, no self, runs on whatever thread calls it.
    nonisolated static func parseMessage(_ text: String) -> ParsedMessage? {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let channel = json["channel"] as? String else {
            return nil
        }

        switch channel {
        case "allMids":
            if let msgData = json["data"] as? [String: Any],
               let newMids = msgData["mids"] as? [String: String] {
                return .mids(newMids)
            }

        case "candle":
            if let candleData = json["data"] as? [String: Any],
               let jsonData = try? JSONSerialization.data(withJSONObject: candleData),
               let candle = try? JSONDecoder().decode(HLCandle.self, from: jsonData) {
                return .candle(candle)
            }

        default:
            break
        }

        return nil
    }

    // MARK: - Apply (runs on @MainActor — just assignment, cheap)

    /// Applies a parsed message to the service state. @MainActor (inherited from class).
    func applyParsed(_ msg: ParsedMessage) {
        switch msg {
        case .mids(let newMids):
            mids = newMids
        case .candle(let candle):
            if let lastIndex = candles.lastIndex(where: { $0.t == candle.t }) {
                candles[lastIndex] = candle
            } else {
                candles.append(candle)
            }
        }
    }

    // MARK: - Convenience (for tests — calls parse + apply in one step)

    /// Parses and applies a message. Runs on @MainActor since applyParsed needs it.
    func handleMessage(_ text: String) {
        if let parsed = Self.parseMessage(text) {
            applyParsed(parsed)
        }
    }

    // Keep for test compatibility
    func handleCandleUpdate(_ data: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data),
              let candle = try? JSONDecoder().decode(HLCandle.self, from: jsonData) else {
            return
        }
        applyParsed(.candle(candle))
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
