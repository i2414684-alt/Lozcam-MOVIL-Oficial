import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/charts.dart';
import '../widgets/diseno_3d.dart';
import '../models/models.dart';
import '../data/actividad_areas.dart';
import '../data/avance_repository.dart';
import '../data/diseno_obra.dart';

/// ============================================================================
///  MAPA DE CALOR POR OBRA (específico, no general)
///
///  Grafica el AVANCE REAL de la obra como una construcción progresiva según
///  lo que pidió el cliente (BD `obras.tipo_servicio` + nombre):
///   - estudio topográfico -> terreno con curvas de nivel
///   - planos              -> plano AutoCAD dibujándose
///   - construcción        -> casa/edificio/puente/pista/vereda creciendo
///  Varias peticiones = varias FASES (paneles) que se completan en orden con
///  el % global. El gerente puede EDITAR el diseño; el cliente solo ve.
///  Los días trabajados se grafican como manchas de calor (sin texto).
/// ============================================================================

class MapaCalorObraScreen extends StatefulWidget {
  final Obra obra;
  final bool puedeEditar; // gerente = true; cliente = false
  const MapaCalorObraScreen(
      {super.key, required this.obra, this.puedeEditar = true});

  @override
  State<MapaCalorObraScreen> createState() => _MapaCalorObraScreenState();
}

