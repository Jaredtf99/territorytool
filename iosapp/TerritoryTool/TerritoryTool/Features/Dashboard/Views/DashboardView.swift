import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @State private var showSettings = false
    @State private var editingEvent: TransactionEvent?
    @State private var showDeleteConfirmation = false
    @State private var eventToDelete: TransactionEvent?
    
    init(viewModel: DashboardViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        List {
            Group {
                // Header & Stats
                VStack(alignment: .leading) {
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
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .listRowBackground(Color.clear)
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.error)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                        .cornerRadius(10)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else if viewModel.oldTerritories.isEmpty {
                    Text("dashboard.no_territories")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                        .cornerRadius(10)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    // Show only first 3
                    ForEach(viewModel.oldTerritories.prefix(3), id: \.id) { territory in
                        DashboardTerritoryRow(territory: territory)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    
                    if viewModel.oldTerritories.count > 3 {
                        NavigationLink(destination: OldTerritoriesListView(territories: viewModel.oldTerritories)) {
                            Text("dashboard.see_all")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            
            
            Group {
                // Recent Transactions Header
                VStack(alignment: .leading) {
                    HStack {
                        Text("dashboard.recent_transactions")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if !viewModel.recentEvents.isEmpty {
                            Text("\(viewModel.recentEvents.count)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.8))
                                .clipShape(Capsule())
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 24, leading: 16, bottom: 12, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                
                if viewModel.recentEvents.isEmpty {
                    Text("dashboard.no_recent_transactions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .glassCardStyle(cornerRadius: 16, padding: 12)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.recentEvents.prefix(3)) { event in
                        TransactionRow(event: event)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if viewModel.canEditTransactions {
                                    Button {
                                        eventToDelete = event
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("common.delete", systemImage: "trash")
                                            .labelStyle(.iconOnly)
                                    }
                                    .tint(.red)
                                    
                                    Button {
                                        editingEvent = event
                                    } label: {
                                        Label("common.edit", systemImage: "pencil")
                                            .labelStyle(.iconOnly)
                                    }
                                    .tint(.blue)
                                }
                            }
                    }
                    
                    if viewModel.recentEvents.count > 3 {
                        NavigationLink(destination: RecentTransactionsListView(events: viewModel.recentEvents, viewModel: viewModel)) {
                            Text("dashboard.see_all")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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
        .sheet(item: $editingEvent) { event in
            EditTransactionSheet(
                transactionEvent: event,
                isPresented: Binding(
                    get: { editingEvent != nil },
                    set: { if !$0 { editingEvent = nil } }
                ),
                onComplete: {
                    await viewModel.loadOldTerritories()
                }
            )
        }
        .alert("common.delete_confirmation", isPresented: $showDeleteConfirmation, presenting: eventToDelete) { event in
            Button("common.delete", role: .destructive) {
                Task {
                    await viewModel.deleteTransaction(event: event)
                }
            }
            Button("common.cancel", role: .cancel) {}
        } message: { event in
            Text("dashboard.delete_transaction_message")
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



