import Combine
import SwiftUI

// MARK: - ViewModel de selección (buscador inteligente)

/// Selector de personas o de territorios libres con el buscador inteligente.
/// Vacío -> lista por defecto (todas las personas / libres). Al teclear -> `search_quick_action`.
@MainActor
final class QuickActionPickerViewModel: ObservableObject {
    enum Mode { case persons, freeTerritories }

    @Published var search = ""
    @Published var persons: [Person] = []
    @Published var territories: [Territory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let mode: Mode
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()

    init(apiService: APIService, mode: Mode) {
        self.apiService = apiService
        self.mode = mode

        $search
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .removeDuplicates()
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in Task { [weak self] in await self?.run() } }
            .store(in: &cancellables)
    }

    func loadInitial() async { await run() }

    private func run() async {
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        isLoading = true
        defer { isLoading = false }
        do {
            if term.isEmpty {
                switch mode {
                case .persons:
                    persons = try await apiService.request(endpoint: TerritoryEndpoint.getPersons(search: nil))
                case .freeTerritories:
                    territories = try await apiService.request(
                        endpoint: TerritoryEndpoint.getTerritories(
                            term: nil, inUse: false,
                            orderBy: TerritorySortOption.name.rawValue, orderByAscending: true,
                            lastGivenDateFrom: nil, lastGivenDateTo: nil
                        )
                    )
                }
            } else {
                let hits: [QuickSearchHit] = try await apiService.request(
                    endpoint: TerritoryEndpoint.searchQuickAction(term: term)
                )
                switch mode {
                case .persons:
                    persons = hits.compactMap(\.person)
                case .freeTerritories:
                    territories = hits.compactMap(\.territory).filter { !$0.isAssigned }
                }
            }
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
    }
}

// MARK: - Entregar un territorio libre: elegir persona

struct QuickActionPickPersonView: View {
    let territory: Territory
    let onDone: () -> Void
    var onClose: (() -> Void)? = nil

    @StateObject private var vm = QuickActionPickerViewModel(apiService: DIContainer.shared.apiService, mode: .persons)
    @FocusState private var focused: Bool
    @State private var action: QuickActionAction?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                CompactTerritoryRow(territory: territory, accessory: .none)
                    .appear(index: 0)

                QASectionHeader(title: "quick_action.who_deliver", systemImage: "person.crop.circle.badge.plus")

