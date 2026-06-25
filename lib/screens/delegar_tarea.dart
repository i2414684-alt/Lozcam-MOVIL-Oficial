import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../core/auth_service.dart';
import '../models/models.dart';
import '../data/roles.dart';
import '../data/personas_repository.dart';
import '../data/obras_repository.dart';
import '../data/tareas_repository.dart';

/// Formulario para delegar una tarea a un rol inferior de la jerarquía.
/// Solo ofrece los roles a los que el usuario actual PUEDE delegar.
class DelegarTarea extends StatefulWidget {
  final Color color;
  const DelegarTarea({super.key, this.color = AppColors.admin});

  @override
  State<DelegarTarea> createState() => _DelegarTareaState();
}

class _DelegarTareaState extends State<DelegarTarea> {
  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  String? _rolDestino;
  String _prioridad = 'media';
  DateTime? _fecha;
  bool _guardando = false;

  List<Persona> _personas = [];
  Persona? _persona; // null = todos los del rol
  bool _cargandoPersonas = false;

  List<Obra> _obras = [];
  Obra? _obra; // obra a la que aporta avance (opcional)
  int _avancePct = 10; // % que aporta al cumplirse

  late final List<RolConfig> _destinos;

  @override
  void initState() {
    super.initState();
    final miRol = AuthService.instance.session?.rol ?? '';
    _destinos = rolesDelegablesPor(miRol);
    if (_destinos.isNotEmpty) {
      _rolDestino = _destinos.first.rol;
      _cargarPersonas();
    }
    _cargarObras();
  }

  Future<void> _cargarObras() async {
    final lista = await cargarObras();
    if (!mounted) return;
    setState(() {
      _obras = lista;
      _obra = lista.isNotEmpty ? lista.first : null;
    });
  }

  Future<void> _cargarPersonas() async {
    if (_rolDestino == null) return;
    setState(() {
      _cargandoPersonas = true;
      _persona = null;
    });
    final lista = await personasPorRol(_rolDestino!);
    if (!mounted) return;
    setState(() {
      _personas = lista;
      _cargandoPersonas = false;
    });
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context,
      initialDate: _fecha ?? hoy,
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 365)),
    );
    if (f != null) setState(() => _fecha = f);
  }

  Future<void> _guardar() async {
    if (_titulo.text.trim().isEmpty) {
      _aviso('Escribe el título de la tarea.');
      return;
    }
    if (_rolDestino == null) {
      _aviso('Elige a quién delegar.');
      return;
    }
    setState(() => _guardando = true);
    await delegarTarea(
      titulo: _titulo.text.trim(),
      descripcion: _descripcion.text.trim(),
      rolDestino: _rolDestino!,
      prioridad: _prioridad,
      asignadoAId: _persona?.id,
      asignadoANombre: _persona?.nombre,
      fechaEntrega: _fecha?.toIso8601String().substring(0, 10),
      obraId: _obra?.id,
      obraNombre: _obra?.nombre ?? '',
      avancePct: _obra == null ? 0 : _avancePct,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  void _aviso(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tokens.appBg,
      appBar: AppBar(
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        title: const Text('Delegar tarea'),
      ),
      body: _destinos.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                    'Tu rol no tiene a quién delegarle tareas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.tokens.textSecondary)),
              ),
            )
          : ListView(padding: const EdgeInsets.all(16), children: [
              _label('Título *'),
              TextField(
                controller: _titulo,
                decoration: _dec('¿Qué hay que hacer?'),
              ),
              const SizedBox(height: 14),
              _label('Descripción'),
              TextField(
                controller: _descripcion,
                maxLines: 3,
                decoration: _dec('Detalles de la tarea (opcional)'),
              ),
              const SizedBox(height: 14),
              _label('Delegar a *'),
              DropdownButtonFormField<String>(
                value: _rolDestino,
                isExpanded: true,
                decoration: _dec(''),
                items: [
                  for (final r in _destinos)
                    DropdownMenuItem(
                        value: r.rol,
                        child: Text(
                            '${r.nombre}  ·  ${etiquetaNivel(r.nivel)}')),
                ],
                onChanged: (v) {
                  setState(() => _rolDestino = v);
                  _cargarPersonas();
                },
              ),
              const SizedBox(height: 14),
              _label('Persona'),
              _selectorPersona(),
              const SizedBox(height: 14),
              _label('Prioridad'),
              DropdownButtonFormField<String>(
                value: _prioridad,
                isExpanded: true,
                decoration: _dec(''),
                items: [
                  for (final p in prioridadesTarea)
                    DropdownMenuItem(value: p, child: Text(prioridadLabel(p))),
                ],
                onChanged: (v) => setState(() => _prioridad = v ?? 'media'),
              ),
              const SizedBox(height: 14),
              _label('Obra (avance al cumplirse)'),
              DropdownButtonFormField<int?>(
                value: _obra?.id,
                isExpanded: true,
                decoration: _dec(''),
                items: [
                  const DropdownMenuItem<int?>(
                      value: null, child: Text('Sin obra (no aporta avance)')),
                  for (final o in _obras)
                    DropdownMenuItem<int?>(value: o.id, child: Text(o.nombre)),
                ],
                onChanged: (id) => setState(() => _obra = id == null
                    ? null
                    : _obras.firstWhere((o) => o.id == id)),
              ),
              if (_obra != null) ...[
                const SizedBox(height: 10),
                _label('Avance que aporta al cumplirse: $_avancePct%'),
                Slider(
                  value: _avancePct.toDouble(),
                  min: 1,
                  max: 100,
                  divisions: 99,
                  activeColor: widget.color,
                  label: '$_avancePct%',
                  onChanged: (v) => setState(() => _avancePct = v.round()),
                ),
              ],
              const SizedBox(height: 14),
              _label('Fecha de entrega'),
              InkWell(
                onTap: _elegirFecha,
                child: InputDecorator(
                  decoration: _dec(''),
                  child: Row(children: [
                    Icon(Icons.event, size: 18, color: context.tokens.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      _fecha == null
                          ? 'Sin fecha'
                          : _fecha!.toIso8601String().substring(0, 10),
                      style: TextStyle(
                          fontSize: 14, color: context.tokens.textPrimary),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: widget.color,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: _guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: Colors.white))
                      : const Text('Delegar tarea',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
    );
  }

  Widget _selectorPersona() {
    if (_cargandoPersonas) {
      return InputDecorator(
        decoration: _dec(''),
        child: Row(children: [
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Text('Cargando personas…',
              style: TextStyle(fontSize: 13, color: context.tokens.textSecondary)),
        ]),
      );
    }
    return DropdownButtonFormField<String?>(
      value: _persona?.id,
      isExpanded: true,
      decoration: _dec(''),
      items: [
        const DropdownMenuItem<String?>(
            value: null, child: Text('Todos los de este rol')),
        for (final p in _personas)
          DropdownMenuItem<String?>(value: p.id, child: Text(p.nombre)),
      ],
      onChanged: (id) => setState(() => _persona =
          id == null ? null : _personas.firstWhere((p) => p.id == id)),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.tokens.textSecondary)),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: context.tokens.appBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      );
}
