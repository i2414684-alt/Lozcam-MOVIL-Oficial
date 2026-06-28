import '../core/asistencia_service.dart';
import 'asignaciones_repository.dart';
import 'avance_repository.dart';
import 'enums.dart';
import 'obras_repository.dart';
import 'personas_repository.dart';
import 'roles.dart';
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
  final clientes = await personasPorRol('cliente');
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

  // PLANTILLA COMPLETA POR ROL: todo el personal interno agrupado por su rol,
  // ordenado de mayor a menor autoridad (nivel). Da al asistente visibilidad
  // total de quién ocupa cada cargo para armar reportes por área/rol.
  sb.writeln('PERSONAL POR ROL (plantilla completa):');
  if (personal.isEmpty) {
    sb.writeln('- (No se pudo leer el personal o no hay registros.)');
  } else {
    final porRol = <String, List<String>>{};
    for (final p in personal) {
      porRol.putIfAbsent(p.rol, () => <String>[]).add(p.nombre);
    }
    final rolesOrdenados = porRol.keys.toList()
      ..sort((a, b) =>
          (rolPorClave(a)?.nivel ?? 99).compareTo(rolPorClave(b)?.nivel ?? 99));
    for (final rol in rolesOrdenados) {
      final nombres = porRol[rol]!;
      final etiqueta = rolPorClave(rol)?.nombre ?? rol;
      sb.writeln('- $etiqueta (${nombres.length}): ${nombres.join(', ')}');
    }
  }
  sb.writeln('');

  // CLIENTES registrados (externos a la jerarquía): nombres para reportes.
  sb.writeln('CLIENTES REGISTRADOS: ${clientes.length}'
      '${clientes.isEmpty ? '' : ' [${clientes.map((c) => c.nombre).join(', ')}]'}');
  sb.writeln('');

  sb.writeln('OBRAS (estado, asistencia de hoy y avance):');

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

    final estado = labelEstadoObra(o.estado);
    sb.writeln('- ${o.nombre}'
        '${o.direccion.isNotEmpty ? ' (${o.direccion})' : ''}'
        '${estado.isNotEmpty ? ' [$estado]' : ''}: '
        'asignados ${asignadosIds.length}; '
        'presentes ${pres.length} [${nombres(pres)}]; '
        'ausentes ${aus.length} [${nombres(aus)}]; '
        'avance $pct');
  }

  return sb.toString();
}
