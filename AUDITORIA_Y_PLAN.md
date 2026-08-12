# Auditoría técnica y plan de avances — Lozcam Móvil

Revisión completa de `lib/` (66 archivos Dart), `test/` y `supabase/`.
Fecha: 2026-08-02 · Rama: `main`

**Restricción respetada en todo el documento:** no se agrega, altera ni elimina
ninguna tabla, columna o función de la base de datos. Todas las mejoras
propuestas usan **solo** lo que ya existe: `obras`, `profiles`, `asignaciones`,
`asistencias`, `avance_obra`, `fases_obra`, `presupuestos` y el RPC
`marcar_asistencia`.

---

## 0. El bug que reportaste — RESUELTO

> «cuando intento apretar el botón de ingresar no me deja avanzar, pero desde el
> teclado sí»

**Causa exacta:** `PrimaryButton` (en [common.dart](lib/widgets/common.dart))
tenía **dos detectores de gestos anidados**:

```dart
GestureDetector(                      // ← el que llamaba a onPressed
  onTapUp: (_) async { ...; widget.onPressed?.call(); },
  child: AnimatedContainer(
    child: Stack(children: [
      Material(child: InkWell(
        onTap: enabled ? () {} : null,   // ← callback VACÍO, pero gana el toque
```

En la *arena de gestos* de Flutter, cuando dos reconocedores de toque compiten,
**gana siempre el más profundo del árbol**. El `InkWell` interno se quedaba con
el toque y ejecutaba su `onTap` vacío; el `GestureDetector` de arriba perdía la
arena y su `onTapUp` **no se ejecutaba nunca**. Por eso ni siquiera se veía la
animación de pulsado.

