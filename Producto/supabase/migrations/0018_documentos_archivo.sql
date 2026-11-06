-- Documentos del vehículo: guardar el archivo original (foto o PDF).
--
-- Hasta ahora, al subir un permiso, una revisión técnica, un SOAP o un seguro,
-- solo se guardaban los datos leídos y el nombre del archivo, no el archivo.
-- Ahora el archivo queda en un bucket privado, igual que las boletas de
-- mantenciones, estacionamientos y combustible, y el conductor puede volver a
-- verlo desde la pantalla del documento.
--
-- La columna archivo_nombre ya existía (0009); aquí se agrega la ruta.
alter table public.vehiculo_documentos
  add column if not exists archivo_path text;

comment on column public.vehiculo_documentos.archivo_path is
  'Ruta del archivo dentro del bucket vehiculo_docs: <usuario>/<vehiculo>/<archivo>.';

-- Bucket privado: los documentos del vehículo son datos personales, así que solo
-- el dueño puede leer o escribir, y cada usuario en su propia carpeta
-- (<uid>/<vehiculo>/<archivo>). 10 MB como máximo, solo imágenes y PDF.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'vehiculo_docs', 'vehiculo_docs', false, 10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do nothing;

create policy vehiculo_docs_select on storage.objects
  for select using (
    bucket_id = 'vehiculo_docs' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy vehiculo_docs_insert on storage.objects
  for insert with check (
    bucket_id = 'vehiculo_docs' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy vehiculo_docs_update on storage.objects
  for update using (
    bucket_id = 'vehiculo_docs' and (storage.foldername(name))[1] = auth.uid()::text
  ) with check (
    bucket_id = 'vehiculo_docs' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy vehiculo_docs_delete on storage.objects
  for delete using (
    bucket_id = 'vehiculo_docs' and (storage.foldername(name))[1] = auth.uid()::text
  );
