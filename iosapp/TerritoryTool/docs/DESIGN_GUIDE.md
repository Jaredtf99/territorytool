# TerritoryTool iOS — Guía de Diseño

> Guía maestra del sistema de diseño. Toda pantalla nueva o modificada debe seguir este documento.
> Dirección visual: **Liquid Glass nativo de iOS 26**. Target de despliegue: iOS 26.0+.

---

## 1. Principios

1. **Nativo primero.** Usar los materiales, controles y navegación que da el sistema (`.glassEffect`, `TabView`, `NavigationStack`, `Form`, `.searchable`, `List`). No reimplementar cristal, sombras ni fondos a mano.
2. **Tokens, no valores mágicos.** Ningún color, espaciado, radio o fuente hardcodeado en una vista. Todo sale de `DesignSystem/Tokens/`.
3. **Claridad sobre decoración.** La jerarquía la marca la tipografía y el espacio, no los bordes ni los degradados.
4. **Accesible por defecto.** Dynamic Type, `accessibilityLabel`, contraste y *Reduce Motion* no son opcionales.
5. **Consistencia entre pantallas.** Mismo patrón para cargar, vaciar y errar. Mismo patrón para acciones destructivas (swipe + confirmación).
6. **Localizable siempre.** Todo texto visible pasa por `Localizable.strings` (es/en). Nunca strings literales en la UI.

---

## 2. Color

Los colores se definen como **Color Sets en `Assets.xcassets`** (con variante Any/Light + Dark) y se exponen tipados desde `DesignSystem/Tokens/Colors.swift`. El acento tiñe el Liquid Glass nativo.

### Paleta

| Token | Light | Dark | Uso |
|-------|-------|------|-----|
| `accent` (Primary) | `#0F8A8A` | `#2DD4BF` | Acción principal, tinte de glass, enlaces, selección |
| `secondary` | `#4F46E5` | `#818CF8` | Acentos puntuales, badges secundarios |
| `success` | `#16A34A` | `#22C55E` | Confirmaciones, estado "devuelto/OK" |
| `warning` | `#D97706` | `#F59E0B` | Avisos, "necesita atención" |
| `danger` | `#DC2626` | `#F87171` | Destructivo, errores, días vencidos |
| `info` | `#2563EB` | `#60A5FA` | Información neutra |

### Neutros (usar SIEMPRE los del sistema, adaptan claro/oscuro y accesibilidad)

- Fondos: `Color(.systemBackground)`, `Color(.secondarySystemBackground)`, `Color(.systemGroupedBackground)`.
- Texto: `Color(.label)`, `Color(.secondaryLabel)`, `Color(.tertiaryLabel)`.
- Separadores: `Color(.separator)`.

### Reglas

- **No** usar `Color.blue`, `Color.red`, `Color.green` directos. Usar `accent`, `danger`, `success`…
- El color nunca es el único portador de información: acompañar de icono o texto (p. ej. estado de territorio).
- En Liquid Glass, dejar que el material aporte el fondo translúcido; aplicar tinte con `.tint(.accent)`.

```swift
// ❌ Antes
.foregroundColor(.blue)
.background(Color.red.opacity(0.1))

// ✅ Después
.foregroundColor(.accent)
.background(Color.danger.opacity(0.12))
```

---

## 3. Tipografía

Mapear a los **text styles del sistema** (soportan Dynamic Type) con `design: .rounded` como rasgo distintivo de la app. Definido en `DesignSystem/Tokens/Typography.swift`.

| Token | Estilo base | Peso | Uso |
|-------|-------------|------|-----|
| `.appLargeTitle()` | `.largeTitle` | `.bold` | Títulos de pantalla grandes |
| `.appTitle()` | `.title2` | `.semibold` | Cabeceras de sección destacadas |
| `.appHeadline()` | `.headline` | `.semibold` | Títulos de tarjeta/fila |
| `.appBody()` | `.body` | `.regular` | Texto principal |
| `.appSubheadline()` | `.subheadline` | `.medium` | Metadatos, etiquetas |
| `.appCaption()` | `.caption` | `.regular` | Texto auxiliar, fechas |

> Nota: los tokens tipográficos se exponen como **funciones** (`.font(.appHeadline())`) para coincidir con la API existente del proyecto.

### Reglas

- **Prohibidos** los pesos `.thin` / `.light` en títulos (poco legibles, mal contraste).
- Nunca tamaños fijos (`.system(size: 34)`); usar el token, que escala con Dynamic Type.
- `lineLimit` + `.minimumScaleFactor(0.8)` en textos que puedan truncar (nombres, códigos).

```swift
Text("territories.title").font(.appHeadline())   // ✅
Text("…").font(.system(size: 24, weight: .light)) // ❌
```

---

## 4. Espaciado y forma

Escala base 8pt. Definido en `DesignSystem/Tokens/Spacing.swift` y `Radius.swift`.

### Spacing (`AppSpacing`)
`xxs = 4` · `xs = 8` · `sm = 12` · `md = 16` · `lg = 24` · `xl = 32`

- Padding interno de tarjetas/filas: `md` (16).
- Separación entre elementos de un grupo: `xs`/`sm`.
- Separación entre secciones: `lg`.
- Márgenes laterales de pantalla: `md` (16).

### Radius (`AppRadius`)
`sm = 8` · `md = 12` · `lg = 16` · `xl = 20`

- Tarjetas: `lg` (16). Hojas/contenedores grandes: `xl` (20). Badges/chips: `Capsule` o `sm`.

