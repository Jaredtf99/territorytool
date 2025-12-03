# Transacciones y Reportes

## 1. Transacciones Recientes (RecentTransactionsComponent)

**Ruta:** `/recent-transactions`  
**Archivo:** `src/app/components/recent-transactions/recent-transactions.component.ts`

### Descripción
Vista de las transacciones más recientes del sistema. Muestra una lista cronológica de las últimas entregas y recogidas de territorios.

### Funcionalidad Principal
- Visualizar las transacciones más recientes
- Vista rápida de actividad del sistema
- Monitoreo de operaciones

### Datos Mostrados

Una transacción incluye:
- **Territorio**: Código y nombre del territorio
- **Persona**: Nombre de la persona involucrada
- **Tipo**: Entrega (give) o Recogida (pick)
- **Fecha**: Fecha y hora de la transacción
- **Estado**: Si la transacción está completa o activa

### Funciones Principales

#### `loadRecentTransactions()`
Carga las transacciones más recientes:
```typescript
Flujo:
1. Llama a TerritoryTransactionService.getRecentTransactions()
2. Almacena resultados en array transactions
3. Muestra en la vista
4. Maneja errores si los hay
```

### Ordenamiento
Las transacciones se muestran de más reciente a más antigua.

### Estados de la Vista
- **Cargando**: Obteniendo transacciones del servidor
- **Con datos**: Lista de transacciones visible
- **Sin datos**: Mensaje de que no hay transacciones recientes
- **Error**: Mensaje de error si falla la carga

### Caso de Uso
Esta pantalla es útil para:
- Supervisores monitoreando actividad
- Auditores revisando operaciones
- Usuarios verificando si su transacción se registró
- Dashboard general de actividad

---

## 2. Transacciones de Territorio (TerritoryTransactionsComponent)

**Ruta:** `/territory/:id/transactions`  
**Archivo:** `src/app/components/territory-transactions/territory-transactions.component.ts`

### Descripción
Vista detallada de todas las transacciones de un territorio específico. Muestra el historial completo con opciones de edición y eliminación.

### Funcionalidad Principal
- Ver historial completo de un territorio
- Editar transacciones existentes
- Eliminar transacciones (con confirmación)
- Seguimiento detallado de asignaciones

### Datos de la Transacción

Cada transacción muestra:
- **ID**: Identificador único
- **Persona**: Quién recibió/devolvió el territorio
- **Fecha de Entrega** (`givenDateUtc`): Cuándo se asignó
- **Fecha de Recogida** (`pickedDateUtc`): Cuándo se devolvió (puede ser null si está activa)
- **Duración**: Tiempo que estuvo asignado
- **Estado**: Activa (sin fecha de recogida) o Completada

### Funciones Principales

#### `loadTransactions()`
Carga todas las transacciones del territorio:
```typescript
Parámetros:
- territoryId: number (obtenido desde la ruta)

Flujo:
1. Obtiene transacciones del servidor
2. Las almacena en array transactions
3. Las muestra ordenadas cronológicamente
```

#### `openEditTransactionModal(id)`
Abre modal para editar una transacción:
```typescript
Acciones:
1. Asigna el ID al componente modal
2. Abre el modal de edición
3. El modal carga los datos automáticamente
```

#### `deleteTransaction(id)`
Elimina una transacción:
```typescript
Flujo:
1. Muestra confirmación nativa (confirm dialog)
2. Si el usuario confirma:
   - Envía petición de eliminación
   - Recarga la lista de transacciones
   - Muestra mensaje "Transacción eliminada"
```

#### `onTransactionUpdated()`
Callback ejecutado cuando se edita una transacción:
- Recarga la lista para reflejar cambios
- Actualiza la vista automáticamente

### Componentes Hijos

#### **EditTransactionModalComponent**
Modal para editar transacciones:
- Cambiar persona asignada
- Modificar fecha de entrega
- Modificar fecha de recogida
- Validar que las fechas sean coherentes

### Navegación
- Accesible desde el detalle del territorio
- Botón "Ver Todas las Transacciones" en `TerritoryDetailComponent`

### Casos de Uso

