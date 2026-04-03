import Foundation

/// Read-only Hyperliquid API client. No authentication required.
final class HyperliquidInfoService {
    static let shared = HyperliquidInfoService()

    private let baseURL: URL
    private let session: URLSession

    init(isTestnet: Bool = true) {
        let urlString = isTestnet
            ? "https://api.hyperliquid-testnet.xyz"
            : "https://api.hyperliquid.xyz"
        self.baseURL = URL(string: urlString)!
        self.session = URLSession.shared
    }

    // MARK: - Public API

    /// Get asset metadata (names, decimals, indices)
    func getMeta() async throws -> HLAssetMeta {
        try await post(body: ["type": "meta"])
    }

    /// Get all mid prices: { "BTC": "95123.5", "ETH": "3200.1", ... }
    func getAllMids() async throws -> [String: String] {
        try await post(body: ["type": "allMids"])
    }

    /// Get clearinghouse state (positions + margin) for a wallet address
    func getClearinghouseState(address: String) async throws -> HLClearinghouseState {
        try await post(body: ["type": "clearinghouseState", "user": address])
    }

    /// Get open orders for a wallet address
    func getOpenOrders(address: String) async throws -> [HLOpenOrder] {
        try await post(body: ["type": "openOrders", "user": address])
    }

    /// Get recent trade fills for a wallet address
    func getUserFills(address: String) async throws -> [HLFill] {
        try await post(body: ["type": "userFills", "user": address])
    }

    /// Get asset metadata + context (24h volume, mark price, etc.) for all perps
    func getMetaAndAssetCtxs() async throws -> HLMetaAndAssetCtxs {
        try await post(body: ["type": "metaAndAssetCtxs"])
    }

    /// Get asset metadata + context for a specific builder dex (HIP-3)
    func getMetaAndAssetCtxs(dex: String) async throws -> HLMetaAndAssetCtxs {
        try await postAny(body: ["type": "metaAndAssetCtxs", "dex": dex])
    }

    /// Get spot metadata + context for all spot pairs
    func getSpotMetaAndAssetCtxs() async throws -> HLSpotMetaAndAssetCtxs {
        try await post(body: ["type": "spotMetaAndAssetCtxs"])
    }

    /// Get historical candle data for a coin
    func getCandleSnapshot(coin: String, interval: String, startTime: UInt64, endTime: UInt64) async throws -> [HLCandle] {
        let reqBody: [String: Any] = [
            "type": "candleSnapshot",
            "req": ["coin": coin, "interval": interval, "startTime": startTime, "endTime": endTime] as [String: Any]
        ]
        print("[API] candleSnapshot request: \(reqBody)")
        return try await postAny(body: reqBody)
    }

    /// Get all builder dexes: [null, {name: "xyz", ...}, ...]
    func getPerpDexs() async throws -> [HLPerpDex?] {
        try await post(body: ["type": "perpDexs"])
    }

    /// Get perp categories: [["xyz:TSLA", "stocks"], ["xyz:GOLD", "commodities"], ...]
    func getPerpCategories() async throws -> [[String]] {
        try await post(body: ["type": "perpCategories"])
    }

    // MARK: - Private

    private func post<T: Decodable>(body: [String: String]) async throws -> T {
        let url = baseURL.appendingPathComponent("info")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw HLError.apiError(statusCode: statusCode, message: body)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    private func postAny<T: Decodable>(body: [String: Any]) async throws -> T {
        let url = baseURL.appendingPathComponent("info")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw HLError.apiError(statusCode: statusCode, message: body)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - Errors

enum HLError: LocalizedError {
    case apiError(statusCode: Int, message: String)
    case signingFailed(String)
    case walletNotConnected
    case agentNotApproved
    case encodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .apiError(let code, let msg):
            return "API error (\(code)): \(msg)"
        case .signingFailed(let msg):
            return "Signing failed: \(msg)"
        case .walletNotConnected:
            return "Wallet not connected"
        case .agentNotApproved:
            return "Agent wallet not approved"
        case .encodingFailed(let msg):
            return "Encoding failed: \(msg)"
        }
    }
}
