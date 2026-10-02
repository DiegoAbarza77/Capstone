# Guía para generar e instalar la APK de TAG OK

Cómo compilar la app para Android, instalarla en un celular y, lo más importante, **actualizarla** cada vez que haya cambios sin perder la sesión ni los datos.

## Cómo funcionan las actualizaciones

Cuando instalas una APK encima de otra, Android la acepta como actualización solo si se cumplen **tres** cosas:

1. Tiene el **mismo identificador de app** (`applicationId`).
2. Está firmada con la **misma llave**.
3. Su **número de versión interno sube** (el número después del `+` en `pubspec.yaml`).

Si falla alguna, Android dice "App no instalada" y hay que desinstalar la anterior, perdiendo la sesión y los datos locales.

---

## Parte 1 · Preparar el computador (una sola vez)

### 1.1 Instalar Android Studio

1. Descárgalo de https://developer.android.com/studio e instálalo con las opciones por defecto.
2. Ábrelo una vez y deja que termine de descargar el **Android SDK**.
3. En **More Actions → SDK Manager → SDK Tools**, comprueba que estén marcados **Android SDK Command-line Tools** y **Android SDK Platform-Tools**.

### 1.2 Conectar Flutter con el SDK

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

## Parte 2 · Elegir el identificador de la app (una sola vez)

Hoy el proyecto usa `com.example.tag_ok`, que es el de la plantilla. **Cámbialo antes de repartir la primera APK**: si lo cambias después, Android lo trata como otra app distinta y no se actualiza encima.

1. Elige un identificador único, en minúsculas y sin espacios, por ejemplo `cl.tagok.app`.
2. Abre `Producto/tag_ok/android/app/build.gradle.kts` y cambia **solo** esta línea:

```kotlin
applicationId = "cl.tagok.app"
```

No cambies la línea `namespace`: debe seguir como está.

---

## Parte 3 · Crear la llave de firma (una sola vez)

La llave es el "sello" que demuestra que todas tus versiones vienen de ti.

> **Guarda una copia del archivo `.jks` y de las contraseñas fuera de tu PC** (un pendrive o una nube privada). Si pierdes la llave, nunca más podrás actualizar esa app: habría que publicarla como una nueva.

### 3.1 Generar el archivo

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

### 3.2 Crear `key.properties`

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

## Parte 4 · Compilar la APK

### 4.1 Revisar el archivo `.env`

La app lee `Producto/tag_ok/.env` y **lo incluye dentro de la APK**. Debe tener `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `MAPBOX_ACCESS_TOKEN` completos, o la app no arrancará.

Tenlo presente: esos valores quedan dentro del archivo, y cualquiera con la APK podría extraerlos. La clave `anon` de Supabase está pensada para ser pública (la protegen las reglas RLS), pero no repartas la APK en lugares abiertos.

### 4.2 Subir el número de versión

En `Producto/tag_ok/pubspec.yaml`, aumenta el número después del `+` en cada versión nueva:

```yaml
version: 2.0.0+2
```

Lo de antes del `+` (`2.0.0`) es el nombre que ve el usuario. Lo de después (`+2`) es el número que Android compara, y **tiene que subir siempre**.

### 4.3 Compilar

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

Si en la salida aparece el aviso `no hay android/key.properties; se firma con la llave de depuración`, falta la Parte 3. **No repartas esa APK.**

### 4.4 Comprobar con qué llave quedó firmada (opcional)

```bash
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -printcert -jarfile build\app\outputs\flutter-apk\app-release.apk
```

Anota la huella **SHA-256**. En todas tus versiones futuras debe ser la misma.

---

## Parte 5 · Instalar en el celular

### Opción A · Copiando el archivo (la más simple)

1. Pasa `app-release.apk` al celular: cable USB, WhatsApp, Drive o correo.
2. Ábrelo desde el celular.
3. La primera vez, Android pedirá permitir **"instalar apps desconocidas"** para la aplicación desde la que lo abres. Actívalo.
4. Pulsa **Instalar**.

### Opción B · Por cable USB

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

## Parte 6 · Cada vez que haya una versión nueva

1. Haz los cambios en el código.
2. Sube el número de versión (`2.0.0+2` → `2.0.0+3`).
3. Compila: `flutter build apk --release`.
4. Pasa la nueva APK al celular e instálala **encima de la anterior**: no desinstales nada. La sesión y los datos se mantienen.

---

## Problemas frecuentes

| Síntoma | Causa probable | Solución |
|---|---|---|
| "App no instalada" al actualizar | La firma, el identificador o el número de versión no coinciden | Revisa que usaste la **misma** llave, el mismo `applicationId` y un `+N` mayor. Si cambiaste algo de eso, desinstala la app anterior |
| "La app no es compatible" o no instala | La APK es de depuración o hay otra versión con otra firma | Desinstala la anterior e instala la de release |
| `flutter doctor` marca el SDK de Android con ✗ | No está instalado o no está enlazado | Repite las partes 1.1 y 1.2 |
| El build falla con un error de `key.properties` | Falta algún valor o la ruta de `storeFile` es incorrecta | Comprueba que `tagok-release.jks` esté en `android/` y que `key.properties` tenga las 4 líneas |
| La app abre y se cierra o se queda en blanco | Falta el `.env` o está incompleto | Revisa `Producto/tag_ok/.env` antes de compilar |
| Perdí el `.jks` o la contraseña | — | No se puede recuperar. Hay que crear una llave nueva y publicar la app como una nueva (desinstalar la anterior en cada celular) |
| El GPS o las notificaciones no responden | Faltan permisos en el celular | En **Ajustes → Apps → TAG OK → Permisos**, concede ubicación y notificaciones |

---

## Archivos que no se deben subir ni compartir

- `Producto/tag_ok/android/key.properties`
- `Producto/tag_ok/android/tagok-release.jks`
- Las contraseñas del keystore
- `Producto/tag_ok/.env`
