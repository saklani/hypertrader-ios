import SwiftUI

@main
struct hypertraderApp: App {
    init() {
        WalletConnectManager.shared.initialize()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
