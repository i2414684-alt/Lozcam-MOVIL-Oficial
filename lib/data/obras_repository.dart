import '../core/local_store.dart';
import '../core/supabase_client.dart';
import '../models/models.dart';
import 'mock_data.dart';

/// Carga las obras/áreas donde el trabajador puede marcar asistencia.
/// Prioridad:
///   1. Supabase listo  -> tabla `obras` (id, nombre, lat/lng, radio).
///   2. Áreas definidas por el gerente en memoria interna.
///   3. Obras de ejemplo (para que la app no quede vacía en beta).
Future<List<Obra>> cargarObras() async {
  if (supabaseListo) {
    try {
      final rows = await supabase
          .from('obras')
          .select('id, nombre, latitud, longitud, radio_metros, estado, activo')
          .eq('activo', true);
      final lista = (rows as List)
          .map((r) => _obraDesdeRow(Map<String, dynamic>.from(r as Map)))
          .toList();
      if (lista.isNotEmpty) return lista;
    } catch (_) {
      // cae a las áreas locales / semilla
    }
  }
  final locales = areasLocales();
  if (locales.isNotEmpty) return locales;
  return obras;
}

/// Áreas de trabajo definidas por el gerente (memoria interna).
List<Obra> areasLocales() =>
    LocalStore.areas().map(_obraDesdeArea).toList();

/// Crea o actualiza un área de trabajo (geolocalización del gerente).
Future<void> guardarArea({
  int? id,
  required String nombre,
  required double lat,
  required double lng,
  required int radio,
  String? direccion,
}) async {
  await LocalStore.guardarArea({
    'id': id ?? DateTime.now().millisecondsSinceEpoch,
    'nombre': nombre,
    'lat': lat,
    'lng': lng,
    'radio': radio,
    'direccion': direccion ?? '',
  });
}

Future<void> eliminarArea(int id) => LocalStore.eliminarArea(id);

Obra _obraDesdeArea(Map<String, dynamic> a) => Obra(
      (a['id'] as num).toInt(),
      (a['nombre'] ?? 'Área') as String,
      'Área',
      '',
      'en_ejecucion',
      0,
      '',
      (a['direccion'] ?? '') as String,
      (a['lat'] as num).toDouble(),
      (a['lng'] as num).toDouble(),
      'orange',
      radioMetros: (a['radio'] as num?)?.toInt() ?? 200,
    );

Obra _obraDesdeRow(Map<String, dynamic> r) => Obra(
      (r['id'] as num).toInt(),
      (r['nombre'] ?? 'Obra') as String,
      '',
      '',
      (r['estado'] ?? 'en_ejecucion') as String,
      0,
      '',
      '',
      (r['latitud'] as num?)?.toDouble() ?? 0,
      (r['longitud'] as num?)?.toDouble() ?? 0,
      'blue',
      radioMetros: (r['radio_metros'] as num?)?.toInt() ?? 200,
    );
