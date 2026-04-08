import Foundation

/// Manages position display, account summary, and position closing.
@Observable
@MainActor
final class PositionsViewModel {
    var positions: [HLAssetPosition] = []
    var marginSummary: HLMarginSummary?
    var withdrawable: String?
    var assets: [HLAsset] = []

    var isLoading = false
    var error: String?
    var closingCoin: String?

    private let infoService = HyperliquidInfoService.shared
    private let exchangeService = HyperliquidExchangeService.shared
    private let wsService = HyperliquidWebSocketService.shared
    private var refreshTask: Task<Void, Never>?

    var walletAddress: String? {
        WalletConnectManager.shared.walletAddress
    }

    /// Real-time prices from WebSocket.
    var midPrices: [String: String] { wsService.mids }

    // MARK: - Load Positions

    func loadPositions() async {
        guard let address = walletAddress else { return }
        isLoading = true
        error = nil

        do {
            async let stateResult = infoService.getClearinghouseState(address: address)
            async let metaResult = infoService.getMeta()

            let (state, meta) = try await (stateResult, metaResult)

            // Filter to only positions with non-zero size
            positions = state.assetPositions.filter { pos in
                (Double(pos.position.szi) ?? 0) != 0
            }
            marginSummary = state.marginSummary
            withdrawable = state.withdrawable
            assets = meta.universe
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { break }
                await loadPositions()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Close Position

    func closePosition(_ position: HLAssetPosition) async {
        let coin = position.position.coin
        guard let assetIndex = assets.firstIndex(where: { $0.name == coin }),
              let midPriceStr = midPrices[coin],
              let midPrice = Double(midPriceStr) else {
            error = "Cannot close: missing price data for \(coin)"
            return
        }

        closingCoin = coin

        do {
            let response = try await exchangeService.close(
                position: position.position,
                assetIndex: assetIndex,
                currentMidPrice: midPrice
            )

            if response.status == "ok" {
                // Refresh positions
                await loadPositions()
            } else {
                error = "Close failed: \(response.status)"
            }
        } catch {
            self.error = error.localizedDescription
        }

        closingCoin = nil
    }

    // MARK: - Computed

    var accountValue: String {
        guard let summary = marginSummary,
              let val = Double(summary.accountValue) else { return "--" }
        return String(format: "$%.2f", val)
    }

    var totalMarginUsed: String {
        guard let summary = marginSummary,
              let val = Double(summary.totalMarginUsed) else { return "--" }
        return String(format: "$%.2f", val)
    }
}
