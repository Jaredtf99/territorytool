import SwiftUI

// MARK: - Piezas del flujo de Acción rápida.
// Aquí los territorios se muestran COMPACTOS (no la tarjeta grande del listado):
// solo código, nombre y una línea de estado. Conservan la identidad visual usando
// `TerritoryStatusPresentation` para color e icono, igual que el resto de la app.

/// Accesorio a la derecha de una fila compacta.
enum CompactRowAccessory: Equatable {
    case chevron
    case selection(Bool)
    case none
}

/// Fila de territorio compacta: icono de estado + código + nombre + línea de estado.
struct CompactTerritoryRow: View {
    let territory: Territory
    var accessory: CompactRowAccessory = .chevron

    private var status: TerritoryStatusPresentation {
        TerritoryStatusPresentation(territory.operationalStatus())
    }

    private var detail: String {
        switch territory.operationalStatus() {
        case .available:
            if let days = territory.daysFree() {
                return String(format: String.localized("quick_action.free_since"), days)
            }
            return String.localized("territory.status.available")
        case .assigned(let days), .attention(let days):
            return String(format: String.localized("quick_action.assigned_days"), territory.personName ?? "", days)
        }
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            TerritoryStatusIcon(presentation: status, size: .regular)
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AppSpacing.xs) {
                    Text(territory.code)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(status.color)
                    Text(territory.name)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                }
                Text(detail)
                    .font(.appCaption())
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: AppSpacing.xs)

            accessoryView
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.sm)
        .background(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous).fill(Color.surface))
        .overlay(rowBorder)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.textSecondary)
        case .selection(let on):
            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(on ? Color.accent : Color.textSecondary.opacity(0.4))
        case .none:
            EmptyView()
        }
    }

    private var isSelected: Bool {
        if case .selection(true) = accessory { return true }
        return false
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
            .strokeBorder(isSelected ? Color.accent : Color.hairline, lineWidth: isSelected ? 1.5 : 1)
    }
}

/// Fila de persona compacta: avatar + nombre + estado operativo.
struct PersonQuickRow: View {
    let person: Person
    var accessory: CompactRowAccessory = .chevron

    private var tint: Color { person.hasActiveTerritory ? .accentSecondary : .accent }

    private var subtitle: String {
        if let active = person.primaryActiveTerritory {
            if person.activeTerritoryCount > 1 {
                return String(format: String.localized("quick_action.person_territory_count"), person.activeTerritoryCount)
            }
            return String(format: String.localized("quick_action.has_territory"), active.territoryCode)
        }
        return String.localized("quick_action.person_no_territory")
    }

    private var isSelected: Bool {
        if case .selection(true) = accessory { return true }
        return false
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            InitialsAvatar(name: person.name, size: 38, tint: tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.appCaption())
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: AppSpacing.xs)

            switch accessory {
            case .chevron:
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Color.textSecondary)
            case .selection(let on):
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(on ? Color.accent : Color.textSecondary.opacity(0.4))
            case .none:
                EmptyView()
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.sm)
        .background(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous).fill(Color.surface))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .strokeBorder(isSelected ? Color.accent : Color.hairline, lineWidth: isSelected ? 1.5 : 1)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Barra de búsqueda inferior (cristal a ancho completo, tipo tab bar)

/// Barra de búsqueda anclada abajo, reutilizada por el hub y los selectores.
struct QuickActionSearchBar: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var focus: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.appBody())
                .foregroundStyle(Color.textPrimary)
                .focused(focus)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button {
                    text = ""
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
        // Sin `.interactive()`: el cristal interactivo se "comía" el toque del botón de
        // limpiar. `contentShape` evita que el toque se cuele a la fila de debajo.
        .contentShape(Capsule())
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.bottom, AppSpacing.xs)
    }
}
