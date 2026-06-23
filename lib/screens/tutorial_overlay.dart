import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../core/auth_service.dart';
import '../core/local_store.dart';

/// Tarjeta del tutorial: un emoji temático, título y texto que "explica" el
/// ingeniero 👷.
class _Slide {
  final String emoji, titulo, texto;
  const _Slide(this.emoji, this.titulo, this.texto);
}

const _slides = <AppArea, List<_Slide>>{
  AppArea.operativo: [
    _Slide('👋', 'Bienvenido a Lozcam',
        'Soy tu guía de obra. Te muestro lo básico en 3 pasos.'),
    _Slide('📍', 'Marca tu asistencia',
        'En "Marcar" elige tu obra, acércate al radio en el mapa y marca entrada o salida.'),
    _Slide('✅', 'Tareas y avances',
        'En "Tareas" ves lo asignado a ti; en "Parte de avance" reportas con foto.'),
  ],
  AppArea.gerencia: [
    _Slide('👋', 'Bienvenido, Gerencia',
        'Soy tu guía. Te muestro tu panel en 3 pasos.'),
    _Slide('🗺️', 'Define áreas por GPS',
        'En "Áreas" fijas la ubicación de cada obra y asignas a tus trabajadores.'),
    _Slide('📊', 'Delega y monitorea',
        'En "Tareas" delegas el trabajo; en "Monitor" ves asistencia y avances por área.'),
  ],
  AppArea.cliente: [
    _Slide('👋', 'Bienvenido', 'Soy tu guía. Aquí puedes seguir tu obra.'),
    _Slide('🏗️', 'Tu proyecto',
        'Ves la ubicación, la dirección y el avance reportado de tu obra.'),
  ],
};

Color _colorDe(AppArea a) {
  switch (a) {
    case AppArea.gerencia:
      return AppColors.admin;
    case AppArea.cliente:
      return AppColors.cliente;
    case AppArea.operativo:
      return AppColors.empleado;
  }
}

/// Muestra el tutorial SOLO la primera vez para ese panel/rol.
Future<void> mostrarTutorialSiPrimeraVez(
    BuildContext context, AppArea area) async {
  final clave = area.name;
  if (LocalStore.tutorialVisto(clave)) return;
  await LocalStore.marcarTutorialVisto(clave); // garantiza "una sola vez"
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TutorialDialog(area: area),
  );
}

class _TutorialDialog extends StatefulWidget {
  final AppArea area;
  const _TutorialDialog({required this.area});
  @override
  State<_TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<_TutorialDialog> {
  final _page = PageController();
  int _i = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorDe(widget.area);
    final slides = _slides[widget.area] ?? _slides[AppArea.operativo]!;
    final esUltima = _i == slides.length - 1;

    return Dialog(
      backgroundColor: Colors.white,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: 290,
            child: PageView.builder(
              controller: _page,
              itemCount: slides.length,
              onPageChanged: (v) => setState(() => _i = v),
              itemBuilder: (_, i) => _vistaSlide(slides[i], color),
            ),
          ),
          const SizedBox(height: 10),
          // Indicadores (puntos)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int d = 0; d < slides.length; d++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: d == _i ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: d == _i ? color : AppColors.border,
                      borderRadius: BorderRadius.circular(4)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Saltar',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                if (esUltima) {
                  Navigator.of(context).pop();
                } else {
                  _page.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text(esUltima ? 'Entendido' : 'Siguiente',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _vistaSlide(_Slide s, Color color) {
    final tono = color.withValues(alpha:0.12);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      // El ingeniero
      Container(
        width: 96,
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: tono, shape: BoxShape.circle),
        child: const Text('👷', style: TextStyle(fontSize: 52)),
      ),
      const SizedBox(height: 16),
      // Globo de diálogo
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.screen,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 0.5)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${s.emoji}  ${s.titulo}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
          const SizedBox(height: 6),
          Text(s.texto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSoft, height: 1.4)),
        ]),
      ),
    ]);
  }
}
