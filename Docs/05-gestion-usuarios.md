# Gestión de Usuarios

## 1. Lista de Usuarios (UsersComponent)

**Ruta:** `/users`  
**Archivo:** `src/app/components/users/users.component.ts`  
**Permisos:** SUPERADMIN y ADMIN

### Descripción
Pantalla administrativa para gestionar las cuentas de usuario del sistema. Permite editar roles, cambiar contraseñas y eliminar usuarios.

### Funcionalidad Principal
- Listar todos los usuarios del sistema
- Editar usuarios (nombre, rol, contraseña)
- Eliminar usuarios
- Control de permisos según rol del administrador
- Filtros y búsqueda en la tabla

### Tecnología Utilizada
Utiliza **Tabulator** para gestión avanzada de tablas.

### Columnas de la Tabla

| Columna | Campo | Descripción |
|---------|-------|-------------|
| ✏️ | - | Editar usuario |
| 🗑️ | - | Eliminar usuario |
| ID | UserID | Identificador único |
| Name | UserName | Nombre de usuario |
| Role | Role | Rol asignado (USER, ADMIN, SUPERADMIN) |

Todas las columnas (excepto íconos) tienen **filtro de búsqueda**.

### Roles del Sistema

#### Jerarquía de Roles
```
SUPERADMIN > ADMIN > USER
```

#### Permisos por Rol

| Rol | Puede Gestionar |
|-----|-----------------|
| **SUPERADMIN** | Administradores y Usuarios normales |
| **ADMIN** | Solo Usuarios normales |
| **USER** | Sin permisos de gestión |

**Regla importante:** Ningún rol puede gestionar SUPERADMIN.

### Funciones Principales

#### `getUsersData()`
Obtiene todos los usuarios:
```typescript
Flujo:
1. Muestra spinner
2. Llama a UserService.getAllUsers()
3. Almacena en array users
4. Construye tabla Tabulator
5. Oculta spinner
```

#### `buildTabulatorTable()`
Construye la tabla interactiva:
- Columnas con filtros por header
- Formatters para íconos
- Event handlers para editar/eliminar
- Layout adaptativo

#### `canConfigurate(userRoleToConfigurate)`
Determina si el usuario actual puede gestionar otro usuario:
```typescript
Lógica:
- SUPERADMIN nunca puede ser configurado
- ADMIN solo puede ser configurado por SUPERADMIN
- USER puede ser configurado por ADMIN o SUPERADMIN

Retorna: boolean
```

#### `setRolesCanIChange()`
Define qué roles puede asignar el administrador actual:
```typescript
SUPERADMIN puede asignar:
- ADMIN
- USER

ADMIN puede asignar:
- USER

USER:
- No puede asignar roles
```

### Edición de Usuarios

#### `openEditModal(idToEdit)`
Abre modal de edición:
```typescript
Acciones:
1. Busca el usuario por ID
2. Carga datos en el formulario
3. Determina si puede cambiar contraseña (canChangePassword)
4. Muestra el modal
```

#### `editUser()`
Guarda cambios del usuario:
```typescript
Parámetros editables:
- userName: string
- role: string

Flujo:
1. Valida formulario
2. Muestra spinner
3. Envía petición de actualización
4. Actualiza array local
5. Cierra modal
6. Muestra mensaje "Usuario editado"
```

#### Permisos de Edición

**Cambio de Contraseña:**
- SUPERADMIN puede cambiar contraseñas de ADMIN y USER
- ADMIN puede cambiar contraseñas de USER
- Nadie puede cambiar contraseña de SUPERADMIN

### Cambio de Contraseña

#### `canChangePassword`
Boolean que determina si se muestra la opción de cambiar contraseña:
```typescript
Se permite si:
- Usuario actual es SUPERADMIN y usuario a editar es ADMIN o USER
- Usuario actual es ADMIN y usuario a editar es USER
```

#### `changePassword()`
Cambia la contraseña de un usuario:
```typescript
Parámetros:
- userId: string
- newPassword: string

Flujo:
1. Valida campo newPassword
2. Muestra spinner
3. Envía petición al servidor
4. Cierra modal
5. Resetea campo de contraseña
6. Muestra mensaje de éxito/error
```

### Eliminación de Usuarios

#### `openDeleteUserModal(idToDelete)`
Abre confirmación de eliminación:
- Guarda ID temporalmente
- Muestra modal de confirmación

#### `deleteUser()`
Ejecuta la eliminación:
```typescript
Flujo:
1. Muestra spinner
2. Cierra modal
3. Envía petición de eliminación
4. Recarga lista de usuarios
5. Muestra mensaje "Usuario eliminado"
```

### Formulario de Edición

El formulario reactivo incluye:
```typescript
editForm: FormGroup = {
  userName: FormControl (required),
  role: FormControl (required),
  newPassword: FormControl (opcional)
}
```

### Manejo de Errores

#### `handleEditError(error)`
Gestiona errores de edición:

