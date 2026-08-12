import '../core/auth_service.dart';
import '../core/config.dart';
import '../core/supabase_client.dart';
import 'informes_repository.dart';

/// Registra un avance de obra (el progreso que aporta una tarea al cumplirse).
///
/// - Con escritura habilitada (hay nube Y NO está en modo solo-lectura):
///   inserta una fila en la tabla EXISTENTE `avance_obra` (no crea nada).
/// - Si no (solo-lectura / offline): lo guarda como parte de avance LOCAL, para
///   no perder el progreso ni cargar Supabase. Así lo ve el trabajador y el
///   cliente (cliente_informes lee de ahí).
/// Avance de obra normalizado para mostrar (nube o local).
class AvanceItem {
  final String autor;
  final String fecha; // ISO
  final int pct;
  final String texto;
  final String? fotoUrl; // URL (nube, Storage)
  final String? fotoPath; // ruta local (offline)
  const AvanceItem({
    required this.autor,
    required this.fecha,
    required this.pct,
    required this.texto,
    this.fotoUrl,
    this.fotoPath,
  });
}

/// Avances de una obra (lo que ve el cliente).
///
/// FUSIONA nube + memoria interna en vez de ignorar lo local cuando la nube
/// responde. Antes, si la consulta a `avance_obra` funcionaba, los partes que
/// el trabajador había guardado en su dispositivo (por estar sin señal, o antes
/// de que se habilitara la escritura) quedaban huérfanos y el cliente no los
/// veía jamás. Se deduplica por (fecha, texto) para que un parte que sí llegó a
/// subir no aparezca dos veces.
Future<List<AvanceItem>> avancesDeObra(int obraId) async {
  final nube = <AvanceItem>[];
  if (supabaseListo) {
    try {
      final rows = await supabase
          .from('avance_obra')
          .select('fecha, porcentaje, descripcion, fotos_urls')
          .eq('obra_id', obraId)
          .order('fecha', ascending: false)
          .limit(50);
      for (final e in rows as List) {
        final m = Map<String, dynamic>.from(e as Map);
        final fotos = m['fotos_urls'];
        final url = (fotos is List && fotos.isNotEmpty)
            ? fotos.first.toString()
            : null;
        nube.add(AvanceItem(
          autor: 'Equipo',
          fecha: (m['fecha'] ?? '').toString(),
          pct: (m['porcentaje'] as num?)?.round() ?? 0,
          texto: (m['descripcion'] ?? '').toString(),
          fotoUrl: url,
        ));
      }
    } catch (_) {
      // sin nube legible seguimos con lo local
    }
  }

  final locales = informesDeObra(obraId).map((i) => AvanceItem(
        autor: i.perfilNombre.isEmpty ? 'Equipo' : i.perfilNombre,
        fecha: i.fecha,
        pct: i.pct,
        texto: i.texto,
        fotoPath: i.fotoPath,
      ));

  // Clave de deduplicación: día + texto. La fecha de la nube puede venir como
  // fecha sola y la local como ISO completo, así que se compara solo el día.
  String clave(AvanceItem a) =>
      '${a.fecha.length >= 10 ? a.fecha.substring(0, 10) : a.fecha}|'
      '${a.texto.trim().toLowerCase()}';

  final vistos = nube.map(clave).toSet();
  final fusion = [...nube];
  for (final l in locales) {
    if (vistos.add(clave(l))) fusion.add(l);
  }
  fusion.sort((a, b) => b.fecha.compareTo(a.fecha));
  return fusion;
}

/// Registra un parte de avance. Devuelve `true` si llegó a la nube (y por lo
/// tanto lo verá el cliente y el resto del equipo), `false` si solo quedó
/// guardado en este dispositivo.
///
/// Siempre deja copia local: es el historial personal del trabajador («Mis
/// avances registrados») y el respaldo si la subida falló. La lectura
/// ([avancesDeObra]) deduplica, así que la copia no se ve dos veces.
/// Último porcentaje reportado por obra, para VARIAS obras en UNA sola consulta.
///
/// Sustituye al patrón `Future.wait(obras.map(avancesDeObra))`, que lanzaba una
/// consulta por obra (N+1). Con el refresco automático del mapa de calor cada
/// 60 s, eso eran N consultas por minuto mientras la pantalla estuviera
/// abierta; ahora es una sola.
Future<Map<int, int>> ultimoAvancePorObra(List<int> obraIds) async {
  final out = <int, int>{};
  if (obraIds.isEmpty) return out;

  if (supabaseListo) {
    try {
      final rows = await supabase
          .from('avance_obra')
          .select('obra_id, porcentaje, fecha')
          .inFilter('obra_id', obraIds)
          .order('fecha', ascending: false);
      // Como vienen ordenadas por fecha descendente, la primera de cada obra
      // es la más reciente.
      for (final e in rows as List) {
        final m = Map<String, dynamic>.from(e as Map);
        final id = (m['obra_id'] as num?)?.toInt();
        if (id == null || out.containsKey(id)) continue;
        out[id] = (m['porcentaje'] as num?)?.round() ?? 0;
      }
    } catch (_) {
      // cae a los partes locales
    }
  }

  // Completa con los partes guardados en el dispositivo las obras que la nube
  // no haya devuelto.
  for (final id in obraIds) {
    if (out.containsKey(id)) continue;
    final locales = informesDeObra(id);
    if (locales.isNotEmpty) out[id] = locales.first.pct;
  }
  return out;
}

Future<bool> registrarAvanceObra({
  required int obraId,
  required String obraNombre,
  required int porcentaje,
  required String descripcion,
  String? fotoPath,
}) async {
  var enNube = false;
  if (supabaseListo && escrituraTareas && obraId > 0) {
    try {
      await supabase.from('avance_obra').insert({
        'obra_id': obraId,
        'porcentaje': porcentaje,
        'descripcion': descripcion,
        'registrado_por': AuthService.instance.session?.id,
      });
      enNube = true;
    } catch (_) {
      // Si la escritura falla, queda solo el respaldo local.
    }
  }
  await guardarInforme(
    obraId: obraId,
    obraNombre: obraNombre,
    texto: descripcion,
    pct: porcentaje,
    fotoPath: fotoPath,
  );
  return enNube;
}
