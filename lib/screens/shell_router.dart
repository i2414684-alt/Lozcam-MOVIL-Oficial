import 'package:flutter/material.dart';
import '../core/auth_service.dart';
import 'admin/admin_shell.dart';
import 'empleado/empleado_shell.dart';
import 'cliente/cliente_shell.dart';
import 'login_screen.dart';

/// Devuelve el panel (shell) que corresponde al rol del usuario logueado.
Widget shellForSession(SessionUser u) {
  switch (u.area) {
    case AppArea.gerencia:
      return const AdminShell();
    case AppArea.cliente:
      return const ClienteShell();
    case AppArea.operativo:
      return const EmpleadoShell();
  }
}

/// Cierra la sesión y vuelve al login, limpiando toda la pila de navegación.
Future<void> cerrarSesionYSalir(BuildContext context) async {
  await AuthService.instance.cerrarSesion();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}
