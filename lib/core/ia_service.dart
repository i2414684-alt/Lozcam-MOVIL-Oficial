import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/monitoreo.dart';
import 'config.dart';
import 'supabase_client.dart';

/// Asistente IA del gerente. Llama a la Edge Function `chat-gerente` (que
/// guarda la API key de Ollama). Envía la pregunta + un resumen SOLO LECTURA
/// del estado de la empresa. NO escribe nada en la BD.
class IaService {
  IaService._();
  static final IaService instance = IaService._();

  Future<String> preguntar(String pregunta) async {
    if (!supabaseListo) {
      return 'El asistente necesita conexión a la base de datos (modo nube).';
    }
    final token = supabase.auth.currentSession?.accessToken;
    if (token == null) {
      return 'Tu sesión no es válida. Vuelve a iniciar sesión.';
    }

    String contexto;
    try {
      contexto = await construirContextoMonitoreo();
    } catch (_) {
      contexto = '(No se pudieron leer los datos de monitoreo.)';
    }

    try {
      final res = await http
          .post(
            Uri.parse('$funcionesUrl/chat-gerente'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'apikey': supabaseAnonKey,
            },
            body: jsonEncode({'pregunta': pregunta, 'contexto': contexto}),
          )
          .timeout(const Duration(seconds: 45));

      if (res.statusCode == 401) {
        return 'Tu sesión expiró. Vuelve a iniciar sesión.';
      }
      // Parseo defensivo: el cuerpo podría venir vacío o no ser un objeto JSON.
      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {}
      if (res.statusCode == 200) {
        final r = (body?['respuesta'] ?? '').toString().trim();
        return r.isEmpty ? 'Sin respuesta.' : r;
      }
      return (body?['error'] ??
              'El asistente no está disponible ahora (${res.statusCode}).')
          .toString();
    } on TimeoutException {
      return 'El asistente tardó demasiado en responder. Intenta de nuevo.';
    } catch (_) {
      return 'No se pudo contactar al asistente. Revisa tu conexión.';
    }
  }
}
