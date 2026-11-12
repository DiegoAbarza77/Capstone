-- Registro del uso de la IA (panel de administración, "Uso de IA").
--
-- La función gemini-proxy (el único lugar que habla con Gemini) anota aquí cada
-- llamada: quién la hizo, cuándo, si resultó bien, falló o chocó con el límite
-- por minuto, y cuánto tardó. Sirve para ver el volumen de uso, los errores y
-- controlar el costo.
--
-- No guarda el contenido de lo que se envía (ni el texto ni el archivo): solo
-- datos de la llamada.
create table public.uso_ia (
  id            uuid primary key default gen_random_uuid(),
  -- Si se borra la cuenta, la fila queda (sin dueño) para no perder el conteo.
  usuario_id    uuid references public.usuarios(id) on delete set null,
  created_at    timestamptz not null default now(),
  resultado     text not null check (resultado in ('ok', 'error', 'limitado')),
  -- Código HTTP del fallo (503 = Google con alta demanda, 502 = respuesta vacía).
  http_status   integer,
  con_archivo   boolean not null default false,
  tipo_archivo  text,
  prompt_chars  integer not null default 0,
  duracion_ms   integer
);

create index uso_ia_created_at_idx on public.uso_ia (created_at desc);
create index uso_ia_usuario_idx on public.uso_ia (usuario_id, created_at desc);

alter table public.uso_ia enable row level security;

-- Solo los administradores leen el registro. No hay políticas de insertar,
-- modificar ni borrar: escribe únicamente la función del servidor, con su llave
-- de servicio, así que ningún usuario puede alterar las cifras.
create policy uso_ia_select on public.uso_ia
  for select using (is_admin());
