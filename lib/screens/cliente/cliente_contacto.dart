import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import '../../core/local_store.dart';
import '../../data/roles.dart';

/// Contacto del cliente: equipo de su proyecto (gerencia + jefatura de obra),
/// tomado de la memoria interna. Datos de la oficina son estáticos.
class ClienteContacto extends StatelessWidget {
  const ClienteContacto({super.key});

  // Roles que son punto de contacto para el cliente.
  static const _rolesContacto = {
    'gerente_general',
    'subgerente',
    'administrador',
    'ingeniero_residente',
  };

  String _iniciales(String nombre) {
    final p = nombre.trim().split(RegExp(r'\s+'));
    if (p.isEmpty || p.first.isEmpty) return '?';
    if (p.length == 1) return p.first.substring(0, 1).toUpperCase();
    return (p[0].substring(0, 1) + p[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final equipo = LocalStore.usuarios()
        .where((u) => _rolesContacto.contains(u['rol']))
        .toList();

    return Column(children: [
      const PanelHeader(
          title: 'Contacto',
          subtitle: 'Equipo de tu proyecto',
          color: AppColors.cliente,
          icon: Icons.call_outlined),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(12), children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitle('Equipo de tu obra'),
              if (equipo.isEmpty)
                const Text('Sin contactos disponibles.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted))
              else
                for (final u in equipo)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Avatar(_iniciales('${u['nombre']}'),
                          colorKey: rolPorClave('${u['rol']}')?.color ?? 'blue'),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${u['nombre']}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textDark)),
                              Text(
                                  rolPorClave('${u['rol']}')?.nombre ??
                                      '${u['rol']}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.textMuted)),
                            ]),
                      ),
                    ]),
                  ),
            ]),
          ),
          const AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CardTitle('Oficina Lozcam'),
              IconRow(
                  icon: Icons.call_outlined,
                  iconColor: AppColors.cliente,
                  title: '(064) 123-456',
                  subtitle: 'Oficina principal — Huancayo'),
              IconRow(
                  icon: Icons.mail_outline,
                  iconColor: AppColors.primary,
                  title: 'info@lozcam.pe',
                  subtitle: 'Correo atención al cliente'),
            ]),
          ),
        ]),
      ),
    ]);
  }
}
