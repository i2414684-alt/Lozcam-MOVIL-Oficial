import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'enums.dart';
import 'reporte_datos.dart';
import 'roles.dart';
import 'tareas_repository.dart' show estadoTareaLabel, prioridadLabel;

// La UI (chat de gerencia) importa este archivo: re-exportamos lo compartido
// (PlantillaReporte, labels, paleta, nombreArchivoReporte, etc.).
export 'reporte_datos.dart';

/// ============================================================================
///  REPORTE EXCEL (.xlsx) — detallado y con plantillas de diseño
///
///  Hojas: Resumen · Asistencia hoy (con horas) · Faltas hoy · Historial 7 días
///  (día y hora) · Personal · Clientes · Obras · Tareas.
///  SOLO LECTURA: mismos datos que el chat de gerencia; no escribe en la BD.
/// ============================================================================

ExcelColor _hex(int argb) => ExcelColor.fromHexString(
    argb.toRadixString(16).toUpperCase().padLeft(8, '0'));

class _Estilos {
  final PaletaReporte pal;
  _Estilos(this.pal);

  late final titulo = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: _hex(pal.tituloTexto),
      backgroundColorHex: _hex(pal.titulo));
  late final subtitulo = CellStyle(
      italic: true, fontSize: 10, fontColorHex: _hex(pal.acento));
  late final cabecera = CellStyle(
      bold: true,
      fontColorHex: _hex(pal.cabeceraTexto),
      backgroundColorHex: _hex(pal.cabecera));
  late final zebra = CellStyle(backgroundColorHex: _hex(pal.zebra));
  late final kpiValor = CellStyle(bold: true, fontColorHex: _hex(pal.acento));
  late final malo = CellStyle(bold: true, fontColorHex: _hex(pal.peligro));
  late final maloZebra = CellStyle(
      bold: true,
      fontColorHex: _hex(pal.peligro),
      backgroundColorHex: _hex(pal.zebra));
  late final bueno = CellStyle(bold: true, fontColorHex: _hex(0xFF1D6E48));
  late final buenoZebra = CellStyle(
      bold: true,
      fontColorHex: _hex(0xFF1D6E48),
      backgroundColorHex: _hex(pal.zebra));
}

/// Banda de título (celdas combinadas) + subtítulo con fecha/hora + separador.
void _banner(Sheet s, String texto, String sub, int cols, _Estilos e) {
  final r0 = s.maxRows;
  s.appendRow([TextCellValue(texto)]);
  s.merge(
    CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r0),
    CellIndex.indexByColumnRow(columnIndex: cols - 1, rowIndex: r0),
    customValue: TextCellValue(texto),
  );
  s.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r0)).cellStyle =
      e.titulo;

  final r1 = s.maxRows;
  s.appendRow([TextCellValue(sub)]);
  s.merge(
    CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r1),
    CellIndex.indexByColumnRow(columnIndex: cols - 1, rowIndex: r1),
    customValue: TextCellValue(sub),
  );
  s.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r1)).cellStyle =
      e.subtitulo;

  s.appendRow([TextCellValue('')]);
}

/// Tabla con cabecera estilada y franjas zebra. [colEstado] (opcional) pinta
/// esa columna en verde/rojo según [filasMal] (un bool por fila).
void _tabla(
  Sheet s,
  List<String> cabeceras,
  List<List<CellValue>> filas,
  _Estilos e, {
  int colEstado = -1,
  List<bool>? filasMal,
}) {
  final rCab = s.maxRows;
  s.appendRow([for (final c in cabeceras) TextCellValue(c)]);
  for (var c = 0; c < cabeceras.length; c++) {
    s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rCab))
        .cellStyle = e.cabecera;
  }
  for (var i = 0; i < filas.length; i++) {
    final r = s.maxRows;
    s.appendRow(filas[i]);
    final zebra = i.isOdd;
    for (var c = 0; c < filas[i].length; c++) {
      CellStyle? st = zebra ? e.zebra : null;
      if (c == colEstado) {
        final mal = (filasMal != null && i < filasMal.length) && filasMal[i];
        st = mal
            ? (zebra ? e.maloZebra : e.malo)
            : (zebra ? e.buenoZebra : e.bueno);
      }
      if (st != null) {
        s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
            .cellStyle = st;
      }
    }
  }
}

/// Fija anchos de columna (en "caracteres") para que los textos no se corten.
void _anchos(Sheet sheet, List<double> anchos) {
  for (var c = 0; c < anchos.length; c++) {
    sheet.setColumnWidth(c, anchos[c]);
  }
}

