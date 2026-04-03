import SwiftUI

/// Evenly spaced timeframe selector bar.
struct IntervalPickerBar: View {
    let intervals: [String]
    let selected: String
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(intervals, id: \.self) { interval in
                Button {
                    onSelect(interval)
                } label: {
                    Text(interval)
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selected == interval ? Color.accentColor.opacity(0.15) : Color.clear)
                        .foregroundStyle(selected == interval ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack(spacing: 20) {
        IntervalPickerBar(
            intervals: ["1m", "5m", "15m", "1h", "4h", "1d"],
            selected: "1h",
            onSelect: { _ in }
        )

        IntervalPickerBar(
            intervals: ["1m", "5m", "15m", "1h", "4h", "1d"],
            selected: "1d",
            onSelect: { _ in }
        )
    }
}
