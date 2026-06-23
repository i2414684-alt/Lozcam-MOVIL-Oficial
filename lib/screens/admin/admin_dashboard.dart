import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import '../../core/auth_service.dart';
import '../../core/local_store.dart';
import '../../core/asistencia_service.dart';
import '../../data/obras_repository.dart';
import '../../data/asignaciones_repository.dart';
import '../../data/tareas_repository.dart';
import '../shell_router.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String get _hoy => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _refrescar() async => setState(() {});

  @override
  Widget build(BuildContext context) {
    final u = AuthService.instance.session;
    final subtitulo = u == null ? 'Gerencia' : '${u.nombre} · ${u.rolNombre}';

    final areas = areasLocales();
    final personal =
        LocalStore.usuarios().where((x) => x['rol'] != 'cliente').length;
    final tareas = todasLasTareas();
    final abiertas = tareas.where((t) => t.estado != 'completada').length;
    final registros = registrosAsistenciaLocales();
    final marcasHoy = registros
        .where((r) => r['fecha'] == _hoy && r['tipo'] == 'entrada')
        .map((r) => r['perfil_id'])
        .toSet()
        .length;

    return Column(children: [
      PanelHeader(
          title: 'Panel Gerencia',
          subtitle: subtitulo,
          color: AppColors.admin,
          icon: Icons.grid_view_outlined,
          onLogout: () => cerrarSesionYSalir(context)),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _refrescar,
          child: ListView(padding: const EdgeInsets.all(12), children: [
            Row(children: [
              StatCard('${areas.length}', 'Áreas', color: AppColors.admin),
              const SizedBox(width: 8),
              StatCard('$personal', 'Personal', color: AppColors.empleado),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              StatCard('$abiertas', 'Tareas abiertas',
                  color: AppColors.warning),
              const SizedBox(width: 8),
              StatCard('$marcasHoy', 'Presentes hoy',
                  color: AppColors.success),
            ]),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CardTitle('Áreas de trabajo'),
                    if (areas.isEmpty)
                      const Text('Crea áreas en la pestaña "Áreas".',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted))
                    else
                      for (final a in areas)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(children: [
                            const Icon(Icons.location_on_outlined,
                                size: 18, color: AppColors.admin),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(a.nombre,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textDark)),
                            ),
                            AppBadge(
                                '${contarTrabajadoresArea(a.id)} trab.',
                                tone: 'blue'),
                          ]),
                        ),
                  ]),
            ),
            AppCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CardTitle('Tareas recientes'),
                    if (tareas.isEmpty)
                      const Text('Aún no has delegado tareas.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted))
                    else
                      for (final t in tareas.take(4))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            Expanded(
                              child: Text('${t.titulo} → ${t.destinoTexto}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textDark)),
                            ),
                            const SizedBox(width: 6),
                            AppBadge(estadoTareaLabel(t.estado),
                                tone: estadoTareaTone(t.estado)),
                          ]),
                        ),
                  ]),
            ),
          ]),
        ),
      ),
    ]);
  }
}
