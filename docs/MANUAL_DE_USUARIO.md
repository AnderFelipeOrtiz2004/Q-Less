# MANUAL DE USUARIO

**Sistema:** Q-LESS — Útiles escolares e insumos académicos  
**Documento:** Manual de usuario  
**Versión del sistema:** 2.9.1 (APK v0.2.9.1)  
**Versión del manual:** 1.0  
**Fecha:** Junio 2026  
**Programa de formación:** Análisis y Desarrollo de Software  
**Institución:** CBA (Centro de Biotecnología Agropecuaria)  

**Equipo responsable:**  
Anderson Felipe Ortiz García · Cristian Darío Rojas Ubalteros · Daniel Andrés Cubides Herrera  

---

## Control de cambios

| Versión | Fecha     | Responsable      | Descripción                    |
|---------|-----------|------------------|--------------------------------|
| 1.0     | Jun 2026  | Equipo Q-LESS    | Creación inicial del manual    |

---

## 1. Introducción

El presente manual describe el funcionamiento de **Q-LESS**, aplicación móvil para Android orientada a aprendices e instructores del CBA. El sistema facilita la consulta, reserva y solicitud de compra de útiles escolares y materiales de papelería, con sincronización del catálogo en línea y asistencia mediante chatbot inteligente.

El documento orienta al usuario final en el acceso, navegación y uso de las funcionalidades principales, sin abordar aspectos técnicos de instalación o programación.

---

## 2. Objetivo del manual

Orientar al usuario final en el uso adecuado de Q-LESS, mediante la descripción ordenada de los procedimientos para registrarse, iniciar sesión, consultar productos, gestionar el carrito, realizar solicitudes de compra y administrar el catálogo cuando corresponda al rol de administrador.

---

## 3. Alcance del manual

| Aspecto | Descripción |
|---------|-------------|
| **Incluye** | Acceso, navegación, catálogo, favoritos, carrito, compras, perfil, chatbot y panel administrativo de compras y productos. |
| **No incluye** | Instalación del servidor, configuración de Railway, desarrollo del código, despliegue web Laravel o mantenimiento de base de datos. |

---

## 4. Público objetivo

| Tipo de usuario | Descripción |
|-----------------|-------------|
| **Aprendiz / usuario general** | Persona que consulta productos, agrega favoritos, reserva artículos y solicita compras. |
| **Instructor** | Persona que utiliza las mismas funciones del usuario general para adquirir materiales. |
| **Administrador** | Persona autorizada que gestiona productos, aprueba o rechaza compras y habilita compras a otros usuarios. |

---

## 5. Requisitos previos

| Requisito | Descripción |
|-----------|-------------|
| Dispositivo Android | Teléfono o tableta con Android actualizado. |
| Conexión a internet | Necesaria para sincronizar catálogo, autenticación y compras. |
| Aplicación instalada | APK Q-LESS v0.2.9.1 instalada en el dispositivo. |
| Correo electrónico | Requerido para registro, verificación y notificaciones de compra. |
| Cuenta verificada | Para solicitar compras, el correo debe estar verificado y las compras habilitadas por el administrador. |

---

## 6. Acceso al sistema

### 6.1 Inicio de sesión

1. El usuario abre la aplicación Q-LESS en el dispositivo.
2. El sistema muestra la pantalla de inicio de sesión.
3. El usuario ingresa el correo electrónico y la contraseña registrados.
4. El usuario selecciona el botón **Iniciar sesión**.
5. El sistema valida las credenciales y muestra la pantalla principal si los datos son correctos.

### 6.2 Registro de cuenta nueva

1. El usuario selecciona la opción **Registrarse**.
2. El sistema muestra el formulario con nombre, correo, contraseña y confirmación.
3. El usuario marca la casilla de aceptación de términos y condiciones.
4. El usuario selecciona **Registrarse**.
5. El sistema envía un código de verificación al correo indicado.
6. El usuario ingresa el código recibido y confirma.
7. El sistema activa la cuenta y permite el inicio de sesión.

### 6.3 Inicio de sesión con Google

1. El usuario selecciona **Iniciar sesión con Google**.
2. El sistema muestra el diálogo de términos y condiciones (si aplica).
3. El usuario acepta los términos y selecciona la cuenta de Google.
4. El sistema registra o vincula la cuenta y muestra la pantalla principal.

