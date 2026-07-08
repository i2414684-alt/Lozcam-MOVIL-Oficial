import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/diseno_obra.dart';

/// ============================================================================
///  DISEÑO 3D — modelo ESTÁTICO (no depende del avance) y rotable/zoomable.
///
///  Reemplaza el antiguo "blueprint" 2D que se revelaba con el % de avance.
///  Ahora el modelo siempre se ve completo; el avance real de la obra se
///  sigue comunicando aparte (badge, barra de progreso, StatCard) en
///  mapa_calor_obra.dart. Motor 3D propio en Dart puro (sin paquetes nuevos):
///  cámara con yaw interactivo (drag horizontal) + zoom (pinch), pitch fijo
///  para no competir con el scroll vertical de la pantalla que lo contiene.
///  Las manchas de calor (`calorDias`) se mantienen como "billboards"
///  proyectados sobre la escena 3D.
/// ============================================================================

/// Rampa térmica estándar (fría → caliente): azul · verde · amarillo · rojo.
const List<Color> heatRampColors = [
  Color(0xFF2979FF),
  Color(0xFF00BFA5),
  Color(0xFFFFD600),
  Color(0xFFFF3D00),
];

Color colorTermico(double w) {
  final t = w.clamp(0.0, 1.0) * (heatRampColors.length - 1);
  final i = t.floor().clamp(0, heatRampColors.length - 2);
  final f = t - i;
  return Color.lerp(heatRampColors[i], heatRampColors[i + 1], f)!;
}

// ═══════════════════════════ Álgebra 3D mínima ═════════════════════════════

class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);
  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);
  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;
  Vec3 cross(Vec3 o) =>
      Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(x * x + y * y + z * z);
  Vec3 get normalizado {
    final l = length;
    return l < 1e-9 ? this : Vec3(x / l, y / l, z / l);
  }
}

Vec3 _rotarY(Vec3 v, double a) {
  final c = math.cos(a), s = math.sin(a);
  return Vec3(v.x * c + v.z * s, v.y, -v.x * s + v.z * c);
}

Vec3 _rotarX(Vec3 v, double a) {
  final c = math.cos(a), s = math.sin(a);
  return Vec3(v.x, v.y * c - v.z * s, v.y * s + v.z * c);
}

Color _mezclar(Color a, Color b, double t) => Color.lerp(a, b, t)!;

Color _aclarar(Color c, [double a = .10]) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness + a).clamp(0.0, 1.0)).toColor();
}

Color _oscurecer(Color c, [double a = .12]) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness - a).clamp(0.0, 1.0)).toColor();
}

// ═══════════════════════════ Malla (mesh) por fase ═════════════════════════

/// Polígono plano (cara). Se dibuja con [Canvas.drawPath], por eso las caras
/// se construyen SIEMPRE planas (evita necesitar un tesselator).
class Cara3D {
  final List<Vec3> vertices;
  final Color color;
  final double emisivo; // 0..1 — "brilla" aunque no reciba luz (vidrio)
  const Cara3D(this.vertices, this.color, {this.emisivo = 0});
}

/// Línea/alambre 3D — cables, antena, líneas de centro, estacas, arco puerta.
class Arista3D {
  final List<Vec3> puntos;
  final Color color;
  final double grosor;
  final double glow; // 0..1 — halo extra difuminado
  const Arista3D(this.puntos, this.color, {this.grosor = 1.4, this.glow = 0});
}

/// Modelo completo de una fase, con su encuadre (centro/radio) precalculado
/// para que la cámara auto-ajuste el zoom sin importar cuánto varía la altura
/// real entre fases (un edificio de 6 pisos vs. una vereda casi plana).
class Malla3D {
  final List<Cara3D> caras;
  final List<Arista3D> aristas;
  late final Vec3 centro;
  late final double radio;
  late final double extentX, extentZ, alturaTope;

