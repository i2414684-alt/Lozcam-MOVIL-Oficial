import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../data/fuente_datos.dart';

/// Historial de asistencia del trabajador, día por día, CON las faltas.
///
/// Antes esta pantalla se llamaba «inasistencias» pero nunca calculaba una
/// falta: listaba solo los días con marca, todos con check verde. Ahora
/// recorre el calendario del período y marca en rojo los días hábiles sin
/// registro (lunes a sábado; el domingo no cuenta).
///
/// En producción lee la tabla `asistencias`; sin nube, la memoria interna.
class EmpleadoInasistencias extends StatefulWidget {
  const EmpleadoInasistencias({super.key});
  @override
  State<EmpleadoInasistencias> createState() => _EmpleadoInasistenciasState();
}

class _EmpleadoInasistenciasState extends State<EmpleadoInasistencias> {
  List<DiaAsistencia> _dias = const [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final d = await historialConFaltas();
    if (!mounted) return;
    setState(() {
      _dias = d;
      _cargando = false;
    });
  }

  String _hora(dynamic iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso.toString());
    if (d == null) return '—';
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.hour)}:${two(l.minute)}';
  }

  String _fechaCorta(String f) {
    final p = f.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}' : f;
  }

  @override
  Widget build(BuildContext context) {
    final asistidos = _dias.where((d) => !d.falta).length;
    final faltas = _dias.where((d) => d.falta).length;
    final habiles = _dias.length;
    // Porcentaje de cumplimiento del período: es la cifra que de verdad le
    // sirve al trabajador y a gerencia.
    final pct = habiles == 0 ? 0 : ((asistidos / habiles) * 100).round();

    return Column(children: [
      const PanelHeader(
          title: 'Mi asistencia',
          subtitle: 'Historial y faltas · últimos 30 días',
          color: AppColors.roleEmpleado,
          icon: Icons.history),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Row(children: [
                Expanded(
                  child: StatTile(
                    label: 'Asistidos',
                    value: '$asistidos',
                    accentColor: context.tokens.success,
                    icon: Icons.check_circle_outline,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: StatTile(
                    label: 'Faltas',
                    value: '$faltas',
                    accentColor: faltas > 0
                        ? context.tokens.danger
                        : context.tokens.textSecondary,
                    icon: Icons.event_busy_outlined,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: StatTile(
                    label: 'Cumplimiento',
                    value: '$pct%',
                    accentColor: AppColors.roleEmpleado,
                    icon: Icons.percent,
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.md),
              if (_cargando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_dias.isEmpty)
                const AppCard(
                  child: EmptyState(
                      icon: Icons.fingerprint,
                      title: 'Aún no has marcado asistencia',
                      description:
                          'Tus marcas y tus faltas aparecerán aquí por día.'),
                )
              else
                AppCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CardTitle('Registros por día'),
                        for (final d in _dias) _filaDia(d),
                      ]),
                ),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _filaDia(DiaAsistencia d) {
    final t = context.tokens;
    final falta = d.falta;
    final fondo = falta
        ? t.dangerSoft
        : (d.completo ? t.successSoft : t.warningSoft);
    final tinte =
        falta ? t.danger : (d.completo ? t.success : t.warning);
    final icono = falta
        ? Icons.close_rounded
        : (d.completo ? Icons.check_rounded : Icons.schedule);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
          child: Icon(icono, size: 18, color: tinte),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                d.obraNombre.isEmpty
                    ? _fechaCorta(d.fecha)
                    : '${_fechaCorta(d.fecha)} · ${d.obraNombre}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary)),
            const SizedBox(height: 1),
            Text(
                falta
                    ? 'Sin marca de asistencia'
                    : 'Entrada ${_hora(d.horaEntrada)}  ·  Salida ${_hora(d.horaSalida)}',
                style: TextStyle(fontSize: 11, color: t.textSecondary)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          AppBadge(
              falta ? 'Falta' : (d.completo ? 'Completo' : 'Solo entrada'),
              badgeTone: falta
                  ? BadgeTone.danger
                  : (d.completo ? BadgeTone.success : BadgeTone.warning)),
          const SizedBox(height: 4),
          if (!falta) _gpsChip(t),
        ]),
      ]),
    );
  }

  /// Distintivo de validación por GPS (toda marca registrada pasó el radio).
  Widget _gpsChip(AppTokens t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: t.brandSoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: t.brand.withValues(alpha: .25), width: 0.8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.location_on, size: 11, color: t.brand),
          const SizedBox(width: 3),
          Text('GPS',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: t.brand)),
        ]),
      );
}
