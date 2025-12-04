# Autenticación y Acceso

## 1. Pantalla de Inicio de Sesión (LoginComponent)

**Ruta:** `/login`  
**Archivo:** `src/app/components/login/login.component.ts`

### Descripción
Pantalla de inicio de sesión donde los usuarios ingresan sus credenciales para acceder a la aplicación.

### Funcionalidad Principal
- Permite a los usuarios autenticarse con nombre de usuario y contraseña
- Valida las credenciales contra el servidor
- Al autenticarse exitosamente, guarda el token JWT en localStorage
- Redirige automáticamente al dashboard (`/home`) si el usuario ya está autenticado
- Muestra mensajes de error si las credenciales son incorrectas

### Campos del Formulario
- **UserName**: Nombre de usuario (requerido)
- **Password**: Contraseña (requerido)

### Flujo de Trabajo
1. El usuario ingresa sus credenciales
2. El sistema valida el formulario
3. Se envía una petición al servidor para autenticar
4. Si es exitoso:
   - Se guarda el token en localStorage
   - Se redirige al dashboard
5. Si falla:
   - Se muestra un mensaje de error "Usuario o contraseña incorrecta"

### Estados
- **Cargando**: Muestra spinner mientras se validan las credenciales
- **Error**: Muestra mensaje de error si la autenticación falla
- **Autenticado**: Redirige automáticamente al home

---

## 2. Pantalla de Registro (RegistrationComponent)

**Ruta:** `/registration`  
**Archivo:** `src/app/components/registration/registration.component.ts`  
**Permisos:** Solo SUPERADMIN y ADMIN

### Descripción
Pantalla para registrar nuevos usuarios en el sistema. Solo accesible por administradores.

### Funcionalidad Principal
- Permite crear nuevas cuentas de usuario
- Valida que el nombre de usuario no exista
- Requiere permisos de administrador para acceder
- Muestra mensajes de éxito o error según el resultado

### Campos del Formulario
Los campos están definidos en `userService.formModel`:
- Nombre de usuario
- Contraseña
- Confirmación de contraseña
- Rol del usuario (opcional, según permisos)

### Validaciones
- **Nombre de usuario**: Debe ser único en el sistema
- **Contraseña**: Debe cumplir requisitos mínimos de seguridad
- **Campos requeridos**: Todos los campos son obligatorios

### Flujo de Trabajo
1. El administrador completa el formulario de registro
2. El sistema valida los datos ingresados
3. Se envía la petición al servidor
4. Si es exitoso:
   - Se resetea el formulario
   - Se muestra mensaje "Registro con éxito"
5. Si falla:
   - Se muestra error específico (ej: "Usuario ya existe")

### Manejo de Errores
- **DuplicateUserName**: El nombre de usuario ya existe
- **Error de validación**: Campos inválidos o incompletos

---

## 3. Pantalla de Acceso Denegado (ForbiddenComponent)

**Ruta:** `/forbidden`  
**Archivo:** `src/app/components/forbidden/forbidden.component.ts`

### Descripción
Pantalla que se muestra cuando un usuario intenta acceder a una funcionalidad para la que no tiene permisos.

### Funcionalidad Principal
- Informa al usuario que no tiene permisos suficientes
- Proporciona un mensaje claro sobre la restricción de acceso
- Puede incluir opciones para regresar o contactar al administrador

### Cuándo se Muestra
- Cuando un usuario sin permisos intenta acceder a:
  - Gestión de usuarios
  - Logs de acciones
  - Registro de nuevos usuarios
  - Agregar territorios
  - Cualquier otra funcionalidad restringida por rol

### Roles y Restricciones
La aplicación tiene tres roles principales:
- **SUPERADMIN**: Acceso completo
- **ADMIN**: Acceso limitado a funciones administrativas
- **USER**: Acceso básico a funciones de usuario

---

## Sistema de Autenticación

### AuthGuard
Protege las rutas que requieren autenticación. Todas las rutas principales están bajo el componente `LoggedComponent` que implementa `canActivateChild`.

### AuthInterceptor
Intercepta todas las peticiones HTTP para:
- Agregar el token JWT en los headers
- Manejar errores de autenticación
- Redirigir al login si el token expira

### Tokens JWT
- Se almacenan en `localStorage` con la key `'token'`
- Se envían automáticamente en cada petición
- Se validan en el servidor para cada operación

### Flujo de Seguridad
1. Usuario intenta acceder a una ruta protegida
2. AuthGuard verifica si existe token válido
3. Si no hay token → Redirige a `/login`
4. Si hay token → Verifica permisos del rol
5. Si no tiene permisos → Redirige a `/forbidden`
6. Si tiene permisos → Permite acceso

---

*Última actualización: 2025-12-03*
