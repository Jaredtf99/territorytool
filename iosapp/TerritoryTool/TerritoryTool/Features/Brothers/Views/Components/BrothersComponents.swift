import SwiftUI

// MARK: - Piezas del explorador de Hermanos (tema "Cartográfico cálido").
// Controles fijos (búsqueda + orden + chips de filtro, mismo formato que el
// explorador de Territorios), tarjeta resumen estilo mockup (frase + pictogramas
// + puntos por urgencia), fila compacta de hermano y "ruta" expandible de
// asignaciones.

// MARK: Tinte de avatar

extension Person {
    /// Tinte estable por persona (rota por id sobre la paleta cálida).
    var avatarTint: Color {
        guard enabled else { return .textSecondary }
        let palette: [Color] = [.accent, .accentSecondary, .accentTertiary, .info]
        return palette[abs(id) % palette.count]
    }
}

// MARK: Controles superiores

struct BrothersControls: View {
    @ObservedObject var viewModel: BrothersViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            searchField
                .padding(.horizontal, AppSpacing.md)

            // El scroll ocupa todo el ancho (el margen va en el contenido):
            // así los chips no se clipean en el contenedor y llegan al borde.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    sortMenu
                    ForEach(BrotherFilter.allCases) { filter in
                        filterChip(filter)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 2)
            }
        }
        .padding(.bottom, AppSpacing.xs)
    }

    private var searchField: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)

            TextField("brothers.search_placeholder", text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("common.clear"))
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        // Sin `.interactive()`: el cristal interactivo capturaba el toque del botón de limpiar.
        .glassEffect(.regular, in: .capsule)
    }

    private var sortMenu: some View {
        Menu {
            Picker("brothers.sort.title", selection: $viewModel.sortOption) {
                ForEach(BrotherSortOption.allCases) { option in
                    Text(option.titleKey).tag(option)
                }
            }
            Button {
                viewModel.sortAscending.toggle()
            } label: {
                Label(
                    viewModel.sortAscending ? "territories.sort.ascending" : "territories.sort.descending",
                    systemImage: viewModel.sortAscending ? "arrow.up" : "arrow.down"
                )
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentDeep)
                .frame(width: 34, height: 34)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(Text("brothers.sort.title"))
    }

    @ViewBuilder
    private func filterChip(_ filter: BrotherFilter) -> some View {
        let selected = viewModel.filter == filter
        Button {
            HapticManager.shared.selection()
            withAnimation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.78)) {
                viewModel.filter = filter
            }
        } label: {
            HStack(spacing: 6) {
                Text(filter.titleKey)
                    .font(.appCaption().weight(.medium))
                    .foregroundStyle(selected ? .white : Color.textPrimary)

                Text("\(viewModel.count(for: filter))")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(selected ? .white : Color.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        selected ? Color.white.opacity(0.22) : Color.accent.opacity(0.12),
                        in: Capsule()
                    )
            }
            .padding(.horizontal, AppSpacing.sm)
            .frame(height: 34)
        }
        .glassEffect(
            selected ? .regular.tint(.accent).interactive() : .regular.interactive(),
            in: .capsule
        )
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: Tarjeta resumen

/// "X hermanos tienen · Y territorios" + pictogramas de hermanos (verde = con
/// territorio) y rejilla de puntos, uno por asignación activa, coloreados por
/// antigüedad (rampa de urgencia). Réplica de la tarjeta del mockup.
struct BrothersSummaryCard: View {
    let holderCount: Int
    let enabledCount: Int
    let assignmentDays: [Int]

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            phrase

            Rectangle()
                .fill(Color.hairline)
                .frame(width: 1)
                .frame(maxHeight: 48)

            peopleGrid

