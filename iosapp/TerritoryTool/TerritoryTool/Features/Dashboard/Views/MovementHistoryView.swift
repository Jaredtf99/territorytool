import SwiftUI

struct MovementHistoryView: View {
    @StateObject private var viewModel: MovementHistoryViewModel
    @ObservedObject var actionViewModel: DashboardViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editingEvent: TransactionEvent?
    @State private var eventToDelete: TransactionEvent?
    @State private var showDeleteConfirmation = false

    init(actionViewModel: DashboardViewModel) {
        self.actionViewModel = actionViewModel
        _viewModel = StateObject(
            wrappedValue: MovementHistoryViewModel(apiService: DIContainer.shared.apiService)
        )
    }

    var body: some View {
        List {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(MovementHistoryFilter.allCases) { filter in
                        filterChip(filter)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .listRowInsets(
                EdgeInsets(
                    top: AppSpacing.xs,
                    leading: AppSpacing.md,
                    bottom: AppSpacing.xs,
                    trailing: AppSpacing.md
                )
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if viewModel.isLoading && viewModel.movements.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if viewModel.movements.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.movements) { movement in
                    MovementRow(movement: movement)
                        .onAppear {
                            viewModel.loadMoreIfNeeded(current: movement)
                        }
                        .listRowInsets(
                            EdgeInsets(
                                top: 2,
                                leading: AppSpacing.md,
                                bottom: 2,
                                trailing: AppSpacing.md
                            )
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(allowsFullSwipe: false) {
                            if actionViewModel.canEditTransactions {
                                Button(role: .destructive) {
                                    eventToDelete = movement.transactionEvent
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("common.delete", systemImage: "trash")
                                }

                                Button {
                                    editingEvent = movement.transactionEvent
                                } label: {
                                    Label("common.edit", systemImage: "pencil")
                                }
                                .tint(.accent)
                            }
                        }
                }

                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .listRowSpacing(0)
        .scrollContentBackground(.hidden)
        .background { LiquidBackgroundView() }
        .navigationTitle("movements.title")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "movements.search")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("movements.sort.title", selection: $viewModel.sort) {
                        ForEach(MovementHistorySort.allCases) { sort in
                            Text(sort.title).tag(sort)
                        }
                    }
                } label: {
                    Label("movements.sort.title", systemImage: "arrow.up.arrow.down")
                }
            }
        }
        .refreshable {
            await viewModel.load(reset: true)
        }
        .task {
            await viewModel.load(reset: true)
        }
        .sheet(item: $editingEvent) { event in
            EditTransactionSheet(
                transactionEvent: event,
                isPresented: Binding(
                    get: { editingEvent != nil },
                    set: { if !$0 { editingEvent = nil } }
                ),
                onComplete: {
                    await actionViewModel.loadDashboard()
                    await viewModel.load(reset: true)
                }
            )
        }
        .alert(
            "common.delete_confirmation",
            isPresented: $showDeleteConfirmation,
            presenting: eventToDelete
        ) { event in
            Button("common.delete", role: .destructive) {
                Task {
                    await actionViewModel.deleteTransaction(event: event)
                    await viewModel.load(reset: true)
                }
            }
            Button("common.cancel", role: .cancel) {}
        } message: { _ in
            Text("dashboard.delete_transaction_message")
        }
        .alert(
            "common.error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func filterChip(_ filter: MovementHistoryFilter) -> some View {
        let selected = viewModel.filter == filter

        return Button {
            HapticManager.shared.selection()
            withAnimation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.78)) {
                viewModel.filter = filter
            }
        } label: {
            HStack(spacing: 6) {
                filterIndicator(filter, selected: selected)
                Text(filter.title)
                    .font(.appSubheadline())
                    .foregroundStyle(selected ? .white : Color.textPrimary)
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(height: 38)
        }
        .glassEffect(
            selected ? .regular.tint(.accent).interactive() : .regular.interactive(),
            in: .capsule
        )
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func filterIndicator(_ filter: MovementHistoryFilter, selected: Bool) -> some View {
        if filter == .all {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(selected ? .white : Color.accent)
        } else {
            Circle()
                .fill(selected ? Color.white : filter.tint)
                .frame(width: 9, height: 9)
        }
    }
}

extension DashboardMovement {
    var transactionEvent: TransactionEvent {
        TransactionEvent(
            txnId: transactionId,
            type: eventType == .given ? .given : .returned,
            date: eventDate,
            transaction: transaction
        )
    }
}

private extension MovementHistoryFilter {
    var tint: Color {
        switch self {
        case .all: .accent
        case .given: .accentSecondary
        case .returned: .accent
        }
    }
}
