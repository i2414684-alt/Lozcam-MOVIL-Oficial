import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../core/auth_service.dart';
import '../../widgets/common.dart';
import '../tutorial_overlay.dart';
import 'empleado_dashboard.dart';
import 'empleado_tareas.dart';
import 'empleado_marcar.dart';
import 'empleado_informe.dart';
import 'empleado_inasistencias.dart';

class EmpleadoShell extends StatefulWidget {
  const EmpleadoShell({super.key});
  @override
  State<EmpleadoShell> createState() => _EmpleadoShellState();
}

class _EmpleadoShellState extends State<EmpleadoShell> {
  int _i = 0;

  static const _items = [
    AppBottomNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Inicio'),
    AppBottomNavItem(
        icon: Icons.checklist_outlined,
        activeIcon: Icons.checklist,
        label: 'Tareas'),
    AppBottomNavItem(
        icon: Icons.fingerprint,
        activeIcon: Icons.fingerprint,
        label: 'Marcar'),
    AppBottomNavItem(
        icon: Icons.description_outlined,
        activeIcon: Icons.description,
        label: 'Informe'),
    AppBottomNavItem(
        icon: Icons.history_outlined,
        activeIcon: Icons.history,
        label: 'Historial'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) mostrarTutorialSiPrimeraVez(context, AppArea.operativo);
    });
  }

  late final List<Widget> _pages = [
    EmpleadoDashboard(onMarcar: () => setState(() => _i = 2)),
    const EmpleadoTareas(),
    const EmpleadoMarcar(),
    const EmpleadoInforme(),
    const EmpleadoInasistencias(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _i, children: _pages),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _i,
        onTap: (v) => setState(() => _i = v),
        items: _items,
        roleColor: AppColors.roleEmpleado,
      ),
    );
  }
}
