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
