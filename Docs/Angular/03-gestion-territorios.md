# Gestión de Territorios

## 1. Agregar Territorio (AddTerritoryComponent)

**Ruta:** `/add-territory`  
**Archivo:** `src/app/components/add-territory/add-territory.component.ts`  
**Permisos:** SUPERADMIN y ADMIN

### Descripción
Pantalla para dar de alta nuevos territorios en el sistema. Permite escanear códigos QR o ingresar datos manualmente.

### Funcionalidad Principal
- Crear nuevos territorios en el sistema
- Escaneo de códigos QR para obtener URL del mapa
- Validación de datos únicos (código, nombre, URL)
- Gestión de errores específicos

### Campos del Formulario

#### **code** (Código)
- Identificador único del territorio
- Requerido
- Debe ser único en el sistema
- Ejemplo: "T-001", "CENTRO-A"

#### **name** (Nombre)
- Nombre descriptivo del territorio
- Requerido
- Debe ser único en el sistema
- Ejemplo: "Centro Comercial Norte"

#### **mapUrl** (URL del Mapa)
- URL del mapa del territorio (Google Maps, etc.)
- Requerido
- Puede obtenerse escaneando código QR
- Debe ser única en el sistema

### Funciones Principales

#### `addTerritory()`
Guarda el nuevo territorio:
```typescript
Parámetros:
- mapUrl: string
- name: string
- code: string

Flujo:
1. Valida que el formulario sea válido
2. Muestra spinner de carga
3. Envía petición al servidor
4. Si éxito: resetea formulario y muestra mensaje
5. Si error: muestra error específico
```

#### Scanner de QR

**`startQrScanner()`**
Inicia el escáner de códigos QR:
- Activa la cámara del dispositivo
- Prioriza cámara trasera (rear/back) si está disponible
- Utiliza la librería `ngx-scanner-qrcode`

**`stopQrScanner()`**
Detiene el escáner de códigos QR:
- Se ejecuta al cerrar el modal
- Libera recursos de la cámara

**`onEvent(e: ScannerQRCodeResult[])`**
Procesa el resultado del escaneo:
- Extrae la URL del código QR
- La asigna automáticamente al campo `mapUrl`
- Cierra el modal del scanner

### Validaciones y Errores

#### `handleAddError(err)`
Gestiona los errores específicos del servidor:

| Error | Campo Afectado | Mensaje |
|-------|----------------|---------|
| `CODE_EXIST` | code | El código ya existe |
| `NAME_EXIST` | name | El nombre ya existe |
| `MAPURL_EXIST` | mapUrl | La URL del mapa ya existe |
| Otros | - | Error desconocido |

### Configuración del Scanner

```typescript
config: ScannerQRCodeConfig = {
  isBeep: false,  // Sin sonido al escanear
  constraints: {
    video: {
      width: window.innerWidth  // Ancho completo
    }
  }
}
```

### Flujo de Trabajo Típico

#### Opción 1: Manual
1. Usuario ingresa código del territorio
2. Usuario ingresa nombre del territorio
3. Usuario ingresa URL del mapa manualmente
4. Hace clic en "Guardar"
5. Sistema valida y guarda

#### Opción 2: Con QR
1. Usuario ingresa código del territorio
2. Usuario ingresa nombre del territorio
3. Usuario hace clic en "Escanear QR"
4. Escanea el código QR del mapa
5. La URL se completa automáticamente
6. Hace clic en "Guardar"
7. Sistema valida y guarda

### Estados de la Vista
- **Formulario vacío**: Esperando datos
- **Escaneando QR**: Modal de scanner activo
- **Validando**: Verificando datos en servidor
- **Guardando**: Spinner activo
- **Error**: Mostrando mensajes de validación
- **Éxito**: Formulario reseteado, listo para nuevo territorio

---

## 2. Editar Territorio (EditTerritoryModalComponent)

**Archivo:** `src/app/components/edit-territory-modal/edit-territory-modal.component.ts`  
**Tipo:** Modal/Componente

### Descripción
Modal para editar la información básica de un territorio existente.

### Funcionalidad Principal
- Modificar datos de territorios existentes
- Validación de unicidad de datos
- Actualización en tiempo real de la información

### Campos Editables

#### **name** (Nombre)
- Nombre del territorio
- Debe ser único
- Requerido

#### **code** (Código)
- Código identificador
- Debe ser único
- Requerido

#### **mapUrl** (URL del Mapa)
- URL del mapa del territorio
- Debe ser única
- Requerida

### Funciones Principales

#### `initializeForm()`
Inicializa el formulario con los datos actuales del territorio:
- Se ejecuta cuando se asigna `territoryInfo`
- Carga valores existentes en los campos

#### `openModal()`
Abre el modal de edición:
- Muestra el formulario pre-llenado
- Utiliza Bootstrap modal