#### Corrección de Errores
- Se asignó al territorio a la persona incorrecta
- La fecha de entrega/recogida fue mal registrada
- Necesidad de ajustar historial

#### Auditoría
- Revisar historial completo del territorio
- Verificar patrones de uso
- Identificar problemas recurrentes

#### Gestión
- Eliminar transacciones duplicadas
- Limpiar registros incorrectos
- Mantener datos precisos

### Estados de la Vista
- **Cargando**: Obteniendo transacciones
- **Lista completa**: Todas las transacciones visibles
- **Editando**: Modal de edición abierto
- **Confirmando eliminación**: Dialog de confirmación activo
- **Actualizando**: Después de editar/eliminar

---

## 3. Modal de Edición de Transacción (EditTransactionModalComponent)

**Archivo:** `src/app/components/edit-transaction-modal/edit-transaction-modal.component.ts`  
**Tipo:** Modal/Componente

### Descripción
Modal para editar los detalles de una transacción existente.

### Funcionalidad Principal
- Modificar persona asignada
- Cambiar fecha de entrega
- Cambiar fecha de recogida
- Validar coherencia de fechas

### Campos del Formulario

#### **person** (Persona)
- Persona asignada al territorio
- Selector con búsqueda (ng-select)
- Requerido

#### **givenDate** (Fecha de Entrega)
- Fecha y hora de entrega del territorio
- Formato: `YYYY-MM-DDTHH:mm`
- Requerida

#### **pickedDate** (Fecha de Recogida)
- Fecha y hora de devolución
- Formato: `YYYY-MM-DDTHH:mm`
- Opcional (null si aún está asignado)

### Funciones Principales

#### `openModal()`
Abre el modal con datos de la transacción:
```typescript
Flujo:
1. Muestra spinner
2. Carga personas disponibles para el selector
3. Obtiene datos de la transacción del servidor
4. Pre-llena el formulario con datos actuales
5. Muestra el modal
6. Oculta spinner
```

#### `editTransaction()`
Guarda los cambios:
```typescript
Parámetros enviados:
- personId: number
- givenDateUtc: Date
- pickedDateUtc: Date | undefined

Flujo:
1. Valida el formulario
2. Muestra spinner
3. Crea objeto TerritoryTransaction
4. Envía actualización al servidor
5. Emite evento transactionUpdated
6. Cierra modal
7. Muestra mensaje "Transacción editada"
```

#### `loadPersons()`
Carga lista de personas para el selector:
- Búsqueda en tiempo real con RxJS
- Máximo 3 resultados por búsqueda
- Manejo de estados de carga

### Validaciones

#### `dateRangeValidator()`
Validador personalizado del rango de fechas:
```typescript
Validación:
- Si existe pickedDate, debe ser >= givenDate
- No puede recoger antes de entregar

Error:
- dateRange: true (si la validación falla)
```

### Manejo de Errores

#### `handleError(error)`
Procesa errores del servidor:

| Error | Campos Afectados | Descripción |
|-------|------------------|-------------|
| `INVALID_DATES` | givenDate, pickedDate | Fechas incoherentes |
| `TERRITORY_ALREADY_IN_USE` | pickedDate | El territorio ya estaba asignado en ese período |
| Otros | - | Error desconocido |

### Input/Output

```typescript
@Input() transactionId: number
@Output() transactionUpdated: EventEmitter<void>
```

### Formateo de Fechas

#### `formatDate(date: Date)`
Convierte Date a string en formato para input datetime-local:
```typescript
Formato: "YYYY-MM-DDTHH:mm"
Ejemplo: "2025-12-03T14:30"
```

### Estados del Modal
- **Cerrado**: No visible
- **Cargando datos**: Spinner mientras obtiene transacción
- **Editando**: Formulario activo
- **Validando**: Verificando datos
- **Guardando**: Enviando cambios al servidor
- **Error**: Mostrando mensajes de validación

---

## 4. Generar Reporte (GenerateReportComponent)

**Ruta:** `/generate-report`  
**Archivo:** `src/app/components/generate-report/generate-report.component.ts`

### Descripción
Pantalla para generar reportes en formato Excel con las transacciones de territorios en un rango de fechas específico.

