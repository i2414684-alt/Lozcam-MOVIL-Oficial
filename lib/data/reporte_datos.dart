import '../core/asistencia_service.dart';
import 'asignaciones_repository.dart';
import 'avance_repository.dart';
import 'obras_repository.dart';
import 'personas_repository.dart';
import 'roles.dart';
import 'tareas_repository.dart';
import '../models/models.dart';

/// ============================================================================
///  DATOS COMPARTIDOS DE LOS REPORTES (Excel y PDF)
///
///  Una sola recolección (SOLO LECTURA, sin tocar la BD) para que ambos
///  formatos muestren EXACTAMENTE las mismas cifras que el chat de gerencia.
/// ============================================================================

/// Formatos de descarga del reporte.
enum FormatoReporte { excel, pdf }

String formatoLabel(FormatoReporte f) => switch (f) {
      FormatoReporte.excel => 'Excel (.xlsx)',
      FormatoReporte.pdf => 'PDF (.pdf)',
    };

String extensionDe(FormatoReporte f) => switch (f) {
      FormatoReporte.excel => 'xlsx',
      FormatoReporte.pdf => 'pdf',
    };

/// Plantillas de estilo del reporte (el gerente elige en la UI).
enum PlantillaReporte { naranja, minimal, oscuro, azul, verde }

/// Etiqueta legible de cada plantilla (para el selector en la UI).
String plantillaLabel(PlantillaReporte p) => switch (p) {
      PlantillaReporte.naranja => 'Naranja Lozcam',
      PlantillaReporte.minimal => 'Minimal B/N',
      PlantillaReporte.oscuro => 'Ejecutivo oscuro',
      PlantillaReporte.azul => 'Corporativo azul',
      PlantillaReporte.verde => 'Obra verde',
    };

/// Descripción corta de cada plantilla (para el selector en la UI).
String plantillaDescripcion(PlantillaReporte p) => switch (p) {
      PlantillaReporte.naranja => 'Identidad Lozcam: cabeceras naranja',
      PlantillaReporte.minimal => 'Sobrio en blanco y negro',
      PlantillaReporte.oscuro => 'Fondo carbón con acento naranja',
      PlantillaReporte.azul => 'Formal, azul corporativo',
      PlantillaReporte.verde => 'Verde construcción / seguridad',
    };

/// Paleta de una plantilla en ARGB (int) - cada formato la convierte a su tipo.
class PaletaReporte {
  final int titulo; // banda del título
  final int tituloTexto;
  final int cabecera; // fila de cabeceras de tabla
  final int cabeceraTexto;
  final int zebra; // franja alterna de filas
  final int acento; // texto de énfasis (totales, presentes)
  final int peligro; // faltas / ausencias
  const PaletaReporte({
    required this.titulo,
    required this.tituloTexto,
    required this.cabecera,
    required this.cabeceraTexto,
    required this.zebra,
    required this.acento,
    required this.peligro,
  });
}

PaletaReporte paletaDe(PlantillaReporte p) => switch (p) {
      PlantillaReporte.naranja => const PaletaReporte(
          titulo: 0xFFFF6D00,
          tituloTexto: 0xFFFFFFFF,
          cabecera: 0xFFFF6D00,
          cabeceraTexto: 0xFFFFFFFF,
          zebra: 0xFFFFF3E9,
          acento: 0xFFC24E00,
          peligro: 0xFFC5221F,
        ),
      PlantillaReporte.minimal => const PaletaReporte(
          titulo: 0xFF3A3A3A,
          tituloTexto: 0xFFFFFFFF,
          cabecera: 0xFF3A3A3A,
          cabeceraTexto: 0xFFFFFFFF,
          zebra: 0xFFF2F2F2,
          acento: 0xFF3A3A3A,
          peligro: 0xFFC5221F,
        ),
      PlantillaReporte.oscuro => const PaletaReporte(
          titulo: 0xFF141414,
          tituloTexto: 0xFFFF8320,
          cabecera: 0xFF141414,
          cabeceraTexto: 0xFFFF8320,
          zebra: 0xFFEDEDED,
          acento: 0xFF8F3A00,
          peligro: 0xFFC5221F,
        ),
      PlantillaReporte.azul => const PaletaReporte(
          titulo: 0xFF1A56B0,
          tituloTexto: 0xFFFFFFFF,
          cabecera: 0xFF1A56B0,
          cabeceraTexto: 0xFFFFFFFF,
          zebra: 0xFFE8F0FE,
          acento: 0xFF123C7C,
          peligro: 0xFFC5221F,
        ),
      PlantillaReporte.verde => const PaletaReporte(
          titulo: 0xFF1D6E48,
          tituloTexto: 0xFFFFFFFF,
          cabecera: 0xFF1D6E48,
          cabeceraTexto: 0xFFFFFFFF,
          zebra: 0xFFE8F8EF,
          acento: 0xFF14562F,
          peligro: 0xFFC5221F,
        ),
    };

