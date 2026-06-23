# Lozcam Móvil (Flutter)

App móvil del Sistema de Gestión de Obras de **GRUPO LOZCAM S.A.C.**, en **Flutter**,
conectada a la misma base de datos **Supabase** que la web.

Sistema de trabajo **jerárquico**: gerencia delega a las ramas, las ramas ejecutan
y suben avances, y la gerencia monitorea todo.

---

## 1. Requisitos

- **Flutter SDK** → https://docs.flutter.dev/get-started/install (verifica con `flutter doctor`)
- **VSCode** con extensiones **Flutter** y **Dart**
- Un emulador o tu celular en modo desarrollador

## 2. Iniciar desde VSCode

```bash
flutter pub get
flutter run        # o presiona F5  (elige un emulador o tu celular)
```

Arranca en el **login real**: ingresa con **correo y contraseña**. La app
enruta automáticamente al panel según el rol del usuario (Gerencia, Empleado o
Cliente) y **recuerda la sesión** al volver a abrir (auto-login).

### Modo "memoria interna" (sin nube)

Mientras NO configures Supabase, la app funciona como aplicación real usando la
**memoria interna del dispositivo** (`shared_preferences`). Cuentas por defecto:

| Correo | Contraseña | Panel |
|---|---|---|
| `gerente@lozcam.pe`   | `lozcam123` | Gerencia |
| `residente@lozcam.pe` | `lozcam123` | Empleado |
| `cliente@lozcam.pe`   | `lozcam123` | Cliente |

