# Guía Rápida de Pantallas

Esta es una referencia rápida de todas las pantallas de la aplicación Territory Tool.

---

## 🔐 Autenticación

| Pantalla | Ruta | Acceso | Descripción Breve |
|----------|------|--------|-------------------|
| **Login** | `/login` | Público | Inicio de sesión con usuario y contraseña |
| **Registro** | `/registration` | Admin+ | Crear nuevas cuentas de usuario |
| **Acceso Denegado** | `/forbidden` | Todos | Error cuando no hay permisos suficientes |

---

## 🏠 Pantallas Principales

| Pantalla | Ruta | Acceso | Descripción Breve |
|----------|------|--------|-------------------|
| **Dashboard** | `/home` | Autenticado | Vista principal con territorios antiguos (>4 meses) |
| **Lista de Territorios** | `/territories` | Autenticado | Todos los territorios con filtros y búsqueda |
| **Detalle de Territorio** | `/territory/:id` | Autenticado | Información completa, timeline, estadísticas |

---

## 🗺️ Gestión de Territorios

| Pantalla | Ruta | Acceso | Descripción Breve |
|----------|------|--------|-------------------|
| **Agregar Territorio** | `/add-territory` | Admin+ | Crear nuevo territorio (con scanner QR) |
| **Asignar Territorio** | `/change-territory` | Autenticado | Entregar territorio a una persona |
| **Asignar (con código)** | `/change-territory/:code` | Autenticado | Asignar territorio específico pre-seleccionado |
| **Recoger Territorio** | `/pick-territory` | Autenticado | Registrar devolución de territorio |
| **Recoger (con código)** | `/pick-territory/:code` | Autenticado | Recoger territorio específico pre-seleccionado |

---

## 👥 Gestión de Personas

| Pantalla | Ruta | Acceso | Descripción Breve |
|----------|------|--------|-------------------|
| **Lista de Personas** | `/persons` | Autenticado | Todas las personas con territorios activos |
| **Agregar Persona** | `/add-person` | Admin+ | Registrar nueva persona |

---

## 👤 Gestión de Usuarios

| Pantalla | Ruta | Acceso | Descripción Breve |
|----------|------|--------|-------------------|
| **Lista de Usuarios** | `/users` | Admin+ | Gestionar cuentas de usuario |
| **Mi Configuración** | `/user-configuration` | Autenticado | Cambiar mi propia contraseña |

---

## 📊 Transacciones y Reportes

| Pantalla | Ruta | Acceso | Descripción Breve |
|----------|------|--------|-------------------|
| **Transacciones Recientes** | `/recent-transactions` | Autenticado | Últimas entregas/recogidas del sistema |
| **Transacciones de Territorio** | `/territory/:id/transactions` | Autenticado | Historial completo de un territorio |
| **Generar Reporte** | `/generate-report` | Autenticado | Crear Excel con transacciones por rango de fechas |
| **Logs de Acciones** | `/action-logs` | SuperAdmin | Auditoría completa del sistema |

---

## 🔧 Componentes Modales

Estos no son rutas, sino componentes que se abren como modales:

| Modal | Componente | Descripción |
|-------|-----------|-------------|
| **Editar Territorio** | `EditTerritoryModalComponent` | Modificar datos de territorio |
| **Eliminar Territorio** | `DeleteTerritoryModalComponent` | Confirmar eliminación de territorio |
| **Editar Transacción** | `EditTransactionModalComponent` | Corregir datos de transacción |
| **Editar Persona** | Dentro de `PersonsComponent` | Modificar nombre y estado de persona |
| **Eliminar Persona** | Dentro de `PersonsComponent` | Confirmar eliminación de persona |

---

## 📱 Componentes de Layout

Estos componentes estructuran el layout de la aplicación:

| Componente | Ubicación | Descripción |
|-----------|-----------|-------------|
| **Navbar** | Superior | Barra de navegación con usuario y opciones |
| **Sidebar** | Lateral izquierda | Menú principal de navegación |
| **Logged** | Contenedor | Layout que envuelve todas las rutas autenticadas |
| **Territory Card** | Reutilizable | Tarjeta visual para mostrar territorios |

---

## 🎯 Referencia Rápida por Funcionalidad

### Ver Información
- Dashboard (`/home`)
- Lista de Territorios (`/territories`)
- Detalle de Territorio (`/territory/:id`)
- Lista de Personas (`/persons`)
- Lista de Usuarios (`/users`)
- Transacciones Recientes (`/recent-transactions`)
- Logs (`/action-logs`)

### Crear
- Agregar Territorio (`/add-territory`)
- Agregar Persona (`/add-person`)
- Registrar Usuario (`/registration`)
- Asignar Territorio (`/change-territory`)

### Modificar
- Editar Territorio (modal)
- Editar Transacción (modal)
- Editar Persona (modal)
- Editar Usuario (modal en `/users`)
- Cambiar Contraseña (`/user-configuration`)

### Eliminar
- Eliminar Territorio (modal)
- Eliminar Transacción (en `/territory/:id/transactions`)
- Eliminar Persona (modal)
- Eliminar Usuario (modal en `/users`)

### Reportes
- Generar Excel (`/generate-report`)
- Ver Logs (`/action-logs`)
- Ver Timeline (en `/territory/:id`)

---

## 🔑 Matrices de Permisos

