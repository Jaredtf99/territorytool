import SwiftUI

/// Centro rápido de escaneo. Pantalla única con cámara embebida y un buscador
/// universal anclado abajo (cristal líquido, estilo Safari): el usuario escanea o
/// busca y la app infiere si toca entregar o devolver. La resolución se **empuja**
/// en esta misma pila (sin hojas anidadas).
struct QuickActionHubView: View {
    /// Cierra todo el flujo (lo controla `MainTabView`, que lo presenta superpuesto).
    let onClose: () -> Void

    @StateObject private var vm = QuickActionViewModel(apiService: DIContainer.shared.apiService)
    @Environment(\.scenePhase) private var scenePhase

    @State private var resolution: QuickActionResolution?
    @FocusState private var searchFocused: Bool

    /// El usuario está buscando: hay texto o el campo tiene el foco.
    private var isSearching: Bool {
        searchFocused || vm.hasSearch
    }

    /// La cámara se pausa con la escena inactiva, al empujar la resolución o
    /// mientras el usuario está buscando (entonces ni siquiera se muestra).
    private var cameraActive: Bool {
        resolution == nil && scenePhase == .active && !isSearching
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Mientras se busca, la cámara no aporta nada: se oculta.
                    if !isSearching {
                        ScannerCameraCard(
                            isActive: .constant(cameraActive),
                            onScan: handleScan,
                            onManualSearch: { searchFocused = true }
                        )
                        .appear(index: 0)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if vm.hasSearch {
                        searchResults
                    } else {
                        suggestions
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xl)
                .animation(.spring(response: 0.4, dampingFraction: 0.88), value: isSearching)
            }
            .scrollIndicators(.hidden)
            .background { LiquidBackgroundView().ignoresSafeArea() }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { searchBar }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { onClose() } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                    }
                    .accessibilityLabel(Text("common.close"))
                }
            }
            .navigationDestination(item: $resolution) { resolution in
                QuickActionResolutionView(
                    resolution: resolution,
                    onCompleted: handleCompleted,
                    onFinish: onClose
                )
            }
            .task { await vm.loadSuggestions() }
            .onReceive(NotificationCenter.default.publisher(for: .territoryDataChanged)) { _ in
                Task { await vm.loadSuggestions() }
            }
            .alert(
                "common.error",
                isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })
            ) {
                Button("common.ok", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    // MARK: - Buscador inferior (barra de cristal a ancho completo, tipo tab bar)

    private var searchBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)

            TextField("quick_action.search_placeholder", text: $vm.searchTerm)
                .textFieldStyle(.plain)
                .font(.appBody())
                .foregroundStyle(Color.textPrimary)
                .focused($searchFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !vm.searchTerm.isEmpty {
                Button {
                    vm.searchTerm = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("common.clear"))
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        // Captura todo el toque dentro de la cápsula para que no se cuele a la fila de
        // debajo. Sin `.interactive()`: el cristal interactivo se "comía" el toque del
        // botón de limpiar (mismo criterio que el buscador del explorador).
        .contentShape(Capsule())
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.bottom, AppSpacing.xs)
    }

    // MARK: - Resultados de búsqueda

    @ViewBuilder
    private var searchResults: some View {
        if vm.isSearching && !vm.hasAnyResults {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, AppSpacing.lg)
        } else if !vm.hasAnyResults {
            CartoEmptyState(systemImage: "mappin.slash", message: "quick_action.no_results")
        } else {
            // Lista única rankeada por relevancia (territorios + personas mezclados).
            VStack(spacing: AppSpacing.xs) {
                ForEach(vm.searchHits) { hit in
                    if let resolution = hit.resolution {
                        rowButton(resolution) { hitRow(hit) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func hitRow(_ hit: QuickSearchHit) -> some View {
        switch hit.kind {
        case .territory:
            if let territory = hit.territory {
                CompactTerritoryRow(territory: territory)
            }
        case .person:
            if let person = hit.person {
                PersonQuickRow(person: person)
            }
        }
    }

    // MARK: - Sugerencias (estado ocioso)

    @ViewBuilder
    private var suggestions: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            if let name = vm.lastReturnedPersonName {
                Button { deliverToReturnedPerson(name) } label: {
                    ChainSuggestionCard(personName: name)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            if vm.isLoadingSuggestions && vm.attentionTerritories.isEmpty && vm.oldestFreeTerritories.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, AppSpacing.lg)
            }

            if !vm.attentionTerritories.isEmpty {
                section(title: "quick_action.suggestions.attention", systemImage: "exclamationmark.triangle.fill", tint: .accentTertiary) {
                    ForEach(vm.attentionTerritories) { territory in
                        rowButton(.territory(territory)) {
                            CompactTerritoryRow(territory: territory)
                        }
                    }
                }
            }

            if !vm.oldestFreeTerritories.isEmpty {
                section(title: "quick_action.suggestions.free", systemImage: "leaf.fill") {
                    ForEach(vm.oldestFreeTerritories) { territory in
                        rowButton(.territory(territory)) {
                            CompactTerritoryRow(territory: territory)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers de presentación

    @ViewBuilder
    private func section<Content: View>(
        title: LocalizedStringKey,
        systemImage: String,
        tint: Color = .accent,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Cabecera simple (sin la línea de puntos): icono + título en una sola línea.
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
            VStack(spacing: AppSpacing.xs) { content() }
        }
    }

    private func rowButton<Content: View>(
        _ res: QuickActionResolution,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button { select(res) } label: { content() }
            .buttonStyle(.plain)
    }

    // MARK: - Acciones

    private func handleScan(_ value: String) {
        Task {
            if let territory = await vm.resolve(scannedValue: value) {
                HapticManager.shared.notification(type: .success)
                resolution = .territory(territory)
            } else {
                HapticManager.shared.notification(type: .error)
            }
        }
    }

    private func select(_ res: QuickActionResolution) {
        HapticManager.shared.selection()
        searchFocused = false
        resolution = res
    }

    private func handleCompleted(_ kind: QuickActionResolutionViewModel.SuccessKind) {
        if case let .returned(_, person?) = kind {
            vm.lastReturnedPersonName = person
        } else {
            vm.lastReturnedPersonName = nil
        }
        Task { await vm.loadSuggestions() }
    }

    private func deliverToReturnedPerson(_ name: String) {
        // Persona mínima sin territorios: la resolución llevará a elegir territorio.
        let person = Person(id: Int.random(in: 1_000_000...9_999_999), name: name, enabled: true, territoriesInUse: [])
        select(.person(person))
    }
}

/// Tarjeta de sugerencia encadenada: "Entregar otro a {persona}".
private struct ChainSuggestionCard: View {
    let personName: String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "arrow.turn.up.right")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    LinearGradient(colors: [.accentSecondary, .accentSecondary.opacity(0.78)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
                .shadow(color: Color.accentSecondary.opacity(0.35), radius: 5, x: 0, y: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: String.localized("quick_action.chain_deliver"), personName))
                    .font(.appHeadline()).foregroundStyle(Color.textPrimary)
                Text("quick_action.chain_deliver_hint")
                    .font(.appCaption()).foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Color.textSecondary)
        }
        .padding(AppSpacing.md)
        .paperCard(cornerRadius: AppRadius.lg)
    }
}
