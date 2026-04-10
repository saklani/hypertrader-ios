import Foundation

/// Order form state and placement.
@Observable
@MainActor
final class OrderViewModel {
    var isBuy = true
    var isMarketOrder = true
    var sizeText = ""
    var priceText = ""
    var slippage = 0.01 // 1% default
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
