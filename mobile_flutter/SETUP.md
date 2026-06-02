# Guía de Configuración Completa - Q-LESS

## 📋 Requisitos Previos

- ✅ Flutter SDK 3.0+ ([descargar](https://flutter.dev/docs/get-started/install))
- ✅ XAMPP con PHP 7.4+ y MySQL ([descargar](https://www.apachefriends.org/))
- ✅ Git (opcional)
- ✅ Android emulator / iOS simulator O dispositivo físico
- ✅ Editor: VS Code / Android Studio

## 🚀 Pasos de Configuración

### Paso 1: Preparar XAMPP y Base de Datos

1. **Inicia XAMPP**
   - Windows: Ejecuta `C:\xampp\xampp-control-panel.exe`
   - Inicia "Apache" y "MySQL"

2. **Accede a phpMyAdmin**
   - Abre: `http://localhost/phpmyadmin`
   - Deberías ver el panel de administración

3. **Crear la Base de Datos**
   - Haz clic en "SQL" en el menú superior
   - Copia TODO el contenido de `backend/database.sql`
   - Pega en el editor SQL de phpMyAdmin
   - Haz clic en "Continuar" o presiona Ctrl+Enter

   **Alternativa por terminal:**
   ```bash
   mysql -u root < backend\database.sql
   ```

4. **Verificar creación**
   - En el panel izquierdo deberías ver "q_less_db"
   - Dentro verás las tablas: "usuarios", "colas", "items"

### Paso 2: Configurar Archivos PHP

1. **Copiar archivos al servidor**
   
   Windows:
   ```bash
   Copia la carpeta "backend" a:
   C:\xampp\htdocs\q-less\backend\
   
   Estructura final:
   C:\xampp\htdocs\
   ├── q-less/
   │   └── backend/
   │       ├── config.php
   │       ├── register.php
   │       ├── database.sql
   │       └── README.md
   ```

2. **Verificar credenciales en config.php**
   
   Abre `backend/config.php` y verifica:
   ```php
   define('DB_HOST', 'localhost');
   define('DB_USER', 'root');        // Usuario por defecto XAMPP
   define('DB_PASS', '');            // XAMPP por defecto es vacío
   define('DB_NAME', 'q_less_db');   // Nombre de BD creada
   ```

3. **Probar conexión**
   
   Abre en navegador:
   ```
   http://localhost/q-less/register.php
   ```
   
   Deberías ver un error JSON (esperado, solo acepta POST):
   ```json
   {"status":"error","message":"Método no permitido"}
   ```
   
   ✅ Si ves esto, la configuración PHP funciona

### Paso 3: Obtener tu IP Local (IMPORTANTE)

1. **En Windows:**
   ```bash
   # Abre CMD y ejecuta:
   ipconfig
   
   # Busca "IPv4 Address" debajo de "Ethernet adapter" o "Wireless adapter"
   # Ejemplo: 192.168.1.100
   ```

2. **En Mac/Linux:**
   ```bash
   ifconfig | grep inet
   ```

### Paso 4: Configurar Flutter

1. **Abre el proyecto**
   ```bash
   cd c:\Users\felip\OneDrive\Desktop\project\flutter
   ```

2. **Actualiza la IP en el código**
   
   Abre: `lib/services/auth_service.dart`
   
   Encuentra esta línea:
   ```dart
   static const String baseUrl = 'http://YOUR_IP:80/q-less';
   ```
   
   Reemplaza `YOUR_IP` con tu IP. Ejemplos:
   ```dart
   // Para localhost (mismo PC):
   static const String baseUrl = 'http://localhost:80/q-less';
   
   // Para red local (otro PC):
   static const String baseUrl = 'http://192.168.1.100:80/q-less';
   
   // En producción (dominio):
   static const String baseUrl = 'https://tu-dominio.com/q-less';
   ```

3. **Descargar dependencias**
   ```bash
   flutter pub get
   ```

4. **Verificar que no hay errores**
   ```bash
   flutter analyze
   ```
   
   Deberías ver: `No issues found!`

### Paso 5: Ejecutar la Aplicación

1. **Lista dispositivos disponibles**
   ```bash
   flutter devices
   ```

2. **Ejecuta la aplicación**
   ```bash
   # En emulator/simulator:
   flutter run
   
   # En dispositivo físico:
   flutter run -d <device_id>
   ```

3. **Verifica que funciona**
   - Deberías ver la pantalla de Login
   - Haz clic en "Crear una cuenta"
   - Completa el formulario
   - Haz clic en "Crear Cuenta"

## 🧪 Pruebas

### Prueba de Registro Exitoso

1. **Datos de prueba:**
   ```
   Nombre: Juan Pérez García
   Correo: juan.perez@example.com
   Contraseña: micontraseña123
   Confirmar: micontraseña123
   ```

2. **Resultado esperado:**
   - SnackBar verde: "Cuenta creada correctamente"
   - Navegación automática a HomePage
   - Nombre del usuario en el AppBar

3. **Verificar en BD:**
   ```sql
   SELECT * FROM usuarios WHERE correo = 'juan.perez@example.com';
   ```

### Prueba de Error (Email Duplicado)

1. **Intenta registrar el mismo correo nuevamente**
2. **Resultado esperado:**
   - SnackBar rojo: "El correo ya está registrado"
   - Permanece en RegisterPage

### Prueba de Validación

1. **Intenta campos vacíos:**
   - Deberías ver mensajes de error debajo de cada campo

2. **Email inválido:**
   - Intenta: "correo-sin-arroba"
   - Error esperado: "Ingresa un correo válido"

3. **Contraseña corta:**
   - Intenta: "abc"
   - Error: "Mínimo 6 caracteres"

## ⚠️ Solución de Problemas

### "Connection refused" o "Connection timeout"

**Solución:**
1. Verifica que XAMPP esté corriendo (Apache y MySQL)
2. Verifica tu IP (ejecuta `ipconfig`)
3. Verifica que el archivo está en `C:\xampp\htdocs\q-less\backend\`

### "Database not found"

**Solución:**
1. Verifica que ejecutaste `database.sql` en phpMyAdmin
2. Abre phpMyAdmin y busca `q_less_db` en la lista izquierda
3. Si no existe, copia y ejecuta nuevamente `database.sql`

### "CORS error" o "error de origen"

**Solución:**
1. Los headers CORS ya están en `config.php`
2. Si persiste, verifica que `config.php` esté en la carpeta correcta
3. Limpia la caché: `flutter clean && flutter pub get`

### La app no se conecta

**Checklist:**
```
✓ XAMPP Apache corriendo
✓ MySQL corriendo
✓ Carpeta backend en C:\xampp\htdocs\q-less\backend\
✓ Base de datos q_less_db creada
✓ IP correcta en auth_service.dart
✓ Firewall permite conexiones (desactiva si es necesario)
✓ Misma red WiFi si es otro PC
```

### "Error in register.php"

**Pasos de debugging:**
1. Abre navegador: `http://localhost/q-less/register.php`
2. Deberías ver JSON error
3. Verifica que `config.php` esté en la misma carpeta
4. Revisa permisos de carpetas (debe ser legible)

## 📱 Próximos Pasos

Después de que todo funcione:

1. **Implementa Login** (backend/login.php)
2. **Agrega JWT** para sesiones seguras
3. **Crea endpoints CRUD** para colas
4. **Implementa push notifications**
5. **Despliega en producción**

## 📚 Documentación Adicional

- [Flutter Docs](https://flutter.dev/docs)
- [PHP Documentation](https://www.php.net/docs.php)
- [MySQL Reference](https://dev.mysql.com/doc/)
- [HTTP Package](https://pub.dev/packages/http)

## 💡 Tips

- Usa `flutter run -v` para ver logs detallados
- Presiona `r` para hot-reload, `R` para hot-restart
- Abre DevTools con `flutter pub global run devtools`
- Usa `adb logcat` para ver logs de Android en tiempo real

## ✉️ Soporte

Si tienes problemas:
1. Verifica todos los pasos de configuración
2. Revisa los logs en la terminal de Flutter
3. Abre la consola de desarrollador del navegador (F12) en phpMyAdmin

¡Listo! Tu aplicación Q-LESS debería funcionar completamente.
