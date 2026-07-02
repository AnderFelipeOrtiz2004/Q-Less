import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/fade_slide_entry.dart';

class ForgotPasswordPage extends StatefulWidget {
  final String? initialEmail;
  final String? initialCode;

  const ForgotPasswordPage({
    super.key,
    this.initialEmail,
    this.initialCode,
  });

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _codeSent = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!.trim();
    }
    if (widget.initialCode != null && widget.initialCode!.trim().isNotEmpty) {
      _codeController.text = widget.initialCode!.trim();
      _codeSent = true;
      _infoMessage =
          'Código recibido por correo. También puedes usar el enlace del email.';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _requestCode({bool resend = false}) async {
    final email = _emailController.text.trim();
    final emailError = AppValidators.validateEmail(email);
    if (emailError != null) {
      setState(() => _errorMessage = emailError);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final result = await AuthService.requestPasswordReset(
      email: email,
      resend: resend,
    );
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _codeSent = true;
        _infoMessage = result['message']?.toString() ??
            'Revisa tu correo. Abre el enlace o ingresa el código de 6 dígitos.';
      } else {
        _errorMessage = result['message']?.toString();
      }
    });
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    final emailError = AppValidators.validateEmail(email);
    if (emailError != null) {
      setState(() => _errorMessage = emailError);
      return;
    }
    if (code.length < 6) {
      setState(() => _errorMessage = 'Ingresa el código de 6 dígitos');
      return;
    }
    final passError = AppValidators.validatePassword(password);
    if (passError != null) {
      setState(() => _errorMessage = passError);
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Las contraseñas no coinciden');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.confirmPasswordReset(
      email: email,
      code: code,
      newPassword: password,
    );
    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Contraseña actualizada',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    setState(() => _errorMessage = result['message']?.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageBackground,
      appBar: AppBar(
        backgroundColor: kBrandGreen,
        foregroundColor: Colors.white,
        title: const Text('Recuperar contraseña'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FadeSlideEntry(
              child: Text(
                _codeSent
                    ? 'Revisa tu Gmail. Puedes abrir el enlace del correo o ingresar el código aquí.'
                    : 'Te enviaremos un código y un enlace para restablecer tu contraseña.',
                style: const TextStyle(fontSize: 15, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              enabled: !_codeSent,
              decoration: const InputDecoration(
                labelText: 'Correo Gmail',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Código de verificación',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar contraseña',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : () => _requestCode(resend: true),
                  child: const Text('Reenviar código'),
                ),
              ),
            ],
            if (_infoMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _infoMessage!,
                style: const TextStyle(color: kBrandGreenDark, fontSize: 14),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBrandGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: _isLoading
                    ? null
                    : (_codeSent ? _resetPassword : () => _requestCode()),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_codeSent ? 'Cambiar contraseña' : 'Enviar código'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
