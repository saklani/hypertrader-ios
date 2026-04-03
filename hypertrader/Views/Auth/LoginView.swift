import SwiftUI

struct LoginView: View {
    @State private var authVM = AuthViewModel()
    @State private var showCopyURI = false
    @State private var copiedURI = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("Hypertrader")
                    .font(.largeTitle.bold())
                Text("Trade on Hyperliquid")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if authVM.wcManager.isConnected {
                connectedView
            } else {
                walletPicker
            }

            if let error = authVM.wcManager.error ?? authVM.setupError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Wallet Picker

    private var walletPicker: some View {
        VStack(spacing: 12) {
            ForEach(WalletApp.allCases) { wallet in
                walletButton(wallet)
            }

            if authVM.wcManager.isLoading {
                ProgressView("Connecting...")
                    .padding(.top, 8)
            }

            Button {
                Task { await authVM.generateURI() }
                showCopyURI = true
            } label: {
                Text("Having trouble?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(authVM.wcManager.isLoading)
            .padding(.top, 4)
        }
        .padding(.horizontal)
        .sheet(isPresented: $showCopyURI) {
            copyURISheet
        }
    }

    private func walletButton(_ wallet: WalletApp) -> some View {
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
        .buttonStyle(WalletRowButtonStyle())
        .disabled(authVM.wcManager.isLoading)
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

    // MARK: - Connected View

    private var connectedView: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(authVM.shortAddress)
                    .font(.headline.monospaced())
            }

            if authVM.isAgentApproved {
                Text("Trading enabled")
                    .foregroundStyle(.green)
            } else {
                Button {
                    Task { await authVM.setupAgentWallet() }
                } label: {
                    Text("Approve Trading")
                }
                .buttonStyle(PrimaryButtonStyle(color: .orange, isLoading: authVM.isSettingUpAgent))
                .disabled(authVM.isSettingUpAgent)
                .padding(.horizontal)

                Text("This opens your wallet to approve an agent key.\nAfter this, trades sign automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    LoginView()
}