#### `editTerritory()`
Guarda los cambios realizados:
```typescript
Parámetros:
- territoryId: number
- mapUrl: string
- name: string
- code: string

Flujo:
1. Valida el formulario
2. Envía petición de actualización
3. Emite evento territoryUpdated
4. Cierra el modal
5. Muestra mensaje de éxito
```

### Manejo de Errores

Similar a AddTerritoryComponent, gestiona:
- `CODE_EXIST`: Código duplicado
- `NAME_EXIST`: Nombre duplicado
- `MAPURL_EXIST`: URL duplicada

### Eventos

#### Output: `territoryUpdated`
Emitido cuando se actualiza exitosamente:
- Permite al componente padre refrescar los datos
- No envía parámetros

### Input/Output

```typescript
@Input() territoryInfo: TerritoryEditInfo
@Output() territoryUpdated: EventEmitter<void>
```

---

## 3. Eliminar Territorio (DeleteTerritoryModalComponent)

**Archivo:** `src/app/components/delete-territory-modal/delete-territory-modal.component.ts`  
**Tipo:** Modal/Componente

### Descripción
Modal de confirmación para eliminar un territorio del sistema.

### Funcionalidad Principal
- Confirmar eliminación de territorio
- Prevenir eliminaciones accidentales
- Notificar al componente padre

### Propiedades

```typescript
@Input() territoryId: number  // ID del territorio a eliminar
@Output() territoryDeleted: EventEmitter<void>  // Evento de confirmación
```

### Funciones Principales

#### `openModal()`
Muestra el modal de confirmación:
- Presenta información del territorio
- Solicita confirmación del usuario

#### `deleteTerritory()`
Ejecuta la eliminación:
```typescript
Flujo:
1. Muestra spinner
2. Cierra el modal
3. Envía petición de eliminación al servidor
4. Si éxito:
   - Emite evento territoryDeleted
   - Muestra mensaje de éxito
5. Si error:
   - Muestra mensaje de error
```

### Consideraciones de Seguridad
- La eliminación es permanente
- Se recomienda verificar que no haya transacciones activas
- Solo usuarios con permisos ADMIN o SUPERADMIN pueden acceder

---

## 4. Asignar Territorio (ChangeTerritoryComponent)

**Ruta:** `/change-territory` o `/change-territory/:territoryCode`  
**Archivo:** `src/app/components/change-territory/change-territory.component.ts`

### Descripción
Pantalla para asignar (entregar) un territorio a una persona específica.

### Funcionalidad Principal
- Seleccionar territorio disponible
- Seleccionar persona destinataria
- Establecer fecha de entrega (actual o personalizada)
- Escanear QR para seleccionar territorio
- Ver sugerencias de territorios prioritarios

### Campos del Formulario

#### **selectedTerritory** (Territorio)
- Territorio a asignar
- Debe estar libre (no asignado)
- Búsqueda con autocompletado
- Puede pre-cargarse desde URL
- Puede escanearse con QR

#### **selectedPerson** (Persona)
- Persona que recibirá el territorio
- Búsqueda con autocompletado
- Debe existir en el sistema

#### **customDate** (Fecha Personalizada)
- Checkbox para habilitar fecha personalizada
- Por defecto usa fecha actual

#### **date** (Fecha de Entrega)
- Fecha y hora de la entrega
- Requerida si customDate está activo
- Debe ser posterior a la última fecha de recogida
- Formato: `YYYY-MM-DDTHH:mm`

### Funciones Principales

#### `loadTerritories()`
Carga territorios disponibles:
- Solo muestra territorios libres
- Búsqueda en tiempo real (pipe con RxJS)
- Máximo 3 resultados por búsqueda

#### `loadPersons()`
Carga lista de personas:
- Búsqueda en tiempo real
- Máximo 3 resultados por búsqueda

#### `loadTerritorySuggestions()`
Carga sugerencias de territorios prioritarios:
- Territorios más antiguos sin asignar
- Ordenados por última fecha de recogida
- Muestra en sección especial de la UI

#### `giveTerritory()`
Ejecuta la asignación del territorio:
```typescript
Parámetros:
- territoryCode: string
- personName: string
- useCustomDate: boolean
- customDate?: Date

Flujo:
1. Valida formulario
2. Envía petición al servidor
3. Resetea formulario si tiene éxito
4. Recarga listas y sugerencias
5. Muestra mensaje de éxito
```

#### `selectSuggestedTerritory(territory)`
Selecciona un territorio de las sugerencias:
- Convierte la sugerencia a objeto Territory
- Lo asigna al formulario
- Permite envío rápido

### Validaciones

#### `dateValidator()`
Validador personalizado para la fecha:
- Solo se ejecuta si `customDate` está activo
- Verifica que la fecha no sea anterior a la última recogida del territorio
- Error: `dateBeforeLastPicked`

### Scanner de QR

Similar a AddTerritoryComponent:
- **`startQrScanner()`**: Inicia scanner
- **`stopQrScanner()`**: Detiene scanner
- **`onEvent()`**: Procesa resultado y busca el territorio por URL

