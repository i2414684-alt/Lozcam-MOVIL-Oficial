import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../core/asistencia_service.dart';

/// Historial de asistencia del trabajador, agrupado por día.
/// En producción lee la tabla `asistencias`; sin nube, la memoria interna.
class EmpleadoInasistencias extends StatefulWidget {
  const EmpleadoInasistencias({super.key});
  @override
  State<EmpleadoInasistencias> createState() => _EmpleadoInasistenciasState();
}

class _EmpleadoInasistenciasState extends State<EmpleadoInasistencias> {
  List<Map<String, dynamic>> _dias = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final d = await AsistenciaService.instance.resumen();
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

  String _fechaCorta(dynamic f) {
    final p = f.toString().split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}' : f.toString();
  }

  @override
  Widget build(BuildContext context) {
    final entradas = _dias.where((d) => d['hora_entrada'] != null).length;
    final salidas = _dias.where((d) => d['hora_salida'] != null).length;

    return Column(children: [
      const PanelHeader(
          title: 'Mi asistencia',
          subtitle: 'Historial de entradas y salidas',
          color: AppColors.empleado,
          icon: Icons.history),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.all(12),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Row(children: [
                Expanded(
                  child: StatTile(
                    label: 'Días',
                    value: '${_dias.length}',
                    accentColor: AppColors.empleado,
                    icon: Icons.calendar_month_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    label: 'Entradas',
                    value: '$entradas',
                    accentColor: AppColors.success,
                    icon: Icons.login,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    label: 'Salidas',
                    value: '$salidas',
                    accentColor: context.tokens.textSecondary,
                    icon: Icons.logout,
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              if (_cargando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_dias.isEmpty)
                AppCard(
                  child: IconRow(
                      icon: Icons.fingerprint,
                      iconColor: context.tokens.textSecondary,
                      title: 'Aún no has marcado asistencia',
                      subtitle: 'Tus marcas aparecerán aquí por día.'),
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

  Widget _filaDia(Map<String, dynamic> d) {
    final t = context.tokens;
    final obra = (d['obra_nombre'] ?? '').toString();
    final salida = d['hora_salida'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: t.successSoft, shape: BoxShape.circle),
          child: Icon(Icons.check_rounded, size: 18, color: t.success),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                obra.isEmpty
                    ? _fechaCorta(d['fecha'])
                    : '${_fechaCorta(d['fecha'])} · $obra',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary)),
            const SizedBox(height: 1),
            Text(
                'Entrada ${_hora(d['hora_entrada'])}  ·  Salida ${_hora(salida)}',
                style: TextStyle(fontSize: 11, color: t.textSecondary)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          AppBadge(salida != null ? 'Completo' : 'Solo entrada',
              badgeTone: salida != null ? BadgeTone.success : BadgeTone.warning),
          const SizedBox(height: 4),
          _gpsChip(t),
        ]),
      ]),
    );
  }

  /// Distintivo de validación por GPS (toda marca registrada pasó el radio).
  Widget _gpsChip(AppTokens t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: t.brandSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: t.brand.withValues(alpha: .25), width: 0.8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.location_on, size: 11, color: t.brand),
          const SizedBox(width: 3),
          Text('GPS',
              style: TextStyle(
                  fontSize: 9.5, fontWeight: FontWeight.w700, color: t.brand)),
        ]),
      );
}
