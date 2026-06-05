import 'package:flutter_dotenv/flutter_dotenv.dart';

const String kDefaultBaseUrl = 'http://127.0.0.1/q-less/';

const Duration apiTimeout = Duration(seconds: 20);
const Duration apiUploadTimeout = Duration(seconds: 60);

String apiUrl(String base, String path) {
  final normalizedBase = base.replaceAll(RegExp(r'/+$'), '');
  final normalizedPath = path.replaceFirst(RegExp(r'^/+'), '');
  return '$normalizedBase/$normalizedPath';
}

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

String baseUrlFromEnv() => normalizeApiBaseUrl(dotenv.env['API_BASE_URL']);