### USER (Usuario Regular)

| Funcionalidad | Permitido |
|---------------|-----------|
| Ver territorios | ✅ |
| Ver personas | ✅ |
| Asignar territorio | ✅ |
| Recoger territorio | ✅ |
| Ver transacciones recientes | ✅ |
| Generar reportes | ✅ |
| Cambiar mi contraseña | ✅ |
| Agregar territorio | ❌ |
| Eliminar territorio | ❌ |
| Agregar persona | ❌ |
| Gestionar usuarios | ❌ |
| Ver logs del sistema | ❌ |

### ADMIN (Administrador)

| Funcionalidad | Permitido |
|---------------|-----------|
| Todo lo de USER | ✅ |
| Agregar territorio | ✅ |
| Editar territorio | ✅ |
| Eliminar territorio | ✅ |
| Agregar persona | ✅ |
| Editar persona | ✅ |
| Eliminar persona | ✅ |
| Crear usuarios USER | ✅ |
| Editar usuarios USER | ✅ |
| Eliminar usuarios USER | ✅ |
| Crear usuarios ADMIN | ❌ |
| Ver logs del sistema | ❌ |

### SUPERADMIN (Super Administrador)

| Funcionalidad | Permitido |
|---------------|-----------|
| Todo lo de ADMIN | ✅ |
| Crear usuarios ADMIN | ✅ |
| Editar usuarios ADMIN | ✅ |
| Cambiar contraseña de ADMIN | ✅ |
| Ver logs del sistema | ✅ |
| Control total | ✅ |

**Nota:** Ningún rol puede gestionar cuentas SUPERADMIN (protección de seguridad).

---

## 📋 Checklist de Funcionalidades

### ✅ Gestión de Territorios
- [x] Ver lista completa
- [x] Filtrar por estado (libre/asignado)
- [x] Buscar por nombre
- [x] Ver detalle completo
- [x] Agregar nuevo territorio
- [x] Editar territorio existente
- [x] Eliminar territorio
- [x] Escanear QR para URL de mapa
- [x] Actualizar imagen de territorio
- [x] Ver estadísticas de territorio
- [x] Ver timeline de transacciones

### ✅ Asignación y Recogida
- [x] Asignar territorio a persona
- [x] Recoger territorio
- [x] Fecha personalizada (backdating)
- [x] Validación de fechas coherentes
- [x] Escanear QR para seleccionar territorio
- [x] Sugerencias de territorios prioritarios
- [x] Búsqueda con autocompletado

### ✅ Gestión de Personas
- [x] Ver lista con territorios activos
- [x] Agregar persona
- [x] Editar persona
- [x] Eliminar persona
- [x] Habilitar/deshabilitar persona
- [x] Ver sub-tabla de territorios por persona

### ✅ Gestión de Usuarios
- [x] Listar usuarios
- [x] Registrar nuevo usuario
- [x] Editar usuario (nombre, rol)
- [x] Cambiar contraseña de usuario
- [x] Eliminar usuario
- [x] Control de permisos por rol
- [x] Auto-gestión (cambiar mi contraseña)

### ✅ Transacciones
- [x] Ver transacciones recientes
- [x] Ver transacciones por territorio
- [x] Editar transacción
- [x] Eliminar transacción
- [x] Validación de datos coherentes

### ✅ Reportes y Auditoría
- [x] Generar reporte Excel por rango de fechas
- [x] Ver logs de auditoría
- [x] Paginación y ordenamiento
- [x] Filtros en logs
- [x] Ver acciones exitosas vs fallidas

### ✅ Seguridad
- [x] Autenticación JWT
- [x] Control de acceso basado en roles
- [x] Guards en rutas
- [x] Interceptor de peticiones
- [x] Logs de auditoría
- [x] Redirección a forbidden si no hay permisos

### ✅ UX/UI
- [x] Spinners de carga
- [x] Notificaciones toast
- [x] Confirmaciones para acciones destructivas
- [x] Validaciones en tiempo real
- [x] Mensajes de error descriptivos
- [x] Navegación intuitiva
- [x] Layout responsivo

---

## 🚀 Accesos Rápidos por Tarea

### "Necesito asignar un territorio"
1. Ve a `/change-territory`
2. O desde `/territories` → click en territorio → "Asignar"
3. O desde `/territory/:id` → botón "Asignar"

### "Necesito recoger un territorio"
1. Ve a `/pick-territory`
2. O desde `/territory/:id` → botón "Recoger"

### "Necesito ver qué territorios están muy antiguos"
1. Inicia sesión 
2. Dashboard (`/home`) los muestra automáticamente

### "Necesito agregar una persona nueva"
1. Ve a `/add-person`
2. Escribe el nombre
3. Confirma

### "Necesito generar un reporte mensual"
1. Ve a `/generate-report`
2. Selecciona rango de fechas
3. Descarga Excel

### "Necesito ver quién hizo qué"
1. Ve a `/action-logs` (solo SuperAdmin)
2. Filtra y ordena según necesites

### "Olvidé mi contraseña"
1. Contacta al administrador
2. El administrador puede cambiártela desde `/users`

### "Necesito cambiar mi contraseña"
1. Ve a `/user-configuration`
2. Ingresa contraseña actual y nueva
3. Confirma

---

*Última actualización: 2025-12-03*
