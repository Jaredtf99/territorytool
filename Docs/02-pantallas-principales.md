# Pantallas Principales

## 1. Dashboard / Home (HomeComponent)

**Ruta:** `/home`  
**Archivo:** `src/app/components/home/home.component.ts`

### Descripción
Dashboard principal de la aplicación que muestra una vista general de los territorios que llevan más tiempo sin actividad.

### Funcionalidad Principal
- Muestra territorios que no han tenido actividad en los últimos 4 meses
- Presenta información clave para identificar territorios que necesitan atención
- Permite navegar al detalle de cada territorio
- Es la primera pantalla que ve el usuario después de iniciar sesión

### Datos Mostrados
- **Territorios antiguos**: Territorios recogidos hace más de 4 meses
- **Ordenamiento**: Por relevancia (los más antiguos primero)
- **Límite**: Máximo 3 territorios mostrados inicialmente

### Funciones Principales

#### `loadOldTerritories()`
Carga los territorios que llevan más tiempo sin actividad:
- Calcula la fecha de 4 meses atrás
- Realiza consulta al servidor con filtros:
  - `inUse`: true (solo territorios actualmente asignados)
  - `orderBy`: 3 (ordenamiento específico)
  - `beforeDate`: hace 4 meses
- Muestra spinner durante la carga

#### `getTimeAgo(date)`
Formatea las fechas para mostrarlas de forma legible (ej: "15/11/2025")

#### `navigateToDetail(id)`
Navega al detalle completo del territorio seleccionado

### Estados de la Vista
- **Cargando**: Muestra spinner mientras se obtienen los datos
- **Con datos**: Lista los territorios antiguos
- **Sin datos**: Muestra mensaje de que no hay territorios antiguos

### Caso de Uso
Esta pantalla es útil para:
- Supervisores que necesitan identificar territorios desatendidos
- Hacer seguimiento de territorios que requieren revisión
- Priorizar qué territorios necesitan atención inmediata

---

## 2. Vista de Territorios (TerritoriesComponent)

**Ruta:** `/territories`  
**Archivo:** `src/app/components/territories/territories.component.ts`

### Descripción
Pantalla principal para visualizar y gestionar todos los territorios del sistema. Incluye filtros, búsqueda y opciones de administración.

### Funcionalidad Principal
- Lista completa de todos los territorios
- Filtros avanzados (disponibles, en uso, por nombre)
- Ordenamiento personalizable
- Acceso rápido a edición y eliminación
- Navegación al detalle de cada territorio

### Filtros Disponibles

#### **Por Estado**
- **Libres** (`free`): Territorios sin asignar
- **En Uso** (`inUse`): Territorios actualmente asignados
- **Todos**: Sin filtro de estado (por defecto)

#### **Por Nombre**
- Campo de búsqueda por texto (`filterName`)
- Búsqueda en tiempo real

#### **Ordenamiento**
- `orderBy`: Criterio de ordenamiento (valor numérico)
- `sortAscending`: Dirección (ascendente/descendente)

### Funciones Principales

#### `getTerritories()`
Obtiene la lista de territorios aplicando los filtros activos:
```typescript
- Parámetros:
  - filterName: string opcional
  - inUse/free: boolean opcional
  - orderBy: número
  - sortAscending: boolean
```

#### `onChangeFree()` y `onChangeInUse()`
Gestiona la exclusividad de los filtros:
- Si se activa "Libres", desactiva "En Uso"
- Si se activa "En Uso", desactiva "Libres"
- Recarga automáticamente los territorios

#### `detail(territoryId)`
Navega al detalle completo del territorio

#### `openEditModal(territory)`
Abre el modal de edición con los datos del territorio seleccionado

#### `assignIdToDelete(idToDelete)`
Abre el modal de confirmación para eliminar un territorio

### Componentes Hijos Utilizados

#### **EditTerritoryModalComponent**
Modal para editar información del territorio:
- Nombre
- Código
- URL del mapa

#### **DeleteTerritoryModalComponent**
Modal de confirmación para eliminar territorio

#### **TerritoryCardComponent**
Componente visual para mostrar cada territorio en formato de tarjeta

### Callbacks

#### `territoryUpdatedCallback()`
Se ejecuta cuando un territorio se edita exitosamente:
- Recarga la lista de territorios
- Actualiza la vista

#### `territoryDeleteCallback()`
Se ejecuta cuando un territorio se elimina:
- Recarga la lista de territorios

