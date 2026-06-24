import 'package:flutter/material.dart';
import '../../theme/colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final tareas = todasLasTareas();
    final abiertas = tareas.where((t) => t.estado != 'completada').length;
    final presentesHoy = _asistHoy.map((r) => r['perfil_id']).toSet().length;

    return Column(children: [
      const PanelHeader(
          title: 'Monitor',
          subtitle: 'Asistencia y tareas por área',
          color: AppColors.admin,
          icon: Icons.insights_outlined),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.all(12),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Row(children: [
                StatCard('${_obras.length}', 'Obras', color: AppColors.admin),
                const SizedBox(width: 8),
                StatCard('$abiertas', 'Tareas abiertas',
                    color: AppColors.warning),
                const SizedBox(width: 8),
                StatCard('$presentesHoy', 'Presentes hoy',
                    color: AppColors.success),
              ]),
              const SizedBox(height: 10),
              _tareasPorEstado(tareas),
              if (_cargando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                _porArea(),
            ],
          ),
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

  Widget _porArea() {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CardTitle('Por obra'),
        if (_obras.isEmpty)
          const Text('No hay obras activas.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted))
        else
          for (final o in _obras) _filaArea(o),
      ]),
    );
  }

  Widget _filaArea(Obra o) {
    final asignados = _conteo[o.id] ?? 0;
    final presentes = _presentesEn(o.id);
    final tone = asignados == 0
        ? 'gray'
        : presentes >= asignados
            ? 'green'
            : presentes == 0
                ? 'red'
                : 'amber';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o.nombre,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark)),
            Text('$asignados asignado(s)',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
        AppBadge('$presentes/$asignados hoy', tone: tone),
      ]),
    );
  }
}
