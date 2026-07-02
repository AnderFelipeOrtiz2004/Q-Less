# Google Sign-In — paso a paso (Q-LESS en Railway)

Proyecto Google Cloud: **Q-lees**  
Package Android: `com.qless.q_less_prototype`  
API: `https://mobile-api-production-21d2.up.railway.app/`

---

## Parte A — Google Cloud Console

### 1. Pantalla de consentimiento OAuth
1. [Google Cloud Console](https://console.cloud.google.com) → proyecto **Q-lees**.
2. **APIs y servicios** → **Pantalla de consentimiento de OAuth**.
3. Tipo: **Externo** → Crear.
4. Completa: nombre de la app **Q-LESS**, correo de soporte (tu Gmail).
5. Ámbitos: añade `email`, `profile`, `openid` (o los básicos de Google Sign-In).
6. Usuarios de prueba: añade tu Gmail (`ortizgarciafelipe37@gmail.com`) mientras la app esté en modo prueba.
7. Guardar.

### 2. Credencial WEB (obligatoria)
1. **APIs y servicios** → **Credenciales** → **+ Crear credenciales** → **ID de cliente de OAuth**.
2. Tipo: **Aplicación web**.
3. Nombre: `Q-LESS Web`.
4. Orígenes autorizados (opcional para APK):  
   `https://mobile-api-production-21d2.up.railway.app`
5. Crear → **copia el Client ID** (termina en `.apps.googleusercontent.com`).

Este mismo ID va en **Railway** y en **Flutter**.

### 3. Credencial ANDROID (obligatoria para APK)
1. Obtén el SHA-1 de tu keystore debug (en PowerShell):

```powershell
cd "C:\Users\felip\OneDrive\Documentos\Q-Less\mobile_flutter\android"
.\gradlew signingReport
```

Busca la variante **debug** → copia el **SHA-1** (ej. `AA:BB:CC:...`).

2. **Credenciales** → **+ Crear credenciales** → **ID de cliente de OAuth**.
3. Tipo: **Android**.
4. Nombre: `Q-LESS Android`.
5. Nombre del paquete: `com.qless.q_less_prototype`
6. Huella digital SHA-1: pega el SHA-1 del paso anterior.
7. Crear.

> Para APK de **release** en Play Store, repite con el SHA-1 del keystore de release.

---

## Parte B — Railway (Mobile-API)

En **Variables**, añade:

```
GOOGLE_CLIENT_ID=123456789-xxxx.apps.googleusercontent.com
```

(El **Web Client ID** del paso 2, no el de Android.)

Guardar → **Redeploy**.

Comprueba: `https://mobile-api-production-21d2.up.railway.app/health.php`  
Debe incluir `"google_configured": true` (tras el próximo deploy con el código actualizado).

---

## Parte C — Flutter / APK

Edita `mobile_flutter/.env`:

```
API_BASE_URL=https://mobile-api-production-21d2.up.railway.app/
GOOGLE_WEB_CLIENT_ID=123456789-xxxx.apps.googleusercontent.com
```

(Mismo Web Client ID que en Railway.)

Genera APK nuevo:

```powershell
cd "C:\Users\felip\OneDrive\Documentos\Q-Less\mobile_flutter"
flutter pub get
flutter build apk --release
```

Instala el APK nuevo en el celular. **Sin APK nuevo, Google no funcionará** aunque Railway esté bien.

---

## Parte D — Probar

1. Abre la app → **Iniciar sesión con Google**.
2. Acepta términos → elige tu cuenta Gmail.
3. Debe entrar al catálogo.

| Error | Solución |
|-------|----------|
| `:10` o `sign_in_failed` | Falta credencial Android o SHA-1 incorrecto |
| `GOOGLE_WEB_CLIENT_ID` | Falta en `.env` o APK viejo |
| `google_not_configured` | Falta `GOOGLE_CLIENT_ID` en Railway |
| `Token no autorizado` | Web Client ID distinto en Railway vs Flutter |

---

## Resumen de variables

| Dónde | Variable | Valor |
|-------|----------|-------|
| Railway | `GOOGLE_CLIENT_ID` | Web Client ID |
| Flutter `.env` | `GOOGLE_WEB_CLIENT_ID` | Mismo Web Client ID |
| Google Cloud | Credencial Android | Package + SHA-1 |

No uses el Client ID de Android en Railway/Flutter; usa siempre el **Web**.
