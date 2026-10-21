# TAG OK 2.0 · Resumen del proyecto y de la Fase 2

Documento de síntesis: qué es el proyecto, cómo evolucionó de la versión 1 a la 2, qué se construyó en la Fase 2, en qué estado está cada caso de uso y qué falta.

> Las cifras y estados de este documento salen del repositorio al momento de escribirlo. Cuando dice "probado" se refiere a pruebas automáticas o a una prueba hecha por una persona; cuando dice "sin probar en pantalla", el código compila y pasa sus pruebas, pero nadie lo ha recorrido todavía en la aplicación.

---

## 1. Qué es TAG OK

Una aplicación para conductores chilenos que ayuda a controlar **lo que cuesta tener un auto**, con un panel web para administrar la plataforma. Es un proyecto de portafolio de título.

- **App del conductor:** Flutter (móvil, web y escritorio).
- **Panel de administración:** Flutter web.
- **Back end:** Supabase (PostgreSQL, autenticación, almacenamiento de archivos, tiempo real y funciones en el servidor).
- **Mapas y rutas:** Mapbox.
- **Inteligencia artificial:** Google Gemini, siempre a través de una función propia en el servidor.

## 2. De la versión 1 a la versión 2

| | Versión 1 | Versión 2 |
|---|---|---|
| Alcance | Solo el cobro del TAG en cada viaje | Asistente integral del vehículo |
| Datos | Firebase (Firestore) | Supabase (PostgreSQL) |
| Seguridad | Reglas de Firebase y lógica en la app | Seguridad por fila en la propia base de datos (RLS) |
| IA | Auditar boletas de peaje | Además, leer documentos, boletas de taller, tickets de estacionamiento y boletas de combustible |
| Registro de datos | Manual | Manual o con IA, siempre con revisión antes de guardar |

**Todo lo de la versión 1 se conserva:** navegación en tiempo real, cálculo de peajes (tarifa base, punta y saturación), presupuesto con alertas, auditoría de boletas de las concesionarias y panel de administración.

**Regla de oro de la IA:** ningún dato leído por la IA se guarda solo. Siempre pasa por una pantalla de revisión donde la persona confirma o corrige, y lo que la IA no pudo leer queda destacado.

## 3. Arquitectura

```
 App del conductor (Flutter)      Panel de administración (Flutter web)
            │                                   │
            └──────────────┬────────────────────┘
                           ▼
                       SUPABASE
        ┌──────────────────┼───────────────────┐
        ▼                  ▼                   ▼
   Autenticación   PostgreSQL + RLS      Funciones en el servidor
                   Almacenamiento        ├─ gemini-proxy ──► Google Gemini
                   Tiempo real           ├─ create-admin
                                         └─ delete-user
        App ──► Mapbox (rutas, direcciones y mapas)
```

- **Funciones en el servidor (3):** `gemini-proxy` (con límites de tamaño, tipo de archivo y 10 llamadas por minuto por usuario), `create-admin` y `delete-user`.
- **Base de datos:** 14 tablas y 16 migraciones, con seguridad por fila en todas.
- **Almacenamiento:** 6 buckets: `avatars`, `vehiculo_fotos`, `beneficios_imagenes` (públicos de lectura) y `mantencion_docs`, `estacionamiento_docs`, `combustible_docs` (privados, cada persona solo accede a su carpeta).

## 4. Fase 2: alcance y estado por módulo

| Módulo | Estado | Qué incluye |
|---|---|---|
| **Cuentas** | ✅ 100% | Registro, inicio de sesión, recuperación y cambio de contraseña, foto de perfil, edición de datos tocando cada campo |
| **Mi Vehículo** | ✅ ~95% | Ficha completa, 4 formatos de patente, foto, alias, kilometraje, 4 documentos legales (manual o con IA), estado general, eliminar vehículo |
| **Mantenciones** | ✅ ~90% | Registro manual o con IA, línea de tiempo, boleta adjunta, próxima mantención por fecha, kilometraje o ambos, recordatorios |
| **Estacionamientos** | ✅ ~85% | Registro manual o con IA, cronómetro que sobrevive al cierre de la app, ubicación GPS con mapa, historial y gasto del mes |
| **Combustible** | ✅ ~90% | Registro parcial, litros o kWh, lectura de boleta con IA ("Carga detectada"), historial por mes, rendimiento, modificar y eliminar |
| **Beneficios** | ✅ ~85% | Catálogo con filtros por categoría, ubicación y vigencia, detalle con código de canje, y administración desde el panel |
| **Dashboard "Mi Auto"** | ⚠️ ~40% | Pestaña central con estado, alertas y los seis módulos; falta el resumen de gastos por categoría |

### Mi Auto, el punto de entrada
Una sola pestaña desde la que se llega a todo: el vehículo elegido con su estado, alertas de documentos vencidos y mantenciones próximas, el estacionamiento en curso, y una cuadrícula con Documentos, Combustible, Mantenciones, Estacionamientos, Beneficios y Mis vehículos.

### Los cinco puntos donde actúa la IA
1. Documentos del vehículo (permiso, revisión técnica, SOAP, seguro).
2. Boletas de peaje (auditoría contra el GPS).
3. Boletas y facturas de taller.
4. Tickets de estacionamiento.
5. Boletas de combustible y de carga eléctrica.

