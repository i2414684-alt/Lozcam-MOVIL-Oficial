import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../core/auth_service.dart';
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _i,
        onTap: (v) => setState(() => _i = v),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.empleado,
        unselectedItemColor: AppColors.textMuted,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.checklist), label: 'Tareas'),
          BottomNavigationBarItem(icon: Icon(Icons.fingerprint), label: 'Marcar'),
          BottomNavigationBarItem(icon: Icon(Icons.description_outlined), label: 'Informe'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historial'),
        ],
      ),
    );
  }
}