  Malla3D(this.caras, this.aristas) {
    var minX = 1e9, maxX = -1e9;
    var minY = 1e9, maxY = -1e9;
    var minZ = 1e9, maxZ = -1e9;
    void considerar(Vec3 v) {
      if (v.x < minX) minX = v.x;
      if (v.x > maxX) maxX = v.x;
      if (v.y < minY) minY = v.y;
      if (v.y > maxY) maxY = v.y;
      if (v.z < minZ) minZ = v.z;
      if (v.z > maxZ) maxZ = v.z;
    }

    for (final c in caras) {
      for (final v in c.vertices) {
        considerar(v);
      }
    }
    for (final a in aristas) {
      for (final v in a.puntos) {
        considerar(v);
      }
    }
    if (minX > maxX) {
      minX = 0;
      maxX = 100;
      minY = 0;
      maxY = 10;
      minZ = 0;
      maxZ = 62;
    }
    centro = Vec3((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2);
    final r = [maxX - minX, maxY - minY, maxZ - minZ].reduce(math.max) / 2;
    radio = r < 6 ? 6 : r;
    extentX = (maxX - minX) / 2;
    extentZ = (maxZ - minZ) / 2;
    alturaTope = maxY;
  }
}

// ── Helpers de extrusión genéricos (reusados por casi todas las fases) ─────

/// Extruye una polilínea (puntos en el plano suelo XZ) en una cinta de caras
/// verticales, una por segmento, entre alturas [y0] e [y1].
List<Cara3D> _extruirMuro(
    List<(double, double)> xz, double y0, double y1, Color color,
    {double emisivo = 0}) {
  final out = <Cara3D>[];
  for (var i = 0; i < xz.length - 1; i++) {
    final a = xz[i], b = xz[i + 1];
    out.add(Cara3D([
      Vec3(a.$1, y0, a.$2),
      Vec3(b.$1, y0, b.$2),
      Vec3(b.$1, y1, b.$2),
      Vec3(a.$1, y1, a.$2),
    ], color, emisivo: emisivo));
  }
  return out;
}

/// Tapa plana (piso/techo) para un perímetro cerrado, a altura [y] fija.
Cara3D _tapaPlana(List<(double, double)> xzCerrado, double y, Color color,
        {double emisivo = 0}) =>
    Cara3D([for (final p in xzCerrado) Vec3(p.$1, y, p.$2)], color,
        emisivo: emisivo);

/// Caja rectangular alineada a ejes (footprint XZ, altura Y).
List<Cara3D> _caja(double x0, double x1, double z0, double z1, double y0,
    double y1, Color color) {
  final perim = [(x0, z0), (x1, z0), (x1, z1), (x0, z1), (x0, z0)];
  final caras = _extruirMuro(perim, y0, y1, color);
  caras.add(_tapaPlana(perim.sublist(0, 4), y1, color));
  caras.add(_tapaPlana(perim.sublist(0, 4).reversed.toList(), y0, color));
  return caras;
}

/// Barre una silueta cerrada del plano de elevación XY a lo largo de Z —
/// da paredes + techo como una sola "piel" extruida en una sola llamada.
List<Cara3D> _extruirPerfil(
    List<(double, double)> xyCerrado, double zFrente, double zFondo,
    Color color) {
  final caras = <Cara3D>[
    Cara3D([for (final p in xyCerrado) Vec3(p.$1, p.$2, zFrente)], color),
    Cara3D(
        [for (final p in xyCerrado.reversed) Vec3(p.$1, p.$2, zFondo)],
        color),
  ];
  for (var i = 0; i < xyCerrado.length - 1; i++) {
    final a = xyCerrado[i], b = xyCerrado[i + 1];
    caras.add(Cara3D([
      Vec3(a.$1, a.$2, zFrente),
      Vec3(b.$1, b.$2, zFrente),
      Vec3(b.$1, b.$2, zFondo),
      Vec3(a.$1, a.$2, zFondo),
    ], color));
  }
  return caras;
}

Cara3D _quadPlano(List<(double, double, double)> xyz, Color color,
        {double emisivo = 0}) =>
    Cara3D([for (final p in xyz) Vec3(p.$1, p.$2, p.$3)], color,
        emisivo: emisivo);

Arista3D _arcoPuertaArista((double, double) a, (double, double) b, Color c) {
  final r = math.sqrt(math.pow(b.$1 - a.$1, 2) + math.pow(b.$2 - a.$2, 2));
  final pts = <Vec3>[
    for (var t = 0; t <= 16; t++)
      Vec3(a.$1 + r * math.cos(t / 16 * math.pi / 2), 0.02,
          a.$2 + r * math.sin(t / 16 * math.pi / 2)),
  ];
  return Arista3D(pts, c, grosor: 1.2, glow: .3);
}

// ── Terreno (heightmap) para la fase topográfica ────────────────────────────

const List<(double, double, double, double)> _colinas = [
  (25, 20, 9, 22), // cx, cz, pico, dispersión
  (72, 16, 6, 18),
  (46, 46, 4.5, 16),
  (82, 42, 7, 20),
];

double _alturaTerreno(double x, double z) {
  var h = 0.0;
  for (final c in _colinas) {
    final dx = x - c.$1, dz = z - c.$2;
    h += c.$3 * math.exp(-(dx * dx + dz * dz) / (2 * c.$4 * c.$4));
  }
  return h;
}

// ── Material base: superficies grandes en un tono neutro con ADN de marca;
//    el naranja puro queda reservado para bordes/vidrios/acentos ──────────
Color _materialBase(Color acento, Color guia) =>
    _mezclar(_mezclar(guia, Colors.white, .55), acento, .18)
        .withValues(alpha: .97);

Malla3D _mallaDe(FaseDiseno f, Color acento, Color guia) {
  final base = _materialBase(acento, guia);
  switch (f) {
    case FaseDiseno.topografico:
      return _mallaTopografico(acento);
    case FaseDiseno.plano:
      return _mallaPlano(acento, base);
    case FaseDiseno.casa:
      return _mallaCasa(acento, base);
    case FaseDiseno.edificio:
      return _mallaEdificio(acento, base);
    case FaseDiseno.puente:
      return _mallaPuente(acento, base);
    case FaseDiseno.pista:
      return _mallaPista(acento);
    case FaseDiseno.vereda:
      return _mallaVereda(acento);
  }
}

Malla3D _mallaTopografico(Color acento) {
  const nx = 14, nz = 9;
  const x0 = 5.0, x1 = 95.0, z0 = 4.0, z1 = 58.0;
  final color = _mezclar(acento, const Color(0xFF6B5B3E), .55);
  Vec3 v(int i, int j) {
    final x = x0 + (x1 - x0) * i / (nx - 1);
    final z = z0 + (z1 - z0) * j / (nz - 1);
    return Vec3(x, _alturaTerreno(x, z), z);
  }

  final caras = <Cara3D>[];
  for (var j = 0; j < nz - 1; j++) {
    for (var i = 0; i < nx - 1; i++) {
      final a = v(i, j), b = v(i + 1, j), c = v(i + 1, j + 1), d = v(i, j + 1);
      caras.add(Cara3D([a, b, c], color));
      caras.add(Cara3D([a, c, d], color));
    }
  }
  final aristas = <Arista3D>[
    for (final p in const [
      (12.0, 54.0),
      (50.0, 50.0),
      (86.0, 48.0),
      (30.0, 12.0),
      (70.0, 8.0),
    ])
      Arista3D(
          [
            Vec3(p.$1, _alturaTerreno(p.$1, p.$2), p.$2),
            Vec3(p.$1, _alturaTerreno(p.$1, p.$2) + 3.2, p.$2),
          ],
          acento,
          grosor: 1.6,
          glow: .55),
  ];
  return Malla3D(caras, aristas);
}

Malla3D _mallaPlano(Color acento, Color base) {
  const alturaMuro = 6.0, alturaPuerta = 1.0;
  final caras = <Cara3D>[
    ..._extruirMuro(
        const [(14, 10), (86, 10), (86, 52), (14, 52), (14, 10)], 0,
        alturaMuro, base),
    ..._extruirMuro(const [(14, 30), (52, 30)], 0, alturaMuro, base),
    ..._extruirMuro(const [(52, 10), (52, 38)], 0, alturaMuro, base),
    ..._extruirMuro(const [(52, 38), (86, 38)], 0, alturaMuro, base),
    ..._extruirMuro(const [(68, 38), (68, 52)], 0, alturaMuro, base),
    ..._extruirMuro(const [(30, 52), (38, 52)], 0, alturaPuerta, base),
    ..._extruirMuro(const [(52, 20), (60, 20)], 0, alturaPuerta, base),
    ..._extruirMuro(
        const [(20, 14), (30, 14), (30, 26), (20, 26), (20, 14)], 0,
        alturaMuro, base),
    _tapaPlana(const [(14, 10), (86, 10), (86, 52), (14, 52)], .15,
        acento.withValues(alpha: .30),
        emisivo: .35),
  ];
  final aristas = <Arista3D>[
    _arcoPuertaArista((30.0, 52.0), (38.0, 52.0), acento),
    _arcoPuertaArista((52.0, 20.0), (60.0, 20.0), acento),
  ];
  return Malla3D(caras, aristas);
}

Malla3D _mallaCasa(Color acento, Color base) {
  const zFrente = 22.0, zFondo = 40.0;
  const silueta = [
    (24.0, 0.0),
    (24.0, 22.0),
    (50.0, 40.0),
    (76.0, 22.0),
    (76.0, 0.0),
    (24.0, 0.0),
  ];
  final caras = <Cara3D>[
    ..._extruirPerfil(silueta, zFrente, zFondo, base),
    _quadPlano([
      (28.0, 8.0, zFrente - .3),
      (38.0, 8.0, zFrente - .3),
      (38.0, 16.0, zFrente - .3),
      (28.0, 16.0, zFrente - .3),
    ], acento, emisivo: .6),
    _quadPlano([
      (62.0, 8.0, zFrente - .3),
      (72.0, 8.0, zFrente - .3),
      (72.0, 16.0, zFrente - .3),
      (62.0, 16.0, zFrente - .3),
    ], acento, emisivo: .6),
    _quadPlano([
      (44.0, 0.0, zFrente - .25),
      (56.0, 0.0, zFrente - .25),
      (56.0, 14.0, zFrente - .25),
      (44.0, 14.0, zFrente - .25),
    ], _oscurecer(_oscurecer(base, .22), .22)),
  ];
  return Malla3D(caras, const []);
}

Malla3D _mallaEdificio(Color acento, Color base) {
  const zFrente = 23.0, zFondo = 39.0, x0 = 30.0, x1 = 70.0, floorH = 7.5;
  final caras = <Cara3D>[];
  for (var piso = 0; piso < 6; piso++) {
    final y0 = piso * floorH, y1 = (piso + 1) * floorH;
    caras.addAll(_extruirMuro(
        [(x0, zFrente), (x1, zFrente), (x1, zFondo), (x0, zFondo),
          (x0, zFrente)],
        y0, y1, base));
    final wy0 = y0 + 2.2, wy1 = y1 - 2.2;
    caras.add(_quadPlano([
      (36.0, wy0, zFrente - .3),
      (44.0, wy0, zFrente - .3),
      (44.0, wy1, zFrente - .3),
      (36.0, wy1, zFrente - .3),
    ], acento, emisivo: .55));
    caras.add(_quadPlano([
      (56.0, wy0, zFrente - .3),
      (64.0, wy0, zFrente - .3),
      (64.0, wy1, zFrente - .3),
      (56.0, wy1, zFrente - .3),
    ], acento, emisivo: .55));
  }
  caras.add(_tapaPlana(
      [(x0, zFrente), (x1, zFrente), (x1, zFondo), (x0, zFondo)],
      6 * floorH, base));
  final aristas = <Arista3D>[
    Arista3D(const [Vec3(50, 6 * floorH, 31), Vec3(50, 6 * floorH + 7, 31)],
        acento, grosor: 1.6, glow: .5),
  ];
  return Malla3D(caras, aristas);
}

Malla3D _mallaPuente(Color acento, Color base) {
  const zC = 31.0;
  final agua = _mezclar(acento, const Color(0xFF1560C4), .78);
  final caras = <Cara3D>[
    ..._caja(12.5, 15.5, zC - 6, zC + 6, 0, 24, base),
    ..._caja(84.5, 87.5, zC - 6, zC + 6, 0, 24, base),
    ..._caja(4, 96, zC - 6, zC + 6, 16, 18.5, base),
    _quadPlano([
      (4.0, -1.0, zC - 6),
      (96.0, -1.0, zC - 6),
      (96.0, -1.0, zC + 6),
      (4.0, -1.0, zC + 6),
    ], agua.withValues(alpha: .55)),
  ];
  Arista3D cable(double px, double pDeckX) => Arista3D(
      [Vec3(px, 24, zC), Vec3(pDeckX, 18.5, zC)], acento,
      grosor: 1.3, glow: .45);
  final aristas = [cable(14, 34), cable(14, 54), cable(86, 66), cable(86, 46)];
  return Malla3D(caras, aristas);
}

Malla3D _mallaPista(Color acento) {
  const asfalto = Color(0xFF3B3F46);
  final caras = <Cara3D>[..._caja(4, 96, 24, 44, 0, 1.4, asfalto)];
  const marca = Color(0xFFFFD54F);
  final aristas = <Arista3D>[
    for (final seg in const [
      (8.0, 20.0),
      (28.0, 40.0),
      (48.0, 60.0),
      (68.0, 80.0),
      (88.0, 94.0),
    ])
      Arista3D([Vec3(seg.$1, 1.55, 34), Vec3(seg.$2, 1.55, 34)], marca,
          grosor: 2.0, glow: .25),
  ];
  return Malla3D(caras, aristas);
}

Malla3D _mallaVereda(Color acento) {
  const concreto = Color(0xFFBFC3C9);
  final caras = <Cara3D>[..._caja(6, 94, 26, 46, 0, 1.1, concreto)];
  const junta = Color(0xFF8A8E94);
  final aristas = <Arista3D>[
    for (var i = 1; i < 6; i++)
      Arista3D(
          [Vec3(6 + i * 14.7, 1.15, 26), Vec3(6 + i * 14.7, 1.15, 46)],
          junta,
          grosor: 1.4),
  ];
  return Malla3D(caras, aristas);
}

// ═══════════════════════════ Widget interactivo ════════════════════════════

class Diseno3D extends StatefulWidget {
  final FaseDiseno fase;
  final List<double> calorDias;
  final Color acento;
  final Color guia;
  final Color fondo;

