import 'package:flutter/material.dart';

import '../services/server_config_service.dart';

class SplashGate extends StatefulWidget {
  final Widget child;

  const SplashGate({super.key, required this.child});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  static const Color _splashGreen = Color(0xFF76C11F);

  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    await ServerConfigService.ensureConnectedOnMobile();
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: _splashGreen,
          body: Center(
            child: Image(
              image: AssetImage('assets/images/icon_ql.png'),
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }
    return widget.child;
  }
}
