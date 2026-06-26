import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../models/models.dart';
import '../../core/auth_service.dart';
import '../../core/asistencia_service.dart';
import '../../data/obras_repository.dart';
import '../../data/asignaciones_repository.dart';
import '../../data/personas_repository.dart';
import '../../data/tareas_repository.dart';
import '../shell_router.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Obra> _obras      = [];
  Map<int, int> _conteo  = {};
  int _personal          = 0;
  int _presentesHoy      = 0;
  bool _cargando         = true;

  /// Hay obras pero no se leyó personal/asignaciones/asistencias: probable
  /// bloqueo por permisos (RLS) en la base de datos.
  bool get _sospechaSinPermisos =>
      _obras.isNotEmpty &&
      _personal == 0 &&
      _presentesHoy == 0 &&
      _conteo.values.fold<int>(0, (a, b) => a + b) == 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final obras    = await cargarObras();
    final personal = await todoElPersonal();
    final conteo   = await conteoAsignadosPorObra();
    final asist    = await asistenciasHoyTodas();
    final presentes = asist.map((r) => r['perfil_id']).toSet().length;
    if (!mounted) return;
    setState(() {
      _obras        = obras;
      _conteo       = conteo;
      _personal     = personal.length;
      _presentesHoy = presentes;
      _cargando     = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t   = context.tokens;
    final u   = AuthService.instance.session;
    final subtitulo = u == null
        ? 'Gerencia'
        : '${u.nombre} · ${u.rolNombre}';
    final tareas  = todasLasTareas();
    final abiertas = tareas.where((t) => t.estado != 'completada').length;

    return Column(children: [
      PanelHeader(
          title:    'Panel Gerencia',
          subtitle: subtitulo,
          color:    AppColors.roleAdmin,
          icon:     Icons.grid_view_outlined,
          onLogout: () => cerrarSesionYSalir(context)),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // ── Grid 2×2 de KPIs ─────────────────────────────────────────
              if (_cargando)
                const SkeletonList(count: 2)
              else ...[
                Row(children: [
                  Expanded(
                    child: StatTile(
                      label: 'Obras activas',
                      value: '${_obras.length}',
                      accentColor: AppColors.roleAdmin,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: StatTile(
                      label: 'Empleados',
                      value: '$_personal',
                      accentColor: AppColors.roleEmpleado,
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  Expanded(
                    child: StatTile(
                      label: 'Tareas abiertas',
                      value: '$abiertas',
                      accentColor: t.warning,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: StatTile(
                      label: 'Presentes hoy',
                      value: '$_presentesHoy',
                      accentColor: t.success,
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.sm),
                if (_sospechaSinPermisos) _avisoSinPermisos(t),
              ],

              // ── Lista de obras ────────────────────────────────────────────
              AppCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CardTitle('Obras'),
                      if (_obras.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.xl),
                          child: EmptyState(
                            icon: Icons.business_outlined,
                            title: 'Sin obras activas',
                            description:
                                'Las obras aparecerán aquí cuando estén registradas.',
                          ),
                        )
                      else
                        for (final o in _obras)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm - 1),
                            child: Row(children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 18,
                                  color: AppColors.roleAdmin),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(o.nombre,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: t.textPrimary)),
                              ),
                              AppBadge('${_conteo[o.id] ?? 0} trab.',
                                  badgeTone: BadgeTone.info),
                            ]),
                          ),
                    ]),
              ),

              // ── Tareas recientes ──────────────────────────────────────────
              AppCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CardTitle('Tareas recientes'),
                      if (tareas.isEmpty)
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          child: EmptyState(
                            icon: Icons.checklist_outlined,
                            title: 'Sin tareas delegadas',
                            description:
                                'Aquí verás las tareas que asignes al equipo.',
                          ),
                        )
                      else
                        for (final tarea in tareas.take(4))
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm - 2),
                            child: Row(children: [
                              Expanded(
                                child: Text(
                                  '${tarea.titulo} → ${tarea.destinoTexto}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: t.textPrimary),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm - 2),
                              AppBadge(
                                  estadoTareaLabel(tarea.estado),
                                  tone: estadoTareaTone(tarea.estado)),
                            ]),
                          ),
                    ]),
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _avisoSinPermisos(AppTokens t) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: t.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: t.warning.withValues(alpha: .3), width: 0.5),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, size: 18, color: t.warning),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Hay obras pero no se leyó personal ni asistencias. '
            'Revisa los permisos (RLS) de la base de datos para gerencia.',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: t.warning),
          ),
        ),
      ]),
    );
  }
}
