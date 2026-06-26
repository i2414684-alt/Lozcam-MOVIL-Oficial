-- ============================================================================
--  POLÍTICAS RLS DE LECTURA — SUGERENCIA / REFERENCIA  (Lozcam Móvil)
--  Generado 2026-06-26.
--
--  ⚠️  ESTO ES UNA REFERENCIA. No se ha aplicado a ninguna base de datos.
--  Revísalo, pruébalo PRIMERO en tu BD duplicada y solo después en producción.
--
--  POR QUÉ EXISTE:
--  La app (gerencia, trabajador, cliente) muestra "0/0", coordenadas por
--  defecto o el chatbot "no da datos" cuando el RLS de la BD NO deja al usuario
--  autenticado hacer SELECT sobre estas tablas. Recuerda: con RLS HABILITADO y
--  SIN políticas, Postgres NIEGA todo por defecto. Estas políticas abren SOLO
--  la LECTURA que la app necesita, respetando el rol de cada quien.
--
--  ALCANCE: solo SELECT. No abre escritura (la asistencia se escribe por el RPC
--  `marcar_asistencia`, que es SECURITY DEFINER y no necesita política INSERT).
--
--  IDEMPOTENTE: usa `drop policy if exists` + `create policy`. Aditivo: no borra
--  datos ni columnas.
--
--  NOTA WEB: el backend Next.js que use la `service_role` key IGNORA el RLS, así
--  que estas políticas no lo afectan. Solo afectan a clientes con la anon/
--  publishable key (como esta app), que es justo lo que queremos arreglar.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 0) DIAGNÓSTICO (corre esto primero para ver el estado actual)
-- ----------------------------------------------------------------------------
-- ¿Qué tablas tienen RLS habilitado?
--   select relname, relrowsecurity
--   from pg_class
--   where relname in ('obras','profiles','asignaciones','asistencias','avance_obra');
--
-- ¿Qué políticas existen ya?
--   select tablename, policyname, cmd, roles
--   from pg_policies
--   where tablename in ('obras','profiles','asignaciones','asistencias','avance_obra')
--   order by tablename, policyname;
--
-- Valores reales del enum de rol:
--   select distinct rol from public.profiles;


-- ----------------------------------------------------------------------------
-- 1) FUNCIONES HELPER (SECURITY DEFINER -> evitan recursión de RLS)
--    `es_gerencia()` y `mi_rol()` YA EXISTEN en producción; se re-crean igual
--    por si acaso. Las cross-table (asignado / mi obra) son nuevas.
-- ----------------------------------------------------------------------------

create or replace function public.mi_rol()
returns text language sql stable security definer set search_path = public as $$
  select rol::text from public.profiles where id = auth.uid();
$$;

create or replace function public.es_gerencia()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(
    (select rol::text from public.profiles where id = auth.uid())
      in ('gerente_general','subgerente','administrador'),
    false);
$$;

-- ¿El usuario actual está asignado (activo) a esa obra?
create or replace function public.app_esta_asignado(p_obra_id bigint)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.asignaciones a
    where a.obra_id = p_obra_id
      and a.perfil_id = auth.uid()
      and coalesce(a.activo, true) = true
  );
$$;

-- ¿Esa obra pertenece al cliente del usuario actual?  (tipo-agnóstico)
create or replace function public.app_es_mi_obra(p_obra_id bigint)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.obras o
    join public.profiles p on p.id = auth.uid()
    where o.id = p_obra_id
      and o.cliente_id is not null
      and o.cliente_id = p.cliente_id
  );
$$;


-- ----------------------------------------------------------------------------
-- 2) PROFILES  (gerencia ve todos; cada quien su propio perfil)
--    La app lee profiles para: monitor de gerencia, equipo, nombres del chatbot.
-- ----------------------------------------------------------------------------
-- alter table public.profiles enable row level security;  -- (suele YA estar on)

drop policy if exists profiles_self_select on public.profiles;
create policy profiles_self_select on public.profiles
  for select to authenticated
  using (id = auth.uid());

drop policy if exists profiles_gerencia_select on public.profiles;
create policy profiles_gerencia_select on public.profiles
  for select to authenticated
  using (public.es_gerencia());


