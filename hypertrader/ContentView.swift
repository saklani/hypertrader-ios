import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MarketView()
                .tabItem {
                    Label("Markets", systemImage: "chart.xyaxis.line")
                }

            PositionsView()
                .tabItem {
                    Label("Positions", systemImage: "list.bullet")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
}
