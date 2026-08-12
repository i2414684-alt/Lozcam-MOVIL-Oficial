import '../core/asistencia_service.dart';
import '../models/models.dart';
import 'asignaciones_repository.dart';
import 'avance_repository.dart';
import 'obras_repository.dart';
import 'personas_repository.dart';
import 'reporte_datos.dart' show fechaCorta, horaCorta;
import 'tareas_repository.dart';

/// ============================================================================
///  ACTIVIDAD POR ÁREA — motor del "mapa de calor"
///
///  Combina, SOLO EN LECTURA, lo que ya existe en la BD:
///   - `asistencias` de hoy  -> quiénes están trabajando ahora en cada área
///   - `asignaciones`        -> quiénes están delegados a cada área
///   - tareas (memoria)      -> carga de trabajo abierta por área
///   - `avance_obra`         -> último % reportado
///  Con eso calcula una INTENSIDAD 0..1 por área (más marcas hoy + más tareas
///  en curso = más caliente). "Tiempo real" = recarga periódica / pull.
/// ============================================================================

class ActividadArea {
  final Obra obra;
  final int asignados;
  final List<String> delegados; // nombres asignados al área
  final List<String> presentes; // nombres con marca HOY en el área
  final int tareasAbiertas;
  final int tareasEnProgreso;
  final int? avancePct; // último % reportado (null = sin reporte)
  final String ultimaMarca; // HH:mm de la última entrada de hoy, o '-'
  final double intensidad; // 0..1 relativo al área más activa

  const ActividadArea({
    required this.obra,
    required this.asignados,
    required this.delegados,
    required this.presentes,
    required this.tareasAbiertas,
    required this.tareasEnProgreso,
    required this.avancePct,
    required this.ultimaMarca,
    required this.intensidad,
  });

  bool get coordsValidas =>
      !(obra.lat.abs() < 0.0001 && obra.lng.abs() < 0.0001) &&
      obra.lat >= -90 &&
      obra.lat <= 90 &&
      obra.lng >= -180 &&
      obra.lng <= 180;

  String get nivelCalor =>
      intensidad >= 0.66 ? 'Alta' : (intensidad >= 0.33 ? 'Media' : 'Baja');
}

/// Carga la actividad de TODAS las áreas/obras. [soloObras] filtra por ids.
Future<List<ActividadArea>> cargarActividadAreas({List<int>? soloObras}) async {
  var obras = await cargarObras();
  if (soloObras != null) {
    obras = obras.where((o) => soloObras.contains(o.id)).toList();
  }
  // Las cuatro consultas independientes salen en paralelo, no en cadena: en
  // obra la latencia es alta y encadenarlas multiplicaba la espera.
  final resultados = await Future.wait([
    asignacionesDetalle(), // {obra_id, perfil_id}
    todoElPersonal(),
    asistenciasUltimosDias(1), // hoy, con horas
    // UNA consulta para el avance de todas las obras (antes era una por obra).
    ultimoAvancePorObra(obras.map((o) => o.id).toList()),
  ]);
  final detalle = resultados[0] as List<Map<String, dynamic>>;
  final personal = resultados[1] as List<Persona>;
  final marcasHoy = resultados[2] as List<Map<String, dynamic>>;
  final avancePorObra = resultados[3] as Map<int, int>;
  final tareas = todasLasTareas();

  final hoy = fechaCorta(DateTime.now());
  final nombrePorId = {for (final p in personal) p.id: p.nombre};

  // Puntaje crudo por área; luego se normaliza contra el máximo.
  final crudos = <double>[];
  final parciales = <ActividadArea>[];

  for (var i = 0; i < obras.length; i++) {
    final o = obras[i];

    final delegados = detalle
        .where((a) => (a['obra_id'] as num?)?.toInt() == o.id)
        .map((a) => nombrePorId['${a['perfil_id']}'] ?? '')
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();

    final marcas = marcasHoy
        .where((m) =>
            (m['obra_id'] as num?)?.toInt() == o.id && '${m['fecha']}' == hoy)
        .toList();
    final presentes = marcas
        .map((m) => nombrePorId['${m['perfil_id']}'] ?? '')
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    String ultima = '-';
    for (final m in marcas) {
      final h = horaCorta(m['hora_entrada']);
      if (h != '-' && (ultima == '-' || h.compareTo(ultima) > 0)) ultima = h;
    }

    final deObra = tareas.where((t) => t.obraId == o.id).toList();
    final abiertas = deObra.where((t) => t.estado != 'completada').length;
    final enProgreso = deObra.where((t) => t.estado == 'en_progreso').length;

    final puntaje = presentes.length * 3.0 +
        enProgreso * 2.0 +
        (abiertas - enProgreso) * 1.0 +
        (ultima != '-' ? 1.0 : 0.0);
    crudos.add(puntaje);

    parciales.add(ActividadArea(
      obra: o,
      asignados: delegados.length,
      delegados: delegados,
      presentes: presentes,
      tareasAbiertas: abiertas,
      tareasEnProgreso: enProgreso,
      avancePct: avancePorObra[o.id],
      ultimaMarca: ultima,
      intensidad: 0, // se rellena abajo, normalizada
    ));
  }

  final max = crudos.fold<double>(0, (a, b) => a > b ? a : b);
  return [
    for (var i = 0; i < parciales.length; i++)
      ActividadArea(
        obra: parciales[i].obra,
        asignados: parciales[i].asignados,
        delegados: parciales[i].delegados,
        presentes: parciales[i].presentes,
        tareasAbiertas: parciales[i].tareasAbiertas,
        tareasEnProgreso: parciales[i].tareasEnProgreso,
        avancePct: parciales[i].avancePct,
        ultimaMarca: parciales[i].ultimaMarca,
        intensidad: max > 0 ? (crudos[i] / max) : 0,
      ),
  ];
}
