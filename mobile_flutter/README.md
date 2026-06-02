# Q-LESS - Sistema de Papelería con Flutter y PHP

Un prototipo completo de aplicación móvil desarrollado con **Flutter** y backend **PHP/MySQL** para gestionar colas y papelería.

## Características Implementadas

### ✅ Frontend (Flutter)
- **Login Screen**: Pantalla de inicio de sesión
- **Register Page**: Registro completo con validaciones exhaustivas
- **Home Page**: Pantalla principal con AppBar verde institucional
- **Validaciones**:
  - Validación de nombre (mínimo 3 caracteres, solo letras)
  - Validación de email (formato correcto)
  - Validación de contraseña (mínimo 6 caracteres)
  - Confirmación de contraseña
- **Manejo de Errores**: Try-catch para conexiones fallidas
- **UI/UX**: Diseño profesional con colores institucionales (verde #3EC13B)

### ✅ Backend (PHP/MySQL)
- **Registro de usuarios**: Endpoint POST `/q-less/register.php`
- **Validaciones en servidor**: Email duplicado, campos requeridos
- **Seguridad**: Contraseñas hasheadas con BCRYPT
- **CORS**: Headers configurados para comunicación móvil
- **SQL Injection**: Prepared statements para consultas seguras

## Estructura del Proyecto

```
flutter/
├── lib/
│   ├── main.dart                    # Punto de entrada (Login)
│   ├── models/
│   │   ├── index.dart
│   │   └── user.dart                # Modelo de usuario
│   ├── services/
│   │   ├── index.dart
│   │   └── auth_service.dart        # Llamadas HTTP a la API
│   ├── pages/
│   │   ├── index.dart
│   │   ├── register_page.dart       # Pantalla de registro
│   │   └── home_page.dart           # Pantalla principal
│   ├── widgets/
│   │   ├── index.dart
│   │   └── app_text_field.dart      # Widget reutilizable
│   └── utils/
│       ├── index.dart
│       └── validators.dart          # Validadores
├── backend/
│   ├── config.php                   # Configuración BD
│   ├── register.php                 # Endpoint registro
│   ├── database.sql                 # Script SQL
│   └── README.md                    # Guía backend
└── pubspec.yaml                     # Dependencias
```

## Configuración Rápida

### 1. Preparar Flutter
```bash
cd flutter
flutter pub get
flutter analyze
```

### 2. Configurar Backend
1. Copia `backend/` a `C:\xampp\htdocs\q-less\`
2. Ejecuta `backend/database.sql` en phpMyAdmin
3. Actualiza IP en `lib/services/auth_service.dart`

### 3. Ejecutar
```bash
flutter run
```

## Endpoints API

### POST /q-less/register.php
```json
{
  "nombre": "Juan Pérez",
  "correo": "juan@example.com",
  "password": "123456"
}
```

**Success (201):**
```json
{
  "status": "success",
  "message": "Cuenta creada correctamente",
  "data": {"id": 1, "nombre": "Juan Pérez", "correo": "juan@example.com"}
}
```

## Ver más

Para documentación detallada, consulta:
- Backend: `backend/README.md`
- Validaciones: `lib/utils/validators.dart`
- API Service: `lib/services/auth_service.dart`
