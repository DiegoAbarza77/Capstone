-- =====================================================================
-- TAG OK 2.0 · Script de poblado (datos de ejemplo)
-- =====================================================================
--
-- Llena las tablas con datos de muestra para demos y pruebas.
--
-- CÓMO USARLO
--   1. Ejecuta primero 03_SCRIPT_COMPLETO.sql (crea las tablas y carga los pórticos).
--   2. Crea al menos UNA cuenta de conductor desde la app (Crear Cuenta).
--   3. Pega este archivo en el SQL Editor de Supabase y ejecútalo.
--
-- QUÉ HACE
--   - Catálogos (tarifas y beneficios): se insertan siempre, sin duplicar.
--   - Datos de ejemplo: se cargan en la cuenta de conductor MÁS ANTIGUA
--     (vehículos, documentos, combustible, mantenciones, estacionamientos,
--     viaje y auditoría). Es seguro volver a ejecutarlo: no repite lo ya cargado.
--
-- NOTA: los usuarios no se insertan aquí porque dependen de auth.users
-- (Supabase Auth); por eso se parte de una cuenta creada desde la app.
-- No ejecutar en producción con datos reales.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Catálogo de tarifas
-- ---------------------------------------------------------------------
insert into public.tarifas (nombre, datos)
select 'Tarifas base 2026',
       '{"moneda":"CLP","vigencia":"2026","categorias":{"AUTO":1.0,"CAMIONETA":1.0,"MOTO":0.5},"horarios":["base","punta","saturacion"]}'::jsonb
where not exists (select 1 from public.tarifas where nombre = 'Tarifas base 2026');

-- ---------------------------------------------------------------------
-- 2. Catálogo de beneficios
-- ---------------------------------------------------------------------
insert into public.beneficios
  (nombre, descripcion, categoria, ubicacion, vigencia_desde, vigencia_hasta,
   condiciones, destacado, activo, comercio, codigo_canje)
select v.nombre, v.descripcion, v.categoria, v.ubicacion, v.desde, v.hasta,
       v.condiciones, v.destacado, true, v.comercio, v.codigo
from (values
  ('10% de descuento en combustible', 'Descuento en cargas de bencina y diésel presentando tu código.', 'combustible', 'Región Metropolitana', now() - interval '30 days', now() + interval '180 days', 'Tope de 40 litros por carga. No acumulable con otras promociones.', true, 'Estación Ejemplo', 'TAGOK10'),
  ('Revisión gratuita de frenos', 'Chequeo de frenos sin costo al contratar una mantención preventiva.', 'talleres', 'Santiago', now() - interval '10 days', now() + interval '90 days', 'Previa reserva de hora.', false, 'Taller Ejemplo', 'FRENOS2026'),
  ('15% en cambio de aceite', 'Descuento en cambio de aceite y filtro.', 'mantenciones', 'Todo Chile', now() - interval '5 days', now() + interval '120 days', 'Válido de lunes a viernes.', false, 'Lubricentro Ejemplo', 'ACEITE15'),
  ('Lavado de auto con descuento', 'Lavado completo con 20% de descuento.', 'lavado', 'Santiago', now(), now() + interval '60 days', 'Un lavado por mes.', false, 'Lavacar Ejemplo', 'LAVA20'),
  ('SOAP con precio especial', 'Cotiza tu SOAP con tarifa preferente.', 'seguros', 'Online', now(), now() + interval '300 days', 'Presentar patente del vehículo.', true, 'Seguros Ejemplo', 'SOAPTAG')
) as v(nombre, descripcion, categoria, ubicacion, desde, hasta, condiciones, destacado, comercio, codigo)
where not exists (select 1 from public.beneficios b where b.nombre = v.nombre);

-- ---------------------------------------------------------------------
-- 3. Datos de ejemplo para la cuenta de conductor más antigua
-- ---------------------------------------------------------------------
do $$
declare
  u uuid;
  v1 uuid;
  v2 uuid;
