# Q-LESS — Estado de avance (checkpoint)

**Fecha de corte:** junio 2026  
**Versión app:** 2.9.1+31 (APK `Q-LESS-v0.2.9.1.apk`)  
**Rama Git:** `fix/mobile-api-web-v029`  
**Repositorio:** https://github.com/AnderFelipeOrtiz2004/Q-Less  

---

## Componentes del sistema

| Componente | Tecnología | Ubicación / despliegue |
|------------|------------|------------------------|
| App móvil | Flutter (Android) | APK release |
| API móvil | PHP + MySQL | Railway (`mobile-api-production-21d2.up.railway.app`) |
| Web | Laravel + frontend | Misma BD MySQL compartida |
| Base de datos | MySQL | Railway (compartida web + app) |

---

## Funcionalidades implementadas

| Módulo | Estado | Notas |
|--------|--------|-------|
| Registro/login Gmail | ✅ | Verificación por código SMTP |
| Login Google | ⚠️ | Requiere `GOOGLE_WEB_CLIENT_ID` + SHA-1 en Google Cloud |
| Términos legales | ✅ | Un checkbox en registro; diálogo solo para Google |
| Catálogo productos | ✅ | Grid 2 columnas, sync cada 30 s con web |
| CRUD productos (admin) | ✅ | Edición parcial (ej. solo precio) |
| Carrito y reservas stock | ✅ | Timer de expiración de reserva |
| Compras pendientes | ✅ | Admin aprueba/rechaza; correo al aprobar |
| Mis compras + código | ✅ | ID del pedido como código |
| Favoritos | ✅ | Local por usuario |
| Perfil y edición | ✅ | Avatar, descripción, secciones organizadas |
| Chatbot escolar | ✅ | Historial local, sugerencias animadas |
| Sonidos UI | ✅ | click, navigate, purchase, success, edit |
| Timestamps `created_at` | ✅ | Usuarios y productos en API |
| Mercado Pago | ❌ | Eliminado (flujo manual admin) |

---

## Pendientes / mantenimiento futuro

1. Merge PR a `cubsyd/Q-Less` y redeploy Railway tras aceptación.
2. Configurar Google Sign-In en producción (Web Client ID + SHA-1 release).
3. Verificar SMTP en Railway tras cada deploy (`SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`).
4. Release GitHub tag `v0.2.9.1` con APK adjunta.
5. Pruebas en dispositivo físico con usuarios reales (aprendiz, admin).
6. Documentación académica: análisis, manual usuario, proyección de costos.

---

## Archivos de referencia interna

| Archivo | Contenido |
|---------|-----------|
| `mobile_flutter/CODIGO_GUIA.md` | Qué hace cada módulo del código Flutter |
| `docs/PROYECCION_COSTOS_QLESS.md` | Tablas de costos en COP para documentación |
| `material_apoyo_proyeccion_costos_software.docx` | Guía institucional de referencia |

---

## Enlaces útiles

- PR merge: https://github.com/cubsyd/Q-Less/compare/main...AnderFelipeOrtiz2004:fix/mobile-api-web-v029?expand=1
- Releases: https://github.com/AnderFelipeOrtiz2004/Q-Less/releases