-- ----------------------------------------------------------------------------
-- 3) OBRAS  (coordenadas del mapa, lista de obras)
--    Opción A (recomendada, simple): cualquier usuario autenticado lee las
--    obras activas. Es una app interna; evita el caso "trabajador sin
--    asignación no ve ninguna obra".
-- ----------------------------------------------------------------------------
-- alter table public.obras enable row level security;

drop policy if exists obras_auth_select on public.obras;
create policy obras_auth_select on public.obras
  for select to authenticated
  using (coalesce(activo, true) = true);

-- Opción B (estricta) — si prefieres que cada quien vea SOLO lo suyo, BORRA la
-- política A de arriba y usa estas tres en su lugar:
--
-- drop policy if exists obras_gerencia_select on public.obras;
-- create policy obras_gerencia_select on public.obras
--   for select to authenticated using (public.es_gerencia());
--
-- drop policy if exists obras_asignado_select on public.obras;
-- create policy obras_asignado_select on public.obras
--   for select to authenticated using (public.app_esta_asignado(id));
--
-- drop policy if exists obras_cliente_select on public.obras;
-- create policy obras_cliente_select on public.obras
--   for select to authenticated
--   using (cliente_id is not null
--          and cliente_id = (select p.cliente_id from public.profiles p
--                            where p.id = auth.uid()));


-- ----------------------------------------------------------------------------
-- 4) ASIGNACIONES  (conteos del monitor, obras del trabajador, contexto chatbot)
-- ----------------------------------------------------------------------------
-- alter table public.asignaciones enable row level security;

drop policy if exists asignaciones_self_select on public.asignaciones;
create policy asignaciones_self_select on public.asignaciones
  for select to authenticated
  using (perfil_id = auth.uid());

drop policy if exists asignaciones_gerencia_select on public.asignaciones;
create policy asignaciones_gerencia_select on public.asignaciones
  for select to authenticated
  using (public.es_gerencia());


-- ----------------------------------------------------------------------------
-- 5) ASISTENCIAS  (historial del trabajador, presentes hoy, monitor, chatbot)
--    Solo LECTURA. La escritura va por el RPC `marcar_asistencia` (definer).
-- ----------------------------------------------------------------------------
-- alter table public.asistencias enable row level security;

drop policy if exists asistencias_self_select on public.asistencias;
create policy asistencias_self_select on public.asistencias
  for select to authenticated
  using (perfil_id = auth.uid());

drop policy if exists asistencias_gerencia_select on public.asistencias;
create policy asistencias_gerencia_select on public.asistencias
  for select to authenticated
  using (public.es_gerencia());

-- (Opcional) Si tu RPC `marcar_asistencia` NO fuera SECURITY DEFINER y diera
-- error de permiso al marcar, habilita el INSERT del propio trabajador:
-- drop policy if exists asistencias_self_insert on public.asistencias;
-- create policy asistencias_self_insert on public.asistencias
--   for insert to authenticated with check (perfil_id = auth.uid());


-- ----------------------------------------------------------------------------
-- 6) AVANCE_OBRA  (panel/informes del cliente y avance que ve el chatbot)
-- ----------------------------------------------------------------------------
-- alter table public.avance_obra enable row level security;

drop policy if exists avance_gerencia_select on public.avance_obra;
create policy avance_gerencia_select on public.avance_obra
  for select to authenticated
  using (public.es_gerencia());

drop policy if exists avance_asignado_select on public.avance_obra;
create policy avance_asignado_select on public.avance_obra
  for select to authenticated
  using (public.app_esta_asignado(obra_id));

drop policy if exists avance_cliente_select on public.avance_obra;
create policy avance_cliente_select on public.avance_obra
  for select to authenticated
  using (public.app_es_mi_obra(obra_id));


-- ----------------------------------------------------------------------------
-- 7) VERIFICACIÓN (después de aplicar, prueba como cada rol)
-- ----------------------------------------------------------------------------
-- Inicia sesión en la app con un trabajador y mira el mapa (debe centrar en su
-- obra), con un gerente y abre el chatbot ("¿cuántos faltaron hoy?"), y con un
-- cliente su panel. Si el banner ámbar "Revisa los permisos (RLS)" desaparece,
-- las lecturas quedaron habilitadas.
--
-- En SQL Editor puedes simular un usuario:
--   set local role authenticated;
--   set local request.jwt.claim.sub = '<uuid-del-usuario>';
--   select id, nombre, latitud, longitud from public.obras;  -- ¿devuelve filas?
--   reset role;
-- ============================================================================
