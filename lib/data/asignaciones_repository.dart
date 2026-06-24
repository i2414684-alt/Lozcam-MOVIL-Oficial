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

Future<void> asignar({
  required Persona persona,
  required int areaId,
  required String areaNombre,
}) async {
  await LocalStore.guardarAsignacion({
    'perfil_id': persona.id,
    'perfil_nombre': persona.nombre,
    'rol': persona.rol,
    'area_id': areaId,
    'area_nombre': areaNombre,
  });
}

Future<void> quitar(String perfilId, int areaId) =>
    LocalStore.quitarAsignacion(perfilId, areaId);
