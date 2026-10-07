-- Beneficios de EJEMPLO para probar el catálogo de la app y el panel.
--
-- Los comercios son inventados: no existen alianzas reales. Úsalo solo en un
-- proyecto de pruebas. No es una migración: se ejecuta a mano, una sola vez,
-- en el SQL Editor de Supabase (necesita aplicadas las migraciones 0014 y 0015).
--
-- Para borrar estos ejemplos después:
--   delete from public.beneficios where descripcion like '[EJEMPLO]%';

insert into public.beneficios
  (nombre, comercio, categoria, descripcion, ubicacion, condiciones, codigo_canje,
   vigencia_desde, vigencia_hasta, destacado, activo)
values
  -- Destacado, vigente varios meses.
  ('10% de descuento en bencina', 'Estación Los Aromos (ejemplo)', 'combustible',
   '[EJEMPLO] Descuento en bencina de 93, 95 y 97 octanos.', 'Santiago',
   'Máximo 40 litros por carga. No acumulable con otras promociones.', 'TAGOK10',
   now() - interval '5 days', now() + interval '90 days', true, true),

  -- Vence en 3 días: aparece con la fecha en ámbar y en el filtro "esta semana".
  ('Cambio de aceite con 20% de descuento', 'Taller Mecánico Central (ejemplo)', 'talleres',
   '[EJEMPLO] Cambio de aceite y filtro con mano de obra incluida.', 'Santiago',
   'Presentar la patente del vehículo registrado en TAG OK.', 'Muestra la app en el taller',
   now() - interval '20 days', now() + interval '3 days', false, true),

  -- Sin ubicación: aplica en todas partes.
  ('Lavado express gratis en tu segunda visita', 'AutoSpa Brillo (ejemplo)', 'lavado',
   '[EJEMPLO] Lavado exterior y aspirado.', null,
   'Válido de lunes a jueves.', 'LAVADO2DA',
   now() - interval '2 days', now() + interval '25 days', false, true),

  -- Sin fecha límite.
  ('2 horas gratis de estacionamiento', 'Estacionamientos Plaza Sur (ejemplo)', 'estacionamiento',
   '[EJEMPLO] Presentando un comprobante de compra.', 'Valparaíso',
   'Una vez por día. Sujeto a disponibilidad.', null,
   null, null, false, true),

  ('15% en neumáticos de marca', 'Neumáticos del Pacífico (ejemplo)', 'neumaticos',
   '[EJEMPLO] En toda la línea de neumáticos para auto y camioneta.', 'Santiago',
   'No incluye instalación.', 'RUEDAS15',
   now() - interval '1 day', now() + interval '60 days', false, true),

  -- Estos tres NO deben aparecer en la app: sirven para comprobar la visibilidad.
  ('Beneficio vencido', 'Comercio de prueba (ejemplo)', 'otros',
   '[EJEMPLO] Su vigencia terminó: no debe verse en la app.', null, null, null,
   now() - interval '60 days', now() - interval '2 days', false, true),

  ('Beneficio desactivado', 'Comercio de prueba (ejemplo)', 'otros',
   '[EJEMPLO] Está desactivado: no debe verse en la app.', null, null, null,
   null, null, false, false),

  ('Beneficio que aún no empieza', 'Comercio de prueba (ejemplo)', 'seguros',
   '[EJEMPLO] Empieza en 10 días: no debe verse todavía.', null, null, null,
   now() + interval '10 days', now() + interval '40 days', false, true);