/// Fila detallada de asistencia lista para pintar en el reporte.
class FilaAsistencia {
  final String fecha; // yyyy-MM-dd
  final String nombre;
  final String rol; // nombre legible del rol
  final String obra;
  final String entrada; // HH:mm o '-'
  final String salida; // HH:mm o '-'
  const FilaAsistencia(this.fecha, this.nombre, this.rol, this.obra,
      this.entrada, this.salida);
}

/// Persona ausente hoy, con su(s) obra(s) asignada(s).
class FilaFalta {
  final String nombre;
  final String rol;
  final String obras; // nombres separados por coma o '-'
  const FilaFalta(this.nombre, this.rol, this.obras);
}

/// Todos los datos que consumen los reportes (Excel y PDF).
class DatosReporte {
  final DateTime generado; // fecha y hora de generación
  final List<Persona> personal;
  final List<Persona> clientes;
  final List<Obra> obras;
  final List<TareaAsignada> tareas;
  final Set<String> presentesHoy; // perfil_id
  final List<FilaAsistencia> asistenciaHoy; // todo el personal, con horas
  final List<FilaFalta> faltasHoy;
  final List<FilaAsistencia> historial; // últimos 7 días, con día y hora
  final Map<int, int> asignadosPorObra; // obraId -> asignados
  final Map<int, int> presentesPorObra; // obraId -> presentes hoy
  final Map<int, int?> avancePorObra; // obraId -> último % (null sin reporte)

  const DatosReporte({
    required this.generado,
    required this.personal,
    required this.clientes,
    required this.obras,
    required this.tareas,
    required this.presentesHoy,
    required this.asistenciaHoy,
    required this.faltasHoy,
    required this.historial,
    required this.asignadosPorObra,
    required this.presentesPorObra,
    required this.avancePorObra,
  });

  int get tareasAbiertas =>
      tareas.where((t) => t.estado != 'completada').length;
  int get faltaronHoy => faltasHoy.length;
  int get pctAsistencia => personal.isEmpty
      ? 0
      : ((presentesHoy.length * 100) / personal.length).round();
}

/// Días de historial que incluyen los reportes.
const int diasHistorialReporte = 7;