| Error | Acción |
|-------|--------|
| `USERNAME_IN_USE` | Marca campo userName con error `usernameExists` |
| Otros | Muestra "Error desconocido" |

### Flujo de Trabajo: Editar Usuario

1. Administrador hace clic en ícono de editar
2. Modal se abre con datos actuales
3. Administrador modifica:
   - Nombre de usuario
   - Rol (según permisos)
   - Contraseña (si tiene permiso)
4. Hace clic en "Guardar"
5. Sistema valida y actualiza
6. Modal se cierra
7. Tabla se actualiza automáticamente

### Flujo de Trabajo: Eliminar Usuario

1. Administrador hace clic en ícono de eliminar
2. Modal de confirmación aparece
3. Administrador confirma la eliminación
4. Usuario es eliminado permanentemente
5. Lista se recarga

### Estados de la Vista
- **Cargando**: Spinner mientras obtiene usuarios
- **Lista completa**: Todos los usuarios visibles
- **Editando**: Modal de edición abierto
- **Cambiando contraseña**: Campo de nueva contraseña activo
- **Confirmando eliminación**: Modal de confirmación visible
- **Actualizando**: Guardando cambios

---

## 2. Configuración de Usuario (UserConfigurationComponent)

**Ruta:** `/user-configuration`  
**Archivo:** `src/app/components/user-configuration/user-configuration.component.ts`

### Descripción
Pantalla para que cada usuario cambie su propia contraseña. Accesible para todos los usuarios autenticados.

### Funcionalidad Principal
- Cambiar la contraseña del usuario actual
- Validación de contraseña actual
- Validación de requisitos de nueva contraseña
- Auto-gestión sin necesidad de administrador

### Campos del Formulario

El formulario está en `userService.changePasswordForm`:

#### **OldPassword** (Contraseña Actual)
- Contraseña actual del usuario
- Requerida
- Se valida contra el servidor

#### **NewPasswords.Password** (Nueva Contraseña)
- Nueva contraseña deseada
- Requerida
- Debe cumplir requisitos de longitud mínima

#### **NewPasswords.ConfirmPassword** (Confirmar Contraseña)
- Confirmación de la nueva contraseña
- Debe coincidir con Password

### Funciones Principales

#### `changePassword()`
Procesa el cambio de contraseña:
```typescript
Flujo:
1. Valida que el formulario sea válido
2. Muestra spinner
3. Envía petición al servidor
4. Si éxito:
   - Resetea formulario
   - Muestra mensaje "Contraseña cambiada"
   - Limpia flag submitted
5. Si error:
   - Procesa error específico
   - Muestra mensaje correspondiente
```

### Validaciones y Errores

#### Errores del Servidor

| Error | Campo Afectado | Mensaje |
|-------|----------------|---------|
| `PasswordMismatch` | OldPassword | La contraseña actual es incorrecta |
| `PasswordTooShort` | NewPasswords.Password | La contraseña es demasiado corta |
| Otros | - | Error cambiando la contraseña |

**Nota:** Los errores vienen como string separado por comas, se procesan con `split(',')`.

### Requisitos de Contraseña

Aunque el componente no define explícitamente los requisitos, típicamente incluyen:
- Longitud mínima (validada como `PasswordTooShort`)
- Puede incluir complejidad (mayúsculas, números, símbolos)

### Seguridad

- **Verificación de identidad**: Requiere contraseña actual
- **Auto-gestión**: No requiere intervención de administrador
- **Validación en servidor**: La contraseña se valida en el backend
- **No expone contraseñas**: Las contraseñas nunca se muestran en texto plano

### Flujo de Trabajo Típico

1. Usuario accede a su configuración
2. Ingresa su contraseña actual
3. Ingresa nueva contraseña dos veces
4. Sistema valida:
   - Contraseña actual correcta
   - Nueva contraseña cumple requisitos
   - Ambas nuevas contraseñas coinciden
5. Si válido:
   - Actualiza la contraseña
   - Usuario puede iniciar sesión con nueva contraseña
6. Si inválido:
   - Muestra error específico
   - Usuario corrige y reintenta

### Estados de la Vista
- **Formulario vacío**: Esperando entrada
- **Validando**: Verificando contraseña actual
- **Guardando**: Spinner activo
- **Error**: Mostrando mensajes de validación
- **Éxito**: Contraseña cambiada, formulario limpio

### Diferencias con UsersComponent

| Aspecto | UserConfiguration | Users |
|---------|-------------------|-------|
| Usuario objetivo | El mismo usuario | Otros usuarios |
| Contraseña actual | Requerida | No requerida |
| Permisos | Todos | Solo ADMIN/SUPERADMIN |
| Cambiar rol | No | Sí |
| Cambiar nombre | No | Sí |

### Mejores Prácticas

Para el usuario:
- Usar contraseñas seguras
- No reutilizar contraseñas antiguas
- Cambiar periódicamente la contraseña
- No compartir credenciales

---

*Última actualización: 2025-12-03*