  const Diseno3D({
    super.key,
    required this.fase,
    this.calorDias = const [],
    required this.acento,
    required this.guia,
    required this.fondo,
  });

  @override
  State<Diseno3D> createState() => _Diseno3DState();
}

class _Diseno3DState extends State<Diseno3D> with TickerProviderStateMixin {
  static const double _pitch = -0.40; // cámara fija ~23° mirando hacia abajo
  static const double _yawInicial = -0.6;

  late Malla3D _malla;
  double _yaw = _yawInicial;
  double _zoom = 1.0;
  double _zoomInicioGesto = 1.0;

  late final AnimationController _introCtrl;
  late final AnimationController _autoCtrl;
  AnimationController? _resetCtrl;

  @override
  void initState() {
    super.initState();
    _malla = _mallaDe(widget.fase, widget.acento, widget.guia);
    _introCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 850))
          ..forward();
    _autoCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 40))
          ..repeat();
  }

  @override
  void didUpdateWidget(covariant Diseno3D old) {
    super.didUpdateWidget(old);
    if (old.fase != widget.fase || old.acento != widget.acento || old.guia != widget.guia) {
      _malla = _mallaDe(widget.fase, widget.acento, widget.guia);
    }
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _autoCtrl.dispose();
    _resetCtrl?.dispose();
    super.dispose();
  }

  /// Congela la rotación automática en el ángulo actual apenas el usuario
  /// toca la escena, para que no "salte" al detenerse.
  void _detenerAuto() {
    if (_autoCtrl.isAnimating) {
      setState(() {
        _yaw += _autoCtrl.value * 2 * math.pi;
        _autoCtrl.stop();
        _autoCtrl.value = 0;
      });
    }
  }

  void _resetear() {
    _detenerAuto();
    _resetCtrl?.dispose();
    final yawInicio = _yaw, zoomInicio = _zoom;
    final ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _resetCtrl = ctrl;
    ctrl.addListener(() {
      if (!mounted) return;
      final t = Curves.easeOutCubic.transform(ctrl.value);
      setState(() {
        _yaw = yawInicio + (_yawInicial - yawInicio) * t;
        _zoom = zoomInicio + (1.0 - zoomInicio) * t;
      });
    });
    ctrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => _detenerAuto(),
        onHorizontalDragUpdate: (d) =>
            setState(() => _yaw += d.primaryDelta! * 0.012),
        onScaleStart: (_) {
          _detenerAuto();
          _zoomInicioGesto = _zoom;
        },
        onScaleUpdate: (d) =>
            setState(() => _zoom = (_zoomInicioGesto * d.scale).clamp(0.6, 2.2)),
        onDoubleTap: _resetear,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_introCtrl, _autoCtrl]),
            builder: (_, __) {
              final introVal = Curves.easeOutCubic.transform(_introCtrl.value);
              return CustomPaint(
                painter: _Diseno3DPainter(
                  malla: _malla,
                  acento: widget.acento,
                  guia: widget.guia,
                  fondo: widget.fondo,
                  calorDias: widget.calorDias,
                  yaw: _yaw + _autoCtrl.value * 2 * math.pi,
                  pitch: _pitch,
                  zoom: _zoom * (0.72 + 0.28 * introVal),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════ Cámara / proyección ═══════════════════════════

class _Camara {
  final double yaw, pitch, zoom;
  final Vec3 centro;
  final double radio;
  final Size size;
  late final double _escala;
  late final double _distCam;

  _Camara({
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.centro,
    required this.radio,
    required this.size,
  }) {
    _escala = size.shortestSide * 0.40 * zoom / radio;
    _distCam = radio * 3.4 + 40;
  }

  ({Offset punto, double profundidad, Vec3 vista}) proyectar(Vec3 v) {
    var p = Vec3(v.x - centro.x, v.y - centro.y, v.z - centro.z);
    p = _rotarY(p, yaw);
    p = _rotarX(p, pitch);
    final f = _distCam / (_distCam + p.z);
    final ox = size.width / 2 + p.x * f * _escala;
    final oy = size.height / 2 - p.y * f * _escala;
    return (punto: Offset(ox, oy), profundidad: p.z, vista: p);
  }
}

class _ItemDibujo {
  final double profundidad; // mayor = más lejos de la cámara
  final void Function(Canvas canvas) dibujar;
  _ItemDibujo(this.profundidad, this.dibujar);
}

// "Sol" fijo arriba-frente-izquierda, ya aprox. normalizado.
const Vec3 _luz = Vec3(-0.45, 0.78, -0.44);

class _Diseno3DPainter extends CustomPainter {
  final Malla3D malla;
  final Color acento, guia, fondo;
  final List<double> calorDias;
  final double yaw, pitch, zoom;

  _Diseno3DPainter({
    required this.malla,
    required this.acento,
    required this.guia,
    required this.fondo,
    required this.calorDias,
    required this.yaw,
    required this.pitch,
    required this.zoom,
  });

  bool get _esOscuro => fondo.computeLuminance() < .3;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final cam = _Camara(
        yaw: yaw,
        pitch: pitch,
        zoom: zoom,
        centro: malla.centro,
        radio: malla.radio,
        size: size);

    _fondo2D(canvas, rect);
    _dibujarGrilla(canvas, cam);
    _sombraContacto(canvas, cam);

    final items = <_ItemDibujo>[];
    for (final c in malla.caras) {
      _agregarCara(items, cam, c);
    }
    for (final a in malla.aristas) {
      _agregarArista(items, cam, a);
    }
    _agregarManchas(items, cam, size);
    items.sort((a, b) => b.profundidad.compareTo(a.profundidad));
    for (final it in items) {
      it.dibujar(canvas);
    }

    _vineta(canvas, rect);
  }

  void _fondo2D(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = fondo);
    canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(radius: 1.0, colors: [
            _aclarar(fondo, _esOscuro ? .04 : .02),
            fondo.withValues(alpha: 0),
          ]).createShader(rect));
  }

  void _dibujarGrilla(Canvas canvas, _Camara cam) {
    final menor = Paint()
      ..color = guia.withValues(alpha: .10)
      ..strokeWidth = 0.8;
    final mayor = Paint()
      ..color = guia.withValues(alpha: .22)
      ..strokeWidth = 1.1;
    for (var x = -40.0; x <= 140; x += 10) {
      final a = cam.proyectar(Vec3(x, 0, -40)).punto;
      final b = cam.proyectar(Vec3(x, 0, 102)).punto;
      canvas.drawLine(a, b, x % 50 == 0 ? mayor : menor);
    }
    for (var z = -40.0; z <= 102; z += 10) {
      final a = cam.proyectar(Vec3(-40, 0, z)).punto;
      final b = cam.proyectar(Vec3(140, 0, z)).punto;
      canvas.drawLine(a, b, z % 50 == 0 ? mayor : menor);
    }
  }

  void _sombraContacto(Canvas canvas, _Camara cam) {
    final r = malla.radio;
    final c = malla.centro;
    final p0 = cam.proyectar(Vec3(c.x - r, 0.02, c.z - r * .6)).punto;
    final p1 = cam.proyectar(Vec3(c.x + r, 0.02, c.z + r * .6)).punto;
    canvas.drawOval(
        Rect.fromPoints(p0, p1),
        Paint()
          ..color = Colors.black.withValues(alpha: _esOscuro ? .40 : .16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
  }

  void _agregarCara(List<_ItemDibujo> items, _Camara cam, Cara3D c) {
    final proyectados = <Offset>[];
    var sumZ = 0.0;
    for (final v in c.vertices) {
      final r = cam.proyectar(v);
      proyectados.add(r.punto);
      sumZ += r.profundidad;
    }
    final profundidad = sumZ / c.vertices.length;

    // Normal en espacio de MUNDO (vértices originales, sin rotar): así el
    // "sol" queda fijo respecto al modelo y no gira con la cámara. Se usa
    // valor absoluto para no depender del orden de vértices con que se
    // construyó cada cara a mano.
    var normal = const Vec3(0, 1, 0);
    if (c.vertices.length >= 3) {
      normal = (c.vertices[1] - c.vertices[0])
          .cross(c.vertices[2] - c.vertices[0])
          .normalizado;
    }
    var nDotL = normal.dot(_luz).abs().clamp(0.0, 1.0);
    if (c.emisivo > 0) nDotL = math.max(nDotL, 0.55 * c.emisivo + 0.35);
    final h = HSLColor.fromColor(c.color);
    final color = h
        .withLightness((h.lightness * (0.55 + 0.45 * nDotL)).clamp(0.06, 0.97))
        .toColor();

    items.add(_ItemDibujo(profundidad, (canvas) {
      final path = Path()..addPolygon(proyectados, true);
      canvas.drawPath(path, Paint()..color = color);
      if (c.emisivo > 0) {
        canvas.drawPath(
            path,
            Paint()
              ..color = acento.withValues(alpha: .30 * c.emisivo)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = Colors.black.withValues(alpha: .16)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .6);
    }));
  }

  void _agregarArista(List<_ItemDibujo> items, _Camara cam, Arista3D a) {
    final proyectados = <Offset>[];
    var sumZ = 0.0;
    for (final v in a.puntos) {
      final r = cam.proyectar(v);
      proyectados.add(r.punto);
      sumZ += r.profundidad;
    }
    final profundidad = sumZ / a.puntos.length;
    items.add(_ItemDibujo(profundidad, (canvas) {
      final path = Path()..addPolygon(proyectados, false);
      if (a.glow > 0) {
        canvas.drawPath(
            path,
            Paint()
              ..color = a.color.withValues(alpha: .45 * a.glow)
              ..style = PaintingStyle.stroke
              ..strokeWidth = a.grosor * 3.2
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = a.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = a.grosor
            ..strokeCap = StrokeCap.round);
    }));
  }

  /// Manchas de calor como "billboards": posición 3D fija (misma fórmula
  /// determinística de siempre), proyectada cada frame — así se ocluyen
  /// correctamente detrás del modelo al rotar.
  void _agregarManchas(List<_ItemDibujo> items, _Camara cam, Size size) {
    for (var i = 0; i < calorDias.length; i++) {
      final w = calorDias[i];
      if (w <= 0) continue;
      final ang = i * 2.39996;
      final rad = 0.16 + 0.22 * ((i * 37) % 10) / 10;
      final x = malla.centro.x + math.cos(ang) * malla.extentX * (0.35 + rad * .55);
      final z = malla.centro.z + math.sin(ang) * malla.extentZ * (0.35 + rad * .55);
      final refAltura = math.max(malla.alturaTope, 8.0);
      final y = malla.alturaTope + refAltura * (0.15 + 0.12 * rad) + 1.5;
      final r = cam.proyectar(Vec3(x, y, z));
      final color = colorTermico(w);
      items.add(_ItemDibujo(r.profundidad, (canvas) {
        final c = r.punto;
        final radioHalo = size.shortestSide * (0.09 + 0.11 * w);
        canvas.drawCircle(
            c,
            radioHalo,
            Paint()
              ..shader = RadialGradient(colors: [
                color.withValues(alpha: .10 + .12 * w),
                color.withValues(alpha: 0),
              ]).createShader(Rect.fromCircle(center: c, radius: radioHalo))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
        final radio = size.shortestSide * (0.09 + 0.12 * w);
        final rect = Rect.fromCircle(center: c, radius: radio);
        canvas.drawCircle(
            c,
            radio,
            Paint()
              ..shader = RadialGradient(colors: [
                Colors.white.withValues(alpha: .16 + .30 * w),
                color.withValues(alpha: .24 + .30 * w),
                color.withValues(alpha: .08 + .14 * w),
                color.withValues(alpha: 0),
              ], stops: const [
                0,
                .30,
                .60,
                1
              ]).createShader(rect)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
      }));
    }
  }

  void _vineta(Canvas canvas, Rect rect) {
    canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(radius: 1.15, colors: [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: _esOscuro ? .32 : .08),
          ], stops: const [
            .62,
            1
          ]).createShader(rect));
  }

  @override
  bool shouldRepaint(covariant _Diseno3DPainter old) =>
      old.yaw != yaw ||
      old.pitch != pitch ||
      old.zoom != zoom ||
      old.malla != malla ||
      old.calorDias != calorDias ||
      old.acento != acento ||
      old.guia != guia ||
      old.fondo != fondo;
}
