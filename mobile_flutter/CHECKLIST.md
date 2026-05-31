# ✅ Checklist de Verificación Rápida

Use este archivo para verificar que todo está configurado correctamente.

## Estructura de Carpetas
- [ ] `lib/main.dart` existe
- [ ] `lib/models/user.dart` existe
- [ ] `lib/services/auth_service.dart` existe
- [ ] `lib/pages/register_page.dart` existe
- [ ] `lib/pages/home_page.dart` existe
- [ ] `lib/widgets/app_text_field.dart` existe
- [ ] `lib/utils/validators.dart` existe
- [ ] `backend/config.php` existe
- [ ] `backend/register.php` existe
- [ ] `backend/database.sql` existe

## Flutter Setup
- [ ] `flutter pub get` ejecutado exitosamente
- [ ] `flutter analyze` sin errores (`No issues found!`)
- [ ] `pubspec.yaml` contiene `http: ^1.1.0`
- [ ] Todos los imports están correctos

## Backend PHP
- [ ] XAMPP con Apache corriendo
- [ ] XAMPP con MySQL corriendo
- [ ] Base de datos `q_less_db` creada
- [ ] Tabla `usuarios` existe en phpMyAdmin
- [ ] Credenciales en `config.php` son correctas

## Flutter Configuration
- [ ] IP actualizada en `auth_service.dart`
  - [ ] Localhost: `http://localhost:80/q-less`
  - [ ] O tu IP local: `http://192.168.x.x:80/q-less`
- [ ] App compilada sin errores
- [ ] App se inicia correctamente

## Tests Funcionales
- [ ] Pantalla de Login se muestra
- [ ] Botón "Crear una cuenta" funciona
- [ ] RegisterPage se abre correctamente
- [ ] Validaciones de formulario funcionan
- [ ] Botón "Crear Cuenta" envía datos
- [ ] Respuesta exitosa redirige a HomePage
- [ ] HomePage muestra el nombre del usuario
- [ ] AppBar es de color verde (#3EC13B)

## Seguridad
- [ ] Contraseñas se validan (mínimo 6 caracteres)
- [ ] Email se valida (formato correcto)
- [ ] Contraseña no se muestra en texto plano
- [ ] Manejo de errores con try-catch
- [ ] Mensajes de error seguros (sin info sensible)

## Documentación
- [ ] `README.md` actualizado
- [ ] `SETUP.md` completo con instrucciones
- [ ] `backend/README.md` con detalles del backend
- [ ] Este `CHECKLIST.md` completado

## Próximos Pasos (Opcional)
- [ ] Implementar login completo
- [ ] Agregar recuperación de contraseña
- [ ] Crear endpoint para perfil de usuario
- [ ] Implementar logout
- [ ] Agregar autenticación con JWT
- [ ] Desplegar a producción

---

✅ Si todos los items están marcados, ¡tu aplicación Q-LESS está lista para usar!
