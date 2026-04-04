import Foundation

/// Trade fills for a single asset.
@Observable
@MainActor
final class TradeHistoryViewModel {
    var fills: [HLFill] = []

    private let infoService = HyperliquidInfoService.shared

    func load(address: String, coin: String) async {
        do {
            let allFills = try await infoService.getUserFills(address: address)
            fills = allFills
                .filter { $0.coin == coin }
                .sorted { $0.time > $1.time }
        } catch {
            // Silently fail
        }
    }

    func clear() {
        fills = []
    }
}
