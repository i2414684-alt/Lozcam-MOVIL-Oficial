import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../data/fuente_datos.dart';
import '../../data/personas_repository.dart';
import '../../data/roles.dart';

/// Contacto del cliente: equipo de su proyecto (gerencia + jefatura de obra).
///
/// Lee de `profiles` a través de [equipoDeContacto]. Antes leía la semilla de
/// demo de la memoria interna, así que un cliente real veía como equipo de su
/// obra a personas que no existen en la empresa.
class ClienteContacto extends StatefulWidget {
  const ClienteContacto({super.key});

  @override
  State<ClienteContacto> createState() => _ClienteContactoState();
}

class _ClienteContactoState extends State<ClienteContacto> {
  List<Persona> _equipo = const [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final e = await equipoDeContacto();
    if (!mounted) return;
    setState(() {
      // Orden por jerarquía: primero gerencia, luego jefatura de obra.
      _equipo = e
        ..sort((a, b) {
          final na = rolPorClave(a.rol)?.nivel ?? 99;
          final nb = rolPorClave(b.rol)?.nivel ?? 99;
          return na != nb ? na.compareTo(nb) : a.nombre.compareTo(b.nombre);
        });
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
    final equipo = _equipo;

    return Column(children: [
      const PanelHeader(
          title: 'Contacto',
          subtitle: 'Equipo de tu proyecto',
          color: AppColors.roleCliente,
          icon: Icons.call_outlined),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(12), children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitle('Equipo de tu obra'),
              if (_cargando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                )
              else if (equipo.isEmpty)
                Text('Sin contactos disponibles.',
                    style: TextStyle(
                        fontSize: 12, color: context.tokens.textSecondary))
              else
                for (final p in equipo)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Avatar(_iniciales(p.nombre),
                          colorKey: rolPorClave(p.rol)?.color ?? 'blue'),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.nombre,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: context.tokens.textPrimary)),
                              Text(rolPorClave(p.rol)?.nombre ?? p.rol,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: context.tokens.textSecondary)),
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
                  iconColor: AppColors.roleCliente,
                  title: '(064) 123-456',
                  subtitle: 'Oficina principal — Huancayo'),
              IconRow(
                  icon: Icons.mail_outline,
                  iconColor: AppColors.brand,
                  title: 'info@lozcam.pe',
                  subtitle: 'Correo atención al cliente'),
            ]),
          ),
        ]),
      ),
    ]);
  }
}
