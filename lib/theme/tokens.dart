import 'package:flutter/material.dart';

/// Escala de espaciado base 4.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Escala de radios semánticos.
class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24; // tarjetas "Bento" 2026
  static const double pill = 999;
}

/// Sombras semánticas "3D 2026": DOS capas (contacto nítido + ambiente suave)
/// que dan profundidad real. En dark mode una sombra negra corta separa la
/// tarjeta (#151517) del fondo (#0A0A0A).
class AppShadows {
  static List<BoxShadow> sm(Brightness b) => b == Brightness.light
      ? [
          BoxShadow(
              color: Colors.black.withValues(alpha: .05),
              blurRadius: 3,
              offset: const Offset(0, 1)),
          BoxShadow(
              color: Colors.black.withValues(alpha: .05),
              blurRadius: 12,
              offset: const Offset(0, 6)),
        ]
      : [
          BoxShadow(
              color: Colors.black.withValues(alpha: .45),
              blurRadius: 10,
              offset: const Offset(0, 5)),
        ];

  static List<BoxShadow> md(Brightness b) => b == Brightness.light
      ? [
          BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 4,
              offset: const Offset(0, 2)),
          BoxShadow(
              color: Colors.black.withValues(alpha: .09),
              blurRadius: 22,
              offset: const Offset(0, 10)),
        ]
      : [
          BoxShadow(
              color: Colors.black.withValues(alpha: .55),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ];

  /// Elevación con "glow" del color dado (botones/headers protagonistas).
  static List<BoxShadow> glow(Brightness b, Color c) => [
        ...md(b),
        BoxShadow(
            color: c.withValues(alpha: b == Brightness.light ? .18 : .30),
            blurRadius: 24,
            offset: const Offset(0, 8)),
      ];
}

/// Constantes de animación / transición.
class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);
}
