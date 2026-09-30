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