            dotGrid
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(
            format: String.localized("brothers.summary.accessibility"),
            holderCount, assignmentDays.count
        )))
    }

    private var phrase: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(format: String.localized("brothers.summary.have"), holderCount))
                .font(.appSubheadline())
                .foregroundStyle(Color.textPrimary)
                .contentTransition(.numericText())

            Text(String(format: String.localized("brothers.summary.territories"), assignmentDays.count))
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.textPrimary)
                .contentTransition(.numericText())
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .layoutPriority(1)
    }

    /// Pictogramas 2×6: proporción de hermanos activos con territorio (verde)
    /// frente al resto (gris), como en el mockup.
    private var peopleGrid: some View {
        let total = min(max(enabledCount, 0), 12)
        let green = enabledCount == 0 ? 0 : max(
            holderCount > 0 ? 1 : 0,
            Int((Double(holderCount) / Double(enabledCount) * Double(total)).rounded())
        )
        return LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(13), spacing: 3), count: 6),
            spacing: 4
        ) {
            ForEach(0..<total, id: \.self) { index in
                Image(systemName: "person.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(index < green ? Color.accent : Color.textSecondary.opacity(0.4))
            }
        }
        .fixedSize()
        // Una única animación de entrada por rejilla: el escalonado por elemento
        // (decenas de springs con retardo) se re-disparaba en cada scroll al tope.
        .appear(index: 1)
        .accessibilityHidden(true)
    }

    /// Un punto por territorio en uso; el color cuenta la historia de urgencia
    /// de un vistazo sin necesidad de leyenda.
    private var dotGrid: some View {
        let maxRows = 4
        let columns = 6
        let maxItems = maxRows * columns
        let hasOverflow = assignmentDays.count > maxItems
        let visibleDays = Array(assignmentDays.prefix(hasOverflow ? maxItems - 1 : maxItems))

        return HStack(alignment: .center, spacing: AppSpacing.xs) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(9), spacing: 5), count: columns),
                spacing: 5
            ) {
                ForEach(Array(visibleDays.enumerated()), id: \.offset) { _, days in
                    Circle()
                        .fill(Color.urgency(forDays: days))
                        .frame(width: 7, height: 7)
                }
            }
            .fixedSize()

            if hasOverflow {
                Text("+\(assignmentDays.count - visibleDays.count)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(Color.surfaceRaised.opacity(0.78), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.hairline, lineWidth: 1))
            }
        }
        .appear(index: 2)
        .accessibilityHidden(true)
    }
}

// MARK: Tarjeta de hermano

/// Fila-tarjeta compacta: avatar + nombre y, según el estado, botón Entregar
/// (activo sin territorios), contador de territorios + ruta expandible
/// (con territorios) o distintivo "Inactivo".
struct BrotherCard: View {
    let person: Person
    var isExpanded: Bool = false
    var onToggle: (() -> Void)? = nil
    var onGive: (() -> Void)? = nil
    var geometry: (Int) -> TerritoryMapGeometry? = { _ in nil }
    var imageURL: (Int) -> String? = { _ in nil }
    var onOpenTerritory: ((TerritoryInUse) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var territories: [TerritoryInUse] {
        (person.territoriesInUse ?? []).sorted { $0.givenDate < $1.givenDate }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                primaryTap()
            } label: {
                header
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded && !territories.isEmpty {
                AssignedTerritoriesPanel(
                    territories: territories,
                    geometry: geometry,
                    imageURL: imageURL,
                    onOpen: { onOpenTerritory?($0) }
                )
                .padding(.horizontal, AppSpacing.sm)
                .padding(.bottom, AppSpacing.sm)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .scale(scale: 0.995, anchor: .top))
                )
            }
        }
        .paperCard(cornerRadius: AppRadius.lg)
        .opacity(person.enabled ? 1 : 0.72)
    }

    private func primaryTap() {
        if person.hasActiveTerritory {
            HapticManager.shared.impact(style: .light)
            withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.34, dampingFraction: 0.84)) {
                onToggle?()
            }
        } else if person.enabled {
            onGive?()
        }
    }

    private var header: some View {
        HStack(spacing: AppSpacing.sm) {
            InitialsAvatar(name: person.name, size: 40, tint: person.avatarTint)

            Text(person.name)
                .font(.appHeadline())
                .foregroundStyle(person.enabled ? Color.textPrimary : Color.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.88)

            Spacer(minLength: AppSpacing.xs)

            trailing
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if !person.enabled {
            inactiveBadge
        } else if territories.isEmpty {
            giveButton
        } else {
            HStack(spacing: AppSpacing.xs) {
                territoryCountBadge
                chevron
            }
        }
    }

    private var inactiveBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "slash.circle.fill")
                .font(.caption2.weight(.bold))
            Text("brothers.status.inactive")
                .font(.appCaption().weight(.semibold))
        }
        .foregroundStyle(Color.textSecondary)
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, 4)
        .background(Color.textSecondary.opacity(0.1), in: Capsule())
    }

    private var giveButton: some View {
        Button {
            onGive?()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "paperplane.fill")
                    .font(.caption.weight(.bold))
                Text("brothers.give")
                    .font(.appSubheadline().weight(.semibold))
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 7)
        }
        .buttonStyle(.glassProminent)
        .tint(.accent)
        .controlSize(.regular)
        .accessibilityLabel(Text("brothers.give_to \(person.name)"))
    }

    /// Nº de territorios en uso, teñido por la asignación más antigua.
    /// El detalle (códigos, días, ruta) solo aparece al desplegar.
    private var territoryCountBadge: some View {
        let tint = Color.urgency(forDays: person.maxDaysHeld ?? 0)
        return HStack(spacing: 4) {
            Image(systemName: "map.fill")
                .font(.system(size: 10, weight: .bold))
            Text("\(territories.count)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, 4)
        .background(tint.opacity(0.13), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.25), lineWidth: 1))
        .accessibilityLabel(Text("brothers.territories_assigned"))
        .accessibilityValue(Text("\(territories.count)"))
    }

    private var chevron: some View {
        Image(systemName: "chevron.down")
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.textSecondary)
            .rotationEffect(.degrees(isExpanded ? -180 : 0))
            .animation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.28, dampingFraction: 0.78), value: isExpanded)
    }
}

