import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../core/auth_service.dart';
import '../../widgets/common.dart';
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

  static const _items = [
    AppBottomNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Inicio'),
    AppBottomNavItem(
        icon: Icons.description_outlined,
        activeIcon: Icons.description,
        label: 'Informes'),
    AppBottomNavItem(
        icon: Icons.location_on_outlined,
        activeIcon: Icons.location_on,
        label: 'Mapa'),
    AppBottomNavItem(
        icon: Icons.call_outlined,
        activeIcon: Icons.call,
        label: 'Contacto'),
  ];

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
      bottomNavigationBar: AppBottomNav(
        currentIndex: _i,
        onTap: (v) => setState(() => _i = v),
        items: _items,
        roleColor: AppColors.roleCliente,
      ),
    );
  }
}
