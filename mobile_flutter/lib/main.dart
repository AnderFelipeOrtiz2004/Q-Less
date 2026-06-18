import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'providers/carrito_provider.dart';
import 'pages/index.dart';
import 'services/chatbot_service.dart';
import 'services/auth_service.dart';
import 'services/server_config_service.dart';
import 'services/sound_service.dart';
import 'theme/app_theme.dart';
import 'utils/transition_utils.dart';
import 'widgets/fade_slide_entry.dart';
import 'widgets/interactive_scale_button.dart';
import 'widgets/splash_gate.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // Keep the app usable even when the local .env asset is missing.
  }

  await ServerConfigService.init();

  ChatbotService.instance.init();

  // 🌟 SOLUCIÓN AQUÍ: Envolvemos la app con el Provider para que esté disponible globalmente
  runApp(
    ChangeNotifierProvider(
      create: (context) => CarritoProvider(),
      child: const SplashGate(child: QLessApp()),
    ),
  );
}

class QLessApp extends StatelessWidget {
  const QLessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Q-LESS',
      theme: buildAppTheme(),
      home: const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _navigateHome(dynamic user, String fallbackEmail) async {
    final userName = user?.nombre ?? 'Usuario';
    final userId = int.tryParse(user?.id ?? '') ?? 0;
    final userRole = user?.role ?? 'aprendiz';
    final userEmail = user?.correo ?? fallbackEmail;
    final purchasesEnabled = user?.purchasesEnabled == true;

    if (userId <= 0) {
      setState(() {
        _errorMessage = 'Sesión inválida. Vuelve a iniciar sesión.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Provider.of<CarritoProvider>(context, listen: false)
        .inicializarCarrito(userId: userId);

    Navigator.of(context).pushReplacement(
      fadeSlideRoute(
        HomePage(
          userId: userId,
          userName: userName,
          userEmail: userEmail,
          userRole: userRole,
          purchasesEnabled: purchasesEnabled || userRole == 'admin',
        ),
      ),
    );
  }

  Future<void> _submitLogin() async {
    SoundService.playClick();
    setState(() {
      _errorMessage = '';
    });

    final correo = _userController.text.trim();
    final password = _passwordController.text;

    if (correo.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor completa todos los campos';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await AuthService.loginUser(
        correo: correo,
        password: password,
      );

      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sesión iniciada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          await _navigateHome(response['user'], correo);
        } else {
          final code = response['code']?.toString() ?? '';
          setState(() {
            _errorMessage = response['message'] ?? 'Error desconocido';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorMessage),
              backgroundColor: Colors.red,
            ),
          );

          if (code == 'user_not_found' && mounted) {
            final goRegister = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Cuenta no encontrada'),
                content: const Text(
                  'No existe una cuenta con ese correo Gmail. ¿Quieres registrarte?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Registrarme'),
                  ),
                ],
              ),
            );
            if (goRegister == true && mounted) {
              Navigator.of(context).push(fadeSlideRoute(const RegisterPage()));
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: ${e.toString()}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    SoundService.playClick();
    setState(() {
      _errorMessage = '';
      _isGoogleLoading = true;
    });

    try {
      final googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile'],
      );

      final account = await googleSignIn.signIn();
      if (account == null) {
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('No se pudo obtener el token de Google');
      }

      final response = await AuthService.loginWithGoogle(idToken: idToken);
      if (!mounted) return;

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión iniciada con Google'),
            backgroundColor: Colors.green,
          ),
        );
        await _navigateHome(response['user'], account.email);
      } else {
        setState(() {
          _errorMessage =
              response['message']?.toString() ?? 'No se pudo iniciar con Google';
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
        _errorMessage = 'Error con Google: ${e.toString()}';
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
          _isGoogleLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final headerHeight = MediaQuery.of(context).size.height * 0.30;

    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            FadeSlideEntry(
              duration: const Duration(milliseconds: 520),
              child: Container(
                width: double.infinity,
                height: headerHeight,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [kBrandGreen, kBrandGreenDark],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(36),
                    bottomRight: Radius.circular(36),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Q-LESS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.85, end: 1),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) {
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.white24,
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 76,
                            height: 76,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.storefront,
                              size: 44,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                children: [
                  FadeSlideEntry(
                    duration: const Duration(milliseconds: 420),
                    verticalOffset: 14,
                    child: TextField(
                    controller: _userController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.mail_outline),
                      hintText: 'Correo Gmail',
                    ),
                  ),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideEntry(
                    duration: const Duration(milliseconds: 480),
                    verticalOffset: 14,
                    child: TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline),
                      hintText: 'Contraseña',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Olvidaste tu contraseña?',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeSlideEntry(
                    duration: const Duration(milliseconds: 540),
                    verticalOffset: 12,
                    child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3EC13B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: _isLoading ? null : _submitLogin,
                      onLongPress: () => SoundService.playClick(),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Inicia sesión',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideEntry(
                    duration: const Duration(milliseconds: 560),
                    verticalOffset: 10,
                    child: Row(
                      children: const [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'o continúa con',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideEntry(
                    duration: const Duration(milliseconds: 560),
                    verticalOffset: 10,
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: (_isLoading || _isGoogleLoading)
                            ? null
                            : _loginWithGoogle,
                        icon: _isGoogleLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.g_mobiledata, size: 28),
                        label: const Text('Iniciar sesión con Google'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideEntry(
                    duration: const Duration(milliseconds: 580),
                    verticalOffset: 10,
                    child: InteractiveScaleButton(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      SoundService.playClick();
                      Navigator.of(context).push(
                        fadeSlideRoute(const RegisterPage()),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Color(0xFFE0E4E0)),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Crear una cuenta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}