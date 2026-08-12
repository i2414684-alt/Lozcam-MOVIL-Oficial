import '../core/asistencia_service.dart';
import '../core/auth_service.dart';
import '../core/supabase_client.dart';
import '../models/models.dart';
import 'asignaciones_repository.dart';
import 'obras_repository.dart';
import 'personas_repository.dart';

/// ============================================================================
///  FUENTE DE DATOS ÚNICA
///
///  El problema que resuelve: cada pantalla elegía por su cuenta si leer de la
///  nube (Supabase) o de la memoria interna del dispositivo. Con la nube activa
///  eso hacía que el MISMO trabajador viera tres cosas distintas sobre "su
///  obra" según la pestaña (Inicio decía «Sin área asignada», Marcar mostraba
///  la obra real, Informe decía «Sin obra asignada»).
///
///  A partir de aquí, la decisión nube/local se toma en UN SOLO SITIO y todas
///  las pantallas consumen la misma función por concepto. Si mañana cambia el
///  backend, se cambia aquí y no en once pantallas.
///
///  NO toca la base de datos: usa solo tablas que ya existen (`obras`,
///  `profiles`, `asignaciones`, `asistencias`).
/// ============================================================================

/// Roles que son punto de contacto para el cliente (gerencia + jefatura de obra).
const Set<String> rolesContactoCliente = {
  'gerente_general',
  'subgerente',
  'administrador',
  'ingeniero_residente',
};

/// Obras del trabajador indicado (por defecto, el de la sesión actual).
///
/// Regla única, la misma para Inicio, Marcar e Informe:
///  1. Se cargan las obras visibles (`cargarObras()` — nube o local).
///  2. Se filtran por las asignaciones del trabajador (`obrasAsignadasA()`,
///     que lee la tabla real `asignaciones` y cae a memoria interna).
///  3. Si el trabajador no tiene ninguna asignación, se devuelven todas las
///     obras disponibles como respaldo — así nunca se queda sin poder marcar
///     ni reportar por un dato de asignación que aún no se cargó en el sistema.
Future<List<Obra>> obrasDelUsuario({String? perfilId}) async {
  final id = perfilId ?? AuthService.instance.session?.id ?? '';
  final todas = await cargarObras();
  if (id.isEmpty) return todas;
  final asignadas = await obrasAsignadasA(id);
  if (asignadas.isEmpty) return todas;
  final filtradas = todas.where((o) => asignadas.contains(o.id)).toList();
  // Si las asignaciones apuntan a obras que ya no están visibles (inactivas o
  // fuera del alcance del RLS), es preferible mostrar todas antes que dejar la
  // pantalla vacía sin explicación.
  return filtradas.isEmpty ? todas : filtradas;
}

/// Obra principal del trabajador (la primera asignada), o null si no hay ninguna.
Future<Obra?> obraPrincipalDelUsuario({String? perfilId}) async {
  final lista = await obrasDelUsuario(perfilId: perfilId);
  return lista.isEmpty ? null : lista.first;
}

/// Resumen de asistencia del trabajador actual, agrupado por día.
/// Única vía permitida: producción lee la tabla `asistencias`; sin nube agrupa
/// la memoria interna. Antes, *Inicio* usaba `historialLocal()` (siempre 0 en
/// producción) mientras *Historial* usaba esta misma consulta.
Future<List<Map<String, dynamic>>> asistenciaDelUsuario() =>
    AsistenciaService.instance.resumen();

/// Totales de asistencia listos para las tarjetas KPI del panel del trabajador.
class TotalesAsistencia {
  final int dias;
  final int entradas;
  final int salidas;
  const TotalesAsistencia(this.dias, this.entradas, this.salidas);

  /// Días con entrada pero sin salida registrada (jornada sin cerrar).
  int get sinCerrar => entradas - salidas < 0 ? 0 : entradas - salidas;
}

