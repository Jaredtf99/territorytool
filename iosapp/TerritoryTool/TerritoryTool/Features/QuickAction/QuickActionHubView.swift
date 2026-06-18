import Combine
import SwiftUI

@MainActor
final class QuickActionViewModel: ObservableObject {
    @Published var territories: [Territory] = []
    @Published var persons: [Person] = []
    @Published var territorySearch = ""
    @Published var personSearch = ""
    @Published var isLoadingTerritories = false
    @Published var isLoadingPersons = false
    @Published var isResolvingScan = false
    @Published var errorMessage: String?

    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()

    init(apiService: APIService) {
        self.apiService = apiService

        $territorySearch
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { [weak self] in await self?.loadTerritories() }
            }
            .store(in: &cancellables)

        $personSearch
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { [weak self] in await self?.loadPersons() }
            }
            .store(in: &cancellables)
    }

    func loadTerritories() async {
        isLoadingTerritories = true
        defer { isLoadingTerritories = false }
        do {
            let result: [Territory] = try await apiService.request(
                endpoint: TerritoryEndpoint.getTerritories(
                    term: territorySearch.isEmpty ? nil : territorySearch,
                    inUse: nil,
                    orderBy: TerritorySortOption.name.rawValue,
                    orderByAscending: true,
                    lastGivenDateFrom: nil,
                    lastGivenDateTo: nil
                )
            )
            territories = result
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadPersons() async {
        isLoadingPersons = true
        defer { isLoadingPersons = false }
        do {
            let result: [Person] = try await apiService.request(
                endpoint: TerritoryEndpoint.getPersonsWithAssignments(
                    search: personSearch.isEmpty ? nil : personSearch
                )
            )
            persons = result
        } catch {
            if !error.isCancellation {
                errorMessage = error.localizedDescription
            }
        }
    }

    func resolve(scannedValue: String) async -> Territory? {
        isResolvingScan = true
        defer { isResolvingScan = false }
        do {
            let territory: Territory = try await apiService.request(
                endpoint: TerritoryEndpoint.resolveTerritorySelector(value: scannedValue)
            )
            return territory
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

private enum QuickActionDestination: Hashable, Identifiable {
    case assign
    case returnTerritory
    case personDecision

    var id: Self { self }
}

struct QuickActionHubView: View {
    @StateObject private var viewModel: QuickActionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showScanner = false
    @State private var showTerritoryPicker = false
    @State private var showPersonPicker = false
    @State private var selectedTerritory: Territory?
    @State private var selectedPerson: Person?
    @State private var destination: QuickActionDestination?

    @MainActor
    init() {
        _viewModel = StateObject(
            wrappedValue: QuickActionViewModel(apiService: DIContainer.shared.apiService)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    scanCard

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        quickActionButton(
                            title: "quick_action.select_territory",
                            subtitle: "quick_action.select_territory_hint",
                            systemImage: "map"
                        ) {
                            showTerritoryPicker = true
                        }

                        quickActionButton(
                            title: "quick_action.select_person",
                            subtitle: "quick_action.select_person_hint",
                            systemImage: "person.crop.circle"
                        ) {
                            showPersonPicker = true
                        }
                    }

                    Divider()

                    HStack(spacing: AppSpacing.sm) {
                        Button {
                            selectedTerritory = nil
                            selectedPerson = nil
                            destination = .assign
                        } label: {
                            Label("assignment.title", systemImage: "person.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            selectedTerritory = nil
                            destination = .returnTerritory
                        } label: {
                            Label("return.title", systemImage: "tray.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(AppSpacing.md)
            }
            .background { LiquidBackgroundView() }
            .navigationTitle("quick_action.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
            .navigationDestination(item: $destination) { route in
                switch route {
                case .assign:
                    TerritoryAssignmentView(
                        territory: selectedTerritory,
                        person: selectedPerson,
                        onSuccess: { dismiss() }
                    )
                case .returnTerritory:
                    TerritoryReturnView(
                        territory: selectedTerritory,
                        onSuccess: { dismiss() }
                    )
                case .personDecision:
                    if let selectedPerson {
                        PersonQuickActionDecisionView(
                            person: selectedPerson,
                            onAssign: {
                                destination = .assign
                            },
                            onReturn: { territory in
                                selectedTerritory = territory
                                destination = .returnTerritory
                            }
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView(isPresented: $showScanner) { value in
                Task {
                    if let territory = await viewModel.resolve(scannedValue: value) {
                        resolve(territory)
                    }
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showTerritoryPicker) {
            SearchSelectionSheet(
                title: String(localized: "quick_action.select_territory"),
                searchText: $viewModel.territorySearch,
                items: viewModel.territories,
                isLoading: viewModel.isLoadingTerritories,
                onSelect: resolve
            ) { territory in
                TerritorySelectionLabel(territory: territory)
            }
            .task { await viewModel.loadTerritories() }
        }
        .sheet(isPresented: $showPersonPicker) {
            SearchSelectionSheet(
                title: String(localized: "quick_action.select_person"),
                searchText: $viewModel.personSearch,
                items: viewModel.persons,
                isLoading: viewModel.isLoadingPersons,
                onSelect: resolve
            ) { person in
                PersonSelectionLabel(person: person)
            }
            .task { await viewModel.loadPersons() }
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

    private var scanCard: some View {
        Button {
            showScanner = true
        } label: {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(Color.accent)
                    .symbolEffect(.pulse, isActive: viewModel.isResolvingScan)
                Text("quick_action.scan")
                    .font(.appHeadline())
                    .foregroundStyle(Color.textPrimary)
                Text("quick_action.scan_hint")
                    .font(.appCaption())
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xl)
            .paperCard(cornerRadius: AppRadius.xl)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func quickActionButton(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accent)
                    .frame(width: 42, height: 42)
                    .background(Color.accent.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.appHeadline())
                        .foregroundStyle(Color.textPrimary)
                    Text(subtitle)
                        .font(.appCaption())
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(AppSpacing.md)
            .paperCard(cornerRadius: AppRadius.lg)
        }
        .buttonStyle(.plain)
    }

    private func resolve(_ territory: Territory) {
        selectedTerritory = territory
        selectedPerson = nil
        destination = territory.personName == nil ? .assign : .returnTerritory
    }

    private func resolve(_ person: Person) {
        selectedPerson = person
        selectedTerritory = nil
        let territories = person.territoriesInUse ?? []
        if territories.isEmpty {
            guard person.enabled else { return }
            destination = .assign
        } else {
            destination = .personDecision
        }
    }
}

private struct TerritorySelectionLabel: View {
    let territory: Territory

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            TerritoryCodeBadge(code: territory.code)
            VStack(alignment: .leading, spacing: 2) {
                Text(territory.name)
                Text(territory.personName == nil ? "territories.filter.free" : "territories.filter.in_use")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct PersonSelectionLabel: View {
    let person: Person

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                Text(
                    String(
                        format: String(localized: "quick_action.person_territory_count"),
                        person.territoriesInUse?.count ?? 0
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if !person.enabled {
                Label("brothers.status.inactive", systemImage: "person.slash")
                    .font(.caption)
                    .foregroundStyle(Color.warning)
            }
        }
    }
}

private struct PersonQuickActionDecisionView: View {
    let person: Person
    let onAssign: () -> Void
    let onReturn: (Territory) -> Void

    var body: some View {
        List {
            if person.enabled {
                Section {
                    Button(action: onAssign) {
                        Label("quick_action.give_another", systemImage: "person.badge.plus")
                    }
                }
            }

            Section("quick_action.return_one") {
                ForEach(person.territoriesInUse ?? [], id: \.territoryId) { assignment in
                    Button {
                        onReturn(
                            Territory(
                                id: assignment.territoryId,
                                code: assignment.territoryCode,
                                name: assignment.territoryName,
                                mapUrl: "",
                                imgUrl: nil,
                                personName: person.name,
                                givenDateUtc: assignment.givenDate,
                                lastPickedDateUtc: nil,
                                mapGeometry: nil
                            )
                        )
                    } label: {
                        HStack {
                            TerritoryCodeBadge(code: assignment.territoryCode)
                            VStack(alignment: .leading) {
                                Text(assignment.territoryName)
                                Text(assignment.givenDate, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
