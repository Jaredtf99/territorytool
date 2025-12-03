# Documentación de Endpoints - Territory Tool API

## Tabla de Contenidos
- [Autenticación](#autenticación)
- [Endpoints de Usuarios](#endpoints-de-usuarios)
- [Endpoints de Personas](#endpoints-de-personas)
- [Endpoints de Territorios](#endpoints-de-territorios)
- [Endpoints de Transacciones](#endpoints-de-transacciones)
- [Endpoints de Logs de Acción](#endpoints-de-logs-de-acción)
- [Modelos de Datos](#modelos-de-datos)

---

## Autenticación

Todos los endpoints (excepto `/api/v1/users/login`) requieren autenticación mediante **JWT Bearer Token**.

### Headers requeridos:
```
Authorization: Bearer {token}
```

### Roles disponibles:
- **SUPERADMIN**: Acceso completo al sistema
- **ADMIN**: Acceso administrativo (gestión de usuarios, territorios y personas)
- **USER**: Acceso básico (consulta y operaciones básicas)

---

## Endpoints de Usuarios

**Base URL**: `/api/v1/users`

### 1. Login
**POST** `/api/v1/users/login`

Autentica un usuario y devuelve un token JWT.

**Autorización**: No requiere autenticación

**Request Body**:
```json
{
  "userName": "string",
  "password": "string"
}
```

**Response (200 OK)**:
```json
{
  "token": "string"
}
```

**Response (400 Bad Request)**:
```
"WRONG_USERNAME_PASSWORD"
```

---

### 2. Registrar Usuario
**POST** `/api/v1/users/register`

Registra un nuevo usuario en el sistema.

**Autorización**: SUPERADMIN, ADMIN

**Request Body**:
```json
{
  "userName": "string",
  "password": "string",
  "role": "USER | ADMIN | SUPERADMIN"
}
```

**Response (200 OK)**:
```json
{
  "succeeded": true,
  "errors": []
}
```

---

### 3. Obtener Usuarios
**GET** `/api/v1/users`

Devuelve una lista de todos los usuarios del sistema.

**Autorización**: SUPERADMIN, ADMIN

**Response (200 OK)**:
```json
[
  {
    "userID": "string",
    "userName": "string",
    "role": "USER | ADMIN | SUPERADMIN"
  }
]
```

---

### 4. Editar Usuario
**POST** `/api/v1/users/{userId}`

Edita la información de un usuario existente.

**Autorización**: SUPERADMIN, ADMIN

**Path Parameters**:
- `userId`: ID del usuario a editar

**Request Body**:
```json
{
  "userName": "string",
  "role": "USER | ADMIN"
}
```

**Notas**:
- No se puede asignar el rol SUPERADMIN
- Solo SUPERADMIN puede asignar el rol ADMIN

**Response (200 OK)**: Sin contenido

**Response (400 Bad Request)**: 
```
"INVALID_PARAMETERS"
```

**Response (403 Forbidden)**: Si un ADMIN intenta asignar el rol ADMIN

---

### 5. Eliminar Usuario
**DELETE** `/api/v1/users/{userId}`

Elimina un usuario del sistema.

**Autorización**: SUPERADMIN, ADMIN

**Path Parameters**:
- `userId`: ID del usuario a eliminar

**Response (200 OK)**: Sin contenido

**Response (400 Bad Request)**:
```
"INVALID_PARAMETERS"
```

---

### 6. Cambiar Contraseña (Usuario Actual)
**POST** `/api/v1/users/change-password`

Permite al usuario actual cambiar su propia contraseña.

**Autorización**: Cualquier usuario autenticado

**Request Body**:
```json
{
  "oldPassword": "string",
  "newPassword": "string"
}
```

**Response (200 OK)**: Sin contenido

**Response (400 Bad Request)**:
```
"ErrorCode1,ErrorCode2,..."
```

---

### 7. Cambiar Contraseña de Otro Usuario
**POST** `/api/v1/users/{userId}/change-password`

Permite a un administrador cambiar la contraseña de otro usuario.

**Autorización**: SUPERADMIN, ADMIN

**Path Parameters**:
- `userId`: ID del usuario cuya contraseña se va a cambiar

**Request Body**:
```json
{
  "newPassword": "string"
}
```

**Response (200 OK)**: Sin contenido

**Response (400 Bad Request)**:
```
"INVALID_PASSWORD" | "INVALID_USER_ID"
```

**Response (404 Not Found)**:
```
"USER_NOT_FOUND"
```

**Response (403 Forbidden)**: Si no tiene permisos

---

## Endpoints de Personas

**Base URL**: `/api/v1/persons`

### 1. Obtener Todas las Personas
**GET** `/api/v1/persons`

Devuelve una lista de todas las personas registradas.

**Autorización**: Cualquier usuario autenticado

**Response (200 OK)**:
```json
[
  {
    "name": "string",
    "id": 0,
    "enabled": true,
    "territoriesInUse": [
      {
        "territoryName": "string",
        "territoryCode": "string",
        "givenDate": "2024-01-01T00:00:00Z"
      }
    ]
  }
]
```

---

### 2. Buscar Personas
**GET** `/api/v1/persons/{search}`

Busca personas por nombre.

**Autorización**: Cualquier usuario autenticado

**Path Parameters**:
- `search`: Término de búsqueda

**Query Parameters**:
- `take` (opcional): Número máximo de resultados (default: sin límite)

**Response (200 OK)**:
```json
[
  {
    "name": "string",
    "id": 0,
    "enabled": true,
    "territoriesInUse": []
  }
]
```

---

### 3. Añadir Persona
**POST** `/api/v1/persons`

Añade una nueva persona al sistema.

**Autorización**: SUPERADMIN, ADMIN

**Request Body**:
```json
{
  "name": "string"
}
```

**Response (200 OK)**: Sin contenido

**Response (400 Bad Request)**:
```
"Error message from domain exception"
```

---

### 4. Actualizar Persona
**PUT** `/api/v1/persons/{id}`

Actualiza la información de una persona.

**Autorización**: SUPERADMIN, ADMIN

**Path Parameters**:
- `id`: ID de la persona a actualizar

**Request Body**:
```json
{
  "name": "string",
  "enabled": true
}
```

**Response (200 OK)**: Sin contenido

**Response (400 Bad Request)**:
```
"Error message from domain exception"
```

---

### 5. Eliminar Persona
**DELETE** `/api/v1/persons/{name}`

Elimina una persona del sistema.

**Autorización**: SUPERADMIN, ADMIN

**Path Parameters**:
- `name`: Nombre de la persona a eliminar

**Response (200 OK)**: Sin contenido

---

## Endpoints de Territorios

**Base URL**: `/api/v1/territories`

### 1. Obtener Todos los Territorios (con filtros)
**GET** `/api/v1/territories/all`

Devuelve una lista de territorios con filtros opcionales.

**Autorización**: Cualquier usuario autenticado

**Query Parameters**:
- `term` (string, opcional): Término de búsqueda
- `inUse` (boolean, opcional): Filtrar por territorios en uso o libres
- `orderBy` (enum, opcional): Campo de ordenación (Name=1, Code=2, GivenDate=3)
- `orderByAscending` (boolean, opcional): Orden ascendente (default: true)
- `lastGivenDateFrom` (DateTime, opcional): Filtro de fecha de entrega desde
- `lastGivenDateTo` (DateTime, opcional): Filtro de fecha de entrega hasta

**Response (200 OK)**:
```json
[
  {
    "id": 0,
    "code": "string",
    "name": "string",
    "mapUrl": "string",
    "imgUrl": "string",
    "personName": "string",
    "givenDateUtc": "2024-01-01T00:00:00Z",
    "lastPickedDateUtc": "2024-01-01T00:00:00Z"
  }
]
```

---

### 2. Buscar Territorios
**GET** `/api/v1/territories`

Busca territorios por código o nombre.

**Autorización**: Cualquier usuario autenticado

**Query Parameters**:
- `search` (string): Término de búsqueda
- `onlyFreeTerritories` (boolean, opcional): Solo territorios libres (default: false)
- `onlyGivenTerritories` (boolean, opcional): Solo territorios entregados (default: false)
- `take` (int, opcional): Número máximo de resultados (default: sin límite)

**Response (200 OK)**:
```json
[
  {
    "id": 0,
    "code": "string",
    "name": "string",
    "mapUrl": "string",
    "imgUrl": "string",
    "personName": "string",
    "givenDateUtc": "2024-01-01T00:00:00Z",
    "lastPickedDateUtc": "2024-01-01T00:00:00Z"
  }
]
```

---

### 3. Obtener Territorio por ID
**GET** `/api/v1/territories/{idTerritory}`

Obtiene la información de un territorio específico por su ID.

**Autorización**: Cualquier usuario autenticado

**Path Parameters**:
- `idTerritory`: ID del territorio

**Response (200 OK)**:
```json
{
  "id": 0,
  "code": "string",
  "name": "string",
  "mapUrl": "string",
  "imgUrl": "string",
  "personName": "string",
  "givenDateUtc": "2024-01-01T00:00:00Z",
  "lastPickedDateUtc": "2024-01-01T00:00:00Z"
}
```

**Response (404 Not Found)**: Si no existe el territorio

---

### 4. Obtener Detalle del Territorio
**GET** `/api/v1/territories/{idTerritory}/detail`

Obtiene información detallada de un territorio, incluyendo historial y estadísticas.

**Autorización**: Cualquier usuario autenticado

**Path Parameters**:
- `idTerritory`: ID del territorio

**Response (200 OK)**:
```json
{
  "id": 0,
  "code": "string",
  "name": "string",
  "mapUrl": "string",
  "imgUrl": "string",
  "personName": "string",
  "lastPickedDateUtc": "2024-01-01T00:00:00Z",
  "givenDateUtc": "2024-01-01T00:00:00Z",
  "pickedCount": 0,
  "lastUser": "string",
  "timelineItems": [
    {
      "id": 0,
      "description": "string",
      "type": 1,
      "date": "2024-01-01T00:00:00Z"
    }
  ]
}
```

**Tipos de Timeline**:
- 1: Picked (Recogido)
- 2: Gave (Entregado)
- 3: Edited (Editado)
- 4: Added (Añadido)

**Response (404 Not Found)**: Si no existe el territorio

---

### 5. Obtener Territorio por MapUrl
**GET** `/api/v1/territories/map`

Obtiene un territorio por su URL de mapa.

**Autorización**: Cualquier usuario autenticado

**Query Parameters**:
- `mapUrl` (string): URL del mapa del territorio (se decodificará automáticamente)

**Response (200 OK)**:
```json
{
  "id": 0,
  "code": "string",
  "name": "string",
  "mapUrl": "string",
  "imgUrl": "string",
  "personName": "string",
  "givenDateUtc": "2024-01-01T00:00:00Z",
  "lastPickedDateUtc": "2024-01-01T00:00:00Z"
}
```

**Response (404 Not Found)**: Si no existe el territorio

---

### 6. Obtener Territorio por Código
**GET** `/api/v1/territories/code`

Obtiene un territorio por su código.

**Autorización**: Cualquier usuario autenticado

**Query Parameters**:
- `code` (string): Código del territorio

**Response (200 OK)**:
```json
{
  "id": 0,
  "code": "string",
  "name": "string",
  "mapUrl": "string",
  "imgUrl": "string",
  "personName": "string",
  "givenDateUtc": "2024-01-01T00:00:00Z",
  "lastPickedDateUtc": "2024-01-01T00:00:00Z"
}
```

**Response (404 Not Found)**: Si no existe el territorio

---

### 7. Añadir Territorio
**POST** `/api/v1/territories`

Añade un nuevo territorio al sistema.

**Autorización**: SUPERADMIN, ADMIN

**Request Body**:
```json
{
  "code": "string",
  "name": "string",
  "mapUrl": "string"
}
```

**Response (200 OK)**: Sin contenido

**Response (400 Bad Request)**:
```
"Error message from domain exception"
```

---

### 8. Editar Territorio
**POST** `/api/v1/territories/{idTerritory}`

Edita la información de un territorio existente.

**Autorización**: SUPERADMIN, ADMIN

**Path Parameters**:
- `idTerritory`: ID del territorio a editar

**Request Body**:
```json
{
  "code": "string",
  "name": "string",
  "mapUrl": "string"
}
```

**Response (200 OK)**: Sin contenido

**Response (400 Bad Request)**:
```
"INVALID_PARAMETERS" | "Error message from domain exception"
```

---

### 9. Eliminar Territorio
**DELETE** `/api/v1/territories/{idTerritory}`

Elimina un territorio del sistema.

**Autorización**: SUPERADMIN, ADMIN

**Path Parameters**:
- `idTerritory`: ID del territorio a eliminar

**Response (200 OK)**: Sin contenido

**Response (400 Bad Request)**:
```
"TERRITORY_NOT_FOUND"
```

---

### 10. Entregar Territorio
**POST** `/api/v1/territories/give-territory`

Asigna un territorio a una persona.

**Autorización**: Cualquier usuario autenticado

**Request Body**:
```json
{
  "territoryCode": "string",
  "personName": "string",
  "isCustomDate": false,
  "customDate": "2024-01-01T00:00:00Z"
}
```

**Notas**:
- `customDate` es requerido si `isCustomDate` es true
- La fecha de entrega no puede ser anterior a la última fecha de recogida

**Response (200 OK)**: Sin contenido

**Response (400 Bad Request)**:
```
"Fecha invalida"
"No existe el territorio a entregar"
"No existe la persona a la que entregar el territorio"
"La fecha de entrega no puede ser anterior a la última fecha de recogida"
```

---

### 11. Recoger Territorio
**POST** `/api/v1/territories/pick-territory`

Marca un territorio como recogido.

**Autorización**: Cualquier usuario autenticado

**Request Body**:
```json
{
  "territoryCode": "string",
  "isCustomDate": false,
  "customDate": "2024-01-01T00:00:00Z"
}
```

**Notas**:
- `customDate` es requerido si `isCustomDate` es true
- La fecha de recogida no puede ser anterior a la fecha de entrega

**Response (200 OK)**: Sin contenido

**Response (400 Bad Request)**:
```
"Fecha invalida"
"No existe el territorio a recoger"
"El territorio no esta asignado a nadie"
"La fecha de recogida no puede ser anterior a la fecha de entrega"
```

---

### 12. Generar Excel de Transacciones
**POST** `/api/v1/territories/generate-excel`

Genera un archivo Excel con las transacciones de territorios en un rango de fechas.

**Autorización**: Cualquier usuario autenticado

**Request Body**:
```json
{
  "start": "2024-01-01T00:00:00Z",
  "end": "2024-12-31T23:59:59Z"
}
```

**Response (200 OK)**:
- Content-Type: `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
- Content-Disposition: `attachment; filename=TerritoryTransactions_YYYYMMDDHHMMSS.xlsx`

**Response (400 Bad Request)**:
```
"START_DATE_GREATER_THAN_END"
```

---

### 13. Refrescar Imagen del Territorio
**POST** `/api/v1/territories/{idTerritory}/refresh-image`

Actualiza la imagen de un territorio desde su MapUrl.

**Autorización**: SUPERADMIN, ADMIN

**Path Parameters**:
- `idTerritory`: ID del territorio

**Response (200 OK)**: Sin contenido

**Response (404 Not Found)**:
```
"Error message from domain exception"
```

---

### 14. Obtener Estadísticas del Territorio
**GET** `/api/v1/territories/{id}/statistics`

Obtiene estadísticas de uso de un territorio específico.

**Autorización**: Cualquier usuario autenticado

**Path Parameters**:
- `id`: ID del territorio

**Response (200 OK)**:
```json
{
  "totalTerritories": 0,
  "usageRank": 0,
  "isHighUsage": false,
  "isLowUsage": false,
  "assignedTimePercentage": 0.0,
  "globalAverageAssignedTimePercentage": 0.0,
  "averageReassignmentTime": 0.0,
  "globalAverageReassignmentTime": 0.0,
  "averageHoldingTime": 0.0,
  "globalAverageHoldingTime": 0.0,
  "currentUnassignedTime": 0.0,
  "uniqueUsersCount": 0,
  "globalAverageUniqueUsersCount": 0.0
}
```

**Descripción de campos**:
- `totalTerritories`: Total de territorios en el sistema
- `usageRank`: Ranking de uso del territorio (1 = más usado)
- `isHighUsage`: Indica si el territorio tiene alto uso
- `isLowUsage`: Indica si el territorio tiene bajo uso
- `assignedTimePercentage`: Porcentaje de tiempo que el territorio ha estado asignado
- `globalAverageAssignedTimePercentage`: Promedio global de tiempo asignado
- `averageReassignmentTime`: Tiempo promedio entre asignaciones (en días)
- `globalAverageReassignmentTime`: Promedio global de tiempo de reasignación
- `averageHoldingTime`: Tiempo promedio que las personas mantienen el territorio (en días)
- `globalAverageHoldingTime`: Promedio global de tiempo de retención
- `currentUnassignedTime`: Días desde la última recogida (si no está asignado)
- `uniqueUsersCount`: Número de personas únicas que han usado el territorio
- `globalAverageUniqueUsersCount`: Promedio global de usuarios únicos

**Response (404 Not Found)**: Si no existe el territorio

---

### 15. Obtener Transacciones del Territorio
**GET** `/api/v1/territories/{territoryId}/transactions`

Obtiene el historial de transacciones de un territorio.

**Autorización**: Cualquier usuario autenticado

**Path Parameters**:
- `territoryId`: ID del territorio

**Response (200 OK)**:
```json
[
  {
    "transactionId": 0,
    "personId": 0,
    "givenDateUtc": "2024-01-01T00:00:00Z",
    "pickedDateUtc": "2024-01-15T00:00:00Z",
    "givenBy": "string",
    "pickedBy": "string",
    "territoryId": 0,
    "territoryName": "string",
    "personName": "string"
  }
]
```

**Response (404 Not Found)**: Si no existe el territorio

---

### 16. Obtener Sugerencias de Territorios
**GET** `/api/v1/territories/give-suggestions`

Obtiene sugerencias de territorios para entregar (territorios que llevan más tiempo sin asignarse).

**Autorización**: Cualquier usuario autenticado

**Response (200 OK)**:
```json
[
  {
    "id": 0,
    "code": "string",
    "name": "string",
    "mapUrl": "string",
    "imgUrl": "string",
    "lastPickedDate": "2024-01-01T00:00:00Z",
    "givenDate": null
  }
]
```

**Notas**:
- Devuelve hasta 3 territorios
- Incluye URL completa de la imagen (scheme://host/path)

---

## Endpoints de Transacciones

**Base URL**: `/api/v1/transactions`

### 1. Obtener Transacciones Recientes
**GET** `/api/v1/transactions/recent`

Obtiene las transacciones más recientes del sistema.

**Autorización**: Cualquier usuario autenticado

**Response (200 OK)**:
```json
[
  {
    "transactionId": 0,
    "personId": 0,
    "givenDateUtc": "2024-01-01T00:00:00Z",
    "pickedDateUtc": "2024-01-15T00:00:00Z",
    "givenBy": "string",
    "pickedBy": "string",
    "territoryId": 0,
    "territoryName": "string",
    "personName": "string"
  }
]
```

---

### 2. Obtener Transacción por ID
**GET** `/api/v1/transactions/{id}`

Obtiene una transacción específica por su ID.

**Autorización**: Cualquier usuario autenticado

**Path Parameters**:
- `id`: ID de la transacción

**Response (200 OK)**:
```json
{
  "transactionId": 0,
  "personId": 0,
  "givenDateUtc": "2024-01-01T00:00:00Z",
  "pickedDateUtc": "2024-01-15T00:00:00Z",
  "givenBy": "string",
  "pickedBy": "string",
  "territoryId": 0,
  "territoryName": "string",
  "personName": "string"
}
```

**Response (404 Not Found)**: Si no existe la transacción

---

### 3. Actualizar Transacción
**PUT** `/api/v1/transactions/{id}`

Actualiza una transacción existente.

**Autorización**: Cualquier usuario autenticado

**Path Parameters**:
- `id`: ID de la transacción

**Request Body**:
```json
{
  "personId": 0,
  "givenDateUtc": "2024-01-01T00:00:00Z",
  "pickedDateUtc": "2024-01-15T00:00:00Z"
}
```

**Response (200 OK)**:
```json
{
  "transactionId": 0,
  "personId": 0,
  "givenDateUtc": "2024-01-01T00:00:00Z",
  "pickedDateUtc": "2024-01-15T00:00:00Z",
  "givenBy": "string",
  "pickedBy": "string",
  "territoryId": 0,
  "territoryName": "string",
  "personName": "string"
}
```

**Response (400 Bad Request)**:
```
"Error message from domain exception"
```

**Response (404 Not Found)**: Si no existe la transacción

---

### 4. Eliminar Transacción
**DELETE** `/api/v1/transactions/{id}`

Elimina una transacción del sistema.

**Autorización**: Cualquier usuario autenticado

**Path Parameters**:
- `id`: ID de la transacción a eliminar

**Response (204 No Content)**: Eliminación exitosa

**Response (404 Not Found)**: Si no existe la transacción

---

## Endpoints de Logs de Acción

**Base URL**: `/api/v1/actionlogs`

### 1. Obtener Logs Paginados
**GET** `/api/v1/actionlogs`

Obtiene los logs de acciones del sistema con paginación.

**Autorización**: SUPERADMIN

**Query Parameters**:
- `pageNumber` (int, opcional): Número de página (default: 1)
- `pageSize` (int, opcional): Tamaño de página (default: 20)
- `sortField` (string, opcional): Campo por el que ordenar (default: "DateUtc")
- `sortOrder` (string, opcional): Orden de clasificación - "asc" o "desc" (default: "desc")

**Response (200 OK)**:
```json
{
  "data": [
    {
      "actionType": "GiveTerritory | PickTerritory | EditTerritory | DeleteTerritory | EditTransaction | DeleteTransaction",
      "dateUtc": "2024-01-01T00:00:00Z",
      "message": "string",
      "userName": "string",
      "successful": true
    }
  ],
  "totalCount": 0,
  "pageNumber": 1,
  "pageSize": 20,
  "last_page": 1
}
```

---

## Modelos de Datos

### ActionType (Enum)
```csharp
public enum ActionType
{
    GiveTerritory,
    PickTerritory,
    EditTerritory,
    DeleteTerritory,
    EditTransaction,
    DeleteTransaction
}
```

### RoleType (Enum)
```csharp
public enum RoleType
{
    Unknown = 0,
    SUPERADMIN = 1,
    ADMIN = 2,
    USER = 3
}
```

### FilterTerritoriesOrderByEnum (Enum)
```csharp
public enum FilterTerritoriesOrderByEnum
{
    Name = 1,
    Code = 2,
    GivenDate = 3
}
```

### TerritoryInfoTimelineType (Enum)
```csharp
public enum TerritoryInfoTimelineType
{
    Picked = 1,
    Gave = 2,
    Edited = 3,
    Added = 4
}
```

---

## Códigos de Error Comunes

### Errores de Autenticación
- **401 Unauthorized**: Token JWT no proporcionado o inválido
- **403 Forbidden**: Usuario sin permisos suficientes para la operación

### Errores de Validación
- **400 Bad Request**: Datos de entrada inválidos o reglas de negocio violadas
- **404 Not Found**: Recurso no encontrado

### Errores del Servidor
- **500 Internal Server Error**: Error interno del servidor

---

## Notas Adicionales

### Zonas Horarias
- Todas las fechas y horas se manejan en **UTC**
- Los campos de fecha terminan con el sufijo `Utc` para indicar esto

### Formato de Fechas
- Formato ISO 8601: `YYYY-MM-DDTHH:mm:ssZ`
- Ejemplo: `2024-01-15T14:30:00Z`

### Imágenes de Territorios
- Las URLs de imágenes son generadas automáticamente con el esquema completo
- Formato: `{scheme}://{host}{pathBase}/{imgUrl}`
- Las imágenes pueden ser refrescadas mediante el endpoint de refresh

### Transacciones
- Una transacción representa la asignación de un territorio a una persona
- `GivenDateUtc`: Fecha de entrega del territorio
- `PickedDateUtc`: Fecha de recogida del territorio (null si aún está asignado)
- Las fechas deben ser coherentes: la fecha de recogida no puede ser anterior a la de entrega

### Excel de Transacciones
- El archivo Excel agrupa las transacciones por territorio
- Cada territorio tiene sus propias columnas
- Las fechas se formatean como `yyyy-MM-dd`
