import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';
import 'tokens.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  AppTokens — ThemeExtension con todos los colores semánticos de la app.
//  Acceso: context.tokens.surface, context.tokens.brand, etc.
// ══════════════════════════════════════════════════════════════════════════════

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  // Superficies
  final Color appBg;
  final Color surface;
  final Color surfaceAlt;

  // Textos
  final Color textPrimary;
  final Color textSecondary;

  // Bordes / separadores
  final Color border;
  final Color divider;

  // Inputs
  final Color inputFill;
  final Color inputBorder;

  // Overlay (modal scrims, etc.)
  final Color overlay;

  // Marca
  final Color brand;
  final Color brandSoft;
  final Color onBrand;

  // Semánticos
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;

  const AppTokens({
    required this.appBg,
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.divider,
    required this.inputFill,
    required this.inputBorder,
    required this.overlay,
    required this.brand,
    required this.brandSoft,
    required this.onBrand,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
  });

  static const light = AppTokens(
    appBg:        Color(0xFFFAFAFA),
    surface:      Color(0xFFFFFFFF),
    surfaceAlt:   Color(0xFFF5F5F7),
    textPrimary:  Color(0xFF1A1A2E),
    textSecondary: Color(0xFF636366), // WCAG AA ≥4.5:1 sobre #FFFFFF
    border:       Color(0xFFE5E5EA),
    divider:      Color(0xFFEEEEF2),
    inputFill:    Color(0xFFF5F5F7),
    inputBorder:  Color(0xFFE5E5EA),
    overlay:      Color(0x52000000),
    brand:        AppColors.brand,
    brandSoft:    AppColors.brand50,
    onBrand:      Color(0xFFFFFFFF),
    success:      AppColors.success,
    successSoft:  Color(0xFFE8F8EF),
    warning:      AppColors.warning,
    warningSoft:  Color(0xFFFFF3E0),
    danger:       AppColors.danger,
    dangerSoft:   Color(0xFFFCE8E6),
  );

  static const dark = AppTokens(
    appBg:        Color(0xFF0F0F14),
    surface:      Color(0xFF1A1A24),
    surfaceAlt:   Color(0xFF232330),
    textPrimary:  Color(0xFFF5F5F5),
    textSecondary: Color(0xFF9E9E9E),
    border:       Color(0xFF2E2E3C),
    divider:      Color(0xFF252532),
    inputFill:    Color(0xFF2C2C3E),
    inputBorder:  Color(0xFF3A3A50),
    overlay:      Color(0x73000000),
    brand:        AppColors.brand400,
    brandSoft:    Color(0xFF2E1509),
    onBrand:      Color(0xFFFFFFFF),
    success:      Color(0xFF4CD964),
    successSoft:  Color(0xFF0D2B14),
    warning:      Color(0xFFFFAD33),
    warningSoft:  Color(0xFF2B1E00),
    danger:       Color(0xFFFF6B63),
    dangerSoft:   Color(0xFF2B0E0D),
  );

  @override
  AppTokens copyWith({
    Color? appBg,
    Color? surface,
    Color? surfaceAlt,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? divider,
    Color? inputFill,
    Color? inputBorder,
    Color? overlay,
    Color? brand,
    Color? brandSoft,
    Color? onBrand,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
  }) =>
      AppTokens(
        appBg:         appBg         ?? this.appBg,
        surface:       surface       ?? this.surface,
        surfaceAlt:    surfaceAlt    ?? this.surfaceAlt,
        textPrimary:   textPrimary   ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        border:        border        ?? this.border,
        divider:       divider       ?? this.divider,
        inputFill:     inputFill     ?? this.inputFill,
        inputBorder:   inputBorder   ?? this.inputBorder,
        overlay:       overlay       ?? this.overlay,
        brand:         brand         ?? this.brand,
        brandSoft:     brandSoft     ?? this.brandSoft,
        onBrand:       onBrand       ?? this.onBrand,
        success:       success       ?? this.success,
        successSoft:   successSoft   ?? this.successSoft,
        warning:       warning       ?? this.warning,
        warningSoft:   warningSoft   ?? this.warningSoft,
        danger:        danger        ?? this.danger,
        dangerSoft:    dangerSoft    ?? this.dangerSoft,
      );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      appBg:         Color.lerp(appBg,         other.appBg,         t)!,
      surface:       Color.lerp(surface,       other.surface,       t)!,
      surfaceAlt:    Color.lerp(surfaceAlt,    other.surfaceAlt,    t)!,
      textPrimary:   Color.lerp(textPrimary,   other.textPrimary,   t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border:        Color.lerp(border,        other.border,        t)!,
      divider:       Color.lerp(divider,       other.divider,       t)!,
      inputFill:     Color.lerp(inputFill,     other.inputFill,     t)!,
      inputBorder:   Color.lerp(inputBorder,   other.inputBorder,   t)!,
      overlay:       Color.lerp(overlay,       other.overlay,       t)!,
      brand:         Color.lerp(brand,         other.brand,         t)!,
      brandSoft:     Color.lerp(brandSoft,     other.brandSoft,     t)!,
      onBrand:       Color.lerp(onBrand,       other.onBrand,       t)!,
      success:       Color.lerp(success,       other.success,       t)!,
      successSoft:   Color.lerp(successSoft,   other.successSoft,   t)!,
      warning:       Color.lerp(warning,       other.warning,       t)!,
      warningSoft:   Color.lerp(warningSoft,   other.warningSoft,   t)!,
      danger:        Color.lerp(danger,        other.danger,        t)!,
      dangerSoft:    Color.lerp(dangerSoft,    other.dangerSoft,    t)!,
    );
  }
}

