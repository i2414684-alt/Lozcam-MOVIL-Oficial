import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../models/models.dart';
import '../../data/obras_repository.dart';
import '../../data/asignaciones_repository.dart';
import '../../data/avance_repository.dart';
import 'obra_detalle.dart';
import '../mapa_calor_obra.dart';

/// Lista de OBRAS reales (tabla `obras` de la nube), con trabajadores asignados
/// y el último % de avance reportado. Es la misma fuente que el dashboard, por
/// lo que aquí aparecen las mismas obras (antes leía áreas locales y salía vacía).
class AdminObras extends StatefulWidget {
  const AdminObras({super.key});
  @override
  State<AdminObras> createState() => _AdminObrasState();
}

class _AdminObrasState extends State<AdminObras> {
  List<Obra> _obras = [];
  Map<int, int> _conteo = {};
  final Map<int, int?> _pct = {}; // obra_id -> último % (null = sin reporte)
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final obras = await cargarObras();
    final conteo = await conteoAsignadosPorObra();
    final avances = await Future.wait(obras.map((o) => avancesDeObra(o.id)));
    if (!mounted) return;
    final pct = <int, int?>{};
    for (var i = 0; i < obras.length; i++) {
      pct[obras[i].id] = avances[i].isNotEmpty ? avances[i].first.pct : null;
    }
    setState(() {
      _obras = obras;
      _conteo = conteo;
      _pct
        ..clear()
        ..addAll(pct);
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const PanelHeader(
          title: 'Obras',
          subtitle: 'Avance por obra',
          color: AppColors.admin,
          icon: Icons.business_outlined),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.all(12),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (_cargando)
                const SkeletonList(count: 3)
              else if (_obras.isEmpty)
                AppCard(
                  child: IconRow(
                      icon: Icons.business_outlined,
                      iconColor: context.tokens.textSecondary,
                      title: 'No hay obras activas',
                      subtitle:
                          'No se pudieron leer obras de la base de datos.'),
                )
              else
                for (final o in _obras) _tarjeta(o),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _tarjeta(Obra o) {
    final t = context.tokens;
    final trabajadores = _conteo[o.id] ?? 0;
    final pct = _pct[o.id];
    final tone = pct == null
        ? BadgeTone.neutral
        : pct >= 60
            ? BadgeTone.success
            : pct >= 30
                ? BadgeTone.warning
                : BadgeTone.danger;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ObraDetalle(obra: o)),
      ),
      child: Container(
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
          AppBadge(pct == null ? 'Sin avance' : '$pct%', badgeTone: tone),
        ]),
        const SizedBox(height: AppSpacing.md),
        ProgressBar(pct ?? 0),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          _chip(Icons.groups_2_outlined, '$trabajadores asignado(s)'),
          const Spacer(),
          // Mapa de calor ESPECÍFICO de esta obra (avance graficado)
          IconButton(
            tooltip: 'Mapa de calor de la obra',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.local_fire_department,
                size: 20, color: AppColors.brand),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => MapaCalorObraScreen(obra: o))),
          ),
          Icon(Icons.chevron_right, size: 18, color: t.textSecondary),
        ]),
      ]),
      ),
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
