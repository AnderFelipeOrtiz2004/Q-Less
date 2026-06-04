# Nombre de proyecto 
Q-LESS 

# Idea de proyecto Q-LESS 📚
Una pagina web de utiles escolares e insumos para los aprendices e instructores del CBA 
para el optimo desarrollo de sus actvidades academicas. Lo que se busca es facilitar el 
acceso a los materiales escolares y de papeleria de una manera optima y eficaz.

# La pagina web permite a los usuarios:
- Registrar y crear cuenta a usuarios nuevos
- Ver un amplio catalogo de productos dividos por categorias
- Ver detalle de los productos junto con nombre, descripcion e imagen
- Buscar productos por categorias
- Seleccionar productos y ser llevados al carrito de compras
- Sistema de apartado para productos y comprar mas tarde
- Pasarela pagos con codigo de confirmacion que es enviado al correo individual
- IA ChatBOT para consultas sobre materiales y guia de actividades
  
El proyecto Q-less resuelve la necesidad del acceso a los materiales escolares y de papeleria de una manera optima y eficaz,
mejorando la experiencia tanto para usuarios como para administradores


# Integrantes 🚻
- Anderson Felipe Ortiz Garcia
- Cristian Dario Rojas Ubalteros
- Daniel Andres Cubides Herrera

# Características Principales 📗

### Usuarios
- Registro de usuarios.
- Inicio de sesión.
- Protección de rutas.
- Gestión de autenticación.
  
### Productos
- Creación de productos.
- Edición de productos.
- Visualización de catálogo.
- Gestión de categorías.

### Carrito de Compras
- Agregar productos al carrito.
- Reservas de carrito.
- Gestión dinámica de cantidades.
- Flujo de pedidos.
  
### Pedidos
- Creación de órdenes.
- Gestión de estados.
- Historial de pedidos.

### Inteligencia Artificial y Chatbot
- Sistema de recomendaciones.
- Integración de chatbot.
- Servicios inteligentes para asistencia al usuario.
  
### Correos y Confirmaciones
- Envío de códigos de entrega.
- Gestión de notificaciones mediante correo.

# Arquitectura del Proyecto
El proyecto se encuentra dividido en dos capas principales:

# Frontend

Aplicación cliente desarrollada en Angular.
Responsabilidades:

- Renderizado de interfaces.
- Consumo de API REST.
- Gestión de sesiones.
- Navegación y experiencia de usuario.

# Backend

API REST desarrollada en Laravel.
Responsabilidades:

- Lógica de negocio.
- Gestión de autenticación.
- Persistencia de datos.
- Gestión de pedidos y productos.
- Servicios inteligentes y chatbot.
  
# Flujo General del Sistema

El sistema **Q-Less** sigue una arquitectura cliente-servidor desacoplada, donde el frontend desarrollado en Angular consume servicios REST proporcionados por el backend en Laravel.

## Flujo Principal del Usuario

```text
Usuario
   │
   ▼
Frontend Angular
   │
   ├── Autenticación
   ├── Visualización de productos
   ├── Gestión del carrito
   ├── Generación de pedidos
   └── Chatbot y recomendaciones
   │
   ▼
API REST Laravel
   │
   ├── Controladores
   ├── Servicios
   ├── Validaciones
   ├── Lógica de negocio
   └── Autenticación
   │
   ▼
Base de Datos MySQL
```

## Flujo de Autenticación

1. El usuario accede al sistema.
2. El frontend muestra el formulario de login o registro.
3. Angular envía la información al backend mediante peticiones HTTP.
4. Laravel valida las credenciales.
5. El sistema genera la sesión o token de autenticación.
6. El usuario obtiene acceso a las rutas protegidas.

## Flujo de Compra

1. El usuario navega por el catálogo de productos.
2. Selecciona uno o varios productos.
3. Los productos se agregan al carrito de compras.
4. El sistema valida disponibilidad y cantidades.
5. El usuario confirma el pedido.
6. Laravel registra la orden en la base de datos.
7. El sistema genera confirmaciones y actualiza el inventario.

## Flujo Administrativo

1. El administrador inicia sesión.
2. Accede al panel administrativo.
3. Gestiona productos, categorías y pedidos.
4. El backend procesa las operaciones CRUD.
5. La base de datos actualiza la información en tiempo real.

## Flujo del Chatbot Inteligente

