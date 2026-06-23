import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import '../../models/models.dart';
import '../../core/auth_service.dart';
import '../../core/asistencia_service.dart';
import '../../data/obras_repository.dart';
import '../../data/asignaciones_repository.dart';
import '../../data/tareas_repository.dart';
import '../shell_router.dart';

class EmpleadoDashboard extends StatelessWidget {
  /// Callback para saltar a la pestaña "Marcar" del shell.
  final VoidCallback? onMarcar;
  const EmpleadoDashboard({super.key, this.onMarcar});

  @override
  Widget build(BuildContext context) {
    final u = AuthService.instance.session;
    final saludo = u == null ? 'Buen día' : 'Buen día, ${u.primerNombre}';
    final rol = u?.rolNombre ?? 'Empleado';
    final rolClave = u?.rol ?? '';
    final id = u?.id ?? '';

    final asignadas = areasDeTrabajador(id);
    final areas =
        areasLocales().where((o) => asignadas.contains(o.id)).toList();
    final Obra? obra = areas.isNotEmpty ? areas.first : null;

    final tareas = tareasParaPersona(rolClave, id);
    final pendientes = tareas.where((t) => t.estado != 'completada').toList();

    final hist = AsistenciaService.instance.historialLocal();
    final dias = hist.map((r) => r['fecha']).toSet().length;
    final entradas = hist.where((r) => r['tipo'] == 'entrada').length;
    final salidas = hist.where((r) => r['tipo'] == 'salida').length;

    return Column(children: [
      PanelHeader(
          title: saludo,
          subtitle: rol,
          color: AppColors.empleado,
          icon: Icons.handyman_outlined,
          onLogout: () => cerrarSesionYSalir(context)),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(12), children: [
          // Obra asignada
          AppCard(
            color: AppColors.blueBg,
            borderColor: const Color(0xFFB5D4F4),
            child: Row(children: [
              const Icon(Icons.business_outlined,
                  color: AppColors.empleado, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Obra asignada',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.empleado)),
                      const SizedBox(height: 2),
                      Text(obra?.nombre ?? 'Sin área asignada',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                      if (obra != null && obra.direccion.isNotEmpty)
                        Text(obra.direccion,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSoft)),
                    ]),
              ),
            ]),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onMarcar,
              icon: const Icon(Icons.fingerprint, color: Colors.white),
              label: const Text('Marcar asistencia',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(height: 10),
          // Mis tareas
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitle('Mis tareas'),
              if (tareas.isEmpty)
                const Text('No tienes tareas asignadas.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted))
              else
                for (final t in pendientes.take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      const Icon(Icons.radio_button_unchecked,
                          size: 16, color: AppColors.empleado),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(t.titulo,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textDark)),
                      ),
                      AppBadge(estadoTareaLabel(t.estado),
                          tone: estadoTareaTone(t.estado)),
                    ]),
                  ),
              if (tareas.isNotEmpty && pendientes.isEmpty)
                const Text('¡Todo al día! Sin tareas pendientes.',
                    style: TextStyle(fontSize: 12, color: AppColors.success)),
            ]),
          ),
          // Mi asistencia
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitle('Mi asistencia'),
              Row(children: [
                _MiniStat(num: '$dias', label: 'Días', color: AppColors.empleado),
                const SizedBox(width: 16),
                _MiniStat(
                    num: '$entradas', label: 'Entradas', color: AppColors.success),
                const SizedBox(width: 16),
                _MiniStat(
                    num: '$salidas', label: 'Salidas', color: AppColors.textSoft),
              ]),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  final String num, label;
  final Color color;
  const _MiniStat({required this.num, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(num,
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: color)),
      Text(label,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
    ]);
  }
}