Con el teclado sí funcionaba porque el login llama a `_ingresar()` desde
`onSubmitted` del `TextField` ([login_screen.dart:210](lib/screens/login_screen.dart#L210)),
que no pasa por la arena de gestos.

**Alcance:** no era solo el login. `PrimaryButton` se usa en 4 pantallas —
login, dashboard del empleado ("Marcar asistencia"), dashboard del cliente
("Ver avance de mi proyecto") y `EmptyState` (CTA de estados vacíos). **Todos
esos botones estaban muertos al tacto.**

**Corrección aplicada:** se eliminó el `GestureDetector` externo y se dejó un
único detector — el `InkWell` — que ahora recibe el `onPressed` real y además
dispara la animación de escala vía `onTapDown`/`onTapUp`/`onTapCancel`. Se
añadió `Semantics(button: true)` (antes el botón no se anunciaba como botón a
lectores de pantalla) y un `didUpdateWidget` que suelta la escala si el botón
se deshabilita en pleno pulsado, para que no se quede "hundido".

**No cambia nada de la lógica ni del diseño:** mismo gradiente, mismo gloss,
misma sombra, misma animación, mismo contrato de API.

**Regresión cubierta:** [test/primary_button_test.dart](test/primary_button_test.dart)
— 5 casos (toque normal, variante `.large`, estado `loading`, `onPressed` nulo,
accesibilidad). Con el código anterior el primer test falla; ahora pasan los 5.
Suite completa: **21 pasan, 2 saltados** (los `skip: !kIsWeb`).

---

## 1. Estado general

Lo que está **bien** y conviene no romper:

- Separación limpia `core/` (servicios) · `data/` (repositorios) · `screens/` · `widgets/` · `theme/`.
- Sistema de diseño real: `AppTokens` como `ThemeExtension` con modo claro/oscuro completo, escalas de espaciado/radio/sombra/motion.
- Seguridad de sesión bien planteada: el panel **no** lo elige el cliente, se deriva de `profiles.rol` en el servidor (`shellForSession`).
- Jerarquía de roles (`roles.dart`) coherente y bien documentada, con `puedeDelegarA()` correcto.
- `main.dart` con `runZonedGuarded` + `ErrorWidget.builder` — arranque robusto.
- Validación de coordenadas `(0,0)` repetida en mapa/actividad: buen detalle defensivo.
- `flutter analyze` limpio: solo 4 avisos de deprecación (`DropdownButtonFormField.value` → `initialValue`) en `delegar_tarea.dart`.

Lo que **no** está bien se detalla abajo, ordenado por severidad.

---

## 2. P0 — Incoherencias entre ventanas (lo más grave)

La app tiene **dos fuentes de datos** (nube Supabase y memoria interna
`shared_preferences`) y cada pantalla eligió una distinta. Con credenciales de
producción activas (`config.dart` → `Entorno.produccion`), esto produce
contradicciones visibles entre pestañas del **mismo usuario**.

### P0-1 · El mismo trabajador ve tres cosas distintas sobre "su obra"

| Pantalla | Fuente que usa | Resultado en producción |
|---|---|---|
| [empleado_marcar.dart:40-55](lib/screens/empleado/empleado_marcar.dart#L40) | `cargarObras()` + `obrasAsignadasA()` → **nube** | Muestra la obra real ✅ |
| [empleado_dashboard.dart:29-32](lib/screens/empleado/empleado_dashboard.dart#L29) | `areasLocales()` + `areasDeTrabajador()` → **local** | «Sin área asignada» ❌ |
| [empleado_informe.dart:45-56](lib/screens/empleado/empleado_informe.dart#L45) | `areasLocales()` + `areasDeTrabajador()` → **local** | «Sin obra asignada» ❌ |

El trabajador entra a *Inicio* y lee "Sin área asignada", pasa a *Marcar* y ahí
sí aparece su obra. Es la incoherencia más visible de la app.

### P0-2 · El gerente asigna trabajadores y no le llega a nadie

- **Escritura:** [asignaciones_repository.dart:100](lib/data/asignaciones_repository.dart#L100) — `asignar()` guarda **solo** en `LocalStore`.
- **Lectura:** [asignaciones_repository.dart:17](lib/data/asignaciones_repository.dart#L17) — `obrasAsignadasA()` lee de la tabla **`asignaciones` de Supabase**.

La tabla `asignaciones` **sí existe** en producción. Como la lectura solo cae a
local cuando hay *excepción* (no cuando la consulta devuelve vacío), una
asignación hecha desde la app **jamás** se ve: ni en otro dispositivo, ni en el
mismo. La pantalla *Asignar trabajadores* es, en la práctica, un formulario que
no escribe donde se lee.

### P0-3 · Toda la pestaña "Áreas" del gerente es invisible para el resto

`guardarArea()` escribe en `LocalStore`; pero
[obras_repository.dart:17-35](lib/data/obras_repository.dart#L17) — `cargarObras()`
en modo nube devuelve **solo** filas de `obras` y **nunca** mezcla las áreas
locales (decisión deliberada y bien comentada, para no mostrar coordenadas
viejas). Consecuencia correcta pero no comunicada: las áreas que crea el gerente
no existen para nadie más. No hay tabla `areas` en el backend, así que esto es
una **limitación estructural**, no un descuido — pero la UI la presenta como si
fuera una función compartida.

### P0-4 · Las tareas delegadas no cruzan de dispositivo

`tareas_repository.dart` es 100 % `LocalStore`. No existe tabla `tareas` en el
backend real (el `esquema_lozcam_movil.sql` que la define lleva una advertencia
explícita: *«diseño anterior… las tablas `tareas`, `horarios`, `notificaciones`
son Fase 2 (aún NO existen en el backend real)»*).

El gerente delega desde su teléfono → se guarda en **su** `shared_preferences` →
el trabajador nunca la recibe. Todo el módulo de delegación (que es el corazón
funcional de la app) es efectivamente monodispositivo.

### P0-5 · El cliente ve contactos de mentira

[cliente_contacto.dart:30](lib/screens/cliente/cliente_contacto.dart#L30) lee
`LocalStore.usuarios()` — la **semilla de demo**. En producción, un cliente real
ve como equipo de su obra a *«Carlos Lozcam»*, *«Ana Quispe Flores»* y
*«Pedro Vega Huari»*, que no existen. Existe `personasDeRoles()` que sí consulta
`profiles`; esta pantalla simplemente no la usa.

### P0-6 · Dos cifras distintas de asistencia para el mismo trabajador

- *Inicio* usa `historialLocal()` → solo memoria interna.
- *Historial* usa `resumen()` → tabla `asistencias`.

Como las marcas se escriben en la nube vía RPC (y **no** en local), en
producción *Inicio* muestra `Días 0 / Entradas 0 / Salidas 0` mientras
*Historial* muestra los registros reales.

### P0-7 · El parte de avance del trabajador no llega al cliente

`guardarInforme()` escribe solo en `LocalStore`. En cambio `registrarAvanceObra()`
(al completar una tarea) **sí** inserta en `avance_obra`. Y el cliente lee
`avancesDeObra()`, que en modo nube consulta `avance_obra` y **nunca** cae a los
informes locales si la consulta funciona. Resultado: el trabajador redacta su
parte con foto y el cliente no lo ve jamás. `avance_obra` ya existe → esto se
arregla sin tocar la BD.

---

## 3. P1 — Bugs concretos

| # | Archivo | Problema |
|---|---|---|
| P1-1 | [reporte_pdf.dart](lib/data/reporte_pdf.dart) | No se registra fuente Unicode; `dart_pdf` cae a Helvetica (Latin-1 core). Los tests lo gritan: *«Helvetica has no Unicode support»*. **Las tildes y la ñ salen rotas en todos los PDF** (hay 11 líneas con acentos en el propio generador). |
| P1-2 | [personas_repository.dart:57-60](lib/data/personas_repository.dart#L57) | `todoElPersonal()` **no** filtra `activo`, mientras `personasPorRol()` sí lo hace. El KPI "Empleados" y el organigrama cuentan personal dado de baja. |
| P1-3 | [delegar_tarea.dart:55](lib/screens/delegar_tarea.dart#L55) | `_obra` arranca en `lista.first` y `_avancePct` en `10`. Toda tarea delegada **suma 10 % de avance a una obra arbitraria** sin que el gerente lo haya elegido. El desplegable ofrece «Sin obra» pero no es el valor por defecto. Corrompe el % de avance que ve el cliente. |
| P1-4 | [admin_tareas.dart:33](lib/screens/admin/admin_tareas.dart#L33) | `_eliminar()` borra la tarea **sin confirmación**, con un solo toque. `admin_areas.dart` sí pide confirmación para borrar. Incoherencia de criterio en acciones destructivas. |
| P1-5 | [auth_service.dart:139-164](lib/core/auth_service.dart#L139) | En `restaurarSesion()`, si `_perfilDesdeSupabase` lanza `LoginError('usuario inactivo')`, el `catch (_)` lo traga y devuelve `null`. El usuario inactivo ve el login **sin ninguna explicación** y vuelve a intentar en bucle. |
| P1-6 | [auth_service.dart:180](lib/core/auth_service.dart#L180) | `guardarSesion()` persiste la sesión también en modo nube, pero `restaurarSesion()` en modo nube **nunca la lee** (`return null` en la línea 155). Se escriben datos de sesión en disco que no se usan jamás. |
| P1-7 | [descarga_io.dart:37](lib/core/descarga_io.dart#L37) | El mensaje de respaldo dice siempre *«Reporte Excel guardado en…»*, incluso cuando el archivo es un PDF. |
| P1-8 | [login_screen.dart:132,175](lib/screens/login_screen.dart#L132) | `fontFamily: 'Poppins'` — Poppins **no está declarada** en `pubspec.yaml` ni cargada por `google_fonts`. Cae silenciosamente a la fuente por defecto. El tema real usa Inter (cuerpo) + Lexend (títulos). El comentario de `main.dart:55` («Poppins incluida») y el de `pubspec.yaml:26` también mienten. |
| P1-9 | [tutorial_overlay.dart:53](lib/screens/tutorial_overlay.dart#L53) | `tutorialAutomaticoHabilitado = false` y **no hay ningún punto de entrada manual** en toda la app. Son ~200 líneas de UI (3 shells la invocan) completamente inalcanzables. |
| P1-10 | [empleado_marcar.dart:36-38](lib/screens/empleado/empleado_marcar.dart#L36) | `initState` llama a `_cargarObras()` **y** a `_cargarRecientes()`, pero `_cargarObras()` ya llama a `_cargarRecientes()` internamente. Doble carga en cada apertura de la pestaña. |
| P1-11 | [empleado_inasistencias.dart](lib/screens/empleado/empleado_inasistencias.dart) | El archivo, la clase y el concepto son "inasistencias", pero la pantalla **nunca calcula una falta**: lista solo los días con marca, todos con check verde. El título dice "Mi asistencia" y el nav dice "Historial". Tres nombres, ninguna inasistencia. |
| P1-12 | [delegar_tarea.dart:60-72](lib/screens/delegar_tarea.dart#L60) | `_cargarPersonas()` no cancela la petición anterior: cambiar de rol dos veces rápido puede dejar la lista del rol equivocado (última respuesta gana, no última petición). |

---

## 4. P2 — Diseño e interfaz

### P2-1 · Modo oscuro roto en 5 puntos

El sistema de tokens es excelente, pero hay superficies con color fijo claro que
en modo oscuro quedan como parches blancos:

| Ubicación | Qué pasa |
|---|---|
| [area_editor.dart:411](lib/screens/admin/area_editor.dart#L411) | Panel inferior con `color: Colors.white` fijo |
| [area_editor.dart:395](lib/screens/admin/area_editor.dart#L395) | Cartel de ayuda del mapa, `Colors.white` fijo |
| [live_map.dart:280-281](lib/widgets/live_map.dart#L280) | Chip de distancia usa `greenBg`/`redBg` (paleta clara fija) |
| [empleado_informe.dart:286](lib/screens/empleado/empleado_informe.dart#L286) | Botón de foto con `AppColors.grayBg` |
| [main.dart:103](lib/main.dart#L103) · [error_boundary.dart:19](lib/widgets/error_boundary.dart#L19) | Splash y pantalla de error 100 % claros: destello blanco al arrancar en oscuro |

### P2-2 · Dos vocabularios de color conviviendo

`AppColors` mantiene alias `@Deprecated` (`admin`, `empleado`, `cliente`,
`primary`) junto a los nuevos (`roleAdmin`, `roleEmpleado`, `roleCliente`,
`brand`) — y **las pantallas usan ambos, mezclados**:

- `admin_dashboard` → `AppColors.roleAdmin`
- `admin_areas`, `admin_tareas`, `admin_empleados` → `AppColors.admin`
- `empleado_dashboard` → `roleEmpleado` · `empleado_tareas`, `empleado_marcar` → `empleado`

Son el mismo color, así que no se ve el error — pero significa que el día que
quieras diferenciar tonos por rol, la mitad de la app no responderá. (El lint
`deprecated_member_use_from_same_package` no está activo en
`analysis_options.yaml`, por eso el analizador no lo reporta.)

### P2-3 · Dos sistemas de tarjeta KPI

`StatTile` (nueva, con tokens, gradiente 3D, `Semantics`) y `StatCard` (legacy,
plana). `admin_dashboard` usa la nueva; `admin_tareas` usa la vieja. En la misma
app, la misma métrica se ve de dos formas distintas.

### P2-4 · Escalas de espaciado ignoradas a medias

`AppSpacing` existe y está bien, pero las pantallas de `admin/` y varias de
`empleado/` usan números crudos (`EdgeInsets.all(12)`, `SizedBox(height: 10)`,
`8`, `6`, `7`). Los dashboards nuevos sí usan tokens. Resultado: los márgenes no
coinciden entre pestañas de un mismo panel.

### P2-5 · Tipografía por libre

`context.text.*` (`h1`, `body`, `caption`, `overline`) está definido y es bueno,
pero la mayoría de pantallas escribe `TextStyle(fontSize: 13, fontWeight: w600, …)`
a mano. Hay más de 40 tamaños distintos en el proyecto, incluidos `10.5`, `9.5`
y `11.5`. No hay una escala tipográfica real aplicada.

### P2-6 · `MapPlaceholder` dice "Google Maps"

[common.dart:1135](lib/widgets/common.dart#L1135) — el rótulo dice **Google
Maps** en el dashboard del cliente, mientras toda la app usa OpenStreetMap/Carto.
Es lo primero que ve el cliente al entrar. Además es un mapa **falso** (círculos
decorativos) puesto justo debajo de un mapa real: el cliente ve un mapa de
verdad en la pestaña *Mapa* y un dibujo en *Inicio*.

### P2-7 · `PanelHeader` fijo come pantalla

120 px mínimos + gradiente + sombra en **todas** las pestañas de **todos** los
paneles, sin colapsar al hacer scroll. En un teléfono de 5,5" con el dock
flotante abajo, el área útil se reduce notablemente.

### P2-8 · Accesibilidad

- Los `IconButton` de acciones (editar/eliminar/asignar en `admin_areas`) tienen `tooltip`, lo cual es bueno; pero muchos otros iconos interactivos no tienen etiqueta semántica.
- Objetivos táctiles por debajo de 48 dp en varias filas de lista y chips.
- El texto de 9–10 px (`fontSize: 9`, `9.5`, `10`) en chips y leyendas queda por debajo del mínimo legible recomendado.
- `textSecondary` sobre `surfaceAlt` no está verificado para AA (el token está documentado como AA solo sobre `#FFFFFF`).

---

## 5. P3 — Rendimiento y calidad

| # | Dónde | Qué |
|---|---|---|
| P3-1 | [actividad_areas.dart:66](lib/data/actividad_areas.dart#L66) | `Future.wait(obras.map((o) => avancesDeObra(o.id)))` → **N+1 consultas**. Combinado con el `Timer.periodic(60s)` de `MapaCalorScreen`, son N consultas por minuto mientras la pantalla esté abierta. |
| P3-2 | [mapa_calor.dart:44](lib/screens/mapa_calor.dart#L44) | El timer de 60 s sigue disparando aunque la pantalla esté tapada por otra ruta o la app en segundo plano. |
| P3-3 | [admin_dashboard.dart:67](lib/screens/admin/admin_dashboard.dart#L67) | `todasLasTareas()` se llama **dentro de `build()`**: lee y parsea JSON de `shared_preferences` en cada reconstrucción (cada animación, cada cambio de tema). Igual en [admin_asistencias.dart:61](lib/screens/admin/admin_asistencias.dart#L61). |
| P3-4 | Los 3 shells | `IndexedStack` construye las 6 pantallas de golpe al entrar → 6 `initState` lanzando sus cargas de red simultáneamente en el primer segundo de sesión. |
| P3-5 | `app_theme.dart` | `GoogleFonts` descarga Inter y Lexend por HTTP en el primer arranque. Sin internet, la app arranca con fuente del sistema; con internet, hay un parpadeo tipográfico. Para una app de campo (obras con mala señal) conviene empaquetar las fuentes como assets. |
| P3-6 | [config.dart:53](lib/core/config.dart#L53) | La clave `publishable` de producción está commiteada. Es *pública por diseño* (la protege el RLS), así que no es una fuga — pero conviene moverla a `--dart-define` (el soporte ya está escrito) para poder rotarla sin recompilar y para no confundir a futuros colaboradores. |
| P3-7 | `test/` | 4 archivos de test, ninguno cubre login, asistencia, repositorios ni jerarquía de roles. La lógica de negocio crítica (`puedeDelegarA`, Haversine, `areaDeRol`) no tiene una sola prueba. |

---

## 6. Plan de avances

Ocho etapas, ordenadas para que cada una entregue algo visible sin romper lo
anterior. Ninguna toca la base de datos.

---

### **Avance 1 — Coherencia de datos: una sola fuente de verdad** ⭐ prioridad máxima

*Objetivo:* que dos pantallas nunca contradigan a una tercera.

1. Crear `lib/data/fuente_datos.dart`: una capa fina que decida — en **un solo
   sitio** — si un dato viene de nube o de local, y lo exponga con una única
   función por concepto (`obrasDelUsuario()`, `asistenciaDelUsuario()`,
   `equipoDeContacto()`).
2. Migrar `empleado_dashboard` y `empleado_informe` de `areasLocales()` a la
   misma función que ya usa `empleado_marcar` → **cierra P0-1**.
3. Migrar `empleado_dashboard` de `historialLocal()` a `resumen()` → **cierra P0-6**.
4. Migrar `cliente_contacto` de `LocalStore.usuarios()` a `personasDeRoles()`
   → **cierra P0-5**.
5. Convertir `EmpleadoDashboard` en `StatefulWidget` con carga asíncrona y
   `RefreshIndicator`, como el resto de dashboards.

*Criterio de aceptación:* con la nube activa, el nombre de la obra es idéntico
en *Inicio*, *Marcar* e *Informe*; los contadores de asistencia coinciden entre
*Inicio* e *Historial*; el cliente ve nombres reales de `profiles`.

---

### **Avance 2 — Que la escritura llegue donde se lee**

*Objetivo:* que las acciones del gerente y del trabajador tengan efecto real.

1. **Asignaciones (P0-2):** la tabla `asignaciones` ya existe. Escribir ahí
   (INSERT/UPDATE de `activo`) desde `asignar()`/`quitar()`, con la memoria
   interna como caché de respaldo. Si el RLS no permite escritura para gerencia,
   la alternativa sin tocar la BD es **quitar el toggle de la app** y mostrar
   las asignaciones como solo lectura, indicando que se gestionan desde la web.
   Cualquiera de las dos es coherente; la actual (escribir donde nadie lee) no.
2. **Parte de avance (P0-7):** `guardarInforme()` debe intentar primero
   `avance_obra` (tabla existente, mismo camino que ya usa `registrarAvanceObra`)
   y caer a local solo si falla. Así el parte del trabajador llega al cliente.
3. Hacer que `avancesDeObra()` **fusione** nube + local en vez de ignorar lo
   local cuando la nube responde, para que nada quede huérfano durante la
   transición.

*Criterio de aceptación:* asignar un trabajador y verlo reflejado tras cerrar y
abrir la app; un parte de avance escrito por el trabajador aparece en el panel
del cliente.

---

### **Avance 3 — Honestidad de estado (lo que no cruza de dispositivo)**

*Objetivo:* que la app no prometa lo que el backend no soporta hoy.

Áreas GPS (P0-3) y tareas delegadas (P0-4) no tienen tabla y **no se pueden
sincronizar sin tocar la BD**. En lugar de dejarlo silencioso:

1. Añadir un distintivo reutilizable `ChipSoloEsteDispositivo` y colocarlo en
   la cabecera de *Áreas* y *Tareas*: «Guardado en este dispositivo».
2. En *Asignar trabajadores*, avisar cuando el área no está vinculada a una obra
   de la BD (esa asignación no la verá el trabajador).
3. Documentar en el propio `README` qué módulos son locales y cuáles nube.
4. Preparar `tareas_repository.dart` detrás de una interfaz (`RepositorioTareas`)
   con implementación `Local` — para que el día que exista la tabla se cambie
   una línea, sin tocar pantallas.

*Criterio de aceptación:* ningún usuario puede confundir un dato local con uno
compartido.

---

### **Avance 4 — Corrección de bugs P1**

Lote de arreglos pequeños e independientes:

1. **PDF con tildes (P1-1):** registrar una fuente TTF Unicode en `reporte_pdf.dart`
   vía `pw.ThemeData.withFont()`. Es el bug más visible para gerencia.
2. `todoElPersonal()`: añadir `.eq('activo', true)` (P1-2).
3. `delegar_tarea`: obra por defecto = **«Sin obra»**, `_avancePct` solo cuando
   el gerente elige obra explícitamente (P1-3).
4. Confirmación al eliminar tarea, reutilizando el diálogo de `admin_areas` (P1-4).
5. Propagar el motivo real cuando el usuario está inactivo (P1-5).
6. Quitar el `guardarSesion` muerto en modo nube (P1-6).
7. Mensaje de descarga según extensión real (P1-7).
8. Quitar `fontFamily: 'Poppins'` y usar `context.text.display` (P1-8).
9. Decidir sobre el tutorial (P1-9): o se reactiva con un botón «Ver guía» en
   cada panel, o se elimina el archivo. Hoy es peso muerto.
10. Quitar la doble carga de `empleado_marcar` (P1-10).
11. Renombrar `empleado_inasistencias` → `empleado_historial` y unificar el
    título en las tres capas (P1-11). Opcional: calcular faltas reales cruzando
    `asignaciones` con días hábiles sin marca — se puede con las tablas actuales.
12. Guardia de secuencia en `_cargarPersonas` (P1-12).
13. Actualizar los 4 `DropdownButtonFormField.value` → `initialValue`.

---

### **Avance 5 — Unificación del sistema de diseño**

*Objetivo:* que la app se vea hecha por una sola mano, sin rediseñarla.

1. **Modo oscuro completo (P2-1):** sustituir los 5 `Colors.white` / paletas
   claras fijas por `t.surface` / `t.successSoft` / `t.dangerSoft`. Incluir
   splash y pantalla de error.
2. **Un solo vocabulario de color (P2-2):** reemplazar todos los usos de
   `AppColors.admin/empleado/cliente/primary` por `roleAdmin/roleEmpleado/roleCliente/brand`,
   y activar el lint `deprecated_member_use_from_same_package` en
   `analysis_options.yaml` para que no vuelvan a colarse.
3. **Una sola tarjeta KPI (P2-3):** migrar `admin_tareas` a `StatTile` y borrar
   `StatCard`.
4. **Espaciado (P2-4):** sustituir números crudos por `AppSpacing.*` en
   `admin/*` y `empleado/*`.
5. **Tipografía (P2-5):** sustituir los `TextStyle` sueltos por `context.text.*`,
   ampliando la escala con los 2–3 estilos que falten en vez de inventar
   tamaños. Objetivo: bajar de 40 tamaños a ~8.
6. **`MapPlaceholder` (P2-6):** cambiar el rótulo «Google Maps» y, mejor aún,
   reemplazar el mapa falso del dashboard del cliente por un `LiveMap` real con
   `mostrarUsuario: false` — el widget ya existe y `cliente_mapa` ya lo usa así.

*Criterio de aceptación:* recorrer los 3 paneles en claro y en oscuro sin
encontrar un parche de color fuera de tema ni dos márgenes distintos para el
mismo tipo de tarjeta.

---

### **Avance 6 — Rendimiento**

1. Resolver el N+1 de `cargarActividadAreas` (P3-1): una sola consulta a
   `avance_obra` con `in_('obra_id', ids)` y agrupar en memoria.
2. Pausar el timer del mapa de calor cuando la ruta no está visible o la app está
   en segundo plano (`WidgetsBindingObserver` + `RouteAware`) (P3-2).
3. Sacar `todasLasTareas()` de los `build()` y llevarlo al estado (P3-3).
4. Carga diferida en los shells: construir la pestaña la primera vez que se
   visita, en vez de las 6 de golpe (P3-4).
5. Empaquetar Inter y Lexend como assets locales (P3-5) — clave para obras sin
   señal.
6. Mover credenciales a `--dart-define` (P3-6).

---

### **Avance 7 — Robustez y pruebas**

1. Tests unitarios de la lógica que hoy no tiene ninguna: `puedeDelegarA()`,
   `areaDeRol()`, Haversine de `asistencia_service`, `_marcarLocal` (duplicados
   entrada/salida), normalización de `intensidad` en `actividad_areas`.
2. Tests de widget para el flujo de login (credenciales vacías, error de
   servidor, éxito → shell correcto por rol).
3. Estados vacíos y de error consistentes: hoy conviven `EmptyState`,
   `IconRow` y textos sueltos para decir lo mismo. Unificar en `EmptyState`.
4. Reintento visible cuando falla una carga de red — ahora mismo casi todos los
   `catch (_)` devuelven lista vacía y la pantalla dice «no hay datos», que es
   indistinguible de «falló la conexión».

---

### **Avance 8 — Mejoras de producto (con las tablas actuales)**

Ya con base sana, funciones que aportan valor sin tocar la BD:

1. **Faltas reales** en el historial: cruzar `asignaciones` + `asistencias` para
   marcar días hábiles sin marca. Da sentido al nombre "inasistencias".
2. **Resumen semanal** para el trabajador: horas trabajadas por día calculadas
   desde `hora_entrada`/`hora_salida`.
3. **Filtros y búsqueda** en *Equipo* y *Monitor* (hoy son listas planas; con 50
   personas se vuelven inmanejables).
4. **Contacto accionable** para el cliente: `url_launcher` para llamar y enviar
   correo desde la tarjeta de contacto (hoy el teléfono es texto muerto).
5. **Modo offline honesto** en *Marcar*: si no hay red, encolar la marca y
   reintentar, avisando claramente al trabajador (hoy simplemente falla).
6. **Detalle de obra enriquecido** usando `fases_obra` y `presupuestos`, que ya
   se leen pero se aprovechan poco.

---

## 7. Orden recomendado

```
Avance 1  ██████████  Coherencia de datos      ← empezar aquí
Avance 2  ████████    Escritura efectiva
Avance 4  ██████      Bugs P1 (PDF primero)
Avance 3  ████        Honestidad de estado
Avance 5  ████████    Sistema de diseño
Avance 6  █████       Rendimiento
Avance 7  █████       Pruebas
Avance 8  ██████      Producto
```

Los avances 1, 2 y 4 son los que un usuario nota de inmediato. El 5 es el que
más cambia la percepción de calidad. El 3 es barato y evita malentendidos
mientras el backend no crezca.

---

## 8. Resumen ejecutivo

- **1 bug bloqueante corregido:** ningún `PrimaryButton` de la app respondía al
  tacto (arena de gestos). Cubierto con pruebas.
- **7 incoherencias P0** entre ventanas, todas por mezclar nube y memoria
  interna sin criterio único. La app muestra datos contradictorios al mismo
  usuario en pestañas distintas.
- **12 bugs P1**, de los cuales el PDF sin Unicode y el 10 % de avance
  automático son los que ensucian datos reales.
- **8 incoherencias de diseño P2**, sobre un sistema de tokens que en realidad
  está bien construido — el problema es que solo la mitad de la app lo usa.
- **7 puntos de rendimiento/calidad P3.**
- **Nada de lo propuesto requiere tocar la base de datos.**
