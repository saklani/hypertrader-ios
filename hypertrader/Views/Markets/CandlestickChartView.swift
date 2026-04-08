import SwiftUI
import Charts

struct CandlestickChartView: View {
    let candles: [HLCandle]
    var interval: String = "1h"
    var currentPrice: Double? = nil

    var body: some View {
        if candles.isEmpty {
            emptyState
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart {
            ForEach(candles) { candle in
                // Wick
                RuleMark(
                    x: .value("Time", candle.time),
                    yStart: .value("Low", candle.low),
                    yEnd: .value("High", candle.high)
                )
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(candle.isBullish ? Color.green : Color.red)

                // Body
                RectangleMark(
                    x: .value("Time", candle.time),
                    yStart: .value("Open", candle.open),
                    yEnd: .value("Close", candle.close),
                    width: .fixed(bodyWidth)
                )
                .foregroundStyle(candle.isBullish ? Color.green : Color.red)
            }

            // Current price line
            if let price = currentPrice {
                RuleMark(y: .value("Price", price))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(Color.accentColor.opacity(0.7))
                    .annotation(position: .trailing, alignment: .leading, spacing: 4) {
                        Text(formatChartPrice(price))
                            .font(.caption2.bold().monospaced())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
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
        .containerRelativeFrame(.vertical) { height, _ in height * 0.5 }
    }

    private var emptyState: some View {
        Rectangle()
            .fill(Color(.systemGray6))
            .containerRelativeFrame(.vertical) { height, _ in height * 0.5 }
            .overlay {
                ProgressView("Loading chart...")
                    .font(.caption)
            }
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
        let first = candles.first?.time ?? Date()
        let last = candles.last?.time ?? Date()
        let rightPadding = Double(rightPaddingCandles * intervalSeconds)
        return first...last.addingTimeInterval(rightPadding)
    }

    /// Start scrolled to the end (most recent candles + padding visible).
    private var initialScrollPosition: Date {
        let last = candles.last?.time ?? Date()
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
        switch interval {
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
        switch interval {
        case "1d": return .dateTime.month(.abbreviated).day()
        case "4h": return .dateTime.day().hour()
        default: return .dateTime.hour().minute()
        }
    }

    private var yDomain: ClosedRange<Double> {
        let lows = candles.map(\.low)
        let highs = candles.map(\.high)
        guard let minLow = lows.min(), let maxHigh = highs.max(), maxHigh > minLow else {
            return 0...1
        }
        let padding = (maxHigh - minLow) * 0.05
        return (minLow - padding)...(maxHigh + padding)
    }

    private func formatChartPrice(_ price: Double) -> String {
        formatDisplayPrice(price)
    }
}

// MARK: - Mock Data Helper

private func mockCandles(count: Int = 200, interval: String = "1h", basePrice: Double = 95000) -> [HLCandle] {
    let now = Date()
    let intervalSeconds: Double = switch interval {
    case "1m": 60
    case "5m": 300
    case "15m": 900
    case "4h": 14400
    case "1d": 86400
    default: 3600
    }

    var price = basePrice
    return (0..<count).map { i in
        price += Double.random(in: -200...200)
        let open = price
        let close = price + Double.random(in: -150...150)
        let high = max(open, close) + Double.random(in: 10...100)
        let low = min(open, close) - Double.random(in: 10...100)
        price = close
        let time = UInt64(now.addingTimeInterval(Double(i - count) * intervalSeconds).timeIntervalSince1970 * 1000)
        return HLCandle(
            t: time, T: time + UInt64(intervalSeconds * 1000),
            s: "BTC", i: interval,
            o: String(format: "%.2f", open), c: String(format: "%.2f", close),
            h: String(format: "%.2f", high), l: String(format: "%.2f", low),
            v: "12.5", n: 100
        )
    }
}

// MARK: - Previews

#Preview("1h - 200 candles (scrollable)") {
    CandlestickChartView(candles: mockCandles(count: 200, interval: "1h"), interval: "1h")
        .padding()
}

#Preview("1m - 200 candles") {
    CandlestickChartView(candles: mockCandles(count: 200, interval: "1m"), interval: "1m")
        .padding()
}

#Preview("1d - 100 candles") {
    CandlestickChartView(candles: mockCandles(count: 100, interval: "1d", basePrice: 60000), interval: "1d")
        .padding()
}

#Preview("Few candles") {
    CandlestickChartView(candles: mockCandles(count: 10, interval: "1h"), interval: "1h")
        .padding()
}

#Preview("Empty") {
    CandlestickChartView(candles: [])
        .padding()
}