### Panel de administración
- Ya existían: usuarios, pórticos, tarifas, reportes de peajes, auditoría y gestión de administradores.
- Nuevo: **Beneficios y Alianzas** (crear, editar, activar, desactivar, destacar y subir imagen) y **Métricas y Reportes** (usuarios activos, vehículos, documentos procesados por IA, gasto por categoría y crecimiento mensual, con filtro de fechas, solo con datos agregados).

## 5. Casos de uso

| CU | Caso de uso | Estado | Pendiente |
|---|---|---|---|
| 1 | Autenticarse | ✅ | |
| 2 | Crear cuenta | ✅ | El registro pide nombre y teléfono, más que el documento |
| 3 | Registrar vehículo | ✅ | |
| 4 | Ficha del vehículo | ✅ | |
| 5 | Documentos | ⚠️ | No se pueden eliminar |
| 6 | Estado y vencimientos | ⚠️ | Notificaciones sin probar en un teléfono |
| 7 | Registrar mantención | ✅ | Probado con IA y 2 boletas |
| 8 | Historial de mantenciones | ✅ | Sin recorrer en pantalla |
| 9 | Programar próxima mantención | ✅ | Sin recorrer en pantalla |
| 10 | Registrar estacionamiento | ✅ | Sin probar en pantalla |
| 11 | Cronómetro y GPS | ✅ | Necesita un teléfono para probarse |
| 12 | Historial de estacionamientos | ✅ | Sin probar en pantalla |
| 13 | Registrar combustible | ✅ | Sin probar en pantalla |
| 14 | Historial de combustible | ✅ | Sin probar en pantalla |
| 15 | Catálogo de beneficios | ✅ | Sin probar en pantalla |
| 16 | Dashboard Mi Auto | ⚠️ | Falta el resumen de gastos por categoría |
| 17 | Modificar o eliminar registros | ⚠️ | Falta eliminar documentos |
| 18 | Gestión de usuarios | ❓ | No revisado: buscar por correo y suspender cuentas |
| 19 | Beneficios (panel) | ✅ | Sin probar en pantalla |
| 20 | Métricas globales | ✅ | Sin probar en pantalla |

**Resumen:** 15 completos en código, 4 parciales, 1 sin revisar.

## 6. Base de datos

**14 tablas:** `usuarios`, `administradores`, `vehiculos`, `vehiculo_documentos`, `combustible_cargas`, `mantenciones`, `mantenciones_programadas`, `estacionamientos`, `trips`, `audited_invoices`, `porticos`, `tarifas`, `beneficios`, `auditoria`.

**Lo que falta para un modelo lógico y relacional completo:**
- Una columna de estado en `usuarios` para suspender cuentas (CU18).
- Entidades que hoy viven dentro de campos JSON o de listas: los cruces de peaje, el detalle de las boletas, y los servicios y repuestos de cada mantención.
- Claves foráneas en lugar de texto para el vehículo principal y para el administrador en la bitácora; y una entidad de comercios.
- Los catálogos (tipos de documento, de mantención, categorías) hoy son restricciones de valores y no tablas.

## 7. Calidad

- **Pruebas automáticas:** 226 en la app y 44 en el panel, todas pasan. Cubren la lógica: cálculos, validaciones, lectura de la IA con respuestas simuladas, fechas y filtros.
- **Seguridad:** seguridad por fila en todas las tablas, clave de Gemini solo en el servidor, límites en la función de IA, borrado de usuarios restringido a `super_admin`, archivos privados por carpeta de usuario.
- **Lo que las pruebas no cubren:** que las pantallas se vean y funcionen bien, el GPS, las notificaciones y la IA real con comprobantes reales, salvo Mantenciones.

## 8. Cómo se instala y se ejecuta
- **`INSTALACION.md`:** montar el proyecto desde cero.
- **`GUIA_APK.md`:** generar e instalar la app en un celular Android, y cómo actualizarla.
- **Datos de prueba ficticios:** boletas de taller, tickets de estacionamiento y boletas de combustible en `Producto/tag_ok/test/fixtures/`, y beneficios de ejemplo en `Producto/supabase/seeds/`.

## 9. Pendientes y riesgos

**Para dejar la Fase 2 cerrada**
1. Aplicar en Supabase las migraciones `0013` a `0016`, en orden.
2. Recorrer en pantalla Estacionamientos, Beneficios, Combustible y el panel nuevo.
3. Instalar la app en un celular, necesario para el GPS, el cronómetro y las notificaciones.
4. Resumen de gastos del dashboard (CU16).
5. Eliminar documentos (CU5) y revisar la gestión de usuarios (CU18).

**Para el proyecto**
6. Modelo lógico, modelo relacional y script completo de la base de datos.
7. Actualizar README e `INSTALACION.md` con las migraciones 0011 a 0016.
8. Limpiar restos de la versión anterior: la llave de Firebase y las dependencias de Firebase en `requirements.txt`.
9. Reemplazar la prueba por defecto del panel (`admin/test/widget_test.dart`), que es la plantilla de Flutter y no corresponde al proyecto.
10. Notificaciones: decidir con cuánta anticipación avisar y que el interruptor del Perfil cancele los avisos ya programados.

**Riesgo principal:** el trabajo reciente debe estar guardado en git. Conviene hacer commit y push después de cada bloque terminado.
