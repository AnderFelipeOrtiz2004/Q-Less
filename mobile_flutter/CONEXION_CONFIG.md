# Guía de Configuración - Flutter App con XAMPP

## ✅ Configuración Completada

### 1. **Base de Datos**
- ✅ Base de datos `q_less_db` creada
- ✅ Tabla `usuarios` con campos: id, nombre, correo, password, etc.
- ✅ Contraseñas almacenadas con hash BCRYPT

### 2. **Backend PHP**
- ✅ `backend/config.php` - Configuración de conexión MySQL
- ✅ `backend/register.php` - Endpoint para registrar usuarios
- ✅ `backend/login.php` - Endpoint para iniciar sesión (NUEVO)

### 3. **App Flutter**
- ✅ `lib/services/auth_service.dart` - Servicio de autenticación
- ✅ `lib/main.dart` - LoginScreen funcional
- ✅ `lib/pages/register_page.dart` - Registro de usuarios
- ✅ `lib/pages/home_page.dart` - Página de inicio

## 🔧 Configuración de Conexión

### Opción 1: Para Testing Local (Emulador o Web)
En `lib/services/auth_service.dart`, el baseUrl está configurado como:
```dart
static const String baseUrl = 'http://localhost:80';
```

### Opción 2: Para Dispositivo Físico o Externa
Si ejecutas la app en un dispositivo físico o desde otra máquina, debes cambiar la URL:

1. **Obtén tu IP local:**
   ```
   En Windows: ipconfig
   En Mac/Linux: ifconfig
   ```
   Busca algo como: `192.168.1.100` o `192.168.0.5`

2. **Actualiza el baseUrl en `lib/services/auth_service.dart`:**
   ```dart
   static const String baseUrl = 'http://192.168.1.100:80';
   // Reemplaza 192.168.1.100 con tu IP real
   ```

## 📋 Requisitos XAMPP

- **Apache** debe estar en funcionamiento (puerto 80)
- **MySQL** debe estar activo
- El proyecto debe estar en la carpeta `htdocs` de XAMPP o ser accesible vía alias

## 🧪 Pruebas

### Registrar Usuario
1. Abre la app Flutter
2. Click en "Crear una cuenta"
3. Llena los datos:
   - **Nombre**: Mínimo 3 caracteres
   - **Correo**: Email válido (único)
   - **Contraseña**: Mínimo 6 caracteres
4. Click en "Registrarse"

### Iniciar Sesión
1. Usa los datos del usuario registrado
2. Click en "Inicia sesión"
3. Serás llevado a la HomePage

## 🐛 Solución de Problemas

### "Connection timeout" o "Network error"
- Verifica que XAMPP esté corriendo
- Comprueba que la URL base sea correcta
- Para dispositivo físico: asegúrate de usar la IP local, no localhost

### "Correo ya está registrado"
- El correo ya existe en la BD
- Intenta con un correo diferente

### "Correo o contraseña incorrectos"
- Verifica que los datos sean exactos
- Confirma que la contraseña sea correcta
- El usuario debe estar en estado "activo" en la BD

## 📊 Estructura de Respuestas

### Login Success
```json
{
  "status": "success",
  "message": "Sesión iniciada correctamente",
  "user": {
    "id": "1",
    "nombre": "Juan Pérez",
    "correo": "juan@example.com"
  }
}
```

### Login Error
```json
{
  "status": "error",
  "message": "Correo o contraseña incorrectos"
}
```

## 🔐 Seguridad

- Las contraseñas se almacenan con hash BCRYPT
- Nunca se envían contraseñas en las respuestas del servidor
- Validación de email en client-side y server-side
- Validación de contraseña mínima (6 caracteres)

## 📝 Notas

- Los usuarios se crean como "activos" por defecto
- Puedes desactivar usuarios manualmente en la BD cambiando el estado a "inactivo"
- Para cambiar la contraseña, necesitarías crear un endpoint adicional (no incluido aún)
