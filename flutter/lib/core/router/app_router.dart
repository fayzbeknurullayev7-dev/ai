import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/home/presentation/pages/home_shell.dart';
import '../../features/splash/splash_page.dart';

/// Auth holati o'zgarganda routerni qayta baholash uchun `Listenable`.
/// (go_router `refreshListenable` Riverpod bilan shunday bog'lanadi.)
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: listenable,
    redirect: (ctx, state) {
      final isAuth = ref.read(authProvider).isAuthenticated;
      final loc = state.matchedLocation;
      final onSplash = loc == '/';
      final onAuthPage = loc == '/login' || loc == '/register';

      // Splash o'zini boshqaradi (animatsiyadan keyin yo'naltiradi).
      if (onSplash) return null;

      // Kirmagan foydalanuvchi — faqat auth sahifalari.
      if (!isAuth && !onAuthPage) return '/login';

      // Kirgan foydalanuvchi auth sahifasida — chatga.
      if (isAuth && onAuthPage) return '/chat';

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (ctx, state) => const LoginPage()),
      GoRoute(path: '/register', builder: (ctx, state) => const RegisterPage()),
      GoRoute(path: '/chat', builder: (ctx, state) => const HomeShell()),
    ],
  );
});
