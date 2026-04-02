import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            MarketsView()
                .tabItem {
                    Label("Markets", systemImage: "chart.bar.fill")
                }

            TradingView()
                .tabItem {
                    Label("Trade", systemImage: "chart.line.uptrend.xyaxis")
                }

            PositionsView()
                .tabItem {
                    Label("Positions", systemImage: "list.bullet.rectangle")
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
