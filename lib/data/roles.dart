/// ============================================================================
///  JERARQUÍA DE PERFILES — LOZCAM
///
///  Espejo EXACTO de los roles del sistema web (ROL_SISTEMA), para que
///  `profiles.rol` coincida entre web y móvil. Son 11 roles internos que puede
///  crear gerencia + `cliente` (externo, FUERA de la jerarquía).
///
///  Lógica de jerarquía (nivel: 1 = máxima autoridad):
///    Nivel 1  Gerente General          (máximo: delega a TODOS, monitorea todo)
///    Nivel 2  Subgerente, Administrador (alta dirección: delegan, monitorean todo)
///    Nivel 3  Jefaturas / profesionales (delegan dentro de SU área)
///    Nivel 4  Mando operativo / técnico
///    Nivel 5  Operativo de base
///    Nivel 9  Cliente                   (externo: no delega ni recibe tareas)
///
///  Delegación: un rol delega "hacia abajo" (a niveles mayores). Gerencia
///  (monitorea_todo) delega a toda la empresa; las jefaturas solo dentro de su
///  área. Nunca a `cliente`.
/// ============================================================================
class RolConfig {
  final String rol; // == profiles.rol (enum del web)
  final String nombre;
  final int nivel; // 1=máx ... 5=base, 9=externo
  final String? area; // construccion, arquitectura, topografia, administracion, comercial
  final bool puedeDelegar;
  final bool puedeMonitorearTodo;
  final String color;
  const RolConfig(this.rol, this.nombre, this.nivel, this.area,
      this.puedeDelegar, this.puedeMonitorearTodo, this.color);
}

/// La jerarquía completa (coincide con ROL_SISTEMA del web).
const jerarquiaLozcam = <RolConfig>[
  // Nivel 1 — Gerencia máxima
  RolConfig('gerente_general', 'Gerente General', 1, null, true, true, 'orange'),
  // Nivel 2 — Alta dirección
  RolConfig('subgerente', 'Subgerente', 2, null, true, true, 'orange'),
  RolConfig('administrador', 'Administrador', 2, null, true, true, 'gray'),
  // Nivel 3 — Jefaturas / profesionales (delegan dentro de su área)
  RolConfig('ingeniero_residente', 'Ing. Residente', 3, 'construccion', true, false, 'blue'),
  RolConfig('arquitecto', 'Arquitecto', 3, 'arquitectura', true, false, 'green'),
  RolConfig('topografo', 'Topógrafo', 3, 'topografia', true, false, 'blue'),
  RolConfig('contador', 'Contador', 3, 'administracion', true, false, 'purple'),
  RolConfig('vendedor', 'Vendedor', 3, 'comercial', true, false, 'pink'),
  // Nivel 4 — Mando operativo / técnico
  RolConfig('maestro_obra', 'Maestro de Obra', 4, 'construccion', true, false, 'purple'),
  RolConfig('tecnico_autocad', 'Técnico AutoCAD', 4, 'arquitectura', false, false, 'blue'),
  // Nivel 5 — Operativo de base
  RolConfig('personal_obra', 'Personal de Obra', 5, 'construccion', false, false, 'gray'),
  // Nivel 9 — Externo (fuera de la jerarquía)
  RolConfig('cliente', 'Cliente', 9, null, false, false, 'green'),
];

/// Roles internos que puede crear gerencia (los 11, sin `cliente`).
List<RolConfig> get rolesEmpresa =>
    jerarquiaLozcam.where((r) => r.rol != 'cliente').toList();

/// Roles que registran asistencia de campo (según el brief del backend).
const rolesQueMarcanAsistencia = <String>{'personal_obra', 'maestro_obra'};

bool puedeMarcarAsistencia(String rol) =>
    rolesQueMarcanAsistencia.contains(rol);

/// Roles de campo que el gerente puede asignar a un área de trabajo.
const rolesDeCampo = <String>{
  'ingeniero_residente',
  'arquitecto',
  'topografo',
  'maestro_obra',
  'personal_obra',
};

RolConfig? rolPorClave(String rol) {
  for (final r in jerarquiaLozcam) {
    if (r.rol == rol) return r;
  }
  return null;
}

/// ¿`rolA` puede delegar una tarea a `rolB`?
///   - rolA debe poder delegar.
///   - Nunca a `cliente` (externo a la empresa).
///   - Solo "hacia abajo" (nivel de B mayor que el de A).
///   - Gerencia (monitorea todo) delega a TODA la empresa; las jefaturas solo
///     dentro de su misma área.
bool puedeDelegarA(String rolA, String rolB) {
  final a = rolPorClave(rolA);
  final b = rolPorClave(rolB);
  if (a == null || b == null) return false;
  if (!a.puedeDelegar) return false;
  if (b.rol == 'cliente') return false;
  if (b.nivel <= a.nivel) return false;
  if (a.puedeMonitorearTodo) return true; // gerencia: toda la empresa
  return a.area != null && a.area == b.area; // jefaturas: solo su área
}

/// Lista de roles a los que `rol` puede delegarles tareas.
List<RolConfig> rolesDelegablesPor(String rol) =>
    jerarquiaLozcam.where((r) => puedeDelegarA(rol, r.rol)).toList();

String etiquetaNivel(int n) {
  switch (n) {
    case 1:
      return 'Gerencia';
    case 2:
      return 'Alta dirección';
    case 3:
      return 'Jefatura';
    case 4:
      return 'Operativo';
    case 5:
      return 'Operativo';
    default:
      return 'Externo';
  }
}
