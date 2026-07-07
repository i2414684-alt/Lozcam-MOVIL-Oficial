import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/diseno_obra.dart';

/// ============================================================================
///  DISEÑO PROGRESIVO — gráfico "blueprint" que se CONSTRUYE con el avance.
///
///  Dibuja un esquema genérico (no un plano arquitectónico real) del tipo de
///  trabajo: terreno topográfico, plano AutoCAD, casa, edificio, puente,
///  pista o vereda. Toda la geometría aparece como guía tenue (líneas de
///  plano) y se va "construyendo" en color conforme sube [progreso] (0..1).
///  Encima se pintan manchas de CALOR según los días trabajados ([calorDias]).
/// ============================================================================

/// Rampa térmica estándar (fría → caliente): azul · verde · amarillo · rojo.
/// Se usa tanto para pintar las manchas de calor como para la leyenda.
const List<Color> heatRampColors = [
  Color(0xFF2979FF), // azul — baja intensidad
  Color(0xFF00BFA5), // verde-azulado
  Color(0xFFFFD600), // amarillo
  Color(0xFFFF3D00), // rojo — alta intensidad
];

/// Interpola un color de [heatRampColors] según la intensidad [w] (0..1).
Color colorTermico(double w) {
  final t = w.clamp(0.0, 1.0) * (heatRampColors.length - 1);
  final i = t.floor().clamp(0, heatRampColors.length - 2);
  final f = t - i;
  return Color.lerp(heatRampColors[i], heatRampColors[i + 1], f)!;
}

class DisenoProgresivo extends StatelessWidget {
  final FaseDiseno fase;
  final double progreso; // 0..1
  final List<double> calorDias; // intensidad por día (0..1), antiguo -> hoy
  final Color acento; // color de lo construido (naranja Lozcam)
  final Color guia; // color de las líneas pendientes
  final Color fondo;

  const DisenoProgresivo({
    super.key,
    required this.fase,
    required this.progreso,
    this.calorDias = const [],
    required this.acento,
    required this.guia,
    required this.fondo,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progreso.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, p, __) => CustomPaint(
          painter: _DisenoPainter(
            fase: fase,
            progreso: p,
            calorDias: calorDias,
            acento: acento,
            guia: guia,
            fondo: fondo,
          ),
        ),
      ),
    );
  }
}

class _DisenoPainter extends CustomPainter {
  final FaseDiseno fase;
  final double progreso;
  final List<double> calorDias;
  final Color acento, guia, fondo;

  _DisenoPainter({
    required this.fase,
    required this.progreso,
    required this.calorDias,
    required this.acento,
    required this.guia,
    required this.fondo,
  });

  // Coordenadas lógicas 100x62 -> se escalan al tamaño real.
  late double _sx, _sy;
  Offset _p(double x, double y) => Offset(x * _sx, y * _sy);

  late final Paint _guiaP = Paint()
    ..color = guia.withValues(alpha: .45)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1;

