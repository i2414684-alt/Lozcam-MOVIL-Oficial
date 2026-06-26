import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../core/auth_service.dart';
import '../../widgets/common.dart';
import '../tutorial_overlay.dart';
import 'chat_gerente.dart';
import 'admin_dashboard.dart';
import 'admin_obras.dart';
import 'admin_areas.dart';
import 'admin_empleados.dart';
import 'admin_tareas.dart';
import 'admin_asistencias.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _i = 0;

  static const _items = [
    AppBottomNavItem(
        icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view,
        label: 'Inicio'),
    AppBottomNavItem(
        icon: Icons.business_outlined,
        activeIcon: Icons.business,
        label: 'Obras'),
    AppBottomNavItem(
        icon: Icons.add_location_alt_outlined,
        activeIcon: Icons.add_location_alt,
        label: 'Áreas'),
    AppBottomNavItem(
        icon: Icons.account_tree_outlined,
        activeIcon: Icons.account_tree,
        label: 'Equipo'),
    AppBottomNavItem(
        icon: Icons.checklist_outlined,
        activeIcon: Icons.checklist,
        label: 'Tareas'),
    AppBottomNavItem(
        icon: Icons.insights_outlined,
        activeIcon: Icons.insights,
        label: 'Monitor'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) mostrarTutorialSiPrimeraVez(context, AppArea.gerencia);
    });
  }

  final _pages = const [
    AdminDashboard(),
    AdminObras(),
    AdminAreas(),
    AdminEmpleados(),
    AdminTareas(),
    AdminAsistencias(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _i, children: _pages),
      floatingActionButton: Tooltip(
        message: 'Asistente IA',
        child: FloatingActionButton(
          backgroundColor: AppColors.brand,
          onPressed: () => mostrarChatGerente(context),
          child: const Text('🤖', style: TextStyle(fontSize: 22)),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _i,
        onTap: (v) => setState(() => _i = v),
        items: _items,
        roleColor: AppColors.roleAdmin,
      ),
    );
  }
}
