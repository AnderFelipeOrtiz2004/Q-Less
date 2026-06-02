# Backend Q-LESS - Guía de Configuración

## Requisitos
- XAMPP (con PHP 7.4+ y MySQL)
- Flutter app con paquete `http`

## Pasos de Configuración

### 1. Crear la Base de Datos

1. Abre phpMyAdmin en tu navegador: `http://localhost/phpmyadmin`
2. Ve a la pestaña "SQL"
3. Copia y pega el contenido de `database.sql`
4. Ejecuta el script SQL

O desde línea de comandos:
```bash
mysql -u root < database.sql
```

### 2. Configurar los Archivos PHP

1. Copia la carpeta `backend` a la raíz de tu servidor XAMPP:
   - Windows: `C:\xampp\htdocs\q-less\`
   - macOS: `/Applications/XAMPP/htdocs/q-less/`
   - Linux: `/opt/lampp/htdocs/q-less/`

2. Edita `config.php` si necesitas cambiar credenciales de base de datos:
   ```php
   define('DB_HOST', 'localhost');
   define('DB_USER', 'root');
   define('DB_PASS', ''); // XAMPP default vacío
   define('DB_NAME', 'q_less_db');
   ```

### 3. Configurar la URL en Flutter

En el archivo `lib/services/auth_service.dart`, reemplaza:
```dart
static const String baseUrl = 'http://YOUR_IP:80/q-less';
```

Con tu IP de XAMPP. Ejemplos:
- **Localhost (mismo PC)**: `http://localhost:80/q-less`
- **Red local (otro PC)**: `http://192.168.x.x:80/q-less`
- **IMPORTANTE**: Usa HTTP, no HTTPS, para XAMPP local

### 4. Probar la Conexión

Abre en tu navegador:
```
http://localhost/q-less/register.php
```

Deberías ver una respuesta JSON indicando un error de método (esperado, porque GET no está permitido).

## Endpoints Disponibles

### POST /register.php
Registra un nuevo usuario

**Request Body:**
```json
{
  "nombre": "Juan Pérez",
  "correo": "juan@example.com",
  "password": "micontraseña123"
}
```

**Success Response (201):**
```json
{
  "status": "success",
  "message": "Cuenta creada correctamente",
  "data": {
    "id": 1,
    "nombre": "Juan Pérez",
    "correo": "juan@example.com"
  }
}
```

**Error Response (400):**
```json
{
  "status": "error",
  "message": "El correo ya está registrado"
}
```

## Validaciones en el Backend

- ✅ Email obligatorio y formato válido
- ✅ Contraseña mínimo 6 caracteres
- ✅ Nombre mínimo 3 caracteres
- ✅ Verificación de email duplicado
- ✅ Contraseña hasheada con BCRYPT
- ✅ Headers CORS habilitados
- ✅ Prepared statements para prevenir SQL injection

## Solución de Problemas

### "Connection refused"
- Verifica que XAMPP esté corriendo
- Asegúrate que MySQL está iniciado en XAMPP Control Panel

### "Database not found"
- Ejecuta el script `database.sql` en phpMyAdmin
- Verifica el nombre de la base de datos en `config.php`

### "CORS error"
- Los headers CORS ya están configurados en `config.php`
- Si persiste, agrega esto a `config.php`:
  ```php
  header('Access-Control-Allow-Origin: *');
  ```

### "Connection timeout"
- Verifica tu dirección IP
- Asegúrate que la ruta es correcta: `http://IP:80/q-less/register.php`

## Estructura de Carpetas

```
flutter/
├── backend/
│   ├── config.php           # Configuración de BD
│   ├── register.php         # Endpoint de registro
│   ├── database.sql         # Script SQL
│   └── README.md            # Este archivo
├── lib/
│   ├── models/
│   ├── services/
│   ├── pages/
│   ├── widgets/
│   └── utils/
```

## Próximos Pasos

1. Implementar endpoint de login
2. Agregar autenticación con tokens (JWT)
3. Implementar recuperación de contraseña
4. Crear endpoints para gestión de colas
