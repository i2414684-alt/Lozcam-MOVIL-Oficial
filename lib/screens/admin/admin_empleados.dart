import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import '../../data/roles.dart';
import '../../data/personas_repository.dart';

/// Equipo y jerarquía: personal real agrupado por nivel.
/// Producción: lee `profiles`; sin nube: usuarios de la memoria interna.
class AdminEmpleados extends StatefulWidget {
  const AdminEmpleados({super.key});
  @override
  State<AdminEmpleados> createState() => _AdminEmpleadosState();
}

class _AdminEmpleadosState extends State<AdminEmpleados> {
  List<Persona> _personal = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final p = await todoElPersonal();
    if (!mounted) return;
    setState(() {
      _personal = p;
      _cargando = false;
    });
  }

  String _iniciales(String nombre) {
    final p = nombre.trim().split(RegExp(r'\s+'));
    if (p.isEmpty || p.first.isEmpty) return '?';
    if (p.length == 1) return p.first.substring(0, 1).toUpperCase();
    return (p[0].substring(0, 1) + p[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final lista = [..._personal]..sort((a, b) {
        final na = rolPorClave(a.rol)?.nivel ?? 4;
        final nb = rolPorClave(b.rol)?.nivel ?? 4;
        if (na != nb) return na.compareTo(nb);
        return a.nombre.compareTo(b.nombre);
      });

    final orden = <String>[];
    final grupos = <String, List<Persona>>{};
    for (final p in lista) {
      final label = etiquetaNivel(rolPorClave(p.rol)?.nivel ?? 4);
      if (!grupos.containsKey(label)) {
        grupos[label] = [];
        orden.add(label);
      }
      grupos[label]!.add(p);
    }

    return Column(children: [
      const PanelHeader(
          title: 'Equipo y jerarquía',
          subtitle: 'Personal por nivel',
          color: AppColors.admin,
          icon: Icons.account_tree_outlined),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.all(12),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (_cargando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                AppCard(
                  child: Row(children: [
                    const Icon(Icons.groups_outlined, color: AppColors.admin),
                    const SizedBox(width: 10),
                    Text('${lista.length} miembros del equipo',
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
                          for (final p in grupos[label]!) _fila(p),
                        ]),
                  ),
              ],
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _fila(Persona p) {
    final rc = rolPorClave(p.rol);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Avatar(_iniciales(p.nombre), colorKey: rc?.color ?? 'blue'),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.nombre,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark)),
            Text(rc?.nombre ?? p.rol,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
      ]),
    );
  }
}
