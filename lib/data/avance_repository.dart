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
