-- =====================================================================
-- TAG OK 2.0 · Script completo de la base de datos
-- =====================================================================
--
-- Arma la base de datos desde cero, tal como está implementada. Es la unión,
-- en orden, de las 17 migraciones de Producto/supabase/migrations/, que son
-- la fuente de verdad: este archivo se genera a partir de ellas.
--
-- CÓMO USARLO
--   1. Crea un proyecto nuevo y VACÍO en Supabase.
--   2. Abre el SQL Editor, pega este archivo completo y ejecútalo una sola vez.
--   3. Crea el primer administrador (ver el final de la sección 0003).
--
-- Requiere un proyecto de Supabase: usa sus esquemas auth y storage y sus roles.
-- No se puede ejecutar dos veces sobre la misma base (las tablas ya existirían).
--
-- CONTENIDO
--   Tablas (14):  usuarios, administradores, vehiculos, vehiculo_documentos,
--                 trips, combustible_cargas, audited_invoices, porticos, tarifas,
--                 auditoria, beneficios, mantenciones, estacionamientos,
--                 mantenciones_programadas
--   Además:       funciones is_admin / is_super_admin, trigger de creación de
--                 perfil, políticas de seguridad por fila (RLS), tiempo real,
--                 carga inicial de pórticos y 6 buckets de almacenamiento.
--
-- ÍNDICE DE SECCIONES
--    1. 0001_init_schema.sql
--    2. 0002_profile_trigger.sql
--    3. 0003_rls.sql
--    4. 0004_fix_combustible_rls.sql
--    5. 0005_nuevos_modulos.sql
--    6. 0006_enable_realtime.sql
--    7. 0007_seed_porticos.sql
--    8. 0008_avatar_storage.sql
--    9. 0009_vehiculo_foto_y_documento_ia.sql
--   10. 0010_usuarios_delete_super_admin.sql
--   11. 0011_combustible_energia.sql
--   12. 0012_mantenciones_detalle.sql
--   13. 0013_estacionamientos_detalle.sql
--   14. 0014_beneficios_backoffice.sql
--   15. 0015_beneficios_categorias_y_canje.sql
--   16. 0016_combustible_comprobante.sql
--   17. 0017_estado_cuenta_y_auditoria.sql
-- =====================================================================

-- =====================================================================
-- SECCIÓN 1 de 17 · 0001_init_schema.sql
-- =====================================================================

-- TAG-OK: esquema inicial Postgres (migración desde Firestore)
-- Ver plan: C:\Users\diego\.claude\plans\joyful-noodling-pine.md

create extension if not exists "pgcrypto";

-- usuarios: fila de perfil 1:1 con auth.users
create table public.usuarios (
  id                          uuid primary key references auth.users(id) on delete cascade,
  email                       text not null,
  nombre_mostrar              text,
  telefono                    text,
  fecha_creacion              timestamptz not null default now(),
  -- antes "vehiculo_principal_id"; en realidad siempre guardó una patente, no un id
  vehiculo_principal_patente  text,
  limite_presupuesto_mensual  numeric(12,2) not null default 0,
  notif_cobros                boolean not null default true,
  notif_presupuesto           boolean not null default true,
  alertas_vistas              jsonb not null default '{}'::jsonb
);

comment on column public.usuarios.vehiculo_principal_patente is
  'Guarda una patente (string), no un id de vehiculo -- coincide con el comportamiento legacy.';

-- administradores: tabla de roles de backoffice
create table public.administradores (
  id              uuid primary key references auth.users(id) on delete cascade,
  email           text not null,
  -- 'operador' es el rol de administrador normal (no elevado); coincide con
  -- el vocabulario ya usado en admin/lib/main.dart, distinto de 'super_admin'
  rol             text not null default 'operador' check (rol in ('operador', 'super_admin')),
  fecha_creacion  timestamptz not null default now()
);

-- vehiculos
create table public.vehiculos (
  id                uuid primary key default gen_random_uuid(),
  usuario_id        uuid not null references public.usuarios(id) on delete cascade,
  patente           text not null,
  categoria         text not null default 'AUTO' check (categoria in ('AUTO', 'CAMIONETA', 'MOTO')),
  marca             text not null default 'No especificada',
  modelo            text,
  anio              integer,
  tipo_combustible  text check (tipo_combustible in ('Bencina', 'Diésel', 'Híbrido', 'Eléctrico')),
  kilometraje       numeric,
  alias             text,
  fecha_ingreso     timestamptz not null default now(),
  created_at        timestamptz not null default now(),
  unique (usuario_id, patente)
);

create index vehiculos_usuario_id_idx on public.vehiculos (usuario_id);
create index vehiculos_patente_idx on public.vehiculos (patente);

-- vehiculo_documentos (antes vehiculos/{id}/documentos/{tipo})
create table public.vehiculo_documentos (
  id                    uuid primary key default gen_random_uuid(),
  vehiculo_id           uuid not null references public.vehiculos(id) on delete cascade,
  tipo                  text not null check (tipo in ('permiso_circulacion', 'revision_tecnica', 'soap', 'seguro')),
  numero                text,
  fecha_emision         timestamptz,
  fecha_vencimiento     timestamptz,
  compania              text,
  fecha_actualizacion   timestamptz not null default now(),
  unique (vehiculo_id, tipo)
);

create index vehiculo_documentos_vehiculo_id_idx on public.vehiculo_documentos (vehiculo_id);

-- trips (antes usuarios/{uid}/trips/{tripId})
create table public.trips (
  id            uuid primary key default gen_random_uuid(),
  usuario_id    uuid not null references public.usuarios(id) on delete cascade,
  date          timestamptz not null,
  total_cost    numeric(12,2) not null default 0,
  distance_km   numeric not null default 0,
  duration      text,
  vehicle_name  text,
  -- array embebido {name, cost, timestamp}; ver plan (Decision Points) sobre normalizar despues
  tolls         jsonb not null default '[]'::jsonb,
  created_at    timestamptz not null default now()
);

create index trips_usuario_id_date_idx on public.trips (usuario_id, date desc);

-- combustible_cargas (antes usuarios/{uid}/combustible/{id})
create table public.combustible_cargas (
  id                uuid primary key default gen_random_uuid(),
  usuario_id        uuid not null references public.usuarios(id) on delete cascade,
  vehiculo_id       uuid references public.vehiculos(id) on delete set null,
  vehiculo_patente  text,
  fecha             timestamptz not null,
  kilometraje       numeric,
  estacion          text,
  tipo_combustible  text,
  litros            numeric(10,2) not null default 0,
  precio_litro      numeric(10,2) not null default 0,
  total             numeric(12,2) not null default 0,
  created_at        timestamptz not null default now()
);

create index combustible_cargas_usuario_id_idx on public.combustible_cargas (usuario_id);
create index combustible_cargas_vehiculo_id_idx on public.combustible_cargas (vehiculo_id);

-- audited_invoices (antes usuarios/{uid}/audited_invoices/{id})
create table public.audited_invoices (
  id                    uuid primary key default gen_random_uuid(),
  usuario_id            uuid not null references public.usuarios(id) on delete cascade,
  concessionaire        text,
  period                text,
  patent                text,
  total_billed          numeric(12,2) not null default 0,
  total_matched         numeric(12,2) not null default 0,
  status                text,
  reconciliation_rate   numeric(5,2) not null default 0,
  upload_date           timestamptz not null default now(),
  details               jsonb not null default '[]'::jsonb,
  ai_report             text,
  audited_by            text,
  created_at            timestamptz not null default now()
);

create index audited_invoices_usuario_id_idx on public.audited_invoices (usuario_id, upload_date desc);

