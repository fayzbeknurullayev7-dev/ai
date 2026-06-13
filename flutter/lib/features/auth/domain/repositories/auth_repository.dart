import 'package:dartz/dartz.dart';
import '../entities/auth_user.dart';

/// Auth repozitoriy shartnomasi (domain qatlami). `Left` — xato xabari,
/// `Right` — muvaffaqiyatli foydalanuvchi. Token saqlash impl ichida bo'ladi.
abstract class AuthRepository {
  Future<Either<String, AuthUser>> register({
    required String email,
    required String password,
    String fullName = '',
  });

  Future<Either<String, AuthUser>> login({
    required String email,
    required String password,
  });

  Future<void> logout();

  /// Saqlangan tokendan joriy foydalanuvchini tiklaydi (yo'q bo'lsa null).
  AuthUser? currentUser();

  bool get isLoggedIn;
}
