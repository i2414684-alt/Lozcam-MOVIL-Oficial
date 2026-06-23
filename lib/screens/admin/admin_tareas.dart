import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import '../../data/tareas_repository.dart';
import '../delegar_tarea.dart';

/// Consola de delegación y monitoreo de tareas (gerencia ve TODAS).
class AdminTareas extends StatefulWidget {
  const AdminTareas({super.key});
  @override
  State<AdminTareas> createState() => _AdminTareasState();
}

class _AdminTareasState extends State<AdminTareas> {
  List<TareaAsignada> _tareas = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() => setState(() => _tareas = todasLasTareas());

  Future<void> _delegar() async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => const DelegarTarea(color: AppColors.admin)));
    if (ok == true) _cargar();
  }

  Future<void> _eliminar(TareaAsignada t) async {
    await eliminarTarea(t.id);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final pend = _tareas.where((t) => t.estado != 'completada').length;
    final comp = _tareas.length - pend;
    return Column(children: [
      const PanelHeader(
          title: 'Delegación de tareas',
          subtitle: 'Monitoreo de toda la empresa',
          color: AppColors.admin,
          icon: Icons.checklist),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(12), children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _delegar,
              icon: const Icon(Icons.add_task, color: Colors.white, size: 18),
              label: const Text('Delegar nueva tarea',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.admin,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            StatCard('${_tareas.length}', 'Total', color: AppColors.admin),
            const SizedBox(width: 8),
            StatCard('$pend', 'Abiertas', color: AppColors.warning),
            const SizedBox(width: 8),
            StatCard('$comp', 'Completadas', color: AppColors.success),
          ]),
          const SizedBox(height: 10),
          if (_tareas.isEmpty)
            const AppCard(
              child: IconRow(
                  icon: Icons.assignment_outlined,
                  iconColor: AppColors.textMuted,
                  title: 'Sin tareas delegadas',
                  subtitle: 'Delega la primera a un rol de la empresa.'),
            )
          else
            for (final t in _tareas) _tarjeta(t),
        ]),
      ),
    ]);
  }

  Widget _tarjeta(TareaAsignada t) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(t.titulo,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
          ),
          AppBadge(estadoTareaLabel(t.estado), tone: estadoTareaTone(t.estado)),
        ]),
        if (t.descripcion.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(t.descripcion,
              style: const TextStyle(fontSize: 11, color: AppColors.textSoft)),
        ],
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.arrow_downward, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 2),
          Expanded(
            child: Text('${t.asignadoPorNombre}  →  ${t.destinoTexto}',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textSoft)),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          AppBadge(prioridadLabel(t.prioridad), tone: prioridadTone(t.prioridad)),
          const SizedBox(width: 6),
          if (t.fechaEntrega != null)
            Text('Vence ${t.fechaEntrega}',
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppColors.danger),
            tooltip: 'Eliminar',
            onPressed: () => _eliminar(t),
          ),
        ]),
      ]),
    );
  }
}
