import SwiftUI

// MARK: - Primary Button

/// Full-width solid background button with optional loading spinner.
/// Usage: `Button("Place Order") { }.buttonStyle(PrimaryButtonStyle(color: .green))`
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .blue
    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Spacer()
            if isLoading {
                ProgressView()
                    .tint(.white)
            }
            configuration.label
            Spacer()
        }
        .font(.headline)
        .padding()
        .background(color)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Wallet Row Button

/// Row-style button with quaternary background for selection lists.
/// Usage: `Button { } label: { HStack { ... } }.buttonStyle(WalletRowButtonStyle())`
struct WalletRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .padding()
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

// MARK: - Wallet Grid Card

/// Vertical card-style button for the wallet picker grid.
/// Usage: `Button { } label: { VStack { Image(...); Text(...) } }.buttonStyle(WalletGridCardStyle())`
struct WalletGridCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

// MARK: - Destructive Button

/// Bordered destructive-style button for dangerous actions.
/// Usage: `Button("Close Position") { }.buttonStyle(DestructiveActionButtonStyle())`
struct DestructiveActionButtonStyle: ButtonStyle {
    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Spacer()
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
            configuration.label
            Spacer()
        }
        .font(.subheadline.bold())
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.red.opacity(configuration.isPressed ? 0.15 : 0.1))
        .foregroundStyle(.red)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview("Button Styles") {
    VStack(spacing: 16) {
        Button("Buy ETH") {}
            .buttonStyle(PrimaryButtonStyle(color: .green))

        Button("Sell ETH") {}
            .buttonStyle(PrimaryButtonStyle(color: .red))

        Button("Loading...") {}
            .buttonStyle(PrimaryButtonStyle(color: .blue, isLoading: true))

        Button {} label: {
            HStack {
                Image(systemName: "rainbow")
                    .frame(width: 24)
                Text("Rainbow")
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(WalletRowButtonStyle())

        Button("Close Position") {}
            .buttonStyle(DestructiveActionButtonStyle())
    }
    .padding()
}
