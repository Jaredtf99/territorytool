import SwiftUI

struct TerritoryDetailView: View {
    @StateObject private var viewModel: TerritoryDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    @State private var showEditSheet = false
    
    // Animation states
    @State private var isHeaderVisible = false
    @State private var areStatsVisible = false
    @State private var isTimelineVisible = false
    
    private let territoryName: String
    
    init(territoryId: Int, territoryName: String) {
        self.territoryName = territoryName
        _viewModel = StateObject(wrappedValue: TerritoryDetailViewModel(territoryId: territoryId, apiService: NetworkManager()))
    }
    
    var body: some View {
        ZStack {
            LiquidBackgroundView()
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.yellow)
                    Text("territory.detail.error")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("territory.detail.retry") {
                        Task { await viewModel.loadData() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if let territory = viewModel.territory {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Section
                        headerSection(territory: territory)
                            .opacity(isHeaderVisible ? 1 : 0)
                            .offset(y: isHeaderVisible ? 0 : 20)
                        
                        // Actions
                        actionButtons(territory: territory)
                            .opacity(isHeaderVisible ? 1 : 0)
                            .offset(y: isHeaderVisible ? 0 : 20)
                        
                        // Timeline
                        timelineSection(transactions: viewModel.transactions)
                            .opacity(isTimelineVisible ? 1 : 0)
                            .offset(y: isTimelineVisible ? 0 : 40)
                        
                        // Stats Grid
                        if let stats = viewModel.stats {
                            statsGrid(stats: stats)
                                .opacity(areStatsVisible ? 1 : 0)
                                .offset(y: areStatsVisible ? 0 : 30)
                        }
                    }
                    .padding()
                    .padding(.bottom, 80) // Space for bottom safe area
                }
                .refreshable {
                    await viewModel.loadData()
                }
            }
        }
        .navigationTitle(viewModel.territory?.name ?? territoryName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem() {
                Button {
                    HapticManager.shared.selection()
                    Task { 
                        if await viewModel.refreshImage() {
                            HapticManager.shared.notification(type: .success)
                            ToastManager.shared.show(NSLocalizedString("territory.detail.refresh_image_success", comment: ""), style: .success)
                        } else {
                            HapticManager.shared.notification(type: .error)
                        }
                    }
                } label: {
                    if viewModel.isRefreshingImage {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isRefreshingImage)
            }
            
            ToolbarSpacer(.flexible)
            
            ToolbarItem() {
                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
            
            ToolbarSpacer(.flexible)
            
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .task {
            await viewModel.loadData()
            withAnimation(.easeOut(duration: 0.6)) {
                isHeaderVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                areStatsVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
                isTimelineVisible = true
            }
        }
        .alert("territory.detail.delete_confirmation_title", isPresented: $showDeleteAlert) {
            Button("cancel", role: .cancel) { }
            Button("territory.detail.delete", role: .destructive) {
                Task {
                    if await viewModel.deleteTerritory() {
                        ToastManager.shared.show(NSLocalizedString("territory.delete.success", value: "Territory deleted", comment: ""), style: .success)
                        NotificationCenter.default.post(name: .territoryDeleted, object: nil)
                        dismiss()
                    } else {
                        HapticManager.shared.notification(type: .error)
                    }
                }
            }
        } message: {
            Text("territory.detail.delete_confirmation_message")
        }
        .sheet(isPresented: $showEditSheet) {
            if let territory = viewModel.territory {
                EditTerritoryView(territory: territory, apiService: NetworkManager())
                    .onDisappear {
                        Task {
                            await viewModel.loadData()
                        }
                    }
            }
        }
    }
    
    private func headerSection(territory: TerritoryDetail) -> some View {
        VStack(spacing: 20) {
            // Map Image
            Color.clear
                .frame(height: 250)
                .overlay(
                    CachedAsyncImage(
                        url: URL(string: territory.imgUrl ?? ""),
                        content: { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        },
                        placeholder: {
                            ProgressView()
                                .tint(.white)
                        },
                        errorView: {
                            VStack {
                                Image(systemName: "map.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("territory.detail.map_unavailable")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    )
                )
                .clipped()
                .cornerRadius(12)
            .overlay(
                TerritoryCodeBadge(code: territory.code)
                    .padding()
                , alignment: .topLeading
            )
            .overlay(
                Group {
                    if let person = territory.personName {
                        PersonBadge(personName: person)
                    } else {
                        StatusBadge(isAssigned: false)
                    }
                }
                .padding()
                , alignment: .topTrailing
            )
            
        }
    }
    
    private func actionButtons(territory: TerritoryDetail) -> some View {
        HStack(spacing: 16) {
            if territory.personName == nil {
                NavigationLink {
                    TerritoryAssignmentView(territory: territory.toTerritory())
                } label: {
                    Label("territory.detail.assign", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    HapticManager.shared.selection()
                })
            } else {
                NavigationLink {
                    TerritoryReturnView(territory: territory.toTerritory())
                } label: {
                    Label("territory.detail.return", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: .green.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    HapticManager.shared.selection()
                })
            }
        }
    }
    
    private func statsGrid(stats: TerritoryStatistics) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            // Usage Rank
            TerritoryStatCard(
                title: "territory.stats.rank_label",
                value: String(format: String.localized("territory.stats.rank_value"), stats.usageRank, stats.totalTerritories),
                description: "territory.stats.rank_desc",
                icon: "trophy.fill",
                color: .yellow
            )
            
            // Active Time
            TerritoryStatCard(
                title: "territory.stats.active_time",
                value: String(format: String.localized("territory.stats.percentage"), stats.assignedTimePercentage),
                comparisonValue: String(format: String.localized("territory.stats.global_avg"), String(format: String.localized("territory.stats.percentage"), stats.globalAverageAssignedTimePercentage)),
                description: "territory.stats.active_time_desc",
                trend: stats.assignedTimePercentage > stats.globalAverageAssignedTimePercentage ? .up : (stats.assignedTimePercentage < stats.globalAverageAssignedTimePercentage ? .down : .neutral),
                trendColor: stats.assignedTimePercentage > stats.globalAverageAssignedTimePercentage ? .green : (stats.assignedTimePercentage < stats.globalAverageAssignedTimePercentage ? .red : .secondary),
                icon: "chart.pie.fill",
                color: .blue
            )
            
            // Idle Time
            TerritoryStatCard(
                title: "territory.stats.idle_time",
                value: String(format: String.localized("territory.stats.days"), stats.averageReassignmentTime),
                comparisonValue: String(format: String.localized("territory.stats.global_avg"), String(format: String.localized("territory.stats.days"), stats.globalAverageReassignmentTime)),
                description: "territory.stats.idle_time_desc",
                trend: stats.averageReassignmentTime > stats.globalAverageReassignmentTime ? .up : (stats.averageReassignmentTime < stats.globalAverageReassignmentTime ? .down : .neutral),
                trendColor: stats.averageReassignmentTime > stats.globalAverageReassignmentTime ? .green : (stats.averageReassignmentTime < stats.globalAverageReassignmentTime ? .red : .secondary),
                icon: "hourglass",
                color: .gray
            )
            
            // Avg Duration
            TerritoryStatCard(
                title: "territory.stats.avg_duration",
                value: String(format: String.localized("territory.stats.days"), stats.averageHoldingTime),
                comparisonValue: String(format: String.localized("territory.stats.global_avg"), String(format: String.localized("territory.stats.days"), stats.globalAverageHoldingTime)),
                description: "territory.stats.avg_duration_desc",
                trend: stats.averageHoldingTime > stats.globalAverageHoldingTime ? .up : (stats.averageHoldingTime < stats.globalAverageHoldingTime ? .down : .neutral),
                trendColor: stats.averageHoldingTime > stats.globalAverageHoldingTime ? .green : (stats.averageHoldingTime < stats.globalAverageHoldingTime ? .red : .secondary),
                icon: "clock.fill",
                color: .orange
            )
            
            // Unique Users
            TerritoryStatCard(
                title: "territory.stats.unique_users",
                value: "\(stats.uniqueUsersCount)",
                comparisonValue: String(format: String.localized("territory.stats.global_avg"), String(format: "%.1f", stats.globalAverageUniqueUsersCount)),
                description: "territory.stats.unique_users_desc",
                trend: Double(stats.uniqueUsersCount) > stats.globalAverageUniqueUsersCount ? .up : (Double(stats.uniqueUsersCount) < stats.globalAverageUniqueUsersCount ? .down : .neutral),
                trendColor: Double(stats.uniqueUsersCount) > stats.globalAverageUniqueUsersCount ? .green : (Double(stats.uniqueUsersCount) < stats.globalAverageUniqueUsersCount ? .red : .secondary),
                icon: "person.2.fill",
                color: .purple
            )
        }
    }
    
    private func timelineSection(transactions: [Transaction]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("territory.history.title")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.leading, 4)
            
            GlassCard {
                LazyVStack(spacing: 0) {
                    ForEach(transactions.reversed()) { transaction in
                        TimelineItemRow(transaction: transaction)
                            .padding(.horizontal)
                            .padding(.top, 16)
                    }
                }
                .padding(.bottom, 16)
            }
        }
    }
}

extension TerritoryDetail {
    func toTerritory() -> Territory {
        return Territory(
            id: self.id,
            code: self.code,
            name: self.name,
            mapUrl: self.mapUrl,
            imgUrl: self.imgUrl,
            personName: self.personName,
            givenDateUtc: self.givenDateUtc,
            lastPickedDateUtc: self.lastPickedDateUtc
        )
    }
}


