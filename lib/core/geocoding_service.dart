import 'dart:convert';
import 'package:http/http.dart' as http;

/// Resultado de una búsqueda de dirección.
class GeoResultado {
  final String nombre; // dirección legible
  final double lat;
  final double lng;
  const GeoResultado(this.nombre, this.lat, this.lng);
}

/// ============================================================================
///  GEOCODIFICACIÓN  (OpenStreetMap / Nominatim — sin API key)
///
///  - buscar(direccion)    -> dirección a coordenadas (para que el gerente fije
///                            el punto del área de trabajo).
///  - direccionDe(lat,lng) -> coordenadas a dirección (para que el cliente vea
///                            la dirección de la obra).
///
///  Nota: Nominatim es de uso libre con límite ~1 req/seg y exige User-Agent.
///  Para producción intensiva conviene un proveedor propio. Si la red falla, el
///  gerente igual puede fijar el punto tocando el mapa (no depende de esto).
/// ============================================================================
class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  static const _ua = 'LozcamApp/1.0 (gestion-asistencia)';
  static const _base = 'nominatim.openstreetmap.org';

  Future<List<GeoResultado>> buscar(String consulta) async {
    final q = consulta.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.https(_base, '/search', {
      'q': q,
      'format': 'jsonv2',
      'limit': '6',
      'addressdetails': '0',
    });
    try {
      final res = await http
          .get(uri, headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return const [];
      final data = jsonDecode(res.body) as List;
      return data
          .map((e) {
            final m = e as Map<String, dynamic>;
            return GeoResultado(
              (m['display_name'] ?? '') as String,
              double.tryParse('${m['lat']}') ?? 0,
              double.tryParse('${m['lon']}') ?? 0,
            );
          })
          .where((r) => r.lat != 0 || r.lng != 0)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<String?> direccionDe(double lat, double lng) async {
    final uri = Uri.https(_base, '/reverse', {
      'lat': '$lat',
      'lon': '$lng',
      'format': 'jsonv2',
    });
    try {
      final res = await http
          .get(uri, headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      return m['display_name'] as String?;
    } catch (_) {
      return null;
    }
  }
}
