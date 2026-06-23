import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/colors.dart';
import '../../widgets/common.dart';
import '../../models/models.dart';
import '../../core/auth_service.dart';
import '../../data/roles.dart';
import '../../data/obras_repository.dart';
import '../../data/asignaciones_repository.dart';
import '../../data/informes_repository.dart';

/// Parte de avance del trabajador, en memoria interna (offline).
/// - Roles de campo: reportan sobre una OBRA asignada.
/// - Técnico AutoCAD / oficina: reportan sobre una REFERENCIA (plano/entrega).
/// Permite adjuntar una FOTO de evidencia (se guarda local; subirá a Storage
/// cuando se integre la nube).
class EmpleadoInforme extends StatefulWidget {
  const EmpleadoInforme({super.key});
  @override
  State<EmpleadoInforme> createState() => _EmpleadoInformeState();
}

class _EmpleadoInformeState extends State<EmpleadoInforme> {
  final _texto = TextEditingController();
  final _ref = TextEditingController();
  double _pct = 50;
  List<Obra> _obras = [];
  Obra? _obra;
  String? _fotoPath;
  List<InformeAvance> _lista = [];

  bool get _esCampo =>
      rolesDeCampo.contains(AuthService.instance.session?.rol ?? '');
  bool get _esCad =>
      (AuthService.instance.session?.rol ?? '') == 'tecnico_autocad';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    if (_esCampo) {
      final id = AuthService.instance.session?.id ?? '';
      final asignadas = areasDeTrabajador(id);
      final todas = areasLocales();
      final obras = asignadas.isEmpty
          ? todas
          : todas.where((o) => asignadas.contains(o.id)).toList();
      setState(() {
        _obras = obras;
        _obra = obras.isNotEmpty ? obras.first : null;
      });
    }
    setState(() => _lista = misInformes());
  }

  @override
  void dispose() {
    _texto.dispose();
    _ref.dispose();
    super.dispose();
  }

  Future<void> _elegirFoto() async {
    final fuente = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de galería'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (fuente == null) return;
    try {
      final x = await ImagePicker()
          .pickImage(source: fuente, imageQuality: 70, maxWidth: 1280);
      if (x != null && mounted) setState(() => _fotoPath = x.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo obtener la imagen.')));
      }
    }
  }

  Future<void> _guardar() async {
    if (_texto.text.trim().isEmpty) {
      _aviso('Describe el avance antes de guardar.');
      return;
    }
    final String obraNombre;
    final int? obraId;
    if (_esCampo) {
      obraNombre = _obra?.nombre ?? 'General';
      obraId = _obra?.id;
    } else {
      obraNombre = _ref.text.trim().isEmpty ? 'General' : _ref.text.trim();
      obraId = null;
    }
    await guardarInforme(
      obraId: obraId,
      obraNombre: obraNombre,
      texto: _texto.text.trim(),
      pct: _pct.round(),
      fotoPath: _fotoPath,
    );
    _texto.clear();
    _ref.clear();
    setState(() => _fotoPath = null);
    _cargar();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Avance guardado.')));
    }
  }

  void _aviso(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String _fecha(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      PanelHeader(
          title: 'Parte de avance',
          subtitle: _esCad
              ? 'Avance de planos / diseño'
              : 'Registra el avance de la obra',
          color: AppColors.empleado,
          icon: Icons.description_outlined),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(12), children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CardTitle('Nuevo avance'),
              _selectorDestino(),
              _Label('Porcentaje completado: ${_pct.round()}%'),
              Slider(
                value: _pct,
                min: 0,
                max: 100,
                divisions: 20,
                activeColor: AppColors.empleado,
                label: '${_pct.round()}%',
                onChanged: (v) => setState(() => _pct = v),
              ),
              const _Label('Descripción del avance'),
              TextField(
                controller: _texto,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: _esCad
                      ? 'Ej. Planos estructurales piso 3 listos para revisión.'
                      : 'Ej. Vaciado de 4 columnas eje B-C, 6 operarios.',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.screen,
                  contentPadding: const EdgeInsets.all(11),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AppColors.border, width: 0.5)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.empleado)),
                ),
              ),
              const SizedBox(height: 8),
              _bloqueFoto(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _guardar,
                  icon: const Icon(Icons.save_outlined,
                      color: Colors.white, size: 18),
                  label: const Text('Guardar avance',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.empleado,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ]),
          ),
          if (_lista.isNotEmpty)
            AppCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CardTitle('Mis avances registrados'),
                    for (final inf in _lista) _fila(inf),
                  ]),
            ),
        ]),
      ),
    ]);
  }

  Widget _selectorDestino() {
    // Campo: obra asignada. Oficina/CAD: referencia (plano/entrega).
    if (_esCampo) {
      _Label label = const _Label('Obra');
      if (_obras.isEmpty) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          _Label('Obra'),
          Text('Sin obra asignada (se guardará como "General").',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        label,
        DropdownButton<Obra>(
          value: _obra,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          items: [
            for (final o in _obras)
              DropdownMenuItem(value: o, child: Text(o.nombre)),
          ],
          onChanged: (o) => setState(() => _obra = o),
        ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Label(_esCad ? 'Plano / entrega' : 'Referencia'),
      TextField(
        controller: _ref,
        decoration: InputDecoration(
          hintText: _esCad
              ? 'Ej. Plano A-201 · Fachada'
              : 'Ej. Documento / entrega',
          isDense: true,
          filled: true,
          fillColor: AppColors.screen,
          contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border, width: 0.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.empleado)),
        ),
      ),
    ]);
  }

  Widget _bloqueFoto() {
    final etiqueta = _esCad ? 'Adjuntar plano / imagen' : 'Adjuntar foto';
    if (_fotoPath == null) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _elegirFoto,
          icon: const Icon(Icons.photo_camera_outlined,
              size: 18, color: AppColors.textDark),
          label: Text(etiqueta,
              style: const TextStyle(
                  color: AppColors.textDark, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.grayBg,
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
        ),
      );
    }
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(File(_fotoPath!),
            width: double.infinity, height: 160, fit: BoxFit.cover),
      ),
      Positioned(
        top: 6,
        right: 6,
        child: GestureDetector(
          onTap: () => setState(() => _fotoPath = null),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
                color: Colors.black54, shape: BoxShape.circle),
            child: const Icon(Icons.close, size: 16, color: Colors.white),
          ),
        ),
      ),
    ]);
  }

  Widget _fila(InformeAvance inf) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (inf.fotoPath != null && File(inf.fotoPath!).existsSync()) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(inf.fotoPath!),
                width: 46, height: 46, fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text('${inf.obraNombre} · ${inf.pct}%',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
              ),
              Text(_fecha(inf.fecha),
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 2),
            Text(inf.texto,
                style: const TextStyle(fontSize: 11, color: AppColors.textSoft)),
            ProgressBar(inf.pct),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline,
              size: 18, color: AppColors.danger),
          tooltip: 'Eliminar',
          onPressed: () async {
            await eliminarInforme(inf.id);
            _cargar();
          },
        ),
      ]),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSoft)),
    );
  }
}
