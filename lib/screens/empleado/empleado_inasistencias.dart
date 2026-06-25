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
                StatCard('${_dias.length}', 'Días', color: AppColors.empleado),
                const SizedBox(width: 8),
                StatCard('$entradas', 'Entradas', color: AppColors.success),
                const SizedBox(width: 8),
                StatCard('$salidas', 'Salidas', color: context.tokens.textSecondary),
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
    final obra = (d['obra_nombre'] ?? '').toString();
    final salida = d['hora_salida'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        const Icon(Icons.check_circle, size: 16, color: AppColors.success),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(obra.isEmpty ? _fechaCorta(d['fecha']) : '${_fechaCorta(d['fecha'])} · $obra',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.tokens.textPrimary)),
            Text(
                'Entrada ${_hora(d['hora_entrada'])}  ·  Salida ${_hora(salida)}',
                style: TextStyle(fontSize: 11, color: context.tokens.textSecondary)),
          ]),
        ),
        AppBadge(salida != null ? 'Completo' : 'Solo entrada',
            tone: salida != null ? 'green' : 'amber'),
      ]),
    );
  }
}