                personList
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .background { LiquidBackgroundView().ignoresSafeArea() }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            QuickActionSearchBar(placeholder: "quick_action.search_publisher", text: $vm.search, focus: $focused)
        }
        .navigationTitle("assignment.title")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(onClose != nil)
        .toolbar {
            if let onClose {
                ToolbarItem(placement: .topBarLeading) {
                    Button { onClose() } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                    }
                    .accessibilityLabel(Text("common.close"))
                }
            }
        }
        .navigationDestination(item: $action) { QuickActionConfirmView(action: $0, onDone: onDone) }
        .task { await vm.loadInitial() }
    }

    @ViewBuilder
    private var personList: some View {
        if vm.isLoading && vm.persons.isEmpty {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, AppSpacing.lg)
        } else if vm.persons.isEmpty {
            CartoEmptyState(systemImage: "person.slash", message: "common.no_results")
        } else {
            VStack(spacing: AppSpacing.xs) {
                ForEach(vm.persons) { person in
                    Button {
                        HapticManager.shared.selection()
                        action = .deliver(territory: territory, personName: person.name)
                    } label: {
                        PersonQuickRow(person: person)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Persona seleccionada: decidir (recoger uno / entregar otro)

struct QuickActionPersonView: View {
    let person: Person
    let onDone: () -> Void
    var onClose: (() -> Void)? = nil

    private enum Mode { case decision, pickTerritory }
    @State private var mode: Mode
    @StateObject private var vm = QuickActionPickerViewModel(apiService: DIContainer.shared.apiService, mode: .freeTerritories)
    @FocusState private var focused: Bool
    @State private var action: QuickActionAction?

    init(person: Person, onDone: @escaping () -> Void, onClose: (() -> Void)? = nil) {
        self.person = person
        self.onDone = onDone
        self.onClose = onClose
        _mode = State(initialValue: person.hasActiveTerritory ? .decision : .pickTerritory)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                PersonHero(person: person).appear(index: 0)

                switch mode {
                case .decision: decisionContent
                case .pickTerritory: pickTerritoryContent
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .background { LiquidBackgroundView().ignoresSafeArea() }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            if mode == .pickTerritory {
                QuickActionSearchBar(placeholder: "quick_action.search_territory", text: $vm.search, focus: $focused)
            }
        }
        .navigationTitle(Text(person.name))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(onClose != nil)
        .toolbar {
            if let onClose {
                ToolbarItem(placement: .topBarLeading) {
                    Button { onClose() } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                    }
                    .accessibilityLabel(Text("common.close"))
                }
            }
        }
        .navigationDestination(item: $action) { act in
            QuickActionConfirmView(action: act, onDone: onDone, onDeliverAnother: { _ in
                // Recogido: continúa entregando otro a esta misma persona.
                action = nil
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { mode = .pickTerritory }
                Task { await vm.loadInitial() }
            })
        }
        .task {
            if mode == .pickTerritory { await vm.loadInitial() }
        }
    }

    @ViewBuilder
    private var decisionContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            QASectionHeader(title: "quick_action.return_one", systemImage: "tray.and.arrow.down", tint: .accentSecondary)
            VStack(spacing: AppSpacing.sm) {
                ForEach(person.territoriesInUse ?? [], id: \.territoryId) { assignment in
                    let territory = assignment.asTerritory(personName: person.name)
                    Button {
                        HapticManager.shared.selection()
                        action = .returnTerritory(territory)
                    } label: {
                        CompactTerritoryRow(territory: territory)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .appear(index: 1)

        Button {
            HapticManager.shared.selection()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { mode = .pickTerritory }
            Task { await vm.loadInitial() }
        } label: {
            ActionPromptCard(
                icon: "paperplane.fill",
                title: "quick_action.deliver_other_territory",
                subtitle: "quick_action.deliver_other_hint",
                tint: .accent
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .appear(index: 2)
    }

    @ViewBuilder
    private var pickTerritoryContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            QASectionHeader(title: "quick_action.choose_territory", systemImage: "leaf.fill")

            if vm.isLoading && vm.territories.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, AppSpacing.lg)
            } else if vm.territories.isEmpty {
                CartoEmptyState(systemImage: "mappin.slash", message: "common.no_results")
            } else {
                VStack(spacing: AppSpacing.xs) {
                    ForEach(vm.territories) { territory in
                        Button {
                            HapticManager.shared.selection()
                            action = .deliver(territory: territory, personName: person.name)
                        } label: {
                            CompactTerritoryRow(territory: territory)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .appear(index: 1)
    }
}

// MARK: - Piezas compartidas

/// Cabecera de sección simple (sin línea de puntos), una sola línea.
struct QASectionHeader: View {
    let title: LocalizedStringKey
    var systemImage: String
    var tint: Color = .accent

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
    }
}

/// Cabecera de persona (avatar grande + nombre + nº de territorios).
struct PersonHero: View {
    let person: Person

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            InitialsAvatar(name: person.name, size: 52, tint: person.hasActiveTerritory ? .accentSecondary : .accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(person.hasActiveTerritory
                     ? String(format: String.localized("quick_action.person_territory_count"), person.activeTerritoryCount)
                     : String.localized("quick_action.person_no_territory"))
                    .font(.appSubheadline())
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .paperCard(cornerRadius: AppRadius.xl)
    }
}

/// Tarjeta-prompt de acción (icono en círculo tintado + título + subtítulo + chevron).
struct ActionPromptCard: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var tint: Color = .accentDeep

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    LinearGradient(colors: [tint, tint.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
                .shadow(color: tint.opacity(0.35), radius: 5, x: 0, y: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.appHeadline()).foregroundStyle(Color.textPrimary)
                Text(subtitle).font(.appCaption()).foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Color.textSecondary)
        }
        .padding(AppSpacing.md)
        .paperCard(cornerRadius: AppRadius.lg)
    }
}
