import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../models/models.dart';
import '../../data/obras_repository.dart';
import '../../data/actividad_areas.dart';
import '../../data/avance_repository.dart';
import '../../data/enums.dart';
import '../mapa_calor_obra.dart';

/// ============================================================================
///  DETALLE DEL PROYECTO (obra) — al tocar una obra en el panel del gerente.
///
///  KPIs (presupuesto, plazo, equipo, estado) + línea de tiempo de hitos
///  (tabla `fases_obra`; si no hay, usa los avances reportados) + actividad
///  de hoy (quién está trabajando / delegado). TODO en SOLO LECTURA.
/// ============================================================================

class ObraDetalle extends StatefulWidget {
  final Obra obra;
  const ObraDetalle({super.key, required this.obra});

  @override
  State<ObraDetalle> createState() => _ObraDetalleState();
}

class _ObraDetalleState extends State<ObraDetalle> {
  Map<String, dynamic>? _fila; // fila completa de la BD (fechas, tipo...)
  List<FaseObra> _fases = [];
  List<AvanceItem> _avances = [];
  double? _presupuesto;
  ActividadArea? _actividad;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final o = widget.obra;
    final resultados = await Future.wait([
      filaObraCompleta(o.id),
      fasesDeObra(o.id),
      avancesDeObra(o.id),
      presupuestoDeObra(o.id),
      cargarActividadAreas(soloObras: [o.id]),
    ]);
    if (!mounted) return;
    final actividad = resultados[4] as List<ActividadArea>;
    setState(() {
      _fila = resultados[0] as Map<String, dynamic>?;
      _fases = resultados[1] as List<FaseObra>;
      _avances = resultados[2] as List<AvanceItem>;
      _presupuesto = resultados[3] as double?;
      _actividad = actividad.isNotEmpty ? actividad.first : null;
      _cargando = false;
    });
  }

  String get _plazo {
    final f = _fila;
    if (f == null) return '-';
    for (final k in const ['fecha_fin', 'fecha_entrega', 'fin']) {
      final v = f[k];
      if (v != null && '$v'.isNotEmpty) return _fechaLegible('$v');
    }
    return '-';
  }

  String get _inicio {
    final f = _fila;
    if (f == null) return '-';
    for (final k in const ['fecha_inicio', 'inicio', 'created_at']) {
      final v = f[k];
      if (v != null && '$v'.isNotEmpty) return _fechaLegible('$v');
    }
    return '-';
  }

  static String _fechaLegible(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso.length >= 10 ? iso.substring(0, 10) : iso;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static String _monto(double v) {
    // S/ 1,250,000 (sin decimales para montos grandes)
    final s = v.round().toString();
    final sb = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) sb.write(',');
      sb.write(s[i]);
    }
    return 'S/ $sb';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final o = widget.obra;
    final avanceActual =
        _avances.isNotEmpty ? _avances.first.pct : (_actividad?.avancePct);

    return Scaffold(
      backgroundColor: t.appBg,
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _portada(o, t),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kpis(t, avanceActual),
                    const SizedBox(height: 12),
                    if (_actividad != null) _actividadHoy(t),
                    const SizedBox(height: 12),
                    Text('Línea de tiempo',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary)),
                    const SizedBox(height: 8),
                    if (_cargando)
                      const SkeletonList(count: 3)
                    else
                      _timeline(t),
                    const SizedBox(height: 12),
                    if (_actividad != null &&
                        _actividad!.delegados.isNotEmpty)
                      _equipo(t),
                  ]),
            ),
          ],
        ),
      ),
    );
  }

  /// Portada con degradado de marca (la foto real de la obra puede añadirse
  /// luego como asset/columna foto_url).
  Widget _portada(Obra o, AppTokens t) {
    return Container(
      height: 170,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brand, AppColors.brand900],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Expanded(
                child: Text('Detalle del proyecto',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
              IconButton(
                tooltip: 'Mapa de calor de la obra',
                icon: const Icon(Icons.local_fire_department,
                    color: Colors.white),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MapaCalorObraScreen(obra: widget.obra))),
              ),
            ]),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    if (o.direccion.isNotEmpty)
                      Text(o.direccion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: .85),
                              fontSize: 12)),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _kpis(AppTokens t, int? avance) {
    Widget kpi(IconData icon, String label, String valor, {Color? color}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: t.border, width: 0.6),
          ),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: t.brandSoft, shape: BoxShape.circle),
              child: Icon(icon, size: 17, color: t.brand),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 10, color: t.textSecondary)),
                    Text(valor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: color ?? t.textPrimary)),
                  ]),
            ),
          ]),
        ),
      );
    }

    final equipo = _actividad?.asignados ?? 0;
    return Column(children: [
      Row(children: [
        kpi(Icons.payments_outlined, 'Presupuesto',
            _presupuesto != null ? _monto(_presupuesto!) : '-'),
        const SizedBox(width: 8),
        kpi(Icons.schedule, 'Plazo', _plazo),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        kpi(Icons.groups_2_outlined, 'Equipo', '$equipo'),
        const SizedBox(width: 8),
        kpi(Icons.speed, 'Estado', labelEstadoObra(widget.obra.estado),
            color: t.brand),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        kpi(Icons.flag_outlined, 'Inicio', _inicio),
        const SizedBox(width: 8),
        kpi(Icons.trending_up, 'Avance',
            avance != null ? '$avance%' : 'Sin reporte'),
      ]),
    ]);
  }

  Widget _actividadHoy(AppTokens t) {
    final a = _actividad!;
    return AppCard(
      child: Row(children: [
        Icon(Icons.local_fire_department,
            color: AppColors.brand.withValues(alpha: .4 + a.intensidad * .6),
            size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            a.presentes.isEmpty
                ? 'Nadie ha marcado asistencia hoy en esta obra.'
                : 'Trabajando hoy (${a.presentes.length}): '
                    '${a.presentes.join(', ')} · última marca ${a.ultimaMarca}',
            style: TextStyle(fontSize: 12, color: t.textPrimary),
          ),
        ),
      ]),
    );
  }

  /// Línea de tiempo: fases reales (`fases_obra`) o, si no hay, los avances.
  Widget _timeline(AppTokens t) {
    final items = <(String, String, bool)>[]; // (título, subtítulo, hecho)
    if (_fases.isNotEmpty) {
      for (final f in _fases) {
        final hecho = f.estado.toLowerCase().contains('complet') ||
            f.estado.toLowerCase().contains('finaliz');
        items.add((
          'Hito ${f.orden}: ${f.nombre}',
          'Meta ${f.pctMeta}%${f.estado.isNotEmpty ? ' · ${f.estado}' : ''}',
          hecho
        ));
      }
    } else {
      for (final a in _avances.take(8)) {
        items.add((
          '${a.pct}% · ${a.texto.isEmpty ? 'Avance reportado' : a.texto}',
          '${_fechaLegible(a.fecha)} · ${a.autor}',
          a.pct >= 100
        ));
      }
    }
    if (items.isEmpty) {
      return AppCard(
        child: IconRow(
            icon: Icons.timeline,
            iconColor: t.textSecondary,
            title: 'Sin hitos ni avances aún',
            subtitle:
                'Cuando el equipo reporte avances (o existan fases), aparecerán aquí.'),
      );
    }
    return AppCard(
      child: Column(children: [
        for (var i = 0; i < items.length; i++)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Column(children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: items[i].$3 ? AppColors.brand : t.surfaceAlt,
                    border: Border.all(color: AppColors.brand, width: 2),
                  ),
                ),
                if (i != items.length - 1)
                  Expanded(
                    child: Container(
                        width: 2,
                        color: AppColors.brand.withValues(alpha: .35)),
                  ),
              ]),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      bottom: i == items.length - 1 ? 0 : 14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[i].$1,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: t.textPrimary)),
                        Text(items[i].$2,
                            style: TextStyle(
                                fontSize: 11, color: t.textSecondary)),
                      ]),
                ),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _equipo(AppTokens t) {
    final a = _actividad!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Equipo delegado (${a.delegados.length})',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: t.textPrimary)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final n in a.delegados)
          Chip(
            avatar: CircleAvatar(
              backgroundColor: t.brandSoft,
              child: Text(n.isNotEmpty ? n[0].toUpperCase() : '?',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: t.brand)),
            ),
            label: Text(n, style: const TextStyle(fontSize: 11)),
          ),
      ]),
    ]);
  }
}
