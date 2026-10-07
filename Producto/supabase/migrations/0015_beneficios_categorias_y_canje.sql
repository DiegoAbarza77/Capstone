-- Beneficios: las 8 categorías del catálogo (CU15) y el código o mecanismo de canje.

-- El catálogo permite filtrar por combustible, talleres, mantenciones,
-- estacionamientos, lavado, neumáticos, seguros y accesorios, y el panel de
-- administración debe poder asignar esas mismas categorías. Se reemplaza la
-- restricción de la 0014, que solo permitía 5 valores.
alter table public.beneficios drop constraint if exists beneficios_categoria_valida;

alter table public.beneficios
  add constraint beneficios_categoria_valida
    check (
      categoria is null or categoria in (
        'combustible', 'talleres', 'mantenciones', 'estacionamiento',
        'lavado', 'neumaticos', 'seguros', 'accesorios', 'otros'
      )
    );

-- Cómo se usa el beneficio: un código ("TAGOK10"), o una instrucción ("Muestra
-- tu app en caja"). El detalle del catálogo lo muestra para que el conductor
-- pueda canjearlo en el comercio.
alter table public.beneficios add column if not exists codigo_canje text;
