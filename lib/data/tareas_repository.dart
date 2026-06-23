import '../core/auth_service.dart';
import '../core/local_store.dart';
import 'avance_repository.dart';
import 'enums.dart';
import 'roles.dart';

/// Tarea delegada de un rol superior a un rol inferior de la jerarquía.
/// Puede dirigirse a TODO un rol (asignadoAId == null) o a una PERSONA concreta.
class TareaAsignada {
  final int id;
  final String titulo;
  final String descripcion;
  final String rolDestino; // clave del rol al que se delega
  final String? asignadoAId; // persona concreta (null = cualquiera del rol)
  final String? asignadoANombre;
  final String prioridad; // baja | media | alta | critica
  final String estado; // pendiente | en_progreso | completada | bloqueada
  final String asignadoPorId;
  final String asignadoPorNombre;
  final String asignadoPorRol;
  final String? fechaEntrega; // ISO yyyy-MM-dd
  final String creadoEl;
  final int? obraId; // obra a la que aporta avance al cumplirse
  final String obraNombre;
  final int avancePct; // % que aporta a la obra al completarse

  TareaAsignada({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.rolDestino,
    this.asignadoAId,
    this.asignadoANombre,
    required this.prioridad,
    required this.estado,
    required this.asignadoPorId,
    required this.asignadoPorNombre,
    required this.asignadoPorRol,
    this.fechaEntrega,
    required this.creadoEl,
    this.obraId,
    this.obraNombre = '',
    this.avancePct = 0,
  });

  String get rolDestinoNombre => rolPorClave(rolDestino)?.nombre ?? rolDestino;

  /// Texto del destinatario: persona si la hay, si no todo el rol.
  String get destinoTexto =>
      asignadoANombre ?? 'Todos · $rolDestinoNombre';

  TareaAsignada copyWith({String? estado}) => TareaAsignada(
        id: id,
        titulo: titulo,
        descripcion: descripcion,
        rolDestino: rolDestino,
        asignadoAId: asignadoAId,
        asignadoANombre: asignadoANombre,
        prioridad: prioridad,
        estado: estado ?? this.estado,
        asignadoPorId: asignadoPorId,
        asignadoPorNombre: asignadoPorNombre,
        asignadoPorRol: asignadoPorRol,
        fechaEntrega: fechaEntrega,
        creadoEl: creadoEl,
        obraId: obraId,
        obraNombre: obraNombre,
        avancePct: avancePct,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'descripcion': descripcion,
        'rol_destino': rolDestino,
        'asignado_a_id': asignadoAId,
        'asignado_a_nombre': asignadoANombre,
        'prioridad': prioridad,
        'estado': estado,
        'asignado_por_id': asignadoPorId,
        'asignado_por_nombre': asignadoPorNombre,
        'asignado_por_rol': asignadoPorRol,
        'fecha_entrega': fechaEntrega,
        'creado_el': creadoEl,
        'obra_id': obraId,
        'obra_nombre': obraNombre,
        'avance_pct': avancePct,
      };

  factory TareaAsignada.fromJson(Map<String, dynamic> j) => TareaAsignada(
        id: (j['id'] as num).toInt(),
        titulo: (j['titulo'] ?? '') as String,
        descripcion: (j['descripcion'] ?? '') as String,
        rolDestino: (j['rol_destino'] ?? '') as String,
        asignadoAId: j['asignado_a_id'] as String?,
        asignadoANombre: j['asignado_a_nombre'] as String?,
        prioridad: (j['prioridad'] ?? 'media') as String,
        estado: (j['estado'] ?? 'pendiente') as String,
        asignadoPorId: (j['asignado_por_id'] ?? '') as String,
        asignadoPorNombre: (j['asignado_por_nombre'] ?? '') as String,
        asignadoPorRol: (j['asignado_por_rol'] ?? '') as String,
        fechaEntrega: j['fecha_entrega'] as String?,
        creadoEl: (j['creado_el'] ?? '') as String,
        obraId: (j['obra_id'] as num?)?.toInt(),
        obraNombre: (j['obra_nombre'] ?? '') as String,
        avancePct: (j['avance_pct'] as num?)?.toInt() ?? 0,
      );
}