-- porticos: una sola forma canonica (fix del mismatch GeoPoint vs lat/lng
-- entre portico_model.dart y el seed real de admin_service.dart)
create table public.porticos (
  id                    uuid primary key default gen_random_uuid(),
  nombre                text not null,
  autopista             text,
  lat                   double precision not null,
  lng                   double precision not null,
  costo                 numeric(10,2) not null default 0,
  costo_punta           numeric(10,2),
  costo_saturacion      numeric(10,2),
  sentido               text,
  grupo                 text,
  secuencia             text,
  fecha_actualizacion   timestamptz not null default now()
);

-- tarifas: esquema real desconocido hoy (sin escritor encontrado); jsonb flexible
create table public.tarifas (
  id                    uuid primary key default gen_random_uuid(),
  nombre                text,
  datos                 jsonb not null default '{}'::jsonb,
  fecha_actualizacion   timestamptz not null default now()
);

-- auditoria: log de acciones admin, insert/select unicamente
create table public.auditoria (
  id            uuid primary key default gen_random_uuid(),
  fecha         timestamptz not null default now(),
  admin_email   text,
  action        text not null,
  target        text,
  details       text
);

create index auditoria_fecha_idx on public.auditoria (fecha desc);

-- beneficios: sin uso real en codigo hoy; se mantiene como placeholder vacio
create table public.beneficios (
  id                    uuid primary key default gen_random_uuid(),
  nombre                text,
  descripcion           text,
  fecha_actualizacion   timestamptz not null default now()
);

-- NOTA: "alertas" no se crea intencionalmente -- cero escritores en todo
-- el codigo actual (solo un conteo muerto en admin_firestore_service.dart).

-- =====================================================================
-- SECCIÓN 2 de 17 · 0002_profile_trigger.sql
-- =====================================================================

-- Crea automaticamente la fila de public.usuarios cuando se registra un
-- nuevo usuario en auth.users. Reemplaza el segundo insert que hacia
-- AuthRepository.signUpWithEmailAndPassword del lado del cliente.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.usuarios (id, email, nombre_mostrar, telefono, limite_presupuesto_mensual)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'nombre_mostrar',
    new.raw_user_meta_data ->> 'telefono',
    50000.00
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =====================================================================
-- SECCIÓN 3 de 17 · 0003_rls.sql
-- =====================================================================

-- Row Level Security: replica (y corrige) la semantica de
-- firestore.rules / storage.rules de la version Firebase.

-- ── Funciones helper ──────────────────────────────────────────
-- security definer para poder leer administradores sin recursion de RLS.
create or replace function public.is_admin(uid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.administradores a where a.id = uid);
$$;

-- A diferencia de adminRole() en firestore.rules (que caia a 'super_admin'
-- por defecto si faltaba el campo rol/role), aqui NO hay rama por defecto:
-- sin fila o con rol <> 'super_admin' siempre evalua a false.
create or replace function public.is_super_admin(uid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.administradores a
    where a.id = uid and a.rol = 'super_admin'
  );
$$;

-- ── Habilitar RLS ─────────────────────────────────────────────
alter table public.usuarios enable row level security;
alter table public.administradores enable row level security;
alter table public.vehiculos enable row level security;
alter table public.vehiculo_documentos enable row level security;
alter table public.trips enable row level security;
alter table public.combustible_cargas enable row level security;
alter table public.audited_invoices enable row level security;
alter table public.porticos enable row level security;
alter table public.tarifas enable row level security;
alter table public.beneficios enable row level security;
alter table public.auditoria enable row level security;

-- ── usuarios: dueño-o-admin ───────────────────────────────────
create policy usuarios_select on public.usuarios
  for select using (id = auth.uid() or is_admin());
create policy usuarios_insert on public.usuarios
  for insert with check (id = auth.uid());
create policy usuarios_update on public.usuarios
  for update using (id = auth.uid() or is_admin()) with check (id = auth.uid() or is_admin());
create policy usuarios_delete on public.usuarios
  for delete using (is_admin());

-- ── administradores: self-o-superadmin lee, superadmin-only escribe ──
create policy administradores_select on public.administradores
  for select using (id = auth.uid() or is_super_admin());
create policy administradores_insert on public.administradores
  for insert with check (is_super_admin());
create policy administradores_update on public.administradores
  for update using (is_super_admin()) with check (is_super_admin());
create policy administradores_delete on public.administradores
  for delete using (is_super_admin());

-- ── vehiculos: dueño-o-admin (FK uuid real, sin ambiguedad Reference/string) ──
create policy vehiculos_select on public.vehiculos
  for select using (usuario_id = auth.uid() or is_admin());
create policy vehiculos_insert on public.vehiculos
  for insert with check (usuario_id = auth.uid());
create policy vehiculos_update on public.vehiculos
  for update using (usuario_id = auth.uid() or is_admin()) with check (usuario_id = auth.uid() or is_admin());
create policy vehiculos_delete on public.vehiculos
  for delete using (usuario_id = auth.uid() or is_admin());

-- ── vehiculo_documentos: dueño via el vehiculo padre ──────────
create policy vehiculo_documentos_all on public.vehiculo_documentos
  for all using (
    is_admin() or exists (
      select 1 from public.vehiculos v
      where v.id = vehiculo_documentos.vehiculo_id and v.usuario_id = auth.uid()
    )
  ) with check (
    is_admin() or exists (
      select 1 from public.vehiculos v
      where v.id = vehiculo_documentos.vehiculo_id and v.usuario_id = auth.uid()
    )
  );

-- ── trips, combustible_cargas, audited_invoices: dueño-o-admin ──
create policy trips_all on public.trips
  for all using (usuario_id = auth.uid() or is_admin()) with check (usuario_id = auth.uid() or is_admin());

-- combustible_cargas: dueño-o-admin, y ademas el vehiculo_id (si viene) debe
-- pertenecer al mismo usuario (mismo patron que vehiculo_documentos_all)
create policy combustible_cargas_all on public.combustible_cargas
  for all using (
    is_admin() or (
      usuario_id = auth.uid() and (
        vehiculo_id is null or exists (
          select 1 from public.vehiculos v
          where v.id = combustible_cargas.vehiculo_id and v.usuario_id = auth.uid()
        )
      )
    )
  ) with check (
    is_admin() or (
      usuario_id = auth.uid() and (
        vehiculo_id is null or exists (
          select 1 from public.vehiculos v
          where v.id = combustible_cargas.vehiculo_id and v.usuario_id = auth.uid()
        )
      )
    )
  );

create policy audited_invoices_all on public.audited_invoices
  for all using (usuario_id = auth.uid() or is_admin()) with check (usuario_id = auth.uid() or is_admin());

-- ── porticos / tarifas / beneficios: lectura-todo-autenticado, escritura-admin ──
create policy porticos_select on public.porticos for select using (auth.role() = 'authenticated');
create policy porticos_insert on public.porticos for insert with check (is_admin());
create policy porticos_update on public.porticos for update using (is_admin()) with check (is_admin());
create policy porticos_delete on public.porticos for delete using (is_admin());

create policy tarifas_select on public.tarifas for select using (auth.role() = 'authenticated');
create policy tarifas_insert on public.tarifas for insert with check (is_admin());
create policy tarifas_update on public.tarifas for update using (is_admin()) with check (is_admin());
create policy tarifas_delete on public.tarifas for delete using (is_admin());

create policy beneficios_select on public.beneficios for select using (auth.role() = 'authenticated');
create policy beneficios_insert on public.beneficios for insert with check (is_admin());
create policy beneficios_update on public.beneficios for update using (is_admin()) with check (is_admin());
create policy beneficios_delete on public.beneficios for delete using (is_admin());

-- ── auditoria: admin create/read; sin update/delete == imposible para
-- cualquier rol de cliente (equivalente a "allow update, delete: if false") ──
create policy auditoria_select on public.auditoria for select using (is_admin());
create policy auditoria_insert on public.auditoria for insert with check (is_admin());

