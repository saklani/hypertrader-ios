import SwiftUI

struct ContentView: View {
    @State private var authVM = AuthViewModel()

    var body: some View {
        Group {
            if authVM.isFullyReady {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}

#Preview {
    ContentView()
}
