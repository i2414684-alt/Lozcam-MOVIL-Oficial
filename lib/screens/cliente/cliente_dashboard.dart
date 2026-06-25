import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../models/models.dart';
import '../../core/auth_service.dart';
import '../../data/enums.dart';
import '../../data/obras_repository.dart';
import '../shell_router.dart';

class ClienteDashboard extends StatefulWidget {
  const ClienteDashboard({super.key});
  @override
  State<ClienteDashboard> createState() => _ClienteDashboardState();
}

class _ClienteDashboardState extends State<ClienteDashboard> {
  Obra? _obra;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final o = await obraDelCliente();
    if (!mounted) return;
    setState(() {
      _obra = o;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final u = AuthService.instance.session;
    final obra = _obra;

    return Column(children: [
      PanelHeader(
          title: u?.nombre ?? 'Cliente',
          subtitle: 'Mi proyecto',
          color: AppColors.cliente,
          icon: Icons.business_outlined,
          onLogout: () => cerrarSesionYSalir(context)),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.all(12),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (_cargando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (obra == null)
                AppCard(
                  child: IconRow(
                      icon: Icons.business_outlined,
                      iconColor: context.tokens.textSecondary,
                      title: 'Aún no hay un proyecto registrado',
                      subtitle: 'Aparecerá cuando el sistema lo asigne.'),
                )
              else ...[
                AppCard(
                  color: AppColors.greenBg,
                  borderColor: const Color(0xFF9FE1CB),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CardTitle('Mi proyecto'),
                        Text(obra.nombre,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.verified_outlined,
                              size: 15, color: AppColors.cliente),
                          const SizedBox(width: 4),
                          Text(labelEstadoObra(obra.estado),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.cliente)),
                        ]),
                      ]),
                ),
                AppCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CardTitle('Ubicación'),
                        IconRow(
                            icon: Icons.place_outlined,
                            iconColor: AppColors.primary,
                            title: obra.direccion.isNotEmpty
                                ? obra.direccion
                                : 'Dirección no registrada',
                            subtitle:
                                '${obra.lat.toStringAsFixed(5)}, ${obra.lng.toStringAsFixed(5)}'),
                      ]),
                ),
              ],
            ],
          ),
        ),
      ),
    ]);
  }
}
