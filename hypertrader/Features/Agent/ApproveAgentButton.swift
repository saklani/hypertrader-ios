import SwiftUI

/// Self-contained "Enable Trading" FAB. Shown when a wallet is connected but
/// the agent key hasn't been approved yet. Opens a sheet explaining the agent
/// concept and provides a "Sign" button that triggers the EIP-712 approval flow.
/// Auto-dismisses once `WalletConnectManager.shared.isAgentReady` flips.
struct ApproveAgentButton: View {
    @State private var showSheet = false
    @State private var agent = AgentViewModel()

    private var wcManager: WalletConnectManager { .shared }

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Label("Enable Trading", systemImage: "signature")
                .font(.subheadline.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.orange, in: Capsule())
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .sheet(isPresented: $showSheet) {
            NavigationStack {
                agentApprovalContent
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showSheet = false }
                        }
                    }
            }
            .presentationDetents([.medium])
            .onChange(of: wcManager.isAgentReady) { _, ready in
                if ready { showSheet = false }
            }
        }
    }

    // MARK: - Sheet Content

    private var agentApprovalContent: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 8)

            Image(systemName: "key.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("Enable Trading")
                .font(.title2.bold())

            if let address = wcManager.walletAddress {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(formatShortAddress(address))
                        .font(.body.monospaced())
                }
            }

            Text("A local signing key has been created on your device. Approving it lets you place trades instantly without wallet pop-ups.\n\nYour wallet will ask you to sign a one-time message — no funds are transferred.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                Task { await agent.approve() }
            } label: {
                Text("Sign to Approve")
            }
            .buttonStyle(PrimaryButtonStyle(color: .orange, isLoading: agent.isLoading))
            .disabled(agent.isLoading)
            .padding(.horizontal)

            if let error = agent.error {
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
}

#Preview {
    ApproveAgentButton()
}
