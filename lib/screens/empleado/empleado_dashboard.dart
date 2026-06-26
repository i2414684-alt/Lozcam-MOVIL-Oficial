import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/common.dart';
import '../../models/models.dart';
import '../../core/auth_service.dart';
import '../../core/asistencia_service.dart';
import '../../data/obras_repository.dart';
import '../../data/asignaciones_repository.dart';
import '../../data/tareas_repository.dart';
import '../shell_router.dart';

class EmpleadoDashboard extends StatelessWidget {
  /// Callback para saltar a la pestaña "Marcar" del shell.
  final VoidCallback? onMarcar;
  const EmpleadoDashboard({super.key, this.onMarcar});

  @override
  Widget build(BuildContext context) {
    final u   = AuthService.instance.session;
    final saludo = u == null ? 'Buen día' : 'Buen día, ${u.primerNombre}';
    final rol    = u?.rolNombre ?? 'Empleado';
    final rolClave = u?.rol ?? '';
    final id     = u?.id ?? '';

    final asignadas = areasDeTrabajador(id);
    final areas     =
        areasLocales().where((o) => asignadas.contains(o.id)).toList();
    final Obra? obra = areas.isNotEmpty ? areas.first : null;

    final tareas     = tareasParaPersona(rolClave, id);
    final pendientes = tareas.where((t) => t.estado != 'completada').toList();

    final hist    = AsistenciaService.instance.historialLocal();
    final dias    = hist.map((r) => r['fecha']).toSet().length;
    final entradas = hist.where((r) => r['tipo'] == 'entrada').length;
    final salidas  = hist.where((r) => r['tipo'] == 'salida').length;

    return Column(children: [
      PanelHeader(
          title:    saludo,
          subtitle: rol,
          color:    AppColors.roleEmpleado,
          icon:     Icons.handyman_outlined,
          onLogout: () => cerrarSesionYSalir(context)),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // ── Hero: obra asignada ─────────────────────────────────────────
            AppCard.tonal(
              seed: AppColors.roleEmpleado,
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        AppColors.roleEmpleado.withValues(alpha: .12),
                    borderRadius:
                        BorderRadius.circular(AppRadius.md),
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
                        Text(obra?.nombre ?? 'Sin área asignada',
                            style: context.text.bodyStrong),
                        if (obra != null && obra.direccion.isNotEmpty)
                          Text(obra.direccion,
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
                  value: '$dias',
                  accentColor: AppColors.roleEmpleado,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatTile(
                  label: 'Entradas',
                  value: '$entradas',
                  accentColor: context.tokens.success,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatTile(
                  label: 'Salidas',
                  value: '$salidas',
                  accentColor: context.tokens.textSecondary,
                ),
              ),
            ]),
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
                  onMarcar?.call();
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
                    if (tareas.isEmpty)
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
                                size: 16,
                                color: AppColors.roleEmpleado),
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
    ]);
  }
}
