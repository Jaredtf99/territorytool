# Documentación de Pantallas - Territory Tool

## Índice

Esta documentación describe todas las pantallas y componentes de la aplicación Angular Territory Tool.

### 📋 Documentos por Categoría

1. **[Autenticación y Acceso](./01-autenticacion.md)**
   - Inicio de sesión
   - Registro de usuarios
   - Pantalla de acceso denegado

2. **[Pantallas Principales](./02-pantallas-principales.md)**
   - Dashboard/Home
   - Vista de territorios
   - Detalle de territorio

3. **[Gestión de Territorios](./03-gestion-territorios.md)**
   - Agregar territorio
   - Editar territorio
   - Eliminar territorio
   - Asignar territorio
   - Recoger territorio

4. **[Gestión de Personas](./04-gestion-personas.md)**
   - Lista de personas
   - Agregar persona
   - Editar persona

5. **[Gestión de Usuarios](./05-gestion-usuarios.md)**
   - Lista de usuarios
   - Configuración de usuario
   - Cambiar contraseña

6. **[Transacciones y Reportes](./06-transacciones-reportes.md)**
   - Transacciones recientes
   - Transacciones de territorio
   - Generar reporte
   - Logs de acciones

7. **[Componentes Auxiliares](./07-componentes-auxiliares.md)**
   - Navbar
   - Sidebar
   - Modales

## Resumen de la Aplicación

**Territory Tool** es una aplicación web desarrollada en Angular para la gestión de territorios. Permite administrar territorios, asignarlos a diferentes personas, hacer seguimiento de las transacciones y generar reportes.

### Características Principales

- ✅ Gestión completa de territorios (CRUD)
- ✅ Asignación y recogida de territorios
- ✅ Gestión de personas y usuarios
- ✅ Sistema de roles (SuperAdmin, Admin, User)
- ✅ Historial de transacciones
- ✅ Generación de reportes en Excel
- ✅ Escaneo de códigos QR
- ✅ Control de acciones y auditoría

### Roles de Usuario

- **SUPERADMIN**: Acceso completo a todas las funcionalidades
- **ADMIN**: Puede gestionar territorios, personas y usuarios normales
- **USER**: Puede ver y gestionar territorios básicos

## Navegación

La aplicación utiliza las siguientes rutas principales:

| Ruta | Componente | Descripción | Roles Permitidos |
|------|-----------|-------------|------------------|
| `/login` | LoginComponent | Inicio de sesión | Todos |
| `/home` | HomeComponent | Dashboard principal | Autenticado |
| `/territories` | TerritoriesComponent | Lista de territorios | Autenticado |
| `/territory/:id` | TerritoryDetailComponent | Detalle de territorio | Autenticado |
| `/add-territory` | AddTerritoryComponent | Agregar territorio | SUPERADMIN, ADMIN |
| `/change-territory` | ChangeTerritoryComponent | Asignar territorio | Autenticado |
| `/pick-territory` | PickTerritoryComponent | Recoger territorio | Autenticado |
| `/persons` | PersonsComponent | Lista de personas | Autenticado |
| `/add-person` | AddPersonComponent | Agregar persona | SUPERADMIN, ADMIN |
| `/users` | UsersComponent | Gestión de usuarios | SUPERADMIN, ADMIN |
| `/registration` | RegistrationComponent | Registrar usuario | SUPERADMIN, ADMIN |
| `/generate-report` | GenerateReportComponent | Generar reportes | Autenticado |
| `/action-logs` | ViewActionlogsComponent | Logs del sistema | SUPERADMIN |

---

*Última actualización: 2025-12-03*