### Sombras
En Liquid Glass la elevación la aporta el material. **Minimizar sombras manuales.** Si hace falta, usar el token `AppElevation.card` (un único nivel sutil), nunca valores sueltos.

---

## 5. Componentes

Ubicación: primitivas en `DesignSystem/Components/`, componentes de dominio en `Shared/Components/`.

| Componente | Sustituye a | Notas |
|------------|-------------|-------|
| `AppCard` | `GlassCard` / `glassCardStyle` | Wrapper fino sobre `.glassEffect(in: .rect(cornerRadius: AppRadius.lg))`. Padding `md`. |
| Botón primario | `PrimaryButton` / `GlassButton` | `.buttonStyle(.glassProminent)` o `.borderedProminent` con `.tint(.accent)`. Estado loading con `ProgressView`. |
| Botón secundario | — | `.buttonStyle(.glass)` / `.bordered`. |
| `AppTextField` | `GlassTextField` | Campo con label opcional; estilo nativo. |
| `LoadingErrorStateView` | bloques repetidos en cada vista | Estado unificado de carga / vacío / error con reintento. |
| `StatusBadge`, `PersonBadge`, `TerritoryCodeBadge` | (re-tokenizar) | Conservar API, migrar a tokens. |

### Patrón de tarjeta

```swift
AppCard {
    HStack(spacing: AppSpacing.md) {
        // contenido
    }
}
```

### Patrón de estado (carga / vacío / error)

Toda vista que carga datos usa `LoadingErrorStateView` para no repetir lógica:

```swift
LoadingErrorStateView(
    isLoading: vm.isLoading,
    error: vm.errorMessage,
    isEmpty: vm.items.isEmpty,
    emptyText: "territories.empty",
    retry: { await vm.load() }
) {
    // contenido cuando hay datos
}
```

---

## 6. Navegación

**5 tabs máximo** (iOS oculta el resto en "More" y rompe la jerarquía). Estructura oficial:

| # | Tab | Icono SF Symbol | Visible para |
|---|-----|------------------|--------------|
| 1 | Inicio | `house.fill` | Todos |
| 2 | Territorios | `map.fill` | Todos |
| 3 | Hermanos | `person.3.fill` | Todos |
| 4 | Registros | `list.bullet.clipboard` | SUPERADMIN |
| 5 | Ajustes | `gearshape.fill` | Todos |

- **Asignar / Devolver**: ya no son tabs. Son acciones contextuales desde el **detalle de territorio** y desde el botón **(+)** de la lista de Territorios (hoja modal).
- **Usuarios**: entra como fila en **Ajustes → Administración** (ADMIN+), no como tab.
- Cada tab se envuelve en su propio `NavigationStack` (sin excepciones — corregir el patrón previo de Brothers/Users sin stack).
- Drill-down con `NavigationLink`; acciones de crear/editar con `.sheet`; confirmaciones destructivas con `.alert` o `.confirmationDialog`.
- Toolbar: usar `.toolbar { ToolbarItem(...) }` nativo. El switcher de congregación va en `.topBarLeading`.

---

## 7. Accesibilidad (obligatorio)

- **Dynamic Type**: usar tokens tipográficos; probar en tamaño `AX5`. Nada de tamaños fijos.
- **Etiquetas**: `accessibilityLabel` en iconos-botón y badges; `accessibilityHint` donde la acción no sea obvia.
- **Agrupar**: `accessibilityElement(children: .combine)` en filas/tarjetas complejas.
- **Color + texto/icono**: el estado nunca depende solo del color.
- **Reduce Motion**: animaciones decorativas envueltas en
  ```swift
  @Environment(\.accessibilityReduceMotion) var reduceMotion
  withAnimation(reduceMotion ? nil : .spring()) { … }
  ```
- **Contraste**: validar accent sobre fondos claros/oscuros (objetivo WCAG AA).

---

## 8. Localización

- Todo texto visible → clave en `Resources/{en,es}.lproj/Localizable.strings`.
- En SwiftUI usar `Text("clave")` (LocalizedStringKey) o `String(localized:)`.
- Jerarquía de claves por feature: `dashboard.*`, `territories.*`, `common.*`.
- Pluralización con `%d` y, si crece, *stringsdict*.
- **Cero strings literales** en vistas (revisar restos como `"Retry"`).

---

## 9. Do / Don't (resumen)

| ✅ Hacer | ❌ Evitar |
|----------|-----------|
| `.glassEffect(in:)` nativo | `.ultraThinMaterial` + borde + sombra a mano |
| `Color.accent`, `Color.danger` | `Color.blue`, `Color.red` |
| `font(.appHeadline())` | `.system(size: 24, weight: .light)` |
| `AppSpacing.md` | `.padding(16)` literal repetido |
| `LoadingErrorStateView` | copiar bloques `if isLoading … else if error …` |
| 5 tabs + acciones contextuales | 7 tabs cayendo en "More" |
| `#Preview` en claro y oscuro | vistas sin preview |

---

## 10. Checklist por pantalla

Antes de dar por terminada una pantalla:

- [ ] Sin colores/espaciados/fuentes hardcodeados (solo tokens).
- [ ] Materiales y controles nativos (sin glass casero).
- [ ] Estados de carga / vacío / error con `LoadingErrorStateView`.
- [ ] Textos localizados (es/en).
- [ ] `accessibilityLabel` en iconos-botón; probada en Dynamic Type AX5.
- [ ] Acciones destructivas con confirmación.
- [ ] `#Preview` en claro y oscuro.
- [ ] Permisos aplicados vía `PermissionManager` (no lógica de rol duplicada).

Ver también: `ARCHITECTURE.md` y `CONTRIBUTING_UI.md`.
