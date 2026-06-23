-- ============================================================================
--  ⚠️  ADVERTENCIA (LEER ANTES DE EJECUTAR)
--  Este esquema corresponde a un DISEÑO ANTERIOR y NO coincide con el backend
--  descrito en el brief de asistencia (proyecto Supabase ya construido):
--    * Aquí `asistencias` guarda una fila por `tipo` (entrada/salida) con
--      `latitud/longitud/dentro_de_rango`; el brief usa UNA fila por día con
--      `hora_entrada/hora_salida` y `lat_entrada/lng_entrada`, etc.
--    * Aquí `marcar_asistencia(...)` recibe `p_horario_id` y RETURNS la fila;
--      el brief usa `p_foto_url` y RETURNS jsonb { ok, mensaje, ... }.
--    * Las tablas `tareas`, `horarios`, `notificaciones` son Fase 2 (aún NO
--      existen en el backend real).
--  NO ejecutes este archivo sobre el proyecto del brief. Déjalo solo como
--  referencia histórica hasta alinearlo con el backend definitivo.
-- ============================================================================
--
-- ============================================================================
--  LOZCAM MÓVIL — ESQUEMA DE BASE DE DATOS (ampliación para la app móvil)
--  Sistema de trabajo jerárquico con delegación de tareas y monitoreo.
--
--  CÓMO USAR ESTE ARCHIVO:
--    1. Trabaja PRIMERO sobre tu BASE DE DATOS DUPLICADA (no la principal).
--    2. Supabase Dashboard -> SQL Editor -> pega TODO este archivo -> Run.
--    3. Es 100% ADITIVO e IDEMPOTENTE: usa IF NOT EXISTS / CREATE OR REPLACE /
--       ON CONFLICT, así que puedes correrlo varias veces sin romper nada.
--    4. No elimina ni modifica datos de tus tablas existentes.
--
--  ORDEN: roles -> jerarquía -> horarios -> tareas -> avances -> asistencias
--         -> notificaciones -> funciones -> vistas -> índices -> RLS -> seed
-- ============================================================================


