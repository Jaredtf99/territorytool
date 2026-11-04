import SwiftUI

/// Ruta de navegación a la ficha de un hermano (desde la lista o desde un territorio).
struct BrotherDetailRoute: Hashable {
    let id: Int
    let name: String
}

private struct BrotherDetailTerritoryRoute: Hashable {
    let id: Int
    let name: String
}

/// Ficha de hermano, tema "Cartográfico cálido": cabecera con avatar y estado,
/// territorios en curso con su silueta, actividad de 12 meses e histórico
/// completo filtrable. La acción principal (Entregar) queda fija abajo.
struct BrotherDetailView: View {
    @StateObject private var viewModel: BrotherDetailViewModel
    @ObservedObject private var permissionManager = PermissionManager.shared
    @State private var territoryRoute: BrotherDetailTerritoryRoute?
    @State private var showEditSheet = false
    @State private var editViewModel: BrothersViewModel?

    private let personName: String

    init(personId: Int, personName: String, apiService: APIService = NetworkManager.shared) {
        self.personName = personName
        _viewModel = StateObject(wrappedValue: BrotherDetailViewModel(personId: personId, apiService: apiService))
    }

    var body: some View {
        ZStack {
            LiquidBackgroundView()
                .ignoresSafeArea()

            if viewModel.detail == nil && viewModel.isLoading {
                loadingState
            } else if let error = viewModel.errorMessage, viewModel.detail == nil {
                errorState(error)
            } else if let detail = viewModel.detail {
                content(detail)
            } else {
                loadingState
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarVisibility(.hidden, for: .tabBar)
        .toolbar {
            if permissionManager.canManageBrothers, viewModel.detail != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.shared.selection()
                        editViewModel = DIContainer.shared.makeBrothersViewModel()
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel(Text("brothers.edit.title"))
                }
            }
        }
        .navigationDestination(item: $territoryRoute) { route in
            TerritoryDetailView(territoryId: route.id, territoryName: route.name)
        }
        .sheet(isPresented: $showEditSheet, onDismiss: {
            Task { await viewModel.load() }
        }) {
            if let editViewModel, let detail = viewModel.detail {
                EditBrotherView(viewModel: editViewModel, person: detail.asPerson)
            }
        }
        .task {
            if viewModel.detail == nil {
                await viewModel.load()
            }
        }
    }

    // MARK: Contenido

    private func content(_ detail: PersonDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                BrotherDetailHeader(detail: detail)
                    .appear(index: 0)

                currentSection(detail)
                    .appear(index: 1)

                BrotherActivityChart(activity: detail.activity)
                    .appear(index: 2)

                BrotherHistorySection(viewModel: viewModel) { open($0.territoryId, $0.territoryCode) }
                    .appear(index: 3)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .refreshable {
            await viewModel.load()
            HapticManager.shared.notification(type: .success)
        }
        .safeAreaInset(edge: .bottom) {
            if detail.person.enabled {
                giveButton(detail)
            }
        }
    }

    @ViewBuilder
    private func currentSection(_ detail: PersonDetail) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            CartoSectionHeader(
                title: "brother.detail.current.title",
                systemImage: "figure.walk",
                count: detail.current.isEmpty ? nil : detail.current.count,
                tint: .accentSecondary
            )

            if detail.current.isEmpty {
                CartoEmptyState(systemImage: "cup.and.saucer.fill", message: "brother.detail.current.empty")
            } else {
                ForEach(Array(detail.current.enumerated()), id: \.element.id) { index, assignment in
                    BrotherCurrentCard(
                        assignment: assignment,
                        averageDays: detail.summary.congregationAverageHoldingDays
                    ) {
                        open(assignment.territoryId, assignment.territoryCode)
                    }
                    .appear(index: index, base: 0.035)
                }
            }
        }
    }

    private func giveButton(_ detail: PersonDetail) -> some View {
        Button {
            HapticManager.shared.impact(style: .medium)
            AppRouter.shared.openQuickAction(.person(detail.asPerson))
        } label: {
            Label("brother.detail.give", systemImage: "paperplane.fill")
                .font(.appHeadline())
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xxs)
        }
        .buttonStyle(.glassProminent)
        .tint(.accent)
        .controlSize(.large)
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.xs)
    }

    private func open(_ territoryId: Int, _ name: String) {
        HapticManager.shared.selection()
        territoryRoute = BrotherDetailTerritoryRoute(id: territoryId, name: name)
    }

    // MARK: Estados

    /// Esqueleto con la silueta de la ficha real.
    private var loadingState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(spacing: AppSpacing.md) {
                Circle().fill(Color.surface).frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(personName)
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                    Capsule().fill(Color.surface).frame(width: 110, height: 26)
                }
            }
            RoundedRectangle(cornerRadius: AppRadius.lg).fill(Color.surface).frame(height: 96)
                .overlay(ProgressView().tint(.accent))
            RoundedRectangle(cornerRadius: AppRadius.lg).fill(Color.surface).frame(height: 150)
            Spacer()
        }
        .padding(AppSpacing.md)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(Color.warning)
            Text("brother.detail.error")
                .font(.appTitle())
                .foregroundStyle(Color.textPrimary)
            Text(message)
                .multilineTextAlignment(.center)
                .font(.appSubheadline())
                .foregroundStyle(Color.textSecondary)
            Button("common.retry") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(.accentDeep)
        }
        .padding(AppSpacing.lg)
    }
}
