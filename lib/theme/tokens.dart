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

/// Sombras semánticas. En dark mode devuelven lista vacía (usar borde + surfaceTint).
class AppShadows {
  static List<BoxShadow> sm(Brightness b) => b == Brightness.light
      ? [
          BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ]
      : const [];

  static List<BoxShadow> md(Brightness b) => b == Brightness.light
      ? [
          BoxShadow(
              color: Colors.black.withValues(alpha: .08),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ]
      : const [];
}

/// Constantes de animación / transición.
class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);
}
