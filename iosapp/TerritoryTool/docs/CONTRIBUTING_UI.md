# TerritoryTool iOS — Cómo añadir o editar una pantalla

> Checklist práctico para mantener la app consistente. Léelo junto a `DESIGN_GUIDE.md` y `ARCHITECTURE.md`.

---

## Flujo para una pantalla nueva

1. **Ubícala** en `Features/<Feature>/Views/`. Su ViewModel en `Features/<Feature>/ViewModels/`.
2. **Crea el ViewModel** heredando de `BaseViewModel` (`isLoading`/`errorMessage`/`run`). Pide servicios por inyección; añade una factoría en `DIContainer`.
3. **Construye la vista** con controles y materiales nativos. Envuelve en el `NavigationStack` del tab correspondiente (no crees stacks anidados).
4. **Usa tokens** para todo: `Color.accent`, `font(.appHeadline)`, `AppSpacing.md`, `AppRadius.lg`. Cero literales.
5. **Estados** de carga / vacío / error con `LoadingErrorStateView`.
6. **Localiza** todo texto en `en.lproj` y `es.lproj`.
7. **Accesibilidad**: labels en iconos-botón, prueba en Dynamic Type AX5, respeta Reduce Motion.
8. **Permisos**: gatea acciones con `PermissionManager` (`if permissionManager.canManageTerritories { … }`).
9. **Preview** en claro y oscuro.

---

## Checklist de revisión (copiar en el PR)

```
[ ] Solo tokens (sin Color.blue/red, sin .system(size:), sin paddings literales sueltos)
[ ] Materiales/controles nativos (sin .ultraThinMaterial casero, sin glassCardStyle)
[ ] Navegación: dentro del NavigationStack del tab; ≤5 tabs respetado
[ ] LoadingErrorStateView para carga/vacío/error
[ ] Textos localizados es/en (sin literales)
[ ] accessibilityLabel en iconos-botón; probado en Dynamic Type AX5
[ ] Estado solo-de-UI en @State de la vista, no en el ViewModel
[ ] Permisos vía PermissionManager (sin parsear JWT ni duplicar checks de rol)
[ ] Acciones destructivas con confirmación (.alert/.confirmationDialog)
[ ] #Preview en claro y oscuro
[ ] ViewModel testeable (servicios inyectados; sin singletons ocultos)
```

---

## Snippets de referencia

### Tarjeta
```swift
AppCard {
    HStack(spacing: AppSpacing.md) { /* … */ }
}
```

### Botón primario con carga
```swift
Button { Task { await vm.save() } } label: {
    if vm.isLoading { ProgressView() } else { Text("common.save") }
}
.buttonStyle(.borderedProminent)
.tint(.accent)
.disabled(vm.isLoading)
```

### Estado de pantalla
```swift
LoadingErrorStateView(
    isLoading: vm.isLoading,
    error: vm.errorMessage,
    isEmpty: vm.items.isEmpty,
    emptyText: "feature.empty",
    retry: { await vm.load() }
) {
    List(vm.items) { item in Row(item) }
}
.task { await vm.load() }
```

### Acción destructiva
```swift
.swipeActions(edge: .trailing) {
    if permissionManager.canManageTerritories {
        Button(role: .destructive) { itemToDelete = item } label: {
            Label("common.delete", systemImage: "trash")
        }
    }
}
.alert("common.delete_confirmation", isPresented: $showDelete, presenting: itemToDelete) { item in
    Button("common.delete", role: .destructive) { Task { await vm.delete(item) } }
    Button("common.cancel", role: .cancel) {}
}
```

### Preview claro/oscuro
```swift
#Preview("Claro") { MyView(viewModel: .preview) }
#Preview("Oscuro") { MyView(viewModel: .preview).preferredColorScheme(.dark) }
```

---

## Errores comunes a evitar

- Reimplementar cristal con `.ultraThinMaterial` + borde + sombra → usar `AppCard` / `.glassEffect`.
- Colores de marca con `Color.blue`/`Color.red` → usar tokens semánticos.
- Pesos `.thin`/`.light` en títulos → ilegibles; usar tokens tipográficos.
- Estado de sheets/expansión en el ViewModel → debe ir en `@State` de la vista.
- Re-parsear el JWT para saber el rol → usar `PermissionManager`.
- Añadir un tab nuevo → la app tiene 5 fijos; usa acción contextual o entrada en Ajustes.
