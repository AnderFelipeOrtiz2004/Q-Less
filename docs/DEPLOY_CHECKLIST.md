# Q-LESS — Lista de entrega (2 días antes del despliegue público)

## HECHO EN CÓDIGO (esta rama)

- [x] Admin por defecto: `admin@qless.app` (sin correo personal real)
- [x] SMTP Brevo + Gmail en `mail_helpers.php`
- [x] Correos HTML con botón/enlace para verificar y cambiar contraseña
- [x] Páginas web: `reset_password_page.php`, `verify_email_page.php`
- [x] Google login valida `GOOGLE_CLIENT_ID` en servidor
- [x] Código de compra por correo HTML
- [x] Flutter: recuperar contraseña mejorado (validación Gmail, confirmar, reenviar)

---

## TÚ DEBES HACER EN RAILWAY (obligatorio)

### 1. Mobile-API — Variables
| Variable | Valor ejemplo |
|----------|----------------|
| `ADMIN_EMAIL` | `admin@qless.app` |
| `ADMIN_PASSWORD` | (tu contraseña segura) |
| `ADMIN_NAME` | Administrador Q-LESS |
| `SMTP_PROVIDER` | `brevo` |
| `SMTP_HOST` | `smtp-relay.brevo.com` |
| `SMTP_PORT` | `587` |
| `SMTP_USER` | login Brevo |
| `SMTP_PASS` | clave SMTP Brevo |
| `SMTP_FROM` | remitente verificado en Brevo |
| `SMTP_FROM_NAME` | Q-LESS |
| `GOOGLE_CLIENT_ID` | Web Client ID de Google Cloud |
| `APP_BASE_URL` | `https://mobile-api-production-21d2.up.railway.app/` |
| `FLUTTER_APP_URL` | URL donde publicas la app (web/APK) |

### 2. Después del deploy
1. Abrir: `https://TU-API/repair_admin.php`
2. Verificar: `https://TU-API/health.php` → `mysql: true`, `smtp_configured: true`
3. Probar login admin: `admin@qless.app` + `ADMIN_PASSWORD`

### 3. Brevo (correos)
Ver guía: `docs/BREVO_GOOGLE_SETUP.md`

### 4. Google Sign-In
Ver guía: `docs/BREVO_GOOGLE_SETUP.md`
- Crear OAuth Web Client ID
- Poner en Railway `GOOGLE_CLIENT_ID`
- Poner en Flutter `.env` → `GOOGLE_WEB_CLIENT_ID` (mismo valor)
- Android: SHA-1 debug/release en Google Cloud + package name

### 5. Flutter APK release
```bat
cd mobile_flutter
flutter pub get
flutter build apk --release
```
- `.env` con `API_BASE_URL=https://mobile-api-production-21d2.up.railway.app/`
- Subir APK a GitHub Releases o hosting

---

## PRUEBAS ANTES DE MERGE A MAIN

| # | Prueba | OK |
|---|--------|-----|
| 1 | Login admin `admin@qless.app` | ☐ |
| 2 | Registro Gmail + código + enlace verificar | ☐ |
| 3 | Olvidé contraseña + enlace en correo + formulario web | ☐ |
| 4 | Google Sign-In (Android) | ☐ |
| 5 | Catálogo, carrito, solicitar compra | ☐ |
| 6 | Admin aprueba → código por correo | ☐ |
| 7 | Mis compras muestra código | ☐ |
| 8 | Chatbot responde (GEMINI_API_KEY) | ☐ |
| 9 | Ruleta post-compra | ☐ |
| 10 | Crear/editar producto (admin) | ☐ |

---

## MERGE A MAIN (cuando todo esté ☐ marcado)

```bash
git checkout fix/mobile-api-web-v029
git pull origin fix/mobile-api-web-v029
# Crear PR en GitHub: fix/mobile-api-web-v029 → main
# Repo: https://github.com/cubsyd/Q-Less
```

URL PR sugerida:
`https://github.com/cubsyd/Q-Less/compare/main...AnderFelipeOrtiz2004:fix/mobile-api-web-v029`

Después del merge:
1. Railway redeploy automático (o manual)
2. Tag release `v2.9.3` en GitHub
3. Publicar APK

---

## NO HACER

- No commitear `.env` con contraseñas reales
- No usar correo Gmail personal como `ADMIN_EMAIL` en producción
- No mergear sin probar SMTP y login admin