### Autocompletado (ng-select)

Utiliza `Observable` con RxJS para búsqueda eficiente:
```typescript
- distinctUntilChanged(): Evita búsquedas duplicadas
- switchMap(): Cancela búsquedas anteriores
- catchError(): Maneja errores sin romper el flujo
- tap(): Gestiona estados de carga
```

### Sugerencias de Territorios

Muestra lista de territorios recomendados:
- **Criterio**: Más tiempo sin asignar
- **Ordenamiento**: Por `lastPickedDate` ascendente
- **Visualización**: Cards con información clave
- **Acción rápida**: Click para seleccionar

### Pre-carga desde URL

Si se accede con `/:territoryCode`:
1. Carga automáticamente el territorio especificado
2. Pre-llena el campo `selectedTerritory`
3. Usuario solo debe seleccionar persona y confirmar

### Estados de la Vista
- **Formulario vacío**: Esperando selección
- **Cargando territorios**: Spinner en selector
- **Cargando personas**: Spinner en selector
- **Cargando sugerencias**: Skeleton en sección de sugerencias
- **Escaneando QR**: Modal de scanner activo
- **Procesando**: Enviando asignación
- **Éxito**: Formulario reseteado

---

## 5. Recoger Territorio (PickTerritoryComponent)

**Ruta:** `/pick-territory` o `/pick-territory/:territoryCode`  
**Archivo:** `src/app/components/pick-territory/pick-territory.component.ts`

### Descripción
Pantalla para registrar la recogida (devolución) de un territorio que estaba asignado.

### Funcionalidad Principal
- Seleccionar territorio asignado para recoger
- Establecer fecha de recogida (actual o personalizada)
- Escanear QR para seleccionar territorio
- Validar que la fecha sea posterior a la entrega

### Campos del Formulario

#### **selectedTerritory** (Territorio)
- Territorio a recoger
- Debe estar asignado (en uso)
- Búsqueda con autocompletado
- Solo muestra territorios con estado "given"

#### **customDate** (Fecha Personalizada)
- Checkbox para habilitar fecha personalizada
- Por defecto usa fecha y hora actual

#### **date** (Fecha de Recogida)
- Fecha y hora de la recogida
- Requerida si customDate está activo
- Debe ser posterior a la fecha de entrega
- Formato: `YYYY-MM-DDTHH:mm`

### Funciones Principales

#### `loadTerritories()`
Carga territorios asignados:
- Llama a `searchGivenTerritories()`
- Solo territorios actualmente en uso
- Búsqueda en tiempo real
- Máximo 3 resultados

#### `pickTerritory()`
Ejecuta la recogida del territorio:
```typescript
Parámetros:
- territoryCode: string
- useCustomDate: boolean
- customDate?: Date

Flujo:
1. Valida formulario
2. Envía petición al servidor
3. Registra la devolución
4. Resetea formulario
5. Muestra mensaje de éxito
```

#### `onTerritorySelect(event)`
Maneja la selección de territorio:
- Obtiene datos completos del territorio
- Actualiza el formulario
- Permite validaciones adicionales

### Validaciones

#### `dateValidator()`
Validador personalizado de fecha:
```typescript
Validaciones:
- Solo activo si customDate es true
- Verifica que date >= givenDateUtc del territorio
- Error: beforeGivenDate si la fecha es anterior
```

La fecha de recogida NO puede ser anterior a la fecha de entrega.

### Scanner de QR

Funcionalidad idéntica a ChangeTerritoryComponent:
- Escanea código QR del mapa
- Busca el territorio por URL
- Lo asigna automáticamente al formulario

### Pre-carga desde URL

Similar a ChangeTerritoryComponent:
- Ruta: `/pick-territory/:territoryCode`
- Carga automáticamente el territorio
- Usuario solo confirma fecha y ejecuta

### Flujo de Trabajo Típico

1. Usuario busca el territorio asignado
2. Selecciona el territorio de la lista
3. Sistema carga fecha de entrega automáticamente
4. Usuario puede:
   - Usar fecha actual (por defecto)
   - Activar customDate y elegir otra fecha
5. Usuario confirma la recogida
6. Sistema valida y registra

### Diferencias con ChangeTerritoryComponent

| Aspecto | PickTerritory | ChangeTerritory |
|---------|---------------|-----------------|
| Territorios | Solo asignados | Solo libres |
| Persona | No requerida | Requerida |
| Fecha | Debe ser > givenDate | Debe ser > lastPickedDate |
| Resultado | Territorio queda libre | Territorio queda asignado |
| API | `pickTerritory()` | `giveTerritory()` |

### Estados de la Vista
- **Seleccionando territorio**: Buscando en la lista
- **Escaneando QR**: Modal de scanner activo
- **Fecha personalizada**: Input de fecha habilitado
- **Validando**: Verificando fechas
- **Procesando**: Registrando recogida
- **Éxito**: Formulario reseteado, listo para nueva recogida

---

*Última actualización: 2025-12-03*
