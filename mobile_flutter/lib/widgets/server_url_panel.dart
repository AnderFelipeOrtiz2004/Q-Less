import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/server_config_service.dart';
import '../theme/app_theme.dart';

/// Solo para pruebas en PC; en móvil no se muestra.
class ServerUrlPanel extends StatefulWidget {
  const ServerUrlPanel({super.key});

  @override
  State<ServerUrlPanel> createState() => _ServerUrlPanelState();
}

class _ServerUrlPanelState extends State<ServerUrlPanel> {
  final _urlController = TextEditingController();
  bool _expanded = false;
  bool _testing = false;
  String? _statusMessage;
  bool? _lastOk;

  @override
  void initState() {
    super.initState();
    _urlController.text = ServerConfigService.currentBaseUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _statusMessage = null;
    });
    await ServerConfigService.setBaseUrl(_urlController.text);
    final result = await ServerConfigService.testConnection();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _statusMessage = result.message;
      _lastOk = result.ok;
      _urlController.text = ServerConfigService.currentBaseUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _expanded = !_expanded),
          icon: Icon(_expanded ? Icons.expand_less : Icons.settings_ethernet),
          label: Text(
            _expanded ? 'Ocultar servidor' : 'Configurar servidor (PC)',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (_expanded) ...[
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'URL del servidor',
              hintText: 'http://127.0.0.1/q-less/',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _testing ? null : _test,
            style: FilledButton.styleFrom(backgroundColor: kBrandGreen),
            child: _testing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Probar conexión'),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _statusMessage!,
              style: TextStyle(
                fontSize: 13,
                color: _lastOk == true ? Colors.green[800] : Colors.red[800],
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