// MARK: Panel de territorios asignados

/// Panel expandido: una mini-tarjeta por territorio con la preview cacheada del
/// mapa, código, nombre, fecha de entrega y días en poder.
/// Cada tarjeta navega al detalle del territorio.
struct AssignedTerritoriesPanel: View {
    let territories: [TerritoryInUse]
    let geometry: (Int) -> TerritoryMapGeometry?
    let imageURL: (Int) -> String?
    let onOpen: (TerritoryInUse) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            ForEach(territories, id: \.territoryId) { territory in
                Button {
                    HapticManager.shared.selection()
                    onOpen(territory)
                } label: {
                    row(territory)
                        .contentShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
                .transition(
                    reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .scale(scale: 0.995, anchor: .top))
                )
                .animation(
                    reduceMotion
                        ? .easeOut(duration: 0.12)
                        : .spring(response: 0.3, dampingFraction: 0.86),
                    value: territories.map(\.territoryId)
                )
                .accessibilityElement(children: .combine)
                .accessibilityHint(Text("brothers.territory.open_hint"))
            }
        }
    }

    private func row(_ territory: TerritoryInUse) -> some View {
        let days = territory.daysHeld()
        let tint = Color.urgency(forDays: days)
        return HStack(spacing: AppSpacing.sm) {
            TerritoryAssignedMapPreview(
                imageURL: imageURL(territory.territoryId),
                geometry: geometry(territory.territoryId),
                tint: tint
            )
            .frame(width: 72, height: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text(territory.territoryCode)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.accentDeep)

                Text(territory.territoryName)
                    .font(.appSubheadline())
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 9, weight: .semibold))
                    Text(territory.givenDate, style: .date)
                        .font(.caption2)
                }
                .foregroundStyle(Color.textSecondary)
            }

            Spacer(minLength: AppSpacing.xs)

            HStack(spacing: 6) {
                Text(String(format: String.localized("brothers.days_format"), days))
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, 4)
                    .background(tint.opacity(0.13), in: Capsule())

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(AppSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(Color.appBackground.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .strokeBorder(Color.hairline, lineWidth: 1)
        )
    }
}

private struct TerritoryAssignedMapPreview: View {
    let imageURL: String?
    let geometry: TerritoryMapGeometry?
    let tint: Color

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
    }

    var body: some View {
        ZStack {
            if let url = imageURL.flatMap(URL.init(string:)) {
                CachedAsyncImage(
                    url: url,
                    content: { image in
                        image
                            .resizable()
                            .scaledToFill()
                    },
                    placeholder: {
                        fallback
                            .overlay(ProgressView().controlSize(.small))
                    },
                    errorView: {
                        fallback
                    }
                )
            } else {
                fallback
            }
        }
        .clipShape(shape)
        .overlay(
            shape
                .stroke(tint.opacity(0.28), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var fallback: some View {
        if let geometry {
            TerritorySnapshotBackdrop(
                geometry: geometry,
                stroke: tint,
                fill: tint,
                centersTerritory: true
            )
        } else {
            Color.secondary.opacity(0.1)
                .overlay(
                    Image(systemName: "map.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.textSecondary.opacity(0.35))
                )
        }
    }
}
