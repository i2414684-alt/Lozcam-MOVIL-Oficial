import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import '../../models/models.dart';
import '../../core/auth_service.dart';
import '../../core/asistencia_service.dart';
import '../../data/obras_repository.dart';
import '../../data/asignaciones_repository.dart';
import '../../data/personas_repository.dart';
import '../../data/tareas_repository.dart';
import '../shell_router.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Obra> _obras = [];
  Map<int, int> _conteo = {};
  int _personal = 0;
  int _presentesHoy = 0;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final obras = await cargarObras();
    final personal = await todoElPersonal();
    final conteo = await conteoAsignadosPorObra();
    final asist = await asistenciasHoyTodas();
    final presentes = asist.map((r) => r['perfil_id']).toSet().length;
    if (!mounted) return;
    setState(() {
      _obras = obras;
      _conteo = conteo;
      _personal = personal.length;
      _presentesHoy = presentes;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final u = AuthService.instance.session;
    final subtitulo = u == null ? 'Gerencia' : '${u.nombre} · ${u.rolNombre}';
    final tareas = todasLasTareas();
    final abiertas = tareas.where((t) => t.estado != 'completada').length;

    return Column(children: [
      PanelHeader(
          title: 'Panel Gerencia',
          subtitle: subtitulo,
          color: AppColors.admin,
          icon: Icons.grid_view_outlined,
          onLogout: () => cerrarSesionYSalir(context)),
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
                StatCard('$_personal', 'Personal', color: AppColors.empleado),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                StatCard('$abiertas', 'Tareas abiertas',
                    color: AppColors.warning),
                const SizedBox(width: 8),
                StatCard('$_presentesHoy', 'Presentes hoy',
                    color: AppColors.success),
              ]),
              const SizedBox(height: 10),
              if (_cargando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                AppCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CardTitle('Obras'),
                        if (_obras.isEmpty)
                          const Text('No hay obras activas.',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textMuted))
                        else
                          for (final o in _obras)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Row(children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 18, color: AppColors.admin),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(o.nombre,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textDark)),
                                ),
                                AppBadge('${_conteo[o.id] ?? 0} trab.',
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
            ],
          ),
        ),
      ),
    ]);
  }
}
