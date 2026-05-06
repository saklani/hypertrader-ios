import SwiftUI
import CoreImage.CIFilterBuiltins

/// Embeddable wallet picker
/// Designed to be dropped inline into any container (in particular `TradeSheet`'s
/// disconnected branch). No NavigationStack, no toolbar, no dismiss — the host
/// decides when to stop rendering this view. When the wallet is connected + agent
/// is approved, the host should stop mounting `LoginView` entirely.
///
/// The QR code flow is an in-place state swap via `@State showingQR`, not a
/// `navigationDestination` — so nothing here depends on being inside a NavigationStack.
///
///


struct WalletView: View {
    @Bindable var authVM: AuthViewModel
    @State private var searchText = ""
    @State private var showingQR = false
    @State private var copiedURI = false

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        if showingQR {
            qrCodeView
        } else {
            mainContent
        }
    }

    // MARK: - Main content (wallet picker or agent approval)

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                if authVM.wcManager.isConnected {
                    connectedView
                } else {
                    walletPicker
                }

                if let error = authVM.wcManager.error ?? authVM.setupError {
                    Text(error)
                        .font(.caption)
                                                .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
        }
    }

    // MARK: - Wallet Picker

    private var walletPicker: some View {
        VStack(spacing: 16) {
            searchField

            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(filteredWallets) { wallet in
                    walletGridCard(wallet)
                }
            }

            if filteredWallets.isEmpty {
                Text("No wallets match \"\(searchText)\"")
                    .font(.caption)
                                        .padding(.top, 8)
            }

            if authVM.wcManager.isLoading {
                ProgressView("Connecting...")
                    .padding(.top, 8)
            }

            Button {
                Task {
                    await authVM.generateURI()
                    if authVM.pendingURI != nil {
                        showingQR = true
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "qrcode")
                    Text("Connect with QR code")
                }
                .font(.caption)
                            }
            .disabled(authVM.wcManager.isLoading)
            .padding(.top, 4)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                            TextField("Search wallets…", text: $searchText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                                        }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func walletGridCard(_ wallet: WalletApp) -> some View {
        Button {
            authVM.selectedWallet = wallet
            Task { await authVM.connectWallet() }
        } label: {
            VStack(spacing: 8) {
                Image(wallet.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(wallet.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .aspectRatio(contentMode: .fill)
            .roundedCornerWithBorder(
                corners: [.allCorners],
                borderColor: .secondary,
                radius: 4
            )
        }
        .disabled(authVM.wcManager.isLoading)
    }

    private var filteredWallets: [WalletApp] {
        let all = WalletApp.allCases.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        guard !searchText.isEmpty else { return all }
        return all.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - QR Code View

    private var qrCodeView: some View {
        VStack(spacing: 20) {
            // In-place back button (replaces the NavigationStack back chevron)
            HStack {
                Button {
                    showingQR = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Text("Scan with your wallet")
                .font(.title3.bold())

            Text("Open your wallet app and scan\nthis code to connect.")
                .font(.subheadline)
                                .multilineTextAlignment(.center)

            if let error = authVM.wcManager.error ?? authVM.setupError {
                Text(error)
                    .font(.caption)
                                        .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let uri = authVM.pendingURI {
                qrCodeImage(for: uri)
                    .padding(16)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Button {
                    UIPasteboard.general.string = uri
                    copiedURI = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: copiedURI ? "checkmark" : "doc.on.doc")
                        Text(copiedURI ? "Copied" : "Copy URI instead")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
            } else {
                ProgressView("Generating QR code…")
                    .padding(40)
            }

            Spacer()
        }
        .padding()
        .task {
            await authVM.waitForSession()
        }
        .onChange(of: authVM.wcManager.isConnected) { _, connected in
            if connected { showingQR = false }
        }
        .onDisappear {
            copiedURI = false
        }
    }

    @ViewBuilder
    private func qrCodeImage(for uri: String) -> some View {
        if let image = generateQRCode(from: uri) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 240, height: 240)
        } else {
            Text("Failed to generate QR code")
                .font(.caption)
                        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Connected View (agent approval step)

    private var connectedView: some View {
        VStack(spacing: 16) {
            Text(authVM.shortAddress)
                .font(.body.monospaced())
        }
    }
}


// MARK: - Wallet Grid Card

/// Vertical card-style button for the wallet picker grid.
/// Usage: `Button { } label: { VStack { Image(...); Text(...) } }.buttonStyle(WalletGridCardStyle())`
struct WalletGridCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

#Preview("Not Connected") {
    WalletView(authVM: AuthViewModel())
}

#Preview("Connected") {
    WalletView(authVM: AuthViewModel())
        .onAppear {
            WalletConnectManager.shared.setPreviewState(
                connected: true,
                agentReady: false,
                address: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
            )
        }
}
