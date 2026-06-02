import 'package:flutter_dotenv/flutter_dotenv.dart';

/// URL por defecto en PC/emulador (127.0.0.1 evita timeout IPv6 de localhost en Windows).
const String kDefaultBaseUrl = 'http://127.0.0.1/q-less/';

const Duration apiTimeout = Duration(seconds: 20);
const Duration apiUploadTimeout = Duration(seconds: 60);

/// Une base URL y ruta sin doble barra (p. ej. .../q-less/login.php).
String apiUrl(String base, String path) {
  final normalizedBase = base.replaceAll(RegExp(r'/+$'), '');
  final normalizedPath = path.replaceFirst(RegExp(r'^/+'), '');
  return '$normalizedBase/$normalizedPath';
}

/// Normaliza API_BASE_URL del .env (quita /backend si viene de plantillas viejas).
String normalizeApiBaseUrl(String? configuredUrl) {
  if (configuredUrl == null || configuredUrl.trim().isEmpty) {
    return kDefaultBaseUrl;
  }
  var url = configuredUrl.trim();
  url = url.replaceAll(RegExp(r'/backend/?$'), '');
  if (url.endsWith('/backend')) {
    url = url.substring(0, url.length - '/backend'.length);
  }
  url = url.replaceAll('/backend/', '/');
  return url.endsWith('/') ? url : '$url/';
}

/// URL del backend XAMPP. En el teléfono debe ser la IP LAN del PC, no 127.0.0.1.
String getBaseUrl() => normalizeApiBaseUrl(dotenv.env['API_BASE_URL']);

String get storageUrl => '${getBaseUrl()}storage/';
String get productsStorageUrl => '${storageUrl}products/';
String get avatarsStorageUrl => '${storageUrl}avatars/';
