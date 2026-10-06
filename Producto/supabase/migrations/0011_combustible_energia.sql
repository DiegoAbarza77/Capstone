-- Combustible y carga: soporte de kWh para híbridos y eléctricos, trazabilidad
-- del registro con IA y marca de "estanque lleno" para calcular el rendimiento.
--
-- Las columnas litros y precio_litro se conservan con esos nombres para no
-- romper los registros existentes, pero ahora guardan la CANTIDAD y el PRECIO
-- POR UNIDAD, sea cual sea la unidad (litros o kWh).

alter table public.combustible_cargas
  add column unidad text not null default 'litros' check (unidad in ('litros', 'kwh')),
  add column origen text not null default 'manual' check (origen in ('manual', 'ia')),
  add column ai_capturado_en timestamptz,
  add column archivo_nombre text,
  -- Solo las cargas con estanque (o batería) lleno sirven para estimar el
  -- rendimiento: se compara lo cargado entre dos llenados sucesivos.
  add column tanque_lleno boolean not null default false;

comment on column public.combustible_cargas.litros is
  'Cantidad cargada, en la unidad indicada por la columna unidad (litros o kWh).';
comment on column public.combustible_cargas.precio_litro is
  'Precio por unidad (por litro o por kWh).';
