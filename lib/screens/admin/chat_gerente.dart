import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/app_theme.dart';
import '../../core/descarga.dart';
import '../../core/ia_service.dart';
import '../../data/reporte_excel.dart';
import '../../data/reporte_pdf.dart';

/// Abre el asistente IA del gerente en una hoja inferior.
void mostrarChatGerente(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ChatSheet(),
  );
}

class _Msg {
  final bool user;
  final String text;
  const _Msg(this.user, this.text);
}

const _sugerencias = <String>[
  '¿Cuántos faltaron hoy y de qué áreas?',
  '¿Cómo va el avance de las obras hoy?',
  'Resume el estado de hoy',
];

class _ChatSheet extends StatefulWidget {
  const _ChatSheet();
  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [
    const _Msg(false,
        'Hola, soy tu asistente de monitoreo 👷. Pregúntame por asistencia, ausentes por área, avance de obras o tareas.'),
  ];
  bool _enviando = false;
  bool _exportando = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Selector de formato (Excel/PDF) + plantilla de diseño. El gerente ve una
  /// muestra de color de cada plantilla. Devuelve null si se cierra.
  Future<(FormatoReporte, PlantillaReporte)?> _elegirExportacion() {
    final t = context.tokens;
    var formato = FormatoReporte.excel;
    return showModalBottomSheet<(FormatoReporte, PlantillaReporte)>(
      context: context,
      backgroundColor: t.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Widget opcion(PlantillaReporte p) {
            final pal = paletaDe(p);
            return ListTile(
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: Color(pal.titulo),
                    borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                // Mini-preview: franja de "cabecera" + zebra de la plantilla
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 22, height: 4, color: Color(pal.tituloTexto)),
                  const SizedBox(height: 3),
                  Container(width: 22, height: 4, color: Color(pal.zebra)),
                  const SizedBox(height: 3),
                  Container(width: 22, height: 4, color: Color(pal.zebra)),
                ]),
              ),
              title: Text(plantillaLabel(p),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(plantillaDescripcion(p),
                  style: TextStyle(fontSize: 11, color: t.textSecondary)),
              onTap: () => Navigator.of(ctx).pop((formato, p)),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Exportar reporte',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
                // Formato de descarga
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<FormatoReporte>(
                      segments: [
                        for (final f in FormatoReporte.values)
                          ButtonSegment(
                            value: f,
                            label: Text(formatoLabel(f),
                                style: const TextStyle(fontSize: 12)),
                            icon: Icon(
                                f == FormatoReporte.excel
                                    ? Icons.grid_on
                                    : Icons.picture_as_pdf_outlined,
                                size: 16),
                          ),
                      ],
                      selected: {formato},
                      onSelectionChanged: (s) =>
                          setSheet(() => formato = s.first),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Elige el diseño de la plantilla',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: t.textSecondary)),
                  ),
                ),
                for (final p in PlantillaReporte.values) opcion(p),
                const SizedBox(height: 10),
              ]),
            ),
          );
        },
      ),
    );
  }

  /// Genera el reporte (Excel o PDF) desde los datos reales (sin IA) y abre la
  /// descarga/compartir. Ante error, lo informa en el chat.
  Future<void> _exportar() async {
    if (_exportando) return;
    final sel = await _elegirExportacion();
    if (sel == null || !mounted) return;
    final (formato, plantilla) = sel;
    setState(() => _exportando = true);
    try {
      final bytes = formato == FormatoReporte.excel
          ? await generarReporteExcel(plantilla: plantilla)
          : await generarReportePdf(plantilla: plantilla);
      if (!mounted) return;
      // Fachada multiplataforma: en web descarga por el navegador; en móvil/
      // escritorio guarda y comparte. Devuelve el mensaje a mostrar.
      final msg = await guardarODescargar(
          bytes, nombreArchivoReporte(ext: extensionDe(formato)));
      if (!mounted) return;
      setState(() {
        _exportando = false;
        _msgs.add(_Msg(false, msg));
      });
      _bajar();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _exportando = false;
        _msgs.add(_Msg(false,
            'No se pudo generar el reporte ${formatoLabel(formato)}.\nDetalle técnico: $e'));
      });
      _bajar();
    }
  }

  Future<void> _enviar(String texto) async {
    final pregunta = texto.trim();
    if (pregunta.isEmpty || _enviando) return;
    setState(() {
      _msgs.add(_Msg(true, pregunta));
      _enviando = true;
      _ctrl.clear();
    });
    _bajar();
    final r = await IaService.instance.preguntar(pregunta);
    if (!mounted) return;
    setState(() {
      _msgs.add(_Msg(false, r));
      _enviando = false;
    });
    _bajar();
  }

  void _bajar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.82,
            decoration: BoxDecoration(
              color: context.tokens.surface.withValues(alpha: 0.92),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(
                    color: Colors.white.withValues(alpha: .12), width: 0.8),
              ),
            ),
            child: Column(children: [
          // Encabezado
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: const BoxDecoration(
              color: AppColors.roleAdmin,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(children: [
              const Text('👷', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Asistente de Gerencia',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
              _exportando
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)),
                    )
                  : IconButton(
                      tooltip: 'Exportar reporte (Excel o PDF)',
                      icon: const Icon(Icons.file_download_outlined,
                          color: Colors.white),
                      onPressed: _exportar,
                    ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
          ),
          // Mensajes
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _msgs.length + (_enviando ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _msgs.length) return _escribiendo();
                return _burbuja(_msgs[i]);
              },
            ),
          ),
          // Sugerencias
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (final s in _sugerencias)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(s,
                          style: TextStyle(
                              fontSize: 11, color: context.tokens.brand)),
                      backgroundColor: context.tokens.brandSoft,
                      side: BorderSide.none,
                      onPressed: _enviando ? null : () => _enviar(s),
                    ),
                  ),
              ],
            ),
          ),
          // Entrada
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _enviar,
                  decoration: InputDecoration(
                    hintText: 'Escribe tu pregunta…',
                    isDense: true,
                    filled: true,
                    fillColor: context.tokens.appBg,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: AppColors.roleAdmin,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _enviando ? null : () => _enviar(_ctrl.text),
                ),
              ),
            ]),
          ),
        ]),
      ),
      ),
      ),
    );
  }

  /// Convierte **texto** en spans negrita; el resto queda normal. El color base
  /// lo hereda cada span del estilo del TextSpan padre (en _burbuja).
  List<TextSpan> _parsearTexto(String texto) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int cursor = 0;
    for (final match in regex.allMatches(texto)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: texto.substring(cursor, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));
      cursor = match.end;
    }
    if (cursor < texto.length) {
      spans.add(TextSpan(text: texto.substring(cursor)));
    }
    return spans;
  }

  Widget _burbuja(_Msg m) {
    final colorTexto = m.user ? Colors.white : context.tokens.textPrimary;
    return Align(
      alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: m.user ? AppColors.roleAdmin : context.tokens.appBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text.rich(
          TextSpan(
            style: TextStyle(
                fontSize: 13, height: 1.35, color: colorTexto),
            children: _parsearTexto(m.text),
          ),
        ),
      ),
    );
  }

  Widget _escribiendo() {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}
