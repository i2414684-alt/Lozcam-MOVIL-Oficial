import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import '../../models/models.dart';
import '../../core/local_store.dart';
import '../../core/asistencia_service.dart';
import '../../data/obras_repository.dart';
import '../../data/asignaciones_repository.dart';
import '../../data/tareas_repository.dart';

/// Monitor de gerencia (solo lectura): asistencia y tareas por área.
class AdminAsistencias extends StatefulWidget {
  const AdminAsistencias({super.key});
  @override
  State<AdminAsistencias> createState() => _AdminAsistenciasState();
}

class _AdminAsistenciasState extends State<AdminAsistencias> {
  String get _hoy => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _refrescar() async => setState(() {});

  @override
  Widget build(BuildContext context) {
    final areas = areasLocales();
    final asignaciones = LocalStore.asignaciones();
    final trabajadores =
        asignaciones.map((a) => a['perfil_id'] as String).toSet().length;
    final tareas = todasLasTareas();
    final abiertas = tareas.where((t) => t.estado != 'completada').length;
    final registros = registrosAsistenciaLocales();
    final marcasHoy = registros.where((r) => r['fecha'] == _hoy).toList();

    return Column(children: [
      const PanelHeader(
          title: 'Monitor',
          subtitle: 'Asistencia y tareas por área',
          color: AppColors.admin,
          icon: Icons.insights_outlined),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _refrescar,
          child: ListView(padding: const EdgeInsets.all(12), children: [
            Row(children: [
              StatCard('${areas.length}', 'Áreas', color: AppColors.admin),
              const SizedBox(width: 8),
              StatCard('$trabajadores', 'Asignados',
                  color: AppColors.empleado),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              StatCard('$abiertas', 'Tareas abiertas',
                  color: AppColors.warning),
              const SizedBox(width: 8),
              StatCard('${marcasHoy.length}', 'Marcas hoy',
                  color: AppColors.success),
            ]),
            const SizedBox(height: 10),
            _tareasPorEstado(tareas),
            _porArea(areas, registros),
          ]),
        ),
      ),
    ]);
  }

  Widget _tareasPorEstado(List<TareaAsignada> tareas) {
    int n(String e) => tareas.where((t) => t.estado == e).length;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CardTitle('Tareas por estado'),
        if (tareas.isEmpty)
          const Text('Aún no hay tareas delegadas.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted))
        else
          Row(children: [
            _mini(n('pendiente'), 'Pendientes', 'gray'),
            _mini(n('en_progreso'), 'En progreso', 'blue'),
            _mini(n('completada'), 'Completadas', 'green'),
          ]),
      ]),
    );
  }

  Widget _mini(int valor, String label, String tone) {
    final p = tonePair(tone);
    return Expanded(
      child: Column(children: [
        Text('$valor',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: p.fg)),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ]),
    );
  }

  Widget _porArea(List<Obra> areas, List<Map<String, dynamic>> registros) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CardTitle('Por área'),
        if (areas.isEmpty)
          const Text('Crea áreas en la pestaña "Áreas".',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted))
        else
          for (final a in areas) _filaArea(a, registros),
      ]),
    );
  }

  Widget _filaArea(Obra a, List<Map<String, dynamic>> registros) {
    final asignados = contarTrabajadoresArea(a.id);
    final presentesHoy = registros
        .where((r) =>
            (r['obra_id'] as num?)?.toInt() == a.id &&
            r['fecha'] == _hoy &&
            r['tipo'] == 'entrada')
        .map((r) => r['perfil_id'])
        .toSet()
        .length;
    final tone = asignados == 0
        ? 'gray'
        : presentesHoy >= asignados
            ? 'green'
            : presentesHoy == 0
                ? 'red'
                : 'amber';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.nombre,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark)),
            Text('$asignados asignado(s)',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
        AppBadge('$presentesHoy/$asignados hoy', tone: tone),
      ]),
    );
  }
}
