import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../data/tareas_repository.dart';
import '../delegar_tarea.dart';
import '../mapa_calor.dart';

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
        builder: (_) => const DelegarTarea(color: AppColors.roleAdmin)));
    if (ok == true) _cargar();
  }

  /// Borrar es irreversible: se confirma, igual que en «Áreas». Antes bastaba
  /// un solo toque para perder la tarea.
  Future<void> _eliminar(TareaAsignada t) async {
    final ok = await confirmarAccion(
      context,
      titulo: 'Eliminar tarea',
      mensaje: '¿Eliminar "${t.titulo}"? Esta acción no se puede deshacer.',
    );
    if (!ok) return;
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
          color: AppColors.roleAdmin,
          icon: Icons.checklist),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(12), children: [
          // Actividad en vivo por área (mapa de calor): presentes, tareas, avance
          const ActividadAreasStrip(),
          const SizedBox(height: 8),
          // No existe tabla `tareas` en el backend: la delegación es local a
          // este dispositivo. Antes la app lo presentaba como si la tarea le
          // llegara al trabajador, y nunca le llegaba.
          const ChipSoloEsteDispositivo(
              detalle:
                  'Las tareas delegadas se guardan en este teléfono. El avance que aportan a la obra sí se publica en la base de datos.'),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _delegar,
              icon: const Icon(Icons.add_task, color: Colors.white, size: 18),
              label: const Text('Delegar nueva tarea',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.roleAdmin,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: StatTile(
                  label: 'Total',
                  value: '${_tareas.length}',
                  accentColor: AppColors.roleAdmin),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: StatTile(
                  label: 'Abiertas',
                  value: '$pend',
                  accentColor: AppColors.warning),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: StatTile(
                  label: 'Completadas',
                  value: '$comp',
                  accentColor: AppColors.success),
            ),
          ]),
          const SizedBox(height: 10),
          if (_tareas.isEmpty)
            AppCard(
              child: IconRow(
                  icon: Icons.assignment_outlined,
                  iconColor: context.tokens.textSecondary,
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
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.tokens.textPrimary)),
          ),
          AppBadge(estadoTareaLabel(t.estado), tone: estadoTareaTone(t.estado)),
        ]),
        if (t.descripcion.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(t.descripcion,
              style: TextStyle(fontSize: 11, color: context.tokens.textSecondary)),
        ],
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.arrow_downward, size: 13, color: context.tokens.textSecondary),
          const SizedBox(width: 2),
          Expanded(
            child: Text('${t.asignadoPorNombre}  →  ${t.destinoTexto}',
                style:
                    TextStyle(fontSize: 11, color: context.tokens.textSecondary)),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          AppBadge(prioridadLabel(t.prioridad), tone: prioridadTone(t.prioridad)),
          const SizedBox(width: 6),
          if (t.fechaEntrega != null)
            Text('Vence ${t.fechaEntrega}',
                style: TextStyle(fontSize: 10, color: context.tokens.textSecondary)),
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
