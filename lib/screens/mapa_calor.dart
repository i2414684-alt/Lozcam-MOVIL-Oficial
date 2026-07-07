import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../data/actividad_areas.dart';

/// ============================================================================
///  MAPA DE CALOR DE ÁREAS (gerente / jefaturas / cliente)
///
///  Dibuja sobre el mapa un "glow" naranja por área cuya opacidad y tamaño
///  dependen de la INTENSIDAD de trabajo (marcas de hoy + tareas en curso).
///  Selector por obra, leyenda y detalle de quién está presente/delegado.
///  "Tiempo real": se recarga solo cada 60 s + pull-to-refresh.
/// ============================================================================

class MapaCalorScreen extends StatefulWidget {
  /// Si se indica, solo muestra estas obras (p. ej. las del trabajador/cliente).
  final List<int>? soloObras;
  const MapaCalorScreen({super.key, this.soloObras});

  @override
  State<MapaCalorScreen> createState() => _MapaCalorScreenState();
}

class _MapaCalorScreenState extends State<MapaCalorScreen> {
  List<ActividadArea> _todas = [];
  int? _obraSel; // null = todas
  bool _cargando = true;
  Timer? _timer;
  final MapController _map = MapController();
  bool _mapListo = false;

  static const LatLng _fallback = LatLng(-12.0653, -75.2049); // Huancayo

  @override
  void initState() {
    super.initState();
    _cargar();
    // "Tiempo real" sin tocar la BD en exceso: refresco cada 60 s.
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _cargar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    final datos = await cargarActividadAreas(soloObras: widget.soloObras);
    if (!mounted) return;
    setState(() {
      _todas = datos;
      // Si el área seleccionada ya no existe (se eliminó/filtró), volver a
      // "Todas" — evita el crash value-not-in-items del Dropdown.
      if (_obraSel != null && !datos.any((a) => a.obra.id == _obraSel)) {
        _obraSel = null;
      }
      _cargando = false;
    });
  }

  List<ActividadArea> get _visibles => _obraSel == null
      ? _todas
      : _todas.where((a) => a.obra.id == _obraSel).toList();

  LatLng get _centro {
    final conCoords = _visibles.where((a) => a.coordsValidas).toList();
    if (conCoords.isEmpty) return _fallback;
    // Centrar en la más "caliente" visible.
    conCoords.sort((a, b) => b.intensidad.compareTo(a.intensidad));
    final o = conCoords.first.obra;
    return LatLng(o.lat, o.lng);
  }

