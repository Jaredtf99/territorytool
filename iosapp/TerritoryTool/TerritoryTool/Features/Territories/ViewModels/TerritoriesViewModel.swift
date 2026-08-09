import Combine
import CoreLocation
import Foundation
import SwiftUI

enum TerritoryFilter: String, CaseIterable, Identifiable {
    case all = "territories.filter.all"
    case free = "territories.filter.free"
    case inUse = "territories.filter.in_use"
    case attention = "territories.filter.attention"

    var id: String { rawValue }
    var localizedName: String { NSLocalizedString(rawValue, comment: "") }

    var backendValue: String {
        switch self {
        case .all: "all"
        case .free: "available"
        case .inUse: "assigned"
        case .attention: "attention"
        }
    }
}

enum TerritorySortOption: Int, CaseIterable, Identifiable {
    case name = 1
    case code = 2
    case givenDate = 3
    case nearest = 4

    var id: Int { rawValue }

    var localizedName: String {
        switch self {
        case .name: NSLocalizedString("territories.sort.name", comment: "")
        case .code: NSLocalizedString("territories.sort.code", comment: "")
        case .givenDate: NSLocalizedString("territories.sort.given_date", comment: "")
        case .nearest: NSLocalizedString("territories.sort.nearest", comment: "")
        }
    }
}

enum TerritoryDrawerDetent: CaseIterable {
    case collapsed
    case medium
}

/// Listas derivadas de `territories`, materializadas juntas.
///
/// Se recalculan sólo cuando cambian sus entradas (territorios, búsqueda, orden,
/// `attentionDays`), no en cada redibujado, y se publican en un único cambio.
struct TerritoriesDerivedState {
    var sorted: [Territory] = []
    var withGeometry: [Territory] = []
    var withoutGeometry: [Territory] = []
    var attention: [Territory] = []
    /// Estado operacional precalculado una vez por territorio. Evita llamar a
    /// `Calendar.dateComponents` (caro) en cada render y en cada comparación de orden.
    var statusByID: [Int: TerritoryOperationalStatus] = [:]
    var displayRevision = 0
    var geometryRevision = 0
    /// Identidad del conjunto de geometrías; alimenta `geometryRevision`.
    var geometrySignature = ""
}

