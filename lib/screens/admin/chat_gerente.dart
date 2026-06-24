import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../core/ia_service.dart';

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

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      backgroundColor: AppColors.orangeBg,
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
                    fillColor: AppColors.screen,
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

  Widget _burbuja(_Msg m) {
    return Align(
      alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: m.user ? AppColors.admin : AppColors.screen,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(m.text,
            style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: m.user ? Colors.white : AppColors.textDark)),
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
