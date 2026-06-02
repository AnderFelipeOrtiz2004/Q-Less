# Q-LESS — APK, actualizar desde PC y subir a GitHub

## Requisitos en el PC

1. **Flutter SDK** instalado (`flutter doctor` sin errores en Android).
2. **Android Studio** (SDK + licencias aceptadas).
3. **XAMPP** con Apache y MySQL en ejecución.
4. Backend en `C:\xampp\htdocs\q-less\` accesible en el navegador.

---

## 1. Configurar `.env` (muy importante en el móvil)

En la carpeta del proyecto Flutter:

```powershell
cd "C:\Users\felip\OneDrive\Desktop\project\flutter"
copy .env.example .env
notepad .env
```

| Dónde pruebas | `API_BASE_URL` |
|---------------|----------------|
| PC / emulador | `http://127.0.0.1/q-less/` |
| Teléfono real | `http://TU_IP_LAN/q-less/` (ej. `http://192.168.1.50/q-less/`) |

**Obtener tu IP en Windows:**

```powershell
ipconfig
```

Busca **IPv4** de Wi‑Fi (ej. `192.168.1.50`).

El teléfono y el PC deben estar en la **misma red Wi‑Fi**. En el móvil abre el navegador: `http://TU_IP/q-less/health.php` — debe responder JSON.

> El archivo `.env` **no se sube a GitHub** (está en `.gitignore`). Cada vez que generes un APK para el teléfono, edita `.env` con la IP correcta **antes** de `flutter build apk`.

---

## 2. Generar el APK

```powershell
cd "C:\Users\felip\OneDrive\Desktop\project\flutter"
flutter pub get
flutter build apk --release
```

APK generado:

`build\app\outputs\flutter-apk\app-release.apk`

### Instalar en el teléfono

- Copia el APK por USB, Google Drive o correo.
- En Android: **Ajustes → Seguridad → Instalar apps desconocidas** (permite el origen que uses).
- Abre el APK e instala.

---

## 3. Actualizar la app desde el PC (flujo habitual)

1. Edita el código en el PC (Cursor / VS Code).
2. Prueba en PC: `flutter run` (con `.env` en `127.0.0.1`).
3. Para el teléfono: cambia `.env` a la **IP LAN** del PC.
4. Vuelve a compilar:

   ```powershell
   flutter build apk --release
   ```

5. Instala el nuevo APK en el teléfono (sobrescribe la versión anterior).

No hace falta desinstalar si el `applicationId` es el mismo; solo reinstala encima.

---

## 4. Subir cambios a GitHub (paso a paso)

Proyecto en GitHub: carpeta **`mobile_flutter`** dentro del repo Q-Less.

### Primera vez (si ya clonaste)

```powershell
cd "C:\Users\felip\OneDrive\Documentos\Q-Less"
git status
git branch
```

### Sincronizar código de escritorio → repo

Copia `lib`, `android`, `pubspec.yaml`, `.env.example` y esta guía al repo:

```powershell
$src = "C:\Users\felip\OneDrive\Desktop\project\flutter"
$dst = "C:\Users\felip\OneDrive\Documentos\Q-Less\mobile_flutter"

robocopy "$src\lib" "$dst\lib" /E /XD .dart_tool
robocopy "$src\android\app\src\main" "$dst\android\app\src\main" /E
copy "$src\pubspec.yaml" "$dst\pubspec.yaml"
copy "$src\.env.example" "$dst\.env.example"
copy "$src\BUILD_APK.md" "$dst\BUILD_APK.md"
```

### Commit y push

```powershell
cd "C:\Users\felip\OneDrive\Documentos\Q-Less"
git add mobile_flutter/
git status
git commit -m "Mobile: APK listo, URL desde .env y red HTTP para XAMPP"
git push origin feature/mobile-fix-endpoints
```

(Sustituye la rama si usas otra.)

### En GitHub

1. Entra a https://github.com/AnderFelipeOrtiz2004/Q-Less  
2. Verás la rama `feature/mobile-fix-endpoints` (o la que hayas pusheado).  
3. Opcional: **Pull request** → Merge a `main`.

**Nunca subas** `.env` con claves reales; solo `.env.example`.

---

## 5. Firewall de Windows (si el móvil no conecta)

1. Panel de control → Firewall de Windows → Permitir una aplicación.  
2. Marca **Apache HTTP Server** en redes **Privada**.  
3. O crea regla entrante TCP puerto **80**.

---

## 6. Problemas frecuentes

| Síntoma | Solución |
|---------|----------|
| Login timeout en el móvil | `.env` con IP LAN, no `127.0.0.1` |
| Imágenes no cargan | Misma `API_BASE_URL`; revisa `q-less/storage/products/` |
| Chatbot no responde | `GEMINI_API_KEY` en `.env` o `chatbot.php` en el servidor |
| APK no instala | Activa “orígenes desconocidos” |
| `flutter build` falla | `flutter doctor`, acepta licencias Android |

---

## Resumen rápido

```text
PC: editar código → .env con IP LAN → flutter build apk --release
Teléfono: instalar app-release.apk → misma Wi‑Fi que XAMPP
GitHub: robocopy a mobile_flutter → git add → commit → push
```
