# Resumen y Casos de Uso

## Diagrama de Flujo General

```
┌─────────────┐
│   Login     │
│  /login     │
└──────┬──────┘
       │
       ├─ Token JWT guardado
       │
       ▼
┌─────────────────────────────────────────┐
│          Logged Component               │
│  (Navbar + Sidebar + Router Outlet)     │
└─────────────────────────────────────────┘
       │
       ├─── Dashboard (/home)
       │    └─ Ver territorios antiguos
       │
       ├─── Territorios (/territories)
       │    ├─ Ver todos
       │    ├─ Filtrar (libres/en uso)
       │    ├─ Detalle (/territory/:id)
       │    │   ├─ Ver información
       │    │   ├─ Ver timeline
       │    │   ├─ Ver transacciones
       │    │   ├─ Editar
       │    │   ├─ Eliminar
       │    │   ├─ Asignar
       │    │   └─ Recoger
       │    │
       │    ├─ Agregar (/add-territory) [Admin]
       │    ├─ Asignar (/change-territory)
       │    └─ Recoger (/pick-territory)
       │
       ├─── Personas (/persons)
       │    ├─ Ver lista con territorios
       │    ├─ Agregar (/add-person) [Admin]
       │    ├─ Editar [Admin]
       │    └─ Eliminar [Admin]
       │
       ├─── Usuarios (/users) [Admin]
       │    ├─ Ver lista
       │    ├─ Registrar (/registration) [Admin]
       │    ├─ Editar (nombre, rol)
       │    ├─ Cambiar contraseña
       │    └─ Eliminar
       │
       ├─── Reportes y Transacciones
       │    ├─ Transacciones recientes (/recent-transactions)
       │    ├─ Generar reporte Excel (/generate-report)
       │    └─ Logs de sistema (/action-logs) [SuperAdmin]
       │
       └─── Configuración
            └─ Cambiar mi contraseña (/user-configuration)
```

---

## Casos de Uso Principales

### 📌 Caso 1: Asignar un Territorio

**Actor:** Usuario autenticado  
**Precondición:** Existen territorios libres y personas registradas

**Flujo:**
1. Usuario navega a "Asignar Territorio" (`/change-territory`)
2. Busca y selecciona un territorio libre de la lista
   - O escanea código QR del territorio
   - O selecciona de sugerencias
3. Busca y selecciona la persona destinataria
4. Opcionalmente selecciona fecha personalizada
5. Confirma la asignación
6. Sistema valida y registra la transacción
7. Territorio queda marcado como "en uso"

**Resultado:** Territorio asignado a la persona con fecha registrada

---

### 📌 Caso 2: Recoger un Territorio

**Actor:** Usuario autenticado  
**Precondición:** Existen territorios asignados

**Flujo:**
1. Usuario navega a "Recoger Territorio" (`/pick-territory`)
2. Busca y selecciona un territorio asignado
   - O escanea código QR del territorio
   - O accede desde detalle del territorio con código pre-cargado
3. Opcionalmente selecciona fecha personalizada de recogida
4. Sistema valida que fecha sea >= fecha de entrega
5. Confirma la recogida
6. Sistema registra la transacción de recogida
7. Territorio queda marcado como "libre"

**Resultado:** Territorio recogido y disponible para nueva asignación

---

### 📌 Caso 3: Monitorear Territorios Antiguos

**Actor:** Supervisor/Administrador  
**Precondición:** Existen territorios asignados hace más de 4 meses

**Flujo:**
1. Usuario inicia sesión y llega al Dashboard (`/home`)
2. Sistema muestra automáticamente territorios con más de 4 meses sin actividad
3. Usuario puede:
   - Ver información básica del territorio
   - Hacer click para ver detalle completo
   - Decidir acciones (contactar persona, reasignar, etc.)

**Resultado:** Identificación de territorios que requieren atención

---

### 📌 Caso 4: Generar Reporte Mensual

**Actor:** Administrador  
**Precondición:** Existen transacciones registradas

**Flujo:**
1. Usuario navega a "Generar Reporte" (`/generate-report`)
2. Selecciona fecha inicial (ej: 01/11/2025)
3. Selecciona fecha final (ej: 30/11/2025)
4. Sistema valida que fecha inicial <= fecha final
5. Usuario confirma generación
6. Sistema genera archivo Excel con todas las transacciones del período
7. Archivo se descarga automáticamente

