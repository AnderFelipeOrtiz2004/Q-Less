import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';

/// Comprueba conectividad: Wi‑Fi local (demo XAMPP) o internet (producción).
class NetworkStatusService {
  NetworkStatusService._();

  static const String noWifiMessage =
      'Sin conexión. Activa Wi‑Fi o datos móviles.';

  static const String wifiNoServerMessage =
      'No se pudo conectar con el servidor. Intenta de nuevo en unos segundos.';

  static const String noInternetMessage =
      'Sin conexión a internet. Revisa tu red e intenta de nuevo.';

  static const String onlineServerMessage =
      'No se pudo conectar con el servidor en línea. Verifica que el backend esté activo.';

  static bool get _checkOnMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static Future<bool> hasWifi() async {
    if (!_checkOnMobile) return true;
    try {
      final results = await Connectivity().checkConnectivity();
      return results.contains(ConnectivityResult.wifi);
    } catch (_) {
      return true;
    }
  }

  static Future<bool> hasInternet() async {
    if (!_checkOnMobile && !kIsWeb) return true;
    try {
      final results = await Connectivity().checkConnectivity();
      return !results.contains(ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  static Future<bool> hasConnection() async {
    if (isOnlineApiMode) {
      return hasInternet();
    }
    return hasWifi();
  }

  static String get noConnectionMessage =>
      isOnlineApiMode ? noInternetMessage : noWifiMessage;

  static String get serverUnreachableMessage =>
      isOnlineApiMode ? onlineServerMessage : wifiNoServerMessage;
}
