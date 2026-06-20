import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/index.dart';
import '../services/sound_service.dart';
import '../services/user_service.dart';
import '../utils/image_utils.dart';
import '../utils/transition_utils.dart';
import '../widgets/index.dart';
import '../widgets/server_url_panel.dart';
import 'edit_profile_page.dart';
import 'my_purchases_page.dart';
import 'products_page.dart';

class ProfilePage extends StatefulWidget {
  final int? userId;
  final String? userName;
  final String userEmail;
  final String userRole;
  final bool showLogout;

  const ProfilePage({
    super.key,
    this.userId,
    this.userName,
    this.userEmail = 'usuario@q-less.com',
    this.userRole = 'aprendiz',
    this.showLogout = false,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? _user;
  bool _isLoading = true;
  String? _errorMessage;
  bool _soundsEnabled = true;

  bool get _canEdit => widget.showLogout && widget.userId != null;

  bool get _showServerPanel {
    if (kIsWeb) return true;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadSoundPreference();
  }

  Future<void> _loadSoundPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _soundsEnabled = prefs.getBool('ui_sounds_enabled') ?? true;
      SoundService.setEnabled(_soundsEnabled);
    });
  }

  Future<void> _toggleSounds(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ui_sounds_enabled', value);
    SoundService.setEnabled(value);
    if (value) SoundService.playClick();
    setState(() => _soundsEnabled = value);
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF3EC13B)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color? color,
  }) {
    return FadeSlideEntry(
      child: InteractiveScaleButton(
        onTap: onTap == null
            ? null
            : () {
                SoundService.playNavigate();
                onTap();
              },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6EEE6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: color ?? const Color(0xFF3EC13B)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color ?? Colors.black87,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadUser() async {
    if (widget.userId == null) {
      setState(() {
        _errorMessage = 'Usuario no disponible';
        _isLoading = false;
      });
      return;
    }

    try {
      final user = await UserService.fetchUser(userId: widget.userId!);
      if (!mounted) return;
      setState(() {
        _user = user;
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _user = User(
          id: widget.userId.toString(),
          nombre: widget.userName ?? 'Usuario',
          correo: widget.userEmail.isNotEmpty
              ? widget.userEmail
              : 'usuario@q-less.com',
          role: widget.userRole,
        );
        _errorMessage =
            'No se pudo conectar con el servidor. Mostrando datos locales.';
        _isLoading = false;
      });
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final avatarPath = _user?.avatarPath ?? '';
    final avatarUrl = _user?.avatarUrl ?? '';
    if (avatarPath.isNotEmpty || avatarUrl.isNotEmpty) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
        child: CircleAvatar(
          key: ValueKey<String>('path-$avatarUrl$avatarPath'),
          radius: 52,
          backgroundColor: const Color(0xFF3EC13B),
          child: ClipOval(
            child: buildProductImage(
              avatarPath,
              avatarUrl.isNotEmpty ? avatarUrl : avatarPath,
              fit: BoxFit.cover,
              width: 104,
              height: 104,
              placeholder: const Icon(Icons.person, color: Colors.white, size: 64),
            ),
          ),
        ),
      );
    }

    final initials = (_user?.nombre.isNotEmpty == true ? _user!.nombre[0].toUpperCase() : 'U');
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
      child: CircleAvatar(
        key: ValueKey<String>('initials-$initials'),
        radius: 52,
        backgroundColor: const Color(0xFF3EC13B),
        child: Text(
          initials,
          style: const TextStyle(fontSize: 40, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF3EC13B),
        title: const Text('Perfil', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3EC13B)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: _buildAvatar()),
                      const SizedBox(height: 18),
                      Center(
                        child: Text(
                          _user?.nombre ?? widget.userName ?? 'Usuario',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          widget.userEmail.isNotEmpty
                              ? widget.userEmail
                              : _user?.correo ?? 'usuario@q-less.com',
                          style: const TextStyle(fontSize: 15, color: Colors.black54),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Chip(
                            label: Text(_user?.role ?? widget.userRole),
                            backgroundColor: const Color(0xFFEBF8ED),
                            avatar: const Icon(Icons.verified_user, color: Color(0xFF3EC13B)),
                          ),
                          const SizedBox(width: 12),
                          const Chip(
                            avatar: Icon(Icons.check_circle, color: Colors.white),
                            label: Text('Activo'),
                            backgroundColor: Color(0xFF3EC13B),
                            labelStyle: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_user?.description?.isNotEmpty == true) ...[
                        const Text('Descripción', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(_user!.description!, style: const TextStyle(fontSize: 14)),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Text(
                        'Miembro desde ${_user?.createdAt != null ? '${_user!.createdAt!.year}-${_user!.createdAt!.month.toString().padLeft(2, '0')}-${_user!.createdAt!.day.toString().padLeft(2, '0')}' : '---'}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 24),
                      _sectionTitle('Mi cuenta', Icons.person_outline),
                      if (_canEdit)
                        _actionTile(
                          icon: Icons.edit_outlined,
                          label: 'Editar perfil',
                          onTap: () async {
                            SoundService.playEdit();
                            final result = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (context) => EditProfilePage(
                                  userId: widget.userId!,
                                  initialUser: _user,
                                ),
                              ),
                            );
                            if (result == true && mounted) _loadUser();
                          },
                        ),
                      _sectionTitle('Tienda', Icons.storefront_outlined),
                      _actionTile(
                        icon: Icons.inventory_2_outlined,
                        label: 'Ver productos',
                        onTap: widget.userId == null
                            ? null
                            : () => Navigator.of(context).push(
                                  fadeSlideRoute(
                                    ProductsPage(
                                      userId: widget.userId!,
                                      userRole: widget.userRole,
                                    ),
                                  ),
                                ),
                      ),
                      _actionTile(
                        icon: Icons.shopping_bag_outlined,
                        label: 'Mis compras',
                        onTap: widget.userId == null
                            ? null
                            : () => Navigator.of(context).push(
                                  fadeSlideRoute(
                                    MyPurchasesPage(
                                      userId: widget.userId!,
                                      userName: widget.userName ?? 'Usuario',
                                    ),
                                  ),
                                ),
                      ),
                      _sectionTitle('Preferencias', Icons.tune_outlined),
                      FadeSlideEntry(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE6EEE6)),
                          ),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _soundsEnabled,
                            activeThumbColor: const Color(0xFF3EC13B),
                            title: const Text(
                              'Sonidos de la app',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text(
                              'Clic, navegación, compra y edición',
                              style: TextStyle(fontSize: 12),
                            ),
                            secondary: const Icon(
                              Icons.volume_up_outlined,
                              color: Color(0xFF3EC13B),
                            ),
                            onChanged: _toggleSounds,
                          ),
                        ),
                      ),
                      if (_showServerPanel) ...[
                        _sectionTitle('Conexión', Icons.dns_outlined),
                        const ServerUrlPanel(),
                        const SizedBox(height: 12),
                      ],
                      if (widget.showLogout) ...[
                        _sectionTitle('Sesión', Icons.logout),
                        _actionTile(
                          icon: Icons.logout,
                          label: 'Cerrar sesión',
                          color: Colors.red,
                          onTap: _showLogoutDialog,
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4E5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFFC46B)),
                          ),
                          child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFF7A4B00))),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}