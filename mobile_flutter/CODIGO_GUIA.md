# Q-LESS Mobile — Guía del código (v2.9.1)

## Estructura general

```
mobile_flutter/lib/
├── main.dart              → Entrada: login, Google, rutas
├── config/                → API, constantes, términos legales
├── models/                → Product, User, Order, CartItem
├── services/              → HTTP hacia mobile-api Railway
├── pages/                 → Pantallas de la app
├── widgets/               → UI reutilizable, animaciones, grid
├── theme/                 → Colores y ThemeData Material 3
└── utils/                 → Imágenes, transiciones, categorías
```

## Pantallas (`pages/`)

| Archivo | Qué hace |
|---------|----------|
| `home_page.dart` | Inicio tras login: banner, **grid 2 columnas** de productos, favoritos, carrito, búsqueda, sync cada 30s |
| `products_page.dart` | Catálogo/admin: filtro por categoría, **grid 2 columnas**, crear/editar/borrar (admin) |
| `product_detail_page.dart` | Detalle de un producto, cantidad, agregar al carrito |
| `cart_page.dart` | Carrito con reservas de stock, envío de orden pendiente |
| `my_purchases_page.dart` | Historial del usuario; muestra código cuando admin aprueba |
| `admin_purchases_page.dart` | Admin: aprobar/rechazar compras, habilitar compras por usuario |
| `profile_page.dart` | Perfil organizado en secciones + toggle de sonidos |
| `edit_profile_page.dart` | Editar nombre, descripción, avatar |
| `chatbot_page.dart` | Asistente IA escolar; historial local, sugerencias animadas |
| `favorites_page.dart` | Productos marcados como favoritos |
| `register_page.dart` | Registro Gmail + términos (un solo checkbox) |
| `forgot_password_page.dart` | Recuperación de contraseña por Gmail |

## Servicios (`services/`)

| Archivo | Qué hace |
|---------|----------|
| `auth_service.dart` | Login, registro, verificación Gmail, Google token |
| `product_service.dart` | GET/POST/PUT/DELETE productos, reservas de stock |
| `user_service.dart` | Perfil, listado usuarios, toggle compras |
| `order_service.dart` | Crear orden pendiente, aprobar/rechazar, listar |
| `carrito_service.dart` | Sincronizar carrito con servidor |
| `chatbot_service.dart` | Envía mensajes al backend del chatbot |
| `favorites_service.dart` | Favoritos en SharedPreferences |
| `sound_service.dart` | **click, navigate, purchase, success, edit** (WAV locales) |
| `network_status_service.dart` | Detecta conexión |
| `server_config_service.dart` | URL base de la API (.env / panel desktop) |

## Modelos (`models/`)

| Archivo | Qué hace |
|---------|----------|
| `product.dart` | Producto: precio, stock, imagen, `createdAt` |
| `user.dart` | Usuario: rol, email verificado, compras habilitadas |
| `order.dart` | Pedido: estado pendiente/aprobado/rechazado |
| `cart_item.dart` | Ítem en carrito + reserva temporal |

## Widgets clave (`widgets/`)

| Widget | Qué hace |
|--------|----------|
| `product_grid_tile.dart` | **Tarjeta compacta para 2 columnas** con animación |
| `fade_slide_entry.dart` | Entrada fade + slide (stagger por índice) |
| `hover_elevated_card.dart` | Elevación animada al hover/tap |
| `interactive_scale_button.dart` | Botón con escala al presionar |
| `sound_button.dart` | Botón + sonido automático |
| `legal_terms_dialog.dart` | Términos legales (Google) y visor solo lectura |

## Flujo de compras (lógica)

1. Usuario Gmail verificado → registro/login  
2. Admin activa `purchases_enabled` por usuario  
3. Usuario reserva stock → carrito → orden **pendiente**  
4. Admin aprueba → email con código → visible en **Mis Compras**  
5. Sin Mercado Pago; misma BD MySQL que la web Laravel  

## Sonidos (`assets/sounds/`)

Generados con `tool/generate_sounds.ps1`. Puedes reemplazarlos por MP3 de [Pixabay](https://pixabay.com/es/sound-effects/search/app/) y actualizar rutas en `sound_service.dart`.

| Archivo | Uso |
|---------|-----|
| `click.wav` | Chips, favoritos, enviar chat |
| `navigate.wav` | Cambiar de pantalla / menú inferior |
| `purchase.wav` | Agregar al carrito / comprar |
| `success.wav` | Respuesta del chatbot, acciones OK |
| `edit.wav` | Editar producto o perfil |

Toggle en **Perfil → Preferencias → Sonidos de la app**.

## Backend (`mobile-api/`)

| Archivo | Qué hace |
|---------|----------|
| `products.php` | CRUD productos; PUT parcial al editar solo precio |
| `register.php` / `login.php` | Auth Gmail + SMTP |
| `google_login.php` | Login con ID token Google |
| `orders.php` | Órdenes pendientes → aprobar + email |
| `users.php` | Perfiles, UTF-8, toggle compras |
| `helpers.php` | Tablas, timestamps, rutas `storage/productos/` |

## Compilar APK

```cmd
cd mobile_flutter
flutter pub get
flutter build apk --release
```
