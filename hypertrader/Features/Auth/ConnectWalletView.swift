import SwiftUI

/// Full-width "Connect a wallet to trade" call-to-action.
/// Self-contained: owns its own `AuthViewModel` and presents `LoginView` as a sheet
/// when the user taps Connect. Callers just drop it in — no props, no callbacks.
/// When the connect flow finishes, `WalletConnectManager.shared.isAgentReady` flips
/// to true, which any observer (e.g. `MarketViewModel.isWalletReady`) picks up
/// automatically, so the parent view will swap this out for the connected UI on
/// its own without this view having to notify anyone.
struct ConnectWalletView: View {
    @State private var authVM = AuthViewModel()
    @State private var showLoginSheet = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wallet.bifold")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .padding(.top, 24)
            Text("Connect a wallet to trade")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showLoginSheet = true
            } label: {
                Text("Connect")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal)
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginView(authVM: authVM)
        }
    }
}

#Preview {
    ConnectWalletView()
}