@MainActor
final class TerritoriesViewModel: ObservableObject {
    @Published private(set) var territories: [Territory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = "" { didSet { recompute() } }
    @Published var filterStatus: TerritoryFilter = .all
    @Published var sortOption: TerritorySortOption = .code { didSet { recompute() } }
    @Published var sortAscending = true { didSet { recompute() } }
    @Published var attentionDays = 90 { didSet { recompute() } }
    @Published var presentation: TerritoriesPresentation
    @Published var selectedTerritoryID: Int?
    @Published var drawerDetent: TerritoryDrawerDetent = .medium
    @Published private(set) var lastDeleteUndoHandle: UndoHandle?

    /// Todo lo derivado en **una sola** propiedad publicada.
    ///
    /// Antes eran cinco `@Published` separadas, así que cada `recompute()` emitía cinco
    /// `objectWillChange` seguidos —y encima dentro del `withAnimation` de la recarga—,
    /// provocando varias invalidaciones y pases de layout animados por carga.
    @Published private(set) var derived = TerritoriesDerivedState()

    /// Huella de geometría por territorio, cacheada.
    ///
    /// Se calcula una sola vez por carga de red y sobrevive a los recálculos por filtro u
    /// orden, que sólo cogen subconjuntos. Sin esto, `geometryRevision` volvería a hashear
    /// toda la geometría en cada pulsación del buscador.
    private var geometryFingerprints: [Int: String] = [:]

    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?

    init(apiService: APIService) {
        self.apiService = apiService
        let stored = UserDefaults.standard.string(forKey: "territories.presentation")
        presentation = stored == "list" ? .list : .map

        Publishers.CombineLatest($searchText, $filterStatus)
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .removeDuplicates { lhs, rhs in lhs.0 == rhs.0 && lhs.1 == rhs.1 }
            .dropFirst()
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .territoryDeleted)
            .merge(with: NotificationCenter.default.publisher(for: .territoryDataChanged))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .congregationChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.territories = []
                self.geometryFingerprints = [:]
                self.selectedTerritoryID = nil
                self.recompute()
                self.reload()
            }
            .store(in: &cancellables)
    }

    var selectedTerritory: Territory? {
        territories.first { $0.id == selectedTerritoryID }
    }

    // Accesores sobre el estado derivado. Leen de la única propiedad publicada, así que las
    // vistas no notan el cambio pero sólo hay una invalidación por recálculo.
    var sortedTerritories: [Territory] { derived.sorted }
    var territoriesWithGeometry: [Territory] { derived.withGeometry }
    var territoriesWithoutGeometry: [Territory] { derived.withoutGeometry }
    var attentionTerritories: [Territory] { derived.attention }
    var displayedTerritories: [Territory] { derived.sorted }

    /// Cambia en **cada** recálculo (incluida cada pulsación del buscador). Para animaciones
    /// de lista, donde ese es justo el comportamiento deseado.
    var displayRevision: Int { derived.displayRevision }

    /// Cambia **sólo** cuando cambia el conjunto de geometrías mostradas.
    ///
    /// Es la clave del mapa: engancharlo a `displayRevision` dispararía el carísimo
    /// preprocesado geométrico en cada tecla, incluso antes de que llegue la respuesta de
    /// red. Y compararlo contra `[Territory]` obliga a `Equatable` a recorrer todas las
    /// coordenadas de todos los polígonos en cada evaluación de body.
    var geometryRevision: Int { derived.geometryRevision }

    /// Estado operacional cacheado del territorio. Usar esto en las vistas en lugar de
    /// `territory.operationalStatus(...)` evita recalcular fechas con `Calendar` en cada render.
    func status(for territory: Territory) -> TerritoryOperationalStatus {
        derived.statusByID[territory.id] ?? territory.operationalStatus(attentionDays: attentionDays)
    }

    /// Orden por cercanía, cacheado **aparte** del resto de derivados.
    ///
    /// Va separado a propósito: si viviera en `TerritoriesDerivedState`, una actualización de
    /// ubicación forzaría a recalcular también filtros, orden y estados, que no dependen de
    /// ella. Y calcularlo en el `body` —como se hacía en el drawer y en la lista— significaba
    /// reordenar por distancia en **cada frame de arrastre**, a 120 Hz.
    @Published private(set) var nearestFirst: [Territory] = []

    private var lastNearestLocation: CLLocation?

    /// Recalcula el orden por cercanía si procede. Idempotente y barato cuando no hay cambios.
    func updateNearestOrder(from location: CLLocation?) {
        guard sortOption == .nearest, let location else {
            if !nearestFirst.isEmpty { nearestFirst = [] }
            lastNearestLocation = nil
            return
        }

        // Movimientos menores no justifican reordenar la lista entera.
        if let last = lastNearestLocation, last.distance(from: location) < 25,
           nearestFirst.count == derived.withGeometry.count {
            return
        }
        lastNearestLocation = location

        nearestFirst = derived.withGeometry.sorted {
            distance(from: location, to: $0) < distance(from: location, to: $1)
        }
    }

    /// Lista que debe pintar el drawer: orden por cercanía si está activo, si no el general.
    var drawerTerritories: [Territory] {
        sortOption == .nearest && !nearestFirst.isEmpty ? nearestFirst : derived.withGeometry
    }

    private func distance(from location: CLLocation, to territory: Territory) -> CLLocationDistance {
        guard let coordinate = territory.mapGeometry?.representativeCoordinate else {
            return .greatestFiniteMagnitude
        }
        return location.distance(
            from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        )
    }

    private func filtered() -> [Territory] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isCodeQuery(query) else { return territories }
        return territories.filter {
            normalized($0.code).contains(normalized(query))
        }
    }

    /// Recalcula el estado cacheado y todas las listas derivadas en una sola pasada, y
    /// publica el resultado de una sola vez.
    private func recompute() {
        let now = Date()
        let calendar = Calendar.current
        var statuses: [Int: TerritoryOperationalStatus] = [:]
        statuses.reserveCapacity(territories.count)
        for territory in territories {
            statuses[territory.id] = territory.operationalStatus(
                attentionDays: attentionDays,
                now: now,
                calendar: calendar
            )
        }

        let sortedValues = sorted(filtered())
        let withGeometry = sortedValues.filter { $0.mapGeometry != nil }

        var next = TerritoriesDerivedState(
            sorted: sortedValues,
            withGeometry: withGeometry,
            withoutGeometry: sortedValues.filter { $0.mapGeometry == nil },
            attention: sortedValues.filter {
                if case .attention = statuses[$0.id] { return true }
                return false
            },
            statusByID: statuses,
            displayRevision: derived.displayRevision &+ 1,
            geometryRevision: derived.geometryRevision,
            geometrySignature: geometrySignature(for: withGeometry)
        )

        // El mapa sólo tiene que reprocesar si cambia de verdad el conjunto de geometrías
        // mostradas: no basta con que se recargue (la recarga puede traer las mismas
        // geometrías y sólo cambiar la persona asignada o una fecha).
        if next.geometrySignature != derived.geometrySignature {
            next.geometryRevision = derived.geometryRevision &+ 1
        }

        derived = next
    }

    /// Firma del conjunto de geometrías mostradas: `[(id, huella)]` en orden de id.
    private func geometrySignature(for territories: [Territory]) -> String {
        territories
            .sorted { $0.id < $1.id }
            .map { territory in
                let fingerprint = geometryFingerprints[territory.id]
                    ?? territory.mapGeometry?.snapshotFingerprint
                    ?? ""
                return "\(territory.id):\(fingerprint)"
            }
            .joined(separator: "|")
    }

    /// Rehace la caché de huellas. Sólo tras una carga de red: filtrar y ordenar únicamente
    /// coge subconjuntos, así que las huellas por id siguen siendo válidas.
    private func refreshGeometryFingerprints() {
        var fingerprints: [Int: String] = [:]
        fingerprints.reserveCapacity(territories.count)
        for territory in territories {
            if let geometry = territory.mapGeometry {
                fingerprints[territory.id] = geometry.snapshotFingerprint
            }
        }
        geometryFingerprints = fingerprints
    }

    func setPresentation(_ value: TerritoriesPresentation, persist: Bool = true) {
        presentation = value
        if persist {
            UserDefaults.standard.set(value == .map ? "map" : "list", forKey: "territories.presentation")
        }
    }

    func select(_ territory: Territory?) {
        selectedTerritoryID = territory?.id
        // Al seleccionar, el drawer se compacta para mostrar SOLO ese territorio.
        if territory != nil { drawerDetent = .collapsed }
    }

    func reload() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in await self?.loadTerritories() }
    }

    func loadTerritories() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let result = try await apiService.territoryExplorer(
                term: term.isEmpty ? nil : term,
                filter: filterStatus,
                attentionDays: attentionDays
            )
            guard !Task.isCancelled else { return }

            // El cálculo va fuera de `withAnimation`: sólo la publicación del resultado
            // debe animarse. Antes se animaba también el recálculo entero.
            territories = result
            refreshGeometryFingerprints()
            if let selectedTerritoryID, !result.contains(where: { $0.id == selectedTerritoryID }) {
                self.selectedTerritoryID = nil
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                recompute()
            }
        } catch {
            guard !Task.isCancelled, !error.isCancellation else { return }
            errorMessage = error.localizedDescription
        }
    }

    func applyLaunchContext(_ context: TerritoriesLaunchContext) {
        attentionDays = context.attentionDays
        filterStatus = context.filter
        setPresentation(context.presentation, persist: false)
        sortOption = context.filter == .attention ? .givenDate : .code
        sortAscending = true
        selectedTerritoryID = nil
    }

    @discardableResult
    func deleteTerritory(_ territory: Territory) async -> Bool {
        errorMessage = nil
        do {
            let undoResponse: UndoableMutationResponse = try await apiService.request(endpoint: TerritoryEndpoint.deleteTerritoryUndoable(id: territory.id))
            lastDeleteUndoHandle = undoResponse.handle(kind: .domain)

            // La fila sólo desaparece después de que Supabase confirme el borrado. Además de
            // evitar el falso positivo, esto hace que la animación corresponda al resultado
            // real de la operación y no al gesto que abrió la confirmación.
            territories.removeAll { $0.id == territory.id }
            geometryFingerprints.removeValue(forKey: territory.id)
            if selectedTerritoryID == territory.id {
                selectedTerritoryID = nil
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                recompute()
            }

            NotificationCenter.default.post(name: .territoryDeleted, object: nil)
            return true
        } catch {
            lastDeleteUndoHandle = nil
            errorMessage = error.userFriendlyMessage
            return false
        }
    }

    private func sorted(_ values: [Territory]) -> [Territory] {
        values.sorted { lhs, rhs in
            sortAscending ? comesBefore(lhs, rhs) : comesBefore(rhs, lhs)
        }
    }

    private func isCodeQuery(_ query: String) -> Bool {
        guard !query.isEmpty, !query.contains(where: \.isWhitespace) else { return false }
        return query.contains(where: \.isLetter) && query.contains(where: \.isNumber)
    }

    private func normalized(_ value: String) -> String {
        String(
            value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .filter { $0.isLetter || $0.isNumber }
        )
    }

    private func comesBefore(_ lhs: Territory, _ rhs: Territory) -> Bool {
        switch sortOption {
        case .name:
            let comparison = lhs.name.localizedStandardCompare(rhs.name)
            return comparison == .orderedSame ? lhs.id < rhs.id : comparison == .orderedAscending
        case .code:
            let comparison = lhs.code.localizedStandardCompare(rhs.code)
            return comparison == .orderedSame ? lhs.id < rhs.id : comparison == .orderedAscending
        case .givenDate:
            // Ordena por el inicio del estado actual: fecha de entrega si está
            // asignado y última devolución si está libre. Un territorio libre que
            // nunca se ha asignado cuenta como el que más tiempo lleva sin uso.
            let leftDate = currentStateStartDate(for: lhs)
            let rightDate = currentStateStartDate(for: rhs)
            return leftDate == rightDate ? lhs.id < rhs.id : leftDate < rightDate
        case .nearest:
            // Location-aware ordering is applied by the view once distances are available.
            let comparison = lhs.code.localizedStandardCompare(rhs.code)
            return comparison == .orderedSame ? lhs.id < rhs.id : comparison == .orderedAscending
        }
    }

    private func currentStateStartDate(for territory: Territory) -> Date {
        let date = territory.personName == nil
            ? territory.lastPickedDateUtc
            : territory.givenDateUtc
        return date ?? .distantPast
    }
}
