import Foundation

struct OrderInput {
    let asset: HLAsset
    let assetIndex: Int
    let isBuy: Bool
    let size: String
    let price: Double
    let slippage: Double
    let isMarket: Bool
    let reduceOnly: Bool

    var effectivePrice: Double {
        guard isMarket else { return price }
        return isBuy ? price * (1 + slippage) : price * (1 - slippage)
    }
}
