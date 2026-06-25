import Combine
import Foundation
import SwiftUI

/// Conduce la hoja de resolución: decide entre entregar y devolver según el
/// territorio o la persona, gestiona los selectores inline y ejecuta la acción.
@MainActor
final class QuickActionResolutionViewModel: ObservableObject {
    enum Step: Equatable {
        /// Territorio libre: falta elegir a quién entregarlo.
        case deliverNeedsPerson
        /// Territorio asignado: confirmar devolución.
        case returnConfirm
        /// Persona con territorio(s): elegir devolver o entregar otro.
        case personDecision
        /// Persona sin territorio activo: falta elegir territorio a entregar.
        case deliverNeedsTerritory
        /// Acción completada.
        case success
    }

    enum SuccessKind: Equatable {
        case delivered(code: String, person: String)
        case returned(code: String, person: String?)
    }

    @Published var step: Step
    @Published private(set) var successKind: SuccessKind?

    /// Territorio sujeto de la acción (devolución o confirmación de entrega).
    @Published var subjectTerritory: Territory?
    /// Persona destino/sujeto.
    @Published var subjectPerson: Person?
    @Published var targetPersonName: String?

    // Selector de persona (entregar un territorio libre)
    @Published var personSearch = ""
    @Published var personResults: [Person] = []
    @Published var isLoadingPersons = false
    @Published var selectedPerson: Person?

    // Selector de territorio (entregar a una persona)
    @Published var territorySearch = ""
    @Published var territoryResults: [Territory] = []
    @Published var suggestedTerritories: [Territory] = []
    @Published var isLoadingTerritories = false
    @Published var selectedTerritory: Territory?

    @Published var isSubmitting = false
    @Published var errorMessage: String?

    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()

    init(apiService: APIService, resolution: QuickActionResolution) {
        self.apiService = apiService

        switch resolution {
        case .territory(let territory):
            subjectTerritory = territory
            if territory.isAssigned {
                step = .returnConfirm
            } else {
                step = .deliverNeedsPerson
            }
        case .person(let person):
            subjectPerson = person
            targetPersonName = person.name
            if person.hasActiveTerritory {
                step = .personDecision
            } else {
                step = .deliverNeedsTerritory
            }
        }

        // `dropFirst()`: solo reaccionar a lo que el usuario teclea. La carga inicial
        // la dispara el `.task` del paso que la necesita, así un simple "devolver" o la
        // decisión de persona no lanzan búsquedas de personas/territorios innecesarias.
        $personSearch
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .removeDuplicates()
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in Task { [weak self] in await self?.loadPersons() } }
            .store(in: &cancellables)

        $territorySearch
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .removeDuplicates()
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in Task { [weak self] in await self?.loadTerritories() } }
            .store(in: &cancellables)
    }

    // MARK: - Transiciones desde la decisión de persona

    /// El usuario eligió devolver un territorio concreto de la persona.
    func chooseReturn(_ assignment: TerritoryInUse) {
        guard let name = subjectPerson?.name ?? targetPersonName else { return }
        subjectTerritory = assignment.asTerritory(personName: name)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            step = .returnConfirm
        }
    }

    /// El usuario eligió entregar otro territorio a la persona.
    func chooseDeliverAnother() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            step = .deliverNeedsTerritory
        }
        Task { await loadSuggestions() }
    }

    /// Tras devolver, encadenar la entrega de otro territorio a la misma persona.
    func chainDeliverToReturnedPerson() {
        guard case let .returned(_, person?) = successKind else { return }
        targetPersonName = person
        subjectPerson = nil
        selectedTerritory = nil
        territorySearch = ""
        territoryResults = []
        successKind = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            step = .deliverNeedsTerritory
        }
        Task { await loadSuggestions() }
    }

    // MARK: - Ejecución

    /// Devuelve el territorio sujeto.
    func confirmReturn() async -> Bool {
        guard let territory = subjectTerritory else { return false }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let undoResponse: UndoableMutationResponse = try await apiService.request(endpoint: TerritoryEndpoint.pickTerritoryUndoable(code: territory.code, date: nil))
            finish(
                toastKey: "return.success",
                kind: .returned(code: territory.code, person: territory.personName),
                undoHandle: undoResponse.handle(kind: .domain)
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Entrega un territorio (libre) a la persona seleccionada/destino.
    func confirmDeliver() async -> Bool {
        // Territorio: el sujeto (si era libre) o el seleccionado en el picker.
        let territory = subjectTerritory ?? selectedTerritory
        let personName = selectedPerson?.name ?? targetPersonName
        guard let territory, let personName else { return false }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let undoResponse: UndoableMutationResponse = try await apiService.request(
                endpoint: TerritoryEndpoint.giveTerritoryUndoable(code: territory.code, personName: personName, date: nil)
            )
            finish(
                toastKey: "assignment.success",
                kind: .delivered(code: territory.code, person: personName),
                undoHandle: undoResponse.handle(kind: .domain)
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func finish(toastKey: String, kind: SuccessKind, undoHandle: UndoHandle) {
        ToastManager.shared.show(
            String.localized(toastKey),
            style: .success,
            undoHandle: undoHandle,
            duration: undoHandle.toastDuration
        )
        NotificationCenter.default.post(name: .territoryDataChanged, object: nil)
        successKind = kind
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            step = .success
        }
    }

    // MARK: - Carga de datos

    func loadPersons() async {
        isLoadingPersons = true
        defer { isLoadingPersons = false }
        do {
            let term = personSearch.trimmingCharacters(in: .whitespacesAndNewlines)
            let result: [Person] = try await apiService.request(
                endpoint: TerritoryEndpoint.getPersons(search: term.isEmpty ? nil : term)
            )
            personResults = result
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
    }

    func loadTerritories() async {
        isLoadingTerritories = true
        defer { isLoadingTerritories = false }
        do {
            let term = territorySearch.trimmingCharacters(in: .whitespacesAndNewlines)
            let result: [Territory] = try await apiService.request(
                endpoint: TerritoryEndpoint.getTerritories(
                    term: term.isEmpty ? nil : term,
                    inUse: false,
                    orderBy: TerritorySortOption.name.rawValue,
                    orderByAscending: true,
                    lastGivenDateFrom: nil,
                    lastGivenDateTo: nil
                )
            )
            territoryResults = result
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
    }

    func loadSuggestions() async {
        do {
            let result: [Territory] = try await apiService.request(
                endpoint: TerritoryEndpoint.getTerritories(
                    term: nil, inUse: false,
                    orderBy: nil, orderByAscending: nil,
                    lastGivenDateFrom: nil, lastGivenDateTo: nil
                )
            )
            suggestedTerritories = result
                .sorted { lhs, rhs in
                    guard let l = lhs.lastPickedDateUtc else { return true }
                    guard let r = rhs.lastPickedDateUtc else { return false }
                    return l < r
                }
                .prefix(4)
                .map { $0 }
        } catch {
            if !error.isCancellation { errorMessage = error.localizedDescription }
        }
    }
}
