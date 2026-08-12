import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/common.dart';
import '../../models/models.dart';
import '../../core/auth_service.dart';
import '../../data/fuente_datos.dart';
import '../../data/tareas_repository.dart';
import '../shell_router.dart';
import '../tutorial_overlay.dart';

/// Panel de inicio del trabajador.
///
/// Lee SIEMPRE de [obrasDelUsuario] y [asistenciaDelUsuario] — la misma fuente
/// que usan «Marcar» e «Informe». Antes esta pantalla leía la memoria interna
/// mientras las otras leían la nube, y el mismo trabajador veía «Sin área
/// asignada» en Inicio y su obra real en Marcar.
class EmpleadoDashboard extends StatefulWidget {
  /// Callback para saltar a la pestaña "Marcar" del shell.
  final VoidCallback? onMarcar;
  const EmpleadoDashboard({super.key, this.onMarcar});

  @override
  State<EmpleadoDashboard> createState() => _EmpleadoDashboardState();
}

class _EmpleadoDashboardState extends State<EmpleadoDashboard> {
  Obra? _obra;
  TotalesAsistencia _totales = const TotalesAsistencia(0, 0, 0);
  List<TareaAsignada> _tareas = const [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final u = AuthService.instance.session;
    // Las dos consultas en paralelo: en obra la señal es mala y encadenarlas
    // duplicaba la espera.
    final resultados = await Future.wait([
      obraPrincipalDelUsuario(),
      asistenciaDelUsuario(),
    ]);
    if (!mounted) return;
    setState(() {
      _obra = resultados[0] as Obra?;
      _totales = totalesDe(resultados[1] as List<Map<String, dynamic>>);
      _tareas = tareasParaPersona(u?.rol ?? '', u?.id ?? '');
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final u = AuthService.instance.session;
    final saludo = u == null ? 'Buen día' : 'Buen día, ${u.primerNombre}';
    final rol = u?.rolNombre ?? 'Empleado';
    final pendientes = _tareas.where((t) => t.estado != 'completada').toList();

    return Column(children: [
      PanelHeader(
          title: saludo,
          subtitle: rol,
          color: AppColors.roleEmpleado,
          icon: Icons.handyman_outlined,
          onGuia: () => mostrarTutorial(context, AppArea.operativo),
          onLogout: () => cerrarSesionYSalir(context)),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // ── Hero: obra asignada ─────────────────────────────────────────
              AppCard.tonal(
                seed: AppColors.roleEmpleado,
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.roleEmpleado.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.business_outlined,
                        color: AppColors.roleEmpleado, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Obra asignada',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.roleEmpleado)),
                          const SizedBox(height: 2),
                          Text(
                              _cargando
                                  ? 'Cargando…'
                                  : (_obra?.nombre ?? 'Sin obra asignada'),
                              style: context.text.bodyStrong),
                          if (_obra != null && _obra!.direccion.isNotEmpty)
                            Text(_obra!.direccion,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.caption),
                        ]),
                  ),
                ]),
              ),

              // ── Estadísticas de asistencia ──────────────────────────────────
              Row(children: [
                Expanded(
                  child: StatTile(
                    label: 'Días',
                    value: '${_totales.dias}',
                    accentColor: AppColors.roleEmpleado,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: StatTile(
                    label: 'Entradas',
                    value: '${_totales.entradas}',
                    accentColor: context.tokens.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: StatTile(
                    label: 'Salidas',
                    value: '${_totales.salidas}',
                    accentColor: context.tokens.textSecondary,
                  ),
                ),
              ]),

              // Aviso útil: jornadas abiertas sin marcar la salida.
              if (_totales.sinCerrar > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: AppCard(
                    color: context.tokens.warningSoft,
                    borderColor:
                        context.tokens.warning.withValues(alpha: 0.3),
                    child: Row(children: [
                      Icon(Icons.schedule,
                          size: 18, color: context.tokens.warning),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                            _totales.sinCerrar == 1
                                ? 'Tienes 1 día sin marcar la salida.'
                                : 'Tienes ${_totales.sinCerrar} días sin marcar la salida.',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.tokens.warning)),
                      ),
                    ]),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),

              // ── CTA: marcar asistencia ──────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: PrimaryButton.large(
                  label: 'Marcar asistencia',
                  icon: Icons.fingerprint,
                  color: AppColors.roleEmpleado,
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onMarcar?.call();
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── Mis tareas ──────────────────────────────────────────────────
              AppCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Expanded(child: CardTitle('Mis tareas')),
                        if (pendientes.isNotEmpty)
                          AppBadge(
                            '${pendientes.length}',
                            badgeTone: BadgeTone.info,
                          ),
                      ]),
                      if (_tareas.isEmpty)
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          child: EmptyState(
                            icon: Icons.checklist_outlined,
                            title: 'Sin tareas asignadas',
                            description:
                                'Cuando recibas una tarea aparecerá aquí.',
                          ),
                        )
                      else if (pendientes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md),
                          child: Row(children: [
                            Icon(Icons.check_circle_outlined,
                                size: 16, color: context.tokens.success),
                            const SizedBox(width: AppSpacing.sm),
                            Text('¡Todo al día! Sin tareas pendientes.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: context.tokens.success)),
                          ]),
                        )
                      else
                        for (final tarea in pendientes.take(3))
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm - 2),
                            child: Row(children: [
                              const Icon(Icons.radio_button_unchecked,
                                  size: 16, color: AppColors.roleEmpleado),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(tarea.titulo,
                                    style: context.text.body),
                              ),
                              AppBadge(estadoTareaLabel(tarea.estado),
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
}
