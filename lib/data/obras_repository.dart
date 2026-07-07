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
              'id, nombre, tipo_servicio, latitud, longitud, radio_metros, estado, activo, direccion')
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
              'id, nombre, tipo_servicio, latitud, longitud, radio_metros, estado, activo, direccion')
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

/// Fase de una obra (tabla real `fases_obra`), para la línea de tiempo del
/// detalle del proyecto. SOLO LECTURA.
class FaseObra {
  final String nombre;
  final String estado;
  final int orden;
  final int pctMeta;
  const FaseObra(this.nombre, this.estado, this.orden, this.pctMeta);
}

/// Fases de la obra ordenadas. Si la tabla no se puede leer (RLS/offline),
/// devuelve lista vacía y la pantalla usa los avances como línea de tiempo.
Future<List<FaseObra>> fasesDeObra(int obraId) async {
  if (!supabaseListo) return const [];
  try {
    final rows = await supabase
        .from('fases_obra')
        .select('nombre, orden, estado, porcentaje_meta')
        .eq('obra_id', obraId)
        .order('orden', ascending: true);
    return (rows as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return FaseObra(
        (m['nombre'] ?? 'Fase') as String,
        (m['estado'] ?? '') as String,
        _aInt(m['orden'], 0),
        _aInt(m['porcentaje_meta'], 0),
      );
    }).toList();
  } catch (_) {
    return const [];
  }
}

/// Fila COMPLETA de la obra (select *), tolerante a columnas que no conocemos
/// de antemano (fechas, tipo_servicio...). null si no se puede leer.
Future<Map<String, dynamic>?> filaObraCompleta(int obraId) async {
  if (!supabaseListo) return null;
  try {
    final row = await supabase
        .from('obras')
        .select('*')
        .eq('id', obraId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  } catch (_) {
    return null;
  }
}

/// Presupuesto de la obra desde la tabla real `presupuestos` (si existe una
/// fila para la obra). Se busca el primer campo numérico razonable sin asumir
/// el nombre exacto de la columna. null = sin dato legible.
Future<double?> presupuestoDeObra(int obraId) async {
  if (!supabaseListo) return null;
  try {
    final rows = await supabase
        .from('presupuestos')
        .select('*')
        .eq('obra_id', obraId)
        .limit(1);
    final lista = rows as List;
    if (lista.isEmpty) return null;
    final m = Map<String, dynamic>.from(lista.first as Map);
    for (final k in const [
      'monto_total', 'monto', 'total', 'importe', 'presupuesto', 'valor'
    ]) {
      final v = m[k];
      final d = _aDouble(v, double.nan);
      if (v != null && !d.isNaN && d > 0) return d;
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Áreas de trabajo definidas por el gerente (memoria interna).
List<Obra> areasLocales() =>
    LocalStore.areas().map(_obraDesdeArea).toList();

/// Crea o actualiza un área de trabajo (geolocalización del gerente).
/// [obraId]/[obraNombre]: obra de la BD a la que pertenece el área — así el
/// área tiene sentido dentro del flujo real (obra -> área -> asistencia).
Future<void> guardarArea({
  int? id,
  required String nombre,
  required double lat,
  required double lng,
  required int radio,
  String? direccion,
  int? obraId,
  String? obraNombre,
}) async {
  await LocalStore.guardarArea({
    'id': id ?? DateTime.now().millisecondsSinceEpoch,
    'nombre': nombre,
    'lat': lat,
    'lng': lng,
    'radio': radio,
    'direccion': direccion ?? '',
    'obra_id': obraId,
    'obra_nombre': obraNombre ?? '',
  });
}

/// Obra vinculada a un área (id y nombre), o null si no tiene.
({int id, String nombre})? obraVinculadaDeArea(int areaId) {
  for (final a in LocalStore.areas()) {
    if (_aInt(a['id'], -1) == areaId && a['obra_id'] != null) {
      return (
        id: _aInt(a['obra_id'], 0),
        nombre: (a['obra_nombre'] ?? '').toString(),
      );
    }
  }
  return null;
}

Future<void> eliminarArea(int id) => LocalStore.eliminarArea(id);

/// Convierte a double tolerando `num`, `String` (PostgREST devuelve los
/// `numeric` como String para no perder precisión) o `null`.
double _aDouble(dynamic v, [double def = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? def;
  return def;
}

/// Convierte a int tolerando `num`, `String` o `null`.
int _aInt(dynamic v, int def) {
  if (v is num) return v.toInt();
  if (v is String) {
    return int.tryParse(v.trim()) ?? double.tryParse(v.trim())?.toInt() ?? def;
  }
  return def;
}

Obra _obraDesdeArea(Map<String, dynamic> a) => Obra(
      _aInt(a['id'], 0),
      (a['nombre'] ?? 'Área') as String,
      'Área',
      '',
      'en_ejecucion',
      0,
      '',
      (a['direccion'] ?? '') as String,
      _aDouble(a['lat']),
      _aDouble(a['lng']),
      'orange',
      radioMetros: _aInt(a['radio'], 200),
    );

Obra _obraDesdeRow(Map<String, dynamic> r) => Obra(
      _aInt(r['id'], 0),
      (r['nombre'] ?? 'Obra') as String,
      (r['tipo_servicio'] ?? '').toString(), // lo que pidió el cliente
      '',
      (r['estado'] ?? 'en_ejecucion') as String,
      0,
      '',
      (r['direccion'] ?? '') as String,
      _aDouble(r['latitud']),
      _aDouble(r['longitud']),
      'blue',
      radioMetros: _aInt(r['radio_metros'], 200),
    );
