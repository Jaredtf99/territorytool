# Componentes Auxiliares

## 1. Navbar (NavbarComponent)

**Archivo:** `src/app/components/navbar/navbar.component.ts`  
**Tipo:** Componente de Layout

### Descripción
Barra de navegación superior de la aplicación. Visible en todas las pantallas cuando el usuario está autenticado.

### Funcionalidad Principal
- Mostrar información del usuario actual
- Acceso rápido a opciones de usuario
- Navegación a configuración
- Cerrar sesión
- Branding de la aplicación

### Elementos Típicos

#### Marca/Logo
- Nombre de la aplicación
- Logo (si existe)
- Link al dashboard

#### Menú de Usuario
Típicamente incluye:
- Nombre del usuario actual
- Rol del usuario
- Opciones:
  - Configuración de cuenta
  - Cambiar contraseña
  - Cerrar sesión

### Servicios Utilizados
- **UserService**: Para obtener datos del usuario
- **Router**: Para navegación

### Estados
- **Usuario autenticado**: Muestra nombre y opciones
- **Cargando**: Mientras obtiene datos del usuario

---

## 2. Sidebar (SidebarComponent)

**Archivo:** `src/app/components/sidebar/sidebar.component.ts`  
**Tipo:** Componente de Layout

### Descripción
Barra lateral de navegación que proporciona acceso rápido a todas las funcionalidades del sistema.

### Funcionalidad Principal
- Menú de navegación principal
- Organización por categorías
- Visibilidad basada en permisos
- Estado colapsable/expandible (en móviles)

### Estructura del Menú

#### 📊 Dashboard
- Home/Inicio

#### 🗺️ Territorios
- Ver todos los territorios
- Agregar territorio (Admin/SuperAdmin)
- Asignar territorio
- Recoger territorio

#### 👥 Personas
- Ver personas
- Agregar persona (Admin/SuperAdmin)

#### 👤 Usuarios (Admin/SuperAdmin)
- Gestión de usuarios
- Registrar usuario

#### 📈 Reportes
- Transacciones recientes
- Generar reporte
- Logs de acciones (SuperAdmin)

#### ⚙️ Configuración
- Mi configuración
- Cambiar contraseña

### Lógica de Permisos

El sidebar muestra/oculta opciones según el rol:
```typescript
USER: 
- Dashboard, Territorios (ver/asignar/recoger), 
- Personas (ver), Configuración

ADMIN: 
- Todo lo de USER +
- Agregar territorio, Agregar persona
- Gestión de usuarios, Registrar usuario
- Reportes

SUPERADMIN:
- Todo +
- Logs de acciones
```

### Funciones Principales

#### Navegación
Utiliza `routerLink` de Angular para navegación SPA.

#### Estado Colapsado
En dispositivos móviles, puede colapsar/expandir.

### Servicios Utilizados
- **UserService**: Para verificar permisos
- **Router**: Para marcar ruta activa

---

## 3. Logged Component (LoggedComponent)

**Archivo:** `src/app/components/logged/logged.component.ts`  
**Tipo:** Layout Container

### Descripción
Componente contenedor que envuelve todas las rutas autenticadas. Incluye navbar, sidebar y el área de contenido.

### Funcionalidad Principal
- Layout principal de la aplicación
- Contenedor de rutas autenticadas
- Guard de autenticación
- Estructura consistente en todas las páginas

### Estructura HTML Típica
```html
<navbar></navbar>
<div class="container-fluid">
  <sidebar></sidebar>
  <main>
    <router-outlet></router-outlet>
  </main>
</div>
```

### Router Outlet
`<router-outlet>` es donde se renderizan los componentes de las rutas hijas.

### Guard de Autenticación
Implementa `canActivateChild` con AuthGuard:
- Verifica token JWT
- Verifica permisos por ruta
- Redirige si no está autenticado

---

## 4. Territory Card (TerritoryCardComponent)

**Archivo:** `src/app/components/territory-card/territory-card.component.ts`  
**Tipo:** Componente de Presentación

### Descripción
Componente reutilizable para mostrar la información de un territorio en formato de tarjeta (card).

### Funcionalidad Principal
- Mostrar vista resumida de un territorio
- Reutilizable en listas y grids
- Click para ver detalles
- Estado visual (libre/asignado)

### Propiedades de Entrada

```typescript
@Input() territory: Territory
```

### Información Mostrada

#### Datos Básicos
- Código del territorio
- Nombre del territorio
- Imagen/mapa (thumbnail)

