import SwiftUI

/// Acción final del flujo de Acción rápida: entregar un territorio libre a alguien,
/// o recoger uno asignado. Es `Hashable` para empujarse como destino de navegación.
enum QuickActionAction: Hashable {
    case deliver(territory: Territory, personName: String)
    case returnTerritory(Territory)

    var territory: Territory {
        switch self {
        case .deliver(let t, _): t
        case .returnTerritory(let t): t
        }
    }

    var isDeliver: Bool {
        if case .deliver = self { return true }
        return false
    }

    /// Persona destino (solo en entrega).
    var personName: String? {
        if case .deliver(_, let name) = self { return name }
        return nil
    }

    static func == (lhs: QuickActionAction, rhs: QuickActionAction) -> Bool {
        switch (lhs, rhs) {
        case let (.deliver(lt, ln), .deliver(rt, rn)): lt.id == rt.id && ln == rn
        case let (.returnTerritory(lt), .returnTerritory(rt)): lt.id == rt.id
        default: false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .deliver(let t, let name):
            hasher.combine("d"); hasher.combine(t.id); hasher.combine(name)
        case .returnTerritory(let t):
            hasher.combine("r"); hasher.combine(t.id)
        }
    }
}

/// Pantalla de confirmación: resumen visual y claro de lo que se va a hacer + fecha
/// + acción prominente. Al confirmar se ejecuta (con toast deshacible) y se vuelve al
/// tablero. Inspirada en el mockup de "Devolver".
struct QuickActionConfirmView: View {
    let action: QuickActionAction
    /// Cierra el flujo y lleva al tablero (lo controla `MainTabView`).
    let onDone: () -> Void
    /// Solo en devolución: recoge y continúa para entregar otro territorio a la misma
    /// persona (recibe el nombre). Lo gestiona el hub reemplazando el destino.
    var onDeliverAnother: ((String) -> Void)? = nil

    @State private var dateExpanded = false
    @State private var customized = false
    @State private var pickedDate = Date()
    @State private var isSubmitting = false
    /// El territorio puede llegar sin geometría (p. ej. desde la decisión de persona);
    /// si falta, lo hidratamos con el completo para poder mostrar el mapa.
    @State private var hydratedTerritory: Territory?

    private let apiService: APIService = DIContainer.shared.apiService

    private var territory: Territory { hydratedTerritory ?? action.territory }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                ConfirmTerritoryHero(territory: territory)
                    .appear(index: 0)

                if let personName = action.personName {
                    deliverTargetCard(personName).appear(index: 1)
                }

