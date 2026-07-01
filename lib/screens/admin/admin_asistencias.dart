import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../models/models.dart';
import '../../core/asistencia_service.dart';
import '../../data/obras_repository.dart';
import '../../data/asignaciones_repository.dart';
import '../../data/tareas_repository.dart';

/// Monitor de gerencia (solo lectura): asistencia y tareas por área.
/// Producción: lee obras/asignaciones/asistencias de la BD; sin nube, local.
class AdminAsistencias extends StatefulWidget {
  const AdminAsistencias({super.key});
  @override
  State<AdminAsistencias> createState() => _AdminAsistenciasState();
}

class _AdminAsistenciasState extends State<AdminAsistencias> {
  List<Obra> _obras = [];
  Map<int, int> _conteo = {};
  List<Map<String, dynamic>> _asistHoy = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final obras = await cargarObras();
    final conteo = await conteoAsignadosPorObra();
    final asist = await asistenciasHoyTodas();
    if (!mounted) return;
    setState(() {
      _obras = obras;
      _conteo = conteo;
      _asistHoy = asist;
      _cargando = false;
    });
  }

  int _presentesEn(int obraId) => _asistHoy
      .where((r) => (r['obra_id'] as num?)?.toInt() == obraId)
      .map((r) => r['perfil_id'])
      .toSet()
      .length;

  /// Hay obras pero NO se pudo leer ninguna asignación ni asistencia: muy
  /// probablemente el RLS de la BD no deja leer esas tablas a gerencia.
  bool get _sospechaSinPermisos =>
      _obras.isNotEmpty &&
      _conteo.values.fold<int>(0, (a, b) => a + b) == 0 &&
      _asistHoy.isEmpty;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tareas = todasLasTareas();
    final abiertas = tareas.where((t) => t.estado != 'completada').length;
    final presentesHoy = _asistHoy.map((r) => r['perfil_id']).toSet().length;

    return Column(children: [
      const PanelHeader(
          title: 'Monitor',
          subtitle: 'Asistencia y tareas por área',
          color: AppColors.roleAdmin,
          icon: Icons.insights_outlined),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // KPIs
              Row(children: [
                Expanded(
                  child: StatTile(
                    label: 'Obras',
                    value: '${_obras.length}',
                    accentColor: AppColors.roleAdmin,
                    icon: Icons.apartment_rounded,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: StatTile(
                    label: 'Tareas abiertas',
                    value: '$abiertas',
                    accentColor: t.warning,
                    icon: Icons.checklist_rounded,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: StatTile(
                    label: 'Presentes hoy',
                    value: '$presentesHoy',
                    accentColor: t.success,
                    icon: Icons.how_to_reg_outlined,
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.sm),

              // Aviso de posible bloqueo por permisos (RLS).
              if (!_cargando && _sospechaSinPermisos) _avisoSinPermisos(t),

              _tareasPorEstado(tareas),

              if (_cargando)
                const SkeletonList(count: 2)
              else
                _porArea(),
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
            'Hay obras pero no se leyeron asignaciones ni asistencias. '
            'Revisa los permisos (RLS) de la base de datos para gerencia.',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: t.warning),
          ),
        ),
      ]),
    );
  }

  Widget _tareasPorEstado(List<TareaAsignada> tareas) {
    final t = context.tokens;
    int n(String e) => tareas.where((x) => x.estado == e).length;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CardTitle('Tareas por estado'),
        if (tareas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: EmptyState(
              icon: Icons.checklist_outlined,
              title: 'Sin tareas delegadas',
              description: 'Aquí verás el estado de las tareas del equipo.',
            ),
          )
        else
          Row(children: [
            _mini(n('pendiente'), 'Pendientes', t.textSecondary),
            _mini(n('en_progreso'), 'En progreso', t.brand),
            _mini(n('completada'), 'Completadas', t.success),
          ]),
      ]),
    );
  }

  Widget _mini(int valor, String label, Color color) {
    return Expanded(
      child: Column(children: [
        Text('$valor',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: color)),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 10, color: context.tokens.textSecondary)),
      ]),
    );
  }

  Widget _porArea() {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CardTitle('Por obra'),
        if (_obras.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: EmptyState(
              icon: Icons.business_outlined,
              title: 'Sin obras activas',
              description: 'No se pudieron leer obras de la base de datos.',
            ),
          )
        else
          for (final o in _obras) _filaArea(o),
      ]),
    );
  }

  Widget _filaArea(Obra o) {
    final t = context.tokens;
    final asignados = _conteo[o.id] ?? 0;
    final presentes = _presentesEn(o.id);
    final (String estado, BadgeTone tone) = asignados == 0
        ? ('Sin equipo', BadgeTone.neutral)
        : presentes >= asignados
            ? ('A tiempo', BadgeTone.success)
            : presentes == 0
                ? ('Retrasado', BadgeTone.danger)
                : ('Parcial', BadgeTone.warning);
    final ratio =
        asignados == 0 ? 0.0 : (presentes / asignados).clamp(0.0, 1.0);
    final barColor = switch (tone) {
      BadgeTone.success => t.success,
      BadgeTone.warning => t.warning,
      BadgeTone.danger => t.danger,
      _ => t.textSecondary,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(o.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: t.textPrimary)),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppBadge(estado, badgeTone: tone),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: t.surfaceAlt,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('$presentes/$asignados',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: t.textSecondary)),
        ]),
      ]),
    );
  }
}
