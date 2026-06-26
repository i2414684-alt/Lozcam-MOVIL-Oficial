import 'package:flutter/material.dart';
import 'colors.dart';
import '../core/auth_service.dart';

/// Devuelve el color seed del rol activo.
/// Úsalo para crear un sub-árbol con identidad de rol:
/// ```dart
/// Theme(
///   data: Theme.of(context).copyWith(
///     colorScheme: ColorScheme.fromSeed(seedColor: roleSeed(AppArea.operativo)),
///   ),
///   child: ...,
/// )
/// ```
Color roleSeed(AppArea area) {
  return switch (area) {
    AppArea.gerencia  => AppColors.roleAdmin,
    AppArea.operativo => AppColors.roleEmpleado,
    AppArea.cliente   => AppColors.roleCliente,
  };
}

/// Label legible para mostrar en UI.
String roleLabel(AppArea area) {
  return switch (area) {
    AppArea.gerencia  => 'Gerencia',
    AppArea.operativo => 'Trabajador',
    AppArea.cliente   => 'Cliente',
  };
}
