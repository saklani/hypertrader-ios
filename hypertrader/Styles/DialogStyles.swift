import SwiftUI

// MARK: - Sheet Header

/// Consistent sheet/dialog title.
/// Usage: `SheetHeader(title: "WalletConnect URI")`
struct SheetHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.top)
    }
}

// MARK: - Status Message

/// Inline error or success message with icon.
/// Usage: `StatusMessage("Order placed", isError: false)` or `StatusMessage(error, isError: true)`
struct StatusMessage: View {
    let message: String
    let isError: Bool

    init(_ message: String, isError: Bool = true) {
        self.message = message
        self.isError = isError
    }

    var body: some View {
        Label(message, systemImage: isError ? "xmark.circle" : "checkmark.circle")
            .foregroundStyle(isError ? .red : .green)
    }
}

#Preview("Dialog Styles") {
    VStack(spacing: 20) {
        SheetHeader(title: "WalletConnect URI")
        StatusMessage("Order placed successfully", isError: false)
        StatusMessage("Failed to connect wallet", isError: true)
    }
    .padding()
}
