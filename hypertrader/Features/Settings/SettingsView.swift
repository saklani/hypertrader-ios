import SwiftUI

/// Settings tab — app information only. Wallet connect lives on the Markets FAB;
/// disconnect lives in the wallet header on the Positions tab.
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                networkSection
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Network Section

    private var networkSection: some View {
        Section("Network") {
            MetricRow(label: "Network", value: HyperliquidConfig.chainName)
            MetricRow(label: "RPC", value: HyperliquidConfig.infoURL)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            MetricRow(label: "Version", value: "1.0")
            MetricRow(label: "Build", value: "1")
        }
    }
}

#Preview {
    SettingsView()
}
