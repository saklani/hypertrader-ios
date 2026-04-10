import SwiftUI
import CoreImage.CIFilterBuiltins

struct LoginView: View {
    @Bindable var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showingQR = false
    @State private var copiedURI = false

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
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
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .onChange(of: authVM.isFullyReady) { _, ready in
                if ready { dismiss() }
            }
            .navigationDestination(isPresented: $showingQR) {
                qrCodeView
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Text("Hypertrader")
                .font(.largeTitle.bold())
            Text("Trade on Hyperliquid")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
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
                    .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
            }
            .disabled(authVM.wcManager.isLoading)
            .padding(.top, 4)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search wallets…", text: $searchText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func walletGridCard(_ wallet: WalletApp) -> some View {
        Button {
            authVM.selectedWallet = wallet
            Task { await authVM.connectWallet() }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: wallet.iconName)
                    .font(.system(size: 32))
                Text(wallet.displayName)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
        }
        .buttonStyle(WalletGridCardStyle())
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
            Text("Scan with your wallet")
                .font(.title3.bold())
                .padding(.top, 8)

            Text("Open your wallet app and scan\nthis code to connect.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let error = authVM.wcManager.error ?? authVM.setupError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let uri = authVM.pendingURI {
                qrCodeImage(for: uri)
                    .padding(16)
                    .background(Color.white)
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
                .tint(copiedURI ? .green : .blue)
            } else {
                ProgressView("Generating QR code…")
                    .padding(40)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Connect")
        .navigationBarTitleDisplayMode(.inline)
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
                .foregroundStyle(.red)
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
    LoginView(authVM: AuthViewModel())
}
