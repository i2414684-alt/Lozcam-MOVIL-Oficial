import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ============================================================================
///  TEMA GLOBAL — Modo Claro / Modo Oscuro (Lozcam)
///
///  `AppTokens` es un ThemeExtension con los colores SEMÁNTICOS de la app
///  (fondo, superficie, textos, bordes, inputs) en sus dos variantes.
///  Se invocan en cualquier widget con `context.tokens.surface`, etc., y
///  cambian solos al alternar el tema. El naranja corporativo va en el
///  ColorScheme (`Theme.of(context).colorScheme.primary`).
/// ============================================================================

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  final Color appBg; // fondo de la app
  final Color surface; // tarjetas / contenedores
  final Color textPrimary; // texto principal
  final Color textSecondary; // texto secundario / labels
  final Color border; // bordes de tarjetas
  final Color inputFill; // fondo de inputs
  final Color inputBorder; // borde de inputs

  const AppTokens({
    required this.appBg,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.inputFill,
    required this.inputBorder,
  });

  static const light = AppTokens(
    appBg: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF757575),
    border: Color(0xFFE5E5EA),
    inputFill: Color(0xFFF5F5F7),
    inputBorder: Color(0xFFE5E5EA),
  );

  static const dark = AppTokens(
    appBg: Color(0xFF121212),
    surface: Color(0xFF1E1E2A),
    textPrimary: Color(0xFFF5F5F5),
    textSecondary: Color(0xFF9E9E9E),
    border: Color(0xFF2E2E3C),
    inputFill: Color(0xFF2C2C3E),
    inputBorder: Color(0xFF3A3A50),
  );

  @override
  AppTokens copyWith({
    Color? appBg,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? inputFill,
    Color? inputBorder,
  }) =>
      AppTokens(
        appBg: appBg ?? this.appBg,
        surface: surface ?? this.surface,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        border: border ?? this.border,
        inputFill: inputFill ?? this.inputFill,
        inputBorder: inputBorder ?? this.inputBorder,
      );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      appBg: Color.lerp(appBg, other.appBg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
    );
  }
}

/// Acceso corto a los tokens: `context.tokens.surface`.
extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}

/// Construye los ThemeData de la app (claro y oscuro).
class AppTheme {
  static const brand = Color(0xFFD74315); // naranja corporativo

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: t.appBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brand,
        brightness: brightness,
      ).copyWith(surface: t.surface),
      extensions: [t],
    );
    return base.copyWith(
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme)
          .apply(bodyColor: t.textPrimary, displayColor: t.textPrimary),
    );
  }

  static ThemeData get light => _build(AppTokens.light, Brightness.light);
  static ThemeData get dark => _build(AppTokens.dark, Brightness.dark);
}
