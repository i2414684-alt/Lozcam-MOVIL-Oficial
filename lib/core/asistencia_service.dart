import 'dart:math' as math;
import '../models/models.dart';
import 'auth_service.dart';
import 'config.dart';
import 'local_store.dart';
import 'supabase_client.dart';

/// Resultado uniforme de marcar asistencia (mismo contrato que el RPC del brief).
class AsistenciaResult {
  final bool ok;
  final String mensaje;
  final double? distanciaMetros;
  const AsistenciaResult(this.ok, this.mensaje, {this.distanciaMetros});
}

/// ============================================================================
///  SERVICIO DE ASISTENCIA
///
///  - Si Supabase está listo -> llama al RPC `marcar_asistencia` (toda la
///    validación de rol, distancia y duplicados ocurre EN EL SERVIDOR) y
///    devuelve su jsonb { ok, mensaje, distancia_metros }.
///  - Si no (beta sin nube) -> valida localmente con la fórmula Haversine
///    contra las coordenadas y el radio de la obra, controla duplicados en la
///    memoria interna y devuelve el MISMO formato de respuesta.
///
///  Cuando se conecte Supabase, el comportamiento pasa a ser el del backend
///  sin tocar la pantalla: ya consume `ok` y `mensaje`.
/// ============================================================================
class AsistenciaService {
  AsistenciaService._();
  static final AsistenciaService instance = AsistenciaService._();

  Future<AsistenciaResult> marcar({
    required Obra obra,
    required String tipo, // 'entrada' | 'salida'
    required double lat,
    required double lng,
    String? fotoUrl,
  }) async {
    // Geolocalización en modo ESCRITURA: marca real vía RPC en el servidor.
    if (supabaseListo && escrituraAsistencia) {
      try {
        final res = await marcarAsistenciaRpc(
          obraId: obra.id,
          lat: lat,
          lng: lng,
          tipo: tipo,
          fotoUrl: fotoUrl,
        );
        return AsistenciaResult(
          (res['ok'] ?? false) as bool,
          (res['mensaje'] ?? 'Sin respuesta del servidor.') as String,
          distanciaMetros: (res['distancia_metros'] as num?)?.toDouble(),
        );
      } catch (_) {
        return const AsistenciaResult(
            false, 'No se pudo conectar con el servidor. Intenta de nuevo.');
      }
    }
    return _marcarLocal(obra, tipo, lat, lng);
  }

  // --------------------------------------------------------------------------
  //  Validación LOCAL (memoria interna) — réplica de la lógica del backend.
  // --------------------------------------------------------------------------
  Future<AsistenciaResult> _marcarLocal(
      Obra obra, String tipo, double lat, double lng) async {
    final dist = _distanciaMetros(obra.lat, obra.lng, lat, lng);
    final radio = obra.radioMetros;

    if (dist > radio) {
      return AsistenciaResult(
        false,
        'Estás fuera del rango de la obra (${dist.round()}m de ${radio}m)',
        distanciaMetros: dist,
      );
    }

    final perfilId = AuthService.instance.session?.id ?? 'local';
    final hoy = _hoy();
    final registros = _leerRegistros();

    bool existe(String t) => registros.any((r) =>
        r['perfil_id'] == perfilId &&
        r['obra_id'] == obra.id &&
        r['fecha'] == hoy &&
        r['tipo'] == t);

    if (tipo == 'entrada' && existe('entrada')) {
      return const AsistenciaResult(false, 'Ya marcaste entrada hoy');
    }
    if (tipo == 'salida') {
      if (!existe('entrada')) {
        return const AsistenciaResult(false, 'No has marcado entrada hoy');
      }
      if (existe('salida')) {
        return const AsistenciaResult(false, 'Ya marcaste salida hoy');
      }
    }

    registros.add({
      'perfil_id': perfilId,
      'obra_id': obra.id,
      'obra_nombre': obra.nombre,
      'fecha': hoy,
      'tipo': tipo,
      'hora': DateTime.now().toIso8601String(),
      'lat': lat,
      'lng': lng,
      'distancia_metros': dist.round(),
    });
    await LocalStore.cacheGuardar('asistencias', registros);

    return AsistenciaResult(
      true,
      tipo == 'entrada' ? 'Entrada registrada' : 'Salida registrada',
      distanciaMetros: dist,
    );
  }

