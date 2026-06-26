# Revisión pre-merge — Q-LESS v0.2.9 / v2.9.1

**Rama:** `fix/mobile-api-web-v029`  
**Fecha:** 2025-06-01  
**API producción:** https://mobile-api-production-21d2.up.railway.app/

---

## Resumen ejecutivo

| Área | Estado | Notas |
|------|--------|-------|
| Mobile API (PHP/Railway) | ✅ Listo tras fixes | Fixes P0 aplicados en esta revisión |
| Flutter v2.9.1+31 | ✅ Listo | APK compilada; falta `GOOGLE_WEB_CLIENT_ID` en `.env` local |
| Laravel / Angular web | ⚠️ Parcial | Bug stock corregido; sync BD aún dual |
| Railway deploy | ✅ API responde | Verificar variables SMTP y ADMIN_* en panel |
| Merge a `cubsyd/Q-Less` main | ✅ Recomendado | Mobile + API; web sync es trabajo futuro |

---

## Fixes aplicados en esta revisión

1. **`ensure_default_admin()`** — Ya no resetea la contraseña del admin en cada request; solo actualiza nombre y rol si el usuario existe.
2. **`PaymentController.php`** — Eliminado doble descuento de stock al crear pedido (el stock ya se descuenta en `CartReservationService`).
3. **`orders.php` reject** — Envuelto en transacción con `FOR UPDATE` para evitar condiciones de carrera.
4. **`image.php` + `router.php`** — Soporte para rutas `storage/productos/` además de `storage/products/`.
5. **`.env.example`** — Placeholders en lugar de credenciales reales; documentado `GOOGLE_CLIENT_ID` y `RAILWAY_PUBLIC_DOMAIN`.
6. **`build_release_apk.bat`** — Actualizado a v2.9.1.

---

## Checklist Railway (antes/después del merge)

En **Railway → Mobile-API → Variables**, confirmar:

| Variable | Requerida |
|----------|-----------|
| `MYSQLHOST`, `MYSQLPORT`, `MYSQLUSER`, `MYSQLPASSWORD`, `MYSQLDATABASE` | Sí (vinculadas al servicio MySQL) |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD`, `ADMIN_NAME` | Sí |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM` | Sí (registro y códigos de compra) |
| `GEMINI_API_KEY` | Opcional (chatbot) |
| `GOOGLE_CLIENT_ID` | Opcional (validación servidor Google) |
| `RAILWAY_PUBLIC_DOMAIN` | Auto (Railway) |

Tras merge: **Redeploy** del servicio PHP en Railway.

---

## Checklist Flutter / APK

- [x] Versión `2.9.1+31` en `pubspec.yaml`
- [x] Grid 2 columnas, sonidos, perfil reorganizado
- [x] PUT parcial productos, términos únicos, timestamps
- [ ] Configurar `GOOGLE_WEB_CLIENT_ID` en `mobile_flutter/.env` (no commitear)
- [ ] Registrar SHA-1 de debug/release en Google Cloud Console
- [x] APK: `mobile_flutter/build/app/outputs/flutter-apk/app-release.apk`

---

## Riesgos conocidos (no bloquean merge mobile)

### P1 — Autenticación API móvil
El rol admin se envía en el body JSON (`role: admin`). No hay JWT/sesión servidor. Aceptable para MVP interno; endurecer en versión futura.

### P1 — Sync web ↔ mobile (BD compartida)
- Laravel usa `orders` + `cart_reservations` (TTL 5 min, Mercado Pago).
- Mobile API usa `ordenes` + `reservations` (TTL 24 h, aprobación admin).
- Columnas users: `rol` vs `role`, `email_verified_at` vs `email_verified`.
- **No usar la misma BD en producción para ambos flujos** hasta unificar esquema.

### P2 — Storage ephemeral en Railway
Imágenes y flags en `storage/` se pierden al redeploy. Considerar volumen persistente o almacenamiento externo (S3, etc.).

### P2 — `.env` en assets Flutter
El `.env` se empaqueta en el APK. Solo poner valores no secretos (`API_BASE_URL`, `GOOGLE_WEB_CLIENT_ID` es público).

---

## Archivos que NO deben ir al merge

- `Q-LESS-v0.2.9.apk`, `Q-LESS-v0.2.9.1.apk` (distribuir por Releases, no en repo)
- `_mobile-api-backup/`
- `mobile-api/users_users_utf8.php` (script temporal)
- `mobile_flutter/web/` (generado)

---

## Crear el PR

Sin `gh` CLI instalado, abrir manualmente:

https://github.com/cubsyd/Q-Less/compare/main...AnderFelipeOrtiz2004:fix/mobile-api-web-v029?expand=1

**Título sugerido:** `fix: mobile API v0.2.9 + Flutter v2.9.1 (grid, sounds, purchases, timestamps)`

**Descripción sugerida:**
- Fix Google Sign-In, términos duplicados, edición parcial productos, timestamps
- UI: grid 2 columnas, sonidos, perfil y chatbot
- API: admin password no se resetea, reject con transacción, rutas `storage/productos/`
- Laravel: fix doble descuento stock en checkout web

---

## Commits en la rama

```
94088135 fix: sound_button switch fallthrough (APK build)
ee9b84a4 feat: UI grid 2 cols, sounds, profile/chatbot v2.9.1
0afe2b23 fix: Google login, terms, product edit, timestamps v0.2.9
```

(+ commit pendiente con fixes pre-merge de esta revisión)
