import SwiftUI

/// Resolución de la Acción rápida. Se **empuja** en la pila del hub (sin hojas
/// anidadas): confirma qué encontró la app y guía la acción correcta —entregar,
/// devolver o encadenar ambas— con el lenguaje "Cartográfico cálido".
struct QuickActionResolutionView: View {
    @StateObject private var vm: QuickActionResolutionViewModel
    @Environment(\.dismiss) private var dismiss

    /// La acción terminó: deja al hub refrescar y recordar contexto.
    private let onCompleted: (QuickActionResolutionViewModel.SuccessKind) -> Void
    /// Cerrar todo el flujo de Acción rápida (no solo volver al hub).
    private let onFinish: () -> Void

    init(
        resolution: QuickActionResolution,
        onCompleted: @escaping (QuickActionResolutionViewModel.SuccessKind) -> Void = { _ in },
        onFinish: @escaping () -> Void = {}
    ) {
        self.onCompleted = onCompleted
        self.onFinish = onFinish
        _vm = StateObject(
            wrappedValue: QuickActionResolutionViewModel(
                apiService: DIContainer.shared.apiService,
                resolution: resolution
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                content
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .background { LiquidBackgroundView() }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .navigationTitle("quick_action.title")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: vm.step)
        .onChange(of: vm.successKind) { _, kind in
            if let kind { onCompleted(kind) }
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

    // MARK: - Contenido por paso

    @ViewBuilder
    private var content: some View {
        switch vm.step {
        case .returnConfirm:         returnConfirmContent
        case .deliverNeedsPerson:    deliverNeedsPersonContent
        case .personDecision:        personDecisionContent
        case .deliverNeedsTerritory: deliverNeedsTerritoryContent
        case .success:               successContent
        }
    }

    // MARK: Devolución

    @ViewBuilder
    private var returnConfirmContent: some View {
        if let territory = vm.subjectTerritory {
            ResolutionTerritoryHero(territory: territory)
                .appear(index: 0)

            if let days = territory.daysAssigned(), days >= 90 {
                CartoEmptyState(
                    systemImage: "clock.badge.exclamationmark",
                    message: "quick_action.long_held",
                    tint: .accentTertiary
                )
                .appear(index: 1)
            }
        }
    }

    // MARK: Entrega de territorio libre (elegir persona)

    @ViewBuilder
    private var deliverNeedsPersonContent: some View {
        if let territory = vm.subjectTerritory {
            ResolutionTerritoryHero(territory: territory)
                .appear(index: 0)
        }

        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            CartoSectionHeader(title: "quick_action.who_deliver", systemImage: "person.crop.circle.badge.plus")
            QuickSearchField(placeholder: "quick_action.search_publisher", text: $vm.personSearch)
            personResultsList
        }
        .appear(index: 1)
        .task { await vm.loadPersons() }
    }

    // MARK: Decisión de persona

    @ViewBuilder
    private var personDecisionContent: some View {
        if let person = vm.subjectPerson {
            PersonHero(person: person).appear(index: 0)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                CartoSectionHeader(title: "quick_action.return_one", systemImage: "tray.and.arrow.down", tint: .accentSecondary)
                VStack(spacing: AppSpacing.sm) {
                    ForEach(person.territoriesInUse ?? [], id: \.territoryId) { assignment in
                        let territory = assignment.asTerritory(personName: person.name)
                        Button {
                            HapticManager.shared.selection()
                            vm.chooseReturn(assignment)
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
                vm.chooseDeliverAnother()
            } label: {
                ActionPromptCard(
                    icon: "person.badge.plus",
                    title: "quick_action.deliver_other_territory",
                    subtitle: "quick_action.deliver_other_hint",
                    tint: .accentDeep
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .appear(index: 2)
        }
    }

    // MARK: Entrega a persona (elegir territorio)

    @ViewBuilder
    private var deliverNeedsTerritoryContent: some View {
        if let name = vm.targetPersonName {
            DeliverTargetHeader(personName: name).appear(index: 0)
        }

        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            QuickSearchField(placeholder: "quick_action.search_territory", text: $vm.territorySearch)

            if vm.territorySearch.isEmpty && !vm.suggestedTerritories.isEmpty {
                CartoSectionHeader(title: "quick_action.suggestions.free", systemImage: "leaf.fill")
                territoryList(vm.suggestedTerritories)
            } else {
                territoryList(vm.territoryResults)
            }
        }
        .appear(index: 1)
        .task {
            await vm.loadSuggestions()
            await vm.loadTerritories()
        }
    }

    // MARK: Éxito

    @ViewBuilder
    private var successContent: some View {
        if let kind = vm.successKind {
            VStack(spacing: AppSpacing.md) {
                Image(systemName: kind.isReturn ? "tray.and.arrow.down.fill" : "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.white)
                    .frame(width: 92, height: 92)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [kind.tint, kind.tint.opacity(0.8)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    )
                    .shadow(color: kind.tint.opacity(0.4), radius: 12, x: 0, y: 6)
                    .symbolEffect(.bounce, value: vm.successKind)

                Text(successTitle(kind))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.textPrimary)

                Text(successMessage(kind))
                    .font(.appBody())
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xl)
            .padding(.horizontal, AppSpacing.md)
            .paperCard(cornerRadius: AppRadius.xl)
            .appear(index: 0)

            // Acción inteligente: tras devolver, ofrecer entregar otro a la misma persona.
            if case let .returned(_, person?) = kind {
                Button {
                    HapticManager.shared.selection()
                    vm.chainDeliverToReturnedPerson()
                } label: {
                    ActionPromptCard(
                        icon: "arrow.turn.up.right",
                        title: LocalizedStringKey(String(format: String.localized("quick_action.chain_deliver"), person)),
                        subtitle: "quick_action.chain_deliver_hint",
                        tint: .accentSecondary
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .appear(index: 1)
            }
        }
    }

    // MARK: - Listas de selección

    @ViewBuilder
    private var personResultsList: some View {
        if vm.isLoadingPersons && vm.personResults.isEmpty {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, AppSpacing.md)
        } else {
            VStack(spacing: AppSpacing.xs) {
                ForEach(vm.personResults) { person in
                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { vm.selectedPerson = person }
                    } label: {
                        PersonQuickRow(person: person, accessory: .selection(vm.selectedPerson?.id == person.id))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func territoryList(_ items: [Territory]) -> some View {
        if vm.isLoadingTerritories && items.isEmpty {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, AppSpacing.md)
        } else {
            VStack(spacing: AppSpacing.xs) {
                ForEach(items) { territory in
                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { vm.selectedTerritory = territory }
                    } label: {
                        CompactTerritoryRow(
                            territory: territory,
                            accessory: .selection(vm.selectedTerritory?.id == territory.id)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Barra inferior de acción

    @ViewBuilder
    private var bottomBar: some View {
        switch vm.step {
        case .returnConfirm:
            actionBar {
                PrimaryButton(
                    title: "quick_action.confirm_return",
                    isLoading: vm.isSubmitting,
                    isDisabled: vm.isSubmitting,
                    tint: .success
                ) { Task { await vm.confirmReturn() } }
            }

        case .deliverNeedsPerson:
            actionBar {
                PrimaryButton(
                    title: deliverPersonTitle,
                    isLoading: vm.isSubmitting,
                    isDisabled: vm.selectedPerson == nil || vm.isSubmitting,
                    tint: .accent
                ) { Task { await vm.confirmDeliver() } }
            }

        case .deliverNeedsTerritory:
            actionBar {
                PrimaryButton(
                    title: deliverTerritoryTitle,
                    isLoading: vm.isSubmitting,
                    isDisabled: vm.selectedTerritory == nil || vm.isSubmitting,
                    tint: .accent
                ) { Task { await vm.confirmDeliver() } }
            }

        case .success:
            actionBar {
                HStack(spacing: AppSpacing.sm) {
                    Button { dismiss() } label: {
                        Label("quick_action.scan_another", systemImage: "qrcode.viewfinder")
                            .font(.appSubheadline().weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.xs)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .tint(.accentDeep)

                    Button { onFinish() } label: {
                        Text("common.done")
                            .font(.appSubheadline().weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.xs)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .tint(.accentDeep)
                }
            }

        case .personDecision:
            EmptyView()
        }
    }

    private func actionBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.sm)
    }

    private var deliverPersonTitle: LocalizedStringKey {
        if let name = vm.selectedPerson?.name {
            return LocalizedStringKey(String(format: String.localized("quick_action.deliver_to"), name))
        }
        return "quick_action.confirm_deliver"
    }

    private var deliverTerritoryTitle: LocalizedStringKey {
        if let code = vm.selectedTerritory?.code, let name = vm.targetPersonName {
            return LocalizedStringKey(String(format: String.localized("quick_action.deliver_code_to"), code, name))
        }
        return "quick_action.confirm_deliver"
    }

    // MARK: - Textos de éxito

    private func successTitle(_ kind: QuickActionResolutionViewModel.SuccessKind) -> LocalizedStringKey {
        switch kind {
        case .delivered: "quick_action.success.delivered_title"
        case .returned:  "quick_action.success.returned_title"
        }
    }

    private func successMessage(_ kind: QuickActionResolutionViewModel.SuccessKind) -> String {
        switch kind {
        case let .delivered(code, person):
            return String(format: String.localized("quick_action.success.delivered_msg"), code, person)
        case let .returned(code, _):
            return String(format: String.localized("quick_action.success.returned_msg"), code)
        }
    }
}

// MARK: - Helpers de SuccessKind

private extension QuickActionResolutionViewModel.SuccessKind {
    var isReturn: Bool { if case .returned = self { true } else { false } }
    /// Verde de éxito al recoger; verde de acento al entregar (igual que el resto de CTAs).
    var tint: Color { isReturn ? .success : .accent }
}

// MARK: - Cabecera hero del territorio (pantalla de confirmar)

/// Presentación "bonita" del territorio que estamos confirmando: mapa prominente
/// arriba + código grande, nombre, estado y (si está entregado) la persona. Es
/// deliberadamente distinta de la fila compacta del buscador.
private struct ResolutionTerritoryHero: View {
    let territory: Territory

    private var status: TerritoryStatusPresentation {
        TerritoryStatusPresentation(territory.operationalStatus())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mapBanner
                .frame(height: 168)
                .frame(maxWidth: .infinity)
                .clipped()

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.sm) {
                    TerritoryCodeBadge(code: territory.code, fontSize: .system(.title3, design: .rounded))
                    statusChip
                    Spacer(minLength: 0)
                }

                Text(territory.name)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let person = territory.personName {
                    HStack(spacing: AppSpacing.xs) {
                        QAInitialsAvatar(name: person, size: 32, tint: status.color)
                        Text(person)
                            .font(.appHeadline())
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                    }
                } else {
                    Label(status.detail, systemImage: "calendar")
                        .font(.appCaption())
                        .foregroundStyle(status.color)
                }
            }
            .padding(AppSpacing.md)
        }
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .strokeBorder(Color.hairline, lineWidth: 1)
        )
        .shadow(color: Color.glassShadow, radius: 14, x: 0, y: 8)
    }

    @ViewBuilder
    private var mapBanner: some View {
        if let geometry = territory.mapGeometry {
            TerritorySnapshotBackdrop(
                geometry: geometry,
                stroke: status.color,
                fill: status.color,
                centersTerritory: true
            )
        } else if let url = territory.imgUrl.flatMap(URL.init(string:)) {
            CachedAsyncImage(
                url: url,
                content: { $0.resizable().scaledToFill() },
                placeholder: { mapPlaceholder },
                errorView: { mapPlaceholder }
            )
        } else {
            mapPlaceholder
        }
    }

    private var mapPlaceholder: some View {
        status.color.opacity(0.10)
            .overlay(
                Image(systemName: "map.fill")
                    .font(.largeTitle)
                    .foregroundStyle(status.color.opacity(0.45))
            )
    }

    private var statusChip: some View {
        Text(status.title)
            .font(.appCaption().weight(.bold))
            .foregroundStyle(status.color)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xxs)
            .background(status.color.opacity(0.14), in: Capsule())
    }
}

// MARK: - Cabecera de persona (decisión)

private struct PersonHero: View {
    let person: Person

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            QAInitialsAvatar(name: person.name, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: String.localized("quick_action.person_question"), person.name.firstName))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                Text(String(format: String.localized("quick_action.person_territory_count"), person.activeTerritoryCount))
                    .font(.appSubheadline())
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .paperCard(cornerRadius: AppRadius.xl)
    }
}

// MARK: - Cabecera "Entregar a {persona}"

private struct DeliverTargetHeader: View {
    let personName: String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            QAInitialsAvatar(name: personName, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("quick_action.deliver_target")
                    .font(.appCaption())
                    .foregroundStyle(Color.textSecondary)
                Text(personName)
                    .font(.appHeadline())
                    .foregroundStyle(Color.textPrimary)
            }
            Spacer()
        }
        .padding(AppSpacing.md)
        .paperCard(cornerRadius: AppRadius.lg)
    }
}

// MARK: - Filas y tarjetas auxiliares

/// Tarjeta-prompt de acción (icono en círculo tintado + título + subtítulo + chevron).
private struct ActionPromptCard: View {
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

// MARK: - Campo de búsqueda inline

struct QuickSearchField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.textSecondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.appBody())
                .foregroundStyle(Color.textPrimary)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.textSecondary)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous).strokeBorder(Color.hairline, lineWidth: 1))
    }
}

private extension String {
    /// Primer nombre (para titulares cercanos: "¿Qué quieres hacer con Andrés?").
    var firstName: String { split(separator: " ").first.map(String.init) ?? self }
}