### 6.4 Recuperación de contraseña

1. En la pantalla de inicio de sesión, el usuario selecciona **¿Olvidaste tu contraseña?**
2. El sistema solicita el correo registrado.
3. El usuario ingresa el correo y confirma el envío.
4. El sistema envía instrucciones o código al correo para restablecer la contraseña.

---

## 7. Navegación general

Al ingresar, el sistema muestra la **pantalla de inicio** con barra superior (perfil, búsqueda) y barra inferior de acceso rápido:

| Elemento | Descripción |
|----------|-------------|
| **Inicio** | Catálogo destacado en cuadrícula de dos columnas. |
| **Productos** | Listado completo con filtros y gestión (admin). |
| **Favoritos** | Productos marcados como favoritos. |
| **Chat** | Asistente virtual para consultas escolares. |
| **Carrito** | Reservas y solicitud de compra (usuario general). |
| **Compras** | Panel de aprobación de pedidos (solo administrador). |
| **Perfil** | Icono de usuario en la parte superior; acceso a datos personales y cierre de sesión. |

---

## 8. Módulos del sistema

### 8.1 Inicio y catálogo

**Rol:** Usuario general, instructor, administrador.

1. El usuario visualiza los productos disponibles en formato de tarjetas (dos columnas).
2. El usuario puede desplazarse para ver más artículos; el catálogo se actualiza automáticamente.
3. El usuario selecciona un producto para ver nombre, descripción, precio, stock e imagen.
4. Desde el detalle, el usuario puede agregar el artículo al carrito o marcarlo como favorito.

**Resultado esperado:** El sistema muestra la información del producto y confirma las acciones con mensajes breves en pantalla.

---

### 8.2 Búsqueda de productos

**Rol:** Todos los usuarios.

1. El usuario selecciona el icono de búsqueda en la barra superior.
2. El sistema despliega el campo de búsqueda.
3. El usuario escribe el nombre o término relacionado.
4. El sistema filtra y muestra los productos coincidentes.

---

### 8.3 Favoritos

**Rol:** Usuario general e instructor.

1. El usuario selecciona **Favoritos** en la barra inferior.
2. El sistema muestra los productos guardados previamente.
3. El usuario puede abrir el detalle o agregar un artículo al carrito desde esta sección.

---

### 8.4 Carrito y reserva de productos

**Rol:** Usuario con compras habilitadas y correo verificado.

1. El usuario agrega productos al carrito desde el catálogo o favoritos.
2. El sistema reserva temporalmente el stock y muestra el tiempo restante de la reserva.
3. El usuario selecciona **Carrito** en la barra inferior.
4. El sistema lista los artículos, cantidades y total.
5. El usuario ajusta cantidades o elimina productos si lo requiere.
6. El usuario selecciona **Solicitar compra** o equivalente para enviar el pedido.
7. El sistema registra la orden con estado **pendiente de aprobación**.

**Observación:** Si la reserva expira, el sistema elimina el producto del carrito y libera el stock automáticamente.

---

### 8.5 Mis compras

**Rol:** Usuario general e instructor.

1. El usuario accede desde **Perfil** → **Mis compras**.
2. El sistema muestra el historial con estados: pendiente, aceptada, rechazada o completada.
3. Cuando el administrador aprueba una compra, el sistema envía un código al correo del usuario.
4. El usuario consulta el código de entrega en el detalle del pedido aceptado.

---

### 8.6 Perfil de usuario

**Rol:** Todos los usuarios autenticados.

1. El usuario selecciona el icono de perfil en la barra superior.
2. El sistema muestra nombre, correo, rol y opciones de configuración.
3. El usuario puede seleccionar **Editar perfil** para actualizar nombre, descripción o avatar.
4. El usuario puede activar o desactivar los sonidos de la interfaz.
5. Desde el perfil se accede a **Mis compras**, **Ver productos** y **Cerrar sesión**.

---

### 8.7 Chatbot escolar

**Rol:** Todos los usuarios autenticados.

1. El usuario selecciona **Chat** en la barra inferior.
2. El sistema muestra el asistente con sugerencias de consulta.
3. El usuario escribe una pregunta sobre materiales o actividades académicas.
4. El sistema responde con orientación basada en inteligencia artificial.
5. El historial de la conversación se conserva en el dispositivo durante la sesión.

