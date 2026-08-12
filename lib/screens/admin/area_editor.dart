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

  // Obra (de la BD) a la que pertenece esta área: el flujo real es
  // obra -> área de trabajo -> asistencia, así el área tiene contexto.
  List<Obra> _obras = [];
  Obra? _obraSel;

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
    _cargarObras();
  }

  Future<void> _cargarObras() async {
    final obras = await cargarObras();
    if (!mounted) return;
    Obra? sel;
    final a = widget.area;
    if (a != null) {
      final vinculo = obraVinculadaDeArea(a.id);
      if (vinculo != null) {
        for (final o in obras) {
          if (o.id == vinculo.id) sel = o;
        }
      }
    }
    setState(() {
      _obras = obras;
      _obraSel = sel;
    });
  }

  static bool _coordsValidas(Obra o) =>
      !(o.lat.abs() < 0.0001 && o.lng.abs() < 0.0001) &&
      o.lat >= -90 && o.lat <= 90 && o.lng >= -180 && o.lng <= 180;

  /// Al elegir obra: muestra su dirección y, si el punto aún no está fijado,
  /// arranca desde las coordenadas de la obra (menos trabajo para el gerente).
  void _elegirObra(Obra? o) {
    setState(() {
      _obraSel = o;
      if (o != null) {
        if (_nombre.text.trim().isEmpty) _nombre.text = 'Área · ${o.nombre}';
        if (_punto == null && _coordsValidas(o)) {
          _punto = LatLng(o.lat, o.lng);
          if (o.direccion.isNotEmpty) _direccion = o.direccion;
        }
      }
    });
    if (o != null && _punto != null && _mapListo) _map.move(_punto!, 16);
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
    // Regla: si hay obras en la BD, el área debe pertenecer a una (el flujo
    // real es obra -> área). Sin obras (modo offline) se permite sin vínculo.
    if (_obras.isNotEmpty && _obraSel == null) {
      _aviso('Selecciona la obra a la que pertenece esta área.');
      return;
    }
    if (_punto == null) {
      _aviso('Fija la ubicación: busca una dirección o toca el mapa.');
      return;
    }
    setState(() => _guardando = true);
    try {
      await guardarArea(
        id: widget.area?.id,
        nombre: _nombre.text.trim(),
        lat: _punto!.latitude,
        lng: _punto!.longitude,
        radio: _radio,
        direccion: _direccion,
        obraId: _obraSel?.id,
        obraNombre: _obraSel?.nombre,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _guardando = false);
        _aviso('No se pudo guardar el área. Intenta de nuevo.');
      }
    }
  }

  void _aviso(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tokens.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.roleAdmin,
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
        _selectorObra(),
        _buscador(),
        if (_resultados.isNotEmpty) _listaResultados(),
        Expanded(child: _mapaPicker()),
        _panelInferior(),
      ]),
    );
  }

  /// Obra (BD) a la que pertenece el área. Al elegirla se muestra su
  /// dirección registrada — antes de fijar la nueva área de trabajo.
  Widget _selectorObra() {
    final t = context.tokens;
    if (_obras.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.border, width: 0.8),
          ),
          child: DropdownButton<Obra>(
            value: _obraSel,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            hint: const Text('Obra a la que pertenece esta área',
                style: TextStyle(fontSize: 13)),
            items: [
              for (final o in _obras)
                DropdownMenuItem(
                    value: o,
                    child: Text(o.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13))),
            ],
            onChanged: _elegirObra,
          ),
        ),
        if (_obraSel != null && _obraSel!.direccion.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Row(children: [
              Icon(Icons.place_outlined, size: 13, color: t.brand),
              const SizedBox(width: 4),
              Expanded(
                child: Text(_obraSel!.direccion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 11, color: t.textSecondary)),
              ),
            ]),
          ),
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
          width: 52, // ancho FIJO: dentro de un Row el ancho es no-acotado y
          // un mínimo infinito (tema) rompía el layout → pantalla en blanco
          child: ElevatedButton(
            onPressed: _buscando ? null : _hacerBusqueda,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.roleAdmin,
                elevation: 0,
                minimumSize: const Size(52, 44),
                padding: EdgeInsets.zero,
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
                size: 20, color: AppColors.roleAdmin),
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
    // Funciona también en web: los tiles de Carto permiten CORS (la vieja
    // "pantalla en blanco" en web era un bug de layout del tema, no del mapa).
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
            // Carto Voyager: CORS habilitado, carga bien en web (OSM directo
            // deja el mapa en gris en el navegador).
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'pe.lozcam.lozcam_movil',
            errorTileCallback: (tile, error, stackTrace) {},
          ),
          if (_punto != null)
            CircleLayer(circles: [
              CircleMarker(
                point: _punto!,
                radius: _radio.toDouble(),
                useRadiusInMeter: true,
                color: AppColors.roleAdmin.withValues(alpha:0.12),
                borderColor: AppColors.roleAdmin.withValues(alpha:0.6),
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
                    color: AppColors.roleAdmin, size: 38),
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
                // Token del tema: en modo oscuro este cartel sobre el mapa
                // quedaba como un parche blanco.
                color: context.tokens.surface,
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
        // Token del tema, no blanco fijo (ver comentario del cartel de ayuda).
        color: context.tokens.surface,
        border: Border(top: BorderSide(color: context.tokens.border, width: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_direccion != null) ...[
          Row(children: [
            const Icon(Icons.place, size: 14, color: AppColors.roleAdmin),
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
          activeColor: AppColors.roleAdmin,
          label: '$_radio m',
          onChanged: (v) => setState(() => _radio = v.round()),
        ),
      ]),
    );
  }
}