1. El usuario interactúa con el chatbot.
2. Angular envía la consulta al backend.
3. Laravel procesa la solicitud mediante servicios inteligentes.
4. El sistema genera recomendaciones o respuestas automáticas.
5. El frontend muestra la respuesta al usuario.

## Comunicación Entre Capas

### Frontend Angular

Responsable de:

* Interfaces gráficas.
* Navegación.
* Gestión de sesiones.
* Consumo de API REST.

### Backend Laravel

Responsable de:

* Lógica de negocio.
* Seguridad.
* Validaciones.
* Gestión de datos.
* Servicios inteligentes.

### Base de Datos MySQL

Responsable de:

* Persistencia de información.
* Relaciones entre entidades.
* Integridad de datos.

## Flujo Técnico General

```text
Cliente (Angular)
       │
       ▼
Servicios Angular
       │
       ▼
HTTP Requests
       │
       ▼
API Laravel
       │
       ├── Controllers
       ├── Services
       ├── Models
       └── Middleware
       │
       ▼
MySQL Database
```

# Funcionalidades clave de la plataforma web 📘
- **Buscador y filtros avanzados:** Herramientas que permiten organizar los artículos por categorías o precios
- **Fichas de producto detalladas:** Información técnica del material, dimensiones, gramajes y fotografías de alta resolución
- **Pasarelas de pago seguras:** Integración de múltiples métodos como tarjetas de crédito, transferencias o billeteras digitales
- **Actualización de stock en tiempo real:** Indicadores que muestran la disponibilidad exacta de cada artículo para evitar compras sin existencias

# Tipos de productos en la papelería virtual 📙
- **Materiales físicos tradicionales:** Cuadernos, bolígrafos, carpetas, hojas y suministros escolares o de oficina
- **Papelería creativa:** Kits, plantillas de diseño o insumos especializados para manualidades

# Tecnologías Utilizadas 🖥️
### Frontend
- Angular
- TypeScript
- HTML5
- SCSS
- Angular Router
- Angular Guards
- Angular Services

### Backend
- Laravel
- PHP
- Composer
- Laravel Controllers
- Laravel Models
- Laravel Services
- Laravel Mail
  
### Base de Datos
- MySQL
  
# Herramientas
- Node.js
- npm
- Vite
- Git
- GitHub

# Estructura del proyecto
```text
Q-Less/
│
├── frontend/
│   ├── src/
│   │   ├── app/
│   │   │   ├── components/
│   │   │   ├── services/
│   │   │   ├── guards/
│   │   │   ├── app.routes.ts
│   │   │   └── app.config.ts
│   │   ├── index.html
│   │   └── styles.css
│   ├── package.json
│   └── tsconfig.json
│
├── backend/
│   ├── laravel_backend/
│   │   └── backend_Q-LESS/
│   │       ├── app/
│   │       │   ├── Http/Controllers/
│   │       │   ├── Models/
│   │       │   ├── Services/
│   │       │   └── Mail/
│   │       ├── routes/
│   │       ├── public/
│   │       ├── storage/
│   │       ├── artisan
│   │       ├── composer.json
│   │       └── vite.config.js
│   └── package.json
│
├── package.json
└── README.md
```
   
# Requisitos Previos

Antes de ejecutar el proyecto, asegúrate de tener instalado:

### Generales
- Node.js >= 18
- npm >= 9
- Git
  
### Backend
- PHP >= 8.1
- Composer
- MySQL
- Laravel CLI (opcional)

### Frontend
- Angular CLI
 Instalación de Angular CLI: 
- npm install -g @angular/cli

# Instalacion
1. Clonar el repositorio
git clone <https://github.com/AnderFelipeOrtiz2004/Q-Less>
cd Q-Less

# Configuración del Backend
1. Acceder al backend
cd backend/laravel_backend/backend_Q-LESS

2. Instalar dependencias de PHP
composer install

3. Instalar dependencias de Node
npm install

4. Configurar variables de entorno
Copiar el archivo de ejemplo:
cp .env.example .env

5. Generar clave de Laravel
php artisan key:generate

6. Configurar base de datos
Editar el archivo .env:
```text
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=qless
DB_USERNAME=root
DB_PASSWORD=
```
7. Ejecutar migraciones
php artisan migrate

8. Ejecutar el servidor backend
php artisan serve
Servidor disponible en:
http://127.0.0.1:8000

# Configuración del Frontend
1. Acceder al frontend
cd frontend

2. Instalar dependencias
npm install