begin
  select id into u from public.usuarios order by fecha_creacion asc limit 1;
  if u is null then
    raise notice 'No hay cuentas en public.usuarios: crea una cuenta desde la app y vuelve a ejecutar.';
    return;
  end if;

  -- Si ya tiene vehículos no se vuelve a poblar
  if exists (select 1 from public.vehiculos where usuario_id = u) then
    raise notice 'La cuenta ya tiene vehículos: no se cargan datos de ejemplo.';
    return;
  end if;

  update public.usuarios
     set nombre_mostrar = coalesce(nombre_mostrar, 'Conductor Demo'),
         limite_presupuesto_mensual = case when limite_presupuesto_mensual = 0 then 60000 else limite_presupuesto_mensual end
   where id = u;

  -- Vehículos
  insert into public.vehiculos (usuario_id, patente, categoria, marca, modelo, anio, tipo_combustible, kilometraje, alias)
  values (u, 'ABCD12', 'AUTO', 'Toyota', 'Corolla', 2020, 'Bencina', 48500, 'Auto familiar')
  returning id into v1;

  insert into public.vehiculos (usuario_id, patente, categoria, marca, modelo, anio, tipo_combustible, kilometraje, alias)
  values (u, 'WXYZ34', 'CAMIONETA', 'Chevrolet', 'D-Max', 2018, 'Diésel', 92300, 'Camioneta trabajo')
  returning id into v2;

  update public.usuarios set vehiculo_principal_patente = 'ABCD12' where id = u;

  -- Documentos del vehículo principal
  insert into public.vehiculo_documentos (vehiculo_id, tipo, numero, fecha_emision, fecha_vencimiento, compania, origen)
  values
    (v1, 'permiso_circulacion', 'PC-2026-001234', date '2026-03-01', date '2027-03-31', null, 'manual'),
    (v1, 'revision_tecnica',    'RT-880045',      date '2026-06-10', date '2027-06-30', null, 'ia'),
    (v1, 'soap',                'SOAP-55012',     date '2026-04-01', date '2027-03-31', 'Aseguradora Ejemplo', 'manual'),
    (v1, 'seguro',              'POL-998877',     date '2026-05-15', date '2027-05-15', 'Aseguradora Ejemplo', 'manual');

  -- Combustible
  insert into public.combustible_cargas
    (usuario_id, vehiculo_id, vehiculo_patente, fecha, kilometraje, estacion, tipo_combustible, litros, precio_litro, total, unidad, origen, tanque_lleno)
  values
    (u, v1, 'ABCD12', now() - interval '25 days', 48000, 'Estación Ejemplo Centro', '95', 38.5, 1350, 51975, 'litros', 'manual', true),
    (u, v1, 'ABCD12', now() - interval '12 days', 48420, 'Estación Ejemplo Norte',  '95', 34.0, 1360, 46240, 'litros', 'ia',     true),
    (u, v2, 'WXYZ34', now() - interval '8 days',  92200, 'Estación Ejemplo Sur',    'Diésel', 55.0, 1180, 64900, 'litros', 'manual', true);

  -- Mantenciones realizadas
  insert into public.mantenciones
    (usuario_id, vehiculo_id, fecha, kilometraje, tipo, taller, costo, descripcion, servicios, repuestos, origen)
  values
    (u, v1, now() - interval '60 days', 45000, 'aceite', 'Taller Ejemplo', 89900, 'Cambio de aceite y filtro', array['Cambio de aceite','Cambio de filtro de aceite'], array['Aceite 5W-30','Filtro de aceite'], 'manual'),
    (u, v1, now() - interval '20 days', 47800, 'frenos', 'Taller Ejemplo', 125000, 'Cambio de pastillas delanteras', array['Cambio de pastillas'], array['Pastillas de freno delanteras'], 'ia');

  -- Mantenciones programadas
  insert into public.mantenciones_programadas
    (usuario_id, vehiculo_id, tipo, descripcion, fecha_programada, km_programado)
  values
    (u, v1, 'preventiva', 'Mantención de los 50.000 km', current_date + 30, 50000),
    (u, v2, 'neumaticos', 'Rotación de neumáticos', current_date + 15, null);

  -- Estacionamientos
  insert into public.estacionamientos
    (usuario_id, vehiculo_id, fecha, lugar, direccion, lat, lng, hora_entrada, hora_salida, costo, duracion_minutos, en_curso, origen)
  values
    (u, v1, now() - interval '3 days', 'Estacionamiento Mall Ejemplo', 'Av. Ejemplo 1234, Santiago', -33.4489, -70.6693,
     now() - interval '3 days 150 minutes', now() - interval '3 days', 3750, 150, false, 'ia'),
    (u, v1, now() - interval '1 day', 'Playa Centro', 'Calle Ejemplo 55, Santiago', -33.4372, -70.6506,
     now() - interval '1 day 90 minutes', now() - interval '1 day', 2000, 90, false, 'manual');

  -- Viaje con peajes
  insert into public.trips (usuario_id, date, total_cost, distance_km, duration, vehicle_name, tolls)
  values (u, now() - interval '2 days', 1055.13, 22.4, '35 min', 'ABCD12',
          '[{"name":"P3 Ruta 68 - Costanera Norte","cost":351.71,"timestamp":"2026-11-14T08:15:00"},
            {"name":"P14 Guanaco - El Salto","cost":703.42,"timestamp":"2026-11-14T08:32:00"}]'::jsonb);

  -- Auditoría de una cuenta de autopista
  insert into public.audited_invoices
    (usuario_id, concessionaire, period, patent, total_billed, total_matched, status, reconciliation_rate, details, ai_report, audited_by)
  values (u, 'Ruta 68', 'Octubre 2026', 'ABCD12', 4200, 3850, 'Con discrepancias', 91.7,
          '[{"portico":"P3 Ruta 68","monto":351.71,"status":"Correcto"},
            {"portico":"P14 Guanaco","monto":350,"status":"Sin viaje registrado"}]'::jsonb,
          'Se concilió el 91,7% del total cobrado. Revisar un cobro sin viaje asociado.', 'Gemini');

  raise notice 'Datos de ejemplo cargados para el usuario %', u;
end $$;
