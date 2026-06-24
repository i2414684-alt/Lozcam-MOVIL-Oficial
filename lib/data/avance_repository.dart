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
/// - Producción: lee la tabla `avance_obra`.
/// - Sin nube: usa los partes de avance locales.
Future<List<AvanceItem>> avancesDeObra(int obraId) async {
  if (supabaseListo) {
    try {
      final rows = await supabase
          .from('avance_obra')
          .select('fecha, porcentaje, descripcion, fotos_urls')
          .eq('obra_id', obraId)
          .order('fecha', ascending: false)
          .limit(50);
      return (rows as List).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final fotos = m['fotos_urls'];
        final url = (fotos is List && fotos.isNotEmpty)
            ? fotos.first.toString()
            : null;
        return AvanceItem(
          autor: 'Equipo',
          fecha: (m['fecha'] ?? '').toString(),
          pct: (m['porcentaje'] as num?)?.round() ?? 0,
          texto: (m['descripcion'] ?? '').toString(),
          fotoUrl: url,
        );
      }).toList();
    } catch (_) {
      // cae a local
    }
  }
  return informesDeObra(obraId)
      .map((i) => AvanceItem(
            autor: i.perfilNombre.isEmpty ? 'Equipo' : i.perfilNombre,
            fecha: i.fecha,
            pct: i.pct,
            texto: i.texto,
            fotoPath: i.fotoPath,
          ))
      .toList();
}

Future<void> registrarAvanceObra({
  required int obraId,
  required String obraNombre,
  required int porcentaje,
  required String descripcion,
  String? fotoPath,
}) async {
  if (supabaseListo && escrituraTareas) {
    try {
      await supabase.from('avance_obra').insert({
        'obra_id': obraId,
        'porcentaje': porcentaje,
        'descripcion': descripcion,
        'registrado_por': AuthService.instance.session?.id,
      });
      return;
    } catch (_) {
      // Si la escritura falla, cae a local para no perder el dato.
    }
  }
  await guardarInforme(
    obraId: obraId,
    obraNombre: obraNombre,
    texto: descripcion,
    pct: porcentaje,
    fotoPath: fotoPath,
  );
}
