import SwiftUI

struct PortfolioView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "briefcase")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Portfolio")
                    .font(.title2.bold())
                Text("Coming soon")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .navigationTitle("Portfolio")
        }
    }
}

#Preview {
    PortfolioView()
}
