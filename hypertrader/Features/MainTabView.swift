import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            MarketView()
                .tabItem {
                    Label("Markets", systemImage: "chart.bar.fill")
                }

            PositionsView()
                .tabItem {
                    Label("Positions", systemImage: "list.bullet.rectangle")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .task {
            HyperliquidWebSocketService.shared.connect()
        }
    }
}

#Preview {
    MainTabView()
}
