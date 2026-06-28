import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/colors.dart';
import '../../theme/app_theme.dart';
import '../../core/ia_service.dart';
import '../../data/reporte_excel.dart';

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

  /// Genera el reporte Excel desde los datos reales (sin IA) y abre la hoja de
  /// compartir para guardarlo/enviarlo. Ante error, lo informa en el chat.
  Future<void> _exportar() async {
    if (_exportando) return;
    setState(() => _exportando = true);
    try {
      final bytes = await generarReporteExcel();
      final dir = await getTemporaryDirectory();
      final ruta = '${dir.path}/${nombreArchivoReporte()}';
      await File(ruta).writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      await Share.shareXFiles(
        [
          XFile(ruta,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        ],
        subject: 'Reporte LOZCAM',
      );
      if (!mounted) return;
      setState(() => _exportando = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _exportando = false;
        _msgs.add(const _Msg(
            false, 'No se pudo generar el reporte Excel. Intenta de nuevo.'));
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
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: BoxDecoration(
          color: context.tokens.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Encabezado
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: const BoxDecoration(
              color: AppColors.admin,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      tooltip: 'Exportar reporte a Excel',
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
                backgroundColor: AppColors.admin,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _enviando ? null : () => _enviar(_ctrl.text),
                ),
              ),
            ]),
          ),
        ]),
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
          color: m.user ? AppColors.admin : context.tokens.appBg,
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
