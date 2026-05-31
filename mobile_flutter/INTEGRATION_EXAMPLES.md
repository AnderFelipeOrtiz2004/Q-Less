# 📚 Guía Práctica: Cómo Integrar el ChatbotScreen

## OPCIÓN 1: Desde HomePage

En `lib/pages/home_page.dart`, agrega un botón:

```dart
ElevatedButton.icon(
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ChatbotScreen(),
      ),
    );
  },
  icon: const Icon(Icons.smart_toy),
  label: const Text('Asistente de Proyectos'),
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF3EC13B),
  ),
)
```

## OPCIÓN 2: Como un Tab

En tu `TabController`, agrega:

```dart
DefaultTabController(
  length: 3,
  child: Scaffold(
    appBar: AppBar(
      bottom: const TabBar(
        tabs: [
          Tab(text: 'Inicio'),
          Tab(text: 'Mis Proyectos'),
          Tab(text: 'Asistente'),
        ],
      ),
    ),
    body: TabBarView(
      children: [
        HomePage(userId: userId, userName: userName, userRole: userRole),
        ProjectsPage(),
        const ChatbotScreen(),  // ← Agregar aquí
      ],
    ),
  ),
)
```

## OPCIÓN 3: Floating Action Button

En tu `Scaffold`:

```dart
floatingActionButton: FloatingActionButton.extended(
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ChatbotScreen(),
      ),
    );
  },
  icon: const Icon(Icons.chat),
  label: const Text('Asistente IA'),
  backgroundColor: const Color(0xFF3EC13B),
)
```

## Usar ChatbotService Directamente

Si quieres usar el servicio sin la UI de ChatbotScreen:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/chatbot_service.dart';

class MiServicio {
  late ChatbotService _chatbot;

  Future<void> inicializarChatbot() async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    _chatbot = ChatbotService(apiKey: apiKey!);
  }

  Future<String> obtenerRespuesta(String pregunta) async {
    return await _chatbot.sendMessage(pregunta);
  }

  void limpiarChat() {
    _chatbot.resetChat();
  }
}
```

## Personalizar Respuestas

Para cambiar el comportamiento de verificación de stock, edita en `lib/services/chatbot_service.dart` el método `_handleVerificarStock()`.

Ejemplo: Conectar con tu API backend:

```dart
String _handleVerificarStock(String material) {
  try {
    final response = await http.post(
      Uri.parse('https://tu-api.com/stock/verificar'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'material': material}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return '✅ ${data['material']}: ${data['cantidad']} ${data['unidad']}';
    }
  } catch (e) {
    return '❌ Error consultando stock: $e';
  }
}
```

## Debuggear Mensajes

Agrega logs en `chatbot_service.dart`:

```dart
Future<String> sendMessage(String userMessage) async {
  print('📤 Usuario: $userMessage');
  try {
    final userContent = Content.text(userMessage);
    final response = await _chatSession.sendMessage(userContent);
    final result = _processResponse(response);
    print('📥 Asistente: $result');
    return result;
  } catch (e) {
    print('❌ Error: ${e.toString()}');
    return 'Error al procesar tu mensaje: ${e.toString()}';
  }
}
```
