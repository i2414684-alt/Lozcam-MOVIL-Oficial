import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================================
///  MEMORIA INTERNA DEL DISPOSITIVO  (persiste entre reinicios de la app)
///
///  Sirve para que la app sea funcional como aplicación real AUNQUE todavía no
///  se hayan puesto las credenciales de Supabase. Guarda:
///    1. La base local de usuarios (modo sin nube).
///    2. La sesión iniciada (auto-login al volver a abrir la app).
///    3. Una caché genérica "por si acaso" para datos offline.
///
///  Cuando se configure Supabase en lib/core/config.dart, la autenticación pasa
///  automáticamente a la nube y esta memoria queda como respaldo de sesión.
/// ============================================================================
class LocalStore {
  static const _kUsers = 'lozcam_users';
  static const _kSession = 'lozcam_session';
  static const _kAreas = 'lozcam_areas';
  static const _kTareas = 'lozcam_tareas';
  static const _kAsignaciones = 'lozcam_asignaciones';
  static const _kInformes = 'lozcam_informes';
  static const _kCachePrefix = 'lozcam_cache_';

  static SharedPreferences? _p;
  static bool get _listo => _p != null;

  static Future<void> init() async {
    if (_listo) return;
    _p = await SharedPreferences.getInstance();
    if (_p!.getString(_kUsers) == null) {
      await _sembrarUsuarios();
    }
  }

  // --------------------------------------------------------------------------
  //  USUARIOS LOCALES  (modo memoria interna, sin nube)
  //  Roles iguales a los del web (profiles.rol). Contraseña: lozcam123.
  //    gerente@lozcam.pe    -> gerente_general     (delega a todos)
  //    residente@lozcam.pe  -> ingeniero_residente (delega en construcción)
  //    maestro@lozcam.pe    -> maestro_obra        (marca + delega a personal)
  //    personal@lozcam.pe   -> personal_obra       (marca asistencia)
  //    cliente@lozcam.pe    -> cliente             (externo)
  // --------------------------------------------------------------------------
  static Future<void> _sembrarUsuarios() async {
    final seed = <Map<String, dynamic>>[
      {
        'id': 'local-gerente',
        'email': 'gerente@lozcam.pe',
        'password': 'lozcam123',
        'nombre': 'Carlos Lozcam',
        'rol': 'gerente_general',
      },
      {
        'id': 'local-residente',
        'email': 'residente@lozcam.pe',
        'password': 'lozcam123',
        'nombre': 'Ana Quispe Flores',
        'rol': 'ingeniero_residente',
      },
      {
        'id': 'local-maestro',
        'email': 'maestro@lozcam.pe',
        'password': 'lozcam123',
        'nombre': 'Pedro Vega Huari',
        'rol': 'maestro_obra',
      },
      {
        'id': 'local-personal',
        'email': 'personal@lozcam.pe',
        'password': 'lozcam123',
        'nombre': 'Marco Torres Ríos',
        'rol': 'personal_obra',
      },
      {
        'id': 'local-cliente',
        'email': 'cliente@lozcam.pe',
        'password': 'lozcam123',
        'nombre': 'Constructora Méndez S.A.',
        'rol': 'cliente',
      },
    ];
    await _p!.setString(_kUsers, jsonEncode(seed));
  }