                dateCard.appear(index: 2)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.lg)
        }
        .scrollIndicators(.hidden)
        .background { LiquidBackgroundView().ignoresSafeArea() }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .navigationTitle(action.isDeliver ? "assignment.title" : "return.title")
        .navigationBarTitleDisplayMode(.inline)
        .task { await hydrateGeometryIfNeeded() }
    }

    /// Si el territorio llegó sin geometría, trae el completo para mostrar el mapa.
    private func hydrateGeometryIfNeeded() async {
        guard action.territory.mapGeometry == nil, hydratedTerritory == nil else { return }
        if let full: Territory = try? await apiService.request(
            endpoint: TerritoryEndpoint.getTerritory(id: action.territory.id)
        ) {
            hydratedTerritory = full
        }
    }

    // MARK: - Tarjeta destino (entrega)

    private func deliverTargetCard(_ personName: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            InitialsAvatar(name: personName, size: 46, tint: .accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("quick_action.deliver_target")
                    .font(.appCaption())
                    .foregroundStyle(Color.textSecondary)
                Text(personName)
                    .font(.appTitle())
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .paperCard(cornerRadius: AppRadius.lg)
    }

    // MARK: - Fecha (fila tocable + picker expandible)

    private var dateCard: some View {
        VStack(spacing: 0) {
            Button {
                HapticManager.shared.selection()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) { dateExpanded.toggle() }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "clock")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.accentDeep)
                        .frame(width: 40, height: 40)
                        .background(Color.accent.opacity(0.12), in: Circle())

                    Text(dateLabel)
                        .font(.appHeadline())
                        .foregroundStyle(Color.textPrimary)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.textSecondary)
                        .rotationEffect(.degrees(dateExpanded ? 180 : 0))
                }
                .padding(AppSpacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if dateExpanded {
                VStack(spacing: AppSpacing.sm) {
                    DatePicker(
                        "",
                        selection: $pickedDate,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.graphical)
                    .tint(.accent)
                    .onChange(of: pickedDate) { _, _ in customized = true }

                    if customized {
                        Button {
                            withAnimation { customized = false; pickedDate = Date() }
                        } label: {
                            Label("quick_action.date_now", systemImage: "arrow.uturn.backward")
                                .font(.appSubheadline().weight(.semibold))
                                .foregroundStyle(Color.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding([.horizontal, .bottom], AppSpacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .paperCard(cornerRadius: AppRadius.lg)
    }

    private var dateLabel: String {
        if customized {
            return pickedDate.formatted(date: .abbreviated, time: .shortened)
        }
        return String.localized("quick_action.date_now") + " · " + Date().formatted(date: .abbreviated, time: .shortened)
    }

    // MARK: - Barra inferior (acción)

    @ViewBuilder
    private var bottomBar: some View {
        Group {
            // Devolución con opción de encadenar: dos botones al mismo nivel.
            if !action.isDeliver, territory.personName != nil, onDeliverAnother != nil {
                HStack(spacing: AppSpacing.sm) {
                    Button { Task { await submit() } } label: {
                        actionLabel("quick_action.action.return", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .tint(.success)

                    Button { Task { await submit(deliverAnother: true) } } label: {
                        actionLabel("quick_action.return_deliver_short", systemImage: "arrow.2.squarepath")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .tint(.accentSecondary)
                    .accessibilityLabel(Text("quick_action.return_deliver"))
                }
                .disabled(isSubmitting)
            } else {
                PrimaryButton(
                    title: action.isDeliver ? "quick_action.confirm_deliver" : "quick_action.confirm_return",
                    isLoading: isSubmitting,
                    isDisabled: isSubmitting,
                    tint: action.isDeliver ? .accent : .success
                ) {
                    Task { await submit() }
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.sm)
    }

    private func actionLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: systemImage)
            Text(title).fontWeight(.semibold).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xs)
    }

    // MARK: - Ejecución

    private func submit(deliverAnother: Bool = false) async {
        isSubmitting = true
        defer { isSubmitting = false }

        // Al encadenar guardamos a quién tenía el territorio antes de recogerlo.
        let previousHolder = territory.personName
        let date: Date? = customized ? pickedDate : nil
        do {
            let toastKey: String
            let response: UndoableMutationResponse
            if let personName = action.personName {
                response = try await apiService.request(
                    endpoint: TerritoryEndpoint.giveTerritoryUndoable(code: territory.code, personName: personName, date: date)
                )
                toastKey = "assignment.success"
            } else {
                response = try await apiService.request(
                    endpoint: TerritoryEndpoint.pickTerritoryUndoable(code: territory.code, date: date)
                )
                toastKey = "return.success"
            }

            let handle = response.handle(kind: .domain)
            ToastManager.shared.show(
                String.localized(toastKey),
                style: .success,
                undoHandle: handle,
                duration: handle.toastDuration
            )
            NotificationCenter.default.post(name: .territoryDataChanged, object: nil)

            if deliverAnother, let previousHolder, let onDeliverAnother {
                onDeliverAnother(previousHolder)
            } else {
                onDone()
            }
        } catch {
            // Mensaje claro por toast en vez de un alert con el código crudo.
            ToastManager.shared.show(error.userFriendlyMessage, style: .error)
        }
    }
}

// MARK: - Hero rico del territorio (mapa al sangrado derecha)

/// Resumen visual del territorio para la confirmación: columna de info a la izquierda
/// (código, estado, persona/fecha, días en uso) y el mapa real sangrando por la derecha.
private struct ConfirmTerritoryHero: View {
    let territory: Territory

    private var assigned: Bool { territory.isAssigned }
    private var status: TerritoryStatusPresentation { TerritoryStatusPresentation(territory.operationalStatus()) }
    private var tint: Color { status.color }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text(territory.code)
                    .font(.system(.title, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.accentDeep)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Text("· \(territory.name)")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            if assigned, let person = territory.personName {
                HStack(spacing: AppSpacing.sm) {
                    InitialsAvatar(name: person, size: 38, tint: tint)
                    Text(person)
                        .font(.appHeadline())
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                }

                if let given = territory.givenDateUtc {
                    Text(String(format: String.localized("territories.drawer.assigned_on"), given.formatted(date: .abbreviated, time: .omitted)))
                        .font(.appSubheadline())
                        .foregroundStyle(Color.textSecondary)
                }

                divider

                if let days = territory.daysAssigned() {
                    daysBlock("quick_action.in_use_since", days)
                }
            } else {
                statusLabel

                if let days = territory.daysFree() {
                    divider
                    daysBlock("quick_action.free_since_label", days)
                } else {
                    Text("territories.drawer.never_picked")
                        .font(.appSubheadline())
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .padding(AppSpacing.md)
        .padding(.trailing, 104)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .background(alignment: .trailing) { mapBackdrop }
        .background { RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous).fill(Color.surface) }
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [tint.opacity(0.7), tint.opacity(0.22)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        }
        .compositingGroup()
        .shadow(color: Color.glassShadow, radius: 14, x: 0, y: 8)
    }

    /// Indicador de estado idéntico al del listado de territorios (icono en círculo
    /// con degradado + título), vía `TerritoryStatusPresentation`.
    private var statusLabel: some View {
        TerritoryStatusIndicator(presentation: status)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.hairline)
            .frame(width: 96, height: 1)
            .padding(.vertical, AppSpacing.xxs)
    }

    private func daysBlock(_ label: LocalizedStringKey, _ days: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.appCaption())
                .foregroundStyle(Color.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(days)")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.textPrimary)
                Text("common.days")
                    .font(.appHeadline())
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var mapBackdrop: some View {
        Group {
            if let geometry = territory.mapGeometry {
                TerritorySnapshotBackdrop(geometry: geometry, stroke: tint, fill: tint, verticalBias: 0.1)
            } else if let url = territory.imgUrl.flatMap(URL.init(string:)) {
                CachedAsyncImage(
                    url: url,
                    content: { $0.resizable().scaledToFill() },
                    placeholder: { tint.opacity(0.08) },
                    errorView: { tint.opacity(0.08) }
                )
            } else {
                tint.opacity(0.06)
            }
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0), location: 0),
                    .init(color: .black.opacity(0.35), location: 0.32),
                    .init(color: .black.opacity(0.8), location: 0.55),
                    .init(color: .black, location: 0.72),
                    .init(color: .black, location: 1)
                ],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .mask(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
    }
}
