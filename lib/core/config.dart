// ============================================================================
//  CONFIGURACIÓN DE BASE DE DATOS — LOZCAM MÓVIL
//
//  ESTE ES EL ÚNICO APARTADO QUE HAY QUE COMPLETAR para pasar a la nube.
//  Mientras estos campos estén vacíos/placeholder, la app funciona como
//  aplicación real usando la MEMORIA INTERNA del dispositivo (login local).
//  En cuanto pongas credenciales reales aquí, el login pasa AUTOMÁTICAMENTE a
//  autenticar contra Supabase (supabase.auth) y a leer el rol desde `profiles`.
//
//  Trabajas con DOS bases: la DUPLICADA (pruebas) y la PRINCIPAL (producción).
//  Mientras pruebas, deja `entornoActivo = Entorno.duplicada`.
//  Cuando todo funcione, cambia a Entorno.produccion. NO necesitas tocar más.
// ============================================================================

enum Entorno { duplicada, produccion }

/// 👉 CAMBIA AQUÍ a qué base se conecta la app.
const Entorno entornoActivo = Entorno.produccion;

// ============================================================================
//  ESCRITURA EN LA BD POR MÓDULO
//  - USUARIOS: SIEMPRE solo lectura (los crea el gerente en el web; la app
//    nunca registra ni modifica usuarios). No hay flag: jamás escribe.
//  - Los siguientes módulos SÍ escriben datos (en tablas que YA existen; nunca
//    crean ni alteran el esquema):
// ============================================================================

/// Geolocalización / asistencia: marcar entrada-salida vía RPC `marcar_asistencia`
/// (escribe en la tabla existente `asistencias`).
const bool escrituraAsistencia = true;

/// Tareas: al cumplir una tarea, registrar su % en la tabla existente `avance_obra`.
const bool escrituraTareas = true;

// ----------------------------------------------------------------------------
//  BASE DE DATOS DUPLICADA  (tu copia de pruebas — úsala primero)
//  Pega aquí la URL y la anon key de tu proyecto Supabase DUPLICADO.
//  Las encuentras en: Supabase Dashboard -> Project Settings -> API
// ----------------------------------------------------------------------------
const String _urlDuplicada =
    'https://TU-PROYECTO-DUPLICADO.supabase.co';
const String _anonKeyDuplicada =
    'PEGA-AQUI-LA-ANON-KEY-DE-TU-DB-DUPLICADA';

// ----------------------------------------------------------------------------
//  BASE DE DATOS PRINCIPAL  (producción)
//  URL ya puesta (del brief). Falta SOLO pegar la anon key (Project Settings ->
//  API -> "anon public") y luego cambiar arriba entornoActivo a Entorno.produccion.
//  ⚠️ Confirma que el proyecto correcto sea este (dnhagzhimzhijzlozyzs) y no otro.
// ----------------------------------------------------------------------------
const String _urlProduccion = 'https://dnhagzhimzhijzlozyzs.supabase.co';
const String _anonKeyProduccion =
    'sb_publishable_T1qHa_QcPZDAAGIXkz9XNg_aoeOcv0V'; // anon/publishable (pública)

// ----------------------------------------------------------------------------
//  Resolución automática según el entorno activo.
//  También puedes sobrescribir con --dart-define al ejecutar:
//    flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
// ----------------------------------------------------------------------------
const String _overrideUrl =
    String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const String _overrideKey =
    String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

String get supabaseUrl {
  if (_overrideUrl.isNotEmpty) return _overrideUrl;
  return entornoActivo == Entorno.duplicada ? _urlDuplicada : _urlProduccion;
}

String get supabaseAnonKey {
  if (_overrideKey.isNotEmpty) return _overrideKey;
  return entornoActivo == Entorno.duplicada
      ? _anonKeyDuplicada
      : _anonKeyProduccion;
}

/// true cuando las credenciales son reales (no los placeholders de ejemplo).
bool get credencialesListas =>
    supabaseUrl.isNotEmpty &&
    !supabaseUrl.contains('TU-PROYECTO') &&
    supabaseAnonKey.isNotEmpty &&
    !supabaseAnonKey.contains('PEGA-AQUI');

/// Nombre legible del entorno (se muestra en la app para no confundirte).
String get nombreEntorno =>
    entornoActivo == Entorno.duplicada ? 'BD Duplicada' : 'BD Producción';

/// URL base de las Edge Functions de Supabase (para el asistente IA del gerente).
String get funcionesUrl => '$supabaseUrl/functions/v1';
