import SwiftUI

/// Self-contained "Connect Wallet" FAB. Owns its own sheet presentation and
/// `AuthViewModel` — just drop `ConnectWalletButton()` wherever you need it.
/// The sheet auto-dismisses once the agent wallet is approved.
struct ConnectWalletButton: View {
    @State private var showSheet = false
    @State private var authVM = AuthViewModel()

    private var wcManager: WalletConnectManager { .shared }

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Label("Connect Wallet", systemImage: "link")
                .font(.subheadline.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.blue, in: Capsule())
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .sheet(isPresented: $showSheet) {
            NavigationStack {
                VStack(spacing: 0) {
                    Text("Connect a Wallet")
                        .font(.title2.bold())
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    LoginView(authVM: authVM)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showSheet = false }
                    }
                }
            }
            .presentationDetents([.large])
            .onChange(of: wcManager.isConnected) { _, connected in
                if connected { showSheet = false }
            }
        }
    }
}

#Preview {
    ConnectWalletButton()
}
