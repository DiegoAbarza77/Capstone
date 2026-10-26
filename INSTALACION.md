# Guía de instalación — TAG OK 2.0

Esta guía deja el proyecto funcionando en un computador nuevo con Windows. Son tres partes: **herramientas**, **Supabase** (el back end) y **las apps** (la del conductor y el panel de administración). Al final, en la sección 10, está la guía para generar e instalar la APK de Android.

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
git clone https://github.com/DiegoAbarza77/Capstone.git
cd Capstone/Producto
```

La estructura importante es esta:

```
Producto/
├── tag_ok/      → app del conductor (Flutter)
├── admin/       → panel de administración (Flutter web)
├── supabase/
│   ├── migrations/   → scripts SQL de la base de datos (0001 a 0017)
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

Las migraciones crean las tablas, las reglas de seguridad (RLS), los buckets de fotos y cargan los pórticos iniciales. Deben aplicarse **en orden, de la 0001 a la 0017**.

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

---

## 10. Generar e instalar la APK de Android

Cómo compilar la app para Android, instalarla en un celular y, lo más importante, **actualizarla** cada vez que haya cambios sin perder la sesión ni los datos.

### Cómo funcionan las actualizaciones

Cuando instalas una APK encima de otra, Android la acepta como actualización solo si se cumplen **tres** cosas:

1. Tiene el **mismo identificador de app** (`applicationId`).
2. Está firmada con la **misma llave**.
3. Su **número de versión interno sube** (el número después del `+` en `pubspec.yaml`).

Si falla alguna, Android dice "App no instalada" y hay que desinstalar la anterior, perdiendo la sesión y los datos locales.

---

### 10.1 Preparar el computador (una sola vez)

#### 10.1.1 Instalar Android Studio

1. Descárgalo de https://developer.android.com/studio e instálalo con las opciones por defecto.
2. Ábrelo una vez y deja que termine de descargar el **Android SDK**.
3. En **More Actions → SDK Manager → SDK Tools**, comprueba que estén marcados **Android SDK Command-line Tools** y **Android SDK Platform-Tools**.

#### 10.1.2 Conectar Flutter con el SDK

Si Flutter no lo encuentra solo, indícale la ruta (suele ser `C:\Users\TU_USUARIO\AppData\Local\Android\Sdk`):

```bash
flutter config --android-sdk "C:\Users\TU_USUARIO\AppData\Local\Android\Sdk"
```

Acepta las licencias, respondiendo `y` a cada pregunta:

```bash
flutter doctor --android-licenses
```

Comprueba que el apartado de Android aparezca con ✓:

```bash
flutter doctor
```

---

### 10.2 Elegir el identificador de la app (una sola vez)

Hoy el proyecto usa `com.example.tag_ok`, que es el de la plantilla. **Cámbialo antes de repartir la primera APK**: si lo cambias después, Android lo trata como otra app distinta y no se actualiza encima.

1. Elige un identificador único, en minúsculas y sin espacios, por ejemplo `cl.tagok.app`.
2. Abre `Producto/tag_ok/android/app/build.gradle.kts` y cambia **solo** esta línea:

```kotlin
applicationId = "cl.tagok.app"
```

No cambies la línea `namespace`: debe seguir como está.

---

### 10.3 Crear la llave de firma (una sola vez)

La llave es el "sello" que demuestra que todas tus versiones vienen de ti.

> **Guarda una copia del archivo `.jks` y de las contraseñas fuera de tu PC** (un pendrive o una nube privada). Si pierdes la llave, nunca más podrás actualizar esa app: habría que publicarla como una nueva.

#### 10.3.1 Generar el archivo

Abre PowerShell y ejecuta el comando de `keytool`, que viene dentro de Android Studio. Si la ruta de tu instalación es otra, ajústala:

```bash
cd D:\TAG-OK2.1\Producto\tag_ok\android
```
```bash
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v -keystore tagok-release.jks -alias tagok -keyalg RSA -keysize 2048 -validity 10000
```

Te pedirá:
- Una **contraseña del keystore** (elige una y anótala).
- Tus datos (nombre, organización, país: `CL`). Puedes responder lo que quieras.
- La contraseña de la llave: puedes pulsar Enter para usar la misma.

Al terminar quedará el archivo `Producto/tag_ok/android/tagok-release.jks`.

#### 10.3.2 Crear `key.properties`

Copia la plantilla `key.properties.example` y renómbrala a `key.properties` en la misma carpeta (`android/`):

```bash
copy key.properties.example key.properties
```

Ábrelo y completa los valores reales:

