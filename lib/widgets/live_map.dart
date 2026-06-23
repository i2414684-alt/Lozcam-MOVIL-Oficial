import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../theme/colors.dart';

typedef PosicionCallback = void Function(Position pos);

/// Mapa integrado en la app (OpenStreetMap, sin API key).
/// Muestra tu ubicación en vivo, la obra y su radio permitido, y la distancia
/// en tiempo real. Reporta cada posición al padre vía [onPosicion].
class LiveMap extends StatefulWidget {
  final double? obraLat;
  final double? obraLng;
  final int radioMetros;
  final String? obraNombre;
  final double height;
  final PosicionCallback? onPosicion;

  /// Si es false, no pide GPS ni muestra al usuario (solo dibuja la obra).
  final bool mostrarUsuario;

  const LiveMap({
    super.key,
    this.obraLat,
    this.obraLng,
    this.radioMetros = 200,
    this.obraNombre,
    this.height = 240,
    this.onPosicion,
    this.mostrarUsuario = true,
  });

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> {
  final MapController _map = MapController();
  StreamSubscription<Position>? _sub;
  Position? _pos;
  bool _cargando = true;
  bool _mapListo = false;
  bool _yaCentrado = false;
  String? _error;

  static const LatLng _fallback = LatLng(-12.0653, -75.2049); // Huancayo

  @override
  void initState() {
    super.initState();
    if (widget.mostrarUsuario) {
      _iniciar();
    } else {
      _cargando = false;
    }
  }

  @override
  void didUpdateWidget(covariant LiveMap old) {
    super.didUpdateWidget(old);
    // Si cambió la obra seleccionada, recentra el mapa hacia ella.
    if (old.obraLat != widget.obraLat || old.obraLng != widget.obraLng) {
      if (_mapListo && widget.obraLat != null && widget.obraLng != null) {
        _map.move(LatLng(widget.obraLat!, widget.obraLng!), 16);
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _iniciar() async {
    setState(() {
      _error = null;
      _cargando = true;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return _setError('Activa la ubicación (GPS) del dispositivo.');
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied) {
        return _setError('Permiso de ubicación denegado.');
      }
      if (permiso == LocationPermission.deniedForever) {
        return _setError('Permiso bloqueado. Actívalo en Ajustes.');
      }
      final pos = await Geolocator.getCurrentPosition();
      _onPos(pos);
      if (mounted) setState(() => _cargando = false);
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, distanceFilter: 5),
      ).listen(_onPos, onError: (_) {});
    } catch (_) {
      _setError('No se pudo obtener tu ubicación.');
    }
  }

  void _onPos(Position pos) {
    if (!mounted) return;
    setState(() => _pos = pos);
    widget.onPosicion?.call(pos);
    if (!_yaCentrado && _mapListo) {
      _yaCentrado = true;
      _map.move(LatLng(pos.latitude, pos.longitude), 16);
    }
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() {
      _error = msg;
      _cargando = false;
    });
  }

  void _recentrar() {
    if (_pos != null) {
      _map.move(LatLng(_pos!.latitude, _pos!.longitude), 16);
    } else if (widget.obraLat != null && widget.obraLng != null) {
      _map.move(LatLng(widget.obraLat!, widget.obraLng!), 16);
    }
  }

  double? get _distancia {
    if (_pos == null || widget.obraLat == null || widget.obraLng == null) {
      return null;
    }
    return Geolocator.distanceBetween(
        _pos!.latitude, _pos!.longitude, widget.obraLat!, widget.obraLng!);
  }

  LatLng get _centroInicial {
    if (widget.obraLat != null && widget.obraLng != null) {
      return LatLng(widget.obraLat!, widget.obraLng!);
    }
    if (_pos != null) return LatLng(_pos!.latitude, _pos!.longitude);
    return _fallback;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: _error != null ? _vistaError() : _vistaMapa(),
      ),
    );
  }

  Widget _vistaMapa() {
    final dist = _distancia;
    final hayObra = widget.obraLat != null && widget.obraLng != null;
    return Stack(children: [
      FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCenter: _centroInicial,
          initialZoom: 16,
          minZoom: 3,
          maxZoom: 18,
          onMapReady: () {
            _mapListo = true;
            if (_pos != null && !_yaCentrado) {
              _yaCentrado = true;
              _map.move(LatLng(_pos!.latitude, _pos!.longitude), 16);
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'pe.lozcam.lozcam_movil',
          ),
          if (hayObra)
            CircleLayer(circles: [
              CircleMarker(
                point: LatLng(widget.obraLat!, widget.obraLng!),
                radius: widget.radioMetros.toDouble(),
                useRadiusInMeter: true,
                color: AppColors.primary.withOpacity(0.12),
                borderColor: AppColors.primary.withOpacity(0.6),
                borderStrokeWidth: 1.5,
              ),
            ]),
          MarkerLayer(markers: [
            if (hayObra)
              Marker(
                point: LatLng(widget.obraLat!, widget.obraLng!),
                width: 40,
                height: 40,
                child: const Icon(Icons.location_on,
                    color: AppColors.primary, size: 36),
              ),
            if (_pos != null)
              Marker(
                point: LatLng(_pos!.latitude, _pos!.longitude),
                width: 24,
                height: 24,
                child: _puntoUsuario(),
              ),
          ]),
        ],
      ),
      if (dist != null) Positioned(top: 8, left: 8, child: _chipDistancia(dist)),
      Positioned(
        bottom: 8,
        right: 8,
        child: FloatingActionButton.small(
          heroTag: 'recentrar',
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          elevation: 2,
          onPressed: (_pos == null &&
                  (widget.obraLat == null || widget.obraLng == null))
              ? null
              : _recentrar,
          child: const Icon(Icons.my_location, size: 20),
        ),
      ),
      if (_cargando)
        Container(
          color: Colors.black.withOpacity(0.05),
          alignment: Alignment.center,
          child: const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4)),
        ),
    ]);
  }

  Widget _puntoUsuario() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.empleado,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 4),
        ],
      ),
    );
  }

  Widget _chipDistancia(double dist) {
    final dentro = dist <= widget.radioMetros;
    final tone = dentro ? AppColors.greenText : AppColors.redText;
    final bg = dentro ? AppColors.greenBg : AppColors.redBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tone.withOpacity(0.4), width: 0.5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(dentro ? Icons.check_circle : Icons.cancel, size: 14, color: tone),
        const SizedBox(width: 5),
        Text(
          dentro
              ? 'Dentro del rango · ${dist.round()} m'
              : 'Fuera · ${dist.round()} m de ${widget.radioMetros} m',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: tone),
        ),
      ]),
    );
  }

  Widget _vistaError() {
    return Container(
      color: AppColors.grayBg,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.location_off, size: 32, color: AppColors.textMuted),
        const SizedBox(height: 8),
        Text(_error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textSoft)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _iniciar,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Reintentar'),
        ),
      ]),
    );
  }
}
