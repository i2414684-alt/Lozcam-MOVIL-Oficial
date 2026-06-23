import '../models/models.dart';

/// Datos de ejemplo para mostrar la app sin conexión a Supabase.
/// Cuando conectes la base real, reemplaza estos por consultas a supabase.

const obras = <Obra>[
  Obra(1, 'Edif. Residencial Huancayo', 'Construcción', 'Huancayo',
      'en_ejecucion', 68, 'S/ 450,000', 'Jr. Loreto 240', -12.0653, -75.2049, 'orange'),
  Obra(2, 'Topografía Zona Norte', 'Topografía', 'Huancayo', 'en_ejecucion',
      41, 'S/ 85,000', 'Av. Mariscal Castilla', -12.0489, -75.1990, 'blue'),
  Obra(3, 'Hab. Urbana San Carlos', 'Hab. Urbana', 'El Tambo', 'en_ejecucion',
      22, 'S/ 220,000', 'Sector San Carlos', -12.0561, -75.2123, 'green'),
  Obra(4, 'Arquitectura Oficinas Jr.', 'Arquitectura', 'Huancayo', 'contratada',
      5, 'S/ 180,000', 'Jr. Ancash 512', -12.0670, -75.2050, 'purple'),
];

const empleados = <Empleado>[
  Empleado('e1', 'Ana Quispe Flores', 'Residente de obra', 'AQ', 'Activo', 'orange', '964111222'),
  Empleado('e2', 'Luis Ramos Ccente', 'Topógrafo', 'LR', 'Activo', 'blue', '964333444'),
  Empleado('e3', 'María García Poma', 'Arquitecta', 'MG', 'Activo', 'green', '964555666'),
  Empleado('e4', 'Pedro Vega Huari', 'Maestro de obra', 'PV', 'Tardanza', 'purple', '964777888'),
  Empleado('e5', 'Sara Mendoza Torres', 'Supervisora', 'SM', 'En obra', 'pink', '964999000'),
];

const tareasAdmin = <GrupoTareas>[
  GrupoTareas('Edif. Residencial Huancayo', [
    Tarea('Vaciado de columnas — piso 3', 'Ana Quispe', '20 Jun', 'Alta', false),
    Tarea('Encofrado de losa', 'Pedro Vega', 'ayer', 'Media', true),
    Tarea('Habilitación de acero', 'Marco Torres', '22 Jun', 'Media', false),
  ]),
  GrupoTareas('Topografía Zona Norte', [
    Tarea('Levantamiento puntos GPS sector B', 'Luis Ramos', '19 Jun', 'Alta', false),
    Tarea('Plano de curvas de nivel', 'Luis Ramos', '25 Jun', 'Baja', false),
  ]),
];

const tareasEmpleado = <Tarea>[
  Tarea('Vaciado columnas — piso 3', 'Edif. Residencial', '20 Jun', 'Urgente', false),
  Tarea('Verificar niveles de losa', 'Edif. Residencial', '22 Jun', 'Media', false),
  Tarea('Informe semanal de avance', 'Administración', '23 Jun', 'Normal', false),
  Tarea('Supervisar encofrado', 'Edif. Residencial', '15 Jun', 'Media', true),
  Tarea('Revisión de planos', 'Edif. Residencial', '14 Jun', 'Baja', true),
];

const asistenciasHoy = <Asistencia>[
  Asistencia('Ana Quispe', 'Entrada 07:45 · Edif. Residencial', 'presente'),
  Asistencia('Luis Ramos', 'Entrada 07:52 · Topo. Zona Norte', 'presente'),
  Asistencia('Pedro Vega', 'Entrada 08:34 · Edif. Residencial', 'tardanza'),
  Asistencia('Marco Torres', 'Sin registro · Edif. Residencial', 'inasistencia'),
  Asistencia('Sara Mendoza', 'Entrada 07:55 · Hab. San Carlos', 'presente'),
];

