import SwiftUI

struct RecentTransactionsListView: View {
    let events: [TransactionEvent]
    @ObservedObject var viewModel: DashboardViewModel
    @State private var showDeleteConfirmation = false
    @State private var eventToDelete: TransactionEvent?
    @State private var editingEvent: TransactionEvent?
    
    var body: some View {
            List {
                if events.isEmpty {
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
                    ForEach(events) { event in
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
                                    .tint(.danger)
                                    
                                    Button {
                                        editingEvent = event
                                    } label: {
                                        Label("common.edit", systemImage: "pencil")
                                            .labelStyle(.iconOnly)
                                    }
                                    .tint(.accent)
                                }
                            }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background {
                LiquidBackgroundView()
                    .ignoresSafeArea()
            }
        .navigationTitle("dashboard.recent_transactions")
        .navigationBarTitleDisplayMode(.inline)
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
    }
}