#### Estado Visual
- **Libre**: Color verde o distintivo
- **Asignado**: Color diferente
- Badge o indicador de estado

#### Datos Adicionales
- Persona asignada (si aplica)
- Fecha de última asignación
- Tiempo desde última actividad

### Eventos

```typescript
@Output() territoryClicked: EventEmitter<number>
```

Emite el ID del territorio cuando se hace click.

### Uso Típico

En `TerritoriesComponent`:
```html
<territory-card 
  *ngFor="let t of territories"
  [territory]="t"
  (territoryClicked)="detail($event)">
</territory-card>
```

### Estilos
Típicamente usa:
- CSS Grid o Flexbox para layout
- Sombras y bordes para efecto de card
- Hover effects para interactividad
- Responsive design

---

## Modales de Confirmación

Los siguientes componentes ya fueron documentados pero son auxiliares importantes:

### EditTerritoryModalComponent
Ver [Gestión de Territorios](./03-gestion-territorios.md#2-editar-territorio-editTerritoryModalComponent)

### DeleteTerritoryModalComponent
Ver [Gestión de Territorios](./03-gestion-territorios.md#3-eliminar-territorio-deleteTerritoryModalComponent)

### EditTransactionModalComponent
Ver [Transacciones y Reportes](./06-transacciones-reportes.md#3-modal-de-edición-de-transacción-editTransactionModalComponent)

---

## Servicios Compartidos

Aunque no son componentes visuales, son esenciales para el funcionamiento:

### UserService
**Archivo:** `src/app/shared/user.service.ts`

Gestiona:
- Autenticación (login/logout)
- Registro de usuarios
- Obtener usuario actual
- Gestión de roles
- Cambio de contraseña
- Token JWT

### TerritoryService
**Archivo:** `src/app/shared/territory.service.ts`

Gestiona:
- CRUD de territorios
- Búsqueda y filtrado
- Asignación y recogida
- Estadísticas
- Generación de reportes
- Actualización de imágenes

### PersonService
**Archivo:** `src/app/shared/person.service.ts`

Gestiona:
- CRUD de personas
- Búsqueda
- Obtener territorios por persona
- Habilitar/deshabilitar

### TerritoryTransactionService
**Archivo:** `src/app/services/territory-transaction.service.ts`

Gestiona:
- Obtener transacciones
- Transacciones recientes
- Transacciones por territorio
- Editar transacciones
- Eliminar transacciones

---

## Guards y Interceptors

### AuthGuard
**Archivo:** `src/app/auth/auth.guard.ts`

Protege rutas:
```typescript
canActivate(): boolean
canActivateChild(): boolean
```

Verifica:
1. Existencia de token
2. Validez del token
3. Permisos del rol para la ruta

Acciones:
- Permite acceso si es válido
- Redirige a `/login` si no hay token
- Redirige a `/forbidden` si no hay permisos

### AuthInterceptor
**Archivo:** `src/app/auth/auth.interceptor.ts`

Intercepta peticiones HTTP:
```typescript
intercept(req: HttpRequest, next: HttpHandler): Observable<HttpEvent>
```

Funciones:
1. Agrega token JWT a headers
2. Maneja errores 401 (no autorizado)
3. Maneja errores 403 (prohibido)
4. Redirige al login si el token expira

---

## Utilidades y Helpers

### Globals
**Archivo:** `src/app/globals.ts`

Servicio inyectable con variables globales accesibles en toda la aplicación.

### AppService
**Archivo:** `src/app/shared/app.service.ts`

Utilidades generales:
- `clearXButtonFromNgSelect()`: Limpia el botón X de ng-select
- Otras funciones helper

---

## Librerías de Terceros Utilizadas

### UI/UX
- **ngx-spinner**: Indicadores de carga
- **ngx-toastr**: Notificaciones toast
- **ng-select**: Selectores con búsqueda
- **tabulator-tables**: Tablas avanzadas
- **ngx-bootstrap**: Componentes Bootstrap para Angular
- **ngx-timeago**: Formateo de fechas relativas

### Funcionalidad
- **ngx-scanner-qrcode**: Escaneo de códigos QR
- **rxjs**: Programación reactiva

### Styles
- **Bootstrap**: Framework CSS
- **Font Awesome**: Iconos

---

## Estructura de Archivos Estándar

Cada componente típicamente incluye:

```
component-name/
├── component-name.component.ts      # Lógica
├── component-name.component.html    # Template
├── component-name.component.css     # Estilos
└── component-name.component.spec.ts # Tests
```

---

*Última actualización: 2025-12-03*
