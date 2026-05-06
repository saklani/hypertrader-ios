import SwiftUI
import Charts

/// Self-contained candlestick chart for a given coin. Owns its own `ChartViewModel`,
/// embeds `IntervalPickerBar` for interval selection, and reads the live mid price
/// from `HyperliquidWebSocketService.shared.mids` for the overlay line.
///
/// Currently not mounted in `MarketView` — the chart is intentionally hidden.
/// When you re-enable it, just drop `CandlestickChartView(coin: market.selectedAsset?.name)`
/// wherever you want it in the layout.
struct CandlestickChartView: View {
    let coin: String?

    @State private var chart = ChartViewModel()

    var body: some View {
        VStack(spacing: 0) {
            IntervalPickerBar(
                intervals: chart.intervals,
                selected: chart.selectedInterval
            ) { interval in
                guard let coin else { return }
                Task { await chart.changeInterval(interval, coin: coin) }
            }

            if chart.candles.isEmpty {
                emptyState
            } else {
                chartView
            }
        }
        .task(id: coin) {
            guard let coin else { return }
            await chart.load(coin: coin)
        }
    }

    // MARK: - Chart

    private var chartView: some View {
        Chart {
            ForEach(chart.candles) { candle in
                // Wick
                RuleMark(
                    x: .value("Time", candle.time),
                    yStart: .value("Low", candle.low),
                    yEnd: .value("High", candle.high)
                )
                .lineStyle(StrokeStyle(lineWidth: 1))

                // Body
                RectangleMark(
                    x: .value("Time", candle.time),
                    yStart: .value("Open", candle.open),
                    yEnd: .value("Close", candle.close),
                    width: .fixed(bodyWidth)
                )
            }

            // Current price line
            if let price = currentPrice {
                RuleMark(y: .value("Price", price))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .trailing, alignment: .leading, spacing: 4) {
                        Text(formatDisplayPrice(price))
                            .font(.caption2.bold().monospaced())
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visibleDomainSeconds)
        .chartScrollPosition(initialX: initialScrollPosition)
        .chartXScale(domain: xDomain)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                AxisValueLabel(format: xAxisFormat)
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                AxisValueLabel()
                    .font(.caption2.monospaced())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        Rectangle()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                ProgressView("Loading chart...")
                    .font(.caption)
            }
    }

    // MARK: - Live mid price (from WS singleton)

    private var currentPrice: Double? {
        guard let coin else { return nil }
        return HyperliquidWebSocketService.shared.mids[coin].flatMap(Double.init)
    }

    // MARK: - Layout

    /// Number of candles visible at once.
    private var visibleCandleCount: Int { 50 }

    /// Visible domain in seconds.
    private var visibleDomainSeconds: Int {
        visibleCandleCount * intervalSeconds
    }

    private var rightPaddingCandles: Int { 5 }

    /// X-axis domain: from first candle to last candle + 5 candles of padding on the right.
    private var xDomain: ClosedRange<Date> {
        let first = chart.candles.first?.time ?? Date()
        let last = chart.candles.last?.time ?? Date()
        let rightPadding = Double(rightPaddingCandles * intervalSeconds)
        return first...last.addingTimeInterval(rightPadding)
    }

    /// Start scrolled to the end (most recent candles + padding visible).
    private var initialScrollPosition: Date {
        let last = chart.candles.last?.time ?? Date()
        let rightPadding = Double(rightPaddingCandles * intervalSeconds)
        let endOfDomain = last.addingTimeInterval(rightPadding)
        let visibleSeconds = Double(visibleDomainSeconds)
        return endOfDomain.addingTimeInterval(-visibleSeconds)
    }

    /// Body width in points. Approximate chart width / visible candles, minus gap.
    private var bodyWidth: CGFloat {
        let chartWidth: CGFloat = 330 // approximate plot area on most iPhones
        let candleSlot = chartWidth / CGFloat(visibleCandleCount)
        return max(3, candleSlot - 3)
    }

    private var intervalSeconds: Int {
        switch chart.selectedInterval {
        case "1m": return 60
        case "5m": return 300
        case "15m": return 900
        case "1h": return 3600
        case "4h": return 14400
        case "1d": return 86400
        default: return 3600
        }
    }

    /// X-axis label format adapts to interval.
    private var xAxisFormat: Date.FormatStyle {
        switch chart.selectedInterval {
        case "1d": return .dateTime.month(.abbreviated).day()
        case "4h": return .dateTime.day().hour()
        default: return .dateTime.hour().minute()
        }
    }

    private var yDomain: ClosedRange<Double> {
        let lows = chart.candles.map(\.low)
        let highs = chart.candles.map(\.high)
        guard let minLow = lows.min(), let maxHigh = highs.max(), maxHigh > minLow else {
            return 0...1
        }
        let padding = (maxHigh - minLow) * 0.05
        return (minLow - padding)...(maxHigh + padding)
    }
}

#Preview {
    CandlestickChartView(coin: "BTC")
        .padding()
}
