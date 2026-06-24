import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/roles.dart';
import 'local_store.dart';
import 'supabase_client.dart';

/// Área funcional de la app a la que pertenece un rol.
enum AppArea { gerencia, operativo, cliente }

/// Error de inicio de sesión legible para mostrar al usuario.
/// (No se llama "AuthException" para no chocar con la de supabase_flutter.)
class LoginError implements Exception {
  final String mensaje;
  LoginError(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Usuario con sesión iniciada. Es la fuente de verdad de "quién soy".
class SessionUser {
  final String id;
  final String email;
  final String nombre;
  final String rol; // clave del rol == profiles.rol
  final int? clienteId; // profiles.cliente_id (para el rol cliente)

  const SessionUser({
    required this.id,
    required this.email,
    required this.nombre,
    required this.rol,
    this.clienteId,
  });

  RolConfig? get config => rolPorClave(rol);
  String get rolNombre => config?.nombre ?? _rolNombreFallback(rol);
  int get nivel => config?.nivel ?? _nivelFallback(rol);
  String get colorKey => config?.color ?? 'blue';

  String get primerNombre {
    final p = nombre.trim().split(RegExp(r'\s+'));
    return p.isEmpty ? nombre : p.first;
  }

  String get iniciales {
    final p = nombre.trim().split(RegExp(r'\s+'));
    if (p.isEmpty || p.first.isEmpty) return '?';
    if (p.length == 1) return p.first.substring(0, 1).toUpperCase();
    return (p[0].substring(0, 1) + p[1].substring(0, 1)).toUpperCase();
  }

  AppArea get area => areaDeRol(rol);

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'nombre': nombre,
        'rol': rol,
        'cliente_id': clienteId,
      };

  factory SessionUser.fromJson(Map<String, dynamic> j) => SessionUser(
        id: j['id'] as String,
        email: (j['email'] ?? '') as String,
        nombre: (j['nombre'] ?? 'Usuario') as String,
        rol: (j['rol'] ?? 'operario') as String,
        clienteId: (j['cliente_id'] as num?)?.toInt(),
      );
}

// Fallbacks solo para un `rol` desconocido (no presente en la jerarquía).
String _rolNombreFallback(String rol) {
  switch (rol) {
    case 'gerente_general':
      return 'Gerente General';
    case 'administrador':
      return 'Administrador';
    case 'subgerente':
      return 'Subgerente';
    case 'cliente':
      return 'Cliente';
    default:
      return rol;
  }
}

int _nivelFallback(String rol) {
  switch (rol) {
    case 'gerente_general':
      return 1;
    case 'subgerente':
    case 'administrador':
      return 2;
    case 'cliente':
      return 9;
    default:
      return 4; // operativo por defecto
  }
}

/// Área (panel) a la que pertenece un rol: gerencia, operativo o cliente.
AppArea areaDeRol(String rol) {
  final n = rolPorClave(rol)?.nivel ?? _nivelFallback(rol);
  if (n <= 2) return AppArea.gerencia;
  if (n == 9) return AppArea.cliente;
  return AppArea.operativo;
}

/// Nombre del panel para mostrar al usuario.
String etiquetaArea(AppArea a) {
  switch (a) {
    case AppArea.gerencia:
      return 'Gerencia';
    case AppArea.cliente:
      return 'Cliente';
    case AppArea.operativo:
      return 'Trabajador';
  }
}

/// ============================================================================
///  SERVICIO DE AUTENTICACIÓN
///
///  - Si Supabase está configurado y listo -> autentica contra la NUBE
///    (supabase.auth) y lee el rol desde la tabla `profiles`.
///  - Si no -> autentica contra la MEMORIA INTERNA del dispositivo.
///  En ambos casos la sesión se persiste localmente para el auto-login.
/// ============================================================================
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  /// Usuario actual (null = sin sesión). Lo leen las pantallas.
  SessionUser? session;

  /// ¿La app está trabajando contra la nube (Supabase listo)?
  bool get modoNube => supabaseListo;