/// Recolecta TODO lo que necesitan los reportes en una pasada (solo lectura).
Future<DatosReporte> cargarDatosReporte() async {
  final ahora = DateTime.now();
  final hoy = fechaCorta(ahora);

  final obras = await cargarObras();
  final detalle = await asignacionesDetalle(); // {obra_id, perfil_id}
  final personal = await todoElPersonal();
  final clientes = await personasPorRol('cliente');
  final tareas = todasLasTareas();
  final historialRaw = await asistenciasUltimosDias(diasHistorialReporte);
  final avancesPorObra =
      await Future.wait(obras.map((o) => avancesDeObra(o.id)));

  final nombreObra = {for (final o in obras) o.id: o.nombre};
  final personaPorId = {for (final p in personal) p.id: p};

  String nombreDeObra(dynamic id) {
    final oid = (id as num?)?.toInt();
    return (oid != null ? nombreObra[oid] : null) ?? 'Obra $id';
  }

  // Asistencia de HOY con horas (subconjunto del historial).
  final hoyRows =
      historialRaw.where((r) => '${r['fecha']}' == hoy).toList();
  final presentes = hoyRows.map((r) => '${r['perfil_id']}').toSet();

  // Obra(s) asignada(s) por persona (para saber dónde debía estar quien faltó).
  final obrasDePersona = <String, List<String>>{};
  for (final a in detalle) {
    obrasDePersona
        .putIfAbsent('${a['perfil_id']}', () => [])
        .add(nombreDeObra(a['obra_id']));
  }

  String rolLegible(Persona p) => rolPorClave(p.rol)?.nombre ?? p.rol;

  // Fila por cada persona del personal: presente (con horas) o ausente.
  final asistenciaHoy = <FilaAsistencia>[];
  final faltasHoy = <FilaFalta>[];
  for (final p in personal) {
    final marca = hoyRows
        .where((r) => '${r['perfil_id']}' == p.id)
        .toList();
    if (marca.isNotEmpty) {
      final m = marca.first;
      asistenciaHoy.add(FilaAsistencia(
        hoy,
        p.nombre,
        rolLegible(p),
        nombreDeObra(m['obra_id']),
        horaCorta(m['hora_entrada']),
        horaCorta(m['hora_salida']),
      ));
    } else {
      final asignadas = obrasDePersona[p.id]?.join(', ') ?? '-';
      asistenciaHoy.add(FilaAsistencia(
          hoy, p.nombre, rolLegible(p), asignadas, '-', '-'));
      faltasHoy.add(FilaFalta(p.nombre, rolLegible(p), asignadas));
    }
  }

  // Historial detallado (día + horas) de los últimos N días, solo personal.
  final historial = <FilaAsistencia>[];
  for (final r in historialRaw) {
    final p = personaPorId['${r['perfil_id']}'];
    if (p == null) continue; // ignora ids que no son del personal actual
    historial.add(FilaAsistencia(
      '${r['fecha']}',
      p.nombre,
      rolLegible(p),
      nombreDeObra(r['obra_id']),
      horaCorta(r['hora_entrada']),
      horaCorta(r['hora_salida']),
    ));
  }

  // Conteos por obra.
  final asignadosPorObra = <int, int>{};
  final presentesPorObra = <int, int>{};
  final avancePorObraMap = <int, int?>{};
  for (var i = 0; i < obras.length; i++) {
    final o = obras[i];
    final asignados = detalle
        .where((x) => (x['obra_id'] as num?)?.toInt() == o.id)
        .map((x) => '${x['perfil_id']}')
        .toSet();
    asignadosPorObra[o.id] = asignados.length;
    presentesPorObra[o.id] =
        asignados.where((id) => presentes.contains(id)).length;
    final av = avancesPorObra[i];
    avancePorObraMap[o.id] = av.isNotEmpty ? av.first.pct : null;
  }

  return DatosReporte(
    generado: ahora,
    personal: personal,
    clientes: clientes,
    obras: obras,
    tareas: tareas,
    presentesHoy: presentes,
    asistenciaHoy: asistenciaHoy,
    faltasHoy: faltasHoy,
    historial: historial,
    asignadosPorObra: asignadosPorObra,
    presentesPorObra: presentesPorObra,
    avancePorObra: avancePorObraMap,
  );
}

/// Nombre de archivo sugerido para el reporte, con fecha y extensión.
String nombreArchivoReporte({String ext = 'xlsx'}) =>
    'reporte_lozcam_${fechaCorta(DateTime.now())}.$ext';

/// yyyy-MM-dd
String fechaCorta(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// dd/MM/yyyy HH:mm (fecha y hora de generación, legible).
String fechaHoraLegible(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/'
    '${d.year} ${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';

/// Normaliza una hora de la BD ("07:58:23") o un ISO local
/// ("2026-07-04T07:58:23.000") a HH:mm. Null/vacío -> '-'.
String horaCorta(dynamic v) {
  final s = '${v ?? ''}'.trim();
  if (s.isEmpty || s == 'null') return '-';
  final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(s.contains('T')
      ? s.split('T').last
      : s);
  if (m == null) return '-';
  return '${m.group(1)!.padLeft(2, '0')}:${m.group(2)}';
}
