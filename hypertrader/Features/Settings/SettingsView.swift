import SwiftUI

struct SettingsView: View {
    @State private var authVM = AuthViewModel()
    @State private var showLoginSheet = false

    var body: some View {
        NavigationStack {
            List {
                walletSection
                networkSection
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showLoginSheet) {
                LoginView(authVM: authVM)
            }
        }
    }

    // MARK: - Wallet Section

    private var walletSection: some View {
        Section("Wallet") {
            if authVM.wcManager.isConnected {
                // Connected state
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(authVM.shortAddress)
                        .font(.body.monospaced())
                    Spacer()
                }

                if authVM.isAgentApproved {
                    HStack {
                        StatusChip("Trading Enabled", color: .green)
                        Spacer()
                    }
                } else {
                    Button {
                        Task { await authVM.setupAgentWallet() }
                    } label: {
                        Text("Approve Trading")
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .orange, isLoading: authVM.isSettingUpAgent))
                    .disabled(authVM.isSettingUpAgent)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                    Text("Approves an agent key so trades sign automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Disconnect Wallet", role: .destructive) {
                    Task { await authVM.disconnect() }
                }
            } else {
                // Not connected
                Text("No wallet connected")
                    .foregroundStyle(.secondary)

                Button {
                    showLoginSheet = true
                } label: {
                    Text("Connect Wallet")
                }
                .buttonStyle(PrimaryButtonStyle(color: .blue))
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if let error = authVM.wcManager.error ?? authVM.setupError {
                StatusMessage(error, isError: true)
            }
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