---

### 8.8 Gestión de productos (administrador)

**Rol:** Administrador.

1. El usuario administrador ingresa a **Productos**.
2. El sistema muestra el catálogo con opción **Crear** para nuevos artículos.
3. El administrador diligencia nombre, categoría, precio, stock, descripción e imagen.
4. Para editar, el administrador selecciona un producto y modifica los campos necesarios (incluso solo el precio, sin cambiar la imagen).
5. El administrador confirma con **Guardar**.
6. El sistema actualiza el catálogo para todos los usuarios.

---

### 8.9 Aprobación de compras (administrador)

**Rol:** Administrador.

1. El administrador selecciona **Compras** en la barra inferior.
2. El sistema muestra pestañas **Pendientes** y **Todas**.
3. En pendientes, el administrador revisa producto, cantidad, comprador y total.
4. El administrador selecciona **Aprobar** o **Rechazar**.
5. Si aprueba, el sistema envía el código de entrega al correo del comprador y cambia el estado a aceptada.
6. Si rechaza, el sistema restaura el stock y notifica el rechazo al usuario.
7. El administrador puede **Habilitar compras** a usuarios que aún no tienen permiso de compra.

---

## 9. Mensajes y validaciones

| Mensaje / situación | Tipo | Acción recomendada |
|---------------------|------|-------------------|
| Registro exitoso / Cuenta verificada | Éxito | El usuario puede iniciar sesión. |
| Credenciales incorrectas | Error | Verificar correo y contraseña. |
| Campos obligatorios incompletos | Advertencia | Completar todos los campos marcados. |
| Correo ya registrado | Error | Usar otro correo o recuperar contraseña. |
| Reserva expirada | Advertencia | Volver a agregar el producto al carrito. |
| Compras no habilitadas | Restricción | Contactar al administrador. |
| Pendiente de aprobación | Informativo | Esperar respuesta del administrador. |
| Compra aceptada | Éxito | Revisar el correo para el código de entrega. |
| Compra rechazada | Informativo | El stock queda disponible nuevamente. |

---

## 10. Cierre de sesión

1. El usuario selecciona el icono de **Perfil** en la barra superior.
2. El usuario desplaza hasta la opción **Cerrar sesión**.
3. El usuario confirma la acción.
4. El sistema finaliza la sesión y regresa a la pantalla de inicio de sesión.

---

## 11. Preguntas frecuentes

| Pregunta | Respuesta |
|----------|-----------|
| ¿Por qué no puede solicitar una compra? | El correo debe estar verificado y el administrador debe tener habilitadas las compras para esa cuenta. |
| ¿Qué ocurre si no confirma la compra a tiempo? | La reserva del producto expira y el artículo se elimina del carrito. |
| ¿Cómo recibe el código de entrega? | El sistema lo envía al correo registrado cuando el administrador aprueba la compra. |
| ¿Puede editar un producto sin cambiar la imagen? | Sí; el administrador puede modificar solo precio, stock u otros campos. |
| ¿El catálogo se actualiza solo? | Sí; la aplicación sincroniza los productos periódicamente con el servidor. |

---

## 12. Soporte o contacto

| Dato | Información |
|------|-------------|
| Responsable | Equipo desarrollador Q-LESS — CBA |
| Correo | ortizgarciafelipe37@gmail.com |
| Repositorio | https://github.com/AnderFelipeOrtiz2004/Q-Less |
| Tipo de soporte | Orientación de uso, reporte de errores y solicitudes durante la etapa formativa |

---

## 13. Glosario

| Término | Definición |
|---------|------------|
| **Reserva** | Bloqueo temporal de stock mientras el producto permanece en el carrito. |
| **Orden / pedido** | Solicitud de compra registrada en el sistema. |
| **Código de entrega** | Número enviado por correo para retirar o confirmar el pedido aprobado. |
| **Administrador** | Usuario con permisos para gestionar productos y aprobar compras. |
| **Catálogo** | Listado de productos disponibles en la aplicación. |
| **Chatbot** | Asistente virtual que responde consultas sobre materiales y actividades. |

---

*Nota para la entrega académica: este documento debe copiarse a Word (Arial 11, márgenes 2,54 cm, interlineado 1,15) e incluir capturas de pantalla de la aplicación en cada sección de módulos, según las pautas institucionales.*