### Funcionalidad Principal
- Seleccionar rango de fechas para el reporte
- Generar archivo Excel con transacciones
- Descargar automáticamente el reporte
- Validación de fechas coherentes

### Campos del Formulario

#### **startDate** (Fecha Inicial)
- Fecha de inicio del período
- Formato: `YYYY-MM-DD`
- Requerida
- No puede ser posterior a endDate

#### **endDate** (Fecha Final)
- Fecha de fin del período
- Formato: `YYYY-MM-DD`
- Requerida
- No puede ser anterior a startDate
- Por defecto: fecha actual

### Funciones Principales

#### `generarYDescargarExcel()`
Genera y descarga el reporte:
```typescript
Parámetros:
- startDate: Date (a las 00:00)
- endDate: Date (a las 00:00)

Flujo:
1. Valida el formulario
2. Muestra spinner
3. Llama a TerritoryService.generateExcel()
4. Recibe archivo Blob
5. Crea link temporal de descarga
6. Activa descarga automática
7. Oculta spinner
8. Limpia el link temporal
```

#### `formatDate(date: Date, withTime: boolean)`
Formatea fechas para el formulario:
```typescript
Si withTime = false:
  Formato: "YYYY-MM-DD"
  
Si withTime = true:
  Formato: "YYYY-MM-DDTHH:mm"
```

### Validaciones

#### `dateRangeValidator()`
Validador a nivel de formulario:
```typescript
Validación:
- startDate <= endDate

Error:
- dateRange: true (si startDate > endDate)

Mensaje típico: "La fecha inicial no puede ser posterior a la final"
```

### Contenido del Reporte Excel

El archivo Excel generado típicamente incluye:
- **Territorio**: Código y nombre
- **Persona**: Nombre de la persona
- **Fecha de Entrega**: Cuándo se asignó
- **Fecha de Recogida**: Cuándo se devolvió
- **Duración**: Días que estuvo asignado
- **Estado**: Completado o Activo

### Proceso de Descarga

```typescript
1. Servidor genera Excel en memoria
2. Se envía como Blob (binary large object)
3. Se crea un Blob con tipo MIME de Excel
4. Se genera URL temporal con createObjectURL
5. Se crea elemento <a> dinámico
6. Se simula click para iniciar descarga
7. Nombre del archivo: "TerritoryTransactions.xlsx"
```

### Casos de Uso

#### Reportes Mensuales
```
startDate: 2025-11-01
endDate: 2025-11-30
```

#### Reportes Trimestrales
```
startDate: 2025-10-01
endDate: 2025-12-31
```

#### Auditoría Específica
```
startDate: 2025-06-15
endDate: 2025-06-20
```

### Estados de la Vista
- **Seleccionando fechas**: Usuario configura rango
- **Validando**: Verificando que fechas sean coherentes
- **Generando**: Servidor creando Excel (spinner activo)
- **Descargando**: Archivo siendo descargado
- **Error**: Mostrando mensaje de error de validación

### Consideraciones de Rendimiento

- **Rangos grandes**: Pueden tomar más tiempo en generar
- **Límite recomendado**: Máximo 1 año de datos
- **Spinner**: Siempre mostrado durante generación
- **Timeout**: Considerar timeout para rangos muy grandes

---

## 5. Logs de Acciones (ViewActionlogsComponent)

**Ruta:** `/action-logs`  
**Archivo:** `src/app/components/view-actionlogs/view-actionlogs.component.ts`  
**Permisos:** SUPERADMIN únicamente

### Descripción
Vista de auditoría completa del sistema. Muestra todas las acciones realizadas por usuarios con paginación y ordenamiento remoto.

### Funcionalidad Principal
- Visualizar todas las acciones del sistema
- Paginación eficiente del lado servidor
- Ordenamiento por cualquier columna
- Filtrado y búsqueda
- Auditoría completa de operaciones

### Tecnología Utilizada
**Tabulator** con características avanzadas:
- Paginación remota (datos cargados bajo demanda)
- Ordenamiento remoto (ordenamiento en servidor)
- Rendimiento optimizado para grandes volúmenes

### Columnas de la Tabla

