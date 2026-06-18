# TerritoryTool iOS — Arquitectura

> Cómo está organizada la app y las convenciones a seguir. Complementa a `DESIGN_GUIDE.md`.

---

## 1. Patrón general: MVVM + Servicios

```
View (SwiftUI)  ──►  ViewModel (@MainActor, ObservableObject)  ──►  Service (Network/Auth)  ──►  Modelo (Codable)
   ▲                         │
   └──── @Published state ───┘
```

- **View**: solo presentación y enlace de estado. Sin lógica de negocio ni llamadas de red directas. Sin estado de UI propio en el ViewModel que la vista pueda manejar localmente (`@State`).
- **ViewModel**: `@MainActor final class … : ObservableObject`. Expone `@Published` y métodos `async`. Orquesta servicios. Una instancia por pantalla, creada vía `DIContainer`.
- **Service**: capa de red/auth/transformación. No conoce SwiftUI.
- **Modelo**: structs `Codable` en `Shared/Models/`.

---

## 2. Estructura de carpetas

```
TerritoryTool/
├── Core/                  Infraestructura transversal
│   ├── Config/            AppConfig (URLs, entornos)
│   ├── Network/           NetworkManager, APIEndpoint, TokenManager, Auth
│   ├── DI/                DIContainer (factorías de ViewModels)
│   ├── AppViewModel.swift Estado raíz de autenticación
│   ├── CongregationStore  Multi-congregación
│   ├── ThemeManager / LanguageManager / HapticManager
│   └── Extensions/
├── DesignSystem/
│   ├── Tokens/            Colors, Typography, Spacing, Radius, Elevation  ← fuente única
│   └── Components/        Primitivas UI (AppCard, AppTextField, botones…)
├── Features/<Feature>/
│   ├── Views/             Pantallas y subvistas
│   ├── ViewModels/
│   └── Models/            (si son específicos del feature)
├── Shared/
│   ├── Models/            Modelos de dominio (Territory, Person, Transaction, User, ActionLog)
│   ├── Components/         Componentes de dominio reutilizables
│   ├── Utils/             JWTHelper, PermissionManager
│   └── Extensions/
└── Resources/             Assets.xcassets, en.lproj, es.lproj
```

**Regla de dependencias**: `Features` puede usar `Core`, `DesignSystem`, `Shared`. `Shared`/`DesignSystem`/`Core` no dependen de `Features`.

---

## 3. Inyección de dependencias

`DIContainer.shared` es la única factoría de ViewModels. Las vistas piden su ViewModel al contenedor; no instancian servicios.

```swift
DashboardView(viewModel: DIContainer.shared.makeDashboardViewModel())
```

Esto permite sustituir `NetworkManager` por `MockAPIService` en tests.

---

## 4. Estado y ViewModels

### Base común (objetivo del refactor)
Todos los ViewModels comparten `isLoading` / `errorMessage` y el patrón de ejecución async. Centralizar en un helper para no repetir:

```swift
@MainActor
class BaseViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    func run(_ operation: @escaping () async throws -> Void) async {
        isLoading = true; errorMessage = nil
        do { try await operation() }
        catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
}
```

### Reglas
- Estado **de UI puro** (mostrar sheet, fila expandida) vive en la `View` con `@State`, no en el ViewModel.
- `@StateObject` para el ViewModel propietario de la vista; `@ObservedObject` si se inyecta desde fuera.
- Objetos de app compartidos como `@EnvironmentObject`: `PermissionManager`, `ThemeManager`, `LanguageManager`, `CongregationStore`.

---

## 5. Networking

- **Async/await** en todo. Errores como `NetworkError` (enum localizado).
- Autenticación Bearer; el `401` dispara expiración de sesión.
- **Objetivo de refactor**: `NetworkManager` (≈500 líneas) se trocea en:
  - `RESTClient` / `RPCClient` — transporte.
  - `DataTransformers` — mapeo de filas → modelos (territorios, transacciones, estadísticas), con coerción de nulos centralizada.
  - `ImageService` — firma/caché de URLs de imágenes.
- Reglas: validar campos requeridos al mapear y **loggear** filas descartadas (no silenciar). Evitar defaults silenciosos como `id ?? 0`.

---

## 6. Autenticación, JWT y permisos

- **Tokens**: gestionados por `TokenManager`. Objetivo: almacenarlos en **Keychain** (no `UserDefaults`).
- **JWT**: `JWTHelper` decodifica claims (`role`, `congregation_id`, `is_superadmin`). Decodificación robusta (padding base64, manejo de error, sin crashes con tokens malformados).
- **Permisos**: `PermissionManager` es la **única fuente de verdad** de roles/capacidades:
  - `isAdminOrHigher`, `canManageTerritories/Brothers/Users`, `canViewActionLogs`, `canManageCongregations`.
  - **Cachear** el rol tras el primer parse e invalidar en `.authChanged` (no re-parsear el JWT en cada acceso).
  - Las vistas y ViewModels consultan `PermissionManager`; **no** reimplementan checks de rol.

---

## 7. Multi-congregación (multi-tenant)

- El tenant activo viaja en el claim `congregation_id` del JWT; el backend aplica RLS.
- `CongregationStore` mantiene las congregaciones accesibles y la activa.
- Cambiar de congregación → RPC backend → refresco de token (nuevo claim) → recarga de datos.
- **Objetivo**: `CongregationStore` como `@EnvironmentObject`; el cambio dispara recarga automática de las vistas afectadas (en lugar de suscripción manual a `.congregationChanged`).

---

## 8. Sincronización de estado

Hoy se usa `NotificationCenter` (`.authChanged`, `.congregationChanged`, borrado de territorio…). Es frágil. Direcciones:
- Preferir estado observable (`@Published` en stores `@EnvironmentObject`) frente a notificaciones sueltas.
- Si se mantiene `NotificationCenter`, centralizar los nombres en un único sitio y limpiar observers.

---

## 9. Convenciones

- **Naming**: `XxxView`, `XxxViewModel`, `XxxService`, `XxxStore`. Componentes reutilizables con prefijo `App*` (`AppCard`, `AppTextField`).
- **Un tipo por archivo** (salvo subvistas privadas pequeñas de una pantalla).
- **Archivos grandes** (>250 líneas) se trocean en subvistas/extensiones.
- **Concurrencia**: ViewModels `@MainActor`; trabajo pesado en `Task`/`async`.
- **Tests**: target `TerritoryToolTests`, inyectando `MockAPIService`.

---

## 10. Deuda técnica priorizada (ver plan, Fase 3)

1. `BaseViewModel` + `LoadingErrorStateView` (elimina boilerplate).
2. Trocear `NetworkManager`.
3. Cachear JWT/permisos; endurecer `JWTHelper`.
4. Tokens a Keychain.
5. `CongregationStore` reactivo (`@EnvironmentObject`).
6. Localización con seguridad de tipos.
7. Extraer números mágicos a constantes.
8. Tests de ViewModels, JWT y decoding.
