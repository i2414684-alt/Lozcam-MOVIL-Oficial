import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

/// Generadores de estilos 2026: titulares en Lexend, cuerpo en Inter.
/// Reciben color explícito.
class AppTypography {
  static TextStyle display(Color color) => GoogleFonts.lexend(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: color);

  static TextStyle h1(Color color) => GoogleFonts.lexend(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: color);

  static TextStyle h2(Color color) => GoogleFonts.lexend(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: color);

  static TextStyle title(Color color) => GoogleFonts.lexend(
      fontSize: 16, fontWeight: FontWeight.w600, color: color);

  static TextStyle body(Color color) => GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: color);

  static TextStyle bodyStrong(Color color) => GoogleFonts.inter(
      fontSize: 14, fontWeight: FontWeight.w600, color: color);

  static TextStyle caption(Color color) => GoogleFonts.inter(
      fontSize: 12, fontWeight: FontWeight.w500, color: color);

  static TextStyle overline(Color color) => GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: color);
}

/// Acceso corto a estilos tipográficos desde el contexto:
/// `context.text.h1`, `context.text.body`, etc.
class AppTextStyles {
  final BuildContext _ctx;
  const AppTextStyles(this._ctx);

  Color get _primary => _ctx.tokens.textPrimary;
  Color get _secondary => _ctx.tokens.textSecondary;

  TextStyle get display => AppTypography.display(_primary);
  TextStyle get h1 => AppTypography.h1(_primary);
  TextStyle get h2 => AppTypography.h2(_primary);
  TextStyle get title => AppTypography.title(_primary);
  TextStyle get body => AppTypography.body(_primary);
  TextStyle get bodyStrong => AppTypography.bodyStrong(_primary);
  TextStyle get caption => AppTypography.caption(_secondary);
  TextStyle get overline => AppTypography.overline(_secondary);
}

extension AppTypographyX on BuildContext {
  AppTextStyles get text => AppTextStyles(this);
}
