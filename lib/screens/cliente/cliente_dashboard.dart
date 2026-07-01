import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/charts.dart';
import '../../models/models.dart';
import '../../core/auth_service.dart';
import '../../data/enums.dart';
import '../../data/obras_repository.dart';
import '../../data/avance_repository.dart';
import '../shell_router.dart';

class ClienteDashboard extends StatefulWidget {
  const ClienteDashboard({super.key});
  @override
  State<ClienteDashboard> createState() => _ClienteDashboardState();
}

class _ClienteDashboardState extends State<ClienteDashboard> {
  Obra? _obra;
  List<AvanceItem> _avances = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final o = await obraDelCliente();
    final av = o == null ? <AvanceItem>[] : await avancesDeObra(o.id);
    if (!mounted) return;
    setState(() {
      _obra     = o;
      _avances  = av;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t    = context.tokens;
    final u    = AuthService.instance.session;
    final obra = _obra;

    return Column(children: [
      PanelHeader(
          title:    u?.nombre ?? 'Cliente',
          subtitle: 'Mi proyecto',
          color:    AppColors.roleCliente,
          icon:     Icons.business_outlined,
          onLogout: () => cerrarSesionYSalir(context)),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (_cargando)
                const SkeletonList()
              else if (obra == null)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xxxl),
                  child: EmptyState(
                    icon: Icons.business_outlined,
                    title: 'Sin proyecto asignado',
                    description:
                        'Aparecerá aquí cuando el sistema lo registre.',
                  ),
                )
              else ...[
                // Hero: tarjeta del proyecto con visualización de progreso
                AppCard.tonal(
                  seed: AppColors.roleCliente,
                  child: Row(children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CardTitle('Mi proyecto'),
                            Text(obra.nombre,
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                    color: t.textPrimary)),
                            const SizedBox(height: AppSpacing.sm - 2),
                            Row(children: [
                              const Icon(Icons.verified_outlined,
                                  size: 15, color: AppColors.roleCliente),
                              const SizedBox(width: AppSpacing.xs),
                              Text(labelEstadoObra(obra.estado),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.roleCliente)),
                            ]),
                          ]),
                    ),
                    if (_avances.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.md),
                      _anilloProgreso(_avances.first.pct),
                    ],
                  ]),
                ),

                // Ubicación
                AppCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CardTitle('Ubicación'),
                        IconRow(
                            icon: Icons.place_outlined,
                            iconColor: AppColors.brand,
                            title: obra.direccion.isNotEmpty
                                ? obra.direccion
                                : 'Dirección no registrada',
                            subtitle:
                                '${obra.lat.toStringAsFixed(5)}, '
                                '${obra.lng.toStringAsFixed(5)}'),
                      ]),
                ),

                // Mapa placeholder
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: MapPlaceholder(
                    label: obra.nombre,
                    height: MediaQuery.of(context).size.height * 0.28,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ]);
  }

  /// Gauge radial con el último % reportado de la obra.
  Widget _anilloProgreso(int pct) {
    return GaugeCircular(
      value: pct / 100,
      centerLabel: '$pct%',
      subLabel: 'avance',
      size: 84,
      stroke: 9,
      color: AppColors.roleCliente,
    );
  }
}
