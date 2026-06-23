import 'package:flutter/material.dart';
import '../../theme/colors.dart';
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
      backgroundColor: Colors.white,
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
                color: AppColors.screen,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.area.nombre,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                      Text('${_asignados.length} asignado(s)',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                    ]),
              ),
              Expanded(
                child: _personas.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No hay personal de campo disponible.',
                              style: TextStyle(color: AppColors.textMuted)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _personas.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: AppColors.line),
                        itemBuilder: (_, i) {
                          final p = _personas[i];
                          return CheckboxListTile(
                            value: _asignados.contains(p.id),
                            activeColor: AppColors.admin,
                            title: Text(p.nombre,
                                style: const TextStyle(fontSize: 14)),
                            subtitle: Text(
                                rolPorClave(p.rol)?.nombre ?? p.rol,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textMuted)),
                            onChanged: (v) => _toggle(p, v ?? false),
                          );
                        },
                      ),
              ),
            ]),
    );
  }
}
