import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../models/models.dart';
import '../../data/obras_repository.dart';
import '../../data/asignaciones_repository.dart';
import '../../data/informes_repository.dart';

/// Lista de obras con su avance real: trabajadores asignados y el último
/// porcentaje reportado por el equipo (memoria interna, sin red).
class AdminObras extends StatefulWidget {
  const AdminObras({super.key});
  @override
  State<AdminObras> createState() => _AdminObrasState();
}

class _AdminObrasState extends State<AdminObras> {
  Future<void> _refrescar() async => setState(() {});

  @override
  Widget build(BuildContext context) {
    final areas = areasLocales();

    return Column(children: [
      const PanelHeader(
          title: 'Obras',
          subtitle: 'Avance por obra',
          color: AppColors.admin,
          icon: Icons.business_outlined),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _refrescar,
          child: ListView(padding: const EdgeInsets.all(12), children: [
            if (areas.isEmpty)
              AppCard(
                child: IconRow(
                    icon: Icons.business_outlined,
                    iconColor: context.tokens.textSecondary,
                    title: 'No hay obras registradas',
                    subtitle: 'Créalas en la pestaña "Áreas".'),
              )
            else
              for (final a in areas) _tarjeta(a),
          ]),
        ),
      ),
    ]);
  }

  Widget _tarjeta(Obra o) {
    final t = context.tokens;
    final trabajadores = contarTrabajadoresArea(o.id);
    final avances = informesDeObra(o.id);
    final pct = avances.isNotEmpty ? avances.first.pct : 0;
    final tone = avances.isEmpty
        ? BadgeTone.neutral
        : pct >= 60
            ? BadgeTone.success
            : pct >= 30
                ? BadgeTone.warning
                : BadgeTone.danger;

    // Tarjeta "Bento 2026": borde naranja sutil (0.18) + glow tenue del acento.
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: t.brand.withValues(alpha: .18), width: 1),
        boxShadow: [
          BoxShadow(
              color: t.brand.withValues(alpha: .10),
              blurRadius: 18,
              offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.brandSoft,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border:
                  Border.all(color: t.brand.withValues(alpha: .25), width: 0.8),
            ),
            child: Icon(Icons.apartment_rounded, color: t.brand, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary)),
              const SizedBox(height: 2),
              Text(o.direccion.isEmpty ? 'Sin dirección' : o.direccion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: t.textSecondary)),
            ]),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppBadge(avances.isEmpty ? 'Sin avance' : '$pct%', badgeTone: tone),
        ]),
        const SizedBox(height: AppSpacing.md),
        ProgressBar(pct),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          _chip(Icons.groups_2_outlined, '$trabajadores activo(s)'),
          const SizedBox(width: AppSpacing.sm),
          _chip(Icons.description_outlined, '${avances.length} reporte(s)'),
          const Spacer(),
          Icon(Icons.chevron_right, size: 18, color: t.textSecondary),
        ]),
      ]),
    );
  }

  Widget _chip(IconData icon, String label) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: t.textSecondary),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: t.textSecondary)),
      ]),
    );
  }
}
