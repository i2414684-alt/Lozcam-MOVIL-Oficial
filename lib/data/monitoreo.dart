import '../core/asistencia_service.dart';
import 'asignaciones_repository.dart';
import 'avance_repository.dart';
import 'obras_repository.dart';
import 'personas_repository.dart';
import 'tareas_repository.dart';

/// Arma un resumen de texto (SOLO LECTURA) con el estado actual de la empresa
/// para que el asistente IA del gerente responda preguntas de monitoreo:
/// asistencia de hoy, ausentes por obra/área, avance, tareas. No escribe nada.
Future<String> construirContextoMonitoreo() async {
  final d = DateTime.now();
  final hoy = '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  final obras = await cargarObras();
  final detalle = await asignacionesDetalle(); // {obra_id, perfil_id}
  final asistHoy = await asistenciasHoyTodas(); // {obra_id, perfil_id}
  final personal = await todoElPersonal();
  final tareas = todasLasTareas();

  final nombrePorId = {for (final p in personal) p.id: p.nombre};
  final presentes = asistHoy.map((r) => '${r['perfil_id']}').toSet();

  // Asistencia GLOBAL de hoy (independiente de que existan asignaciones).
  // Garantiza poder responder "¿cuántos faltaron hoy?" aunque la tabla
  // `asignaciones` esté vacía o el RLS no la deje leer.
  final presentesNombres =
      presentes.map((id) => nombrePorId[id] ?? 'ID:$id').toList();
  final ausentesPersonal =
      personal.where((p) => !presentes.contains(p.id)).toList();

  final sb = StringBuffer();
  sb.writeln('Fecha de hoy: $hoy');
  sb.writeln('Total de personal: ${personal.length}');
  sb.writeln(
      'Tareas abiertas: ${tareas.where((t) => t.estado != 'completada').length} '
      '(de ${tareas.length} totales)');
  sb.writeln('');
  sb.writeln('ASISTENCIA DE HOY (resumen global):');
  sb.writeln('- Presentes hoy: ${presentes.length}'
      '${presentesNombres.isEmpty ? '' : ' [${presentesNombres.join(', ')}]'}');
  sb.writeln('- Faltaron hoy: ${ausentesPersonal.length}'
      '${ausentesPersonal.isEmpty ? '' : ' [${ausentesPersonal.map((p) => p.nombre).join(', ')}]'}');
  sb.writeln('');
  sb.writeln('OBRAS (asistencia de hoy y avance):');

  if (obras.isEmpty) {
    sb.writeln('- (No hay obras activas o no se pudieron leer.)');
  }

  // Avances de todas las obras en paralelo (evita N+1 secuencial y reduce la
  // latencia online, para no acercarse al timeout del chat).
  final avancesPorObra =
      await Future.wait(obras.map((o) => avancesDeObra(o.id)));

  for (var i = 0; i < obras.length; i++) {
    final o = obras[i];
    final asignadosIds = detalle
        .where((x) => (x['obra_id'] as num?)?.toInt() == o.id)
        .map((x) => '${x['perfil_id']}')
        .toSet();
    final pres =
        asignadosIds.where((id) => presentes.contains(id)).toList();
    final aus =
        asignadosIds.where((id) => !presentes.contains(id)).toList();
    String nombres(List<String> ids) =>
        ids.map((id) => nombrePorId[id] ?? 'ID:$id').join(', ');

    final avances = avancesPorObra[i];
    final pct = avances.isNotEmpty ? '${avances.first.pct}%' : 'sin reporte';

    sb.writeln('- ${o.nombre}'
        '${o.direccion.isNotEmpty ? ' (${o.direccion})' : ''}: '
        'asignados ${asignadosIds.length}; '
        'presentes ${pres.length} [${nombres(pres)}]; '
        'ausentes ${aus.length} [${nombres(aus)}]; '
        'avance $pct');
  }

  return sb.toString();
}