**Resultado:** Archivo Excel con reporte de transacciones

---

### 📌 Caso 5: Auditoría de Acciones

**Actor:** SuperAdministrador  
**Precondición:** Usuario tiene rol SUPERADMIN

**Flujo:**
1. Usuario navega a "Logs de Acciones" (`/action-logs`)
2. Sistema muestra tabla paginada de todas las acciones
3. Usuario puede:
   - Ordenar por cualquier columna
   - Filtrar por tipo de acción
   - Ver quién hizo qué y cuándo
   - Identificar acciones exitosas vs fallidas
   - Navegar entre páginas

**Resultado:** Visibilidad completa de actividad del sistema

---

### 📌 Caso 6: Corregir Error en Transacción

**Actor:** Administrador  
**Precondición:** Existe una transacción con datos incorrectos

**Flujo:**
1. Usuario navega al detalle del territorio (`/territory/:id`)
2. Identifica la transacción incorrecta en el timeline
3. Hace click en "Editar" en la transacción
4. Modal se abre con datos actuales
5. Usuario corrige:
   - Persona asignada
   - Fecha de entrega
   - Fecha de recogida
6. Sistema valida que fechas sean coherentes
7. Confirma cambios
8. Timeline se actualiza automáticamente

**Resultado:** Transacción corregida con datos precisos

---

### 📌 Caso 7: Agregar Nuevo Territorio con QR

**Actor:** Administrador  
**Precondición:** Usuario tiene permisos de ADMIN o SUPERADMIN

**Flujo:**
1. Usuario navega a "Agregar Territorio" (`/add-territory`)
2. Ingresa código único del territorio (ej: "T-155")
3. Ingresa nombre descriptivo
4. En lugar de escribir URL, hace click en "Escanear QR"
5. Cámara se activa
6. Escanea código QR del mapa del territorio
7. URL se completa automáticamente
8. Usuario confirma
9. Sistema valida unicidad de todos los datos
10. Territorio se crea exitosamente

**Resultado:** Nuevo territorio registrado con mapa vinculado

---

### 📌 Caso 8: Gestionar Persona Inactiva

**Actor:** Administrador  
**Precondición:** Existe una persona que temporalmente no puede tener territorios

**Flujo:**
1. Usuario navega a "Personas" (`/persons`)
2. Busca a la persona en la tabla
3. Hace click en el ícono de editar
4. Desmarca el checkbox "Habilitado"
5. Confirma cambios
6. Sistema marca la persona como deshabilitada
7. La persona no aparecerá en listas de asignación

**Resultado:** Persona temporalmente desactivada sin eliminarse del sistema

---

### 📌 Caso 9: Cambiar Rol de Usuario

**Actor:** SuperAdministrador  
**Precondición:** Existe un usuario USER que necesita ser promovido a ADMIN

**Flujo:**
1. Usuario navega a "Usuarios" (`/users`)
2. Busca al usuario en la tabla
3. Hace click en el ícono de editar
4. Cambia el rol de "USER" a "ADMIN"
5. Confirma cambios
6. Sistema valida permisos (solo SUPERADMIN puede crear ADMIN)
7. Usuario actualizado con nuevos permisos

**Resultado:** Usuario promovido a ADMIN con acceso a funciones administrativas

---

### 📌 Caso 10: Usuario Cambia su Contraseña

**Actor:** Cualquier usuario autenticado  
**Precondición:** Usuario conoce su contraseña actual

**Flujo:**
1. Usuario navega a "Mi Configuración" (`/user-configuration`)
2. Ingresa contraseña actual
3. Ingresa nueva contraseña
4. Confirma nueva contraseña
5. Sistema valida:
   - Contraseña actual correcta
   - Nueva contraseña cumple requisitos
   - Ambas nuevas contraseñas coinciden
6. Contraseña se actualiza
7. Usuario puede iniciar sesión con nueva contraseña

**Resultado:** Contraseña cambiada exitosamente

---

## Flujos de Navegación Común

### Para Usuario Regular (USER)

```
Login → Dashboard → Ver Territorios → Asignar/Recoger
                  → Ver Personas
                  → Mi Configuración
```

