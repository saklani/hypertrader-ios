import SwiftUI
import Charts

struct CandlestickChartView: View {
    let candles: [HLCandle]
    var interval: String = "1h"

    var body: some View {
        if candles.isEmpty {
            emptyState
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart(candles) { candle in
            // Wick: thin vertical line from low to high
            RuleMark(
                x: .value("Time", candle.time),
                yStart: .value("Low", candle.low),
                yEnd: .value("High", candle.high)
            )
            .lineStyle(StrokeStyle(lineWidth: 1))
            .foregroundStyle(candle.isBullish ? Color.green : Color.red)

            // Body: rectangle from open to close
            RectangleMark(
                x: .value("Time", candle.time),
                yStart: .value("Open", candle.open),
                yEnd: .value("Close", candle.close),
                width: .fixed(bodyWidth)
            )
            .foregroundStyle(candle.isBullish ? Color.green : Color.red)
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visibleDomainSeconds)
        .chartScrollPosition(initialX: initialScrollPosition)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                AxisValueLabel(format: xAxisFormat)
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                AxisValueLabel()
                    .font(.caption2.monospaced())
            }
        }
        .frame(height: 250)
    }

    private var emptyState: some View {
        Rectangle()
            .fill(Color(.systemGray6))
            .frame(height: 250)
            .overlay {
                ProgressView("Loading chart...")
                    .font(.caption)
            }
    }

    // MARK: - Layout

    /// Number of candles visible at once.
    private var visibleCandleCount: Int { 40 }

    /// Visible domain in seconds.
    private var visibleDomainSeconds: Int {
        visibleCandleCount * intervalSeconds
    }

    /// Start scrolled to the right (most recent candles).
    private var initialScrollPosition: Date {
        let totalSeconds = Double(candles.count * intervalSeconds)
        let visibleSeconds = Double(visibleDomainSeconds)
        let offsetSeconds = max(0, totalSeconds - visibleSeconds)
        return candles.first?.time.addingTimeInterval(offsetSeconds) ?? Date()
    }

    /// Body width in points. Screen width / visible candles, minus gap.
    private var bodyWidth: CGFloat {
        let screenWidth: CGFloat = 350 // approximate chart plot area
        let candleSlot = screenWidth / CGFloat(visibleCandleCount)
        return max(2, candleSlot - 2) // 2px gap between candles
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
            open: open, close: close,
            high: high, low: low,
            volume: 12.5, n: 100
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
