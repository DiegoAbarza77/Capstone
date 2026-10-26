-- Catálogo de beneficios de DEMOSTRACIÓN: 14 beneficios vigentes, uno o más por
-- categoría, para mostrar la app y el panel con un catálogo completo.
--
-- Los comercios son inventados: no existen alianzas reales. No es una migración:
-- se ejecuta a mano, una sola vez, en el SQL Editor de Supabase (necesita las
-- migraciones 0014 y 0015). Todos llevan el prefijo "[EJEMPLO]" en la descripción
-- para poder encontrarlos y borrarlos.
--
-- Para borrar estos ejemplos (y los de beneficios_ejemplo.sql):
--   delete from public.beneficios where descripcion like '[EJEMPLO]%';
--
-- Si no quieres que el prefijo se vea en la app, ejecuta esto después de cargarlos
-- (pierdes la forma fácil de borrarlos, así que anota los nombres):
--   update public.beneficios set descripcion = substring(descripcion from 12)
--   where descripcion like '[EJEMPLO] %';

insert into public.beneficios
  (nombre, comercio, categoria, descripcion, ubicacion, condiciones, codigo_canje,
   vigencia_desde, vigencia_hasta, destacado, activo)
values
  -- Combustible
  ('8% de descuento en carga eléctrica', 'Electrolinera Ruta Sur', 'combustible',
   '[EJEMPLO] Descuento en cualquier carga rápida de vehículos eléctricos e híbridos.', 'Santiago',
   'Máximo 60 kWh por carga. Una carga por día.', 'ELEC8',
   now() - interval '3 days', now() + interval '120 days', true, true),

  ('$3.000 de descuento cada 30 litros', 'Servicentro Cordillera', 'combustible',
   '[EJEMPLO] Descuento directo en la boleta al cargar bencina o diésel.', 'Santiago y regiones',
   'Compra mínima de 30 litros. No acumulable con otras promociones.', 'LITROS30',
   now() - interval '10 days', now() + interval '60 days', false, true),

  -- Talleres
  ('Revisión de frenos gratis', 'Frenos Maipú Express', 'talleres',
   '[EJEMPLO] Diagnóstico de pastillas, discos y líquido de frenos, sin costo.', 'Maipú',
   'Presentar la patente del vehículo registrada en TAG OK.', 'Muestra la app en el taller',
   now() - interval '15 days', now() + interval '45 days', false, true),

  ('Pre-chequeo de revisión técnica sin costo', 'Taller Los Alerces', 'talleres',
   '[EJEMPLO] Revisamos luces, frenos, emisiones y neumáticos antes de tu revisión técnica.', 'Santiago',
   'Con hora previa. Dura cerca de 30 minutos.', 'PRECHEQUEO',
   now() - interval '5 days', now() + interval '90 days', false, true),

  -- Mantenciones
  ('15% en mantención de los 10.000 km', 'Centro de Servicio Autoplus', 'mantenciones',
   '[EJEMPLO] Cambio de aceite, filtros y revisión de 25 puntos con repuestos de calidad.', 'Santiago',
   'Aplica a autos y camionetas livianas. Incluye mano de obra.', 'MANT15',
   now() - interval '2 days', now() + interval '100 days', true, true),

  ('Alineación y balanceo 2x1', 'Mecánica Rápida Sur', 'mantenciones',
   '[EJEMPLO] Pagas la alineación y el balanceo es gratis.', 'Puente Alto',
   'Un servicio por vehículo y por mes.', null,
   now() - interval '1 day', now() + interval '30 days', false, true),

  -- Estacionamiento
  ('1 hora gratis de estacionamiento', 'Parking Centro Mayor', 'estacionamiento',
   '[EJEMPLO] Presentando un comprobante de compra del centro comercial.', 'Santiago',
   'Una vez por día. Sujeto a disponibilidad.', 'PARK1H',
   now() - interval '7 days', now() + interval '75 days', false, true),

  ('Tarifa nocturna plana de $2.500', 'Estacionamientos Providencia', 'estacionamiento',
   '[EJEMPLO] Ingreso después de las 20:00 y salida antes de las 08:00.', 'Providencia',
   'Válido todos los días. No incluye vehículos de más de 2 metros de altura.', null,
   null, null, false, true),

  -- Lavado
  ('25% en lavado completo', 'Lavacar Express', 'lavado',
   '[EJEMPLO] Lavado exterior, aspirado interior y limpieza de vidrios.', 'Santiago',
   'Válido de lunes a viernes.', 'LAVADO25',
   now() - interval '4 days', now() + interval '50 days', false, true),

  ('Encerado gratis en lavado premium', 'AutoSpa Brillo', 'lavado',
   '[EJEMPLO] Al contratar el lavado premium, el encerado va sin costo.', 'Viña del Mar',
   'Con reserva previa.', 'ENCERADO',
   now() - interval '1 day', now() + interval '5 days', false, true),

  -- Neumáticos
  ('15% en neumáticos de marca', 'Neumáticos del Pacífico', 'neumaticos',
   '[EJEMPLO] En toda la línea de neumáticos para auto y camioneta.', 'Santiago',
   'No incluye instalación.', 'RUEDAS15',
   now() - interval '6 days', now() + interval '60 days', false, true),

  -- Seguros
  ('12% en seguro todo riesgo', 'Aseguradora Andes', 'seguros',
   '[EJEMPLO] Descuento en la prima anual al contratar un seguro automotriz todo riesgo.', 'Todo Chile',
   'Sujeto a evaluación del vehículo y del conductor.', 'SEGURO12',
   now() - interval '8 days', now() + interval '150 days', true, true),

  -- Accesorios
  ('20% en cubreasientos y accesorios', 'AutoAccesorios Pro', 'accesorios',
   '[EJEMPLO] Cubreasientos, alfombras, organizadores y soportes para el celular.', 'Santiago',
   'Hasta agotar stock. No aplica a ofertas ya rebajadas.', 'ACCESORIOS20',
   now() - interval '3 days', now() + interval '80 days', false, true),

  -- Otros
  ('Asistencia en ruta: primer mes gratis', 'Asistencia Ruta 5', 'otros',
   '[EJEMPLO] Grúa, cambio de neumático y paso de corriente durante el primer mes.', 'Todo Chile',
   'Un servicio por evento. Hasta 50 km de traslado.', 'RUTA5',
   now() - interval '12 days', now() + interval '110 days', false, true);
