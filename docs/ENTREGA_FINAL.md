# Q-LESS — ENTREGA FUNCIONAL (lista final)

## Enlaces públicos

| Qué | URL |
|-----|-----|
| **Descargar APK** | https://mobile-api-production-21d2.up.railway.app/download |
| **APK directa** | https://mobile-api-production-21d2.up.railway.app/releases/Q-LESS.apk |
| **Estado sistema** | https://mobile-api-production-21d2.up.railway.app/delivery_check.php |
| **Health API** | https://mobile-api-production-21d2.up.railway.app/health.php |

---

## Cuentas de prueba

### Administrador (gestión)
| Campo | Valor |
|-------|--------|
| Email | `admin@qless.app` |
| Contraseña | `Felipe117` (la de `ADMIN_PASSWORD` en Railway) |
| Puede | Login normal, ver usuarios, productos, **aprobar compras**, crear/editar productos |

### Usuario / comprador
| Campo | Valor |
|-------|--------|
| Email | `ortizgarciafelipe37@gmail.com` |
| Entrada | **Iniciar sesión con Google** o registro Gmail |
| Puede | Ver catálogo, carrito, **solicitar compra**, ver mis compras con código |

---

## Flujo de compra (probar mañana)

1. Usuario Gmail entra con Google → catálogo.
2. Añade producto al carrito → solicitar compra.
3. Admin `admin@qless.app` entra → Compras de usuarios → **Aprobar**.
4. Usuario recibe **correo con código** (Brevo).
5. Usuario ve código en **Mis compras**.

---

## Funcionalidades incluidas

- [x] Login / registro Gmail con verificación por correo
- [x] **Google Sign-In** (Web + Android OAuth)
- [x] Recuperar contraseña con enlace HTML (Brevo SMTP)
- [x] Catálogo, carrito, reservas de stock
- [x] Solicitud y **aprobación de compras** (admin)
- [x] **Código de compra por correo** HTML
- [x] Panel admin: productos, usuarios, compras
- [x] Chatbot (GEMINI_API_KEY en Railway)
- [x] Ruleta post-compra
- [x] API en Railway + MySQL
- [x] **Página web descarga APK** (`/download`)
- [x] Páginas web reset/verify contraseña

---

## Railway — variables obligatorias

```
ADMIN_EMAIL=admin@qless.app
ADMIN_PASSWORD=Felipe117
ADMIN_NAME=Felipe Ortiz
APP_BASE_URL=https://mobile-api-production-21d2.up.railway.app/
FLUTTER_APP_URL=https://mobile-api-production-21d2.up.railway.app/download
GOOGLE_CLIENT_ID=913624013632-365sp1sm1r5tfk3rokl4tdlo52vkbaf1.apps.googleusercontent.com
SMTP_PROVIDER=brevo
SMTP_HOST=smtp-relay.brevo.com
SMTP_PORT=587
SMTP_USER=(tu login smtp-brevo.com)
SMTP_PASS=(clave SMTP Brevo)
SMTP_FROM=ortizgarciafelipe37@gmail.com
SMTP_FROM_NAME=Q-LESS
GEMINI_API_KEY=(opcional chatbot)
```

**GOOGLE_CLIENT_ID = cliente WEB**, no el Android.

---

## Merge GitHub

PR sugerido (fork → upstream):

https://github.com/cubsyd/Q-Less/compare/main...AnderFelipeOrtiz2004:fix/mobile-api-web-v029

O en tu repo:

https://github.com/AnderFelipeOrtiz2004/Q-Less/compare/main...fix/mobile-api-web-v029

Tras merge → Railway redeploy automático → probar `/delivery_check.php`.

---

## Si algo falla mañana

| Error | Solución rápida |
|-------|-----------------|
| Google :10 | SHA-1 en cliente Android + APK del link `/download` |
| Sin correo | Brevo → remitente verificado |
| repair_admin 500 | Abrir `delivery_check.php` tras deploy nuevo |
| APK 404 | Merge con `mobile-api/releases/Q-LESS.apk` |
| Admin no entra | `repair_admin.php` + contraseña Railway |