/// Genera el reporte Excel detallado. [plantilla] define el diseño (colores de
/// banda/cabeceras/zebra). Devuelve los bytes del archivo.
Future<Uint8List> generarReporteExcel(
    {PlantillaReporte plantilla = PlantillaReporte.naranja}) async {
  final d = await cargarDatosReporte();
  final e = _Estilos(paletaDe(plantilla));
  final generado = 'Generado el ${fechaHoraLegible(d.generado)}';

  final excel = Excel.createExcel();

  // ── Resumen ────────────────────────────────────────────────────────────────
  final resumen = excel['Resumen'];
  _banner(resumen, 'REPORTE LOZCAM', generado, 2, e);
  void kpi(String label, int valor, {bool mal = false}) {
    final r = resumen.maxRows;
    resumen.appendRow([TextCellValue(label), IntCellValue(valor)]);
    resumen.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
        .cellStyle = mal ? e.malo : e.kpiValor;
  }

  kpi('Total de personal', d.personal.length);
  kpi('Presentes hoy', d.presentesHoy.length);
  kpi('Faltaron hoy', d.faltaronHoy, mal: d.faltaronHoy > 0);
  kpi('% de asistencia hoy', d.pctAsistencia, mal: d.pctAsistencia < 70);
  kpi('Obras activas', d.obras.length);
  kpi('Clientes registrados', d.clientes.length);
  kpi('Tareas abiertas', d.tareasAbiertas);
  kpi('Tareas totales', d.tareas.length);

  // ── Asistencia de hoy (todo el personal, con horas) ────────────────────────
  final asis = excel['Asistencia hoy'];
  _banner(asis, 'ASISTENCIA DE HOY', generado, 6, e);
  _tabla(
    asis,
    ['Nombre', 'Rol', 'Obra', 'Estado', 'Hora entrada', 'Hora salida'],
    [
      for (final f in d.asistenciaHoy)
        [
          TextCellValue(f.nombre),
          TextCellValue(f.rol),
          TextCellValue(f.obra),
          TextCellValue(f.entrada == '-' ? 'Ausente' : 'Presente'),
          TextCellValue(f.entrada),
          TextCellValue(f.salida),
        ],
    ],
    e,
    colEstado: 3,
    filasMal: [for (final f in d.asistenciaHoy) f.entrada == '-'],
  );

  // ── Faltas de hoy (quiénes faltaron y dónde debían estar) ──────────────────
  final faltas = excel['Faltas hoy'];
  _banner(
      faltas,
      'FALTAS DE HOY (${d.faltaronHoy})',
      d.faltaronHoy == 0 ? 'Sin faltas: asistencia completa. $generado' : generado,
      3,
      e);
  _tabla(
    faltas,
    ['Nombre', 'Rol', 'Obra asignada'],
    [
      for (final f in d.faltasHoy)
        [
          TextCellValue(f.nombre),
          TextCellValue(f.rol),
          TextCellValue(f.obras),
        ],
    ],
    e,
  );

  // ── Historial últimos días (detalle día + hora) ────────────────────────────
  final hist = excel['Historial $diasHistorialReporte dias'];
  _banner(hist, 'HISTORIAL DE ASISTENCIA — ÚLTIMOS $diasHistorialReporte DÍAS',
      generado, 6, e);
  _tabla(
    hist,
    ['Fecha', 'Nombre', 'Rol', 'Obra', 'Hora entrada', 'Hora salida'],
    [
      for (final f in d.historial)
        [
          TextCellValue(f.fecha),
          TextCellValue(f.nombre),
          TextCellValue(f.rol),
          TextCellValue(f.obra),
          TextCellValue(f.entrada),
          TextCellValue(f.salida),
        ],
    ],
    e,
  );

  // ── Personal por rol (ordenado por jerarquía) ──────────────────────────────
  final plant = excel['Personal'];
  _banner(plant, 'PERSONAL', generado, 2, e);
  final ordenado = [...d.personal]..sort((a, b) {
      final na = rolPorClave(a.rol)?.nivel ?? 99;
      final nb = rolPorClave(b.rol)?.nivel ?? 99;
      if (na != nb) return na.compareTo(nb);
      return a.nombre.compareTo(b.nombre);
    });
  _tabla(
    plant,
    ['Rol', 'Nombre'],
    [
      for (final p in ordenado)
        [
          TextCellValue(rolPorClave(p.rol)?.nombre ?? p.rol),
          TextCellValue(p.nombre),
        ],
    ],
    e,
  );

  // ── Clientes ───────────────────────────────────────────────────────────────
  final cli = excel['Clientes'];
  _banner(cli, 'CLIENTES', generado, 1, e);
  _tabla(cli, ['Cliente'],
      [for (final c in d.clientes) [TextCellValue(c.nombre)]], e);

  // ── Obras (estado, asistencia y avance) ────────────────────────────────────
  final ob = excel['Obras'];
  _banner(ob, 'OBRAS', generado, 6, e);
  _tabla(
    ob,
    ['Obra', 'Dirección', 'Estado', 'Asignados', 'Presentes hoy', 'Avance %'],
    [
      for (final o in d.obras)
        [
          TextCellValue(o.nombre),
          TextCellValue(o.direccion),
          TextCellValue(labelEstadoObra(o.estado)),
          IntCellValue(d.asignadosPorObra[o.id] ?? 0),
          IntCellValue(d.presentesPorObra[o.id] ?? 0),
          d.avancePorObra[o.id] != null
              ? IntCellValue(d.avancePorObra[o.id]!)
              : TextCellValue('sin reporte'),
        ],
    ],
    e,
  );

  // ── Tareas ─────────────────────────────────────────────────────────────────
  final tar = excel['Tareas'];
  _banner(tar, 'TAREAS', generado, 6, e);
  _tabla(
    tar,
    ['Título', 'Destino', 'Estado', 'Prioridad', 'Obra', 'Vence'],
    [
      for (final t in d.tareas)
        [
          TextCellValue(t.titulo),
          TextCellValue(t.destinoTexto),
          TextCellValue(estadoTareaLabel(t.estado)),
          TextCellValue(prioridadLabel(t.prioridad)),
          TextCellValue(t.obraNombre),
          TextCellValue(t.fechaEntrega ?? ''),
        ],
    ],
    e,
  );

  // Anchos de columna por hoja (look profesional, sin textos cortados).
  _anchos(resumen, [26, 16]);
  _anchos(asis, [30, 22, 26, 12, 13, 13]);
  _anchos(faltas, [30, 22, 30]);
  _anchos(hist, [12, 30, 22, 26, 13, 13]);
  _anchos(plant, [24, 30]);
  _anchos(cli, [40]);
  _anchos(ob, [30, 32, 16, 12, 14, 10]);
  _anchos(tar, [30, 26, 14, 12, 24, 12]);

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
