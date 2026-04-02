import SwiftUI

// MARK: - Metric Row

/// Label + value row with monospaced value text.
/// Usage: `MetricRow(label: "Account Value", value: "$1,234.56")`
struct MetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.body.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Detail Column

/// Small label above a value, used in detail grids.
/// Usage: `DetailColumn(label: "Size", value: "1.5000", alignment: .leading)`
struct DetailColumn: View {
    let label: String
    let value: String
    var alignment: HorizontalAlignment = .leading
    var valueColor: Color? = nil

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(valueColor ?? .primary)
        }
    }
}

#Preview("List Item Styles") {
    List {
        MetricRow(label: "Account Value", value: "$12,345.67")
        MetricRow(label: "Margin Used", value: "$1,234.00")

        HStack {
            DetailColumn(label: "Size", value: "1.5000")
            Spacer()
            DetailColumn(label: "Entry", value: "3200.00", alignment: .center)
            Spacer()
            DetailColumn(label: "uPnL", value: "+150.00", alignment: .trailing, valueColor: .green)
        }
    }
}
