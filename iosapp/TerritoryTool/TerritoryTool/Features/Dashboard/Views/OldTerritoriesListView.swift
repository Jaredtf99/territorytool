import SwiftUI

struct OldTerritoriesListView: View {
    let territories: [Territory]
    
    var body: some View {
        ZStack {
            LiquidBackgroundView()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    if territories.isEmpty {
                        Text("dashboard.no_territories")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                            .glassCardStyle()
                    } else {
                        ForEach(territories, id: \.id) { territory in
                            NavigationLink {
                                TerritoryDetailView(
                                    territoryId: territory.id,
                                    territoryName: territory.name
                                )
                            } label: {
                                TerritoryCard(territory: territory)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("dashboard.needs_attention")
        .navigationBarTitleDisplayMode(.inline)
    }
}
