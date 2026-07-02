# Configurar Brevo y Google Sign-In para Q-LESS

## 1. Brevo (correos: verificación, contraseña, código de compra)

### Crear cuenta
1. Ir a [https://www.brevo.com](https://www.brevo.com) y registrarse (plan gratuito: ~300 correos/día).
2. Verificar tu dominio o usar el remitente que Brevo permita en plan free.

### Obtener SMTP
1. Panel Brevo → **SMTP & API** → pestaña **SMTP**.
2. Crear clave SMTP (`xsmtpsib-...`).
3. Anotar:
   - Servidor: `smtp-relay.brevo.com`
   - Puerto: `587`
   - Login: tu email de cuenta Brevo
   - Contraseña: la clave SMTP generada

### Verificar remitente (obligatorio)
1. Panel Brevo → **Remitentes, dominios y IPs dedicadas** → **Remitentes**.
2. Añadir `ortizgarciafelipe37@gmail.com` (o el que uses en `SMTP_FROM`).
3. Abrir el correo de confirmación de Brevo y pulsar el enlace hasta que el estado sea **Verificado**.

Sin esto, Brevo rechazará el envío aunque SMTP esté bien configurado.

### Paso «Verificación» (pantalla «A la espera de registros»)
Esa pantalla solo avanza cuando **llega al menos un correo enviado por SMTP** (no por la API HTTP).

1. Deja la pestaña abierta (se actualiza sola).
2. Desde tu app o un script de prueba, envía **un correo real** usando:
   - Servidor: `smtp-relay.brevo.com`
   - Puerto: `587` (STARTTLS)
   - Usuario: el login SMTP de Brevo (ej. `xxxx@smtp-brevo.com`)
   - Contraseña: la clave SMTP
   - Remitente (`From`): el email **verificado** arriba
3. Cuando Brevo detecte el envío, verás una línea en la lista y el botón **¡Funciona!** se activará.

**Prueba local en XAMPP (Windows):** PHP de XAMPP suele fallar en `STARTTLS` con Brevo. No es un error de tus credenciales. Opciones:
- **Recomendado:** pegar las variables en **Railway**, redeploy, y abrir  
  `https://mobile-api-production-21d2.up.railway.app/test_smtp.php?to=TU_CORREO`
- O probar desde la app en Railway: registro / «Olvidé contraseña».

**Prueba rápida en tu PC (fuera de PHP):** si tienes Python instalado, en PowerShell (sustituye usuario/clave/remitente):

```powershell
python -c "import smtplib, ssl; h='smtp-relay.brevo.com'; u='TU_LOGIN_SMTP'; p='TU_CLAVE_SMTP'; f='ortizgarciafelipe37@gmail.com'; t=f; c=ssl.create_default_context();
with smtplib.SMTP(h,587,timeout=30) as s: s.ehlo(); s.starttls(context=c); s.ehlo(); s.login(u,p); s.sendmail(f,[t],'Subject: Test Brevo\r\n\r\nHola.\r\n'); print('OK')"
```

### Variables en Railway (servicio Mobile-API)
```
SMTP_PROVIDER=brevo
SMTP_HOST=smtp-relay.brevo.com
SMTP_PORT=587
SMTP_USER=tu_email@ejemplo.com
SMTP_PASS=xsmtpsib-tu_clave
SMTP_FROM=noreply@tudominio.com
SMTP_FROM_NAME=Q-LESS
```

### Probar
1. Redeploy Railway.
2. `https://TU-API/health.php` → `"smtp_configured": true`
3. Registrar usuario nuevo o usar "Olvidé contraseña".
4. Revisar bandeja (y spam).

### Enlaces en correos
Los correos incluyen:
- **Verificar correo:** botón → `verify_email_page.php?email=...&code=...`
- **Cambiar contraseña:** botón → `reset_password_page.php?email=...&code=...`

Opcional: `FLUTTER_APP_URL` = URL de tu app para botón "Abrir aplicación".

---

## 2. Gmail SMTP (alternativa a Brevo)

1. Cuenta Google → verificación en 2 pasos activada.
2. [Contraseñas de aplicación](https://myaccount.google.com/apppasswords) → crear para "Correo".
3. Railway:
```
SMTP_PROVIDER=gmail
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=tu_correo@gmail.com
SMTP_PASS=16caracteressin espacios
SMTP_FROM=tu_correo@gmail.com
```

---

## 3. Google Sign-In (login con cuenta Gmail real)

### Google Cloud Console
1. [https://console.cloud.google.com](https://console.cloud.google.com)
2. Crear proyecto → **APIs y servicios** → **Credenciales**.
3. **OAuth consent screen** → External → completar datos.
4. **Crear credenciales** → **ID de cliente OAuth**:
   - Tipo: **Aplicación web** → copiar **Client ID** (termina en `.apps.googleusercontent.com`)

### Android (APK)
1. Obtener SHA-1:
   ```bat
   cd mobile_flutter\android
   gradlew signingReport
   ```
2. Crear credencial **Android** con:
   - Package: `com.qless.q_less_prototype` (ver `android/app/build.gradle.kts`)
   - SHA-1 debug y release (`gradlew signingReport`)
3. El **Web Client ID** es el que va en la app (`GOOGLE_WEB_CLIENT_ID`).

### Variables
| Dónde | Variable | Valor |
|-------|----------|-------|
| Railway API | `GOOGLE_CLIENT_ID` | Web Client ID |
| Flutter `.env` | `GOOGLE_WEB_CLIENT_ID` | Mismo Web Client ID |

### Probar
- En app: botón **Iniciar sesión con Google**
- Si error `:10` → falta SHA-1 o Client ID incorrecto

---

## 4. Admin de producción (sin correo personal)

Usar en Railway:
```
ADMIN_EMAIL=admin@qless.app
ADMIN_PASSWORD=TuPasswordSeguro123!
ADMIN_NAME=Administrador Q-LESS
```

Luego abrir: `https://TU-API/repair_admin.php`

Login en app con ese correo y contraseña.

Los usuarios reales se registran con **su Gmail**; el admin es solo para gestión.
