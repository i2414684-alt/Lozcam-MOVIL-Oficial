import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';

/// Indica si Supabase quedó inicializado (hay credenciales reales).
bool supabaseListo = false;

/// Inicializa Supabase de forma segura: si aún no pusiste credenciales,
/// la app sigue funcionando con datos de ejemplo (no se cae).
Future<void> initSupabase() async {
  if (!credencialesListas) return;
  try {
    await Supabase.initialize(
        url: supabaseUrl, publishableKey: supabaseAnonKey);
    supabaseListo = true;
  } catch (_) {
    supabaseListo = false;
  }
}

SupabaseClient get supabase => Supabase.instance.client;

/// Prueba la conexión real contra Supabase (para el paso de cutover a
/// producción). Devuelve false si no hay credenciales (modo memoria interna)
/// o si la consulta falla. No se ejecuta sola: llámala bajo demanda.
Future<bool> probarConexion() async {
  if (!supabaseListo) return false;
  try {
    await supabase.from('profiles').select('id').limit(1);
    return true;
  } catch (_) {
    return false;
  }
}

/// Llama al RPC `marcar_asistencia` del backend (valida el GPS y el radio EN EL
/// SERVIDOR). Firma según el brief: p_obra_id, p_lat, p_lng, p_tipo, p_foto_url.
/// Devuelve el jsonb del backend: { ok, mensaje, distancia_metros, ... }.
Future<Map<String, dynamic>> marcarAsistenciaRpc({
  required int obraId,
  required double lat,
  required double lng,
  required String tipo, // 'entrada' | 'salida'
  String? fotoUrl,
}) async {
  final res = await supabase.rpc('marcar_asistencia', params: {
    'p_obra_id': obraId,
    'p_lat': lat,
    'p_lng': lng,
    'p_tipo': tipo,
    'p_foto_url': fotoUrl,
  });
  return Map<String, dynamic>.from(res as Map);
}
