import Foundation

/// Order form state and placement.
@Observable
@MainActor
final class OrderViewModel {
    var isBuy = true
    var isMarketOrder = true
    var isIsolated = true
    var priceText = ""
    var slippage = 0.01 // 1% default
    var leverage: Double = 1

    /// Size as a numeric value — the slider binds here.
    /// Syncs bidirectionally with `sizeText`.
    var sizeValue: Double = 0 {
        didSet {
            let newText = sizeValue > 0 ? String(sizeValue) : ""
            if newText != sizeText { sizeText = newText }
        }
    }

    /// Size as text — the text field binds here.
    /// Syncs bidirectionally with `sizeValue`.
    var sizeText: String = "" {
        didSet {
            if let v = Double(sizeText), v != sizeValue {
                sizeValue = v
            } else if sizeText.isEmpty && sizeValue != 0 {
                sizeValue = 0
            }
        }
    }
    var isPlacingOrder = false
    var orderResult: String?
    var orderError: String?

    private let exchangeService = HyperliquidExchangeService.shared
    private let wsService = HyperliquidWebSocketService.shared

    // MARK: - Leverage text (synced with slider)

    var leverageText: String {
        get { String(Int(leverage)) }
        set {
            if let v = Double(newValue), v >= 1 {
                leverage = v
            }
        }
    }

    // MARK: - Computed order info

    /// Order value = size × price.
    func orderValue(asset: HLAsset?) -> Double? {
        guard let asset, let size = Double(sizeText), size > 0 else { return nil }
        guard let price = effectivePrice(asset: asset) else { return nil }
        return size * price
    }

    /// Margin required = orderValue / leverage.
    func marginRequired(asset: HLAsset?) -> Double? {
        guard let value = orderValue(asset: asset), leverage > 0 else { return nil }
        return value / leverage
    }

    /// Rough estimated liquidation price.
    /// Long: entry × (1 − 1/leverage), Short: entry × (1 + 1/leverage).
    func estimatedLiqPrice(asset: HLAsset?) -> Double? {
        guard let asset, let price = effectivePrice(asset: asset), leverage > 1 else { return nil }
        if isBuy {
            return price * (1 - 1 / leverage)
        } else {
            return price * (1 + 1 / leverage)
        }
    }

    private func effectivePrice(asset: HLAsset) -> Double? {
        if isMarketOrder {
            return wsService.mids[asset.name].flatMap(Double.init)
        } else {
            return Double(priceText)
        }
    }

    // MARK: - Validation

    func canPlaceOrder(asset: HLAsset?) -> Bool {
        guard asset != nil,
              let size = Double(sizeText), size > 0 else { return false }
        if !isMarketOrder {
            guard let price = Double(priceText), price > 0 else { return false }
        }
        return true
    }

    // MARK: - Place Order

    func placeOrder(asset: HLAsset, assetIndex: Int) async {
        let price: Double
        if isMarketOrder {
            guard let mid = wsService.mids[asset.name].flatMap(Double.init) else {
                orderError = "No market price available"
                return
            }
            price = mid
        } else {
            guard let limitPrice = Double(priceText) else {
                orderError = "Invalid price"
                return
            }
            price = limitPrice
        }

        let input = OrderInput(
            asset: asset,
            assetIndex: assetIndex,
            isBuy: isBuy,
            size: sizeText,
            price: price,
            slippage: slippage,
            isMarket: isMarketOrder,
            reduceOnly: false
        )

        isPlacingOrder = true
        orderResult = nil
        orderError = nil

        do {
            let response = try await exchangeService.place(order: input)
            if response.status == "ok" {
                orderResult = "Order placed successfully"
                sizeText = ""
                priceText = ""
            } else {
                orderError = "Order failed: \(response.status)"
            }
        } catch {
            orderError = error.localizedDescription
        }

        isPlacingOrder = false
    }

    // MARK: - Reset

    func reset() {
        orderResult = nil
        orderError = nil
    }
}
