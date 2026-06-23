import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import '../../core/asistencia_service.dart';

/// Historial de asistencia del trabajador (solo memoria interna, sin red).
/// Agrupa los registros por día y muestra entrada/salida y la obra.
class EmpleadoInasistencias extends StatefulWidget {
  const EmpleadoInasistencias({super.key});
  @override
  State<EmpleadoInasistencias> createState() => _EmpleadoInasistenciasState();
}

class _EmpleadoInasistenciasState extends State<EmpleadoInasistencias> {
  Future<void> _refrescar() async => setState(() {});

  String _hora(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}';
  }

  String _fechaCorta(String f) {
    final p = f.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}' : f;
  }

  @override
  Widget build(BuildContext context) {
    final regs = AsistenciaService.instance.historialLocal();

    // Agrupar por fecha (ya viene ordenado desc por hora).
    final porFecha = <String, List<Map<String, dynamic>>>{};
    for (final r in regs) {
      porFecha.putIfAbsent(r['fecha'] as String, () => []).add(r);
    }
    final fechas = porFecha.keys.toList()..sort((a, b) => b.compareTo(a));

    final entradas = regs.where((r) => r['tipo'] == 'entrada').length;
    final salidas = regs.where((r) => r['tipo'] == 'salida').length;

    return Column(children: [
      const PanelHeader(
          title: 'Mi asistencia',
          subtitle: 'Historial registrado en este dispositivo',
          color: AppColors.empleado,
          icon: Icons.history),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _refrescar,
          child: ListView(padding: const EdgeInsets.all(12), children: [
            Row(children: [
              StatCard('${fechas.length}', 'Días', color: AppColors.empleado),
              const SizedBox(width: 8),
              StatCard('$entradas', 'Entradas', color: AppColors.success),
              const SizedBox(width: 8),
              StatCard('$salidas', 'Salidas', color: AppColors.textSoft),
            ]),
            const SizedBox(height: 10),
            if (fechas.isEmpty)
              const AppCard(
                child: IconRow(
                    icon: Icons.fingerprint,
                    iconColor: AppColors.textMuted,
                    title: 'Aún no has marcado asistencia',
                    subtitle: 'Tus marcas aparecerán aquí por día.'),
              )
            else
              AppCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CardTitle('Registros por día'),
                      for (final f in fechas) _filaDia(f, porFecha[f]!),
                    ]),
              ),
          ]),
        ),
      ),
    ]);
  }

  Widget _filaDia(String fecha, List<Map<String, dynamic>> items) {
    Map<String, dynamic>? buscar(String tipo) {
      for (final r in items) {
        if (r['tipo'] == tipo) return r;
      }
      return null;
    }

    final entrada = buscar('entrada');
    final salida = buscar('salida');
    final obra =
        (entrada ?? salida)?['obra_nombre']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
              color: AppColors.success, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_fechaCorta(fecha)} · $obra',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark)),
            Text(
                'Entrada ${_hora(entrada?['hora'] as String?)}  ·  '
                'Salida ${_hora(salida?['hora'] as String?)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
        AppBadge(salida != null ? 'Completo' : 'Solo entrada',
            tone: salida != null ? 'green' : 'amber'),
      ]),
    );
  }
}
