import SwiftUI

struct SettingsView: View {
    @State private var authVM = AuthViewModel()
    @State private var showCopyURI = false
    @State private var copiedURI = false

    var body: some View {
        NavigationStack {
            List {
                walletSection
                networkSection
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showCopyURI) {
                copyURISheet
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

                ForEach(WalletApp.allCases) { wallet in
                    Button {
                        authVM.selectedWallet = wallet
                        Task { await authVM.connectWallet() }
                    } label: {
                        HStack {
                            Image(systemName: wallet.iconName)
                                .frame(width: 24)
                            Text(wallet.displayName)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if authVM.wcManager.isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Connecting...")
                        Spacer()
                    }
                }

                Button {
                    Task { await authVM.generateURI() }
                    showCopyURI = true
                } label: {
                    Text("Having trouble?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

    // MARK: - Copy URI Sheet

    private var copyURISheet: some View {
        VStack(spacing: 20) {
            SheetHeader(title: "WalletConnect URI")

            if let uri = authVM.pendingURI {
                Text(uri)
                    .font(.caption2.monospaced())
                    .lineLimit(4)
                    .surfaceCard()

                Button {
                    UIPasteboard.general.string = uri
                    copiedURI = true
                    Task { await authVM.waitForSession() }
                } label: {
                    HStack {
                        Image(systemName: copiedURI ? "checkmark" : "doc.on.doc")
                        Text(copiedURI ? "Copied" : "Copy to Clipboard")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(color: copiedURI ? .green : .blue))

                Text("Paste this URI into your wallet app\nto connect.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                ProgressView("Generating URI...")
            }

            Spacer()
        }
        .padding()
        .presentationDetents([.medium])
        .onDisappear {
            copiedURI = false
        }
    }
}

#Preview {
    SettingsView()
}
