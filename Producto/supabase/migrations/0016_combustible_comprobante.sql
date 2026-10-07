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