### Estados de la Vista
- **Cargando** (`isLoading = true`): Muestra indicador de carga
- **Con datos**: Muestra grid/lista de territorios
- **Sin datos**: Mensaje de "No hay territorios"
- **Filtrado**: Resultados según filtros aplicados

### Permisos de Usuario
Según el rol, algunas acciones pueden estar limitadas:
- **VER**: Todos los usuarios autenticados
- **EDITAR**: ADMIN y SUPERADMIN
- **ELIMINAR**: ADMIN y SUPERADMIN
- **AGREGAR**: ADMIN y SUPERADMIN (botón en otra vista)

---

## 3. Detalle de Territorio (TerritoryDetailComponent)

**Ruta:** `/territory/:id`  
**Archivo:** `src/app/components/territory-detail/territory-detail.component.ts`

### Descripción
Pantalla de detalle completo de un territorio específico. Muestra toda la información, historial y estadísticas.

### Funcionalidad Principal
- Visualización completa de información del territorio
- Historial de transacciones (timeline)
- Estadísticas del territorio
- Imagen actualizable del mapa
- Opciones de gestión (asignar, recoger, editar, eliminar)
- Scroll horizontal interactivo en el timeline

### Información Mostrada

#### **Datos Básicos**
- Código del territorio
- Nombre
- Imagen/mapa del territorio
- Estado actual (libre/asignado)

#### **Estadísticas**
Obtenidas mediante `getTerritoryStats()`:
- Número de asignaciones
- Tiempo promedio de uso
- Última fecha de entrega/recogida
- Otras métricas relevantes

#### **Timeline de Transacciones**
Lista cronológica de todas las actividades:
- Fecha y hora
- Tipo de transacción (entrega/recogida)
- Persona involucrada
- Ordenado de más reciente a más antiguo

### Funciones Principales

#### `getTerritoryInfo()`
Carga toda la información del territorio:
- Datos básicos
- Historial de transacciones
- Ordena el timeline por fecha descendente

#### `getTerritoryStats()`
Obtiene las estadísticas del territorio

#### `refreshTerritoryImage()`
Actualiza la imagen del mapa del territorio:
- Útil cuando se actualizó el mapa en el sistema externo
- Muestra confirmación al completar

#### `viewTransactions()`
Navega a la vista detallada de transacciones:
- Ruta: `/territory/:id/transactions`

#### `pickTerritory()`
Inicia el proceso de recogida del territorio:
- Muestra modal de confirmación
- Navega a `/pick-territory/:code`

#### `giveTerritory()`
Inicia el proceso de asignación del territorio:
- Navega a `/change-territory/:code`

### Gestión de Transacciones

#### `editTransaction(transactionId)`
Abre el modal para editar una transacción específica del historial

#### `deleteTransaction(id)`
Elimina una transacción del historial:
- Solicita confirmación
- Actualiza el timeline automáticamente

#### `onTransactionUpdated()`
Callback que se ejecuta al editar una transacción:
- Recarga la información del territorio

### Modales Utilizados

1. **EditTerritoryModalComponent**: Editar datos del territorio
2. **DeleteTerritoryModalComponent**: Eliminar el territorio
3. **EditTransactionModalComponent**: Editar transacciones del historial
4. **PickTerritoryModal**: Confirmar recogida de territorio

### Interactividad

#### Drag Scroll en Timeline
Implementado con `initDragScroll()`:
- Permite arrastrar horizontalmente el timeline con el mouse
- Mejora la experiencia de usuario en historiales largos
- Eventos gestionados:
  - `mousedown`: Inicia el arrastre
  - `mousemove`: Desplaza el contenido
  - `mouseup` / `mouseleave`: Finaliza el arrastre

### Callbacks

#### `territoryUpdatedCallback()`
Recarga información cuando se edita el territorio

#### `territoryDeleteCallback()`
Redirige a `/territories` cuando se elimina el territorio

### Navegación Relacionada
Desde esta pantalla se puede ir a:
- `/territories`: Lista de todos los territorios
- `/territory/:id/transactions`: Vista detallada de transacciones
- `/pick-territory/:code`: Recoger el territorio
- `/change-territory/:code`: Asignar el territorio

### Estados de la Vista
- **Cargando datos**: Spinner mientras se obtiene información
- **Mostrando detalles**: Información completa visible
- **Editando**: Modal de edición abierto
- **Confirmando eliminación**: Modal de confirmación abierto

---

*Última actualización: 2025-12-03*
