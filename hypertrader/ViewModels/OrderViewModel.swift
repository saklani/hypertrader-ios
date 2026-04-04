import Foundation

/// Order form state and placement.
@Observable
@MainActor
final class OrderViewModel {
    var isBuy = true
    var isMarketOrder = true
    var sizeText = ""
    var priceText = ""
    var isPlacingOrder = false
    var orderResult: String?
    var orderError: String?

    private let exchangeService = HyperliquidExchangeService.shared
    private let wsService = HyperliquidWebSocketService.shared

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
        let midPrice = wsService.mids[asset.name].flatMap(Double.init)

        let price: String
        if isMarketOrder {
            guard let mid = midPrice else {
                orderError = "No market price available"
                return
            }
            let slippagePrice = isBuy ? mid * 1.01 : mid * 0.99
            price = String(format: "%.2f", slippagePrice)
        } else {
            price = priceText
        }

        let input = OrderInput(
            asset: asset,
            assetIndex: assetIndex,
            isBuy: isBuy,
            size: sizeText,
            price: price,
            isMarket: isMarketOrder,
            reduceOnly: false
        )

        isPlacingOrder = true
        orderResult = nil
        orderError = nil

        do {
            let response = try await exchangeService.placeOrder(input)
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
