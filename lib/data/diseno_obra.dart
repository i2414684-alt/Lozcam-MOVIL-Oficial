import '../core/local_store.dart';
import '../models/models.dart';
import 'reporte_datos.dart' show fechaCorta;
import '../core/asistencia_service.dart';

/// ============================================================================
///  DISEÑO DEL MAPA DE CALOR POR OBRA
///
///  El sistema DETECTA qué pidió el cliente leyendo `obras.tipo_servicio` y el
///  nombre de la obra (BD existente, sin tablas nuevas):
///    - estudio topográfico  -> panel de terreno
///    - planos (AutoCAD)     -> panel de plano en construcción
///    - construcción         -> panel del tipo elegido (casa/edificio/puente/
///                              pista/vereda). Si el tipo no se puede deducir,
///                              el gerente DEBE pasar por edición primero.
///  Si el cliente pidió varios servicios, hay VARIAS fases (paneles) y el
///  avance global se reparte secuencialmente entre ellas.
///  La elección/corrección del gerente se guarda en memoria interna
///  (LocalStore) por obra — la BD no se toca.
/// ============================================================================

/// Tipos de panel que puede graficar el sistema.
enum FaseDiseno { topografico, plano, casa, edificio, puente, pista, vereda }

const tiposConstruccion = [
  FaseDiseno.casa,
  FaseDiseno.edificio,
  FaseDiseno.puente,
  FaseDiseno.pista,
  FaseDiseno.vereda,
];

String faseLabel(FaseDiseno f) => switch (f) {
      FaseDiseno.topografico => 'Estudio topográfico',
      FaseDiseno.plano => 'Plano (AutoCAD)',
      FaseDiseno.casa => 'Construcción · Casa',
      FaseDiseno.edificio => 'Construcción · Edificio',
      FaseDiseno.puente => 'Construcción · Puente',
      FaseDiseno.pista => 'Construcción · Pista',
      FaseDiseno.vereda => 'Construcción · Vereda',
    };

/// Configuración del diseño de una obra (servicios pedidos + tipo elegido).
class DisenoObra {
  final bool topografico;
  final bool plano;
  final bool construccion;
  final FaseDiseno? tipoConstruccion; // null = aún no definido por el gerente

  const DisenoObra({
    required this.topografico,
    required this.plano,
    required this.construccion,
    this.tipoConstruccion,
  });

  /// REGLA: si pidió construcción y el sistema no pudo deducir el tipo,
  /// el gerente debe pasar por el panel de edición antes de ver el mapa.
  bool get requiereEdicion => construccion && tipoConstruccion == null;

  /// Paneles en orden real de ejecución: topográfico -> plano -> construcción.
  List<FaseDiseno> get fases => [
        if (topografico) FaseDiseno.topografico,
        if (plano) FaseDiseno.plano,
        if (construccion && tipoConstruccion != null) tipoConstruccion!,
      ];

  DisenoObra copyWith({
    bool? topografico,
    bool? plano,
    bool? construccion,
    FaseDiseno? tipoConstruccion,
    bool limpiarTipo = false,
  }) =>
      DisenoObra(
        topografico: topografico ?? this.topografico,
        plano: plano ?? this.plano,
        construccion: construccion ?? this.construccion,
        tipoConstruccion:
            limpiarTipo ? null : (tipoConstruccion ?? this.tipoConstruccion),
      );

  Map<String, dynamic> toJson() => {
        'topografico': topografico,
        'plano': plano,
        'construccion': construccion,
        'tipo': tipoConstruccion?.name,
      };

  factory DisenoObra.fromJson(Map<String, dynamic> j) => DisenoObra(
        topografico: j['topografico'] == true,
        plano: j['plano'] == true,
        construccion: j['construccion'] == true,
        tipoConstruccion: FaseDiseno.values
            .where((f) => f.name == j['tipo'])
            .cast<FaseDiseno?>()
            .firstWhere((_) => true, orElse: () => null),
      );
}

/// Quita tildes/eñes para que "topográfico" matchee con "topograf" —
/// imprescindible con datos reales escritos con acentos.
String _normalizar(String s) {
  const con = 'áéíóúüñÁÉÍÓÚÜÑ';
  const sin = 'aeiouunAEIOUUN';
  final sb = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = con.indexOf(ch);
    sb.write(i >= 0 ? sin[i] : ch);
  }
  return sb.toString();
}