TotalesAsistencia totalesDe(List<Map<String, dynamic>> dias) => TotalesAsistencia(
      dias.length,
      dias.where((d) => d['hora_entrada'] != null).length,
      dias.where((d) => d['hora_salida'] != null).length,
    );

/// Un día del historial de asistencia del trabajador.
/// [falta] = día hábil dentro del período SIN ninguna marca registrada.
class DiaAsistencia {
  final String fecha; // yyyy-MM-dd
  final String obraNombre;
  final dynamic horaEntrada;
  final dynamic horaSalida;
  final bool falta;

  const DiaAsistencia({
    required this.fecha,
    this.obraNombre = '',
    this.horaEntrada,
    this.horaSalida,
    this.falta = false,
  });

  bool get completo => horaEntrada != null && horaSalida != null;
  bool get soloEntrada => horaEntrada != null && horaSalida == null;
}

/// Días hábiles de la jornada de obra: lunes a sábado.
/// Los domingos no cuentan como falta.
bool esDiaHabil(DateTime d) => d.weekday != DateTime.sunday;

String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Historial del trabajador de los últimos [dias] días hábiles, CON las faltas
/// calculadas.
///
/// La pantalla se llamaba «inasistencias» pero nunca calculaba una falta:
/// listaba solo los días con marca, todos con check verde. Aquí se recorre el
/// calendario del período y se marca como falta todo día hábil sin registro,
/// que es lo que el trabajador (y el gerente) necesita ver.
///
/// El período arranca en la PRIMERA marca del trabajador: no tiene sentido
/// contar como faltas los días anteriores a su alta en el sistema.
Future<List<DiaAsistencia>> historialConFaltas({int dias = 30}) async {
  final registros = await asistenciaDelUsuario();
  // Sin ninguna marca no hay período del que hablar: devolver 26 "faltas" a un
  // trabajador recién dado de alta sería acusarlo de algo que no ocurrió. La
  // pantalla muestra su estado vacío.
  if (registros.isEmpty) return const [];

  final porFecha = <String, Map<String, dynamic>>{
    for (final r in registros) '${r['fecha']}': r,
  };

  final hoy = DateTime.now();
  final inicioPeriodo = DateTime(hoy.year, hoy.month, hoy.day)
      .subtract(Duration(days: dias - 1));

  // No se cuentan faltas anteriores a la primera marca del trabajador: antes de
  // esa fecha simplemente no estaba operando en el sistema.
  final fechas = porFecha.keys.toList()..sort();
  final primera = DateTime.tryParse(fechas.first);
  final desde = (primera != null && primera.isAfter(inicioPeriodo))
      ? primera
      : inicioPeriodo;

  final out = <DiaAsistencia>[];
  for (var d = DateTime(hoy.year, hoy.month, hoy.day);
      !d.isBefore(desde);
      d = d.subtract(const Duration(days: 1))) {
    final clave = _iso(d);
    final r = porFecha[clave];
    if (r != null) {
      out.add(DiaAsistencia(
        fecha: clave,
        obraNombre: (r['obra_nombre'] ?? '').toString(),
        horaEntrada: r['hora_entrada'],
        horaSalida: r['hora_salida'],
      ));
    } else if (esDiaHabil(d)) {
      out.add(DiaAsistencia(fecha: clave, falta: true));
    }
    // Los domingos sin marca simplemente no aparecen.
  }
  return out;
}

/// Equipo de contacto que ve el cliente. Producción: `profiles` (personas
/// reales y activas). Sin nube: usuarios de la memoria interna.
/// Antes esta pantalla leía SIEMPRE la semilla de demo, así que un cliente real
/// veía como equipo de su obra a personas que no existen.
Future<List<Persona>> equipoDeContacto() =>
    personasDeRoles(rolesContactoCliente);

/// ¿Los datos que se están mostrando vienen de la nube compartida?
/// Las pantallas lo usan para avisar cuando algo vive solo en el dispositivo.
bool get datosCompartidos => supabaseListo;
