import SwiftUI

struct TerritoriesView: View {
    @StateObject private var viewModel: TerritoriesViewModel
    
    init(viewModel: TerritoriesViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Filters (Scrolls with content)
                FilterScrollView(viewModel: viewModel)
                    
                
                // Content
                if viewModel.isLoading && viewModel.territories.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.error)
                        .padding()
                        .multilineTextAlignment(.center)
                        .background(.regularMaterial)
                        .cornerRadius(12)
                    Button("Retry") {
                        Task { await viewModel.loadTerritories() }
                    }
                    .buttonStyle(.bordered)
                } else if viewModel.territories.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("territories.empty_list")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    ForEach(viewModel.territories) { territory in
                        NavigationLink(destination: TerritoryDetailView(territoryId: territory.id, territoryName: territory.name)) {
                            TerritoryCard(territory: territory)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contentShape(Rectangle())
                    }
                    .opacity(viewModel.isLoading ? 0.5 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .refreshable {
            await viewModel.loadTerritories()
            HapticManager.shared.notification(type: .success)
        }
        .navigationTitle("territories.title")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $viewModel.searchText, placement: .automatic, prompt: "territories.search_placeholder")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Sort By", selection: $viewModel.sortOption) {
                        ForEach(TerritorySortOption.allCases) { option in
                            Text(option.localizedName).tag(option)
                        }
                    }
                    
                    Divider()
                    
                    Button(action: { 
                        HapticManager.shared.selection()
                        viewModel.sortAscending.toggle() 
                    }) {
                        Label(
                            viewModel.sortAscending ? "territories.sort.ascending" : "territories.sort.descending",
                            systemImage: viewModel.sortAscending ? "arrow.up" : "arrow.down"
                        )
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
            }
        }
        .background {
            LiquidBackgroundView()
        }
        .task {
            if viewModel.territories.isEmpty {
                await viewModel.loadTerritories()
            }
        }
    }
}

struct FilterScrollView: View {
    @ObservedObject var viewModel: TerritoriesViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TerritoryFilter.allCases) { filter in
                    Button(action: {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.filterStatus = filter
                        }
                    }) {
                        Text(filter.localizedName)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.filterStatus == filter ?
                                Color.brandPrimary :
                                Color.clear
                            )
                            .background(.ultraThinMaterial)
                            .foregroundColor(viewModel.filterStatus == filter ? .white : .primary)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }
                }
            }
            
        }
    }
}
