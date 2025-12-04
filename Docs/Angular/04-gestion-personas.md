# Gestión de Personas

## 1. Lista de Personas (PersonsComponent)

**Ruta:** `/persons`  
**Archivo:** `src/app/components/persons/persons.component.ts`

### Descripción
Pantalla para visualizar y gestionar todas las personas registradas en el sistema. Las personas son los individuos a quienes se asignan los territorios.

### Funcionalidad Principal
- Listar todas las personas del sistema
- Ver territorios asignados a cada persona
- Editar información de personas (Admin/SuperAdmin)
- Eliminar personas (Admin/SuperAdmin)
- Habilitar/deshabilitar personas
- Vista expandible con detalles de territorios activos

### Tecnología Utilizada
Utiliza **Tabulator** para la gestión avanzada de tablas:
- Filtros por columna
- Ordenamiento
- Filas expandibles con sub-tablas
- Rendimiento optimizado

### Columnas de la Tabla Principal

| Columna | Campo | Descripción | Opciones |
|---------|-------|-------------|----------|
| 🗑️ | - | Eliminar persona | Solo Admin/SuperAdmin |
| ✏️ | - | Editar persona | Solo Admin/SuperAdmin |
| Name | Name | Nombre de la persona | Con filtro de búsqueda |
| Habilitado | Enabled | Estado activo/inactivo | Checkbox visual |

### Filas Expandibles

Cada persona muestra una **sub-tabla** con sus territorios activos:

| Columna | Campo | Descripción |
|---------|-------|-------------|
| Fecha | GivenDate | Fecha de entrega del territorio |
| Territorio | TerritoryName | Nombre del territorio |
| Código | TerritoryCode | Código identificador |

**Nota:** Solo se expande si la persona tiene territorios asignados.

### Funciones Principales

#### `getPersons()`
Obtiene todas las personas del sistema:
```typescript
Flujo:
1. Muestra spinner de carga
2. Llama a PersonService.getAllPersons()
3. Almacena resultados en array persons
4. Construye la tabla Tabulator
5. Oculta spinner
```

#### `buildTabulatorTable()`
Construye la tabla interactiva con Tabulator:
- Configuración de columnas
- Formatters personalizados (íconos)
- Row formatter para sub-tablas
- Eventos de click en íconos
- Visibilidad condicional según permisos

#### `openDeleteUserModal(nameToDelete)`
Abre modal de confirmación para eliminar:
- Parámetro: nombre de la persona
- Muestra modal con Bootstrap
- Guarda nombre temporalmente

#### `deletePerson()`
Ejecuta la eliminación de la persona:
```typescript
Flujo:
1. Muestra spinner
2. Cierra modal
3. Envía petición de eliminación
4. Recarga lista de personas
5. Muestra mensaje "Hermano eliminado"
```

#### `openEditPersonModal(personData)`
Abre modal de edición con datos pre-cargados:
- Carga nombre actual
- Carga estado habilitado/deshabilitado
- Muestra modal de edición

#### `submitEditPerson()`
Guarda cambios de la persona editada:
```typescript
Parámetros actualizables:
- name: string
- enabled: boolean

Flujo:
1. Valida selección
2. Muestra spinner
3. Llama a updatePerson()
4. Cierra modal
5. Recarga lista
6. Muestra mensaje de éxito
```

### Formatters Personalizados

#### `deleteIcon()`
```typescript
Retorna: "<i class='fa fa-trash-can'></i>"
Color: Rojo (típicamente)
Acción: Eliminar persona
```

#### `editIcon()`
```typescript
Retorna: "<i class='fa fa-pencil'></i>"
Color: Azul (típicamente)
Acción: Editar persona
```

### Row Formatter (Sub-tabla)

La función `rowFormatter` crea dinámicamente una sub-tabla cuando:
1. La persona tiene territorios en uso (`TerritoriesInUse.length > 0`)
2. Convierte fechas UTC a formato local
3. Muestra información formateada de cada territorio

**Procesamiento de fechas:**
```typescript
preprocessDate(dateString):
- Limpia milisegundos largos
- Convierte UTC a hora local del navegador
- Formato: "dd/MM/yyyy, HH:mm:ss"
```

### Permisos por Rol

