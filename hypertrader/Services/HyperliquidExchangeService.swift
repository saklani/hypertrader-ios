import Foundation

/// Handles Hyperliquid exchange actions (place order, cancel, close position).
/// Signs locally with the agent wallet key stored in Keychain.
@MainActor
final class HyperliquidExchangeService {
    static let shared = HyperliquidExchangeService()

    private let baseURL = URL(string: "https://api.hyperliquid-testnet.xyz/exchange")!

    // Builder fee: 3bp (30 tenths of a basis point) sent to your address
    private let builder = HLBuilderWire(b: "0x73bb3A6A37e95BA396ffabA868F912485Bed4B03", f: 30)

    // MARK: - Place Order

    func placeOrder(_ input: OrderInput) async throws -> HLExchangeResponse {
        guard let agentKey = KeychainManager.loadAgentKey() else {
            throw HLError.agentNotApproved
        }

        let orderWire = input.toWire()
        let (signature, nonce) = try HyperliquidSigner.signOrder(
            orders: [orderWire],
            builder: builder,
            agentPrivateKey: agentKey
        )

        let action: [String: Any] = [
            "type": "order",
            "orders": [[
                "a": orderWire.a,
                "b": orderWire.b,
                "p": orderWire.p,
                "s": orderWire.s,
                "r": orderWire.r,
                "t": encodeOrderType(orderWire.t),
                "c": orderWire.c as Any
            ]],
            "grouping": "na",
            "builder": ["b": builder.b, "f": builder.f]
        ]

        return try await postExchange(action: action, nonce: nonce, signature: signature)
    }

    // MARK: - Cancel Order

    func cancelOrder(assetIndex: Int, orderId: Int) async throws -> HLExchangeResponse {
        guard let agentKey = KeychainManager.loadAgentKey() else {
            throw HLError.agentNotApproved
        }

        let cancel = HLCancelWire(a: assetIndex, o: orderId)
        let (signature, nonce) = try HyperliquidSigner.signCancel(
            cancels: [cancel],
            agentPrivateKey: agentKey
        )

        let action: [String: Any] = [
            "type": "cancel",
            "cancels": [["a": assetIndex, "o": orderId]]
        ]

        return try await postExchange(action: action, nonce: nonce, signature: signature)
    }

    // MARK: - Close Position

    func closePosition(
        position: HLPosition,
        assetIndex: Int,
        currentMidPrice: Double
    ) async throws -> HLExchangeResponse {
        let size = position.absSize
        let isClosingLong = position.isLong

        // 1% slippage for IOC fill
        let slippageMultiplier = isClosingLong ? 0.99 : 1.01
        let slippagePrice = currentMidPrice * slippageMultiplier

        let input = OrderInput(
            asset: HLAsset(name: position.coin, szDecimals: 4, maxLeverage: 50, onlyIsolated: nil, isDelisted: nil),
            assetIndex: assetIndex,
            isBuy: !isClosingLong,
            size: formatPrice(String(size)),
            price: formatPrice(String(format: "%.2f", slippagePrice)),
            isMarket: true,
            reduceOnly: true
        )

        return try await placeOrder(input)
    }

    // MARK: - Approve Agent (one-time, signed by master wallet)

    /// Post the approveAgent action after the master wallet signs it via WalletConnect.
    func postApproveAgent(
        agentAddress: String,
        nonce: UInt64,
        signature: HLSignature
    ) async throws {
        let action: [String: Any] = [
            "type": "approveAgent",
            "hyperliquidChain": "Testnet",
            "signatureChainId": "0x66eee",
            "agentAddress": agentAddress,
            "agentName": "hypertrader",
            "nonce": nonce
        ]

        let body: [String: Any] = [
            "action": action,
            "nonce": nonce,
            "signature": [
                "r": signature.r,
                "s": signature.s,
                "v": signature.v
            ],
            "vaultAddress": NSNull()
        ]

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let msg = String(data: data, encoding: .utf8) ?? "unknown"
            throw HLError.apiError(statusCode: statusCode, message: msg)
        }
    }

    // MARK: - Private

    private func postExchange(
        action: [String: Any],
        nonce: UInt64,
        signature: HLSignature
    ) async throws -> HLExchangeResponse {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "action": action,
            "nonce": nonce,
            "signature": [
                "r": signature.r,
                "s": signature.s,
                "v": signature.v
            ],
            "vaultAddress": NSNull()
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let msg = String(data: data, encoding: .utf8) ?? "unknown"
            throw HLError.apiError(statusCode: statusCode, message: msg)
        }

        return try JSONDecoder().decode(HLExchangeResponse.self, from: data)
    }

    private func encodeOrderType(_ t: HLOrderTypeWire) -> [String: Any] {
        if let limit = t.limit {
            return ["limit": ["tif": limit.tif]]
        } else if let trigger = t.trigger {
            return ["trigger": [
                "isMarket": trigger.isMarket,
                "triggerPx": trigger.triggerPx,
                "tpsl": trigger.tpsl
            ]]
        }
        return [:]
    }
}
