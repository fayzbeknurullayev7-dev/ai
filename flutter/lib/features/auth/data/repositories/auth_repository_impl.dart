import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Backend `/auth/*` endpointlari bilan ishlaydi va tokenni [TokenStorage]
/// orqali saqlaydi. Backend javobi: { user: {...}, token: { access_token } }.
class AuthRepositoryImpl implements AuthRepository {
  final Dio _dio;
  final TokenStorage _storage;

  AuthRepositoryImpl(this._dio, this._storage);

  @override
  bool get isLoggedIn => _storage.isLoggedIn;

  @override
  AuthUser? currentUser() {
    final id = _storage.userId;
    final email = _storage.email;
    if (!_storage.isLoggedIn || id == null || email == null) return null;
    return AuthUser(id: id, email: email, fullName: _storage.fullName ?? '');
  }

  @override
  Future<Either<String, AuthUser>> register({
    required String email,
    required String password,
    String fullName = '',
  }) {
    return _authCall(ApiConstants.registerEndpoint, {
      'email': email,
      'password': password,
      'full_name': fullName,
    });
  }

  @override
  Future<Either<String, AuthUser>> login({
    required String email,
    required String password,
  }) {
    return _authCall(ApiConstants.loginEndpoint, {
      'email': email,
      'password': password,
    });
  }

  @override
  Future<void> logout() => _storage.clear();

  Future<Either<String, AuthUser>> _authCall(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      // So'rovdan oldin: qaysi endpointga, qanday body bilan ketayotganini logga yozamiz.
      // Parol logda chiqmasligi uchun maskalaymiz. Faqat debug rejimda ko'rinadi.
      final maskedBody = {
        ...body,
        if (body.containsKey('password')) 'password': '***',
      };
      debugPrint('[AuthRepository] → POST $endpoint body=$maskedBody');

      final resp = await _dio.post(endpoint, data: body);

      // So'rovdan keyin: status kod va javobni logga yozamiz.
      debugPrint(
        '[AuthRepository] ← ${resp.statusCode} $endpoint data=${resp.data}',
      );

      final data = resp.data as Map<String, dynamic>;
      final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
      final token = (data['token'] as Map<String, dynamic>)['access_token'] as String;
      await _storage.save(
        token: token,
        userId: user.id,
        email: user.email,
        fullName: user.fullName,
      );
      return Right(user);
    } on DioException catch (e) {
      debugPrint(
        '[AuthRepository] ✗ DioException $endpoint '
        'status=${e.response?.statusCode} data=${e.response?.data}',
      );
      return Left(_friendlyError(e));
    } catch (e) {
      debugPrint('[AuthRepository] ✗ Kutilmagan xato $endpoint: $e');
      return Left('Kutilmagan xato: $e');
    }
  }

  String _friendlyError(DioException e) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      // 422 (validation) — detail ro'yxat bo'lishi mumkin.
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) return first['msg'].toString();
      }
      return detail.toString();
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'So\'rov vaqti tugadi — server javob bermayapti.';
      case DioExceptionType.connectionError:
        return 'Serverga ulanib bo\'lmadi. Internetni tekshiring.';
      default:
        return 'Server xatosi${code != null ? ' ($code)' : ''}.';
    }
  }
}
