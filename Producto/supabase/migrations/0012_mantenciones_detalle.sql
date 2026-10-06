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
