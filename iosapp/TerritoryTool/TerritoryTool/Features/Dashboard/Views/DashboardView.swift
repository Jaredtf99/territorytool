import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DIContainer.shared.makeDashboardViewModel()
    @State private var editingEvent: TransactionEvent?
    @State private var showDeleteConfirmation = false
    @State private var eventToDelete: TransactionEvent?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                heroStats
                    .appear(index: 0)

                needsAttentionSection

                recentMovementsSection
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .background { LiquidBackgroundView() }
        .navigationTitle("dashboard.title")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                CongregationSwitcher()
            }
        }
        .refreshable { await viewModel.loadOldTerritories() }
        .task { await viewModel.loadOldTerritories() }
        .task { await CongregationStore.shared.refresh() }
        .sheet(item: $editingEvent) { event in
            EditTransactionSheet(
                transactionEvent: event,
                isPresented: Binding(
                    get: { editingEvent != nil },
                    set: { if !$0 { editingEvent = nil } }
                ),
                onComplete: { await viewModel.loadOldTerritories() }
            )
        }
        .alert("common.delete_confirmation", isPresented: $showDeleteConfirmation, presenting: eventToDelete) { event in
            Button("common.delete", role: .destructive) {
                Task { await viewModel.deleteTransaction(event: event) }
            }
            Button("common.cancel", role: .cancel) {}
        } message: { _ in
            Text("dashboard.delete_transaction_message")
        }
    }

    // MARK: - Hero

    private var heroStats: some View {
        HStack(spacing: AppSpacing.sm) {
            StatTile(
                value: viewModel.oldTerritories.count,
                label: "dashboard.needs_attention",
                systemImage: "exclamationmark.triangle.fill",
                tint: .accentTertiary
            )
            StatTile(
                value: viewModel.recentEvents.count,
                label: "dashboard.recent_transactions",
                systemImage: "arrow.left.arrow.right",
                tint: .accent
            )
        }
    }

    // MARK: - Needs attention

    @ViewBuilder
    private var needsAttentionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            CartoSectionHeader(
                title: "dashboard.needs_attention",
                systemImage: "flag.fill",
                count: viewModel.oldTerritories.isEmpty ? nil : viewModel.oldTerritories.count,
                tint: .accentTertiary
            )
            .appear(index: 1)

            if viewModel.isLoading && viewModel.oldTerritories.isEmpty {
                LoadingCard().appear(index: 2)
            } else if let error = viewModel.errorMessage {
                CartoEmptyState(systemImage: "exclamationmark.octagon.fill",
                                message: LocalizedStringKey(error),
                                tint: .danger)
                    .appear(index: 2)
            } else if viewModel.oldTerritories.isEmpty {
                CartoEmptyState(systemImage: "checkmark.seal.fill",
                                message: "dashboard.no_territories",
                                tint: .accent)
                    .appear(index: 2)
            } else {
                ForEach(Array(viewModel.oldTerritories.prefix(3).enumerated()), id: \.element.id) { index, territory in
                    DashboardTerritoryRow(territory: territory)
                        .appear(index: index + 2)
                }

                if viewModel.oldTerritories.count > 3 {
                    NavigationLink {
                        OldTerritoriesListView(territories: viewModel.oldTerritories)
                    } label: {
                        SeeAllLabel(remaining: viewModel.oldTerritories.count - 3)
                    }
                    .buttonStyle(.plain)
                    .appear(index: 5)
                }
            }
        }
    }

    // MARK: - Recent movements

    @ViewBuilder
    private var recentMovementsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            CartoSectionHeader(
                title: "dashboard.recent_transactions",
                systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill",
                count: viewModel.recentEvents.isEmpty ? nil : viewModel.recentEvents.count,
                tint: .accent
            )
            .appear(index: 6)

            if viewModel.recentEvents.isEmpty {
                CartoEmptyState(systemImage: "tray.fill",
                                message: "dashboard.no_recent_transactions",
                                tint: .accent)
                    .appear(index: 7)
            } else {
                ForEach(Array(viewModel.recentEvents.prefix(3).enumerated()), id: \.element.id) { index, event in
                    movementCard(for: event)
                        .appear(index: index + 7)
                }

                if viewModel.recentEvents.count > 3 {
                    NavigationLink {
                        RecentTransactionsListView(events: viewModel.recentEvents, viewModel: viewModel)
                    } label: {
                        SeeAllLabel(remaining: viewModel.recentEvents.count - 3)
                    }
                    .buttonStyle(.plain)
                    .appear(index: 10)
                }
            }
        }
    }

    @ViewBuilder
    private func movementCard(for event: TransactionEvent) -> some View {
        TransactionRow(event: event)
            .contentShape(Rectangle())
            .onTapGesture {
                guard viewModel.canEditTransactions else { return }
                HapticManager.shared.impact(style: .light)
                editingEvent = event
            }
            .contextMenu {
                if viewModel.canEditTransactions {
                    Button {
                        editingEvent = event
                    } label: {
                        Label("common.edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        eventToDelete = event
                        showDeleteConfirmation = true
                    } label: {
                        Label("common.delete", systemImage: "trash")
                    }
                }
            }
    }
}

// MARK: - Needs-attention card

struct DashboardTerritoryRow: View {
    let territory: Territory

    private var days: Int {
        guard let date = territory.givenDateUtc else { return 0 }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // Regla de urgencia (marcador de mapa)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.urgency(forDays: days))
                .frame(width: 4)

            TerritoryCodeBadge(
                code: territory.code,
                fontSize: .system(.subheadline, design: .rounded),
                paddingHorizontal: AppSpacing.sm,
                paddingVertical: AppSpacing.xs
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(territory.name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                if let person = territory.personName {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill").font(.caption2)
                        Text(person).font(.caption).lineLimit(1)
                    }
                    .foregroundStyle(Color.textSecondary)
                }
            }

            Spacer(minLength: AppSpacing.xs)

            // Días asignado
            VStack(spacing: 0) {
                Text("\(days)")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.urgency(forDays: days))
                Text("common.days")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.urgency(forDays: days).opacity(0.85))
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(Color.urgency(forDays: days).opacity(0.12),
                        in: .rect(cornerRadius: AppRadius.md, style: .continuous))
        }
        .padding(AppSpacing.sm)
        .paperCard(cornerRadius: AppRadius.lg)
    }
}

// MARK: - "Ver todos"

private struct SeeAllLabel: View {
    let remaining: Int

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Text("dashboard.see_all")
                .font(.subheadline.weight(.semibold))
            if remaining > 0 {
                Text("+\(remaining)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accent.opacity(0.14), in: Capsule())
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(Color.accent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .overlay(
            Capsule()
                .strokeBorder(Color.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
    }
}

// MARK: - Loading placeholder

private struct LoadingCard: View {
    var body: some View {
        HStack {
            ProgressView()
                .tint(.accent)
            Text("common.loading")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.md)
        .paperCard(cornerRadius: AppRadius.lg)
    }
}
