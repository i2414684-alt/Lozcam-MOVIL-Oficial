import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/app_theme.dart';
import '../../core/auth_service.dart';
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.admin,
        tooltip: 'Asistente IA',
        onPressed: () => mostrarChatGerente(context),
        child: const Text('🤖', style: TextStyle(fontSize: 22)),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _i,
        onTap: (v) => setState(() => _i = v),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: context.tokens.textSecondary,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_outlined), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.business_outlined), label: 'Obras'),
          BottomNavigationBarItem(icon: Icon(Icons.add_location_alt_outlined), label: 'Áreas'),
          BottomNavigationBarItem(icon: Icon(Icons.account_tree_outlined), label: 'Equipo'),
          BottomNavigationBarItem(icon: Icon(Icons.checklist), label: 'Tareas'),
          BottomNavigationBarItem(icon: Icon(Icons.insights_outlined), label: 'Monitor'),
        ],
      ),
    );
  }
}
