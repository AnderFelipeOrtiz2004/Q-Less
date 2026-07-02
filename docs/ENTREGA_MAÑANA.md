# Q-LESS — Entrega funcional (checklist mañana)

## Link para descargar la APK (web, no GitHub)

Tras copiar el APK y hacer deploy en Railway:

| Uso | URL |
|-----|-----|
| **Página de descarga** (para el informe / QR) | https://mobile-api-production-21d2.up.railway.app/download |
| **APK directa** | https://mobile-api-production-21d2.up.railway.app/releases/Q-LESS.apk |

### Publicar APK en Railway (una vez)

```bat
cd scripts
publicar_apk.bat
cd ..
git add mobile-api/releases/Q-LESS.apk mobile-api/download.html mobile-api/router.php
git commit -m "chore: pagina y APK para descarga publica"
git push origin fix/mobile-api-web-v029
```

Merge PR → esperar deploy verde → abrir `/download` en el celular.

> Android no instala sola sin tocar: el usuario descarga y pulsa Instalar (orígenes desconocidas si pide).

---

## IMPORTANTE — Google Client ID

En Railway `GOOGLE_CLIENT_ID` debe ser el cliente **WEB**, no el Android:

```
913624013632-365sp1sm1r5tfk3rokl4tdlo52vkbaf1.apps.googleusercontent.com
```

(NO uses el ID que termina en `...neb8pjk` — ese es solo Android.)

En Flutter `.env`: mismo ID en `GOOGLE_WEB_CLIENT_ID`.

---

## Checklist esta noche (orden)

### Railway / API
- [ ] Variables: SMTP, ADMIN_*, APP_BASE_URL, **GOOGLE_CLIENT_ID** (Web)
- [ ] `FLUTTER_APP_URL=https://mobile-api-production-21d2.up.railway.app/download`
- [ ] Deploy verde en Mobile-API
- [ ] https://mobile-api-production-21d2.up.railway.app/health.php → mysql + smtp true
- [ ] https://mobile-api-production-21d2.up.railway.app/repair_admin.php → success
- [ ] https://mobile-api-production-21d2.up.railway.app/download → página verde

### Brevo
- [ ] Remitente `ortizgarciafelipe37@gmail.com` verificado
- [ ] Probar correo: olvidé contraseña o registro

### Google Cloud
- [x] Cliente Web
- [x] Cliente Android + SHA-1

### APK
- [x] `flutter build apk --release` (51.5 MB)
- [ ] `scripts\publicar_apk.bat` + push + deploy
- [ ] Instalar APK en celular y probar

### Pruebas en celular (marcar cada una)
- [ ] Abrir link `/download` → descarga e instala
- [ ] Iniciar sesión con Google (Gmail)
- [ ] Registro Gmail + código correo
- [ ] Olvidé contraseña + enlace correo
- [ ] Login admin `admin@qless.app`
- [ ] Ver catálogo y productos
- [ ] Carrito y solicitar compra
- [ ] Admin aprueba → código por correo
- [ ] Chatbot responde
- [ ] Crear/editar producto (admin)

---

## Si algo falla

| Problema | Solución |
|----------|----------|
| Google error :10 | SHA-1 en cliente Android + APK nuevo |
| Google token no autorizado | GOOGLE_CLIENT_ID = Web, no Android |
| repair_admin 500 | Push código nuevo `repair_admin.php` + redeploy |
| /download 404 | Push `download.html` + `router.php` + redeploy |
| APK 404 | Ejecutar `publicar_apk.bat` y volver a push |
| Sin correo | Brevo remitente + variables SMTP |

---

## Para el informe / presentación

Entregar estos enlaces:

1. **Descarga app:** https://mobile-api-production-21d2.up.railway.app/download  
2. **API health:** https://mobile-api-production-21d2.up.railway.app/health.php  
3. **Admin:** `admin@qless.app` (contraseña en Railway ADMIN_PASSWORD)