const historialAsistencia = <Asistencia>[
  Asistencia('Lun 16 Jun', '07:45 entrada · 17:02 salida', 'presente'),
  Asistencia('Vie 13 Jun', '07:50 entrada · 17:00 salida', 'presente'),
  Asistencia('Jue 12 Jun', '08:22 entrada · 17:05 salida', 'tardanza'),
  Asistencia('Mié 11 Jun', '07:48 entrada · 17:00 salida', 'presente'),
  Asistencia('Mar 10 Jun', '07:52 entrada · 16:58 salida', 'presente'),
];

const fasesCliente = <Fase>[
  Fase('Fase 1 — Cimentación', 100),
  Fase('Fase 2 — Losa 1er piso', 100),
  Fase('Fase 3 — Estructura piso 3', 45),
  Fase('Fase 4 — Acabados', 0),
];

const informesCliente = <Informe>[
  Informe('Informe diario — Lun 16 Jun', 'Residente: Ana Quispe', '68%',
      'Vaciado de 4 columnas en eje B-C piso 3. Se trabajó con 6 operarios. Clima: soleado 18°C.', true),
  Informe('Informe diario — Vie 13 Jun', 'Residente: Ana Quispe', '62%',
      'Se completó el encofrado de losa 2do piso. Habilitación de acero al 80%.', false),
  Informe('Informe semanal — Sem. 2', 'Supervisor: Sara Mendoza', 'Semanal',
      'Semana productiva. Se avanzó 8% en estructura. Sin incidencias graves.', false),
];

const contactos = <Contacto>[
  Contacto('Ana Quispe Flores', 'Residente de obra', 'AQ', 'orange'),
  Contacto('Sara Mendoza Torres', 'Supervisora', 'SM', 'purple'),
];


// ===== JERARQUÍA Y DELEGACIÓN (para el panel de gerencia) =====

class NodoEquipo {
  final String nombre, rol, nivel, colorKey;
  final int tareasActivas;
  final List<NodoEquipo> subordinados;
  const NodoEquipo(this.nombre, this.rol, this.nivel, this.colorKey,
      this.tareasActivas, this.subordinados);
}

const organigrama = NodoEquipo(
  'Carlos Lozcam', 'Gerente General', 'Gerencia', 'orange', 0, [
    NodoEquipo('Rosa Ávila', 'Subgerente', 'Subgerencia', 'orange', 2, [
      NodoEquipo('Ana Quispe', 'Residente de Obra', 'Jefe de rama', 'blue', 5, [
        NodoEquipo('Pedro Vega', 'Maestro de Obra', 'Operativo', 'purple', 3, []),
        NodoEquipo('Marco Torres', 'Operario', 'Operativo', 'gray', 2, []),
      ]),
      NodoEquipo('Sara Mendoza', 'Supervisora', 'Jefe de rama', 'pink', 3, []),
      NodoEquipo('Luis Ramos', 'Topógrafo', 'Jefe de rama', 'blue', 4, []),
      NodoEquipo('María García', 'Arquitecta', 'Jefe de rama', 'green', 2, []),
    ]),
  ]);

class TareaDelegada {
  final String titulo, delegadoPor, asignadoA, rama, estado, vence;
  final int avance;
  const TareaDelegada(this.titulo, this.delegadoPor, this.asignadoA, this.rama,
      this.estado, this.vence, this.avance);
}

const tareasDelegadas = <TareaDelegada>[
  TareaDelegada('Plan de vaciado piso 3', 'Subgerente', 'Ana Quispe (Residente)',
      'Construcción', 'en_progreso', '20 Jun', 60),
  TareaDelegada('Levantamiento topográfico Norte', 'Gerente', 'Luis Ramos (Topógrafo)',
      'Topografía', 'en_progreso', '19 Jun', 45),
  TareaDelegada('Revisión planos arquitectónicos', 'Subgerente', 'María García (Arquitecta)',
      'Arquitectura', 'en_revision', '22 Jun', 80),
  TareaDelegada('Inspección de seguridad semanal', 'Gerente', 'Sara Mendoza (Supervisora)',
      'Supervisión', 'pendiente', '23 Jun', 0),
];