/// Acceso corto a los tokens: `context.tokens.surface`.
extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}

// ══════════════════════════════════════════════════════════════════════════════
//  AppTheme — ThemeData light / dark con todos los component themes.
// ══════════════════════════════════════════════════════════════════════════════

class AppTheme {
  /// Color seed único de la marca.
  static const brand = AppColors.brand;

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: brightness,
    ).copyWith(surface: t.surface);

    final poppinsBase = GoogleFonts.poppinsTextTheme()
        .apply(bodyColor: t.textPrimary, displayColor: t.textPrimary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: t.appBg,
      colorScheme: scheme,
      extensions: [t],
      textTheme: poppinsBase,

      // ── AppBar ──────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: t.surface,
        foregroundColor: t.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: brand.withValues(alpha: .05),
        titleTextStyle: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: t.textPrimary),
      ),

      // ── Cards ───────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: t.surface,
        elevation: brightness == Brightness.light ? 0 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: t.border, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Inputs ──────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.inputFill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        hintStyle: GoogleFonts.poppins(
            fontSize: 14,
            color: t.textSecondary.withValues(alpha: .7)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: t.inputBorder, width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: t.brand, width: 1.6)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: t.danger, width: 1)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: t.danger, width: 1.6)),
        disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(
                color: t.inputBorder.withValues(alpha: .5), width: 1)),
      ),

      // ── Buttons ─────────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: const Color(0xFFFFFFFF),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: const Color(0xFFFFFFFF),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brand,
          side: BorderSide(color: brand.withValues(alpha: .5), width: 1.2),
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand,
          textStyle: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm)),
        ),
      ),

      // ── Chips ───────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: t.surfaceAlt,
        selectedColor: brand.withValues(alpha: .12),
        labelStyle: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill)),
        side: BorderSide(color: t.border, width: 0.5),
      ),

      // ── NavigationBar ───────────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        indicatorColor: brand.withValues(alpha: .12),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: brand, size: 22);
          }
          return IconThemeData(color: t.textSecondary, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: brand);
          }
          return GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: t.textSecondary);
        }),
        elevation: 0,
        surfaceTintColor: brand.withValues(alpha: .04),
      ),

      // ── BottomSheet ─────────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl)),
        ),
        elevation: 0,
        surfaceTintColor: brand.withValues(alpha: .04),
      ),

      // ── Divider ─────────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: t.divider,
        thickness: 0.5,
        space: 0,
      ),

      // ── Transiciones de página ──────────────────────────────────────────────
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get light => _build(AppTokens.light, Brightness.light);
  static ThemeData get dark  => _build(AppTokens.dark,  Brightness.dark);
}
