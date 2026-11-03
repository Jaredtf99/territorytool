# TerritoryTool — Android

Port nativo (Kotlin + Jetpack Compose) de la app de iOS (`iosapp/`). Usa el mismo backend de
Supabase (PostgREST, RPC, edge functions y Storage), así que no requiere cambios en el servidor.

## Compilar

Requisitos: JDK 17 y Android SDK (platform 35, build-tools 35). Crea `local.properties` con
`sdk.dir=/ruta/al/sdk` (o ábrelo en Android Studio, que lo genera solo).

```sh
./gradlew :app:assembleDebug        # APK de depuración
./gradlew :app:testDebugUnitTest    # pruebas unitarias
./gradlew :app:assembleRelease      # APK firmado para distribuir a mano (requiere firma)
./gradlew :app:bundleRelease        # AAB para Play Store (requiere firma)
```

La firma de release se lee de `keystore.properties` (ignorado por git), con las claves `storeFile`,
`storePassword`, `keyAlias` y `keyPassword`. Sin ese archivo, el build de release sale sin firmar.

## Correspondencia con iOS

| iOS | Android |
|---|---|
| SwiftUI + `ObservableObject` | Compose + `ViewModel`/`StateFlow` |
| `NavigationStack` por pestaña | `core/navigation/Navigator` (pila por pestaña) |
| `NotificationCenter` | `core/AppEvents` (SharedFlow) |
| `UserDefaults` (sesión) | `EncryptedSharedPreferences` (Keystore) |
| BackgroundTasks (refresco de token) | WorkManager (`TokenRefreshWorker`) |
| MapKit + `MKMapSnapshotter` | MapLibre + `MapSnapshotter` (teselas de OpenFreeMap, sin API key) |
| AVFoundation (QR) | CameraX + ML Kit Barcode |
| PDFKit / `UIGraphicsPDFRenderer` | `android.graphics.pdf.PdfDocument` + `PdfRenderer` |
| Swift Charts | Canvas propio (curva monótona) |
| SF Pro Rounded | Nunito (variable, `res/font`) |
| `Localizable.strings` | `res/values{,-es}/strings.xml` (generados con `scripts/convert_strings.py`) |

Las claves de iOS (`dashboard.title`) pasan a `dashboard_title`. Para añadir textos, edita los
`Localizable.strings` de iOS y vuelve a ejecutar `python3 scripts/convert_strings.py`; los textos
exclusivos de Android van en `strings_android.xml`.