class _MapaCalorObraScreenState extends State<MapaCalorObraScreen>
    with WidgetsBindingObserver {
  DisenoObra? _diseno;
  ActividadArea? _actividad;
  List<double> _calorDias = const [];
  List<AvanceItem> _avances = const [];
  int _faseSel = 0;
  bool _cargando = true;
  bool _edicionAbierta = false;
  Timer? _timer;

  int get _pctGlobal => _actividad?.avancePct ?? 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargar();
    _arrancarTimer();
  }

  /// "Tiempo real": el gráfico se refresca solo cada 60 s.
  void _arrancarTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _cargar());
  }

  /// Se detiene el refresco con la app en segundo plano y se reanuda al volver:
  /// antes seguía consultando la base de datos cada minuto sin nadie mirando.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cargar();
      _arrancarTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    final resultados = await Future.wait([
      disenoDeObra(widget.obra),
      cargarActividadAreas(soloObras: [widget.obra.id]),
      calorPorDia(widget.obra.id),
      avancesDeObra(widget.obra.id),
    ]);
    if (!mounted) return;
    final actividad = resultados[1] as List<ActividadArea>;
    final diseno = resultados[0] as DisenoObra;
    setState(() {
      _diseno = diseno;
      _actividad = actividad.isNotEmpty ? actividad.first : null;
      _calorDias = resultados[2] as List<double>;
      _avances = resultados[3] as List<AvanceItem>;
      if (_faseSel >= diseno.fases.length) _faseSel = 0;
      _cargando = false;
    });
    // REGLA: construcción sin tipo definido -> el gerente pasa a edición.
    if (diseno.requiereEdicion && widget.puedeEditar && !_edicionAbierta) {
      _edicionAbierta = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _editarDiseno());
    }
  }

  Future<void> _editarDiseno() async {
    final base = _diseno ?? detectarDiseno(widget.obra);
    final nuevo = await showModalBottomSheet<DisenoObra>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EditorDiseno(inicial: base, obra: widget.obra),
    );
    if (nuevo != null) {
      await guardarDisenoObra(widget.obra.id, nuevo);
      if (mounted) {
        setState(() {
          _diseno = nuevo;
          _faseSel = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final d = _diseno;
    final fases = d?.fases ?? const <FaseDiseno>[];

    return Scaffold(
      backgroundColor: t.appBg,
      appBar: AppBar(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        title: Text(widget.obra.nombre,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (widget.puedeEditar)
            IconButton(
              tooltip: 'Editar diseño del mapa de calor',
              icon: const Icon(Icons.tune),
              onPressed: _editarDiseno,
            ),
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
        ],
      ),
      body: _cargando
          ? const Padding(
              padding: EdgeInsets.all(12), child: SkeletonList(count: 3))
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: [
                  _resumen(t),
                  const SizedBox(height: 10),
                  if (d != null && d.requiereEdicion)
                    _avisoEdicion(t)
                  else if (fases.isEmpty)
                    AppCard(
                      child: IconRow(
                          icon: Icons.design_services_outlined,
                          iconColor: t.textSecondary,
                          title: 'Sin diseño definido',
                          subtitle: widget.puedeEditar
                              ? 'Usa el botón de edición para elegir el tipo de trabajo.'
                              : 'El gerente aún no define el diseño de esta obra.'),
                    )
                  else ...[
                    if (fases.length > 1) _selectorFases(fases, t),
                    const SizedBox(height: 8),
                    _panelFase(fases, t),
                  ],
                  const SizedBox(height: 12),
                  _franjaDias(t),
                  const SizedBox(height: 2),
                  _historialAvances(t),
                ],
              ),
            ),
    );
  }

  /// Historial de avances: tendencia del % + línea de tiempo de reportes.
  Widget _historialAvances(AppTokens t) {
    if (_avances.isEmpty) return const SizedBox.shrink();
    // avancesDeObra viene del más reciente al más antiguo -> invertir para
    // graficar la evolución en el tiempo.
    final serie = _avances.reversed.map((a) => a.pct.toDouble()).toList();
    final visibles = _avances.take(8).toList();
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CardTitle('Historial de avances'),
        if (serie.length >= 2) ...[
          LineaTendencia(valores: serie, color: AppColors.brand, height: 110),
          const SizedBox(height: 10),
        ],
        for (var i = 0; i < visibles.length; i++)
          IntrinsicHeight(
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == 0 ? AppColors.brand : t.surfaceAlt,
                        border:
                            Border.all(color: AppColors.brand, width: 2),
                      ),
                    ),
                    if (i != visibles.length - 1)
                      Expanded(
                        child: Container(
                            width: 2,
                            color:
                                AppColors.brand.withValues(alpha: .3)),
                      ),
                  ]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          bottom: i == visibles.length - 1 ? 0 : 12),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                    visibles[i].fecha.length >= 10
                                        ? visibles[i].fecha.substring(0, 10)
                                        : visibles[i].fecha,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: t.textPrimary)),
                                if (visibles[i].texto.isNotEmpty)
                                  Text(visibles[i].texto,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: t.textSecondary)),
                              ]),
                        ),
                        AppBadge('${visibles[i].pct}%',
                            badgeTone: BadgeTone.info),
                      ]),
                    ),
                  ),
                ]),
          ),
      ]),
    );
  }

  /// Resumen general en cifras (sin descripciones de texto).
  Widget _resumen(AppTokens t) {
    final a = _actividad;
    // StatTile (única tarjeta KPI de la app). Antes esta pantalla usaba la
    // legacy `StatCard`, así que la misma métrica se veía de dos formas
    // distintas según la pestaña.
    return Row(children: [
      Expanded(
        child: StatTile(
            label: 'Avance global',
            value: '$_pctGlobal%',
            accentColor: AppColors.brand),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: StatTile(
            label: 'Presentes hoy',
            value: '${a?.presentes.length ?? 0}',
            accentColor: t.success),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: StatTile(
            label: 'Tareas abiertas',
            value: '${a?.tareasAbiertas ?? 0}',
            accentColor: t.warning),
      ),
    ]);
  }

  Widget _avisoEdicion(AppTokens t) {
    return AppCard.tonal(
      seed: AppColors.warning,
      child: Row(children: [
        const Icon(Icons.tune, color: AppColors.warning, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Esta obra pide CONSTRUCCIÓN pero falta definir el tipo '
            '(casa, edificio, puente, pista o vereda). '
            '${widget.puedeEditar ? 'Definelo en edición para generar el gráfico.' : 'El gerente debe definirlo.'}',
            style: TextStyle(fontSize: 12, color: t.textPrimary),
          ),
        ),
        if (widget.puedeEditar)
          TextButton(
              onPressed: _editarDiseno, child: const Text('Editar')),
      ]),
    );
  }

  Widget _selectorFases(List<FaseDiseno> fases, AppTokens t) {
    return SizedBox(
      height: 38,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (var i = 0; i < fases.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(
                  'Fase ${i + 1} · ${faseLabel(fases[i])} '
                  '· ${(progresoFase(i, fases.length, _pctGlobal) * 100).round()}%',
                  style: const TextStyle(fontSize: 11)),
              selected: _faseSel == i,
              selectedColor: t.brandSoft,
              onSelected: (_) => setState(() => _faseSel = i),
            ),
          ),
      ]),
    );
  }

  Widget _panelFase(List<FaseDiseno> fases, AppTokens t) {
    final i = _faseSel.clamp(0, fases.length - 1);
    final p = progresoFase(i, fases.length, _pctGlobal);
    final brightness = Theme.of(context).brightness;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(faseLabel(fases[i]),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary)),
          ),
          AppBadge('${(p * 100).round()}% de la fase',
              badgeTone: p >= 1
                  ? BadgeTone.success
                  : p > 0
                      ? BadgeTone.warning
                      : BadgeTone.neutral),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Diseno3D(
            fase: fases[i],
            calorDias: _calorDias,
            acento: AppColors.brand,
            guia: t.textSecondary,
            fondo: brightness == Brightness.dark
                ? const Color(0xFF10151C) // mesa de dibujo oscura
                : const Color(0xFFF2F5F9), // papel de plano claro
          ),
        ),
        const SizedBox(height: 8),
        _leyendaCalor(t),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: p,
            minHeight: 6,
            backgroundColor: t.surfaceAlt,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
          ),
        ),
      ]),
    );
  }

  /// Leyenda del mapa de intensidad: barra con la rampa térmica estándar
  /// (azul → verde → amarillo → rojo) de "Baja" a "Alta".
  Widget _leyendaCalor(AppTokens t) {
    return Row(children: [
      Text('Baja', style: TextStyle(fontSize: 10, color: t.textSecondary)),
      Expanded(
        child: Container(
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            gradient: const LinearGradient(colors: heatRampColors),
          ),
        ),
      ),
      Text('Alta', style: TextStyle(fontSize: 10, color: t.textSecondary)),
    ]);
  }

  /// Días trabajados graficados (intensidad de calor por día, sin texto).
  Widget _franjaDias(AppTokens t) {
    if (_calorDias.isEmpty) return const SizedBox.shrink();
    final n = _calorDias.length;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CardTitle('Días trabajados (últimos 7)'),
        Row(children: [
          for (var i = 0; i < n; i++) ...[
            Expanded(
              child: Tooltip(
                message: fechaDia(n - 1 - i),
                child: Column(children: [
                  Container(
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: _calorDias[i] > 0 ? null : t.surfaceAlt,
                      gradient: _calorDias[i] > 0
                          ? LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                colorTermico(_calorDias[i])
                                    .withValues(alpha: .90),
                                colorTermico(_calorDias[i])
                                    .withValues(alpha: .45),
                              ],
                            )
                          : null,
                      boxShadow: _calorDias[i] > 0
                          ? [
                              BoxShadow(
                                color: colorTermico(_calorDias[i])
                                    .withValues(alpha: .35),
                                blurRadius: 10,
                                spreadRadius: -2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(inicialDia(n - 1 - i),
                      style:
                          TextStyle(fontSize: 9, color: t.textSecondary)),
                ]),
              ),
            ),
            if (i != n - 1) const SizedBox(width: 4),
          ],
        ]),
      ]),
    );
  }
}

