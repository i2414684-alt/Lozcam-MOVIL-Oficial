import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import '../../data/roles.dart';
import '../../data/personas_repository.dart';
import '../../data/asignaciones_repository.dart';

/// El gerente marca qué trabajadores de campo trabajan en un área.
/// Los marcados solo podrán marcar asistencia en esa área.
class AsignarTrabajadores extends StatefulWidget {
  final Obra area;
  const AsignarTrabajadores({super.key, required this.area});

  @override
  State<AsignarTrabajadores> createState() => _AsignarTrabajadoresState();
}

class _AsignarTrabajadoresState extends State<AsignarTrabajadores> {
  List<Persona> _personas = [];
  Set<String> _asignados = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final lista = await personasDeRoles(rolesDeCampo);
    if (!mounted) return;
    setState(() {
      _personas = lista;
      _asignados = trabajadoresDeArea(widget.area.id)
          .map((a) => a['perfil_id'] as String)
          .toSet();
      _cargando = false;
    });
  }

  Future<void> _toggle(Persona p, bool valor) async {
    if (valor) {
      await asignar(
          persona: p, areaId: widget.area.id, areaNombre: widget.area.nombre);
      setState(() => _asignados.add(p.id));
    } else {
      await quitar(p.id, widget.area.id);
      setState(() => _asignados.remove(p.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tokens.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.admin,
        foregroundColor: Colors.white,
        title: const Text('Asignar trabajadores'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                width: double.infinity,
                color: context.tokens.appBg,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.area.nombre,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.tokens.textPrimary)),
                      Text('${_asignados.length} asignado(s)',
                          style: TextStyle(
                              fontSize: 12, color: context.tokens.textSecondary)),
                    ]),
              ),
              Expanded(
                child: _personas.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('No hay personal de campo disponible.',
                              style: TextStyle(color: context.tokens.textSecondary)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _personas.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: context.tokens.border),
                        itemBuilder: (_, i) {
                          final p = _personas[i];
                          return CheckboxListTile(
                            value: _asignados.contains(p.id),
                            activeColor: AppColors.admin,
                            title: Text(p.nombre,
                                style: const TextStyle(fontSize: 14)),
                            subtitle: Text(
                                rolPorClave(p.rol)?.nombre ?? p.rol,
                                style: TextStyle(
                                    fontSize: 12, color: context.tokens.textSecondary)),
                            onChanged: (v) => _toggle(p, v ?? false),
                          );
                        },
                      ),
              ),
            ]),
    );
  }
}