-- ── Bootstrap: el primer super_admin no puede crearse desde la app,
-- porque administradores_insert exige is_super_admin(). Ejecutar una vez
-- a mano desde el SQL editor de Supabase, con un usuario ya creado en
-- Authentication > Users:
--
-- insert into public.administradores (id, email, rol)
-- values ('<uid-del-usuario>', 'tu@email.com', 'super_admin');

-- =====================================================================
-- SECCIÓN 4 de 17 · 0004_fix_combustible_rls.sql
-- =====================================================================

-- combustible_cargas_all solo validaba usuario_id = auth.uid(), a diferencia
-- de vehiculo_documentos_all (que ademas valida que el vehiculo referenciado
-- pertenezca al usuario). Esto permitia insertar una carga de combustible
-- con un vehiculo_id ajeno mientras usuario_id fuera el propio.

drop policy if exists combustible_cargas_all on public.combustible_cargas;

create policy combustible_cargas_all on public.combustible_cargas
  for all using (
    is_admin() or (
      usuario_id = auth.uid() and (
        vehiculo_id is null or exists (
          select 1 from public.vehiculos v
          where v.id = combustible_cargas.vehiculo_id and v.usuario_id = auth.uid()
        )
      )
    )
  ) with check (
    is_admin() or (
      usuario_id = auth.uid() and (
        vehiculo_id is null or exists (
          select 1 from public.vehiculos v
          where v.id = combustible_cargas.vehiculo_id and v.usuario_id = auth.uid()
        )
      )
    )
  );

-- =====================================================================
-- SECCIÓN 5 de 17 · 0005_nuevos_modulos.sql
-- =====================================================================

-- Migración para los nuevos módulos de la Fase 2: Mantenciones, Estacionamientos y Beneficios (ampliado)

-- ── 1. Tabla: mantenciones ──────────────────────────────────────────
create table public.mantenciones (
  id            uuid primary key default gen_random_uuid(),
  usuario_id    uuid not null references public.usuarios(id) on delete cascade,
  vehiculo_id   uuid not null references public.vehiculos(id) on delete cascade,
  fecha         timestamptz not null,
  kilometraje   numeric,
  tipo          text check (tipo in ('preventiva', 'aceite', 'frenos', 'neumaticos', 'otra')),
  taller        text,
  costo         numeric(12,2) not null default 0,
  descripcion   text,
  ai_report     text,
  created_at    timestamptz not null default now()
);

create index mantenciones_usuario_id_idx on public.mantenciones(usuario_id);
create index mantenciones_vehiculo_id_idx on public.mantenciones(vehiculo_id);

alter table public.mantenciones enable row level security;

-- RLS: Dueño-o-admin. Además valida que el vehiculo_id pertenezca al usuario.
create policy mantenciones_all on public.mantenciones
  for all using (
    is_admin() or (
      usuario_id = auth.uid() and exists (
        select 1 from public.vehiculos v
        where v.id = mantenciones.vehiculo_id and v.usuario_id = auth.uid()
      )
    )
  ) with check (
    is_admin() or (
      usuario_id = auth.uid() and exists (
        select 1 from public.vehiculos v
        where v.id = mantenciones.vehiculo_id and v.usuario_id = auth.uid()
      )
    )
  );

-- ── 2. Tabla: estacionamientos ──────────────────────────────────────
create table public.estacionamientos (
  id            uuid primary key default gen_random_uuid(),
  usuario_id    uuid not null references public.usuarios(id) on delete cascade,
  vehiculo_id   uuid not null references public.vehiculos(id) on delete cascade,
  fecha         timestamptz not null,
  lugar         text,
  lat           double precision,
  lng           double precision,
  hora_entrada  timestamptz,
  hora_salida   timestamptz,
  costo         numeric(12,2) not null default 0,
  ai_report     text,
  created_at    timestamptz not null default now()
);

create index estacionamientos_usuario_id_idx on public.estacionamientos(usuario_id);
create index estacionamientos_vehiculo_id_idx on public.estacionamientos(vehiculo_id);

alter table public.estacionamientos enable row level security;

-- RLS: Dueño-o-admin.
create policy estacionamientos_all on public.estacionamientos
  for all using (
    is_admin() or (
      usuario_id = auth.uid() and exists (
        select 1 from public.vehiculos v
        where v.id = estacionamientos.vehiculo_id and v.usuario_id = auth.uid()
      )
    )
  ) with check (
    is_admin() or (
      usuario_id = auth.uid() and exists (
        select 1 from public.vehiculos v
        where v.id = estacionamientos.vehiculo_id and v.usuario_id = auth.uid()
      )
    )
  );

-- ── 3. Ampliar tabla: beneficios ────────────────────────────────────
-- Se añaden los campos requeridos para el catálogo completo y backoffice
alter table public.beneficios
  add column imagen text,
  add column categoria text,
  add column ubicacion text,
  add column vigencia_desde timestamptz,
  add column vigencia_hasta timestamptz,
  add column condiciones text,
  add column destacado boolean not null default false,
  add column activo boolean not null default true;

-- NOTA: La tabla beneficios ya tiene políticas de RLS en 0003_rls.sql
-- (lectura pública para autenticados, escritura para admins) por lo que 
-- no se requieren nuevas políticas.

-- =====================================================================
-- SECCIÓN 6 de 17 · 0006_enable_realtime.sql
-- =====================================================================

-- Supabase NO habilita Realtime automáticamente al crear una tabla; hay que
-- agregarla explícitamente a la publicación "supabase_realtime". Todas las
-- pantallas que usan .stream() (StreamBuilder en Flutter) dependen de esto.
-- Descubierto en vivo: el dashboard de admin fallaba con
-- "RealtimeSubscribeException ... Please check Realtime is enabled" porque
-- la tabla "trips" nunca se agregó a la publicación.
--
-- El bloque DO evita que el script falle si una tabla ya estaba agregada
-- (por ejemplo, si el proyecto la activó a mano desde el dashboard), y
-- también si la tabla todavía no existe (mantenciones/estacionamientos
-- vienen de 0005_nuevos_modulos.sql, que puede no haberse corrido aún).
do $$
declare
  t text;
begin
  foreach t in array array[
    'usuarios',
    'vehiculos',
    'vehiculo_documentos',
    'trips',
    'combustible_cargas',
    'audited_invoices',
    'porticos',
    'tarifas',
    'auditoria',
    'administradores',
    'beneficios',
    'mantenciones',
    'estacionamientos'
  ] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception
      when duplicate_object then
        -- ya estaba agregada a la publicación, no hacer nada
        null;
      when undefined_table then
        -- la tabla aún no existe (ej. 0005 no se ha corrido); se omite
        raise notice 'Tabla % no existe todavía, se omite.', t;
    end;
  end loop;
end $$;

-- =====================================================================
-- SECCIÓN 7 de 17 · 0007_seed_porticos.sql
-- =====================================================================

-- Carga inicial de los pórticos reales en public.porticos.
--
-- Hasta ahora la app calculaba los peajes con una lista escrita en el código
-- (tag_ok/lib/data/mock/tolls_database.dart), así que lo que el admin editaba
-- en la tabla porticos no tenía efecto en los cálculos. Desde este cambio la
-- app lee esta tabla; la lista local queda solo como respaldo sin conexión.
--
-- Se excluyen los 2 "Pórticos de Prueba Local" (grupo 'Prueba') de la lista
-- local. Solo inserta si la tabla está vacía, para no duplicar ni pisar
-- tarifas que el admin ya haya editado.

insert into public.porticos
  (nombre, autopista, lat, lng, costo, costo_punta, costo_saturacion, sentido, grupo, secuencia)
