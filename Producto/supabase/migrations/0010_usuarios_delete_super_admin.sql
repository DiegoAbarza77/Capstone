-- Borrar filas de usuarios era posible para cualquier admin (incluido el
-- rol 'operador') directamente por la API, porque la restricción de menú del
-- panel solo existía en el cliente. El panel ya borra usuarios a través de la
-- Edge Function delete-user (service-role, exige super_admin), así que la
-- política puede exigir lo mismo sin romper nada.

drop policy if exists usuarios_delete on public.usuarios;

create policy usuarios_delete on public.usuarios
  for delete using (is_super_admin());
