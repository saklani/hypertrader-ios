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
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
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