-- ============================================================================
-- SECCIÓN 1 — ROLES CONFIGURABLES (sistema "adaptativo")
--   En lugar de tocar el enum 'rol' (riesgoso), definimos los poderes de cada
--   rol como DATOS editables. Cambiar permisos = editar filas, no el esquema.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.roles_config (
  rol                    VARCHAR PRIMARY KEY,   -- debe COINCIDIR con el valor de tu enum profiles.rol
  nombre_display         VARCHAR NOT NULL,
  nivel                  INT NOT NULL,          -- 1=gerencia, 2=subgerencia, 3=jefe de rama, 4=operativo, 9=cliente
  area                   VARCHAR,               -- rama: construccion, topografia, arquitectura, etc.
  puede_delegar          BOOLEAN NOT NULL DEFAULT FALSE,  -- ¿puede crear y asignar tareas?
  puede_monitorear_todo  BOOLEAN NOT NULL DEFAULT FALSE,  -- ¿ve toda la empresa? (gerencia)
  color                  VARCHAR NOT NULL DEFAULT 'blue',
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================================
-- SECCIÓN 2 — JERARQUÍA / ORGANIGRAMA
--   Columna aditiva en profiles: a quién le reporta cada persona.
--   gerente -> NULL ; subgerente -> gerente ; jefe de rama -> subgerente ; etc.
-- ============================================================================
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS reporta_a UUID REFERENCES public.profiles(id);


-- ============================================================================
-- SECCIÓN 3 — HORARIOS (turnos disponibles que asigna la gerencia)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.horarios (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre       VARCHAR NOT NULL,
  hora_inicio  TIME NOT NULL,
  hora_fin     TIME NOT NULL,
  dias_semana  INT[] NOT NULL DEFAULT '{1,2,3,4,5}',  -- 1=lun ... 7=dom
  activo       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================================
-- SECCIÓN 4 — TAREAS (con delegación jerárquica)
--   tarea_padre_id  -> permite subtareas (un jefe de rama divide una tarea
--                      grande del gerente en subtareas para sus operativos).
--   delegado_por    -> quién delegó esta tarea (cadena de delegación).
--   area            -> rama a la que pertenece la tarea.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.tareas (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  obra_id        BIGINT NOT NULL REFERENCES public.obras(id) ON DELETE CASCADE,
  fase_id        BIGINT REFERENCES public.fases_obra(id) ON DELETE SET NULL,
  tarea_padre_id BIGINT REFERENCES public.tareas(id) ON DELETE CASCADE,
  asignado_a     UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  creado_por     UUID NOT NULL REFERENCES public.profiles(id),
  delegado_por   UUID REFERENCES public.profiles(id),
  titulo         VARCHAR NOT NULL,
  descripcion    TEXT,
  area           VARCHAR,
  estado         VARCHAR NOT NULL DEFAULT 'pendiente'
                   CHECK (estado IN ('pendiente','en_progreso','en_revision','completada','bloqueada')),
  prioridad      VARCHAR NOT NULL DEFAULT 'media'
                   CHECK (prioridad IN ('baja','media','alta','urgente')),
  fecha_inicio   DATE,
  fecha_entrega  DATE,
  porcentaje     NUMERIC NOT NULL DEFAULT 0 CHECK (porcentaje BETWEEN 0 AND 100),
  notas          TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================================
-- SECCIÓN 5 — AVANCES DE TAREAS (cada operativo sube su progreso + fotos)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.avance_tareas (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tarea_id        BIGINT NOT NULL REFERENCES public.tareas(id) ON DELETE CASCADE,
  obra_id         BIGINT NOT NULL REFERENCES public.obras(id),
  registrado_por  UUID NOT NULL REFERENCES public.profiles(id),
  porcentaje      NUMERIC NOT NULL CHECK (porcentaje BETWEEN 0 AND 100),
  descripcion     TEXT,
  fotos_urls      TEXT[],
  fecha           DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================================
-- SECCIÓN 6 — ASISTENCIAS (marcado con geolocalización / radio de 200 m)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.asistencias (
  id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  perfil_id         UUID NOT NULL REFERENCES public.profiles(id),
  obra_id           BIGINT NOT NULL REFERENCES public.obras(id),
  horario_id        BIGINT REFERENCES public.horarios(id) ON DELETE SET NULL,
  tipo              VARCHAR NOT NULL CHECK (tipo IN ('entrada','salida')),
  fecha             DATE NOT NULL DEFAULT CURRENT_DATE,
  hora              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  latitud           NUMERIC NOT NULL,
  longitud          NUMERIC NOT NULL,
  distancia_metros  NUMERIC,
  dentro_de_rango   BOOLEAN NOT NULL DEFAULT FALSE,
  estado            VARCHAR NOT NULL DEFAULT 'presente'
                      CHECK (estado IN ('presente','tardanza','inasistencia','justificada')),
  justificacion     TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (perfil_id, obra_id, fecha, tipo)
);


-- ============================================================================
-- SECCIÓN 7 — NOTIFICACIONES (historial de alertas push; usa profiles.fcm_token)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.notificaciones (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  perfil_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  tipo         VARCHAR NOT NULL,   -- 'tarea_asignada','avance','asistencia','pago'...
  titulo       VARCHAR NOT NULL,
  cuerpo       TEXT,
  leida        BOOLEAN NOT NULL DEFAULT FALSE,
  datos_extra  JSONB,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================================
-- SECCIÓN 8 — FUNCIONES DE APOYO (seguridad y cálculos)
-- ============================================================================

-- Rol del usuario actual (como texto)
CREATE OR REPLACE FUNCTION public.mi_rol()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT rol::text FROM public.profiles WHERE id = auth.uid();
$$;

-- ¿El usuario actual es gerencia? (puede monitorear toda la empresa)
CREATE OR REPLACE FUNCTION public.es_gerencia()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE((
    SELECT rc.puede_monitorear_todo
    FROM public.profiles p
    JOIN public.roles_config rc ON rc.rol = p.rol::text
    WHERE p.id = auth.uid()
  ), FALSE);
$$;

-- ¿El usuario actual puede delegar (crear/asignar) tareas?
CREATE OR REPLACE FUNCTION public.puedo_delegar()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE((
    SELECT rc.puede_delegar
    FROM public.profiles p
    JOIN public.roles_config rc ON rc.rol = p.rol::text
    WHERE p.id = auth.uid()
  ), FALSE);
$$;

-- Marcar asistencia validando el radio de 200 m EN EL SERVIDOR (anti-spoofing)
CREATE OR REPLACE FUNCTION public.marcar_asistencia(
  p_obra_id BIGINT, p_lat NUMERIC, p_lng NUMERIC,
  p_tipo VARCHAR, p_horario_id BIGINT DEFAULT NULL
) RETURNS public.asistencias LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_obra public.obras; v_dist NUMERIC; v_row public.asistencias;
BEGIN
  SELECT * INTO v_obra FROM public.obras WHERE id = p_obra_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Obra no encontrada'; END IF;
  v_dist := 6371000 * ACOS(LEAST(1,
    COS(RADIANS(v_obra.latitud)) * COS(RADIANS(p_lat)) * COS(RADIANS(p_lng) - RADIANS(v_obra.longitud))
    + SIN(RADIANS(v_obra.latitud)) * SIN(RADIANS(p_lat))));
  IF v_dist > 200 THEN
    RAISE EXCEPTION 'Estás a % m de la obra. Debes estar dentro de 200 m.', ROUND(v_dist);
  END IF;
  INSERT INTO public.asistencias (perfil_id, obra_id, horario_id, tipo, fecha, hora, latitud, longitud, distancia_metros, dentro_de_rango, estado)
  VALUES (auth.uid(), p_obra_id, p_horario_id, p_tipo, CURRENT_DATE, NOW(), p_lat, p_lng, v_dist, TRUE, 'presente')
  RETURNING * INTO v_row;
  RETURN v_row;
END; $$;

-- Porcentaje de avance total por obra (web y móvil usan el mismo cálculo)
CREATE OR REPLACE FUNCTION public.avance_total_obra(p_obra_id BIGINT)
RETURNS NUMERIC LANGUAGE sql STABLE AS $$
  SELECT COALESCE(
    SUM((SELECT COALESCE(MAX(a.porcentaje),0) FROM public.avance_obra a WHERE a.fase_id = f.id)
        * COALESCE(f.porcentaje_meta,100) / 100.0)
    / NULLIF(SUM(COALESCE(f.porcentaje_meta,100)),0), 0)
  FROM public.fases_obra f WHERE f.obra_id = p_obra_id;
$$;

-- Al asignar/cambiar una tarea, avisa al responsable (notificación)
CREATE OR REPLACE FUNCTION public.notificar_tarea()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.asignado_a IS NOT NULL AND
     (TG_OP = 'INSERT' OR NEW.asignado_a IS DISTINCT FROM OLD.asignado_a) THEN
    INSERT INTO public.notificaciones (perfil_id, tipo, titulo, cuerpo, datos_extra)
    VALUES (NEW.asignado_a, 'tarea_asignada', 'Nueva tarea asignada', NEW.titulo,
            jsonb_build_object('tarea_id', NEW.id, 'obra_id', NEW.obra_id));
  END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_notificar_tarea ON public.tareas;
CREATE TRIGGER trg_notificar_tarea
  AFTER INSERT OR UPDATE OF asignado_a ON public.tareas
  FOR EACH ROW EXECUTE FUNCTION public.notificar_tarea();


-- ============================================================================
-- SECCIÓN 9 — VISTAS DE MONITOREO (para gerencia/subgerencia)
-- ============================================================================

-- Resumen de cada obra: avance, tareas pendientes, responsable
CREATE OR REPLACE VIEW public.vista_monitoreo_obras AS
SELECT
  o.id, o.nombre, o.estado, o.tipo_servicio,
  public.avance_total_obra(o.id) AS avance_pct,
  (SELECT COUNT(*) FROM public.tareas t WHERE t.obra_id = o.id AND t.estado <> 'completada') AS tareas_abiertas,
  (SELECT COUNT(*) FROM public.tareas t WHERE t.obra_id = o.id) AS tareas_total,
  r.nombre AS residente_nombre
FROM public.obras o
LEFT JOIN public.profiles r ON r.id = o.residente_id;

-- Árbol de tareas: cada tarea con su responsable, quién delegó y su tarea padre
CREATE OR REPLACE VIEW public.vista_arbol_tareas AS
SELECT
  t.id, t.obra_id, t.tarea_padre_id, t.titulo, t.estado, t.prioridad,
  t.area, t.porcentaje, t.fecha_entrega,
  asig.nombre AS asignado_nombre, asig.rol::text AS asignado_rol,
  deleg.nombre AS delegado_por_nombre
FROM public.tareas t
LEFT JOIN public.profiles asig  ON asig.id  = t.asignado_a
LEFT JOIN public.profiles deleg ON deleg.id = t.delegado_por;


-- ============================================================================
-- SECCIÓN 10 — ÍNDICES (rendimiento en móvil)
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_tareas_asignado     ON public.tareas(asignado_a);
CREATE INDEX IF NOT EXISTS idx_tareas_obra         ON public.tareas(obra_id);
CREATE INDEX IF NOT EXISTS idx_tareas_padre        ON public.tareas(tarea_padre_id);
CREATE INDEX IF NOT EXISTS idx_avance_tareas_tarea ON public.avance_tareas(tarea_id);
CREATE INDEX IF NOT EXISTS idx_asistencias_perfil  ON public.asistencias(perfil_id, fecha);
CREATE INDEX IF NOT EXISTS idx_asistencias_obra    ON public.asistencias(obra_id, fecha);
CREATE INDEX IF NOT EXISTS idx_notif_perfil        ON public.notificaciones(perfil_id, leida);
CREATE INDEX IF NOT EXISTS idx_profiles_reporta_a  ON public.profiles(reporta_a);


-- ============================================================================
-- SECCIÓN 11 — SEGURIDAD RLS (OBLIGATORIO antes de usar la app)
--   Como el móvil habla directo con la base, la seguridad vive aquí.
-- ============================================================================
ALTER TABLE public.roles_config   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.horarios       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tareas         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.avance_tareas  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asistencias    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificaciones ENABLE ROW LEVEL SECURITY;

-- roles_config: todos leen; solo gerencia/admin escribe
DROP POLICY IF EXISTS roles_lectura ON public.roles_config;
CREATE POLICY roles_lectura ON public.roles_config FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS roles_escritura ON public.roles_config;
CREATE POLICY roles_escritura ON public.roles_config FOR ALL USING (public.es_gerencia());

-- horarios: todos leen; solo gerencia escribe
DROP POLICY IF EXISTS horarios_lectura ON public.horarios;
CREATE POLICY horarios_lectura ON public.horarios FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS horarios_escritura ON public.horarios;
CREATE POLICY horarios_escritura ON public.horarios FOR ALL USING (public.es_gerencia());

-- TAREAS:
--   ver  -> la tuya, la que creaste/delegaste, o TODO si eres gerencia
--   crear/asignar -> solo quien puede delegar (jefes y gerencia)
--   editar -> el responsable (sube avance/estado), el creador, o gerencia
DROP POLICY IF EXISTS tareas_ver ON public.tareas;
CREATE POLICY tareas_ver ON public.tareas FOR SELECT USING (
  asignado_a = auth.uid() OR creado_por = auth.uid() OR delegado_por = auth.uid() OR public.es_gerencia()
);
DROP POLICY IF EXISTS tareas_crear ON public.tareas;
CREATE POLICY tareas_crear ON public.tareas FOR INSERT WITH CHECK (
  public.puedo_delegar() AND creado_por = auth.uid()
);
DROP POLICY IF EXISTS tareas_editar ON public.tareas;
CREATE POLICY tareas_editar ON public.tareas FOR UPDATE USING (
  asignado_a = auth.uid() OR creado_por = auth.uid() OR public.es_gerencia()
);

-- AVANCE_TAREAS: ver propio/gerencia; insertar solo como uno mismo
DROP POLICY IF EXISTS avance_ver ON public.avance_tareas;
CREATE POLICY avance_ver ON public.avance_tareas FOR SELECT USING (
  registrado_por = auth.uid() OR public.es_gerencia()
  OR EXISTS (SELECT 1 FROM public.tareas t WHERE t.id = tarea_id
             AND (t.creado_por = auth.uid() OR t.delegado_por = auth.uid()))
);
DROP POLICY IF EXISTS avance_crear ON public.avance_tareas;
CREATE POLICY avance_crear ON public.avance_tareas FOR INSERT WITH CHECK (registrado_por = auth.uid());

-- ASISTENCIAS: ver la propia o gerencia ve todo (el insert va por el RPC)
DROP POLICY IF EXISTS asistencias_ver ON public.asistencias;
CREATE POLICY asistencias_ver ON public.asistencias FOR SELECT USING (
  perfil_id = auth.uid() OR public.es_gerencia()
);
DROP POLICY IF EXISTS asistencias_crear ON public.asistencias;
CREATE POLICY asistencias_crear ON public.asistencias FOR INSERT WITH CHECK (perfil_id = auth.uid());

-- NOTIFICACIONES: cada quien solo las suyas
DROP POLICY IF EXISTS notif_propias ON public.notificaciones;
CREATE POLICY notif_propias ON public.notificaciones FOR ALL USING (perfil_id = auth.uid());


-- ============================================================================
-- SECCIÓN 12 — SEED DE ROLES (la jerarquía LOZCAM)
--   AJUSTA la columna 'rol' para que coincida EXACTAMENTE con los valores de
--   tu enum profiles.rol. Si un nombre no coincide, ese rol no tendrá permisos.
--
--   Niveles: 1=Gerencia  2=Subgerencia  3=Jefe de rama  4=Operativo  9=Cliente
-- ============================================================================
INSERT INTO public.roles_config (rol, nombre_display, nivel, area, puede_delegar, puede_monitorear_todo, color) VALUES
  ('admin',       'Administrador del sistema', 1, NULL,            TRUE,  TRUE,  'gray'),
  ('gerente',     'Gerente General',           1, NULL,            TRUE,  TRUE,  'orange'),
  ('subgerente',  'Subgerente',                2, NULL,            TRUE,  TRUE,  'orange'),
  ('residente',   'Residente de Obra',         3, 'construccion',  TRUE,  FALSE, 'blue'),
  ('supervisor',  'Supervisor',                3, 'supervision',   TRUE,  FALSE, 'pink'),
  ('topografo',   'Topógrafo / Jefe Topografía',3,'topografia',    TRUE,  FALSE, 'blue'),
  ('arquitecto',  'Arquitecto',                3, 'arquitectura',  TRUE,  FALSE, 'green'),
  ('maestro_obra','Maestro de Obra',           4, 'construccion',  FALSE, FALSE, 'purple'),
  ('operario',    'Operario',                  4, 'construccion',  FALSE, FALSE, 'gray'),
  ('almacenero',  'Almacenero',                4, NULL,            FALSE, FALSE, 'gray'),
  ('cliente',     'Cliente',                   9, NULL,            FALSE, FALSE, 'green')
ON CONFLICT (rol) DO UPDATE SET
  nombre_display = EXCLUDED.nombre_display,
  nivel = EXCLUDED.nivel,
  area = EXCLUDED.area,
  puede_delegar = EXCLUDED.puede_delegar,
  puede_monitorear_todo = EXCLUDED.puede_monitorear_todo,
  color = EXCLUDED.color;

-- Horarios de ejemplo (opcional)
INSERT INTO public.horarios (nombre, hora_inicio, hora_fin, dias_semana) VALUES
  ('Turno mañana',     '07:00', '13:00', '{1,2,3,4,5,6}'),
  ('Turno tarde',      '13:00', '18:00', '{1,2,3,4,5}'),
  ('Jornada completa', '07:00', '17:00', '{1,2,3,4,5,6}')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- FIN DEL ESQUEMA. Verifica en Table Editor que aparezcan:
-- roles_config, horarios, tareas, avance_tareas, asistencias, notificaciones
-- ============================================================================
