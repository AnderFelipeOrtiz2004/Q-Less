/// Model representing a User in the Q-Less system
class User {
  final String id;
  final String nombre;
  final String correo;
  final String role;
  final String? password;
  final String? avatarPath;
  final String? avatarUrl;
  final String? description;
  final DateTime? createdAt;
  final bool emailVerified;
  final bool purchasesEnabled;

  User({
    required this.id,
    required this.nombre,
    required this.correo,
    this.role = 'aprendiz',
    this.password,
    this.avatarPath,
    this.avatarUrl,
    this.description,
    this.createdAt,
    this.emailVerified = true,
    this.purchasesEnabled = false,
  });

  /// Convert User to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'correo': correo,
      'role': role,
      if (password != null) 'password': password,
      if (avatarPath != null) 'avatar_path': avatarPath,
      if (description != null) 'description': description,
    };
  }

  /// Create User from JSON response
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] ?? '').toString(),
      nombre: (json['nombre'] ?? json['name'] ?? '').toString(),
      correo: (json['correo'] ?? json['email'] ?? '').toString(),
      role: (json['role'] ?? json['rol'] ?? 'aprendiz').toString(),
      password: json['password']?.toString(),
      avatarPath: json['avatar_path']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      description: json['description']?.toString(),
      createdAt: json['created_at'] != null && (json['created_at'] ?? '') != ''
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      emailVerified: json['email_verified'] == true || json['email_verified'] == 1,
      purchasesEnabled:
          json['purchases_enabled'] == true || json['purchases_enabled'] == 1,
    );
  }

  bool get isAdmin => role.toLowerCase() == 'admin';
}