  void _irA(ActividadArea a) {
    if (_mapListo && a.coordsValidas) {
      _map.move(LatLng(a.obra.lat, a.obra.lng), 16);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        title: const Text('Mapa de calor'),
        actions: [
          IconButton(
            tooltip: 'Actualizar ahora',
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: [
            _selectorObra(t),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: SizedBox(height: 300, child: _mapa()),
            ),
            const SizedBox(height: 8),
            _leyenda(t),
            const SizedBox(height: 12),
            Text('Actividad por área',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary)),
            const SizedBox(height: 8),
            if (_cargando)
              const SkeletonList(count: 3)
            else if (_visibles.isEmpty)
              AppCard(
                child: IconRow(
                    icon: Icons.local_fire_department_outlined,
                    iconColor: t.textSecondary,
                    title: 'Sin áreas para mostrar',
                    subtitle:
                        'Crea áreas o revisa los permisos de lectura (RLS).'),
              )
            else
              for (final a in _visibles) _tarjetaArea(a, t),
          ],
        ),
      ),
    );
  }

  Widget _selectorObra(AppTokens t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: t.border, width: 0.8),
      ),
      child: DropdownButton<int?>(
        value: _obraSel,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        items: [
          const DropdownMenuItem<int?>(
              value: null, child: Text('Todas las obras / áreas')),
          for (final a in _todas)
            DropdownMenuItem<int?>(value: a.obra.id, child: Text(a.obra.nombre)),
        ],
        onChanged: (v) {
          setState(() => _obraSel = v);
          if (v != null) {
            final sel = _todas.where((x) => x.obra.id == v);
            if (sel.isNotEmpty) _irA(sel.first);
          }
        },
      ),
    );
  }

  Widget _mapa() {
    final conCoords = _visibles.where((a) => a.coordsValidas).toList();
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _centro,
        initialZoom: _obraSel != null ? 16 : 13,
        minZoom: 3,
        maxZoom: 18,
        onMapReady: () => _mapListo = true,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'pe.lozcam.lozcam_movil',
          errorTileCallback: (tile, error, stackTrace) {},
        ),
        // "Glow" de calor: 3 círculos concéntricos por área, opacidad y radio
        // según la intensidad (más caliente = más grande y más opaco).
        CircleLayer(circles: [
          for (final a in conCoords) ...[
            CircleMarker(
              point: LatLng(a.obra.lat, a.obra.lng),
              radius: a.obra.radioMetros * (1.5 + a.intensidad),
              useRadiusInMeter: true,
              color: AppColors.brand
                  .withValues(alpha: 0.05 + a.intensidad * 0.10),
            ),
            CircleMarker(
              point: LatLng(a.obra.lat, a.obra.lng),
              radius: a.obra.radioMetros.toDouble(),
              useRadiusInMeter: true,
              color: AppColors.brand
                  .withValues(alpha: 0.10 + a.intensidad * 0.22),
              borderColor: AppColors.brand
                  .withValues(alpha: 0.35 + a.intensidad * 0.45),
              borderStrokeWidth: 1.5 + a.intensidad * 1.5,
            ),
            CircleMarker(
              point: LatLng(a.obra.lat, a.obra.lng),
              radius: a.obra.radioMetros * 0.4,
              useRadiusInMeter: true,
              color: AppColors.brand
                  .withValues(alpha: 0.15 + a.intensidad * 0.35),
            ),
          ],
        ]),
        MarkerLayer(markers: [
          for (final a in conCoords)
            Marker(
              point: LatLng(a.obra.lat, a.obra.lng),
              width: 130,
              height: 52,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.location_on,
                    color: AppColors.brand, size: 26),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '${a.obra.nombre} · ${a.presentes.length}👷',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark),
                  ),
                ),
              ]),
            ),
        ]),
      ],
    );
  }

  Widget _leyenda(AppTokens t) {
    Widget punto(double alpha, String label) => Row(children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: alpha),
                shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 11, color: t.textSecondary)),
        ]);
    return Row(children: [
      Text('Densidad de trabajo: ',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: t.textSecondary)),
      punto(0.85, 'Alta'),
      const SizedBox(width: 10),
      punto(0.45, 'Media'),
      const SizedBox(width: 10),
      punto(0.18, 'Baja'),
      const Spacer(),
      Icon(Icons.sensors, size: 13, color: t.brand),
      Text(' en vivo · 60 s',
          style: TextStyle(fontSize: 10, color: t.textSecondary)),
    ]);
  }

  Widget _tarjetaArea(ActividadArea a, AppTokens t) {
    return AppCard(
      child: InkWell(
        onTap: () {
          setState(() => _obraSel = a.obra.id);
          _irA(a);
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.local_fire_department,
                size: 18,
                color: AppColors.brand
                    .withValues(alpha: 0.35 + a.intensidad * 0.65)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(a.obra.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary)),
            ),
            AppBadge('Calor: ${a.nivelCalor}',
                badgeTone: a.intensidad >= 0.66
                    ? BadgeTone.danger
                    : a.intensidad >= 0.33
                        ? BadgeTone.warning
                        : BadgeTone.neutral),
          ]),
          const SizedBox(height: 6),
          // Barra de intensidad
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: a.intensidad.clamp(0.05, 1.0),
              minHeight: 6,
              backgroundColor: t.surfaceAlt,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.brand),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            _mini(t, Icons.engineering,
                '${a.presentes.length}/${a.asignados} presentes'),
            _mini(t, Icons.checklist,
                '${a.tareasAbiertas} tarea(s) · ${a.tareasEnProgreso} en curso'),
            _mini(t, Icons.trending_up,
                a.avancePct != null ? 'Avance ${a.avancePct}%' : 'Sin avance'),
            _mini(t, Icons.schedule, 'Última marca ${a.ultimaMarca}'),
          ]),
          if (a.presentes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Trabajando ahora: ${a.presentes.join(', ')}',
                style: TextStyle(fontSize: 11, color: t.textSecondary)),
          ],
          if (a.delegados.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Delegados al área: ${a.delegados.join(', ')}',
                style: TextStyle(fontSize: 11, color: t.textSecondary)),
          ],
        ]),
      ),
    );
  }

  Widget _mini(AppTokens t, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: t.textSecondary),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 10.5, color: t.textSecondary)),
      ]),
    );
  }
}

/// ============================================================================
///  Tira horizontal de actividad (para los apartados de TAREAS y CLIENTE).
///  Muestra por área: presentes, tareas y avance; tocar abre el mapa de calor.
/// ============================================================================
class ActividadAreasStrip extends StatefulWidget {
  /// Filtra a estas obras (p. ej. las asignadas al trabajador o la del
  /// cliente). null = todas (gerencia / jefaturas).
  final List<int>? soloObras;
  const ActividadAreasStrip({super.key, this.soloObras});

  @override
  State<ActividadAreasStrip> createState() => _ActividadAreasStripState();
}

class _ActividadAreasStripState extends State<ActividadAreasStrip> {
  List<ActividadArea>? _datos;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final d = await cargarActividadAreas(soloObras: widget.soloObras);
    if (mounted) setState(() => _datos = d);
  }

  void _abrirMapa() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MapaCalorScreen(soloObras: widget.soloObras)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final datos = _datos;
    if (datos == null) {
      return const SizedBox(height: 86, child: SkeletonList(count: 1));
    }
    if (datos.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.local_fire_department, size: 15, color: t.brand),
        const SizedBox(width: 4),
        Text('Actividad por área',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: t.textPrimary)),
        const Spacer(),
        TextButton(
          onPressed: _abrirMapa,
          child: const Text('Ver mapa de calor',
              style: TextStyle(fontSize: 11)),
        ),
      ]),
      SizedBox(
        height: 86,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final a in datos)
              GestureDetector(
                onTap: _abrirMapa,
                child: Container(
                  width: 170,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                        color: t.brand
                            .withValues(alpha: 0.15 + a.intensidad * 0.5),
                        width: 1),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.obra.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: t.textPrimary)),
                        const SizedBox(height: 4),
                        Text(
                            '${a.presentes.length}/${a.asignados} presentes · '
                            '${a.tareasAbiertas} tareas',
                            style: TextStyle(
                                fontSize: 10, color: t.textSecondary)),
                        Text(
                            a.avancePct != null
                                ? 'Avance ${a.avancePct}%'
                                : 'Sin avance reportado',
                            style: TextStyle(
                                fontSize: 10, color: t.textSecondary)),
                        const Spacer(),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: a.intensidad.clamp(0.05, 1.0),
                            minHeight: 4,
                            backgroundColor: t.surfaceAlt,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.brand),
                          ),
                        ),
                      ]),
                ),
              ),
          ],
        ),
      ),
    ]);
  }
}
