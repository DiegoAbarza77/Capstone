# TAG OK 2.0

**Tu copiloto inteligente para la gestión integral de tu vehículo.**

> Evoluciona desde una app enfocada en el control de cobros de TAG hacia un asistente inteligente que centraliza vehículo, documentos, gastos y beneficios del conductor en un solo lugar.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.x-blue.svg)](https://dart.dev/)
[![Supabase](https://img.shields.io/badge/Supabase-Postgres%20%2B%20Auth%20%2B%20RLS-3ECF8E.svg)](https://supabase.com/)
[![Mapbox](https://img.shields.io/badge/Mapbox-GL%20Maps-000000.svg)](https://www.mapbox.com/)
[![Gemini](https://img.shields.io/badge/Gemini-AI-8B5CF6.svg)](https://ai.google.dev/)

---

## Tabla de Contenidos

* [Descripción](#descripcion)
* [Estado del proyecto](#estado-del-proyecto)
* [Evolución: de v1 a 2.0](#evolucion)
* [Fase 1 — Gestión de TAG y viajes](#fase-1)
* [Fase 2 — Asistente inteligente](#fase-2)
* [Registro Inteligente con IA](#registro-inteligente)
* [Panel de Administración](#panel-admin)
* [Arquitectura y Seguridad](#arquitectura-seguridad)
* [Instalación y Ejecución](#instalacion) (guía detallada en [INSTALACION.md](INSTALACION.md))
* [Stack Tecnológico](#stack)
* [Estructura del Proyecto](#estructura)
* [Objetivo](#objetivo)

---

<a id="descripcion"></a>

## Descripción

**TAG OK** es una suite para conductores chilenos: una app móvil/web y un panel de administración que, además de calcular en tiempo real el costo de tus viajes por autopistas concesionadas, está evolucionando hacia un **asistente integral del vehículo** — documentos, mantenciones, combustible, estacionamientos y beneficios, todo en un solo lugar, con captura asistida por Inteligencia Artificial.

---

<a id="estado-del-proyecto"></a>

## Estado del proyecto

Este README refleja el estado del código. Los módulos de la Fase 2 están **implementados y cubiertos por pruebas automáticas**, pero la mayoría **aún no se ha recorrido en pantalla ni en un celular real** (GPS, cronómetro y recordatorios necesitan un teléfono). Última verificación en vivo contra Supabase: **22 de septiembre de 2026**. La base de datos va hasta la migración **0017**.

| Módulo | Estado |
| :----- | :----- |
| Backend, autenticación y seguridad (Supabase Auth + Postgres + RLS) | Migrado desde Firebase y verificado en vivo |
| Mi Vehículo (datos + documentos + vencimientos) | Implementado, documentos manual o con IA |
| Mantenciones | Implementado (manual o con IA, historial, próxima mantención y recordatorios); falta probar los recordatorios en celular |
| Estacionamientos + cronómetro | Implementado (manual o con IA, cronómetro, GPS y mapa); falta probar GPS y cronómetro en celular |
| Combustible y carga eléctrica | Implementado (registro manual o con IA, historial y rendimiento) |
| Beneficios (catálogo + backoffice) | Implementado (catálogo con filtros y código de canje, administración desde el panel) |
| TAG, viajes y presupuesto (heredado de Fase 1) | Implementado |
| Registro Inteligente con IA | Implementado: cubre auditoría de boletas, documentos, mantenciones, estacionamientos y combustible, siempre con pantalla de revisión y confirmación |
| Panel de Administración (usuarios, suspensión de cuentas, pórticos, tarifas, reportes, auditoría, admins, beneficios, métricas) | Implementado; beneficios y métricas sin recorrer en pantalla |
| Dashboard "Mi Auto" integrador | Parcial: estado, alertas y acceso a los módulos; falta el resumen de gastos por categoría |

---

<a id="evolucion"></a>

## Evolución: de v1 a 2.0

**v1** estaba enfocada en el control de cobros de TAG: navegación con cálculo de tarifas en tiempo real, gestión de vehículos y presupuesto, y auditoría de boletas con IA — todo sobre **Firebase** (Auth + Firestore).

**2.0** conserva y mejora todo lo anterior, y además:

* Migra el backend completo de **Firebase a Supabase** (Postgres + Row Level Security + Edge Functions), corrigiendo de paso varios bugs de seguridad que existían en las reglas de Firestore.
* Amplía el alcance del producto hacia un asistente integral del vehículo: documentos, mantenciones, estacionamientos, combustible y beneficios.
* Formaliza la regla **"Manual + IA → Revisión → Confirmar → Guardar"**: ningún dato extraído por IA se guarda sin que el usuario lo revise y confirme.
* Agrega soporte para auditar boletas **desde una foto**, no solo PDF/CSV/XLSX.
* Mueve las llamadas a la IA de Gemini a **Edge Functions de servidor**, para que ninguna llave de API quede expuesta en la app.

---

<a id="fase-1"></a>

## Fase 1 — Gestión de TAG y viajes

Base del sistema: control de viajes, vehículos, usuarios y pórticos.

* **Usuarios** — información básica del conductor y sus preferencias.
* **Vehículos** — patente, marca, categoría, fecha de ingreso, vehículo principal.
* **Pórticos y tarifas** — cálculo dinámico según el tipo de tarifa: **TBFP** (Base Fuera de Punta), **TBP** (Base Punta), **TS** (Saturación).
* **Viajes** — registro y consulta de recorridos; detección de pórticos en la ruta vía GPS (Mapbox + Geolocator).
* **Presupuesto** — límite mensual con semaforización de alertas al 50%, 75%, 90% y 100% de uso.

---

<a id="fase-2"></a>

## Fase 2 — Asistente inteligente para el conductor

### Mi Vehículo

Ficha central del vehículo: patente (4 formatos chilenos), marca, modelo, año, categoría, tipo de combustible, kilometraje, alias y foto. Se pueden tener varios vehículos y eliminarlos.

**Documentos**: Permiso de Circulación, Revisión Técnica, SOAP y Seguro Automotriz, cada uno con número, fechas y compañía, registrados de forma manual o fotografiando el documento para que la IA precargue el formulario. Un semáforo calcula el estado — *Al día* / *Por vencer* / *Vencido*.

### Mantenciones

Bitácora con fecha, kilometraje, taller, costo, descripción y boleta adjunta, registrada de forma manual o con IA, que además clasifica el tipo (preventiva, cambio de aceite, frenos, neumáticos, otra). Línea de tiempo de historial y próxima mantención programada por fecha, kilometraje o ambos, con recordatorios.

### Estacionamientos

Registro manual o desde la foto de un ticket (lugar, fecha, entrada/salida, duración y costo), cronómetro de "iniciar/finalizar" que sobrevive al cierre de la app, guardado de la ubicación GPS con mapa, historial y gasto del mes.

### Combustible

Registro de cargas con registros parciales: fecha, kilometraje, estación, tipo de combustible (bencina, diésel, híbrido o eléctrico), litros o kWh, precio y total. Se puede cargar la boleta como foto para precarga con IA ("Carga detectada"). Historial por mes, gasto y rendimiento por vehículo, con edición y eliminación.

### Beneficios

Catálogo filtrable en la app por categoría, ubicación y vigencia, con detalle y código de canje. Se administra desde el panel (crear, editar, activar/desactivar, destacar y subir imagen).

### Dashboard "Mi Auto"

Pestaña de entrada con el vehículo elegido, su estado, alertas de documentos vencidos y mantenciones próximas, el estacionamiento en curso y acceso a los seis módulos. **Pendiente:** el resumen del gasto del mes por categoría (TAG, combustible, estacionamiento, mantención).

---

<a id="registro-inteligente"></a>

## Registro Inteligente con IA

### Flujo (regla obligatoria en todo flujo que use IA)

```text
Foto / PDF / CSV / XLSX
        │
        ▼
  IA extrae los datos (Gemini, vía Edge Function — la llave nunca sale del servidor)
        │
        ▼
  Formulario precargado
        │
        ▼
  El usuario revisa y corrige
        │
        ▼
  Confirmar y Guardar  ←── nada se persiste sin este paso explícito
```

### Estado real por módulo

| Evidencia | Implementado en | Estado |
| :-------- | :--------------- | :----- |
| Boleta de peaje (PDF / CSV / XLSX / **foto**) | Auditoría | Implementado, con motor local determinístico + IA de respaldo, y pantalla de revisión obligatoria |
| Permiso / RT / SOAP / Seguro | Mi Vehículo → Documentos | Implementado |
| Boleta / factura de taller | Mantenciones | Implementado |
| Boleta de combustible o carga eléctrica | Combustible | Implementado |
| Ticket de estacionamiento | Estacionamientos | Implementado |

La auditoría de boletas también incluye un **motor 100% local y gratuito** (sin IA) que lee de forma nativa los formatos oficiales de Autopista Central (CSV), y Costanera Norte / Vespucio Sur / Vespucio Norte (PDF), con la IA como respaldo cuando el formato no se reconoce — el usuario puede alternar entre ambos modos con un interruptor.

---

<a id="panel-admin"></a>

## Panel de Administración

Backoffice web para operar el negocio, verificado en vivo contra el mismo proyecto de Supabase que usan los clientes:

* **Dashboard** — viajes recientes, distribución de costos por autopista, uso y distribución de cobros, transacciones y usuarios recientes.
* **Usuarios** — búsqueda por nombre o correo, edición de presupuesto/nombre, reseteo de contraseña, suspensión y reactivación de cuentas, eliminación.
* **Beneficios y Alianzas** — crear, editar, activar, desactivar, destacar y subir imagen de los beneficios del catálogo.
* **Métricas y Reportes** — usuarios activos, vehículos, documentos procesados por IA, gasto por categoría y crecimiento mensual, con filtro de fechas y solo datos agregados.
* **Pórticos y Tarifas** — ABM en tiempo real de tarifa base/punta/saturación por pórtico.
* **Reportes** — métricas agregadas y desglose de costos por concesionaria.
* **Auditoría (bitácora)** — registro inmutable de cada acción administrativa, con quién, cuándo y qué cambió.
* **Admins** — gestión de roles (`operador` / `super_admin`); crear y eliminar administradores pasa por Edge Functions con verificación de rol en el servidor, no en el cliente.

Todos los cambios se reflejan **en tiempo real** en la app de los usuarios (Supabase Realtime).

---

<a id="arquitectura-seguridad"></a>

## Arquitectura y Seguridad

La migración de Firebase a Supabase no fue solo un cambio de proveedor — se aprovechó para corregir varios problemas de seguridad y diseño que existían en la versión anterior:

* **Row Level Security (RLS) versionada y testeada.** Cada tabla tiene políticas explícitas (dueño-o-admin) en archivos SQL versionados en el repo (`Producto/supabase/migrations/`), no reglas ad hoc solo en el cliente.
* **Sin escalación de privilegios por defecto.** Las reglas de Firestore anteriores asignaban `super_admin` por defecto si faltaba el campo de rol; las políticas de Supabase no tienen esa rama — sin rol explícito, no hay privilegios.
* **Operaciones sensibles en el servidor, no en el cliente.** Crear o eliminar un administrador corre en **Edge Functions** con la *service-role key* (nunca expuesta al cliente) y verifica el rol de quien llama antes de ejecutar nada — reemplaza un truco anterior que abría una segunda sesión de Firebase en el propio cliente.
* **Ninguna llave de IA en el navegador.** Las llamadas a Gemini pasan por una Edge Function (`gemini-proxy`); la API key vive solo como secreto de servidor.
* **Referencias de dueño sin ambigüedad.** `vehiculos.usuario_id` es ahora una llave foránea `uuid` real hacia `auth.users`, eliminando un bug donde el dueño de un vehículo podía quedar guardado como texto o como referencia según la pantalla.

---

<a id="instalacion"></a>

## Instalación y Ejecución

> ¿Primera vez montando el proyecto? Sigue la **[guía de instalación paso a paso](INSTALACION.md)**: incluye la configuración de Supabase, las Edge Functions, el primer administrador y los problemas frecuentes. Lo de abajo es un resumen.

### Requisitos

* [Flutter](https://flutter.dev/) y Dart (vienen juntos).
* Git.
* Una cuenta/proyecto en [Supabase](https://supabase.com/) (gratis, sin tarjeta) con todas las migraciones SQL de `Producto/supabase/migrations/` aplicadas en orden (0001 a 0017) y las 3 Edge Functions de `Producto/supabase/functions/` desplegadas.
* Credenciales de Mapbox y Gemini (opcionales para probar solo Auth/datos; requeridas para mapas e IA).

### Pasos

```bash
git clone https://github.com/DiegoAbarza77/Capstone.git
cd Capstone/Producto
```

Corre `setup.bat` (Windows) — instala las dependencias de ambas apps y te deja un menú para ejecutarlas. La primera vez genera `tag_ok/.env` y `admin/.env` **con una plantilla vacía que debes completar**:

```env
# Producto/tag_ok/.env
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_ANON_KEY=tu-anon-key
MAPBOX_ACCESS_TOKEN=tu-token-de-mapbox

# Producto/admin/.env
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_ANON_KEY=tu-anon-key
```

> A diferencia de la v1, estas credenciales **son obligatorias** — la app no arranca sin ellas. El instalador te avisa con un mensaje claro si intentas ejecutar la app antes de completar el `.env`, en vez de dejar que la app falle en silencio.
>
> `GEMINI_API_KEY` **no** va en ningún `.env` de la app — vive solo como secreto de la Edge Function `gemini-proxy` en el dashboard de Supabase, nunca en el cliente.

O manualmente:

```bash
cd tag_ok && flutter pub get && flutter run
cd ../admin && flutter pub get && flutter run
```

---

<a id="stack"></a>

## Stack Tecnológico

| Componente | Tecnología |
| :--------- | :--------- |
| **Framework** | Flutter (móvil, web y desktop) |
| **Lenguaje** | Dart |
| **Base de datos** | Supabase (Postgres + Row Level Security) |
| **Autenticación** | Supabase Auth |
| **Funciones de servidor** | Supabase Edge Functions (Deno) |
| **Tiempo real** | Supabase Realtime |
| **Mapas** | Flutter Map + Mapbox API |
| **Inteligencia Artificial** | Google Gemini (vía Edge Function) |
| **Procesamiento de archivos** | file_picker, syncfusion_flutter_pdf, excel |
| **Control de versiones** | Git + GitHub |

---

<a id="estructura"></a>

## Estructura del Proyecto

```text
TAG-OK2.1/
│
├── Producto/
│   ├── setup.bat                # Instalador + menú de ejecución
│   │
│   ├── tag_ok/                  # App móvil/web (Flutter)
│   ├── admin/                   # Panel de administración (Flutter)
│   │
│   ├── supabase/
│   │   ├── migrations/          # Esquema SQL + RLS, numerado (0001 a 0017)
│   │   ├── functions/           # Edge Functions (create-admin, delete-user, gemini-proxy)
│   │   └── seeds/               # Datos de ejemplo (beneficios)
│   │
│   └── Base de datos/           # Modelo lógico y relacional, script completo (Supabase) y exportación histórica de la v1 (Firebase)
│
├── INSTALACION.md               # Guía de instalación paso a paso
├── GUIA_APK.md                  # Generar e instalar la app en un Android
├── RESUMEN_FASE_2.md            # Resumen del alcance y estado de la Fase 2
└── README.md
```

---

<a id="objetivo"></a>

## Objetivo

Dar a los conductores una solución centralizada para administrar la información, los gastos y las actividades de su vehículo, reduciendo el ingreso manual de datos mediante IA — sin nunca guardar un dato que el usuario no haya confirmado.

---

**TAG OK 2.0** · Asistente inteligente para el conductor · [gruposentte.cl](https://gruposentte.cl)
