import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'enums.dart';
import 'reporte_datos.dart';
import 'roles.dart';
import 'tareas_repository.dart' show estadoTareaLabel, prioridadLabel;

/// ============================================================================
///  REPORTE PDF - informe ejecutivo detallado (día y hora incluidos)
///
///  Mismos datos (SOLO LECTURA) que el Excel y el chat de gerencia. La
///  [PlantillaReporte] elegida define los colores de banda/cabeceras/zebra.
///  Genera los bytes en el dispositivo; no usa red ni escribe en la BD.
/// ============================================================================

PdfColor _c(int argb) => PdfColor.fromInt(argb);

/// Tema con fuente Unicode. `dart_pdf` usa por defecto Helvetica, que es una
/// fuente "core" Latin-1 y NO sabe dibujar tildes ni ñ: el reporte salía con
/// los acentos rotos. Registramos Roboto (empaquetada en assets/, Apache-2.0)
/// para que el PDF salga correcto también sin conexión.
/// Se cachea porque el TTF se parsea una sola vez por sesión.
pw.ThemeData? _temaCache;

Future<pw.ThemeData> _temaUnicode() async {
  if (_temaCache != null) return _temaCache!;
  try {
    final regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    _temaCache = pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: regular,
      boldItalic: bold,
    );
  } catch (_) {
    // Si el asset no está disponible (p. ej. en un test sin binding), seguimos
    // con el tema por defecto en vez de romper la generación del reporte.
    _temaCache = pw.ThemeData.base();
  }
  return _temaCache!;
}

