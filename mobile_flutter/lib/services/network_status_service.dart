import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Comprueba si el dispositivo tiene Wi‑Fi (sin escanear servidores).
class NetworkStatusService {
  NetworkStatusService._();

  static const String noWifiMessage =
      'No hay red WiFi disponible. Conéctate a la misma red que el PC con XAMPP.';

  static const String wifiNoServerMessage =
      'No funcionó la conexión WiFi con el servidor. Enciende XAMPP (Apache y MySQL) en el PC, misma red Wi‑Fi, y permite Apache en el firewall.';

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
}
