# Guía de instalación — TAG OK 2.0

Esta guía deja el proyecto funcionando en un computador nuevo con Windows. Son tres partes: **herramientas**, **Supabase** (el back end) y **las apps** (la del conductor y el panel de administración).

Tiempo estimado: 40 a 60 minutos la primera vez.

---

## 1. Qué necesitas instalar

| Herramienta | Para qué | Dónde conseguirla |
|---|---|---|
| **Git** | Descargar el código | https://git-scm.com |
| **Flutter 3.41 o superior** (incluye Dart 3.11.5+) | Correr las dos apps | https://docs.flutter.dev/get-started/install/windows |
| **Google Chrome** | Correr las apps como web | https://www.google.com/chrome |
| **Visual Studio 2022** con la carga de trabajo "Desarrollo para el escritorio con C++" | Solo si quieres correr las apps como programa de Windows | https://visualstudio.microsoft.com |
| **Android Studio** | Solo si quieres probar en un emulador o celular Android | https://developer.android.com/studio |
| **Supabase CLI** | Aplicar migraciones y desplegar funciones | https://supabase.com/docs/guides/cli |
| **Node.js** (opcional) | Una forma cómoda de instalar la Supabase CLI con `npx` | https://nodejs.org |

Comprueba que Flutter quedó bien instalado:

```bash
flutter doctor
```

Todo lo que necesites debe aparecer con ✓. Para el modo web basta con que Flutter y Chrome estén bien. Lo de Android y Visual Studio solo importa si vas a usar esas plataformas.

---

## 2. Descargar el proyecto

```bash
git clone https://github.com/DiegoAbarza77/TagOK2.0.git
cd TagOK2.0/Producto
```

La estructura importante es esta:

```
Producto/
├── tag_ok/      → app del conductor (Flutter)
├── admin/       → panel de administración (Flutter web)
├── supabase/
│   ├── migrations/   → scripts SQL de la base de datos (0001 a 0010)
│   └── functions/    → Edge Functions (gemini-proxy, create-admin, delete-user)
└── setup.bat    → instalador de dependencias
```

---

## 3. Crear el proyecto de Supabase

1. Entra a https://supabase.com y crea una cuenta (es gratis, sin tarjeta).
2. Pulsa **New project**. Elige un nombre, una contraseña para la base de datos (guárdala) y la región más cercana.
3. Espera a que termine de crearse.
4. Ve a **Project Settings → API** y anota estos dos valores:
   - **Project URL** (tiene la forma `https://xxxx.supabase.co`)
   - **anon / publishable key**

   Usa solo la clave *anon*. La *service_role* nunca debe ir en las apps.

### 3.1 Aplicar las migraciones

Las migraciones crean las tablas, las reglas de seguridad (RLS), los buckets de fotos y cargan los pórticos iniciales. Deben aplicarse **en orden, de la 0001 a la 0010**.

**Opción A, con la CLI (recomendada):**

```bash
supabase login
supabase link --project-ref TU_PROJECT_REF
supabase db push
```

El `project-ref` es la parte `xxxx` de tu URL.

**Opción B, a mano:** en Supabase ve a **SQL Editor**, abre cada archivo de `Producto/supabase/migrations/` en orden, pega su contenido y pulsa **Run**.

> La migración `0006` activa Realtime. Sin ella, varias pantallas que se actualizan solas dan error.

### 3.2 Desplegar las Edge Functions

Desde la carpeta `Producto`:

```bash
supabase functions deploy gemini-proxy
supabase functions deploy create-admin
supabase functions deploy delete-user
```

### 3.3 Configurar la clave de Gemini

1. Crea una clave en https://aistudio.google.com/apikey
2. Guárdala como secreto del servidor, no en ningún archivo del proyecto:

```bash
supabase secrets set GEMINI_API_KEY=tu-clave-de-gemini
```

Sin esta clave, la app funciona, pero **no la lectura de documentos con IA ni la auditoría con IA**.

### 3.4 Crear el primer administrador

El panel de administración necesita al menos un `super_admin`, y ese primero no se puede crear desde la propia app.

1. En Supabase ve a **Authentication → Users → Add user**. Crea un usuario con correo y contraseña, y márcalo como confirmado.
2. Copia su **User UID**.
3. En **SQL Editor** ejecuta, cambiando los valores:

