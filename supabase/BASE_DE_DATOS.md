# Base de datos — Lozcam Móvil

Guía de lo que la app móvil necesita agregar a tu base de datos Supabase.

## ⚠️ Flujo seguro (no toques la principal todavía)

1. En Supabase, **duplica tu proyecto/base** (o crea uno nuevo y restaura tu backup ahí).
2. Trabaja TODO sobre esa **base duplicada**.
3. Pon sus credenciales en `lib/core/config.dart` (sección "BD Duplicada").
4. Cuando todo funcione, recién pasas a producción cambiando `entornoActivo`.

## Cómo aplicar

Abre **SQL Editor** en tu proyecto duplicado, pega todo `esquema_lozcam_movil.sql` y
ejecútalo. Es **idempotente** (puedes correrlo varias veces) y **100% aditivo**:
no elimina ni cambia tus tablas actuales.

---

## Lo que se AGREGA (resumen)

| Objeto nuevo | Tipo | Para qué |
|---|---|---|
| `roles_config` | tabla | Define poderes de cada rol como DATOS editables (sistema adaptativo) |
| `profiles.reporta_a` | columna | Organigrama: a quién reporta cada persona (cadena de mando) |
| `horarios` | tabla | Turnos disponibles que asigna la gerencia |
| `tareas` | tabla | Tareas con **delegación jerárquica** (subtareas + quién delegó) |
| `avance_tareas` | tabla | Cada operativo sube su progreso de tarea + fotos |
| `asistencias` | tabla | Marcado con geolocalización (radio 200 m) |
| `notificaciones` | tabla | Historial de alertas push (usa `profiles.fcm_token`) |
| `marcar_asistencia()` | función | Valida los 200 m en el servidor (anti-trampa) |
| `avance_total_obra()` | función | % de avance por obra (web y móvil igual) |
| `es_gerencia()`, `puedo_delegar()`, `mi_rol()` | funciones | Reglas de permisos para RLS |
| `vista_monitoreo_obras` | vista | Tablero de gerencia: avance + tareas por obra |
| `vista_arbol_tareas` | vista | Árbol de tareas con responsable y quién delegó |
| Trigger `notificar_tarea` | trigger | Notifica al responsable al asignarle una tarea |
| Políticas RLS | seguridad | Cada rol ve solo lo que le corresponde |

---

## La jerarquía (sistema de trabajo adaptativo)

```
Nivel 1  GERENCIA        gerente            → monitorea TODO, delega
Nivel 2  SUBGERENCIA     subgerente         → monitorea TODO, delega
Nivel 3  JEFES DE RAMA   residente          → rama Construcción
                         supervisor         → rama Supervisión
                         topografo          → rama Topografía
                         arquitecto         → rama Arquitectura
Nivel 4  OPERATIVOS      maestro_obra       → ejecuta y sube avances
                         operario           → ejecuta y sube avances
                         almacenero         → apoyo
(Nivel 9  CLIENTE        cliente            → solo ve su obra)
```

**Delegación:** gerente/subgerente crean tareas y las asignan a los **jefes de rama**
(las "ramificaciones principales"). Cada jefe puede dividir su tarea en **subtareas**
(`tarea_padre_id`) y asignarlas a sus operativos. Los operativos suben avances.
La gerencia ve todo gracias a `es_gerencia()` y las vistas de monitoreo.

**Por qué es "adaptativo":** los permisos (quién delega, quién monitorea) viven en la
tabla `roles_config` como datos. Para cambiar la jerarquía editas filas, no el esquema.

---

## ‼️ Acción que SÍ debes revisar

En la SECCIÓN 12 del SQL (el `INSERT` a `roles_config`), la columna `rol` debe
**coincidir exactamente** con los valores de tu enum `profiles.rol`. Si en tu base
el rol se llama, por ejemplo, `'jefe_topografia'` en vez de `'topografo'`, cámbialo
ahí. Si un nombre no coincide, ese rol se queda sin permisos.

Para ver los valores reales de tu enum, corre en el SQL Editor:

```sql
SELECT enum_range(NULL::tu_nombre_de_enum_rol);
-- o, si no sabes el nombre del tipo:
SELECT DISTINCT rol FROM public.profiles;
```