| Columna | Campo | Descripción | Ordenable |
|---------|-------|-------------|-----------|
| Type | ActionType | Tipo de acción realizada | ✅ |
| Date | DateUtc | Fecha y hora (formato "hace X tiempo") | ✅ |
| UserName | UserName | Usuario que realizó la acción | ✅ |
| Message | Message | Descripción de la acción | ✅ |
| Successful | Successful | Si la acción fue exitosa | ✅ |

### Configuración de Tabulator

#### Paginación
```typescript
paginationMode: "remote"  // Servidor maneja paginación
paginationSize: 20        // 20 registros por página
paginationSizeSelector: [10, 20, 50, 100]  // Opciones
```

#### Ordenamiento
```typescript
sortMode: "remote"  // Servidor maneja ordenamiento
initialSort: [
  { column: "DateUtc", dir: "desc" }  // Más recientes primero
]
```

#### AJAX Configuration
```typescript
ajaxURL: "${baseUrl}/actionlogs"
ajaxRequestFunc: Custom function con HttpClient
```

### Funciones Principales

#### `buildTabulatorTable()`
Construye la tabla con configuración avanzada:
```typescript
Características:
- Layout adaptive (fitColumns)
- Max height 100%
- Request personalizado con HttpClient
- Formatters personalizados para fechas
```

#### Request Personalizado
```typescript
ajaxRequestFunc(url, config, params) {
  Parámetros enviados al servidor:
  - pageNumber: número de página actual
  - pageSize: registros por página
  - sortField: campo de ordenamiento
  - sortOrder: dirección ("asc" o "desc")
  
  Retorna: Promise de datos paginados
}
```

### Formatter de Fecha

Utiliza **TimeagoPipe** para mostrar fechas relativas:
```typescript
Ejemplos:
- "hace 5 minutos"
- "hace 2 horas"
- "hace 3 días"
- "hace 1 mes"
```

### Tipos de Acciones Comunes

Los `ActionType` típicamente incluyen:
- **USER_LOGIN**: Inicio de sesión
- **TERRITORY_CREATED**: Territorio creado
- **TERRITORY_UPDATED**: Territorio editado
- **TERRITORY_DELETED**: Territorio eliminado
- **TERRITORY_GIVEN**: Territorio asignado
- **TERRITORY_PICKED**: Territorio recogido
- **PERSON_CREATED**: Persona creada
- **PERSON_UPDATED**: Persona actualizada
- **PERSON_DELETED**: Persona eliminada
- **USER_CREATED**: Usuario creado
- **USER_UPDATED**: Usuario actualizado
- **PASSWORD_CHANGED**: Contraseña cambiada

### Columna Successful

Muestra con ícono checkmark/cross:
- ✅ **true**: Acción exitosa
- ❌ **false**: Acción fallida

Útil para identificar intentos fallidos o errores.

### Casos de Uso

#### Auditoría de Seguridad
- Revisar inicios de sesión
- Detectar intentos fallidos
- Identificar acciones sospechosas

#### Rastreo de Cambios
- Ver quién modificó un territorio
- Verificar cuándo se realizó una acción
- Investigar errores o problemas

#### Cumplimiento
- Generar reportes de auditoría
- Demostrar trazabilidad
- Mantener registros históricos

### Rendimiento

#### Paginación Remota
Ventajas:
- Solo carga 20-100 registros a la vez
- Rápido incluso con millones de logs
- Reduce uso de memoria del navegador

#### Ordenamiento Remoto
Ventajas:
- El servidor ordena eficientemente
- Usa índices de base de datos
- No requiere cargar todos los datos

### Estados de la Vista
- **Cargando página**: Spinner en tabla mientras carga datos
- **Mostrando datos**: Registros de la página actual visibles
- **Cambiando página**: Cargando nueva página de datos
- **Cambiando orden**: Re-cargando con nuevo ordenamiento
- **Error**: Mensaje si falla la carga

### Restricción de Acceso

**Solo SUPERADMIN** puede acceder:
- Route guard verifica el rol
- Usuarios sin permiso son redirigidos a `/forbidden`
- Información sensible protegida

---

*Última actualización: 2025-12-03*