```sql
insert into public.administradores (id, email, rol)
values ('UID-DEL-USUARIO', 'tu@correo.com', 'super_admin');
```

---

## 4. Conseguir el token de Mapbox

1. Crea una cuenta en https://www.mapbox.com
2. En **Tokens** copia tu **Default public token** (empieza con `pk.`).

Se usa para el mapa, el cálculo de rutas y la búsqueda de direcciones.

---

## 5. Configurar las apps

### 5.1 Instalar dependencias

```bash
setup.bat
```

Este script, en la carpeta `Producto`, hace tres cosas:
- Crea los archivos `.env` vacíos si no existen.
- Ejecuta `flutter pub get` en las dos apps.
- Muestra un menú para ejecutarlas.

Si prefieres hacerlo a mano:

```bash
cd tag_ok
flutter pub get
cd ../admin
flutter pub get
```

### 5.2 Completar los archivos `.env`

**`Producto/tag_ok/.env`**

```env
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_ANON_KEY=tu-anon-key
MAPBOX_ACCESS_TOKEN=pk.tu-token-de-mapbox
```

**`Producto/admin/.env`**

```env
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_ANON_KEY=tu-anon-key
```

Notas:
- Los `.env` no se suben a git, están ignorados a propósito.
- No pongas `GEMINI_API_KEY` aquí. Ya está guardada en el servidor.
- Si falta algún valor, la app no arranca.

---

## 6. Ejecutar

### App del conductor

```bash
cd Producto/tag_ok
flutter run -d chrome
```

Otras opciones: `-d windows` para el programa de escritorio, o `flutter run` con un celular Android conectado por USB y la depuración USB activada.

### Panel de administración

```bash
cd Producto/admin
flutter run -d chrome
```

Inicia sesión con el `super_admin` que creaste en el paso 3.4.

> La primera compilación en modo debug puede tardar varios minutos. Es normal.

---

## 7. Comprobar que todo funciona

1. **App del conductor:** crea una cuenta desde "Crear cuenta" e inicia sesión. Debe llevarte al Home con el mapa.
2. **Vehículo:** registra un vehículo y revisa que aparezca en la lista.
3. **Documentos con IA:** sube la foto o el PDF de un permiso de circulación. Debe precargar los datos para que los revises.
4. **Combustible:** registra una carga y revisa que aparezca en el historial.
5. **Ruta:** en el Home, calcula una ruta por una autopista y revisa que aparezcan los pórticos.
6. **Panel admin:** entra con el `super_admin`. Debes ver el dashboard con el usuario que acabas de crear.

---

## 8. Problemas frecuentes

| Síntoma | Causa probable | Solución |
|---|---|---|
| La app se queda en blanco o no arranca | Falta completar el `.env` | Revisa que `SUPABASE_URL` y `SUPABASE_ANON_KEY` tengan valor |
| Error `RealtimeSubscribeException` | No se aplicó la migración `0006` | Aplícala |
| "Forbidden" o error 403 al crear o borrar admins | Tu usuario no es `super_admin` | Repite el paso 3.4 |
| La IA responde error 502 o "Faltan variables de entorno" | Falta el secreto de Gemini | Repite el paso 3.3 y vuelve a desplegar `gemini-proxy` |
| Error 413, 415 o 429 en la IA | Archivo muy grande (máx. 8 MB), tipo no permitido, o más de 10 llamadas por minuto | Usa JPG, PNG, WebP o PDF menor a 8 MB, y espera un minuto |
| El mapa o las rutas fallan | Token de Mapbox ausente o inválido | Revisa `MAPBOX_ACCESS_TOKEN` |
| `flutter doctor` marca problemas en Visual Studio o Android | Falta ese componente | Solo hace falta si usas esa plataforma; en web puedes ignorarlo |
| "El correo ya está registrado" | Ese correo ya existe en Authentication | Usa otro o bórralo desde el panel de Supabase |

---

## 9. Archivos que no debes compartir ni subir a git

- `tag_ok/.env` y `admin/.env`
- La clave `service_role` de Supabase
- La `GEMINI_API_KEY`
- La carpeta `Base de datos/serviceAccountKey.json`, que quedó de la versión anterior con Firebase y ya no se usa
