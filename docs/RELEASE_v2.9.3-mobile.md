# Q-LESS v2.9.3-mobile

## Novedades
- API Railway en producción (MySQL + Brevo SMTP)
- Google Sign-In (OAuth Web + Android)
- Descarga APK desde https://mobile-api-production-21d2.up.railway.app/download
- Correos HTML: registro, recuperar contraseña, código de compra
- Admin: admin@qless.app
- Fallback producción en APK (funciona sin depender solo de .env)

## Instalar
1. Descargar **Q-LESS-v2.9.3-mobile.apk**
2. Abrir en Android → Instalar (permitir orígenes desconocidos si pide)
3. Usar **Iniciar sesión con Google** o registro Gmail

## Tras merge en cubsyd
1. Railway Mobile-API → Redeploy
2. Verificar: `/download` y `/delivery_check.php`
