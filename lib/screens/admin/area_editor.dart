import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/colors.dart';
import '../../theme/app_theme.dart';
import '../../core/geocoding_service.dart';
import '../../data/obras_repository.dart';
import '../../models/models.dart';

/// Editor de un área de trabajo (geolocalización del gerente).
/// Se fija un punto ESTÁTICO por dirección (Nominatim) o tocando el mapa.
/// No traza rutas: solo guarda la coordenada y el radio permitido.
class AreaEditor extends StatefulWidget {
  final Obra? area; // null = crear; no null = editar
  const AreaEditor({super.key, this.area});

  @override
  State<AreaEditor> createState() => _AreaEditorState();
}

class _AreaEditorState extends State<AreaEditor> {
  final _nombre = TextEditingController();
  final _buscar = TextEditingController();
  final MapController _map = MapController();

  LatLng? _punto;
  int _radio = 200;
  String? _direccion;
  List<GeoResultado> _resultados = [];
  bool _buscando = false;
  bool _guardando = false;
  bool _mapListo = false;

  static const LatLng _fallback = LatLng(-12.0653, -75.2049); // Huancayo

  @override
  void initState() {
    super.initState();
    final a = widget.area;
    if (a != null) {
      _nombre.text = a.nombre;
      _punto = LatLng(a.lat, a.lng);
      _radio = a.radioMetros;
      if (a.direccion.isNotEmpty) _direccion = a.direccion;
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _buscar.dispose();
    super.dispose();
  }

  Future<void> _hacerBusqueda() async {
    FocusScope.of(context).unfocus();
    setState(() => _buscando = true);
    final res = await GeocodingService.instance.buscar(_buscar.text);
    if (!mounted) return;
    setState(() {
      _resultados = res;
      _buscando = false;
    });
    if (res.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sin resultados. Toca el mapa para fijar el punto.')));
    }
  }

  void _elegir(GeoResultado r) {
    setState(() {
      _punto = LatLng(r.lat, r.lng);
      _direccion = r.nombre;
      _resultados = [];
    });
    if (_mapListo) _map.move(_punto!, 17);
  }

  Future<void> _tocarMapa(LatLng punto) async {
    setState(() {
      _punto = punto;
      _resultados = [];
      _direccion = null;
    });
    final dir =
        await GeocodingService.instance.direccionDe(punto.latitude, punto.longitude);
    if (mounted && dir != null) setState(() => _direccion = dir);
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty) {
      _aviso('Ponle un nombre al área.');
      return;
    }
    if (_punto == null) {
      _aviso('Fija la ubicación: busca una dirección o toca el mapa.');
      return;
    }
    setState(() => _guardando = true);
    await guardarArea(
      id: widget.area?.id,
      nombre: _nombre.text.trim(),
      lat: _punto!.latitude,
      lng: _punto!.longitude,
      radio: _radio,
      direccion: _direccion,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  void _aviso(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tokens.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.admin,
        foregroundColor: Colors.white,
        title: Text(widget.area == null ? 'Nueva área' : 'Editar área'),
        actions: [
          TextButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Guardar',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(children: [
        _buscador(),
        if (_resultados.isNotEmpty) _listaResultados(),
        Expanded(child: _mapaPicker()),
        _panelInferior(),
      ]),
    );
  }

  Widget _buscador() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _buscar,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _hacerBusqueda(),
            decoration: InputDecoration(
              hintText: 'Buscar dirección (ej. Jr. Loreto 240, Huancayo)',
              isDense: true,
              filled: true,
              fillColor: context.tokens.appBg,
              prefixIcon: const Icon(Icons.search, size: 20),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 44,
          child: ElevatedButton(
            onPressed: _buscando ? null : _hacerBusqueda,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.admin,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: _buscando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.travel_explore, color: Colors.white),
          ),
        ),
      ]),
    );
  }

  Widget _listaResultados() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: context.tokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.tokens.border, width: 0.5)),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _resultados.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: context.tokens.border),
        itemBuilder: (_, i) {
          final r = _resultados[i];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.place_outlined,
                size: 20, color: AppColors.admin),
            title: Text(r.nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
            onTap: () => _elegir(r),
          );
        },
      ),
    );
  }

  Widget _mapaPicker() {
    return Stack(children: [
      FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCenter: _punto ?? _fallback,
          initialZoom: _punto != null ? 17 : 14,
          minZoom: 3,
          maxZoom: 18,
          onMapReady: () => _mapListo = true,
          onTap: (tapPos, punto) => _tocarMapa(punto),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'pe.lozcam.lozcam_movil',
          ),
          if (_punto != null)
            CircleLayer(circles: [
              CircleMarker(
                point: _punto!,
                radius: _radio.toDouble(),
                useRadiusInMeter: true,
                color: AppColors.admin.withValues(alpha:0.12),
                borderColor: AppColors.admin.withValues(alpha:0.6),
                borderStrokeWidth: 1.5,
              ),
            ]),
          if (_punto != null)
            MarkerLayer(markers: [
              Marker(
                point: _punto!,
                width: 42,
                height: 42,
                child: const Icon(Icons.location_on,
                    color: AppColors.admin, size: 38),
              ),
            ]),
        ],
      ),
      if (_punto == null)
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: context.tokens.border, width: 0.5)),
            child: Text(
                'Busca una dirección o toca el mapa para fijar el área.',
                style: TextStyle(fontSize: 12, color: context.tokens.textSecondary)),
          ),
        ),
    ]);
  }

  Widget _panelInferior() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: context.tokens.border, width: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_direccion != null) ...[
          Row(children: [
            const Icon(Icons.place, size: 14, color: AppColors.admin),
            const SizedBox(width: 4),
            Expanded(
              child: Text(_direccion!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11, color: context.tokens.textSecondary)),
            ),
          ]),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _nombre,
          decoration: InputDecoration(
            hintText: 'Nombre del área (ej. Edif. Residencial Huancayo)',
            isDense: true,
            filled: true,
            fillColor: context.tokens.appBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.adjust, size: 16, color: context.tokens.textSecondary),
          const SizedBox(width: 6),
          Text('Radio permitido: $_radio m',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.tokens.textPrimary)),
        ]),
        Slider(
          value: _radio.toDouble(),
          min: 50,
          max: 1000,
          divisions: 19,
          activeColor: AppColors.admin,
          label: '$_radio m',
          onChanged: (v) => setState(() => _radio = v.round()),
        ),
      ]),
    );
  }
}
