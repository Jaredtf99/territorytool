import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DIContainer.shared.makeDashboardViewModel()
    @State private var showSettings = false
    
    init() {}
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("dashboard.needs_attention")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !viewModel.oldTerritories.isEmpty {
                        Text("\(viewModel.oldTerritories.count)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.error)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                        .cornerRadius(10)
                        .padding(.horizontal)
                } else if viewModel.oldTerritories.isEmpty {
                    Text("dashboard.no_territories")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                        .cornerRadius(10)
                        .padding(.horizontal)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.oldTerritories, id: \.id) { territory in
                            DashboardTerritoryRow(territory: territory)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("dashboard.title")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape.fill")
                }
            }
        }
        .background {
            LiquidBackgroundView()
        }
        .task {
            await viewModel.loadOldTerritories()
        }
    }
}

struct DashboardTerritoryRow: View {
    let territory: Territory
    
    var body: some View {
        HStack(spacing: 16) {
            // Code Bubble
            TerritoryCodeBadge(
                code: territory.code,
                fontSize: .system(.headline, design: .rounded),
                paddingHorizontal: 12,
                paddingVertical: 12
            )
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(territory.name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let person = territory.personName {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                        Text(person)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Time Ago Badge
            if let date = territory.givenDateUtc {
                let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(days)")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundColor(.red)
                    Text(String.localized("common.days"))
                        .font(.caption2)
                        .foregroundColor(.red.opacity(0.8))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .glassCardStyle(cornerRadius: 16, padding: 12)
    }
}