| Acción | USER | ADMIN | SUPERADMIN |
|--------|------|-------|------------|
| Ver lista | ✅ | ✅ | ✅ |
| Ver territorios | ✅ | ✅ | ✅ |
| Editar persona | ❌ | ✅ | ✅ |
| Eliminar persona | ❌ | ✅ | ✅ |

Los íconos de editar/eliminar solo son visibles para usuarios autorizados.

### Estados de la Vista
- **Cargando**: Spinner mientras se obtienen datos
- **Lista completa**: Todas las personas visibles
- **Fila expandida**: Mostrando territorios de una persona
- **Editando**: Modal de edición abierto
- **Confirmando eliminación**: Modal de confirmación activo
- **Actualizando**: Guardando cambios

### Campo "Habilitado"

Una persona puede estar **deshabilitada**:
- No está eliminada del sistema
- Solo está marcada como inactiva
- Puede reactivarse posteriormente
- Útil para personas temporalmente inactivas

---

## 2. Agregar Persona (AddPersonComponent)

**Ruta:** `/add-person`  
**Archivo:** `src/app/components/add-person/add-person.component.ts`  
**Permisos:** SUPERADMIN y ADMIN

### Descripción
Formulario simple para registrar nuevas personas en el sistema.

### Funcionalidad Principal
- Registrar nuevas personas
- Validar nombres únicos
- Interfaz minimalista y rápida

### Campos del Formulario

#### **name** (Nombre)
- Nombre completo de la persona
- Requerido
- Debe ser único en el sistema
- Ejemplo: "Juan Pérez García"

### Funciones Principales

#### `addPerson()`
Registra la nueva persona:
```typescript
Parámetros:
- name: string

Flujo:
1. Valida que el formulario sea válido
2. Muestra spinner
3. Envía petición al servidor
4. Si éxito:
   - Resetea formulario
   - Muestra mensaje "Hermano añadido"
5. Si error:
   - Muestra error específico
```

### Validaciones y Errores

#### `handleAddError(error)`
Gestiona errores del servidor:

| Error del Servidor | Mensaje/Acción |
|-------------------|----------------|
| `PERSON_ALREADY_EXISTS` | Marca el campo name con error `personExists` |
| Otros errores | Muestra "Error inesperado" |

### Flujo de Trabajo Típico

1. Administrador ingresa nombre de la persona
2. Hace clic en "Agregar"
3. Sistema valida:
   - Que el campo no esté vacío
   - Que el nombre no exista
4. Si es válido:
   - Se crea la persona
   - El formulario se limpia
   - Listo para agregar otra persona
5. Si no es válido:
   - Se muestra el error correspondiente
   - Se corrige y se reintenta

### Consideraciones

- **Simplicidad**: Solo requiere el nombre, otros datos opcionales se pueden agregar luego editando
- **Rapidez**: Formulario optimizado para agregar múltiples personas seguidas
- **Estado por defecto**: Las personas nuevas se crean como "Habilitadas"
- **Sin territorios**: Las personas nuevas no tienen territorios asignados inicialmente

### Estados de la Vista
- **Formulario vacío**: Esperando entrada
- **Validando**: Verificando disponibilidad del nombre
- **Guardando**: Spinner activo
- **Error**: Mostrando mensaje de validación
- **Éxito**: Formulario limpio, listo para siguiente persona

### Relación con Otras Pantallas

Después de agregar personas aquí, se pueden:
1. Ver en `/persons`
2. Editar desde `/persons`
3. Asignarles territorios en `/change-territory`

---

## Modelo de Datos: Person

Aunque no se muestra todo el modelo en estos componentes, una Persona típicamente incluye:

```typescript
interface Person {
  Id: number;           // ID único
  Name: string;         // Nombre completo
  Enabled: boolean;     // Estado activo/inactivo
  TerritoriesInUse: Territory[];  // Territorios actualmente asignados
}
```

### Propiedades Clave

- **Id**: Identificador único generado automáticamente
- **Name**: Único en el sistema, usado para búsquedas y asignaciones
- **Enabled**: Permite desactivar sin eliminar
- **TerritoriesInUse**: Array de territorios activos (calculado dinámicamente)

---

*Última actualización: 2025-12-03*
