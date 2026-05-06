import SwiftUI

/// Self-contained "Open Position" FAB. Owns its own sheet presentation and
/// `OrderViewModel` — just pass in the asset context and an `onOrderPlaced`
/// callback. The sheet auto-dismisses after a successful order.
struct OpenPositionButton: View {
    let asset: HLAsset?
    let assetIndex: Int?
    let onOrderPlaced: () -> Void

    @State private var showSheet = false
    @State private var order = OrderViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Label("Open Position", systemImage: "plus")
        }
        .buttonStyle(FABStyle())
        .sheet(isPresented: $showSheet) {
            NavigationStack {
                ScrollView {
                    OrderFormView(
                        order: order,
                        asset: asset,
                        assetIndex: assetIndex,
                        onOrderPlaced: {
                            onOrderPlaced()
                            showSheet = false
                        }
                    )
                }
                .scrollIndicators(.hidden)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showSheet = false }
                    }
                }
            }
            .presentationDetents([.large])
        }
    }
}

#Preview {
    OpenPositionButton(
        asset: nil,
        assetIndex: nil,
        onOrderPlaced: {}
    )
}
