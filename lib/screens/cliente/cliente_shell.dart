import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../core/auth_service.dart';
import '../tutorial_overlay.dart';
import 'cliente_dashboard.dart';
import 'cliente_informes.dart';
import 'cliente_mapa.dart';
import 'cliente_contacto.dart';

class ClienteShell extends StatefulWidget {
  const ClienteShell({super.key});
  @override
  State<ClienteShell> createState() => _ClienteShellState();
}

class _ClienteShellState extends State<ClienteShell> {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) mostrarTutorialSiPrimeraVez(context, AppArea.cliente);
    });
  }
  final _pages = const [
    ClienteDashboard(),
    ClienteInformes(),
    ClienteMapa(),
    ClienteContacto(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _i, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _i,
        onTap: (v) => setState(() => _i = v),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.cliente,
        unselectedItemColor: AppColors.textMuted,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.description_outlined), label: 'Informes'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on_outlined), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.call_outlined), label: 'Contacto'),
        ],
      ),
    );
  }
}