  static Color _lighten(Color c, [double a = .10]) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + a).clamp(0.0, 1.0)).toColor();
  }

  static Color _darken(Color c, [double a = .12]) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - a).clamp(0.0, 1.0)).toColor();
  }

  bool get _esOscuro => fondo.computeLuminance() < .3;

  @override
  void paint(Canvas canvas, Size size) {
    _sx = size.width / 100;
    _sy = size.height / 62;

    _fondoMesa(canvas, size);

    // Geometría por tipo: lista de trazos; cada trazo se "construye" en orden.
    final trazos = _trazosDe(fase);
    final visibles = progreso * trazos.length;
    for (var i = 0; i < trazos.length; i++) {
      // Guía tenue siempre (el "plano" completo)
      final path = _pathDe(trazos[i]);
      canvas.drawPath(path, _guiaP);
      if (trazos[i].puerta) _arcoPuerta(canvas, trazos[i], _guiaP);
      // Construido: trazo con glow + gradiente + extrusión (acabado 3D)
      final f = (visibles - i).clamp(0.0, 1.0);
      if (f > 0) _dibujarHecho(canvas, trazos[i], path, f);
    }

    _manchasCalor(canvas, size);
    _vineta(canvas, size);
  }

  /// Mesa de dibujo: fondo con leve luz central + cuadrícula fina y maestra.
  void _fondoMesa(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = fondo);
    canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            radius: 1.0,
            colors: [
              _lighten(fondo, _esOscuro ? .04 : .02),
              fondo.withValues(alpha: 0),
            ],
          ).createShader(rect));
    final menor = Paint()
      ..color = guia.withValues(alpha: .08)
      ..strokeWidth = 0.5;
    final mayor = Paint()
      ..color = guia.withValues(alpha: .18)
      ..strokeWidth = 0.8;
    for (var x = 0.0; x <= 100; x += 5) {
      canvas.drawLine(_p(x, 0), _p(x, 62), x % 20 == 0 ? mayor : menor);
    }
    for (var y = 0.0; y <= 62; y += 5) {
      canvas.drawLine(_p(0, y), _p(100, y), y % 20 == 0 ? mayor : menor);
    }
  }

  /// Trazo construido con acabado premium: sombra de extrusión (3D), halo de
  /// luz (glow), núcleo con gradiente metálico y relleno degradado.
  void _dibujarHecho(Canvas canvas, _Trazo t, Path path, double f) {
    final bounds = path.getBounds().inflate(2);

    // 1) Extrusión: copia desplazada y difuminada -> el trazo "se levanta".
    if (f >= .6) {
      canvas.save();
      canvas.translate(2.2, 3.2);
      canvas.drawPath(
          path,
          Paint()
            ..color = Colors.black.withValues(alpha: (_esOscuro ? .45 : .18) * f)
            ..style = t.cerrar ? PaintingStyle.fill : PaintingStyle.stroke
            ..strokeWidth = 3
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.restore();
    }

    // 2) Glow: halo del color de marca alrededor del trazo.
    canvas.drawPath(
        path,
        Paint()
          ..color = acento.withValues(alpha: .35 * f)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

    // 3) Relleno degradado para formas cerradas (vidrio naranja).
    if (t.cerrar) {
      canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                acento.withValues(alpha: .34 * f),
                acento.withValues(alpha: .07 * f),
              ],
            ).createShader(bounds));
    }

    // 4) Núcleo: línea con gradiente (luz arriba-izq, sombra abajo-der).
    canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _lighten(acento, .14).withValues(alpha: .55 + .45 * f),
              _darken(acento, .10).withValues(alpha: .55 + .45 * f),
            ],
          ).createShader(bounds)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round);

    if (t.puerta) {
      _arcoPuerta(
          canvas,
          t,
          Paint()
            ..color = acento.withValues(alpha: .5 + .5 * f)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4);
    }
  }

  /// Viñeta perimetral: enfoca la mirada al centro (acabado cinematográfico).
  void _vineta(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            radius: 1.15,
            colors: [
              Colors.black.withValues(alpha: 0),
              Colors.black.withValues(alpha: _esOscuro ? .32 : .08),
            ],
            stops: const [.62, 1],
          ).createShader(rect));
  }

  /// Cada trazo: lista de puntos lógicos + si se cierra + si admite relleno.
  List<_Trazo> _trazosDe(FaseDiseno f) {
    switch (f) {
      case FaseDiseno.topografico:
        // Curvas de nivel concéntricas irregulares + estacas de replanteo.
        return [
          _curva([ (8,54),(20,44),(38,48),(60,42),(80,48),(93,40) ]),
          _curva([ (14,46),(28,36),(48,40),(68,34),(88,38) ]),
          _curva([ (22,38),(36,28),(55,32),(74,26),(90,30) ]),
          _curva([ (30,30),(44,20),(62,24),(80,18) ]),
          _curva([ (38,22),(52,12),(68,16) ]),
          const _Trazo([ (12,56),(12,52) ]), // estacas
          const _Trazo([ (50,52),(50,48) ]),
          const _Trazo([ (86,50),(86,46) ]),
          const _Trazo([ (30,14),(30,10) ]),
          const _Trazo([ (70,10),(70,6) ]),
        ];
      case FaseDiseno.plano:
        // Plano simple de vivienda: muro perimetral, divisiones y puerta.
        return [
          const _Trazo([ (14,10),(86,10),(86,52),(14,52) ], cerrar: true),
          const _Trazo([ (14,30),(52,30) ]),
          const _Trazo([ (52,10),(52,38) ]),
          const _Trazo([ (52,38),(86,38) ]),
          const _Trazo([ (68,38),(68,52) ]),
          const _Trazo([ (30,52),(38,52) ], puerta: true),
          const _Trazo([ (52,20),(60,20) ], puerta: true),
          const _Trazo([ (20,14),(30,14),(30,26),(20,26) ], cerrar: true), // baño
        ];
      case FaseDiseno.casa:
        return [
          const _Trazo([ (20,54),(80,54) ]), // cimiento
          const _Trazo([ (24,54),(24,32),(76,32),(76,54) ]), // muros
          const _Trazo([ (18,32),(50,14),(82,32) ]), // techo
          const _Trazo([ (44,54),(44,40),(56,40),(56,54) ]), // puerta
          const _Trazo([ (28,38),(38,38),(38,46),(28,46) ], cerrar: true), // ventana
          const _Trazo([ (62,38),(72,38),(72,46),(62,46) ], cerrar: true), // ventana
        ];
      case FaseDiseno.edificio:
        // Torre de 6 pisos que crece de abajo hacia arriba.
        final t = <_Trazo>[ const _Trazo([ (26,56),(74,56) ]) ];
        for (var piso = 0; piso < 6; piso++) {
          final y1 = 56.0 - (piso + 1) * 7.5;
          final y2 = 56.0 - piso * 7.5;
          t.add(_Trazo([ (30, y2),(30, y1),(70, y1),(70, y2) ]));
          t.add(_Trazo([ (36, y1 + 2.2),(44, y1 + 2.2),(44, y2 - 2.2),(36, y2 - 2.2) ], cerrar: true));
          t.add(_Trazo([ (56, y1 + 2.2),(64, y1 + 2.2),(64, y2 - 2.2),(56, y2 - 2.2) ], cerrar: true));
        }
        t.add(const _Trazo([ (50,11),(50,4) ])); // antena al 100%
        return t;
      case FaseDiseno.puente:
        return [
          const _Trazo([ (14,50),(14,26) ]), // pilar izq
          const _Trazo([ (86,50),(86,26) ]), // pilar der
          const _Trazo([ (4,34),(96,34) ]), // tablero
          const _Trazo([ (14,26),(34,34) ]), // tirantes
          const _Trazo([ (14,26),(54,34) ]),
          const _Trazo([ (86,26),(66,34) ]),
          const _Trazo([ (86,26),(46,34) ]),
          const _Trazo([ (4,50),(96,50) ]), // cauce
        ];
      case FaseDiseno.pista:
        // Vía que se pavimenta de izquierda a derecha.
        return [
          const _Trazo([ (4,24),(96,24) ]),
          const _Trazo([ (4,44),(96,44) ]),
          const _Trazo([ (8,34),(20,34) ]),
          const _Trazo([ (28,34),(40,34) ]),
          const _Trazo([ (48,34),(60,34) ]),
          const _Trazo([ (68,34),(80,34) ]),
          const _Trazo([ (88,34),(94,34) ]),
        ];
      case FaseDiseno.vereda:
        // Paños de vereda que se vacían uno a uno.
        final t = <_Trazo>[
          const _Trazo([ (6,26),(94,26) ]),
          const _Trazo([ (6,46),(94,46) ]),
        ];
        for (var i = 0; i < 6; i++) {
          final x = 6.0 + i * 14.7;
          t.add(_Trazo(
              [ (x,26),(x + 14.7,26),(x + 14.7,46),(x,46) ], cerrar: true));
        }
        return t;
    }
  }

  _Trazo _curva(List<(double, double)> pts) => _Trazo(pts, curva: true);

  /// Construye el Path escalado de un trazo (líneas o curva suavizada).
  Path _pathDe(_Trazo t) {
    final path = Path()
      ..moveTo(_p(t.pts.first.$1, t.pts.first.$2).dx,
          _p(t.pts.first.$1, t.pts.first.$2).dy);
    if (t.curva) {
      for (var i = 1; i < t.pts.length - 1; i++) {
        final a = _p(t.pts[i].$1, t.pts[i].$2);
        final b = _p(t.pts[i + 1].$1, t.pts[i + 1].$2);
        path.quadraticBezierTo(
            a.dx, a.dy, (a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      }
    } else {
      for (var i = 1; i < t.pts.length; i++) {
        final o = _p(t.pts[i].$1, t.pts[i].$2);
        path.lineTo(o.dx, o.dy);
      }
    }
    if (t.cerrar) path.close();
    return path;
  }

  /// Arco de puerta (detalle de plano AutoCAD).
  void _arcoPuerta(Canvas canvas, _Trazo t, Paint paint) {
    final a = _p(t.pts.first.$1, t.pts.first.$2);
    final b = _p(t.pts.last.$1, t.pts.last.$2);
    final r = (b - a).distance;
    canvas.drawArc(
        Rect.fromCircle(center: a, radius: r), 0, math.pi / 2, false, paint);
  }

  /// Manchas de calor TÉRMICAS con la rampa estándar azul→verde→amarillo→rojo
  /// (como cámara termográfica). Un foco por día trabajado, posición
  /// determinística e intensidad según cuánto se trabajó ese día. Cada foco
  /// se pinta en dos capas —halo externo muy difuso y cuerpo con núcleo
  /// luminoso— para que las zonas se fusionen de forma orgánica y sin bordes
  /// duros: las de baja intensidad quedan translúcidas y extensas (azul/
  /// verde), las de máxima intensidad quedan densas y luminosas (rojo).
  void _manchasCalor(Canvas canvas, Size size) {
    for (var i = 0; i < calorDias.length; i++) {
      final w = calorDias[i];
      if (w <= 0) continue;
      // Posición estable por índice de día (espiral áurea sobre el lienzo)
      final ang = i * 2.39996; // ángulo áureo
      final rad = 0.16 + 0.22 * ((i * 37) % 10) / 10;
      final c = Offset(
        size.width * (0.5 + rad * math.cos(ang)),
        size.height * (0.5 + rad * math.sin(ang)),
      );
      final color = colorTermico(w);

      // 1) Halo externo: muy extenso, muy translúcido y muy desenfocado ->
      //    difusión suave que se fusiona con los focos vecinos.
      final radioHalo = size.shortestSide * (0.22 + 0.30 * w);
      canvas.drawCircle(
          c,
          radioHalo,
          Paint()
            ..shader = RadialGradient(colors: [
              color.withValues(alpha: .10 + .12 * w),
              color.withValues(alpha: 0),
            ]).createShader(Rect.fromCircle(center: c, radius: radioHalo))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));

      // 2) Cuerpo + núcleo: degradado radial en el color de la rampa térmica,
      //    con centro más blanco/luminoso cuanto mayor la intensidad.
      final radio = size.shortestSide * (0.12 + 0.16 * w);
      final rect = Rect.fromCircle(center: c, radius: radio);
      canvas.drawCircle(
          c,
          radio,
          Paint()
            ..shader = RadialGradient(
              colors: [
                Colors.white.withValues(alpha: .16 + .30 * w),
                color.withValues(alpha: .24 + .30 * w),
                color.withValues(alpha: .08 + .14 * w),
                color.withValues(alpha: 0),
              ],
              stops: const [0, .30, .60, 1],
            ).createShader(rect)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    }
  }

  @override
  bool shouldRepaint(_DisenoPainter old) =>
      old.progreso != progreso ||
      old.fase != fase ||
      old.calorDias != calorDias;
}

class _Trazo {
  final List<(double, double)> pts;
  final bool cerrar;
  final bool curva;
  final bool puerta;
  const _Trazo(this.pts,
      {this.cerrar = false, this.curva = false, this.puerta = false});
}
