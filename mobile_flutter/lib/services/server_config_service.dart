import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../config/api_config.dart';
import 'lan_server_discovery.dart';
import 'network_status_service.dart';

/// Local: busca XAMPP en la misma Wi‑Fi. Producción: usa API_BASE_URL con internet.
class ServerConfigService {
  ServerConfigService._();

  static const String _prefsKey = 'api_base_url';
  static String? _cachedUrl;
  static bool _finding = false;

  static String get currentBaseUrl => _cachedUrl ?? baseUrlFromEnv();

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final envUrl = normalizeApiBaseUrl(dotenv.env['API_BASE_URL']);

    if (isOnlineApiMode) {
      _cachedUrl = envUrl;
      await prefs.setString(_prefsKey, _cachedUrl!);
      return;
    }

    final saved = prefs.getString(_prefsKey)?.trim();

    if (_isDesktopPlatform) {
      _cachedUrl = (saved != null && saved.isNotEmpty)
          ? normalizeApiBaseUrl(saved)
          : kDefaultBaseUrl;
      if (_cachedUrl!.contains('192.168')) {
        _cachedUrl = kDefaultBaseUrl;
      }
      await prefs.setString(_prefsKey, _cachedUrl!);
      return;
    }

    if (saved != null && saved.isNotEmpty && !_isLocalhost(saved)) {
      _cachedUrl = normalizeApiBaseUrl(saved);
    }
  }

  static Future<bool> ensureConnectedOnMobile() async {
    if (_isDesktopPlatform || isOnlineApiMode) {
      if (!await NetworkStatusService.hasConnection()) {
        return false;
      }
      return _healthOk(currentBaseUrl);
    }

    if (!await NetworkStatusService.hasWifi()) {
      return false;
    }

    if (await _healthOk(currentBaseUrl)) {
      return true;
    }

    if (_finding) return false;
    _finding = true;
    try {
      final found = await LanServerDiscovery.discover();
      if (found != null) {
        await setBaseUrl(found);
        return true;
      }
      return await _healthOk(currentBaseUrl);
    } finally {
      _finding = false;
    }
  }

  static Future<bool> _healthOk(String base) async {
    try {
      final timeout = isOnlineApiMode
          ? const Duration(seconds: 25)
          : const Duration(seconds: 8);
      final response = await http
          .get(Uri.parse(apiUrl(base, 'health.php')))
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      return response.body.contains('"checks"');
    } catch (_) {
      return false;
    }
  }

  static bool _isLocalhost(String url) {
    final lower = url.toLowerCase();
    return lower.contains('127.0.0.1') || lower.contains('localhost');
  }

  static bool get _isDesktopPlatform {
    if (kIsWeb) return true;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  static Future<void> setBaseUrl(String url) async {
    _cachedUrl = normalizeApiBaseUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _cachedUrl!);
  }

  static Future<void> useLocalPcUrl() => setBaseUrl(kDefaultBaseUrl);

  static Future<ServerConnectionResult> testConnection() async {
    final ok = await ensureConnectedOnMobile();
    if (ok) {
      return const ServerConnectionResult(
        ok: true,
        message: 'Conexión correcta con el servidor.',
      );
    }
    return ServerConnectionResult(
      ok: false,
      message: NetworkStatusService.serverUnreachableMessage,
    );
  }
}

class ServerConnectionResult {
  final bool ok;
  final String message;

  const ServerConnectionResult({required this.ok, required this.message});
}
