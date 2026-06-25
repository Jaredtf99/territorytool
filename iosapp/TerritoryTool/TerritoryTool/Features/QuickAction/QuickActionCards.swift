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

/// Avatar de iniciales canónico (mismo estilo que `TerritoryListAvatar`).
struct QAInitialsAvatar: View {
    let name: String
    var size: CGFloat = 38
    var tint: Color = .accent

    private var initials: String {
        name.split(separator: " ").prefix(2)
            .compactMap(\.first).map(String.init).joined().uppercased()
    }

    var body: some View {
        Text(initials.isEmpty ? "?" : initials)
            .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
            .foregroundStyle(Color.textPrimary)
            .frame(width: size, height: size)
            .background(tint.opacity(0.13), in: Circle())
            .overlay(Circle().strokeBorder(tint.opacity(0.28), lineWidth: 1))
            .accessibilityHidden(true)
    }
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
            Image(systemName: status.icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(status.color)
                .frame(width: 38, height: 38)
                .background(status.color.opacity(0.14), in: Circle())
                .overlay(Circle().strokeBorder(status.color.opacity(0.24), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AppSpacing.xs) {
                    Text(territory.code)
                        .font(.subheadline.weight(.bold).monospaced())
                        .foregroundStyle(status.color)
                    Text(territory.name)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)
                }
                Text(detail)
                    .font(.caption)
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
            QAInitialsAvatar(name: person.name, size: 38, tint: tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
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
