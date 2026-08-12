import '../core/local_store.dart';
import '../core/supabase_client.dart';
import 'personas_repository.dart';

/// Asignación de trabajadores a áreas de trabajo (memoria interna).
/// area_id == el id de la obra/área. Cuando exista la relación en el backend
/// (p. ej. una tabla `obra_personal`), este repositorio se cambia por consultas.

List<int> areasDeTrabajador(String perfilId) => LocalStore.asignaciones()
    .where((a) => a['perfil_id'] == perfilId)
    .map((a) => (a['area_id'] as num).toInt())
    .toList();

/// Obra-ids asignados al trabajador, listo para la BD.
/// - Con nube: LEE la tabla real `asignaciones` (solo lectura).
/// - Sin nube: usa la memoria interna.
Future<List<int>> obrasAsignadasA(String perfilId) async {
  if (supabaseListo) {
    try {
      final rows = await supabase
          .from('asignaciones')
          .select('obra_id')
          .eq('perfil_id', perfilId)
          .eq('activo', true);
      return (rows as List).map((r) => (r['obra_id'] as num).toInt()).toList();
    } catch (_) {
      // si falla la consulta, cae a la memoria interna
    }
  }
  return areasDeTrabajador(perfilId);
}

bool estaAsignado(String perfilId, int areaId) => LocalStore.asignaciones()
    .any((a) => a['perfil_id'] == perfilId && (a['area_id'] as num).toInt() == areaId);

List<Map<String, dynamic>> trabajadoresDeArea(int areaId) => LocalStore
    .asignaciones()
    .where((a) => (a['area_id'] as num).toInt() == areaId)
    .toList();

/// Perfil-ids asignados a un área. Producción: tabla `asignaciones`; sin nube o
/// si el RLS no deja leer: memoria interna.
///
/// La versión síncrona [trabajadoresDeArea] solo veía la memoria interna, así
/// que la pantalla «Asignar trabajadores» abría con todas las casillas
/// desmarcadas aunque el trabajador SÍ estuviera asignado en la base de datos.
Future<Set<String>> perfilesDeArea(int areaId) async {
  if (supabaseListo) {
    try {
      final rows = await supabase
          .from('asignaciones')
          .select('perfil_id')
          .eq('obra_id', areaId)
          .eq('activo', true);
      return (rows as List).map((r) => '${r['perfil_id']}').toSet();
    } catch (_) {
      // cae a memoria interna
    }
  }
  return trabajadoresDeArea(areaId)
      .map((a) => '${a['perfil_id']}')
      .toSet();
}

int contarTrabajadoresArea(int areaId) => trabajadoresDeArea(areaId).length;

/// Detalle de asignaciones activas: lista de { obra_id, perfil_id }.
/// Producción: tabla `asignaciones`; sin nube: memoria interna.
Future<List<Map<String, dynamic>>> asignacionesDetalle() async {
  if (supabaseListo) {
    try {
      final rows = await supabase
          .from('asignaciones')
          .select('obra_id, perfil_id')
          .eq('activo', true);
      return (rows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      // cae a local
    }
  }
  return LocalStore.asignaciones()
      .map((a) => <String, dynamic>{
            'obra_id': (a['area_id'] as num).toInt(),
            'perfil_id': a['perfil_id'],
          })
      .toList();
}

/// Conteo de trabajadores asignados por obra (obra_id -> cantidad).
/// Producción: tabla `asignaciones`; sin nube: memoria interna.
Future<Map<int, int>> conteoAsignadosPorObra() async {
  final map = <int, int>{};
  final seen = <String>{};
  if (supabaseListo) {
    try {
      final rows = await supabase
          .from('asignaciones')
          .select('obra_id, perfil_id')
          .eq('activo', true);
      for (final r in rows as List) {
        final m = Map<String, dynamic>.from(r as Map);
        final oid = (m['obra_id'] as num).toInt();
        if (seen.add('$oid|${m['perfil_id']}')) {
          map[oid] = (map[oid] ?? 0) + 1;
        }
      }
      return map;
    } catch (_) {
      map.clear();
      seen.clear();
    }
  }
  for (final a in LocalStore.asignaciones()) {
    final oid = (a['area_id'] as num).toInt();
    if (seen.add('$oid|${a['perfil_id']}')) {
      map[oid] = (map[oid] ?? 0) + 1;
    }
  }
  return map;
}

/// Asigna un trabajador a una obra/área.
///
/// ESCRIBE DONDE SE LEE: primero en la tabla real `asignaciones` (la misma que
/// consultan [obrasAsignadasA] y [asignacionesDetalle]) y además deja copia en
/// la memoria interna como caché. Antes escribía SOLO en local mientras la
/// lectura iba a la nube, así que una asignación hecha desde la app no se veía
/// nunca — ni en otro dispositivo ni en el mismo.
///
/// Devuelve `true` si quedó registrada en la nube (compartida con el equipo).
Future<bool> asignar({
  required Persona persona,
  required int areaId,
  required String areaNombre,
}) async {
  var enNube = false;
  if (supabaseListo) {
    try {
      // Primero se intenta REACTIVAR una fila existente (el trabajador ya
      // estuvo asignado y se le quitó). Solo si no había ninguna se inserta.
      // Se hace así, y no con `upsert`, para no depender de que exista una
      // restricción única (obra_id, perfil_id) en la tabla.
      final actualizadas = await supabase
          .from('asignaciones')
          .update({'activo': true})
          .eq('obra_id', areaId)
          .eq('perfil_id', persona.id)
          .select('perfil_id');
      if ((actualizadas as List).isEmpty) {
        await supabase.from('asignaciones').insert({
          'obra_id': areaId,
          'perfil_id': persona.id,
          'activo': true,
        });
      }
      enNube = true;
    } catch (_) {
      // Sin permiso de escritura o sin señal: queda el respaldo local.
    }
  }
  await LocalStore.guardarAsignacion({
    'perfil_id': persona.id,
    'perfil_nombre': persona.nombre,
    'rol': persona.rol,
    'area_id': areaId,
    'area_nombre': areaNombre,
  });
  return enNube;
}

/// Quita la asignación. En la nube se marca `activo = false` (no se borra la
/// fila, para conservar el histórico); en local se elimina la entrada.
Future<bool> quitar(String perfilId, int areaId) async {
  var enNube = false;
  if (supabaseListo) {
    try {
      await supabase
          .from('asignaciones')
          .update({'activo': false})
          .eq('obra_id', areaId)
          .eq('perfil_id', perfilId);
      enNube = true;
    } catch (_) {
      // queda el respaldo local
    }
  }
  await LocalStore.quitarAsignacion(perfilId, areaId);
  return enNube;
}
