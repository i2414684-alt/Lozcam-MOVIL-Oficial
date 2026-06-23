import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import '../../core/auth_service.dart';
import '../../data/roles.dart';
import '../../data/tareas_repository.dart';
import '../delegar_tarea.dart';

/// Tareas del trabajador: ve las dirigidas a SU rol, actualiza su estado y,
/// si su rol puede delegar (jefatura/mando), delega hacia su área.
class EmpleadoTareas extends StatefulWidget {
  const EmpleadoTareas({super.key});
  @override
  State<EmpleadoTareas> createState() => _EmpleadoTareasState();
}

class _EmpleadoTareasState extends State<EmpleadoTareas> {
  List<TareaAsignada> _tareas = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    final s = AuthService.instance.session;
    setState(() =>
        _tareas = tareasParaPersona(s?.rol ?? '', s?.id ?? ''));
  }

  Future<void> _delegar() async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => const DelegarTarea(color: AppColors.empleado)));
    if (ok == true) _cargar();
  }

  Future<void> _cambiarEstado(TareaAsignada t, String estado) async {
    await actualizarEstadoTarea(t, estado);
    _cargar();
  }

  Future<void> _completar(TareaAsignada t) async {
    await completarTarea(t); // registra avance en la obra y borra la tarea
    _cargar();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t.obraId != null && t.avancePct > 0
              ? 'Tarea cumplida · +${t.avancePct}% de avance en ${t.obraNombre}'
              : 'Tarea cumplida')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rol = AuthService.instance.session?.rol ?? '';
    final puedeDelegar = rolPorClave(rol)?.puedeDelegar ?? false;
    final pend = _tareas.where((t) => t.estado != 'completada').length;

    return Column(children: [
      const PanelHeader(
          title: 'Mis tareas',
          subtitle: 'Asignadas a tu rol',
          color: AppColors.empleado,
          icon: Icons.checklist),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(12), children: [
          if (puedeDelegar)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _delegar,
                icon: const Icon(Icons.add_task, color: Colors.white, size: 18),
                label: const Text('Delegar tarea a mi área',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.empleado,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
          if (puedeDelegar) const SizedBox(height: 8),
          Row(children: [
            AppBadge('Todas (${_tareas.length})', tone: 'gray'),
            const SizedBox(width: 6),
            AppBadge('Pendientes ($pend)', tone: 'amber'),
          ]),
          const SizedBox(height: 10),
          if (_tareas.isEmpty)
            const AppCard(
              child: IconRow(
                  icon: Icons.assignment_turned_in_outlined,
                  iconColor: AppColors.textMuted,
                  title: 'No tienes tareas asignadas',
                  subtitle: 'Cuando te deleguen una, aparecerá aquí.'),
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
          AppBadge(prioridadLabel(t.prioridad), tone: prioridadTone(t.prioridad)),
          const SizedBox(width: 6),
          Text('De: ${t.asignadoPorNombre}',
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          const Spacer(),
          if (t.fechaEntrega != null)
            Text('Vence ${t.fechaEntrega}',
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ]),
        const SizedBox(height: 8),
        _acciones(t),
      ]),
    );
  }

  Widget _acciones(TareaAsignada t) {
    if (t.estado == 'completada') {
      return const Row(children: [
        Icon(Icons.check_circle, size: 16, color: AppColors.success),
        SizedBox(width: 4),
        Text('Completada',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.success)),
      ]);
    }
    return Row(children: [
      if (t.estado == 'pendiente')
        Expanded(
          child: OutlinedButton(
            onPressed: () => _cambiarEstado(t, 'en_progreso'),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.empleado,
                side: const BorderSide(color: AppColors.empleado),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Iniciar', style: TextStyle(fontSize: 13)),
          ),
        ),
      if (t.estado == 'en_progreso')
        Expanded(
          child: ElevatedButton(
            onPressed: () => _completar(t),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text('Completar',
                style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ),
    ]);
  }
}
