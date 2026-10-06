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
