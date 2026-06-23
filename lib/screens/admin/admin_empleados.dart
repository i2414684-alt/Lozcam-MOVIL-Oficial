import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import '../../core/local_store.dart';
import '../../data/roles.dart';
import '../../data/asignaciones_repository.dart';

/// Equipo y jerarquía: personal real (memoria interna) agrupado por nivel.
class AdminEmpleados extends StatelessWidget {
  const AdminEmpleados({super.key});

  String _iniciales(String nombre) {
    final p = nombre.trim().split(RegExp(r'\s+'));
    if (p.isEmpty || p.first.isEmpty) return '?';
    if (p.length == 1) return p.first.substring(0, 1).toUpperCase();
    return (p[0].substring(0, 1) + p[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final usuarios = [...LocalStore.usuarios()];
    usuarios.sort((a, b) {
      final na = rolPorClave('${a['rol']}')?.nivel ?? 4;
      final nb = rolPorClave('${b['rol']}')?.nivel ?? 4;
      if (na != nb) return na.compareTo(nb);
      return '${a['nombre']}'.compareTo('${b['nombre']}');
    });

    // Agrupar por etiqueta de nivel, preservando el orden jerárquico.
    final orden = <String>[];
    final grupos = <String, List<Map<String, dynamic>>>{};
    for (final u in usuarios) {
      final label = etiquetaNivel(rolPorClave('${u['rol']}')?.nivel ?? 4);
      if (!grupos.containsKey(label)) {
        grupos[label] = [];
        orden.add(label);
      }
      grupos[label]!.add(u);
    }

    final totalEmpresa = usuarios.where((u) => u['rol'] != 'cliente').length;

    return Column(children: [
      const PanelHeader(
          title: 'Equipo y jerarquía',
          subtitle: 'Personal por nivel',
          color: AppColors.admin,
          icon: Icons.account_tree_outlined),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(12), children: [
          AppCard(
            child: Row(children: [
              const Icon(Icons.groups_outlined, color: AppColors.admin),
              const SizedBox(width: 10),
              Text('$totalEmpresa miembros del equipo',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark)),
            ]),
          ),
          for (final label in orden)
            AppCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CardTitle(label),
                    for (final u in grupos[label]!) _fila(u),
                  ]),
            ),
        ]),
      ),
    ]);
  }

  Widget _fila(Map<String, dynamic> u) {
    final rol = '${u['rol']}';
    final rc = rolPorClave(rol);
    final esCampo = rolesDeCampo.contains(rol);
    final areas = esCampo ? areasDeTrabajador('${u['id']}').length : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Avatar(_iniciales('${u['nombre']}'), colorKey: rc?.color ?? 'blue'),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${u['nombre']}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark)),
            Text(rc?.nombre ?? rol,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
        if (esCampo)
          AppBadge('$areas área(s)', tone: areas > 0 ? 'green' : 'gray'),
      ]),
    );
  }
}
