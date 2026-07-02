# Actualizar Railway SIN esperar merge de cubsyd

## Por qué ves 404 en /download

Railway sigue con el **código viejo** porque:
- El servicio puede estar conectado al repo **cubsyd/Q-Less** (no al tuyo), o
- Está en rama `main` antigua, o
- Falta **Redeploy** manual.

Tu código nuevo **ya está** en:
- `https://github.com/AnderFelipeOrtiz2004/Q-Less` rama `main` (commit `dc3024e0`)

---

## OPCIÓN A — Redeploy manual (más rápido, sin cubsyd)

1. Entra a [Railway](https://railway.com) → proyecto **Q-LESS** → servicio **Mobile-API**.
2. Pestaña **Settings** → **Source**:
   - Repo: `AnderFelipeOrtiz2004/Q-Less` (tu fork)
   - Rama: `main`
   - **Root Directory:** `mobile-api`  ← MUY IMPORTANTE
3. Guardar.
4. Pestaña **Deployments** → **Deploy** / **Redeploy** (botón arriba a la derecha).
5. Espera **Deployment successful** (2–5 min, el APK pesa ~51 MB).

### Comprobar que funcionó

| URL | Debe pasar |
|-----|------------|
| `.../download` | Página verde "Descargar APK" |
| `.../delivery_check.php` | JSON `"status":"success"` |
| `.../releases/Q-LESS.apk` | Descarga el archivo |
| `.../repair_admin.php` | JSON success |

---

## OPCIÓN B — Cuando cubsyd acepte el merge

1. Merge PR en:  
   `https://github.com/cubsyd/Q-Less/compare/main...AnderFelipeOrtiz2004:fix/mobile-api-web-v029`
2. Si Railway apunta a **cubsyd/Q-Less** → redeploy automático al mergear.
3. Mismas URLs de arriba para verificar.

**No necesitas cubsyd para que funcione mañana** si usas Opción A (tu repo + redeploy).

---

## Variables Railway (revisar antes del redeploy)

```
GOOGLE_CLIENT_ID=913624013632-365sp1sm1r5tfk3rokl4tdlo52vkbaf1.apps.googleusercontent.com
FLUTTER_APP_URL=https://mobile-api-production-21d2.up.railway.app/download
ADMIN_EMAIL=admin@qless.app
ADMIN_PASSWORD=Felipe117
APP_BASE_URL=https://mobile-api-production-21d2.up.railway.app/
(+ SMTP Brevo ya configurado)
```

---

## Cuentas para probar mañana

| Rol | Email | Cómo entrar |
|-----|-------|-------------|
| **Admin** | `admin@qless.app` | Contraseña `Felipe117` |
| **Usuario** | `ortizgarciafelipe37@gmail.com` | Google Sign-In |

**Link APK para el informe:**  
https://mobile-api-production-21d2.up.railway.app/download