select v.*
from (values
  ('P3 Ruta 68 - Costanera Norte', 'Vespucio Norte', -33.4387137, -70.7831378, 351.71, 703.42, 703.42, 'P-O', 'Anillo', '3'),
  ('P14 Guanaco - El Salto', 'Vespucio Norte', -33.3886039, -70.6333164, 483.35, 966.7, 966.7, 'P-O', 'Anillo', '14'),
  ('PA32 Las Acacias - Lo Blanco', 'Autopista Central', -33.5588804, -70.7105862, 176.67, 353.34, 530.01, 'N-S', 'Norte-Sur', '32'),
  ('P0 Puente Padre Arteaga - P. San Francisco', 'Costanera Norte', -33.3710033, -70.52258, 149.8, 288.4, 436.8, 'O-P', 'Oriente-Poniente', '1'),
  ('PA28 Río Mapocho - Ruta 5 Norte', 'Autopista Central', -33.3822386, -70.6955624, 512.34, 1024.69, 1537.04, 'S-N', 'Norte-Sur', '28'),
  ('PA16 Río Mapocho - 14 de la Fama', 'Autopista Central', -33.4171865, -70.6787232, 425.04, 850.1, 850.1, 'S-N', 'Norte-Sur', '16'),
  ('PA2 Los Guindos - La Capilla', 'Autopista Central', -33.6473389, -70.7116107, 868.37, null, null, 'S-N', 'Norte-Sur', '2'),
  ('P102 Kennedy - El salto', 'Túnel San Cristóbal', -33.3988003, -70.6151323, 449.4, 865.2, 1310.4, 'S-N', 'Túnel', '102'),
  ('PA17 14 de la Fama - A.Vespucio Norte', 'Autopista Central', -33.3685816, -70.6991042, 462.46, 924.92, 924.92, 'S-N', 'Norte-Sur', '17'),
  ('P7 Las Tranqueras - Estoril', 'Costanera Norte', -33.3876805, -70.5429258, 250.21, 481.73, 729.61, 'P-O', 'Oriente-Poniente', '1'),
  ('PA7 Las Acacias - A. Vespucio', 'Autopista Central', -33.5478986, -70.6970069, 452.06, 904.14, 904.14, 'S-N', 'Norte-Sur', '7'),
  ('PA8 A. Vespucio - Las Acacias', 'Autopista Central', -33.5476268, -70.696839, 452.06, 904.14, 904.14, 'N-S', 'Norte-Sur', '8'),
  ('P5 Vivaceta - Carrascal', 'Costanera Norte', -33.4264381, -70.669833, 715.83, 1378.14, 1378.14, 'O-P', 'Oriente-Poniente', '1'),
  ('P2.2 Puente Lo Saldes - Centenario', 'Costanera Norte', -33.3944443, -70.6033861, 264.29, 508.82, 770.64, 'P-O', 'Oriente-Poniente', '22'),
  ('P1 Puente San Francisco - Gran Vía', 'Costanera Norte', -33.3758198, -70.5426489, 449.4, 865.2, 1310.4, 'O-P', 'Oriente-Poniente', '1'),
  ('P8.1 Las Tranqueras - Costanera Norte', 'Costanera Norte', -33.4081406, -70.5997632, 583.84, 1124.03, 1702.42, 'O-P', 'Oriente-Poniente', '8'),
  ('PA31 Carlos Valdovinos - Alameda', 'Autopista Central', -33.469011, -70.6562428, 368.93, 737.86, 1106.79, 'S-N', 'Norte-Sur', '8'),
  ('P1 Ruta 78 - Santa Elena', 'Vespucio Norte', -33.483359, -70.7530939, 120.59, 241.17, 361.76, 'P-O', 'Anillo', '1'),
  ('PA20 A. Vespucio - Ruta 5 Sur', 'Autopista Central', -33.5364729, -70.7076591, 412.57, null, null, 'N-S', 'Norte-Sur', '20'),
  ('P17 Los Mares - Ruta 78', 'Vespucio Norte', -33.4828675, -70.7535733, 391.91, 783.81, 1175.72, 'O-P', 'Anillo', '17'),
  ('Padre Hurtado', null, -33.5528306, -70.8139017, 350.0, null, null, null, null, null),
  ('P5 Carrascal - Vivaceta', 'Costanera Norte', -33.426442, -70.6701402, 715.83, 1378.14, 2087.28, 'P-O', 'Oriente-Poniente', '0'),
  ('P8.0 Las Tranqueras - Costanera Norte', 'Costanera Norte', -33.4080729, -70.599764, 583.84, 1124.03, 1702.42, 'O-P', 'Oriente-Poniente', '8'),
  ('P8.0 Las Tranqueras - Costanera Norte', 'Costanera Norte', -33.40909, -70.6043271, 583.84, 1124.03, 1702.42, 'O-P', 'Oriente-Poniente', '8'),
  ('P8.1 Las Tranqueras - Costanera Norte', 'Costanera Norte', -33.4090708, -70.6038986, 583.84, 1124.03, 1702.42, 'O-P', 'Oriente-Poniente', '8'),
  ('PA12 Alameda - C. Valdovinos', 'Autopista Central', -33.468848, -70.6565584, 368.93, 737.86, 1106.79, 'N-S', 'Norte-Sur', '8'),
  ('PA13 Alameda - Río Mapocho', 'Autopista Central', -33.4489228, -70.6595919, 181.86, 363.73, 545.6, 'S-N', 'Norte-Sur', '13'),
  ('PA14 Río Mapocho - Alameda', 'Autopista Central', -33.4483818, -70.6600861, 181.86, 363.73, 545.6, 'N-S', 'Norte-Sur', '14'),
  ('PA18 A. Vespucio Norte - 14 de la Fama', 'Autopista Central', -33.3682982, -70.6994258, 462.46, 924.92, 1387.38, 'N-S', 'Norte-Sur', '18'),
  ('PA19 Ruta 5 Sur - A. Vespucio', 'Autopista Central', -33.5514043, -70.7090613, 412.57, null, null, 'S-N', 'Norte-Sur', '19'),
  ('P4.3 Coronel - Santa Julia', 'Vespucio Sur', -33.5411449, -70.6149956, 472.3, 944.6, 1416.89, 'O-P', 'Anillo', '43'),
  ('P4.2 Gnmo. de Alderete - Vicuña Mackena', 'Vespucio Sur', -33.5268018, -70.6025742, 472.3, 944.6, 1416.89, 'O-P', 'Anillo', '42'),
  ('P1.3 2a Transversal - Camino a Melipilla', 'Vespucio Sur', -33.5058611, -70.728455, 532.59, 1065.18, 1597.78, 'P-O', 'Anillo', '13'),
  ('P1.1 Camino a Melipilla - 2a Transversal', 'Vespucio Sur', -33.5165613, -70.7125335, 532.59, 1065.18, 1597.78, 'O-P', 'Anillo', '11'),
  ('P2.2 Gral. Velásquez - Ruta 5', 'Vespucio Sur', -33.526262, -70.6941029, 251.22, 502.45, 753.67, 'P-O', 'Anillo', '22'),
  ('P2.1 Ruta 5 - General Velásquez', 'Vespucio Sur', -33.5260519, -70.6940167, 251.22, 502.45, 753.67, 'O-P', 'Anillo', '21'),
  ('P3.3 Gran Avenida - Ruta 5', 'Vespucio Sur', -33.5335852, -70.6763449, 332.62, 665.24, 997.86, 'O-P', 'Anillo', '33'),
  ('P3.4 Ruta 5 - Gran Avenida', 'Vespucio Sur', -33.5338163, -70.6764509, 332.62, 665.24, 997.86, 'P-O', 'Anillo', '34'),
  ('P3.2 Gran Avenida - Santa Rosa', 'Vespucio Sur', -33.5398418, -70.6529975, 332.62, 665.24, 997.86, 'P-O', 'Anillo', '32'),
  ('P3.1 Santa Rosa - Gran Avenida', 'Vespucio Sur', -33.539608, -70.6529431, 332.62, 665.24, 997.86, 'O-P', 'Anillo', '31'),
  ('P101 Salto - Kennedy', 'Túnel San Cristóbal', -33.3986159, -70.6157247, 449.4, 865.2, 1310.4, 'N-S', 'Túnel', '101'),
  ('PA4 Calera de Tango - La Capilla', 'Autopista Central', -33.6219812, -70.7148676, 129.9, null, null, 'N-S', 'Norte-Sur', '4'),
  ('PA3 La Capilla - Colón', 'Autopista Central', -33.6227591, -70.7145696, 585.09, 1170.18, 1755.28, 'S-N', 'Norte-Sur', '3'),
  ('PA5 Colón - Las Acacias', 'Autopista Central', -33.5827543, -70.7138422, 334.63, 669.27, 1003.9, 'S-N', 'Norte-Sur', '5'),
  ('PA6 Lo Blanco - Colón', 'Autopista Central', -33.5824122, -70.7139749, 157.96, 315.93, 473.89, 'N-S', 'Norte-Sur', '6'),
  ('PA30 Americo Vespucio - Departamental', 'Autopista Central', -33.5072, -70.6693, 392.83, 785.66, 785.66, 'S-N', 'Norte-Sur', '30'),
  ('PA9 Departamental - A. Vespucio', 'Autopista Central', -33.5071, -70.6694, 392.83, 785.66, 785.66, 'N-S', 'Norte-Sur', '9'),
  ('PA10 Departamental - Carlos Valdovinos', 'Autopista Central', -33.483, -70.661, 285.79, 571.58, 571.58, 'S-N', 'Norte-Sur', '10'),
  ('PA11 C. Valdovinos - Departamental', 'Autopista Central', -33.4831, -70.6611, 285.79, 571.58, 571.58, 'N-S', 'Norte-Sur', '11'),
  ('EV Entrada Vivaceta', 'Costanera Norte', -33.4302801, -70.6572269, 119.41, 229.89, 348.19, 'O-P', 'Oriente-Poniente', '1'),
  ('P4 Vivaceta - Torres Tajamar', 'Costanera Norte', -33.4302245, -70.6579611, 413.02, 795.16, 1204.32, 'P-O', 'Oriente-Poniente', '1'),
  ('PA15 14 de la Fama - Río Mapocho', 'Autopista Central', -33.4265149, -70.6688947, 425.04, 850.1, 850.1, 'N-S', 'Norte-Sur', '15'),
  ('P7 Las Tranqueras - Estoril', 'Costanera Norte', -33.3872062, -70.5413721, 250.21, 481.73, 729.61, 'P-O', 'Oriente-Poniente', '1'),
  ('P7 Estoril - Las Tranqueras', 'Costanera Norte', -33.3872124, -70.5422849, 250.21, 481.73, 729.61, 'O-P', 'Oriente-Poniente', '1'),
  ('PA23 C. Valdovinos - Alameda', 'Autopista Central', -33.4690606, -70.6881273, 287.86, 575.74, 575.74, 'S-N', 'Norte-Sur', '23'),
  ('PA24 Alameda - C. Valdovinos', 'Autopista Central', -33.4698378, -70.6882455, 287.86, 575.74, 863.61, 'N-S', 'Norte-Sur', '24'),
  ('PA21 A. Vespucio - C. Valdovinos', 'Autopista Central', -33.5064259, -70.697251, 512.34, null, null, 'S-N', 'Norte-Sur', '21'),
  ('PA22 C. Valdovinos - A. Vespucio', 'Autopista Central', -33.5065207, -70.6976839, 512.34, null, null, 'N-S', 'Norte-Sur', '22'),
  ('P2.2 Centenario - Puente Lo Saldes', 'Costanera Norte', -33.398, -70.596, 264.29, 508.82, 770.64, 'O-P', 'Oriente-Poniente', '1'),
  ('P2.2 Puente Lo Saldes - Centenario', 'Costanera Norte', -33.3981, -70.5961, 264.29, 508.82, 770.64, 'P-O', 'Oriente-Poniente', '1'),
  ('SB Salida Bellavista', 'Costanera Norte', -33.4221473, -70.6198252, 233.79, 450.11, 681.72, 'O-P', 'Oriente-Poniente', '1'),
  ('P3 Torres Tajamar - Puente Lo Saldes', 'Costanera Norte', -33.4239919, -70.6219547, 306.02, 589.16, 892.32, 'P-O', 'Oriente-Poniente', '1'),
  ('P3 Puente Lo Saldes - Vivaceta', 'Costanera Norte', -33.423992, -70.6219548, 719.04, 1384.32, 2096.64, 'O-P', 'Oriente-Poniente', '1'),
  ('P1 Puente San Francisco - Gran Vía', 'Costanera Norte', -33.385, -70.55, 449.4, 865.2, 1310.4, 'O-P', 'Oriente-Poniente', '1'),
  ('P1 Gran Vía - Puente San Francisco', 'Costanera Norte', -33.3851, -70.5501, 449.4, 865.2, 1310.4, 'P-O', 'Oriente-Poniente', '1'),
  ('P4.4 Vicuña Mackenna - Macul', 'Vespucio Sur', -33.5135, -70.595, 472.3, 944.6, 1416.89, 'P-O', 'Anillo', '44'),
  ('P4.1 Macul - Vicuña Mackenna', 'Vespucio Sur', -33.5136, -70.5951, 472.3, 944.6, 1416.89, 'O-P', 'Anillo', '41'),
  ('Peaje Gabriela Poniente', null, -33.5819958, -70.6112359, 350.0, null, null, null, null, null),
  ('P1.1 Ruta 78 - Cerrillos', 'Vespucio Sur', -33.525, -70.73, 120.59, 241.17, 361.76, 'P-O', 'Anillo', '0'),
  ('P1.3 Cerrillos - Ruta 78', 'Vespucio Sur', -33.5251, -70.7301, 120.59, 241.17, 361.76, 'O-P', 'Anillo', '13'),
  ('P1.1 Camino a Melipilla - 2a Transversal', 'Vespucio Sur', -33.5059, -70.7285, 532.59, 1065.18, 1597.78, 'O-P', 'Anillo', '11'),
  ('P3.3 Gran Avenida - Ruta 5', 'Vespucio Sur', -33.425, -70.695, 332.62, 665.24, 997.86, 'O-P', 'Anillo', '3'),
  ('P4 Vivaceta - Torres Tajamar', 'Costanera Norte', -33.4251, -70.6951, 413.02, 795.16, 1204.32, 'P-O', 'Oriente-Poniente', '4'),
  ('P9 Ruta 68 - Américo Vespucio Poniente', 'Costanera Norte', -33.418078, -70.7910033, 535.0, 1030.0, 1030.0, 'P-O', 'Oriente-Poniente', '1'),
  ('P6.2 Américo Vespucio Poniente - Petersen', 'Costanera Norte', -33.4130639, -70.7667427, 364.87, 702.46, 1063.92, 'P-O', 'Oriente-Poniente', '6'),
  ('P6.1 Carrascal - Petersen', 'Costanera Norte', -33.4117097, -70.7395811, 239.68, 461.44, 461.44, 'O-P', 'Oriente-Poniente', '6'),
  ('P11 Pedro Fontova - Ruta 5 Norte', 'Vespucio Norte', -33.3657718, -70.6951146, 301.47, 602.93, 602.93, 'O-P', 'Anillo', '11'),
  ('P10 Ruta 5 Norte - Pedro Fontova', 'Vespucio Norte', -33.3657, -70.6951, 301.47, 602.93, 904.4, 'P-O', 'Anillo', '0'),
  ('P11 Pedro Fontova - Ruta 5 Norte', 'Vespucio Norte', -33.37, -70.68, 301.47, 602.93, 602.93, 'O-P', 'Anillo', '0'),
  ('P12 Pedro Fontova - Guanaco', 'Vespucio Norte', -33.375, -70.67, 69.34, 138.67, 138.67, 'P-O', 'Anillo', '0'),
  ('P13 Recoleta - Pedro Fontova', 'Vespucio Norte', -33.38, -70.66, 412.0, 824.01, 1236.01, 'O-P', 'Anillo', '0'),
  ('P2 Ruta 68 - Los Mares', 'Vespucio Norte', -33.456362, -70.767131, 211.03, 422.05, 633.08, 'O-P', 'Anillo', '2'),
  ('P3 Ruta 68 - Costanera Norte', 'Vespucio Norte', -33.438755, -70.783088, 351.71, 703.42, 703.42, 'P-O', 'Anillo', '3'),
  ('P4 Costanera Norte - Ruta 68', 'Vespucio Norte', -33.4313, -70.784842, 351.71, 703.42, 1055.13, 'O-P', 'Anillo', '4'),
  ('P5 Costanera Norte - Condell', 'Vespucio Norte', -33.399627, -70.775606, 452.2, 904.4, 904.4, 'P-O', 'Anillo', '5'),
  ('P7 Condell - Lo Echevers', 'Vespucio Norte', -33.381475, -70.753988, 104.51, 209.02, 209.02, 'P-O', 'Anillo', '7'),
  ('P8 Ruta 5 Norte - Condell', 'Vespucio Norte', -33.373011, -70.711264, 653.18, 1306.36, 1306.36, 'O-P', 'Anillo', '8'),
  ('P9 Lo Echevers - Ruta 5 Norte', 'Vespucio Norte', -33.368868, -70.704319, 548.67, 1097.34, 1097.34, 'P-O', 'Anillo', '9'),
  ('P15 El Salto - Recoleta', 'Vespucio Norte', -33.388665, -70.632964, 140.68, 281.37, 422.05, 'O-P', 'Anillo', '15'),
  ('P16 Santa Elena - Ruta 68', 'Vespucio Norte', -33.451274, -70.772932, 482.35, 964.69, 1447.04, 'P-O', 'Anillo', '16'),
  ('PA1 La Capilla - Los Guindos', 'Autopista Central', -33.6473389, -70.7116107, 868.37, null, null, 'N-S', 'Norte-Sur', '1'),
  ('PA25 Alameda - Río Mapocho', 'Autopista Central', -33.442, -70.686, 421.93, 843.86, 843.86, 'S-N', 'Norte-Sur', '25'),
  ('PA26 Río Mapocho - Alameda', 'Autopista Central', -33.442, -70.686, 421.93, 843.86, 843.86, 'N-S', 'Norte-Sur', '26'),
  ('PA29 Ruta 5 Norte - Río Mapocho', 'Autopista Central', -33.3822386, -70.6955624, 512.34, 1024.69, 1024.69, 'N-S', 'Norte-Sur', '29'),
  ('PA37 Colón - Calera de Tango', 'Autopista Central', -33.61, -70.713, 455.18, null, null, 'N-S', 'Norte-Sur', '37'),
  ('P5.1 Grecia - Quilín', 'Vespucio Sur', -33.480956, -70.57905, 121.59, 243.18, 364.78, 'N-S', 'Anillo', '51'),
  ('P5.2 Quilín - Grecia', 'Vespucio Sur', -33.48109, -70.57881, 290.41, 580.83, 871.24, 'S-N', 'Anillo', '52'),
  ('P5.3 Quilín - Las Torres', 'Vespucio Sur', -33.495589, -70.584467, 551.68, 1103.37, 1655.05, 'N-S', 'Anillo', '53'),
  ('P5.4 Las Torres - Quilín', 'Vespucio Sur', -33.49613, -70.584513, 382.86, 765.73, 1148.59, 'S-N', 'Anillo', '54'),
  ('EP Entrada Purísima', 'Costanera Norte', -33.434671, -70.639482, 225.77, 434.66, 658.32, 'O-P', 'Oriente-Poniente', '1'),
  ('P8.2 Costanera Norte - Las Tranqueras', 'Costanera Norte', -33.4085, -70.601965, 583.84, 1124.03, 1702.42, 'P-O', 'Oriente-Poniente', '8'),
  ('P8.3 Costanera Norte - Las Tranqueras', 'Costanera Norte', -33.4084, -70.601965, 583.84, 1124.03, 1702.42, 'P-O', 'Oriente-Poniente', '8'),
  ('P6 Condell - Costanera Norte', 'Vespucio Norte', -33.399627, -70.775606, 452.2, 904.4, 904.4, 'O-P', 'Anillo', '6'),
  ('P17 Los Mares - Ruta 78', 'Vespucio Norte', -33.484, -70.763, 391.91, 783.81, 1175.72, 'O-P', 'Anillo', '17')
) as v(nombre, autopista, lat, lng, costo, costo_punta, costo_saturacion, sentido, grupo, secuencia)
where not exists (select 1 from public.porticos);

