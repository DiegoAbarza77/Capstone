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
