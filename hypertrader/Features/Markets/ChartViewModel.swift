import Foundation

/// Candlestick chart data: historical candles + live updates.
@Observable
@MainActor
final class ChartViewModel {
    var candles: [HLCandle] = []
    var selectedInterval = "1h"
    var isLoading = false
    let intervals = ["1m", "5m", "15m", "1h", "4h", "1d"]

    private let infoService = HyperliquidInfoService.shared
    private let wsService = HyperliquidWebSocketService.shared

    // MARK: - Load

    func load(coin: String) async {
        isLoading = true

        let now = UInt64(Date().timeIntervalSince1970 * 1000)
        let intervalMs = intervalToMs(selectedInterval)
        let startTime = now - intervalMs * 200

        do {
            let snapshot = try await infoService.getCandleSnapshot(
                coin: coin,
                interval: selectedInterval,
                startTime: startTime,
                endTime: now
            )
            candles = snapshot

            wsService.onCandleUpdate = { [weak self] candle in
                self?.handleCandleUpdate(candle)
            }
            wsService.subscribeCandles(coin: coin, interval: selectedInterval)
        } catch {
            // Chart stays empty
        }

        isLoading = false
    }

    func changeInterval(_ interval: String, coin: String) async {
        selectedInterval = interval
        candles = []
        await load(coin: coin)
    }

    func clear() {
        candles = []
        wsService.unsubscribeCandles()
        wsService.onCandleUpdate = nil
    }

    // MARK: - Live Updates

    private func handleCandleUpdate(_ candle: HLCandle) {
        if let lastIndex = candles.lastIndex(where: { $0.t == candle.t }) {
            candles[lastIndex] = candle
        } else {
            candles.append(candle)
        }
    }

    // MARK: - Helpers

    private func intervalToMs(_ interval: String) -> UInt64 {
        switch interval {
        case "1m": return 60_000
        case "5m": return 300_000
        case "15m": return 900_000
        case "1h": return 3_600_000
        case "4h": return 14_400_000
        case "1d": return 86_400_000
        default: return 3_600_000
        }
    }
}