### Para Administrador (ADMIN)

```
Login → Dashboard → Gestión completa de Territorios
                  → Agregar Persona
                  → Gestión de Usuarios (crear USER)
                  → Generar Reportes
                  → Ver Transacciones
```

### Para SuperAdministrador (SUPERADMIN)

```
Login → Dashboard → Todo lo de ADMIN
                  → Gestión de Administradores
                  → Logs de Auditoría
                  → Control total del sistema
```

---

## Integraciones y Características Especiales

### 🎥 Escaneo de Códigos QR

**Dónde se usa:**
- Agregar territorio (para URL del mapa)
- Asignar territorio (para seleccionar territorio)
- Recoger territorio (para seleccionar territorio)

**Tecnología:** ngx-scanner-qrcode

**Flujo:**
1. Usuario hace click en botón "Escanear QR"
2. Se solicita permiso para usar la cámara
3. Cámara trasera se activa (si está disponible)
4. Usuario apunta al código QR
5. Sistema detecta y lee el código
6. Dato se asigna automáticamente al campo correspondiente
7. Modal de scanner se cierra

### 📊 Tablas Interactivas (Tabulator)

**Componentes que lo usan:**
- Lista de Personas
- Lista de Usuarios
- Logs de Acciones

**Características:**
- Filtros por columna
- Ordenamiento
- Paginación (local o remota)
- Filas expandibles
- Formatters personalizados
- Rendimiento optimizado

### 📅 Gestión de Fechas

**Tipos de fecha en la aplicación:**
- **Fecha actual**: Por defecto en asignaciones/recogidas
- **Fecha personalizada**: Permite backdating de transacciones
- **Formato UTC**: Todas las fechas se almacenan en UTC en el servidor
- **Formato local**: Se muestran en zona horaria del navegador

**Validaciones:**
- Fecha de recogida >= Fecha de entrega
- Fecha de entrega de nueva asignación >= Última fecha de recogida
- Rango de reporte: Fecha inicial <= Fecha final

### 🔍 Búsqueda con Autocompletado

**ng-select con RxJS:**
- Búsqueda en tiempo real
- Debouncing automático
- Cancelación de peticiones anteriores (switchMap)
- Máximo de resultados limitado (eficiencia)
- Loading states

**Dónde se usa:**
- Seleccionar territorio
- Seleccionar persona
- Cualquier campo de búsqueda

---

## Conceptos Clave del Dominio

### Territorio
- Ubicación geográfica asignable
- Tiene código único, nombre y mapa
- Puede estar libre o asignado
- Mantiene historial completo de transacciones

### Persona
- Individuo que recibe territorios
- Puede tener múltiples territorios simultáneamente
- Puede estar habilitada o deshabilitada
- Mantiene historial de territorios recibidos

### Transacción
- Registro de entrega O recogida de un territorio
- Tiene fecha de entrega (obligatoria)
- Tiene fecha de recogida (opcional, null si aún está asignado)
- Vincula territorio con persona
- Es editable y eliminable para correcciones

### Usuario
- Cuenta de acceso al sistema
- Tiene nombre de usuario único
- Tiene rol (USER, ADMIN, SUPERADMIN)
- Todas las acciones se registran en logs

---

## Mejores Prácticas Implementadas

### Seguridad
- ✅ Autenticación JWT
- ✅ Guards en rutas
- ✅ Interceptor para tokens
- ✅ Control de acceso basado en roles
- ✅ Validación en cliente y servidor
- ✅ Logs de auditoría

### UX/UI
- ✅ Spinners durante operaciones
- ✅ Notificaciones toast
- ✅ Confirmaciones para acciones destructivas
- ✅ Validaciones en tiempo real
- ✅ Mensajes de error claros
- ✅ Navegación intuitiva

### Arquitectura
- ✅ Separación de concerns (servicios, componentes)
- ✅ Reutilización de componentes
- ✅ Programación reactiva con RxJS
- ✅ Lazy loading potencial
- ✅ Modularización clara

### Datos
- ✅ Validación de unicidad
- ✅ Validación de coherencia de fechas
- ✅ Paginación para grandes volúmenes
- ✅ Formateo consistente de fechas
- ✅ Manejo de estados de carga

---

*Última actualización: 2025-12-03*
