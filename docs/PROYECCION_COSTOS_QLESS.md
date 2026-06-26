# Proyección de costos — Proyecto Q-LESS (completa)

**Moneda:** pesos colombianos (COP)  
**Alcance:** sitio web (Angular + Laravel) + app móvil (Flutter) + API móvil (PHP/Railway) + MySQL compartida  
**Duración desarrollo:** 5 meses | **Mantenimiento:** 3 meses post-entrega  
**Clasificación:** proyecto mediano

---

## 16.1 Talento humano

| Rol | Actividad principal | Horas estimadas | Valor por hora | Subtotal |
|-----|---------------------|----------------:|---------------:|---------:|
| Analista de requerimientos | Identificación de necesidades del CBA, requerimientos funcionales y no funcionales, actores (aprendiz, instructor, admin), historias de usuario y reglas del flujo de compras web y móvil | 22 | $28.000 | $616.000 |
| Diseñador UI/UX | Diseño de wireframes y prototipos para la web Angular (login, catálogo, carrito, chatbot) y la app Flutter (grid productos, perfil, registro) | 24 | $28.000 | $672.000 |
| Desarrollador frontend | Construcción del frontend Angular (componentes login, productos, carrito, órdenes, chatbot) y la app Flutter (interfaces, animaciones, sonidos, APK) | 58 | $32.000 | $1.856.000 |
| Desarrollador backend | Desarrollo del backend Laravel (API REST, migraciones, productos, usuarios, órdenes) y mobile-api PHP en Railway (sync, SMTP, Google) | 52 | $32.000 | $1.664.000 |
| Tester o QA | Diseño y ejecución de pruebas manuales en web, app y API; validación de sincronización de productos y usuarios en MySQL | 26 | $26.000 | $676.000 |
| Líder del proyecto | Planeación, seguimiento de entregas, control de versiones Git, revisión documental, coordinación del equipo y despliegue | 20 | $30.000 | $600.000 |
| | | | **Subtotal talento humano** | **$6.084.000** |

---

## 16.2 Herramientas tecnológicas

| Herramienta o recurso | Descripción | Tipo de costo | Valor mensual | Tiempo estimado | Subtotal |
|----------------------|-------------|---------------|--------------:|-----------------|----------:|
| VS Code | Editor para programar Angular, Laravel, PHP mobile-api y Flutter | Gratuito | $0 | 5 meses | $0 |
| Angular CLI / Node.js | Framework y entorno para compilar y ejecutar el sitio web Angular del repositorio | Gratuito | $0 | 5 meses | $0 |
| Flutter SDK | Framework para desarrollar y compilar la APK Android de Q-LESS | Gratuito | $0 | 5 meses | $0 |
| GitHub | Control de versiones del repositorio (frontend, backend, mobile-api, mobile_flutter) | Gratuito | $0 | 5 meses | $0 |
| Railway (API + MySQL) | Hosting en la nube de mobile-api PHP y base de datos MySQL compartida con Laravel | Pago estimado | $32.000 | 5 meses | $160.000 |
| Internet | Conexión para desarrollo local (XAMPP/Laravel), pruebas web, app, deploy y reuniones | Estimado | $88.000 | 5 meses | $440.000 |
| Dominio | Nombre web personalizado del proyecto, si se publica con URL propia | Opcional | — | 1 año | $55.000 |
| | | | **Subtotal herramientas tecnológicas** | | **$655.000** |

*Herramientas adicionales sin costo registradas en el informe: Laravel/Composer, XAMPP (desarrollo local), Gmail SMTP, Google Cloud OAuth.*

---

## 16.3 Infraestructura y equipos

| Recurso | Descripción | Cantidad | Valor estimado unitario | Subtotal |
|---------|-------------|--------:|------------------------:|---------:|
| Computador portátil | Equipo para programar web Angular, backend Laravel, API PHP y compilar la APK | 2 | Recurso disponible | $0 |
| Celular Android | Pruebas de la APK en dispositivo físico (login, compras, chatbot) | 1 | Recurso disponible | $0 |
| Navegador web (Chrome/Edge) | Pruebas del sitio Angular en escritorio y responsive | 1 | Recurso disponible | $0 |
| Internet móvil (datos) | Pruebas de la app fuera de red Wi‑Fi del hogar o institución | 1 | $25.000 | $25.000 |
| Mouse / audífonos | Periféricos para trabajo prolongado de desarrollo | 1 | Recurso disponible | $0 |
| Amortización laptop *(opcional)* | Equipo estimado $2.800.000 ÷ 48 meses × 5 meses de proyecto | 1 | $291.700 | $291.700 |
| | | | **Subtotal infraestructura y equipos** | **$316.700** |

---

## 16.4 Pruebas

