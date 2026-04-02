import SwiftUI

struct MarketsView: View {
    @State private var vm = MarketsViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    filterChips
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section {
                    ForEach(vm.filteredItems) { item in
                        MarketRowView(
                            coin: item.name,
                            price: vm.price(for: item),
                            change24h: vm.change24h(for: item),
                            volume: item.dayNtlVlm
                        )
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Markets")
            .searchable(text: $vm.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search coins...")
            .task {
                await vm.loadMarketData()
            }
            .refreshable {
                await vm.loadMarketData()
            }
            .overlay {
                if vm.isLoading && vm.allItems.isEmpty {
                    ProgressView("Loading markets...")
                }
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MarketFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        isSelected: vm.selectedFilter == filter
                    ) {
                        vm.selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    MarketsView()
}
