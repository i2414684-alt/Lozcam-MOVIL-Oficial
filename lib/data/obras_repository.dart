import '../core/auth_service.dart';
import '../core/local_store.dart';
import '../core/supabase_client.dart';
import '../models/models.dart';
import 'mock_data.dart';

/// Carga las obras donde el trabajador puede marcar asistencia.
///
/// IMPORTANTE: en producción (Supabase listo) se devuelve SOLO lo que diga la
/// BD —con las coordenadas reales (latitud, longitud, radio_metros)—. NUNCA se
/// cae a datos locales/semilla, para que el mapa y la distancia jamás muestren
/// coordenadas viejas/equivocadas. Si la BD viene vacía (p. ej. el RLS no deja
/// leer `obras` a ese rol), se devuelve vacío y la pantalla mostrará "no hay
/// obras" en vez de coordenadas incorrectas.
///
/// Solo SIN nube (offline/beta) se usan las áreas locales o la semilla.
Future<List<Obra>> cargarObras() async {
  if (supabaseListo) {
    try {
      final rows = await supabase
          .from('obras')
          .select(
              'id, nombre, latitud, longitud, radio_metros, estado, activo, direccion')
          .eq('activo', true);
      return (rows as List)
          .map((r) => _obraDesdeRow(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (_) {
      return []; // en nube, ante error NO mostramos datos locales/stale
    }
  }
  final locales = areasLocales();
  if (locales.isNotEmpty) return locales;
  return obras;
}

/// Obra del cliente actual (por `cliente_id` de su perfil).
/// Producción: lee de la tabla `obras`; sin nube: primera área local.
Future<Obra?> obraDelCliente() async {
  if (supabaseListo) {
    final cid = AuthService.instance.session?.clienteId;
    if (cid == null) return null;
    try {
      final rows = await supabase
          .from('obras')
          .select(
              'id, nombre, latitud, longitud, radio_metros, estado, activo, direccion')
          .eq('cliente_id', cid)
          .eq('activo', true)
          .limit(1);
      final lista = (rows as List)
          .map((r) => _obraDesdeRow(Map<String, dynamic>.from(r as Map)))
          .toList();
      return lista.isNotEmpty ? lista.first : null;
    } catch (_) {
      return null;
    }
  }
  final locales = areasLocales();
  return locales.isNotEmpty ? locales.first : null;
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
      (r['direccion'] ?? '') as String,
      (r['latitud'] as num?)?.toDouble() ?? 0,
      (r['longitud'] as num?)?.toDouble() ?? 0,
      'blue',
      radioMetros: (r['radio_metros'] as num?)?.toInt() ?? 200,
    );