  static List<Map<String, dynamic>> usuarios() {
    final raw = _p?.getString(_kUsers);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Valida credenciales contra la base local. Devuelve el usuario o null.
  static Map<String, dynamic>? validar(String email, String password) {
    final mail = email.trim().toLowerCase();
    for (final u in usuarios()) {
      if ((u['email'] as String).toLowerCase() == mail &&
          u['password'] == password) {
        return u;
      }
    }
    return null;
  }

  /// Registra o actualiza un usuario local (para crecer la base sin nube).
  static Future<void> guardarUsuario(Map<String, dynamic> usuario) async {
    final lista = usuarios();
    final mail = (usuario['email'] as String).toLowerCase();
    lista.removeWhere((u) => (u['email'] as String).toLowerCase() == mail);
    lista.add(usuario);
    await _p!.setString(_kUsers, jsonEncode(lista));
  }

  // --------------------------------------------------------------------------
  //  SESIÓN ACTUAL
  // --------------------------------------------------------------------------
  static Future<void> guardarSesion(Map<String, dynamic> sesion) async {
    await _p?.setString(_kSession, jsonEncode(sesion));
  }

  static Map<String, dynamic>? leerSesion() {
    final raw = _p?.getString(_kSession);
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  static Future<void> limpiarSesion() async {
    await _p?.remove(_kSession);
  }

  // --------------------------------------------------------------------------
  //  ÁREAS DE TRABAJO  (las define el gerente por geolocalización)
  //  Cada área: { id, nombre, lat, lng, radio, direccion }
  // --------------------------------------------------------------------------
  static List<Map<String, dynamic>> areas() {
    final raw = _p?.getString(_kAreas);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> guardarArea(Map<String, dynamic> area) async {
    final lista = areas();
    lista.removeWhere((a) => a['id'] == area['id']);
    lista.add(area);
    await _p?.setString(_kAreas, jsonEncode(lista));
  }

  static Future<void> eliminarArea(int id) async {
    final lista = areas()..removeWhere((a) => a['id'] == id);
    await _p?.setString(_kAreas, jsonEncode(lista));
  }

  // --------------------------------------------------------------------------
  //  TAREAS DELEGADAS  (gerencia/jefaturas delegan; cada rol ve las suyas)
  //  Cada tarea: { id, titulo, descripcion, rol_destino, prioridad, estado,
  //               asignado_por_id, asignado_por_nombre, asignado_por_rol,
  //               fecha_entrega, creado_el }
  // --------------------------------------------------------------------------
  static List<Map<String, dynamic>> tareas() {
    final raw = _p?.getString(_kTareas);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> guardarTarea(Map<String, dynamic> tarea) async {
    final lista = tareas();
    lista.removeWhere((t) => t['id'] == tarea['id']);
    lista.add(tarea);
    await _p?.setString(_kTareas, jsonEncode(lista));
  }

  static Future<void> eliminarTarea(int id) async {
    final lista = tareas()..removeWhere((t) => t['id'] == id);
    await _p?.setString(_kTareas, jsonEncode(lista));
  }

  // --------------------------------------------------------------------------
  //  ASIGNACIONES  (qué trabajador trabaja en qué área)
  //  Cada registro: { perfil_id, perfil_nombre, rol, area_id, area_nombre }
  // --------------------------------------------------------------------------
  static List<Map<String, dynamic>> asignaciones() {
    final raw = _p?.getString(_kAsignaciones);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> guardarAsignacion(Map<String, dynamic> a) async {
    final lista = asignaciones();
    lista.removeWhere(
        (x) => x['perfil_id'] == a['perfil_id'] && x['area_id'] == a['area_id']);
    lista.add(a);
    await _p?.setString(_kAsignaciones, jsonEncode(lista));
  }

  static Future<void> quitarAsignacion(String perfilId, int areaId) async {
    final lista = asignaciones()
      ..removeWhere((x) => x['perfil_id'] == perfilId && x['area_id'] == areaId);
    await _p?.setString(_kAsignaciones, jsonEncode(lista));
  }

  // --------------------------------------------------------------------------
  //  INFORMES DE AVANCE  (partes que escribe el trabajador, offline)
  //  Cada uno: { id, perfil_id, perfil_nombre, obra_id, obra_nombre, texto,
  //             pct, fecha }
  // --------------------------------------------------------------------------
  static List<Map<String, dynamic>> informes() {
    final raw = _p?.getString(_kInformes);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> guardarInforme(Map<String, dynamic> informe) async {
    final lista = informes();
    lista.removeWhere((i) => i['id'] == informe['id']);
    lista.add(informe);
    await _p?.setString(_kInformes, jsonEncode(lista));
  }

  static Future<void> eliminarInforme(int id) async {
    final lista = informes()..removeWhere((i) => i['id'] == id);
    await _p?.setString(_kInformes, jsonEncode(lista));
  }

  // --------------------------------------------------------------------------
  //  TUTORIAL DE BIENVENIDA  (se muestra una sola vez, por panel/rol)
  // --------------------------------------------------------------------------
  static bool tutorialVisto(String clave) =>
      _p?.getBool('lozcam_tutorial_$clave') ?? false;

  static Future<void> marcarTutorialVisto(String clave) async {
    await _p?.setBool('lozcam_tutorial_$clave', true);
  }

  // --------------------------------------------------------------------------
  //  TEMA  (modo claro / oscuro / sistema — preferencia visual del usuario)
  //  Guarda solo una etiqueta: 'light' | 'dark' | 'system'. No toca la BD.
  // --------------------------------------------------------------------------
  static String temaModo() => _p?.getString('lozcam_tema') ?? 'system';

  static Future<void> guardarTemaModo(String modo) async {
    await _p?.setString('lozcam_tema', modo);
  }

  // --------------------------------------------------------------------------
  //  CACHÉ GENÉRICA  (por si acaso: guardar datos para uso offline)
  // --------------------------------------------------------------------------
  static Future<void> cacheGuardar(String clave, Object valor) async {
    await _p?.setString(_kCachePrefix + clave, jsonEncode(valor));
  }

  static dynamic cacheLeer(String clave) {
    final raw = _p?.getString(_kCachePrefix + clave);
    if (raw == null) return null;
    return jsonDecode(raw);
  }
}