  /// Historial local del trabajador actual (para la pantalla de faltas/historial).
  List<Map<String, dynamic>> historialLocal() {
    final perfilId = AuthService.instance.session?.id ?? 'local';
    return _leerRegistros()
        .where((r) => r['perfil_id'] == perfilId)
        .toList()
      ..sort((a, b) => (b['hora'] as String).compareTo(a['hora'] as String));
  }

  /// Resumen de asistencia del trabajador POR DÍA (más reciente primero).
  /// - Producción: lee la tabla real `asistencias` (una fila por día con
  ///   hora_entrada/hora_salida).
  /// - Sin nube: agrupa los registros locales por fecha.
  /// Cada item: { fecha, obra_nombre, hora_entrada, hora_salida }.
  Future<List<Map<String, dynamic>>> resumen() async {
    if (supabaseListo) {
      final id = AuthService.instance.session?.id;
      if (id != null) {
        try {
          final rows = await supabase
              .from('asistencias')
              .select('fecha, hora_entrada, hora_salida')
              .eq('perfil_id', id)
              .order('fecha', ascending: false)
              .limit(60);
          return (rows as List).map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return <String, dynamic>{
              'fecha': m['fecha'],
              'obra_nombre': '',
              'hora_entrada': m['hora_entrada'],
              'hora_salida': m['hora_salida'],
            };
          }).toList();
        } catch (_) {
          // cae a local
        }
      }
    }
    // Local: agrupar por fecha (entrada/salida en un solo item por día).
    final porFecha = <String, Map<String, dynamic>>{};
    for (final r in historialLocal()) {
      final f = r['fecha'] as String;
      final dia = porFecha.putIfAbsent(
          f,
          () => <String, dynamic>{
                'fecha': f,
                'obra_nombre': r['obra_nombre'] ?? '',
                'hora_entrada': null,
                'hora_salida': null,
              });
      if (r['tipo'] == 'entrada') dia['hora_entrada'] = r['hora'];
      if (r['tipo'] == 'salida') dia['hora_salida'] = r['hora'];
    }
    final lista = porFecha.values.toList()
      ..sort((a, b) => (b['fecha'] as String).compareTo(a['fecha'] as String));
    return lista;
  }

  List<Map<String, dynamic>> _leerRegistros() {
    final raw = LocalStore.cacheLeer('asistencias');
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return <Map<String, dynamic>>[];
  }

  String _hoy() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Distancia en metros entre dos coordenadas (fórmula Haversine).
  double _distanciaMetros(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0; // radio terrestre en metros
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double deg) => deg * math.pi / 180.0;
}

/// Todos los registros de asistencia guardados en memoria interna (para el
/// monitor de gerencia). Cada uno: { perfil_id, obra_id, obra_nombre, fecha,
/// tipo, hora, lat, lng, distancia_metros }.
List<Map<String, dynamic>> registrosAsistenciaLocales() {
  final raw = LocalStore.cacheLeer('asistencias');
  if (raw is List) {
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  return <Map<String, dynamic>>[];
}

/// Asistencias de HOY de toda la empresa (para gerencia). Cada item trae al
/// menos { obra_id, perfil_id }. Producción: tabla `asistencias`; sin nube:
/// registros locales de hoy con entrada.
Future<List<Map<String, dynamic>>> asistenciasHoyTodas() async {
  final d = DateTime.now();
  final hoy = '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  if (supabaseListo) {
    try {
      final rows = await supabase
          .from('asistencias')
          .select('obra_id, perfil_id')
          .eq('fecha', hoy);
      return (rows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      // cae a local
    }
  }
  return registrosAsistenciaLocales()
      .where((r) => r['fecha'] == hoy && r['tipo'] == 'entrada')
      .toList();
}
