import '../core/local_store.dart';
import '../core/supabase_client.dart';

/// Persona del equipo (para delegar tareas a alguien concreto).
class Persona {
  final String id;
  final String nombre;
  final String rol;
  const Persona(this.id, this.nombre, this.rol);
}

/// Personas de un rol dado.
/// - Con Supabase listo: lee `profiles` (rol + activo).
/// - Sin nube: usa los usuarios de la memoria interna.
Future<List<Persona>> personasPorRol(String rol) async {
  if (supabaseListo) {
    try {
      final rows = await supabase
          .from('profiles')
          .select('id, nombre, apellidos, rol, activo')
          .eq('rol', rol)
          .eq('activo', true);
      return (rows as List).map((r) {
        final m = Map<String, dynamic>.from(r as Map);
        final nombre = [m['nombre'], m['apellidos']]
            .where((e) => e != null && e.toString().trim().isNotEmpty)
            .map((e) => e.toString().trim())
            .join(' ');
        return Persona('${m['id']}', nombre.isEmpty ? 'Usuario' : nombre,
            '${m['rol']}');
      }).toList();
    } catch (_) {
      // cae a memoria interna
    }
  }
  return LocalStore.usuarios()
      .where((u) => u['rol'] == rol)
      .map((u) => Persona(
          u['id'] as String, (u['nombre'] ?? 'Usuario') as String, rol))
      .toList();
}

/// Personas de varios roles (p. ej. todo el personal de campo).
Future<List<Persona>> personasDeRoles(Set<String> roles) async {
  final out = <Persona>[];
  for (final r in roles) {
    out.addAll(await personasPorRol(r));
  }
  return out;
}

/// Todo el personal de la empresa (sin clientes). Producción: `profiles`;
/// sin nube: usuarios de la memoria interna.
Future<List<Persona>> todoElPersonal() async {
  if (supabaseListo) {
    try {
      final rows = await supabase
          .from('profiles')
          .select('id, nombre, apellidos, rol')
          .neq('rol', 'cliente');
      return (rows as List).map((r) {
        final m = Map<String, dynamic>.from(r as Map);
        final nombre = [m['nombre'], m['apellidos']]
            .where((e) => e != null && e.toString().trim().isNotEmpty)
            .map((e) => e.toString().trim())
            .join(' ');
        return Persona('${m['id']}', nombre.isEmpty ? 'Usuario' : nombre,
            '${m['rol']}');
      }).toList();
    } catch (_) {
      // cae a memoria interna
    }
  }
  return LocalStore.usuarios()
      .where((u) => u['rol'] != 'cliente')
      .map((u) =>
          Persona(u['id'] as String, (u['nombre'] ?? 'Usuario') as String,
              '${u['rol']}'))
      .toList();
}