/// Detección AUTOMÁTICA desde la BD: analiza `tipo_servicio` + nombre.
/// Ej.: "Puente Comas" -> construcción tipo puente; "solo planos" -> plano.
DisenoObra detectarDiseno(Obra o) {
  final texto = _normalizar('${o.tipo} ${o.nombre}');

  bool tiene(List<String> claves) => claves.any(texto.contains);

  final topo = tiene(['topograf', 'suelo', 'levantamiento']);
  final plano = tiene(['plano', 'autocad', 'arquitect', 'disen']);

  FaseDiseno? tipo;
  if (tiene(['puente'])) tipo = FaseDiseno.puente;
  if (tiene(['edificio', 'multifamiliar', 'torre'])) tipo = FaseDiseno.edificio;
  if (tiene(['casa', 'vivienda', 'residencial'])) tipo = FaseDiseno.casa;
  if (tiene(['pista', 'carretera', 'via ', 'asfalt'])) {
    tipo = FaseDiseno.pista;
  }
  if (tiene(['vereda', 'acera', 'sardinel'])) tipo = FaseDiseno.vereda;

  var construccion = tiene(['construc', 'ejecucion', 'obra']) || tipo != null;

  // Si no se detectó NINGÚN servicio, se asume construcción (el caso más
  // común) y el gerente definirá el tipo en edición.
  if (!topo && !plano && !construccion) construccion = true;

  return DisenoObra(
    topografico: topo,
    plano: plano,
    construccion: construccion,
    tipoConstruccion: tipo,
  );
}

const _cacheKey = 'diseno_obras';

/// Diseño efectivo de la obra: lo guardado por el gerente pisa lo detectado.
Future<DisenoObra> disenoDeObra(Obra o) async {
  final raw = LocalStore.cacheLeer(_cacheKey);
  if (raw is Map && raw['${o.id}'] is Map) {
    return DisenoObra.fromJson(Map<String, dynamic>.from(raw['${o.id}'] as Map));
  }
  return detectarDiseno(o);
}

/// Guarda la elección del gerente (memoria interna, por obra).
Future<void> guardarDisenoObra(int obraId, DisenoObra d) async {
  final raw = LocalStore.cacheLeer(_cacheKey);
  final mapa = raw is Map
      ? Map<String, dynamic>.from(raw)
      : <String, dynamic>{};
  mapa['$obraId'] = d.toJson();
  await LocalStore.cacheGuardar(_cacheKey, mapa);
}

/// Avance (0..1) de la fase [i] repartiendo el % GLOBAL de la obra entre las
/// N fases en orden: con 3 fases, 0-33% construye la 1.ª, 33-66% la 2.ª, etc.
double progresoFase(int i, int nFases, int pctGlobal) {
  if (nFases <= 0) return 0;
  return ((pctGlobal / 100) * nFases - i).clamp(0.0, 1.0);
}

/// Intensidad de trabajo por día (últimos [dias], de más antiguo a hoy),
/// normalizada 0..1 — alimenta las manchas de calor del gráfico. Sin texto:
/// el detalle de "qué se trabajó" se representa visualmente.
Future<List<double>> calorPorDia(int obraId, {int dias = 7}) async {
  final marcas = await asistenciasUltimosDias(dias);
  final hoy = DateTime.now();
  final conteos = List<int>.filled(dias, 0);
  for (final m in marcas) {
    if ((m['obra_id'] as num?)?.toInt() != obraId) continue;
    final f = DateTime.tryParse('${m['fecha']}');
    if (f == null) continue;
    final idx = dias - 1 - hoy.difference(f).inDays;
    if (idx >= 0 && idx < dias) conteos[idx]++;
  }
  final max = conteos.fold<int>(0, (a, b) => a > b ? a : b);
  return [for (final c in conteos) max > 0 ? c / max : 0.0];
}

/// Etiqueta corta del día para la franja gráfica (L, M, X...).
String inicialDia(int offsetDesdeHoy) {
  final d = DateTime.now().subtract(Duration(days: offsetDesdeHoy));
  const iniciales = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  return iniciales[d.weekday - 1];
}

/// Fecha corta del día N atrás (para tooltips de la franja de días).
String fechaDia(int offsetDesdeHoy) =>
    fechaCorta(DateTime.now().subtract(Duration(days: offsetDesdeHoy)));
