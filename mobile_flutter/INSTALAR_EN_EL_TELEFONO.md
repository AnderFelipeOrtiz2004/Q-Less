# Instalar Q-LESS en el teléfono (pasos simples)

## 1. Descargar el APK

1. Abre en el navegador (del teléfono o del PC):  
   **https://github.com/AnderFelipeOrtiz2004/Q-Less/releases**
2. Pulsa la versión más reciente (ej. **v0.1.0-mobile**).
3. En “Assets”, descarga **`Q-LESS.apk`**.

## 2. Instalar en Android

1. Abre el archivo descargado en el teléfono.
2. Si pide permiso: **Ajustes → Permitir instalar esta app**.
3. Pulsa **Instalar**.

## 3. Preparar el PC (servidor)

En el PC donde está XAMPP:

1. Abre **XAMPP** → inicia **Apache** y **MySQL**.
2. En Windows abre CMD y escribe: `ipconfig`
3. Anota la **IPv4** de Wi‑Fi (ejemplo: `192.168.1.50`).
4. El teléfono y el PC deben usar la **misma Wi‑Fi**.

Prueba en el navegador del teléfono:

`http://TU_IP/q-less/health.php`

Si ves texto JSON, el servidor está bien.

## 4. Si la app no conecta (login lento o error)

El APK de GitHub se compiló con la IP de tu red. Si cambiaste de Wi‑Fi o de PC:

1. En el PC, vuelve a generar el APK con tu IP actual (ver `BUILD_APK.md`).
2. O pide una nueva release con la IP correcta.

Mientras tanto, en el PC puedes probar con:

`flutter run` y `.env` con `http://127.0.0.1/q-less/`

## Resumen en 4 líneas

| Paso | Qué haces |
|------|-----------|
| 1 | Descargas APK desde **Releases** en GitHub |
| 2 | Instalas en el Android |
| 3 | XAMPP encendido + misma Wi‑Fi |
| 4 | Abres la app e inicias sesión |
