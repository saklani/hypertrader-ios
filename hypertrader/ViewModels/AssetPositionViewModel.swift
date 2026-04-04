import Foundation

/// Active position for a single asset + close functionality.
@Observable
@MainActor
final class AssetPositionViewModel {
    var activePosition: HLAssetPosition?
    var isClosing = false
    var error: String?

    private let infoService = HyperliquidInfoService.shared
    private let exchangeService = HyperliquidExchangeService.shared
    private let wsService = HyperliquidWebSocketService.shared

    func load(address: String, coin: String) async {
        do {
            let state = try await infoService.getClearinghouseState(address: address)
            activePosition = state.assetPositions.first {
                $0.position.coin == coin && (Double($0.position.szi) ?? 0) != 0
            }
        } catch {
            // Silently fail
        }
    }

    func closePosition(assetIndex: Int) async {
        guard let position = activePosition,
              let midPriceStr = wsService.mids[position.position.coin],
              let midPrice = Double(midPriceStr) else { return }

        isClosing = true
        do {
            let response = try await exchangeService.closePosition(
                position: position.position,
                assetIndex: assetIndex,
                currentMidPrice: midPrice
            )
            if response.status == "ok" {
                activePosition = nil
            }
        } catch {
            self.error = error.localizedDescription
        }
        isClosing = false
    }

    func clear() {
        activePosition = nil
    }
}