Future<Uint8List> generarReportePdf(
    {PlantillaReporte plantilla = PlantillaReporte.naranja}) async {
  final d = await cargarDatosReporte();
  final pal = paletaDe(plantilla);

  final doc = pw.Document(theme: await _temaUnicode());

  pw.Widget seccion(String titulo) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Row(children: [
          pw.Container(width: 4, height: 14, color: _c(pal.cabecera)),
          pw.SizedBox(width: 6),
          pw.Text(titulo,
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _c(pal.acento))),
        ]),
      );

  pw.Widget tabla(List<String> cab, List<List<String>> filas) =>
      pw.TableHelper.fromTextArray(
        headers: cab,
        data: filas,
        headerStyle: pw.TextStyle(
            color: _c(pal.cabeceraTexto),
            fontWeight: pw.FontWeight.bold,
            fontSize: 8.5),
        headerDecoration: pw.BoxDecoration(color: _c(pal.cabecera)),
        oddRowDecoration: pw.BoxDecoration(color: _c(pal.zebra)),
        cellStyle: const pw.TextStyle(fontSize: 8),
        cellPadding:
            const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.2),
        border: null,
        headerAlignment: pw.Alignment.centerLeft,
        cellAlignment: pw.Alignment.centerLeft,
      );

  pw.Widget kpi(String label, String valor, {bool mal = false}) =>
      pw.Container(
        width: 86,
        padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6),
        decoration: pw.BoxDecoration(
          color: mal ? _c(0xFFFCE8E6) : _c(pal.zebra),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(valor,
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: mal ? _c(pal.peligro) : _c(pal.acento))),
          pw.SizedBox(height: 2),
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
        ]),
      );

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 34),
    footer: (ctx) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Grupo Lozcam · Sistema de Gestión de Obras',
              style:
                  const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
              style:
                  const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        ],
      ),
    ),
    build: (ctx) => [
      // ── Banda de título ──────────────────────────────────────────────────
      pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: pw.BoxDecoration(
          color: _c(pal.titulo),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(children: [
          pw.Expanded(
            child:
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('REPORTE LOZCAM',
                  style: pw.TextStyle(
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                      color: _c(pal.tituloTexto))),
              pw.SizedBox(height: 2),
              pw.Text('Informe de monitoreo de gerencia',
                  style: pw.TextStyle(
                      fontSize: 9, color: _c(pal.tituloTexto))),
            ]),
          ),
          pw.Text('Generado el\n${fechaHoraLegible(d.generado)}',
              textAlign: pw.TextAlign.right,
              style:
                  pw.TextStyle(fontSize: 9, color: _c(pal.tituloTexto))),
        ]),
      ),
      pw.SizedBox(height: 12),

      // ── KPIs ─────────────────────────────────────────────────────────────
      pw.Wrap(spacing: 6, runSpacing: 6, children: [
        kpi('Personal', '${d.personal.length}'),
        kpi('Presentes hoy', '${d.presentesHoy.length}'),
        kpi('Faltaron hoy', '${d.faltaronHoy}', mal: d.faltaronHoy > 0),
        kpi('Asistencia', '${d.pctAsistencia}%',
            mal: d.pctAsistencia < 70),
        kpi('Obras activas', '${d.obras.length}'),
        kpi('Tareas abiertas', '${d.tareasAbiertas}'),
      ]),

      // ── Asistencia de hoy (con horas) ────────────────────────────────────
      seccion('Asistencia de hoy (${fechaCorta(d.generado)})'),
      tabla(
        ['Nombre', 'Rol', 'Obra', 'Estado', 'Entrada', 'Salida'],
        [
          for (final f in d.asistenciaHoy)
            [
              f.nombre,
              f.rol,
              f.obra,
              f.entrada == '-' ? 'AUSENTE' : 'Presente',
              f.entrada,
              f.salida,
            ],
        ],
      ),

      // ── Quiénes faltaron hoy ─────────────────────────────────────────────
      seccion('Faltaron hoy (${d.faltaronHoy})'),
      if (d.faltasHoy.isEmpty)
        pw.Text('Sin faltas: asistencia completa.',
            style: pw.TextStyle(fontSize: 9, color: _c(0xFF1D6E48)))
      else
        tabla(
          ['Nombre', 'Rol', 'Obra asignada'],
          [
            for (final f in d.faltasHoy) [f.nombre, f.rol, f.obras],
          ],
        ),

      // ── Historial detallado (día y hora) ─────────────────────────────────
      seccion(
          'Historial de asistencia - últimos $diasHistorialReporte días'),
      if (d.historial.isEmpty)
        pw.Text('Sin registros de asistencia en el período.',
            style:
                const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
      else
        tabla(
          ['Fecha', 'Nombre', 'Rol', 'Obra', 'Entrada', 'Salida'],
          [
            for (final f in d.historial)
              [f.fecha, f.nombre, f.rol, f.obra, f.entrada, f.salida],
          ],
        ),

      // ── Obras ────────────────────────────────────────────────────────────
      seccion('Obras'),
      tabla(
        ['Obra', 'Dirección', 'Estado', 'Asignados', 'Presentes', 'Avance'],
        [
          for (final o in d.obras)
            [
              o.nombre,
              o.direccion,
              labelEstadoObra(o.estado),
              '${d.asignadosPorObra[o.id] ?? 0}',
              '${d.presentesPorObra[o.id] ?? 0}',
              d.avancePorObra[o.id] != null
                  ? '${d.avancePorObra[o.id]}%'
                  : 'sin reporte',
            ],
        ],
      ),

      // ── Tareas ───────────────────────────────────────────────────────────
      seccion('Tareas'),
      if (d.tareas.isEmpty)
        pw.Text('Sin tareas registradas.',
            style:
                const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
      else
        tabla(
          ['Título', 'Destino', 'Estado', 'Prioridad', 'Obra', 'Vence'],
          [
            for (final t in d.tareas)
              [
                t.titulo,
                t.destinoTexto,
                estadoTareaLabel(t.estado),
                prioridadLabel(t.prioridad),
                t.obraNombre,
                t.fechaEntrega ?? '',
              ],
          ],
        ),

      // ── Personal ─────────────────────────────────────────────────────────
      seccion('Personal por jerarquía'),
      tabla(
        ['Rol', 'Nombre'],
        [
          for (final p in ([...d.personal]..sort((a, b) {
                final na = rolPorClave(a.rol)?.nivel ?? 99;
                final nb = rolPorClave(b.rol)?.nivel ?? 99;
                if (na != nb) return na.compareTo(nb);
                return a.nombre.compareTo(b.nombre);
              })))
            [rolPorClave(p.rol)?.nombre ?? p.rol, p.nombre],
        ],
      ),
    ],
  ));

  return doc.save();
}
