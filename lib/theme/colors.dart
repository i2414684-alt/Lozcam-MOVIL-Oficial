import 'package:flutter/material.dart';

/// Paleta central de Lozcam — replica el prototipo aprobado.
class AppColors {
  static const primary = Color(0xFFD4420A); // naranja Lozcam / admin
  static const admin = Color(0xFFD4420A);
  static const empleado = Color(0xFF1A56B0); // azul
  static const cliente = Color(0xFF1D6E48); // verde

  static const screen = Color(0xFFF5F5F7);
  static const card = Colors.white;
  static const border = Color(0xFFE5E5EA);
  static const line = Color(0xFFF0F0F5);

  static const textDark = Color(0xFF1A1A2E);
  static const textMuted = Color(0xFF8E8E93);
  static const textSoft = Color(0xFF636366);

  static const success = Color(0xFF34C759);
  static const warning = Color(0xFFFF9500);
  static const danger = Color(0xFFFF3B30);

  // Pares suaves (fondo / texto) para badges y avatares
  static const orangeBg = Color(0xFFFFF3E0);
  static const orangeText = Color(0xFFA05C00);
  static const blueBg = Color(0xFFE8F0FE);
  static const blueText = Color(0xFF1A56B0);
  static const greenBg = Color(0xFFE8F8EF);
  static const greenText = Color(0xFF1D6E48);
  static const purpleBg = Color(0xFFF0EBFE);
  static const purpleText = Color(0xFF5B2D9E);
  static const pinkBg = Color(0xFFFCE4EC);
  static const pinkText = Color(0xFFAD1457);
  static const redBg = Color(0xFFFCE8E6);
  static const redText = Color(0xFFC5221F);
  static const grayBg = Color(0xFFF0F0F5);
  static const grayText = Color(0xFF636366);
}

/// Devuelve el par de colores (fondo, texto) según una clave.
({Color bg, Color fg}) tonePair(String key) {
  switch (key) {
    case 'orange':
      return (bg: AppColors.orangeBg, fg: AppColors.orangeText);
    case 'green':
      return (bg: AppColors.greenBg, fg: AppColors.greenText);
    case 'purple':
      return (bg: AppColors.purpleBg, fg: AppColors.purpleText);
    case 'pink':
      return (bg: AppColors.pinkBg, fg: AppColors.pinkText);
    case 'red':
      return (bg: AppColors.redBg, fg: AppColors.redText);
    case 'amber':
      return (bg: AppColors.orangeBg, fg: AppColors.orangeText);
    case 'gray':
      return (bg: AppColors.grayBg, fg: AppColors.grayText);
    case 'blue':
    default:
      return (bg: AppColors.blueBg, fg: AppColors.blueText);
  }
}
