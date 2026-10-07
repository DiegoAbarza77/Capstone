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
