/// ============================================================================
///  ENUMS / ETIQUETAS CANÓNICAS — UNA SOLA VERDAD (espejo del web)
///
///  Mantiene los MISMOS valores y etiquetas que el aplicativo web
///  (lib/utils/constants.ts y lib/labels.ts) y que los CHECK del SQL, para que
///  móvil y web hablen exactamente lo mismo. Cuando se integre la nube, no hay
///  discrepancias de estados/tipos. Cambiar aquí = cambiar en un solo lugar.
/// ============================================================================

/// Estados de obra (== ESTADOS_OBRA del web).
const estadosObra = <String, String>{
  'formulacion': 'Formulación',
  'licitacion': 'Licitación',
  'contratada': 'Contratada',
  'en_ejecucion': 'En ejecución',
  'paralizada': 'Paralizada',
  'en_liquidacion': 'En liquidación',
  'completada': 'Completada',
  'cancelada': 'Cancelada',
};

/// Estados de tarea / fase (== ESTADOS_FASE del web).
const estadosTarea = <String, String>{
  'pendiente': 'Pendiente',
  'en_progreso': 'En progreso',
  'completada': 'Completada',
  'bloqueada': 'Bloqueada',
};

/// Tipos de servicio (== TIPOS_SERVICIO del web).
const tiposServicio = <String, String>{
  'construccion': 'Construcción',
  'topografia': 'Topografía',
  'arquitectura': 'Arquitectura',
  'instalaciones': 'Instalaciones',
  'supervision': 'Supervisión',
  'habilitacion_urbana': 'Habilitación urbana',
};

/// Prioridades (== PRIORIDADES del web).
const prioridades = <String, String>{
  'baja': 'Baja',
  'media': 'Media',
  'alta': 'Alta',
  'critica': 'Crítica',
};

String _fallback(String raw) {
  final c = raw.trim().replaceAll('_', ' ');
  if (c.isEmpty) return raw;
  return c[0].toUpperCase() + c.substring(1);
}

String _desde(Map<String, String> mapa, String? valor) {
  final raw = (valor ?? '').trim();
  if (raw.isEmpty) return '';
  return mapa[raw.toLowerCase()] ?? _fallback(raw);
}

String labelEstadoObra(String? v) => _desde(estadosObra, v);
String labelEstadoTarea(String? v) => _desde(estadosTarea, v);
String labelTipoServicio(String? v) => _desde(tiposServicio, v);
String labelPrioridad(String? v) => _desde(prioridades, v);