-- =====================================================================
-- SECCIÓN 8 de 17 · 0008_avatar_storage.sql
-- =====================================================================

-- Foto de perfil: columna en usuarios + bucket de Storage para avatares.
--
-- El bucket es público de lectura (una foto de perfil no es información
-- sensible, y así se sirve directo con getPublicUrl() sin necesitar URLs
-- firmadas). Solo el dueño puede subir/reemplazar/borrar su propio archivo,
-- identificado por el primer segmento del path (<uid>/avatar.<ext>) — mismo
-- patrón de "carpeta = uid" que vehiculo_documentos_all en 0003_rls.sql.

alter table public.usuarios add column foto_url text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy avatars_select on storage.objects
  for select using (bucket_id = 'avatars');

create policy avatars_insert on storage.objects
  for insert with check (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy avatars_update on storage.objects
  for update using (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  ) with check (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy avatars_delete on storage.objects
  for delete using (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

-- =====================================================================
-- SECCIÓN 9 de 17 · 0009_vehiculo_foto_y_documento_ia.sql
-- =====================================================================

-- Módulo "Mi Vehículo": foto del vehículo, trazabilidad de documentos
-- reconocidos por IA, y el toggle de notificaciones de vencimiento.

alter table public.vehiculos add column foto_url text;

-- origen/ai_capturado_en/archivo_nombre: trazabilidad de "Registro Inteligente"
-- (de dónde salió el dato: tipeo manual o extracción de IA), pendiente desde
-- la lectura de audited_invoices -- ahora también se aplica a los documentos
-- del vehículo, que es el primer módulo nuevo que usa el patrón
-- Manual + IA → Revisión → Confirmar → Guardar.
alter table public.vehiculo_documentos
  add column origen text not null default 'manual' check (origen in ('manual', 'ia')),
  add column ai_capturado_en timestamptz,
  add column archivo_nombre text;

-- Toggle de notificaciones preventivas de vencimiento, junto a los que ya
-- existen (notif_cobros, notif_presupuesto) en profile_screen.dart.
alter table public.usuarios add column notif_vencimientos boolean not null default true;

-- Bucket para fotos de vehículo, mismo patrón que 0008_avatar_storage.sql:
-- público de lectura, y solo el dueño puede escribir en su propia carpeta
-- (<uid>/<vehiculo_id>.<ext>).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('vehiculo_fotos', 'vehiculo_fotos', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy vehiculo_fotos_select on storage.objects
  for select using (bucket_id = 'vehiculo_fotos');

create policy vehiculo_fotos_insert on storage.objects
  for insert with check (
    bucket_id = 'vehiculo_fotos' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy vehiculo_fotos_update on storage.objects
  for update using (
    bucket_id = 'vehiculo_fotos' and (storage.foldername(name))[1] = auth.uid()::text
  ) with check (
    bucket_id = 'vehiculo_fotos' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy vehiculo_fotos_delete on storage.objects
  for delete using (
    bucket_id = 'vehiculo_fotos' and (storage.foldername(name))[1] = auth.uid()::text
  );

-- =====================================================================
-- SECCIÓN 10 de 17 · 0010_usuarios_delete_super_admin.sql
-- =====================================================================

-- Borrar filas de usuarios era posible para cualquier admin (incluido el
-- rol 'operador') directamente por la API, porque la restricción de menú del
-- panel solo existía en el cliente. El panel ya borra usuarios a través de la
-- Edge Function delete-user (service-role, exige super_admin), así que la
-- política puede exigir lo mismo sin romper nada.

drop policy if exists usuarios_delete on public.usuarios;

create policy usuarios_delete on public.usuarios
  for delete using (is_super_admin());

-- =====================================================================
-- SECCIÓN 11 de 17 · 0011_combustible_energia.sql
-- =====================================================================

-- Combustible y carga: soporte de kWh para híbridos y eléctricos, trazabilidad
-- del registro con IA y marca de "estanque lleno" para calcular el rendimiento.
--
-- Las columnas litros y precio_litro se conservan con esos nombres para no
-- romper los registros existentes, pero ahora guardan la CANTIDAD y el PRECIO
-- POR UNIDAD, sea cual sea la unidad (litros o kWh).

alter table public.combustible_cargas
  add column unidad text not null default 'litros' check (unidad in ('litros', 'kwh')),
  add column origen text not null default 'manual' check (origen in ('manual', 'ia')),
  add column ai_capturado_en timestamptz,
  add column archivo_nombre text,
  -- Solo las cargas con estanque (o batería) lleno sirven para estimar el
  -- rendimiento: se compara lo cargado entre dos llenados sucesivos.
  add column tanque_lleno boolean not null default false;

comment on column public.combustible_cargas.litros is
  'Cantidad cargada, en la unidad indicada por la columna unidad (litros o kWh).';
comment on column public.combustible_cargas.precio_litro is
  'Precio por unidad (por litro o por kWh).';

-- =====================================================================
-- SECCIÓN 12 de 17 · 0012_mantenciones_detalle.sql
-- =====================================================================

-- Módulo Mantenciones: detalle del servicio, documento adjunto, trazabilidad de
-- la IA y programación de la próxima mantención con recordatorios.

-- ── 1. Detalle de cada mantención ────────────────────────────────────
alter table public.mantenciones
  add column observaciones text,
  -- Lista de servicios realizados ("Cambio de aceite", "Filtro de aire"...) y
  -- de repuestos usados, tal como aparecen en la boleta o factura.
  add column servicios text[] not null default '{}',
  add column repuestos text[] not null default '{}',
  -- Boleta o factura adjunta (ruta dentro del bucket mantencion_docs).
  add column documento_path text,
  add column documento_nombre text,
  -- Trazabilidad del registro inteligente, igual que en los documentos del
  -- vehículo: de dónde salió el dato y cuándo lo leyó la IA.
  add column origen text not null default 'manual' check (origen in ('manual', 'ia')),
  add column ai_capturado_en timestamptz,
  add constraint mantenciones_costo_no_negativo check (costo >= 0);

-- ── 2. Próxima mantención programada ─────────────────────────────────
create table public.mantenciones_programadas (
  id                   uuid primary key default gen_random_uuid(),
  usuario_id           uuid not null references public.usuarios(id) on delete cascade,
  vehiculo_id          uuid not null references public.vehiculos(id) on delete cascade,
  tipo                 text not null default 'preventiva'
                         check (tipo in ('preventiva', 'aceite', 'frenos', 'neumaticos', 'otra')),
  descripcion          text,
  -- Se puede programar por fecha, por kilometraje o por ambos (basta uno).
  fecha_programada     date,
  km_programado        numeric,
  -- Con cuánta anticipación avisar: días antes de la fecha, o kilómetros
  -- antes del kilometraje programado.
  aviso_dias_antes     integer not null default 7 check (aviso_dias_antes >= 0),
  aviso_km_antes       numeric not null default 500 check (aviso_km_antes >= 0),
  completada           boolean not null default false,
  created_at           timestamptz not null default now(),
  constraint mantenciones_programadas_criterio
    check (fecha_programada is not null or km_programado is not null),
  constraint mantenciones_programadas_km_positivo
    check (km_programado is null or km_programado > 0)
);

create index mantenciones_programadas_usuario_id_idx on public.mantenciones_programadas(usuario_id);
create index mantenciones_programadas_vehiculo_id_idx on public.mantenciones_programadas(vehiculo_id);

alter table public.mantenciones_programadas enable row level security;

-- Mismo patrón que mantenciones: dueño-o-admin, y el vehículo debe ser del dueño.
create policy mantenciones_programadas_all on public.mantenciones_programadas
  for all using (
    is_admin() or (
      usuario_id = auth.uid() and exists (
        select 1 from public.vehiculos v
        where v.id = mantenciones_programadas.vehiculo_id and v.usuario_id = auth.uid()
      )
    )
  ) with check (
    is_admin() or (
      usuario_id = auth.uid() and exists (
        select 1 from public.vehiculos v
        where v.id = mantenciones_programadas.vehiculo_id and v.usuario_id = auth.uid()
      )
    )
  );

-- Realtime: las pantallas se actualizan solas (ver 0006_enable_realtime.sql).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'mantenciones_programadas'
  ) then
    alter publication supabase_realtime add table public.mantenciones_programadas;
  end if;
end $$;

-- ── 3. Bucket privado para las boletas y facturas adjuntas ───────────
-- A diferencia de las fotos de perfil, una boleta puede tener datos
-- personales: el bucket NO es público y solo el dueño puede leer o escribir
-- en su propia carpeta (<uid>/<mantencion>/<archivo>).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'mantencion_docs', 'mantencion_docs', false, 10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do nothing;

create policy mantencion_docs_select on storage.objects
  for select using (
    bucket_id = 'mantencion_docs' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy mantencion_docs_insert on storage.objects
  for insert with check (
    bucket_id = 'mantencion_docs' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy mantencion_docs_update on storage.objects
  for update using (
    bucket_id = 'mantencion_docs' and (storage.foldername(name))[1] = auth.uid()::text
  ) with check (
    bucket_id = 'mantencion_docs' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy mantencion_docs_delete on storage.objects
  for delete using (
    bucket_id = 'mantencion_docs' and (storage.foldername(name))[1] = auth.uid()::text
  );

-- =====================================================================
-- SECCIÓN 13 de 17 · 0013_estacionamientos_detalle.sql
-- =====================================================================

-- Módulo Estacionamientos: sesión en curso (cronómetro), dirección, observaciones,
-- comprobante adjunto y trazabilidad de la IA.
--
-- La tabla estacionamientos ya existe (0005): tiene fecha, lugar, lat, lng,
-- hora_entrada, hora_salida y costo. Aquí se agrega lo que faltaba.

alter table public.estacionamientos
  add column direccion text,
  add column observaciones text,
  -- Duración leída de un ticket cuando no trae las dos horas (solo "2 h 30 min").
  add column duracion_minutos integer check (duracion_minutos is null or duracion_minutos >= 0),
  -- true mientras el cronómetro corre. La hora de inicio queda guardada aquí, no
  -- solo en la app: así la duración se recupera aunque la app se cierre.
  add column en_curso boolean not null default false,
  add column documento_path text,
  add column documento_nombre text,
  add column origen text not null default 'manual' check (origen in ('manual', 'ia')),
  add column ai_capturado_en timestamptz,
  add constraint estacionamientos_costo_no_negativo check (costo >= 0),
  add constraint estacionamientos_horas_coherentes
    check (hora_entrada is null or hora_salida is null or hora_salida >= hora_entrada),
  add constraint estacionamientos_coordenadas_validas
    check ((lat is null) = (lng is null) and (lat is null or (lat between -90 and 90 and lng between -180 and 180)));

-- Un vehículo no puede tener dos estacionamientos en curso a la vez. La base lo
-- garantiza aunque la app falle o se abra desde dos dispositivos.
create unique index estacionamientos_un_activo_por_vehiculo
  on public.estacionamientos (vehiculo_id)
  where en_curso;

-- ── Bucket privado para los tickets y boletas adjuntos ───────────────
-- Igual que mantencion_docs: NO es público y solo el dueño lee y escribe en su
-- carpeta (<uid>/<estacionamiento>/<archivo>).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'estacionamiento_docs', 'estacionamiento_docs', false, 10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do nothing;

create policy estacionamiento_docs_select on storage.objects
  for select using (
    bucket_id = 'estacionamiento_docs' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy estacionamiento_docs_insert on storage.objects
  for insert with check (
    bucket_id = 'estacionamiento_docs' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy estacionamiento_docs_update on storage.objects
  for update using (
    bucket_id = 'estacionamiento_docs' and (storage.foldername(name))[1] = auth.uid()::text
  ) with check (
    bucket_id = 'estacionamiento_docs' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy estacionamiento_docs_delete on storage.objects
  for delete using (
    bucket_id = 'estacionamiento_docs' and (storage.foldername(name))[1] = auth.uid()::text
  );

-- =====================================================================
-- SECCIÓN 14 de 17 · 0014_beneficios_backoffice.sql
-- =====================================================================

-- Beneficios (CU15 y CU19): comercio, categorías válidas, visibilidad para los
-- conductores e imágenes promocionales.
--
-- La tabla beneficios ya existe (0001 + 0005): nombre (el título), descripcion,
-- imagen, categoria, ubicacion, vigencia_desde, vigencia_hasta, condiciones,
-- destacado y activo. Aquí se agrega lo que faltaba.

alter table public.beneficios
  add column comercio text,
  add constraint beneficios_categoria_valida
    check (categoria is null or categoria in ('combustible', 'talleres', 'lavado', 'estacionamiento', 'otros')),
  add constraint beneficios_vigencia_coherente
    check (vigencia_desde is null or vigencia_hasta is null or vigencia_hasta >= vigencia_desde);

create index beneficios_activo_idx on public.beneficios (activo, destacado);

-- ── Qué ve cada quien ────────────────────────────────────────────────
-- Antes cualquier usuario autenticado leía TODOS los beneficios, también los
-- desactivados y los vencidos. Ahora los conductores solo ven los activos y
-- vigentes; los administradores ven todo para poder gestionarlos.
drop policy if exists beneficios_select on public.beneficios;

create policy beneficios_select on public.beneficios
  for select using (
    is_admin()
    or (
      auth.role() = 'authenticated'
      and activo
      and (vigencia_desde is null or vigencia_desde <= now())
      and (vigencia_hasta is null or vigencia_hasta >= now())
    )
  );

-- ── Imágenes promocionales ───────────────────────────────────────────
-- Público de lectura (las imágenes se muestran a todos los conductores) y solo
-- los administradores pueden subir, reemplazar o borrar. Límite de 2 MB y solo
-- formatos de imagen: la validación se repite en el panel, pero aquí queda
-- garantizada aunque alguien llame a la API directamente.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'beneficios_imagenes', 'beneficios_imagenes', true, 2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

create policy beneficios_imagenes_select on storage.objects
  for select using (bucket_id = 'beneficios_imagenes');

create policy beneficios_imagenes_insert on storage.objects
  for insert with check (bucket_id = 'beneficios_imagenes' and is_admin());

create policy beneficios_imagenes_update on storage.objects
  for update using (bucket_id = 'beneficios_imagenes' and is_admin())
  with check (bucket_id = 'beneficios_imagenes' and is_admin());

create policy beneficios_imagenes_delete on storage.objects
  for delete using (bucket_id = 'beneficios_imagenes' and is_admin());

-- =====================================================================
-- SECCIÓN 15 de 17 · 0015_beneficios_categorias_y_canje.sql
-- =====================================================================

-- Beneficios: las 8 categorías del catálogo (CU15) y el código o mecanismo de canje.

-- El catálogo permite filtrar por combustible, talleres, mantenciones,
-- estacionamientos, lavado, neumáticos, seguros y accesorios, y el panel de
-- administración debe poder asignar esas mismas categorías. Se reemplaza la
-- restricción de la 0014, que solo permitía 5 valores.
alter table public.beneficios drop constraint if exists beneficios_categoria_valida;

alter table public.beneficios
  add constraint beneficios_categoria_valida
    check (
      categoria is null or categoria in (
        'combustible', 'talleres', 'mantenciones', 'estacionamiento',
        'lavado', 'neumaticos', 'seguros', 'accesorios', 'otros'
      )
    );

-- Cómo se usa el beneficio: un código ("TAGOK10"), o una instrucción ("Muestra
-- tu app en caja"). El detalle del catálogo lo muestra para que el conductor
-- pueda canjearlo en el comercio.
alter table public.beneficios add column if not exists codigo_canje text;

-- =====================================================================
-- SECCIÓN 16 de 17 · 0016_combustible_comprobante.sql
-- =====================================================================

-- Combustible: comprobante adjunto (la boleta de la carga) y montos no negativos.
--
-- El detalle de una carga (CU14) permite ver el comprobante, y el registro con IA
-- (CU13) parte de una foto o PDF de la boleta: se guarda junto con la carga, igual
-- que en Mantenciones y Estacionamientos.

alter table public.combustible_cargas
  add column documento_path text,
  add column documento_nombre text;

-- NOT VALID: se exige a los registros nuevos y modificados sin revisar los que ya
-- existían, para que esta migración no falle por datos antiguos.
alter table public.combustible_cargas
  add constraint combustible_montos_no_negativos
    check (litros >= 0 and precio_litro >= 0 and total >= 0) not valid;

-- Bucket privado, con el mismo patrón que mantencion_docs y estacionamiento_docs:
-- solo el dueño lee y escribe en su propia carpeta (<uid>/<carga>/<archivo>).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'combustible_docs', 'combustible_docs', false, 10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do nothing;

create policy combustible_docs_select on storage.objects
  for select using (
    bucket_id = 'combustible_docs' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy combustible_docs_insert on storage.objects
  for insert with check (
    bucket_id = 'combustible_docs' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy combustible_docs_update on storage.objects
  for update using (
    bucket_id = 'combustible_docs' and (storage.foldername(name))[1] = auth.uid()::text
  ) with check (
    bucket_id = 'combustible_docs' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy combustible_docs_delete on storage.objects
  for delete using (
    bucket_id = 'combustible_docs' and (storage.foldername(name))[1] = auth.uid()::text
  );

-- =====================================================================
-- SECCIÓN 17 de 17 · 0017_estado_cuenta_y_auditoria.sql
-- =====================================================================

-- Estado de la cuenta (suspensión, CU18) y enlace de la bitácora con el administrador.
-- Solo agrega columnas: no cambia nada de lo que ya funciona.

-- ── Suspender cuentas ────────────────────────────────────────────────
alter table public.usuarios
  add column estado text not null default 'activo' check (estado in ('activo', 'suspendido'));

comment on column public.usuarios.estado is
  'activo o suspendido. Solo un administrador puede cambiarlo (ver el trigger usuarios_proteger_estado).';

-- La política usuarios_update deja que cada persona modifique su propia fila. Sin
-- esta protección, alguien suspendido podría reactivarse a sí mismo llamando
-- directamente a la API. Solo un administrador (o el servidor, con la
-- service-role key) puede cambiar el estado.
create or replace function public.proteger_estado_usuario()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.estado is distinct from old.estado
     and not public.is_admin()
     and coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'Solo un administrador puede cambiar el estado de una cuenta.';
  end if;
  return new;
end;
$$;

create trigger usuarios_proteger_estado
  before update on public.usuarios
  for each row execute function public.proteger_estado_usuario();

-- ── Bitácora enlazada con el administrador ───────────────────────────
-- Antes solo guardaba el correo como texto. Ahora también apunta al
-- administrador; el correo se conserva como respaldo por si la cuenta se borra.
alter table public.auditoria
  add column admin_id uuid references public.administradores(id) on delete set null;

create index auditoria_admin_id_idx on public.auditoria (admin_id);

