import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
  );
});

/// Auth holati: yuklanmoqdami, xato bormi, kim kirgan.
class AuthState {
  final bool isLoading;
  final String? error;
  final AuthUser? user;

  const AuthState({this.isLoading = false, this.error, this.user});

  bool get isAuthenticated => user != null;

  AuthState copyWith({bool? isLoading, String? error, AuthUser? user}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  final Ref _ref;

  AuthNotifier(this._repo, this._ref)
      : super(AuthState(user: _repo.currentUser())) {
    // 401 signali kelganda — sessiyani tozalaymiz (token eskirgan/yaroqsiz).
    _ref.listen(unauthorizedSignalProvider, (prev, next) {
      if (next > 0 && state.user != null) {
        logout();
      }
    });
  }

  Future<bool> register({
    required String email,
    required String password,
    String fullName = '',
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repo.register(
      email: email,
      password: password,
      fullName: fullName,
    );
    return _handle(result);
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repo.login(email: email, password: password);
    return _handle(result);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }

  bool _handle(result) {
    return result.fold(
      (error) {
        state = AuthState(isLoading: false, error: error);
        return false;
      },
      (user) {
        state = AuthState(isLoading: false, user: user);
        return true;
      },
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider), ref);
});