/// ═══ Editor del diseño (solo gerente): servicios + tipo de construcción ════
class _EditorDiseno extends StatefulWidget {
  final DisenoObra inicial;
  final Obra obra;
  const _EditorDiseno({required this.inicial, required this.obra});

  @override
  State<_EditorDiseno> createState() => _EditorDisenoState();
}

class _EditorDisenoState extends State<_EditorDiseno> {
  late DisenoObra _d = widget.inicial;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 14),
        child:
            Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Diseño del mapa de calor',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary)),
          const SizedBox(height: 2),
          Text(
              'Qué pidió el cliente en "${widget.obra.nombre}". El sistema lo '
              'detectó de la base de datos; corrígelo si hace falta.',
              style: TextStyle(fontSize: 11, color: t.textSecondary)),
          const SizedBox(height: 8),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Estudio topográfico (terreno)',
                style: TextStyle(fontSize: 13)),
            value: _d.topografico,
            onChanged: (v) => setState(() => _d = _d.copyWith(topografico: v)),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Planos (AutoCAD)', style: TextStyle(fontSize: 13)),
            value: _d.plano,
            onChanged: (v) => setState(() => _d = _d.copyWith(plano: v)),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Construcción', style: TextStyle(fontSize: 13)),
            value: _d.construccion,
            onChanged: (v) => setState(() =>
                _d = _d.copyWith(construccion: v, limpiarTipo: !v)),
          ),
          if (_d.construccion) ...[
            const SizedBox(height: 4),
            Text('Tipo de construcción',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: t.textSecondary)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final tipo in tiposConstruccion)
                ChoiceChip(
                  label: Text(faseLabel(tipo).replaceFirst('Construcción · ', ''),
                      style: const TextStyle(fontSize: 11)),
                  selected: _d.tipoConstruccion == tipo,
                  selectedColor: t.brandSoft,
                  onSelected: (_) =>
                      setState(() => _d = _d.copyWith(tipoConstruccion: tipo)),
                ),
            ]),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Guardar diseño',
              onPressed: (_d.fases.isEmpty && !_d.requiereEdicion) ||
                      _d.requiereEdicion
                  ? null
                  : () => Navigator.of(context).pop(_d),
            ),
          ),
          if (_d.requiereEdicion)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Elige el tipo de construcción para poder guardar.',
                  style: TextStyle(fontSize: 11, color: t.danger)),
            ),
        ]),
      ),
    );
  }
}
