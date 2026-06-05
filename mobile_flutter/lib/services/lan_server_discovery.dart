import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Encuentra el PC con XAMPP en la misma red Wi‑Fi (sin configurar IP a mano).
class LanServerDiscovery {
  LanServerDiscovery._();

  static const Duration _probeTimeout = Duration(milliseconds: 600);
  static const int _batchSize = 48;

  static Future<String?> discover() async {
    if (kIsWeb || !_isMobile) return null;

    final prefixes = await _subnetPrefixes();
    for (final prefix in prefixes) {
      final url = await _scanPrefix(prefix);
      if (url != null) return url;
    }

    if (Platform.isAndroid) {
      return _probeHost('10.0.2.2');
    }
    return null;
  }

  static bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  static Future<List<String>> _subnetPrefixes() async {
    final ordered = <String>[];
    final seen = <String>{};

    void add(String? prefix) {
      if (prefix == null || prefix.isEmpty || !seen.add(prefix)) return;
      ordered.add(prefix);
    }

    final localIp = await _deviceLanIp();
    if (localIp != null) {
      final parts = localIp.split('.');
      if (parts.length == 4) {
        add('${parts[0]}.${parts[1]}.${parts[2]}');
      }
    }

    for (final p in ['192.168.1', '192.168.0', '192.168.40', '192.168.137', '10.0.0']) {
      add(p);
    }
    return ordered;
  }

  static Future<String?> _deviceLanIp() async {
    try {
      for (final iface in await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      )) {
        for (final addr in iface.addresses) {
          if (_isPrivateIp(addr.address)) return addr.address;
        }
      }
    } catch (_) {}
    return null;
  }

  static bool _isPrivateIp(String ip) {
    if (ip.startsWith('192.168.')) return true;
    if (ip.startsWith('10.')) return true;
    if (ip.startsWith('172.')) {
      final n = int.tryParse(ip.split('.')[1]) ?? 0;
      return n >= 16 && n <= 31;
    }
    return false;
  }

  static Future<String?> _scanPrefix(String prefix) async {
    return _scanPrefixSequentialBatched(_probeOrder(prefix));
  }

  static Future<String?> _scanPrefixSequentialBatched(List<String> hosts) async {
    for (var i = 0; i < hosts.length; i += _batchSize) {
      final end = i + _batchSize > hosts.length ? hosts.length : i + _batchSize;
      final futures = hosts.sublist(i, end).map(_probeHost);
      final results = await Future.wait(futures);
      for (final url in results) {
        if (url != null) return url;
      }
    }
    return null;
  }

  static List<String> _probeOrder(String prefix) {
    final priority = [1, 2, 10, 20, 50, 100, 150, 200, 254];
    final seen = <int>{};
    final hosts = <String>[];
    for (final n in priority) {
      if (seen.add(n)) hosts.add('$prefix.$n');
    }
    for (var n = 1; n <= 254; n++) {
      if (seen.add(n)) hosts.add('$prefix.$n');
    }
    return hosts;
  }

  static Future<String?> _probeHost(String host) async {
    final healthUrl = apiUrl('http://$host/q-less/', 'health.php');
    try {
      final response =
          await http.get(Uri.parse(healthUrl)).timeout(_probeTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      if (!_isQlessHealth(response.body)) return null;
      return normalizeApiBaseUrl('http://$host/q-less/');
    } catch (_) {
      return null;
    }
  }

  static bool _isQlessHealth(String body) {
    try {
      final data = jsonDecode(body);
      return data is Map && data.containsKey('checks');
    } catch (_) {
      return false;
    }
  }
}