List<TareaAsignada> _todas() =>
    LocalStore.tareas().map(TareaAsignada.fromJson).toList()
      ..sort((a, b) => b.creadoEl.compareTo(a.creadoEl));

/// Todas las tareas (para gerencia que monitorea todo).
List<TareaAsignada> todasLasTareas() => _todas();

/// Tareas que ve una persona: las dirigidas a su rol y, o bien a todo el rol,
/// o bien a ella en concreto.
List<TareaAsignada> tareasParaPersona(String rol, String perfilId) =>
    _todas()
        .where((t) =>
            t.rolDestino == rol &&
            (t.asignadoAId == null || t.asignadoAId == perfilId))
        .toList();

/// Tareas que creó/delegó una persona.
List<TareaAsignada> tareasCreadasPor(String perfilId) =>
    _todas().where((t) => t.asignadoPorId == perfilId).toList();

/// Crea y delega una tarea. El "asignado por" es el usuario en sesión.
Future<void> delegarTarea({
  required String titulo,
  required String descripcion,
  required String rolDestino,
  required String prioridad,
  String? asignadoAId,
  String? asignadoANombre,
  String? fechaEntrega,
  int? obraId,
  String obraNombre = '',
  int avancePct = 0,
}) async {
  final yo = AuthService.instance.session;
  final t = TareaAsignada(
    id: DateTime.now().millisecondsSinceEpoch,
    titulo: titulo,
    descripcion: descripcion,
    rolDestino: rolDestino,
    asignadoAId: asignadoAId,
    asignadoANombre: asignadoANombre,
    prioridad: prioridad,
    estado: 'pendiente',
    asignadoPorId: yo?.id ?? 'local',
    asignadoPorNombre: yo?.nombre ?? 'Gerencia',
    asignadoPorRol: yo?.rol ?? '',
    fechaEntrega: fechaEntrega,
    creadoEl: DateTime.now().toIso8601String(),
    obraId: obraId,
    obraNombre: obraNombre,
    avancePct: avancePct,
  );
  await LocalStore.guardarTarea(t.toJson());
}

Future<void> actualizarEstadoTarea(TareaAsignada t, String estado) async {
  await LocalStore.guardarTarea(t.copyWith(estado: estado).toJson());
}

/// Completa una tarea: registra el % de avance en la obra (si tiene obra) y
/// BORRA la tarea (efímera, para no sobrecargar). El avance va a `avance_obra`
/// cuando la escritura esté habilitada; si no, queda como avance local.
Future<void> completarTarea(TareaAsignada t) async {
  if (t.obraId != null && t.avancePct > 0) {
    await registrarAvanceObra(
      obraId: t.obraId!,
      obraNombre: t.obraNombre,
      porcentaje: t.avancePct,
      descripcion: 'Tarea cumplida: ${t.titulo}',
    );
  }
  await eliminarTarea(t.id);
}

Future<void> eliminarTarea(int id) => LocalStore.eliminarTarea(id);

// ---- Etiquetas / tonos (valores y textos vienen de la fuente única `enums.dart`) ----
List<String> get prioridadesTarea => prioridades.keys.toList();

String prioridadLabel(String p) => labelPrioridad(p);

String prioridadTone(String p) {
  switch (p) {
    case 'baja':
      return 'green';
    case 'alta':
      return 'amber';
    case 'critica':
      return 'red';
    default:
      return 'blue';
  }
}

String estadoTareaLabel(String e) => labelEstadoTarea(e);

String estadoTareaTone(String e) {
  switch (e) {
    case 'en_progreso':
      return 'blue';
    case 'completada':
      return 'green';
    case 'bloqueada':
      return 'red';
    default:
      return 'gray';
  }
}
