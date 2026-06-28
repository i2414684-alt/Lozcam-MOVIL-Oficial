import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../core/asistencia_service.dart';
import 'asignaciones_repository.dart';
import 'avance_repository.dart';
import 'enums.dart';
import 'obras_repository.dart';
import 'personas_repository.dart';
import 'roles.dart';
import 'tareas_repository.dart';

/// Genera un reporte Excel (.xlsx) con el estado actual de la empresa usando los
/// MISMOS datos (SOLO LECTURA) que alimentan al chat de gerencia, por lo que las
/// cifras coinciden exactamente. Devuelve los bytes del archivo listo para
/// compartir. No escribe nada en la BD ni toca el esquema.
Future<Uint8List> generarReporteExcel() async {
  final hoy = _fecha(DateTime.now());

  final obras = await cargarObras();
  final detalle = await asignacionesDetalle(); // {obra_id, perfil_id}
  final asistHoy = await asistenciasHoyTodas(); // {obra_id, perfil_id}
  final personal = await todoElPersonal();
  final clientes = await personasPorRol('cliente');
  final tareas = todasLasTareas();

  final presentes = asistHoy.map((r) => '${r['perfil_id']}').toSet();
  final ausentes = personal.where((p) => !presentes.contains(p.id)).toList();

  final excel = Excel.createExcel();

  // ── Resumen ────────────────────────────────────────────────────────────────
  final resumen = excel['Resumen'];
  resumen.appendRow([TextCellValue('REPORTE LOZCAM'), TextCellValue(hoy)]);
  resumen.appendRow([TextCellValue('')]);
  resumen.appendRow(
      [TextCellValue('Total de personal'), IntCellValue(personal.length)]);
  resumen.appendRow(
      [TextCellValue('Presentes hoy'), IntCellValue(presentes.length)]);
  resumen.appendRow(
      [TextCellValue('Faltaron hoy'), IntCellValue(ausentes.length)]);
  resumen.appendRow([TextCellValue('Obras activas'), IntCellValue(obras.length)]);
  resumen.appendRow(
      [TextCellValue('Clientes registrados'), IntCellValue(clientes.length)]);
  resumen.appendRow([
    TextCellValue('Tareas abiertas'),
    IntCellValue(tareas.where((t) => t.estado != 'completada').length),
  ]);
  resumen
      .appendRow([TextCellValue('Tareas totales'), IntCellValue(tareas.length)]);

  // ── Asistencia de hoy ──────────────────────────────────────────────────────
  final asis = excel['Asistencia hoy'];
  asis.appendRow([
    TextCellValue('Nombre'),
    TextCellValue('Rol'),
    TextCellValue('Estado'),
  ]);
  for (final p in personal) {
    asis.appendRow([
      TextCellValue(p.nombre),
      TextCellValue(rolPorClave(p.rol)?.nombre ?? p.rol),
      TextCellValue(presentes.contains(p.id) ? 'Presente' : 'Ausente'),
    ]);
  }

  // ── Personal por rol (ordenado por jerarquía) ──────────────────────────────
  final plant = excel['Personal'];
  plant.appendRow([TextCellValue('Rol'), TextCellValue('Nombre')]);
  final ordenado = [...personal]
    ..sort((a, b) {
      final na = rolPorClave(a.rol)?.nivel ?? 99;
      final nb = rolPorClave(b.rol)?.nivel ?? 99;
      if (na != nb) return na.compareTo(nb);
      return a.nombre.compareTo(b.nombre);
    });
  for (final p in ordenado) {
    plant.appendRow([
      TextCellValue(rolPorClave(p.rol)?.nombre ?? p.rol),
      TextCellValue(p.nombre),
    ]);
  }

  // ── Clientes ───────────────────────────────────────────────────────────────
  final cli = excel['Clientes'];
  cli.appendRow([TextCellValue('Cliente')]);
  for (final c in clientes) {
    cli.appendRow([TextCellValue(c.nombre)]);
  }

  // ── Obras (estado, asistencia y avance) ────────────────────────────────────
  final ob = excel['Obras'];
  ob.appendRow([
    TextCellValue('Obra'),
    TextCellValue('Dirección'),
    TextCellValue('Estado'),
    TextCellValue('Asignados'),
    TextCellValue('Presentes hoy'),
    TextCellValue('Avance %'),
  ]);
  final avancesPorObra =
      await Future.wait(obras.map((o) => avancesDeObra(o.id)));
  for (var i = 0; i < obras.length; i++) {
    final o = obras[i];
    final asignados = detalle
        .where((x) => (x['obra_id'] as num?)?.toInt() == o.id)
        .map((x) => '${x['perfil_id']}')
        .toSet();
    final pres = asignados.where((id) => presentes.contains(id)).length;
    final av = avancesPorObra[i];
    ob.appendRow([
      TextCellValue(o.nombre),
      TextCellValue(o.direccion),
      TextCellValue(labelEstadoObra(o.estado)),
      IntCellValue(asignados.length),
      IntCellValue(pres),
      av.isNotEmpty
          ? IntCellValue(av.first.pct)
          : TextCellValue('sin reporte'),
    ]);
  }

  // ── Tareas ─────────────────────────────────────────────────────────────────
  final tar = excel['Tareas'];
  tar.appendRow([
    TextCellValue('Título'),
    TextCellValue('Destino'),
    TextCellValue('Estado'),
    TextCellValue('Prioridad'),
    TextCellValue('Obra'),
    TextCellValue('Vence'),
  ]);
  for (final t in tareas) {
    tar.appendRow([
      TextCellValue(t.titulo),
      TextCellValue(t.destinoTexto),
      TextCellValue(estadoTareaLabel(t.estado)),
      TextCellValue(prioridadLabel(t.prioridad)),
      TextCellValue(t.obraNombre),
      TextCellValue(t.fechaEntrega ?? ''),
    ]);
  }

  // Quita la hoja por defecto que crea el paquete ('Sheet1'); delete() es seguro
  // (solo borra si quedan ≥2 hojas y reasigna la hoja por defecto).
  if (excel.sheets.containsKey('Sheet1')) {
    excel.delete('Sheet1');
  }

  final bytes = excel.encode();
  if (bytes == null) {
    throw Exception('No se pudo generar el archivo Excel.');
  }
  return Uint8List.fromList(bytes);
}

/// Nombre de archivo sugerido para el reporte (con la fecha de hoy).
String nombreArchivoReporte() => 'reporte_lozcam_${_fecha(DateTime.now())}.xlsx';

String _fecha(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
