/// Autentifikatsiyalangan foydalanuvchi (backend `/auth/me` va token javobiga mos).
class AuthUser {
  final String id;
  final String email;
  final String fullName;

  const AuthUser({
    required this.id,
    required this.email,
    this.fullName = '',
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: (json['full_name'] as String?) ?? '',
    );
  }
}
