import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/index.dart';
import '../services/user_service.dart';
import '../services/sound_service.dart';
import '../utils/image_utils.dart';

class EditProfilePage extends StatefulWidget {
  final int userId;
  final User? initialUser;

  const EditProfilePage({
    super.key,
    required this.userId,
    this.initialUser,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  User? _user;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  Uint8List? _avatarBytes;
  String? _avatarFileName;

  @override
  void initState() {
    super.initState();
    if (widget.initialUser != null) {
      _user = widget.initialUser;
      _nameController.text = _user!.nombre;
      _descriptionController.text = _user!.description ?? '';
    } else {
      _loadUser();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await UserService.fetchUser(userId: widget.userId);
      if (!mounted) return;
      setState(() {
        _user = user;
        _nameController.text = user.nombre;
        _descriptionController.text = user.description ?? '';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _user = User(
          id: widget.userId.toString(),
          nombre: 'Usuario',
          correo: 'usuario@q-less.com',
        );
        _nameController.text = _user!.nombre;
        _errorMessage =
            'No se pudo conectar con el servidor. Puedes editar, pero guardar requiere conexion.';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _avatarBytes = bytes;
        _avatarFileName = picked.name;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo seleccionar la imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre no puede estar vacio'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    String? avatarBase64;
    if (_avatarBytes != null) {
      avatarBase64 = 'data:image/png;base64,${base64Encode(_avatarBytes!)}';
    }

    try {
      final response = await UserService.updateProfile(
        userId: widget.userId,
        nombre: name,
        description: description,
        avatarBase64: avatarBase64,
        avatarFileName: _avatarFileName,
      );

      if (!mounted) return;

      if (response['status'] == 'success' && response['data'] != null) {
        final updatedUser = User.fromJson(response['data'] as Map<String, dynamic>);
        setState(() {
          _user = updatedUser;
          _avatarBytes = null;
          _avatarFileName = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        final message = response['message'] ?? 'Error al actualizar el perfil';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo guardar. Revisa que el backend este activo.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildAvatar() {
    if (_avatarBytes != null) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
        child: CircleAvatar(
          key: ValueKey<String>('bytes-${_avatarBytes!.length}'),
          radius: 52,
          backgroundColor: const Color(0xFF3EC13B),
          child: ClipOval(
            child: Image.memory(
              _avatarBytes!,
              fit: BoxFit.cover,
              width: 104,
              height: 104,
            ),
          ),
        ),
      );
    }

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
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Editar Perfil'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: InkWell(
                      onTap: _pickAvatar,
                      borderRadius: BorderRadius.circular(80),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          _buildAvatar(),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(6),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Color(0xFF3EC13B),
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Nombre',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'Tu nombre',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF3EC13B), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF3EC13B), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Descripcion (opcional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Cuentanos sobre ti',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFBEECC6), width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF3EC13B), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              SoundService.playClick();
                              _saveProfile();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3EC13B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Guardar Cambios',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {
                        SoundService.playClick();
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        side: const BorderSide(
                          color: Color(0xFF3EC13B),
                          width: 2,
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Color(0xFF3EC13B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
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
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFF7A4B00)),
                      ),
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
