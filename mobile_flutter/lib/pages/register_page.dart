import 'package:flutter/material.dart';
import '../config/legal_terms.dart';
import '../services/index.dart';
import '../services/sound_service.dart';
import '../utils/validators.dart';
import '../widgets/app_text_field.dart';
import '../widgets/legal_terms_dialog.dart';

/// Registration page with form validation and API integration
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  bool _isLoading = false;
  bool _needsVerification = false;
  bool _acceptedTerms = false;
  String _errorMessage = '';
  String _selectedRole = 'aprendiz';

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final result = await AuthService.verifyEmail(
      correo: _correoController.text.trim(),
      code: _codeController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Correo verificado'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _errorMessage = result['message']?.toString() ?? 'Código inválido';
    });
  }

  Future<void> _handleResendCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final result = await AuthService.resendVerificationCode(
      correo: _correoController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? 'Código reenviado'),
        backgroundColor: result['success'] == true ? Colors.green : Colors.orange,
      ),
    );
  }

  Future<void> _handleRegister() async {
    SoundService.playClick();
    setState(() {
      _errorMessage = '';
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptedTerms) {
      setState(() {
        _errorMessage =
            'Debes aceptar los Términos y la Política de Privacidad para continuar.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final termsOk = await showLegalTermsDialog(context);
    if (!termsOk || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se creó la cuenta. Debes aceptar los términos legales.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await AuthService.registerUser(
        nombre: _nombreController.text,
        correo: _correoController.text,
        password: _passwordController.text,
        role: _selectedRole,
        acceptedTerms: true,
        privacyVersion: LegalTerms.version,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        SoundService.playSuccess();
        final needsVerification =
            response['data']?['needs_verification'] == true;

        if (needsVerification) {
          setState(() {
            _needsVerification = true;
            _errorMessage = '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message']?.toString() ??
                    'Revisa tu Gmail e ingresa el código de verificación.',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta creada. Inicia sesión.'),
            backgroundColor: Colors.green,
          ),
        );
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Error desconocido';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.30,
              decoration: const BoxDecoration(
                color: Color(0xFF3EC13B),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Crear Cuenta',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  SizedBox(height: 16),
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white24,
                    child: Icon(
                      Icons.person_add,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Únete a Q-LESS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    AppTextField(
                      controller: _nombreController,
                      label: 'Nombre Completo',
                      hintText: 'Juan Pérez García',
                      prefixIcon: Icons.person,
                      validator: AppValidators.validateName,
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      controller: _correoController,
                      label: 'Correo Electrónico',
                      hintText: 'tu@gmail.com',
                      readOnly: _needsVerification,
                      prefixIcon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: AppValidators.validateEmail,
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      controller: _passwordController,
                      label: 'Contraseña',
                      hintText: 'Mínimo 6 caracteres',
                      prefixIcon: Icons.lock,
                      obscureText: true,
                      showPasswordToggle: true,
                      validator: AppValidators.validatePassword,
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirmar Contraseña',
                      hintText: 'Repite tu contraseña',
                      prefixIcon: Icons.lock_outline,
                      obscureText: true,
                      showPasswordToggle: true,
                      validator: (value) {
                        return AppValidators.validatePasswordConfirm(
                          value,
                          _passwordController.text,
                        );
                      },
                    ),
                    if (!_needsVerification) ...[
                      const SizedBox(height: 12),
                      const Text('Rol'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRole,
                        items: const [
                          DropdownMenuItem(value: 'aprendiz', child: Text('Aprendiz')),
                          DropdownMenuItem(value: 'instructor', child: Text('Instructor')),
                        ],
                        onChanged: (v) => setState(() => _selectedRole = v ?? 'aprendiz'),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _acceptedTerms,
                        onChanged: (value) {
                          setState(() => _acceptedTerms = value == true);
                        },
                        title: const Text(
                          'Acepto los Términos y la Política de Privacidad de Q-LESS.',
                          style: TextStyle(fontSize: 13),
                        ),
                        subtitle: const Text(
                          'Obligatorio antes de enviar el código a tu Gmail.',
                          style: TextStyle(fontSize: 12),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ],
                    if (_needsVerification) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Enviamos un código a ${_correoController.text.trim()}',
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _codeController,
                        label: 'Código de verificación Gmail',
                        hintText: '6 dígitos',
                        prefixIcon: Icons.verified_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _handleResendCode,
                          child: const Text('Reenviar código'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3EC13B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        onPressed: _isLoading
                            ? null
                            : (_needsVerification ? _handleVerifyEmail : _handleRegister),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _needsVerification ? 'Verificar correo' : 'Crear Cuenta',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(
                            color: Color(0xFF3EC13B),
                            width: 2,
                          ),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.of(context).pop();
                              },
                        child: const Text(
                          'Volver al Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3EC13B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
