import 'package:flutter/material.dart';

/// Paleta central de Lozcam.
class AppColors {
  // ── Marca única ────────────────────────────────────────────────────────────
  static const brand = Color(0xFFD74315); // naranja Lozcam — ÚNICA fuente de verdad

  /// Alias legacy — usar [brand].
  @Deprecated('Usa AppColors.brand')
  static const primary = brand;

  /// Alias legacy — usar [brand].
  @Deprecated('Usa AppColors.brand')
  static const admin = brand;

  // ── Tints de marca (HSL ~15° / sat ~75%) ──────────────────────────────────
  static const brand50  = Color(0xFFFEF2EE);
  static const brand100 = Color(0xFFFDDAD0);
  static const brand200 = Color(0xFFFAB49F);
  static const brand300 = Color(0xFFF58A6B);
  static const brand400 = Color(0xFFEF6038);
  static const brand500 = Color(0xFFD74315); // = brand
  static const brand600 = Color(0xFFB53510);
  static const brand700 = Color(0xFF8F290C);
  static const brand800 = Color(0xFF6A1D08);
  static const brand900 = Color(0xFF451205);

  // ── Colores por rol ────────────────────────────────────────────────────────
  static const roleAdmin    = brand;
  static const roleEmpleado = Color(0xFF1A56B0); // azul
  static const roleCliente  = Color(0xFF1D6E48); // verde

  /// Alias legacy — usar [roleEmpleado].
  @Deprecated('Usa AppColors.roleEmpleado')
  static const empleado = roleEmpleado;

  /// Alias legacy — usar [roleCliente].
  @Deprecated('Usa AppColors.roleCliente')
  static const cliente = roleCliente;

  // ── Semánticos globales ────────────────────────────────────────────────────
  static const success = Color(0xFF34C759);
  static const warning = Color(0xFFFF9500);
  static const danger  = Color(0xFFFF3B30);

  // ── Superficie / texto (solo para compatibilidad — usar AppTokens en pantallas) ─
  static const screen = Color(0xFFF5F5F7);
  static const card   = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5E5EA);
  static const line   = Color(0xFFF0F0F5);

  static const textDark = Color(0xFF1A1A2E);
  static const textMuted = Color(0xFF8E8E93);
  static const textSoft  = Color(0xFF636366);

  // ── Pares tono (deprecated — usar BadgeTone / AppTokens en componentes) ───
  @Deprecated('Usa tokens semánticos')
  static const orangeBg   = Color(0xFFFFF3E0);
  @Deprecated('Usa tokens semánticos')
  static const orangeText = Color(0xFFA05C00);
  @Deprecated('Usa tokens semánticos')
  static const blueBg     = Color(0xFFE8F0FE);
  @Deprecated('Usa tokens semánticos')
  static const blueText   = Color(0xFF1A56B0);
  @Deprecated('Usa tokens semánticos')
  static const greenBg    = Color(0xFFE8F8EF);
  @Deprecated('Usa tokens semánticos')
  static const greenText  = Color(0xFF1D6E48);
  @Deprecated('Usa tokens semánticos')
  static const purpleBg   = Color(0xFFF0EBFE);
  @Deprecated('Usa tokens semánticos')
  static const purpleText = Color(0xFF5B2D9E);
  @Deprecated('Usa tokens semánticos')
  static const pinkBg     = Color(0xFFFCE4EC);
  @Deprecated('Usa tokens semánticos')
  static const pinkText   = Color(0xFFAD1457);
  @Deprecated('Usa tokens semánticos')
  static const redBg      = Color(0xFFFCE8E6);
  @Deprecated('Usa tokens semánticos')
  static const redText    = Color(0xFFC5221F);
  @Deprecated('Usa tokens semánticos')
  static const grayBg     = Color(0xFFF0F0F5);
  @Deprecated('Usa tokens semánticos')
  static const grayText   = Color(0xFF636366);
}

/// Devuelve el par (fondo, texto) según una clave de tono.
({Color bg, Color fg}) tonePair(String key) {
  switch (key) {
    case 'orange':
      // ignore: deprecated_member_use_from_same_package
      return (bg: AppColors.orangeBg, fg: AppColors.orangeText);
    case 'green':
      // ignore: deprecated_member_use_from_same_package
      return (bg: AppColors.greenBg, fg: AppColors.greenText);
    case 'purple':
      // ignore: deprecated_member_use_from_same_package
      return (bg: AppColors.purpleBg, fg: AppColors.purpleText);
    case 'pink':
      // ignore: deprecated_member_use_from_same_package
      return (bg: AppColors.pinkBg, fg: AppColors.pinkText);
    case 'red':
      // ignore: deprecated_member_use_from_same_package
      return (bg: AppColors.redBg, fg: AppColors.redText);
    case 'amber':
      // ignore: deprecated_member_use_from_same_package
      return (bg: AppColors.orangeBg, fg: AppColors.orangeText);
    case 'gray':
      // ignore: deprecated_member_use_from_same_package
      return (bg: AppColors.grayBg, fg: AppColors.grayText);
    case 'blue':
    default:
      // ignore: deprecated_member_use_from_same_package
      return (bg: AppColors.blueBg, fg: AppColors.blueText);
  }
}