```properties
storePassword=LA_CONTRASEÑA_QUE_ELEGISTE
keyPassword=LA_CONTRASEÑA_DE_LA_LLAVE
keyAlias=tagok
storeFile=tagok-release.jks
```

`key.properties` y el `.jks` están ignorados por git, así que **no se subirán a GitHub**. Compruébalo con `git status`: no deben aparecer.

---

### 10.4 Compilar la APK

#### 10.4.1 Revisar el archivo `.env`

La app lee `Producto/tag_ok/.env` y **lo incluye dentro de la APK**. Debe tener `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `MAPBOX_ACCESS_TOKEN` completos, o la app no arrancará.

Tenlo presente: esos valores quedan dentro del archivo, y cualquiera con la APK podría extraerlos. La clave `anon` de Supabase está pensada para ser pública (la protegen las reglas RLS), pero no repartas la APK en lugares abiertos.

#### 10.4.2 Subir el número de versión

En `Producto/tag_ok/pubspec.yaml`, aumenta el número después del `+` en cada versión nueva:

```yaml
version: 2.0.0+2
```

Lo de antes del `+` (`2.0.0`) es el nombre que ve el usuario. Lo de después (`+2`) es el número que Android compara, y **tiene que subir siempre**.

#### 10.4.3 Compilar

```bash
cd D:\TAG-OK2.1\Producto\tag_ok
```
```bash
flutter build apk --release
```

La APK queda en:

```
Producto/tag_ok/build/app/outputs/flutter-apk/app-release.apk
```

Si en la salida aparece el aviso `no hay android/key.properties; se firma con la llave de depuración`, falta el paso 10.3. **No repartas esa APK.**

#### 10.4.4 Comprobar con qué llave quedó firmada (opcional)

```bash
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -printcert -jarfile build\app\outputs\flutter-apk\app-release.apk
```

Anota la huella **SHA-256**. En todas tus versiones futuras debe ser la misma.

---

### 10.5 Instalar en el celular

#### Opción A · Copiando el archivo (la más simple)

1. Pasa `app-release.apk` al celular: cable USB, WhatsApp, Drive o correo.
2. Ábrelo desde el celular.
3. La primera vez, Android pedirá permitir **"instalar apps desconocidas"** para la aplicación desde la que lo abres. Actívalo.
4. Pulsa **Instalar**.

#### Opción B · Por cable USB

1. En el celular: **Ajustes → Acerca del teléfono**, toca 7 veces **Número de compilación**, y luego en **Opciones de desarrollador** activa la **Depuración USB**.
2. Conecta el celular y acepta la huella del PC en la pantalla.
3. Instala con:

```bash
flutter install
```

o directamente:

```bash
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

La opción `-r` reinstala conservando los datos.

---

### 10.6 Cada vez que haya una versión nueva

1. Haz los cambios en el código.
2. Sube el número de versión (`2.0.0+2` → `2.0.0+3`).
3. Compila: `flutter build apk --release`.
4. Pasa la nueva APK al celular e instálala **encima de la anterior**: no desinstales nada. La sesión y los datos se mantienen.

---

### Problemas frecuentes al generar la APK

| Síntoma | Causa probable | Solución |
|---|---|---|
| "App no instalada" al actualizar | La firma, el identificador o el número de versión no coinciden | Revisa que usaste la **misma** llave, el mismo `applicationId` y un `+N` mayor. Si cambiaste algo de eso, desinstala la app anterior |
| "La app no es compatible" o no instala | La APK es de depuración o hay otra versión con otra firma | Desinstala la anterior e instala la de release |
| `flutter doctor` marca el SDK de Android con ✗ | No está instalado o no está enlazado | Repite los pasos 10.1.1 y 10.1.2 |
| El build falla con un error de `key.properties` | Falta algún valor o la ruta de `storeFile` es incorrecta | Comprueba que `tagok-release.jks` esté en `android/` y que `key.properties` tenga las 4 líneas |
| La app abre y se cierra o se queda en blanco | Falta el `.env` o está incompleto | Revisa `Producto/tag_ok/.env` antes de compilar |
| Perdí el `.jks` o la contraseña | — | No se puede recuperar. Hay que crear una llave nueva y publicar la app como una nueva (desinstalar la anterior en cada celular) |
| El GPS o las notificaciones no responden | Faltan permisos en el celular | En **Ajustes → Apps → TAG OK → Permisos**, concede ubicación y notificaciones |

---

### Archivos que no se deben subir ni compartir (APK)

- `Producto/tag_ok/android/key.properties`
- `Producto/tag_ok/android/tagok-release.jks`
- Las contraseñas del keystore
- `Producto/tag_ok/.env`