3. Ejecutar el proyecto Angular - ng serve
4. La aplicación estará disponible en: http://localhost:4200

# Variables de Entorno
Backend (.env)
```text
APP_NAME=Q-Less
APP_ENV=local
APP_DEBUG=true
APP_URL=http://127.0.0.1:8000

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=qless
DB_USERNAME=root
DB_PASSWORD=
```
# Configuración de Base de Datos

El sistema **Q-Less** utiliza **MySQL** como motor de base de datos principal y Laravel como framework backend para la gestión de persistencia de datos.

# Tecnologías Utilizadas

* MySQL
* Laravel Eloquent ORM
* PHP PDO
* Laravel Migrations
* Laravel Seeders

# Creación de la Base de Datos

Antes de ejecutar el proyecto, crear una base de datos en MySQL.

## Ejemplo desde MySQL

```sql
CREATE DATABASE qless;
```


# Configuración del Archivo .env

Ubicar el archivo `.env` dentro del backend:

```bash
backend/laravel_backend/backend_Q-LESS/.env
```

Configurar las variables de entorno de conexión:

```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=qless
DB_USERNAME=root
DB_PASSWORD=
```

# Explicación de Variables

| Variable      | Descripción                  |
| ------------- | ---------------------------- |
| DB_CONNECTION | Motor de base de datos       |
| DB_HOST       | Dirección del servidor MySQL |
| DB_PORT       | Puerto de conexión           |
| DB_DATABASE   | Nombre de la base de datos   |
| DB_USERNAME   | Usuario de MySQL             |
| DB_PASSWORD   | Contraseña de MySQL          |

---

# Configuración de Laravel

## Instalar Dependencias

```bash
composer install
```

## Generar Clave de Aplicación

```bash
php artisan key:generate
```

## Limpiar Caché de Configuración

```bash
php artisan config:clear
```

```bash
php artisan cache:clear
```

# Migraciones

Las migraciones permiten crear automáticamente la estructura de tablas del sistema.

## Ejecutar Migraciones

```bash
php artisan migrate
```

# Seeders

Los seeders permiten insertar datos iniciales en la base de datos.

## Ejecutar Seeders

```bash
php artisan db:seed
```

O ejecutar migraciones y seeders juntos:

```bash
php artisan migrate --seed
```

# Relación de Entidades Principales

La base de datos del sistema Q-Less se encuentra orientada a la gestión de una papelería virtual.

## Entidades Principales

* Usuarios
* Productos
* Categorías
* Carrito de Compras
* Pedidos
* Detalle de Pedidos
* Reservas
* Recomendaciones
* Historial
* Roles


# Flujo de Persistencia de Datos

```text id="1lc1o1"
Frontend Angular
        │
        ▼
HTTP Request
        │
        ▼
Laravel Controllers
        │
        ▼
Services / Business Logic
        │
        ▼
Eloquent Models
        │
        ▼
MySQL Database
```

---

# Verificación de Conexión

Para verificar que Laravel se encuentra conectado correctamente a MySQL:

```bash
php artisan migrate:status
```

Si la conexión es exitosa, Laravel mostrará el estado de las migraciones.


# Posibles Errores Comunes

## Error: Access denied for user

Verificar:

* Usuario MySQL
* Contraseña
* Permisos de acceso

---

## Error: Unknown database

Crear previamente la base de datos:

```sql
CREATE DATABASE qless;
```


## Error: Could not connect to database server

Verificar:

* Que MySQL esté iniciado.
* Puerto correcto.
* Configuración del `.env`.


# Buenas Prácticas Implementadas

* Uso de variables de entorno.
* Separación entre lógica y persistencia.
* Uso de ORM Eloquent.
* Migraciones versionadas.
* Escalabilidad de entidades.
* Integridad relacional.
* Arquitectura desacoplada.


# Comandos Útiles

## Reiniciar Base de Datos

```bash
php artisan migrate:fresh
```

## Reiniciar Base de Datos con Seeders

```bash
php artisan migrate:fresh --seed
```

## Crear Nueva Migración

```bash
php artisan make:migration create_table_name
```

## Crear Modelo

```bash
php artisan make:model NombreModelo
```

## Crear Seeder

```bash
php artisan make:seeder NombreSeeder
```

# Arquitectura de Persistencia

Q-Less implementa el patrón MVC proporcionado por Laravel:

* Models → Gestión de datos
* Controllers → Flujo de peticiones
* Services → Lógica de negocio
* Migrations → Estructura de base de datos
* Seeders → Datos iniciales

