# Q-LESS — Solo Railway (producción en línea)

Ignora XAMPP local. Todo lo que sigue es en **Railway** + **Brevo** + **app Flutter/APK** apuntando a la URL pública.

**API:** `https://mobile-api-production-21d2.up.railway.app/`

---

## Paso 1 — Variables en Railway

Railway → proyecto **Q-LESS** → servicio **Mobile-API** → pestaña **Variables** → **Raw Editor** → pegar y ajustar:

```
SMTP_PROVIDER=brevo
SMTP_HOST=smtp-relay.brevo.com
SMTP_PORT=587
SMTP_USER=b07609001@smtp-brevo.com
SMTP_PASS=(tu clave SMTP de Brevo)
SMTP_FROM=ortizgarciafelipe37@gmail.com
SMTP_FROM_NAME=Q-LESS

ADMIN_EMAIL=admin@qless.app
ADMIN_PASSWORD=QlessAdmin2026!
ADMIN_NAME=Administrador Q-LESS

APP_BASE_URL=https://mobile-api-production-21d2.up.railway.app/
FLUTTER_APP_URL=https://mobile-api-production-21d2.up.railway.app/

GOOGLE_CLIENT_ID=(Web Client ID de Google Cloud, cuando tengas Google Sign-In)
GEMINI_API_KEY=(opcional, para chatbot)
```

Opcional (si SMTP fallara): clave API de Brevo (`xkeysib-...`):

```
BREVO_API_KEY=xkeysib-...
```

MySQL: si ya tienes el servicio MySQL vinculado en Railway, **no** hace falta duplicar `MYSQL*`; el `config.php` las lee solas.

Guardar → **Redeploy** del servicio Mobile-API.

---

## Paso 2 — Brevo (remitente)

1. [Brevo](https://app.brevo.com) → **Remitentes** → verificar `ortizgarciafelipe37@gmail.com`.
2. Sin esto los correos se rechazan aunque Railway esté bien.

---

## Paso 3 — Subir código a Railway

Railway despliega desde GitHub. Los cambios de correo/Brevo están en la rama `fix/mobile-api-web-v029` pero **aún no están en producción** hasta hacer push y que Railway redeploye.

En tu PC (PowerShell), desde la carpeta del repo:

```powershell
cd "C:\Users\felip\OneDrive\Documentos\Q-Less"
git add mobile-api/
git commit -m "feat: Brevo SMTP, test_smtp y correos HTML en Railway"
git push origin fix/mobile-api-web-v029
```

Confirma en Railway que el deploy termina en verde.

---

## Paso 4 — Comprobar API en línea

Abre en el navegador (en este orden):

| URL | Qué debe salir |
|-----|----------------|
| `.../health.php` | `"mysql": true`, `"smtp_configured": true` |
| `.../repair_admin.php` | Mensaje de admin reparado / creado |
| `.../test_smtp.php?to=ortizgarciafelipe37@gmail.com` | `"status": "success"` + correo en Gmail |

En Brevo → **Transaccional → Email → Tiempo real**, debe aparecer el envío. Pulsa **¡Funciona!** en el asistente SMTP.

---

## Paso 5 — Probar la app (APK / Flutter)

El `.env` de Flutter ya debe tener:

```
API_BASE_URL=https://mobile-api-production-21d2.up.railway.app/
```

Pruebas en el celular **con datos móviles o Wi‑Fi** (no hace falta misma red que un PC):

| Prueba | Cómo |
|--------|------|
| Login admin | `admin@qless.app` + contraseña de `ADMIN_PASSWORD` |
| Registro Gmail | Código/enlace al correo |
| Olvidé contraseña | Enlace → formulario web en Railway |
| Compra + código | Admin aprueba → correo con código |

Si el APK es viejo, genera uno nuevo:

```powershell
cd "C:\Users\felip\OneDrive\Documentos\Q-Less\mobile_flutter"
flutter pub get
flutter build apk --release
```

APK: `build\app\outputs\flutter-apk\app-release.apk`

---

## Paso 6 — Google Sign-In (cuando toque)

1. Google Cloud Console → OAuth **Web client ID**.
2. Mismo valor en Railway `GOOGLE_CLIENT_ID` y Flutter `GOOGLE_WEB_CLIENT_ID`.
3. Android: SHA-1 del keystore en Google Cloud.

Detalle: `docs/BREVO_GOOGLE_SETUP.md`

---

## Orden resumido

1. Variables Railway + redeploy  
2. Remitente verificado en Brevo  
3. Push rama `fix/mobile-api-web-v029`  
4. `health.php` → `repair_admin.php` → `test_smtp.php`  
5. Probar app contra Railway  
6. APK release → merge a `main` cuando todo pase  

---

## Si algo falla

| Síntoma | Acción |
|---------|--------|
| `health.php` mysql false | Revisar servicio MySQL en Railway y que esté vinculado al API |
| `smtp_configured` false | Faltan `SMTP_USER`, `SMTP_PASS` o `SMTP_FROM` en Variables |
| `test_smtp` error | Remitente no verificado en Brevo o clave SMTP incorrecta |
| Login admin 401 | Abrir `repair_admin.php` y revisar `ADMIN_EMAIL` / `ADMIN_PASSWORD` |
| App no conecta | APK debe usar URL `https://...railway.app/` (no `127.0.0.1`) |