(En la pantalla de login, en modo sin conexión, el enlace "Ver cuentas
disponibles" las muestra y autocompleta.) Se editan/ampliáin en
`lib/core/local_store.dart`.

En cuanto pongas las credenciales de Supabase (paso 3), el login pasa
**automáticamente** a autenticar contra la nube (`supabase.auth`) y a leer el
rol desde la tabla `profiles`. No hay que cambiar nada más.

## 3. Conectar TU base de datos (duplicada primero)

1. Duplica tu base en Supabase y aplica `supabase/esquema_lozcam_movil.sql`
   (lee `supabase/BASE_DE_DATOS.md` — explica todo paso a paso).
2. Pon las credenciales de la **base duplicada** en `lib/core/config.dart`:
   ```dart
   const Entorno entornoActivo = Entorno.duplicada;
   const String _urlDuplicada = 'https://tu-proyecto-duplicado.supabase.co';
   const String _anonKeyDuplicada = 'tu-anon-key';
   ```
3. Cuando todo funcione, cambia `entornoActivo` a `Entorno.produccion`
   y completa las credenciales de producción. Nada más cambia.

---

## Estructura

```
lib/
├── main.dart
├── core/
│   ├── config.dart            ← CREDENCIALES (duplicada / producción)
│   └── supabase_client.dart   Cliente + RPC marcarAsistencia()
├── theme/colors.dart
├── models/models.dart
├── data/
│   ├── roles.dart             Jerarquía LOZCAM (espejo de roles_config)
│   └── mock_data.dart         Datos de ejemplo + organigrama + delegación
├── widgets/common.dart
└── screens/
    ├── login_screen.dart
    ├── admin/                 Gerencia: monitoreo, organigrama, delegación
    ├── empleado/              Empleado: tareas, marcar, informe, faltas
    └── cliente/               Cliente: avance, informes, mapa, contacto
supabase/
├── esquema_lozcam_movil.sql   ← TODO el SQL a aplicar (idempotente, aditivo)
└── BASE_DE_DATOS.md           Guía de la base de datos y la jerarquía
```

## Estado: Beta 3 — CONECTADA a producción · escritura por módulo

La app apunta al proyecto Supabase de producción
(`lib/core/config.dart`: `entornoActivo = Entorno.produccion`, URL + publishable key).
La escritura se controla **por módulo** (sin crear ni alterar tablas — solo datos):

| Módulo | Modo | Tabla / función |
|---|---|---|
| **Usuarios** | 🔒 Solo lectura (siempre) | `profiles` (login). La app nunca registra usuarios; los crea el gerente en el web |
| **Geolocalización / asistencia** | ✍️ Escritura (`escrituraAsistencia = true`) | RPC `marcar_asistencia` → tabla `asistencias` |
| **Tareas** | ✍️ Escritura (`escrituraTareas = true`) | al cumplir, inserta el % en `avance_obra` |

### Cómo presentar beta 3
1. `flutter run -d chrome` (o en un teléfono con el Android SDK instalado).
2. Inicia sesión con un **usuario real** (las cuentas locales de prueba NO sirven en
   producción; los crea el gerente desde el web).
3. Botón **"Probar conexión"** en el login para evidenciar el enlace con la BD.
4. Se leen datos reales (perfil/rol, obras, asignaciones); asistencia y tareas **sí escriben**.

> Para una demo 100% offline, poner `entornoActivo = Entorno.duplicada` o vaciar las
> credenciales: la app vuelve a memoria interna con las cuentas de prueba.
> Para volver a apagar una escritura: poner su flag (`escrituraAsistencia`/`escrituraTareas`) en `false`.

Ya hecho:
- [x] Login real con `supabase.auth` + lectura de `profiles` (`id, nombre, apellidos, rol, activo`)
- [x] Enrutado por rol; roles que marcan asistencia: `personal_obra` y `maestro_obra`
- [x] **GPS real** con `geolocator` + permisos Android (`ACCESS_FINE_LOCATION`) e iOS (`NSLocationWhenInUseUsageDescription`)
- [x] **Mapa integrado en la app** con `flutter_map` (OpenStreetMap, sin API key): ubicación en vivo, obra, radio permitido y distancia en tiempo real (`lib/widgets/live_map.dart`). En "Marcar asistencia" (con tu posición) y en el panel del Cliente (solo obra).
- [x] **Gerente define las áreas por geolocalización** (`lib/screens/admin/area_editor.dart`): busca una dirección (Nominatim, sin API key) o toca el mapa para fijar una coordenada **estática** + radio. Pestaña "Áreas" del panel de gerencia. Se guardan en memoria interna y los trabajadores las ven al marcar.
- [x] **Trabajador** ve la dirección y coordenadas del área y su cercanía al radio antes de marcar.
- [x] **Cliente** solo ve la **dirección** de su obra (geocodificación inversa) + el mapa, sin rutas.
- [x] **Perfiles alineados al web** (`lib/data/roles.dart`): 11 roles internos que crea gerencia (`gerente_general, subgerente, administrador, ingeniero_residente, arquitecto, tecnico_autocad, topografo, maestro_obra, personal_obra, contador, vendedor`) + `cliente` (externo, fuera de la jerarquía). Niveles 1→5 + cliente nivel 9.
- [x] **Delegación de tareas por jerarquía** (`lib/data/tareas_repository.dart`, `lib/screens/delegar_tarea.dart`): gerencia delega a toda la empresa (excepto cliente); las jefaturas solo dentro de su área; cada rol ve sus tareas y actualiza su estado. En memoria interna hasta que exista la tabla `tareas` en el backend.
- [x] **Delegación por persona** además de por rol (`lib/data/personas_repository.dart`): se puede asignar a "Todos los del rol" o a alguien concreto. Las personas vienen de `profiles` (con nube) o de la memoria interna; el trabajador ve solo lo dirigido a su rol o a él.
- [x] **Asignación de áreas a trabajadores** (`lib/data/asignaciones_repository.dart`, `lib/screens/admin/asignar_trabajadores.dart`): el gerente marca qué personal de campo trabaja en cada área; el trabajador solo ve/marca asistencia en sus áreas asignadas.
- [x] **Monitor de gerencia** (`lib/screens/admin/admin_asistencias.dart`, pestaña "Monitor"): solo lectura, con asistencia del día y estado de tareas agrupado por área. Pull-to-refresh.
- [x] **Historial de asistencia del trabajador** (`lib/screens/empleado/empleado_inasistencias.dart`, pestaña "Historial"): registros reales agrupados por día (entrada/salida + obra), 100% memoria interna, sin red. Pull-to-refresh.
- [x] **Paneles reales (offline)**: inicio del empleado (obra asignada, mis tareas, mi asistencia), parte de avance del empleado guardable en memoria interna (`lib/data/informes_repository.dart`), contacto del cliente (equipo real desde memoria interna) y proyecto del cliente (obra + dirección guardada). Todo sin datos móviles.
- [x] **Preparación para integración (sin tocar la BD prod)**: enums/etiquetas centralizados como "una sola verdad" espejo del web (`lib/data/enums.dart`: estados de obra/tarea, tipos de servicio, prioridades) y `probarConexion()` en `supabase_client.dart` para el cutover a producción.
- [x] **Foto de evidencia local** (`image_picker`): el parte de avance permite adjuntar foto (cámara/galería); se guarda la ruta local y subirá al bucket `avances` de Storage al integrar. Permisos de cámara en Android/iOS.
- [x] **Ajuste para Técnico AutoCAD**: en el parte de avance, los roles de oficina/CAD reportan sobre una **referencia (plano/entrega)** en vez de una obra física, con textos y foto etiquetada como "plano/imagen".
- [x] **Selector de panel en el login**: el usuario elige Gerencia / Trabajador / Cliente. Si las credenciales no corresponden al panel elegido (p. ej. un cliente intenta entrar como Gerencia), el ingreso se rechaza con "Usuario inválido para el panel de X" (no crea sesión; en nube hace signOut). Al tocar una cuenta local se preselecciona su panel correcto.
- [x] **Panel de Gerencia con datos reales (offline)**: Inicio con áreas, personal, tareas abiertas y presentes del día (+ áreas y tareas recientes), y Equipo con el personal real agrupado por jerarquía (con áreas asignadas por trabajador). Pull-to-refresh en Inicio.
- [x] **Informes del cliente reales (ciclo trabajador→cliente)**: el cliente ve los partes de avance que el equipo reporta para su obra (autor, %, fecha, texto y foto), con el % más reciente. Offline, pull-to-refresh (`informesDeObra` en `informes_repository.dart`).
- [x] **Lista de obras real** (`admin_obras.dart`): cada obra con sus trabajadores asignados y el último % de avance reportado. Con esto **ninguna pantalla usa datos de ejemplo** (mock_data solo queda como semilla de respaldo en `obras_repository`).
- [x] **Tutorial de bienvenida** (`lib/screens/tutorial_overlay.dart`): aparece **una sola vez por panel/rol** (flag en memoria interna), con el ingeniero 👷 explicando en un carrusel los pasos clave (Gerencia / Trabajador / Cliente). Botones Saltar / Siguiente / Entendido. Offline, no toca la BD.
- [x] Selección de obra y llamada al RPC `marcar_asistencia(p_obra_id, p_lat, p_lng, p_tipo, p_foto_url)` leyendo `{ ok, mensaje, distancia_metros }`
- [x] Respaldo en memoria interna: misma validación (Haversine + radio + duplicados) + últimos registros del dispositivo

Pendiente para producción:
- [ ] Pegar `SUPABASE_URL` + `SUPABASE_ANON_KEY` reales en `lib/core/config.dart`
- [ ] (Opcional) Foto de evidencia con `image_picker` + Supabase Storage (`p_foto_url`)
- [ ] (Opcional) Historial real de asistencias desde la tabla `asistencias`
- [ ] `flutter build appbundle` → publicar en Play Store (requiere instalar el Android SDK)

> ⚠️ El SQL de `supabase/esquema_lozcam_movil.sql` es de un diseño anterior y **no**
> coincide con el backend del brief. No lo apliques a ese proyecto (ver aviso en el archivo).