Esto permite mantener una arquitectura modular, escalable y mantenible.


# Ejecución del Proyecto
### Backend
- php artisan serve

### Frontend
- ng serve

# Módulos Principales
Autenticación
Archivos relevantes:
- LoginController.php
- RegisterController.php
- AuthController.php
- auth.guard.ts
- auth.interceptor.ts

Funciones:
- Registro.
- Inicio de sesión.
- Protección de rutas.
- Manejo de sesiones.

# Productos
Archivos relevantes:
- ProductoController.php
- products/
- create-product/
- edit-product/

Funciones:
- Crear productos.
- Editar productos.
- Mostrar catálogo.
- Administración de inventario.

# Carrito
Archivos relevantes:
- CartController.php
- cart.service.ts
- cart/
Funciones:
- Gestión del carrito.
- Agregar productos.
- Eliminar productos.
- Reservas temporales.

# Pedidos
Archivos relevantes:
- OrderController.php
- orders/
Funciones:
- Gestión de órdenes.
- Historial de compras.
- Confirmaciones.

# Chatbot y Recomendaciones
Archivos relevantes:
- ChatbotController.php
- ChatbotRecommendationService.php
- chatbot.service.ts
- chatbot/
Funciones:
- Asistencia automatizada.
- Recomendaciones inteligentes.
- Interacción con usuarios.

# API y Endpoints
Las rutas principales se encuentran definidas en:
routes/api.php

Ejemplos:
POST /api/login
POST /api/register
GET /api/products
POST /api/cart
GET /api/orders

# Seguridad y Autenticación
El proyecto implementa:
- Protección de rutas.
- Guards en Angular.
- Interceptores HTTP.
- Validación de usuarios.
- Manejo seguro de autenticación.
- Separación entre frontend y backend.

# Buenas Prácticas Implementadas
- Arquitectura desacoplada.
- Separación de responsabilidades.
- Uso de servicios.
- Modularización de componentes.
- Organización por capas.
- Uso de controladores y modelos.
- Configuración mediante variables de entorno.
- Escalabilidad del proyecto.

# Licencia
Este proyecto es de uso académico y educativo.

# Estado del Proyecto
Proyecto en desarrollo activo.

Posibles mejoras futuras:
- Integración de pasarela de pagos.
- Panel administrativo avanzado.
- Dashboard analítico.
- Sistema de notificaciones en tiempo real.
- Recomendaciones inteligentes avanzadas.
- Optimización responsive.
- Implementación de pruebas automatizadas.

# Dependencias 📁
- Node.js
- Angular CLI
- Este repositorio contiene el Frontend (Angular) y el Backend (Node.js).

## Instrucciones para empezar 📩
1. **Clonar el repositorio:** `git clone [https://github.com/AnderFelipeOrtiz2004/Q-Lees]`
2. **Configurar Backend**
1. **Tener Git instalado en tu computadora.**
2. **Clonar el repositorio:** `git clone [https://github.com/AnderFelipeOrtiz2004/Q-Lees]`
3. **Copiar la URL:** `En GitHub, ve a la página principal del repositorio y haz clic en el botón verde "Code". Copia la dirección HTTPS o SSH`
4. **Abrir la Terminal:** `Abre Git Bash, Terminal o CMD y usa cd para ir a la carpeta donde quieras guardar el proyecto.`
5. **Ejecutar el comando:** `Escribe git clone seguido de la URL copiada y presiona Enter Ejemplo: git clone https://github.com`


## Ejecución local
 **Configurar Backend:**
- `cd backend`
- `npm install`
- `npm run dev`
- `cd Project-Final`
- `npm install`
- `ng serve`
     
## Despliegue ✏️
- Railway: `Bases de datos`
- Railway: `Despliegue de front`
- Railway: `Despliegue de back`



## Evidencias
### Repositorio Q-less [Visita GitHub](https://github.com/AnderFelipeOrtiz2004/Q-Less)

---
- <img width="1600" height="833" alt="image" src="https://github.com/user-attachments/assets/64226f04-ffa4-4e37-8337-28ea387dcc96" />
- <img width="1600" height="826" alt="image" src="https://github.com/user-attachments/assets/64f602cf-0cdf-427f-ad55-78e1579051f1" />
- <img width="1600" height="837" alt="image" src="https://github.com/user-attachments/assets/1bde69d2-23a0-49ea-8057-c4420aeef5f3" />

