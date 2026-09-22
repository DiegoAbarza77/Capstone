# Tag OK 🚗💨

**Tu copiloto inteligente para la gestión integral de tu vehículo.**

> TAG OK 2.0 evoluciona desde una aplicación enfocada al control de cobros TAG hacia un asistente inteligente que centraliza la información, gastos, documentos, mantenciones y necesidades del conductor en una sola aplicación.

---

## 📋 Tabla de Contenidos

* [Descripción](#descripcion)
* [Evolución del Proyecto](#evolucion-del-proyecto)
* [Fase 1](#fase-1)
* [Fase 2](#fase-2)
* [Características Principales](#caracteristicas-principales)
* [Inteligencia Artificial](#inteligencia-artificial)
* [Dashboard y Visualización](#dashboard-y-visualizacion)
* [Panel de Administración](#panel-de-administracion)
* [Instalación y Ejecución](#instalacion-y-ejecucion)
* [Stack Tecnológico](#stack-tecnologico)
* [Estructura del Proyecto](#estructura-del-proyecto)
* [Módulos de TAG OK 2.0](#modulos-de-tag-ok-20)
* [Objetivo](#objetivo)

---

<a id="descripcion"></a>

## 📝 Descripción

**TAG OK 2.0** es una aplicación móvil diseñada para ayudar a los conductores a centralizar y gestionar la información relacionada con sus vehículos.

El proyecto nace como una evolución de la primera versión de TAG OK, originalmente enfocada principalmente en la gestión y control de cobros asociados al **TAG y los pórticos de autopistas**.

En esta nueva versión, el sistema amplía sus funcionalidades para convertirse en un **asistente inteligente para el conductor**, permitiendo gestionar en un solo lugar:

* 🚗 Información del vehículo.
* 🧾 Documentación obligatoria.
* 🛠️ Mantenciones.
* 🅿️ Estacionamientos.
* ⛽ Combustible.
* 🛣️ Viajes y gastos asociados al TAG.
* 📊 Presupuesto y estadísticas.
* 🤖 Extracción de información mediante Inteligencia Artificial.
* 🎁 Beneficios para conductores.

El objetivo es disminuir el ingreso manual de información y facilitar el control de los principales gastos y responsabilidades asociados al vehículo.

---

<a id="evolucion-del-proyecto"></a>

## 🔄 Evolución del Proyecto

### TAG OK V1

La primera versión estaba principalmente orientada a:

* Control de viajes mediante TAG.
* Identificación de pórticos.
* Cálculo de tarifas.
* Gestión de vehículos.
* Control de presupuesto.
* Historial de viajes.
* Auditoría de cobros mediante archivos.
* Panel administrativo para gestionar tarifas y pórticos.

### TAG OK 2.0

La segunda versión amplía el alcance para transformar TAG OK en un **asistente inteligente para el conductor**.

Además de mantener las funcionalidades relacionadas con TAG, incorpora nuevos módulos para administrar la información y los gastos generales del vehículo.

---

<a id="fase-1"></a>

## 🟦 Fase 1 — Gestión de TAG y viajes

La Fase 1 establece la base del sistema y se concentra en el control de viajes, vehículos, usuarios y pórticos.

### 👤 Usuarios

Permite gestionar la información básica del conductor y sus preferencias dentro de la aplicación.

### 🚗 Vehículos

Registro de vehículos asociados a cada usuario, incluyendo información como:

* Patente.
* Marca.
* Categoría.
* Fecha de ingreso.
* Vehículo principal.

### 🛣️ Pórticos

Registro de los pórticos utilizados para calcular los costos de los viajes.

El sistema contempla diferentes tipos de tarifas:

* **TBFP** — Tarifa Base Fuera de Punta.
* **TBP** — Tarifa Base Punta.
* **TS** — Tarifa de Saturación.

### 🗺️ Viajes

Permite registrar y consultar los recorridos realizados por el usuario.

El sistema puede utilizar información geográfica para identificar los pórticos presentes en una ruta y calcular el costo asociado.

### 💰 Presupuesto

Permite establecer un presupuesto mensual relacionado con los gastos del vehículo y visualizar su utilización.

---

<a id="fase-2"></a>

## 🟩 Fase 2 — Asistente inteligente para el conductor

La Fase 2 representa la evolución principal de TAG OK.

El objetivo es centralizar los diferentes gastos, documentos y actividades relacionadas con el vehículo, reduciendo la cantidad de información que el usuario debe ingresar manualmente.

### 🚗 Mi Vehículo

El módulo **Mi Vehículo** permite consultar y administrar la información principal del vehículo.

Incluye:

* Patente.
* Marca.
* Modelo.
* Categoría.
* Año.
* Kilometraje.
* Información general del vehículo.
* Documentación asociada.

El usuario puede mantener un historial actualizado de la información relevante de su vehículo.

---

### 📄 Gestión de Documentos

TAG OK 2.0 permite registrar documentos importantes asociados al vehículo.

Entre ellos:

* Permiso de Circulación.
* Revisión Técnica.
* SOAP.
* Seguro Automotriz.

#### 🤖 Registro mediante IA

El usuario puede cargar una fotografía o archivo PDF del documento.

La Inteligencia Artificial analiza el documento y extrae información relevante para realizar una **precarga automática del formulario**.

El usuario puede:

1. Seleccionar o cargar el documento.
2. Procesar el archivo mediante IA.
3. Revisar la información extraída.
4. Modificar los datos si es necesario.
5. Confirmar el registro.

Si la IA no puede extraer correctamente la información, el usuario puede utilizar el **formulario manual**.

Esto permite mantener el control de la información sin depender exclusivamente del procesamiento automático.

---

### 🛠️ Mantenciones

El módulo de **Mantenciones** permite registrar y consultar el historial de mantenimiento del vehículo.

Cada registro puede incluir:

* Taller.
* Fecha.
* Kilometraje.
* Servicios realizados.
* Repuestos utilizados.
* Monto.
* Tipo de mantención.

#### Categorías de mantención

* Preventiva.
* Cambio de aceite.
* Frenos.
* Neumáticos.
* Otra.

El historial permite al usuario consultar cuánto ha gastado en mantenimiento y mantener un registro organizado de los trabajos realizados.

---

### 🅿️ Estacionamientos

El módulo de **Estacionamientos** permite registrar los gastos relacionados con estacionamientos.

#### Registro manual

El usuario puede ingresar directamente:

* Lugar.
* Fecha.
* Hora de entrada.
* Hora de salida.
* Duración.
* Monto.

#### Registro mediante IA

El usuario puede cargar una fotografía o documento del comprobante.

La IA intenta identificar automáticamente:

* Lugar.
* Fecha.
* Hora de entrada.
* Hora de salida.
* Duración.
* Monto.

La información extraída puede ser modificada antes de confirmar el registro.

---

### ⏱️ Cronómetro de Estacionamiento

TAG OK 2.0 incorpora un cronómetro para facilitar el registro de estacionamientos.

El usuario puede:

1. **Iniciar estacionamiento.**
2. Mantener el cronómetro activo mientras permanece estacionado.
3. **Finalizar estacionamiento.**
4. Registrar la duración obtenida.

Esta funcionalidad permite simplificar el registro cuando el usuario no dispone de un comprobante al momento de ingresar.

---

### ⛽ Combustible

El módulo de **Combustible** permite registrar y consultar los gastos relacionados con cargas de combustible.

El usuario puede almacenar información como:

* Fecha.
* Tipo de combustible.
* Litros.
* Precio por litro.
* Monto total.
* Kilometraje.
* Estación de servicio.

Estos datos pueden utilizarse posteriormente para generar estadísticas sobre el consumo y los gastos del vehículo.

---

### 🛣️ TAG y gastos de viajes

Las funcionalidades relacionadas con TAG desarrolladas en la Fase 1 continúan formando parte de TAG OK 2.0.

El sistema permite mantener información relacionada con:

* Viajes.
* Pórticos.
* Tarifas.
* Costos de recorridos.
* Historial.
* Presupuesto.

De esta manera, los gastos de TAG pasan a formar parte de una visión más completa de los costos operativos del vehículo.

---

<a id="caracteristicas-principales"></a>

## ✨ Características Principales

### 🛰️ Navegación y viajes

* Cálculo de rutas.
* Visualización de recorridos.
* Identificación de pórticos presentes en una ruta.
* Cálculo de costos asociados a los pórticos.
* Manejo de tarifas según el período correspondiente.
* Historial de viajes.

### 🚗 Gestión del vehículo

* Registro de vehículos.
* Gestión de información del vehículo.
* Patentes.
* Kilometraje.
* Documentación.
* Historial de mantenciones.

### 💰 Gestión de gastos

* Gastos de TAG.
* Combustible.
* Estacionamientos.
* Mantenciones.
* Presupuesto mensual.
* Historial de gastos.

### 🤖 Automatización mediante IA

* Procesamiento de fotografías.
* Procesamiento de documentos PDF.
* Extracción de información.
* Precarga de formularios.
* Revisión y edición de información obtenida.
* Registro manual como alternativa.

---

<a id="inteligencia-artificial"></a>

## 🤖 Inteligencia Artificial

Uno de los principales componentes de TAG OK 2.0 es la utilización de Inteligencia Artificial para disminuir el ingreso manual de información.

La IA puede utilizarse para analizar documentos, comprobantes y fotografías relacionadas con el vehículo.

### Flujo general

```text
Usuario
   │
   ▼
Carga fotografía / PDF
   │
   ▼
Procesamiento mediante IA
   │
   ▼
Extracción de información
   │
   ▼
Formulario precargado
   │
   ▼
Usuario revisa y modifica
   │
   ▼
Confirmación
   │
   ▼
Registro en el sistema
```

### Principio de confirmación

La información obtenida mediante IA **no se registra automáticamente sin revisión del usuario**.

El usuario mantiene la posibilidad de:

* Revisar los datos.
* Corregir información.
* Completar campos faltantes.
* Confirmar el registro.

Si el procesamiento mediante IA no entrega información suficiente, el sistema permite realizar el ingreso de forma manual.

---

<a id="dashboard-y-visualizacion"></a>

## 📊 Dashboard y Visualización

TAG OK 2.0 busca centralizar la información de gastos del vehículo para facilitar su consulta.

El dashboard puede presentar información relacionada con:

* Gastos de TAG.
* Combustible.
* Estacionamientos.
* Mantenciones.
* Gastos totales.
* Presupuesto mensual.
* Distribución de gastos.
* Historial de gastos.

Esto permite que el usuario pueda visualizar cómo se distribuyen los costos asociados a su vehículo durante un período determinado.

### 💰 Control de Presupuesto

El sistema permite establecer un presupuesto mensual y controlar su utilización.

Se pueden generar diferentes niveles de alerta según el porcentaje utilizado:

| Porcentaje | Estado                   |
| :--------: | :----------------------- |
|     50%    | 🟢 Seguimiento           |
|     75%    | 🟡 Precaución            |
|     90%    | 🟠 Alerta                |
|    100%    | 🔴 Presupuesto alcanzado |

---

<a id="panel-de-administracion"></a>

## ⚙️ Panel de Administración

TAG OK 2.0 incluye un panel administrativo destinado a la gestión global del sistema.

### 👥 Usuarios

* Consulta de usuarios.
* Gestión de información.
* Administración de presupuestos.
* Gestión de cuentas.

### 🚗 Vehículos

* Consulta de vehículos registrados.
* Visualización de información general.
* Gestión administrativa.

### 🛣️ Pórticos y tarifas

* Gestión de pórticos.
* Actualización de tarifas.
* Administración de valores según horario o tipo de tarifa.

### 📊 Estadísticas

El panel puede mostrar métricas generales relacionadas con:

* Usuarios registrados.
* Vehículos.
* Documentos procesados mediante IA.
* Uso de los módulos.
* Registros de gastos.

---

<a id="instalacion-y-ejecucion"></a>

## 🚀 Instalación y Ejecución

### Requisitos

Antes de ejecutar el proyecto se recomienda contar con:

* Flutter.
* Dart.
* Android Studio.
* Git.
* Cuenta/proyecto configurado en Firebase.
* Credenciales de los servicios externos utilizados por el proyecto.

### Clonar el repositorio

```bash
git clone https://github.com/DiegoAbarza77/TagOK2.0.git
```

### Acceder al proyecto

```bash
cd TagOK2.0
```

### Instalar dependencias

Para la aplicación móvil:

```bash
cd Producto/tag_ok
flutter pub get
```

Para el panel administrativo:

```bash
cd ../admin
flutter pub get
```

### Ejecutar la aplicación

Aplicación móvil:

```bash
flutter run
```

Panel administrativo:

```bash
flutter run
```

> **Importante:** Las credenciales y claves utilizadas por servicios externos deben configurarse mediante el mecanismo definido para el entorno de desarrollo. No deben almacenarse como secretos directamente dentro del repositorio.

---

<a id="stack-tecnologico"></a>

## 🛠️ Stack Tecnológico

| Componente                    | Tecnología               |
| :---------------------------- | :----------------------- |
| **Framework**                 | Flutter                  |
| **Lenguaje**                  | Dart                     |
| **Base de Datos**             | Firebase Cloud Firestore |
| **Autenticación**             | Firebase Authentication  |
| **Mapas**                     | Flutter Map + Mapbox     |
| **Inteligencia Artificial**   | Google Gemini            |
| **Procesamiento de archivos** | File Picker              |
| **Procesamiento PDF**         | Syncfusion PDF           |
| **Archivos CSV**              | CSV                      |
| **Control de versiones**      | Git + GitHub             |

---

<a id="estructura-del-proyecto"></a>

## 📂 Estructura del Proyecto

```text
TAG-OK/
│
├── Producto/
│   │
│   ├── setup.bat
│   │
│   ├── tag_ok/
│   │   └── # Código fuente de la aplicación móvil
│   │
│   ├── admin/
│   │   └── # Código fuente del panel administrativo
│   │
│   └── Base de datos/
│       └── # Esquemas, reportes y configuración de datos
│
├── Documentacion/
│   └── # Documentación, diagramas, manuales y mockups
│
└── Gestion/
    └── # Cronogramas, Trello, backlog y gestión del proyecto
```

---

<a id="modulos-de-tag-ok-20"></a>

## 🧩 Módulos de TAG OK 2.0

```text
                         TAG OK 2.0
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
     🚗 Vehículo          💰 Gastos             🤖 IA
        │                     │                     │
        ├─ Documentos        ├─ TAG               ├─ PDF
        ├─ Información       ├─ Combustible       ├─ Imágenes
        └─ Estado            ├─ Estacionamiento   └─ Precarga
                             └─ Mantenciones
                                      │
                                      ▼
                              📊 Dashboard
                                      │
                                      ▼
                              ⚙️ Administración
```

### Resumen de módulos

| Módulo                   | Descripción                                      |
| :----------------------- | :----------------------------------------------- |
| 🚗 **Mi Vehículo**       | Información general y documentación del vehículo |
| 📄 **Documentos**        | Permiso de Circulación, RT, SOAP y Seguro        |
| 🛠️ **Mantenciones**     | Historial de servicios, repuestos y gastos       |
| 🅿️ **Estacionamientos** | Registro de estacionamientos y gastos            |
| ⏱️ **Cronómetro**        | Control de duración del estacionamiento          |
| ⛽ **Combustible**        | Registro y seguimiento de cargas de combustible  |
| 🛣️ **TAG**              | Viajes, pórticos, tarifas y costos               |
| 💰 **Presupuesto**       | Control del gasto mensual                        |
| 🤖 **IA**                | Extracción y precarga de información             |
| 📊 **Dashboard**         | Visualización y análisis de gastos               |
| 🎁 **Beneficios**        | Catálogo de beneficios para conductores          |
| ⚙️ **Administración**    | Gestión global del sistema                       |

---

<a id="objetivo"></a>

## 🎯 Objetivo

El objetivo de **TAG OK 2.0** es proporcionar una solución centralizada para que los conductores puedan **administrar la información, gastos y actividades relacionadas con sus vehículos**, reduciendo el ingreso manual de datos mediante herramientas de Inteligencia Artificial.

La aplicación busca integrar en un mismo ecosistema la información que normalmente se encuentra distribuida entre documentos, comprobantes, aplicaciones, sitios web y registros personales.

---

## TAG OK 2.0

**Asistente inteligente para el conductor.**

Una plataforma para centralizar la gestión del vehículo, sus gastos, documentos y actividades en un solo lugar.

---

