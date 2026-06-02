/// Configuración centralizada de constantes de la aplicación
/// Usar 127.0.0.1 evita timeouts de localhost→IPv6 en Windows.
const String BASE_URL = 'http://127.0.0.1/q-less/';

const Duration apiTimeout = Duration(seconds: 20);
const Duration apiUploadTimeout = Duration(seconds: 60);

/// Une base URL y ruta sin doble barra (p. ej. .../q-less/login.php).
String apiUrl(String base, String path) {
  final normalizedBase = base.replaceAll(RegExp(r'/+$'), '');
  final normalizedPath = path.replaceFirst(RegExp(r'^/+'), '');
  return '$normalizedBase/$normalizedPath';
}

const String STORAGE_URL = '${BASE_URL}storage/';
const String PRODUCTS_STORAGE = '${STORAGE_URL}products/';
const String AVATARS_STORAGE = '${STORAGE_URL}avatars/';