  /// Restaura la sesión al abrir la app (auto-login).
  Future<SessionUser?> restaurarSesion() async {
    // Nube: auto-login SOLO si hay sesión viva de Supabase.
    if (supabaseListo) {
      final s = supabase.auth.currentSession;
      if (s != null) {
        try {
          final u = await _perfilDesdeSupabase(s.user.id, s.user.email ?? '');
          if (u != null) {
            session = u;
            await LocalStore.guardarSesion(u.toJson());
            return u;
          }
        } catch (_) {
          // Usuario inactivo o error de perfil -> no hay auto-login.
        }
      }
      return null; // en nube sin sesión viva -> ir al login (no usar la local)
    }
    // Memoria interna (offline): sesión guardada en el dispositivo.
    final json = LocalStore.leerSesion();
    if (json != null) {
      session = SessionUser.fromJson(json);
      return session;
    }
    return null;
  }

  /// Inicia sesión con correo y contraseña.
  /// Si se indica [panel], el rol del usuario DEBE corresponder a ese panel;
  /// si no, se rechaza el ingreso (no se crea sesión) con "usuario inválido".
  Future<SessionUser> ingresar(String email, String password,
      {AppArea? panel}) async {
    final mail = email.trim();
    if (mail.isEmpty || password.isEmpty) {
      throw LoginError('Ingresa tu correo y tu contraseña.');
    }
    final u =
        supabaseListo ? await _ingresarNube(mail, password) : await _ingresarLocal(mail, password);

    // El panel elegido debe coincidir con el rol real del usuario.
    if (panel != null && u.area != panel) {
      if (supabaseListo) {
        try {
          await supabase.auth.signOut();
        } catch (_) {}
      }
      session = null;
      throw LoginError(
          'Usuario inválido para el panel de ${etiquetaArea(panel)}.');
    }

    session = u;
    await LocalStore.guardarSesion(u.toJson());
    return u;
  }

  Future<SessionUser> _ingresarNube(String email, String password) async {
    try {
      final res = await supabase.auth
          .signInWithPassword(email: email, password: password);
      final user = res.user;
      if (user == null) throw LoginError('No se pudo iniciar sesión.');
      final u = await _perfilDesdeSupabase(user.id, user.email ?? email) ??
          SessionUser(
              id: user.id,
              email: user.email ?? email,
              nombre: user.email ?? 'Usuario',
              rol: 'operario');
      return u;
    } on AuthException catch (e) {
      throw LoginError(_traducir(e.message));
    } on LoginError {
      rethrow;
    } catch (_) {
      throw LoginError('No se pudo conectar. Revisa tu conexión a internet.');
    }
  }

  Future<SessionUser?> _perfilDesdeSupabase(String id, String email) async {
    Map<String, dynamic>? row;
    try {
      row = await supabase
          .from('profiles')
          .select('id, nombre, apellidos, rol, activo, cliente_id')
          .eq('id', id)
          .maybeSingle();
    } catch (_) {
      return null;
    }
    if (row == null) return null;
    if (row['activo'] == false) {
      throw LoginError('Tu usuario está inactivo. Contacta al administrador.');
    }
    final nombre = [row['nombre'], row['apellidos']]
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .map((e) => e.toString().trim())
        .join(' ');
    return SessionUser(
      id: id,
      email: email,
      nombre: nombre.isEmpty ? email : nombre,
      rol: (row['rol'] ?? 'operario').toString(),
      clienteId: (row['cliente_id'] as num?)?.toInt(),
    );
  }

  Future<SessionUser> _ingresarLocal(String email, String password) async {
    final u = LocalStore.validar(email, password);
    if (u == null) {
      throw LoginError('Correo o contraseña incorrectos.');
    }
    return SessionUser(
      id: u['id'] as String,
      email: u['email'] as String,
      nombre: u['nombre'] as String,
      rol: u['rol'] as String,
    );
  }

  Future<void> cerrarSesion() async {
    if (supabaseListo) {
      try {
        await supabase.auth.signOut();
      } catch (_) {}
    }
    await LocalStore.limpiarSesion();
    session = null;
  }

  String _traducir(String m) {
    final low = m.toLowerCase();
    if (low.contains('invalid login')) return 'Correo o contraseña incorrectos.';
    if (low.contains('email not confirmed')) {
      return 'Tu correo aún no está confirmado.';
    }
    return m;
  }
}