| Actividad de prueba | Descripción | Valor estimado |
|---------------------|-------------|---------------:|
| Diseño de casos de prueba | Escenarios de login web/app, registro Gmail, CRUD productos Laravel, sync BD, carrito y aprobación admin | $180.000 |
| Pruebas manuales | Ejecución en Angular (catálogo, carrito, órdenes), Flutter (APK) y endpoints mobile-api | $220.000 |
| Pruebas automatizadas | Pruebas unitarias Angular (login, register) y validación de rutas protegidas con auth.guard | $180.000 |
| Captura de evidencias | Pantallazos web, app y logs de API para el informe de pruebas | $90.000 |
| Reporte de errores | Documentación de hallazgos, severidad, prioridad y estado de corrección | $110.000 |
| Validación final | Revisión integrada web + app + BD antes de entrega del proyecto | $120.000 |
| | **Subtotal pruebas** | **$900.000** |

---

## 16.5 Documentación

| Documento | Descripción | Valor estimado |
|-----------|-------------|---------------:|
| Documento de análisis | Requerimientos, actores, módulos web y móvil, reglas de negocio Q-LESS | $220.000 |
| Documento técnico | Arquitectura Angular–Laravel–Flutter–Railway, modelo BD, APIs y diagramas | $280.000 |
| Manual de usuario | Guía de uso del sitio web y la app para aprendiz, instructor y administrador | $200.000 |
| Manual técnico | Instalación XAMPP/Laravel, variables Railway, compilación APK y estructura del repo | $240.000 |
| Informe de pruebas | Casos ejecutados, resultados, evidencias y correcciones en web y app | $160.000 |
| Documento final consolidado | Informe integral del proyecto con conclusiones y proyección de costos | $150.000 |
| | **Subtotal documentación** | **$1.250.000** |

---

## 16.6 Despliegue y puesta en marcha

| Concepto | Descripción | Valor estimado |
|----------|-------------|---------------:|
| Configuración del hosting | Despliegue mobile-api y MySQL en Railway; variables de entorno de producción | $130.000 |
| Configuración del backend | Laravel API REST, rutas, CORS, storage de imágenes (`storage/productos/`) y mobile-api PHP | $140.000 |
| Configuración de base de datos | Migraciones Laravel (users, productos, categorías, órdenes, reservas) y tablas mobile-api | $120.000 |
| Configuración de autenticación | Login/registro Gmail, SMTP, Google Sign-In, términos legales y roles admin | $110.000 |
| Pruebas de despliegue | Verificación del sitio web, API Railway y APK contra la misma base de datos | $120.000 |
| Capacitación básica | Demostración del sistema a aprendices e instructores del CBA | $130.000 |
| | **Subtotal despliegue y puesta en marcha** | **$750.000** |

---

## 16.7 Mantenimiento

| Actividad de mantenimiento | Frecuencia | Valor mensual estimado | Tiempo proyectado | Subtotal |
|----------------------------|------------|----------------------:|-------------------|----------:|
| Corrección de errores | Mensual | $140.000 | 3 meses | $420.000 |
| Ajustes menores | Mensual | $180.000 | 3 meses | $540.000 |
| Actualización de contenido o datos | Mensual | $100.000 | 3 meses | $300.000 |
| Soporte a usuarios | Mensual | $130.000 | 3 meses | $390.000 |
| Revisión de seguridad básica | Mensual | $90.000 | 3 meses | $270.000 |
| | | | **Subtotal mantenimiento** | **$1.920.000** |

---

## 16.8 Resumen general

| Categoría | Valor estimado |
|-----------|---------------:|
| Talento humano | $6.084.000 |
| Herramientas tecnológicas | $655.000 |
| Infraestructura y equipos | $316.700 |
| Pruebas | $900.000 |
| Documentación | $1.250.000 |
| Despliegue y puesta en marcha | $750.000 |
| Mantenimiento | $1.920.000 |
| | |
| **Subtotal general** | **$11.875.700** |
| **Imprevistos (10 %)** | **$1.187.570** |
| **Total proyectado del proyecto** | **$13.063.270** |

### Sin amortización de laptop (equipos como recurso disponible)

| Concepto | Valor |
|----------|------:|
| Subtotal general | $11.584.000 |
| Imprevistos 10 % | $1.158.400 |
| **Total proyectado** | **$12.742.400** |

---

## Componentes del repositorio considerados

| Carpeta | Tecnología | Función en el costo |
|---------|------------|-------------------|
| `frontend/` | Angular | Sitio web: login, productos, carrito, órdenes, chatbot |
| `backend/laravel_backend/backend_Q-LESS/` | Laravel + MySQL | API REST, migraciones, lógica de negocio web |
| `mobile-api/` | PHP | API para la app móvil en Railway |
| `mobile_flutter/` | Flutter | APK Android sincronizada con la misma BD |

---

*Valores en COP. Estimación académica coherente con proyecto mediano ($7M–$15M). Ajustar si el equipo modifica el alcance.*
