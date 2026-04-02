import Foundation

/// Manages market data for the Markets tab: unified perps + spot with live prices, filtering, and search.
@Observable
@MainActor
final class MarketsViewModel {
    var allItems: [MarketItem] = []
    var selectedFilter: MarketFilter = .all
    var searchText = ""
    var isLoading = false
    var error: String?

    private let infoService = HyperliquidInfoService.shared
    private let wsService = HyperliquidWebSocketService.shared

    private static let tradFiCategories: Set<String> = ["stocks", "commodities", "indices", "fx", "preipo"]

    // MARK: - Computed

    /// Real-time prices from WebSocket.
    var midPrices: [String: String] { wsService.mids }

    /// Items filtered by selected tab and search text.
    var filteredItems: [MarketItem] {
        var items = allItems

        switch selectedFilter {
        case .all:
            break
        case .perps:
            items = items.filter { !$0.isSpot }
        case .spot:
            items = items.filter { $0.isSpot }
        case .crypto:
            items = items.filter { !$0.isSpot && (!$0.isBuilderPerp || $0.category == "crypto") }
        case .tradFi:
            items = items.filter { Self.tradFiCategories.contains($0.category ?? "") }
        case .hip3:
            items = items.filter { $0.isBuilderPerp }
        }

        if !searchText.isEmpty {
            items = items.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        return items
    }

    /// Get live price for a market item.
    func price(for item: MarketItem) -> Double? {
        guard let str = midPrices[item.rawName] else { return nil }
        return Double(str)
    }

    /// Calculate 24h % change for a market item.
    func change24h(for item: MarketItem) -> Double? {
        guard let current = price(for: item),
              item.prevDayPx > 0 else { return nil }
        return (current - item.prevDayPx) / item.prevDayPx * 100
    }

    // MARK: - Load Data

    func loadMarketData() async {
        isLoading = true
        error = nil

        do {
            // Phase 1: Fetch native perps, dex list, categories, and spot in parallel
            async let nativeResult = infoService.getMetaAndAssetCtxs()
            async let dexsResult = infoService.getPerpDexs()
            async let categoriesResult = infoService.getPerpCategories()
            async let spotResult = infoService.getSpotMetaAndAssetCtxs()

            let native = try await nativeResult
            let dexs = try await dexsResult
            let categories = try await categoriesResult
            let spot = try await spotResult

            // Build category lookup: "xyz:TSLA" -> "stocks"
            var categoryMap: [String: String] = [:]
            for entry in categories where entry.count >= 2 {
                categoryMap[entry[0]] = entry[1]
            }

            // Native perps -> MarketItems (all crypto)
            var items: [MarketItem] = zip(native.meta.universe, native.assetCtxs).map { asset, ctx in
                MarketItem(
                    name: asset.name,
                    rawName: asset.name,
                    dayNtlVlm: Double(ctx.dayNtlVlm) ?? 0,
                    prevDayPx: Double(ctx.prevDayPx) ?? 0,
                    isSpot: false,
                    isBuilderPerp: false,
                    category: nil
                )
            }

            // Phase 2: Fetch each builder dex in parallel
            let dexNames = dexs.compactMap { $0 } // filter out null (native dex)
            let dexResults = await fetchBuilderDexes(dexNames)

            for (dex, result) in dexResults {
                let dexItems: [MarketItem] = zip(result.meta.universe, result.assetCtxs).map { asset, ctx in
                    let rawName = "\(dex):\(asset.name)"
                    return MarketItem(
                        name: asset.name,
                        rawName: rawName,
                        dayNtlVlm: Double(ctx.dayNtlVlm) ?? 0,
                        prevDayPx: Double(ctx.prevDayPx) ?? 0,
                        isSpot: false,
                        isBuilderPerp: true,
                        category: categoryMap[rawName]
                    )
                }
                items.append(contentsOf: dexItems)
            }

            // Spot -> MarketItems
            let spotItems: [MarketItem] = zip(spot.meta.universe, spot.assetCtxs).map { pair, ctx in
                MarketItem(
                    name: pair.name,
                    rawName: "spot:\(pair.name)",
                    dayNtlVlm: Double(ctx.dayNtlVlm) ?? 0,
                    prevDayPx: Double(ctx.prevDayPx) ?? 0,
                    isSpot: true,
                    isBuilderPerp: false,
                    category: nil
                )
            }
            items.append(contentsOf: spotItems)

            // Sort by volume descending
            allItems = items.sorted { $0.dayNtlVlm > $1.dayNtlVlm }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Fetch all builder dexes in parallel, returning successful results.
    private func fetchBuilderDexes(_ dexNames: [String]) async -> [(String, HLMetaAndAssetCtxs)] {
        await withTaskGroup(of: (String, HLMetaAndAssetCtxs?).self) { group in
            for dex in dexNames {
                group.addTask {
                    let result = try? await self.infoService.getMetaAndAssetCtxs(dex: dex)
                    return (dex, result)
                }
            }

            var results: [(String, HLMetaAndAssetCtxs)] = []
            for await (dex, result) in group {
                if let result { results.append((dex, result)) }
            }
            return results
        }
    }
}
