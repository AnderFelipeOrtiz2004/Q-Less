# 🤖 Guía de Configuración - Chatbot Gemini para SENA

## ✅ Pasos de Configuración

### 1️⃣ **Instalar Dependencias**
```bash
flutter pub get
```

### 2️⃣ **Configurar Variables de Entorno**

**Archivo: `.env`** (en la raíz del proyecto)
```env
GEMINI_API_KEY=REEMPLAZA_POR_TU_API_KEY
```

⚠️ **IMPORTANTE**: 
- **Revoca la API Key que compartiste** (ya está comprometida)
- Crea una nueva en: https://aistudio.google.com/apikey
- Nunca commits el archivo `.env` a Git. Agrega a `.gitignore`:
  ```
  .env
  .env.local
  ```

### 3️⃣ **Actualizar pubspec.yaml**
Ya está configurado con:
- `google_generative_ai: ^0.4.0`
- `flutter_dotenv: ^5.1.0`

### 4️⃣ **Inicializar flutter_dotenv en main.dart**
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: '.env');
  runApp(const QLessApp());
}
```

---

## 📋 Estructura de Archivos Creados

```
lib/
├── services/
│   └── chatbot_service.dart          # Servicio principal del chatbot
├── pages/
│   └── chatbot_screen.dart           # Interfaz del chat
└── main.dart                          # Inicialización (ACTUALIZADO)

.env                                   # Variables de entorno (NO hacer commit)
```

---

## 🧠 Características del Chatbot

### ✨ Function Calling (Tools)
El chatbot tiene integrada la función `verificarStock()`:
- **Propósito**: Verificar disponibilidad real de materiales
- **Activación**: Cuando el usuario pregunta por materiales
- **Respuesta**: Cantidad disponible o "agotado"

### 📚 Sistema de Prompts Personalizado
- Tono amable y motivador
- Especializado en proyectos escolares y maquetas
- Respuestas formateadas con emojis y estructura clara
- Enfocado en la comunidad SENA

### 💾 Inventario Simulado
Ejemplo de materiales disponibles:
- Cartulina: 150 pliegos
- Marcadores: 500 unidades
- Pegamento: 80 frascos
- Pintura acrílica: 120 botes
- *...y más*

Para usar una **base de datos real**, reemplaza `_handleVerificarStock()` con llamadas a tu API backend.

---

## 🚀 Cómo Usar en tu Aplicación

### Opción 1: Agregar a HomePage
```dart
ElevatedButton(
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ChatbotScreen(),
      ),
    );
  },
  child: const Text('Ir al Asistente de Proyectos'),
)
```

### Opción 2: Crear Tab en TabBar
```dart
TabBarView(
  children: [
    // ...otras tabs...
    const ChatbotScreen(),
  ],
)
```

---

## 🔧 Personalización

### Cambiar el Modelo
En `chatbot_service.dart`:
```dart
_model = GenerativeModel(
  model: 'gemini-2.0-flash',  // Cambiar a otro modelo
  apiKey: apiKey,
  ...
);
```

### Actualizar el Prompt del Sistema
En `chatbot_service.dart`, edita `systemInstruction`:
```dart
systemInstruction: Content.text(
  '''Tu nuevo prompt aquí...''',
),
```

### Agregar Más Herramientas (Tools)
```dart
Tool(
  functionDeclarations: [
    FunctionDeclaration(
      name: 'nombreFuncion',
      description: 'Descripción...',
      parameters: Schema(...),
    ),
  ],
)
```

---

## 🛡️ Seguridad - Checklist

- [ ] ✅ Revocaste la API Key comprometida
- [ ] ✅ Creaste una nueva API Key
- [ ] ✅ `.env` está en `.gitignore`
- [ ] ✅ No hiciste push de `.env` a Git
- [ ] ✅ Cambiaste `GEMINI_API_KEY` en el archivo `.env` por tu clave real

---

## 📝 Ejemplos de Uso

### Usuario pregunta por materiales:
```
Usuario: ¿Tenemos cartulina disponible?
Bot: ✅ DISPONIBILIDAD CONFIRMADA
     Material: cartulina
     Stock: 150 pliegos
     Estado: Disponible en la papelería
```

### Usuario pide una guía:
```
Usuario: ¿Cómo hago una maqueta del sistema solar?
Bot: 📋 MATERIALES NECESARIOS:
     - Cartulina (1 pliego)
     - Marcadores (5 colores)
     - Pegamento (1 frasco)
     - Esferas de telgopor
     ...
     ⏱️ TIEMPO ESTIMADO: 4-5 horas
     📝 PASOS:
     1. Recorta la cartulina...
     ...
```

---

## 🐛 Troubleshooting

| Problema | Solución |
|----------|----------|
| `API key not found` | Verifica `.env` y que `dotenv.load()` sea async en main |
| `Model not found` | Asegúrate de que el modelo existe en Gemini API |
| `Function call not working` | El modelo puede ignorar tools; usa instrucciones claras en el prompt |
| Stock siempre dice "no disponible" | Verifica que el nombre del material coincida en el inventario |

---

## 📚 Recursos

- [Google Generative AI Dart](https://pub.dev/packages/google_generative_ai)
- [Flutter Dotenv](https://pub.dev/packages/flutter_dotenv)
- [Gemini API Documentation](https://ai.google.dev/tutorials/dart_quickstart)
- [Function Calling Guide](https://ai.google.dev/docs/function_calling)

---

**Creado para la comunidad del SENA 🎓**
