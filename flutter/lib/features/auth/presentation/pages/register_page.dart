import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).register(
          email: _email.text.trim(),
          password: _password.text,
          fullName: _fullName.text.trim(),
        );
    if (ok && mounted) context.go('/chat');
  }

  /// Google bilan ro'yxatdan o'tish hozircha tayyor emas — "Tez kunda" oynasi.
  void _googleSoon() => showComingSoonDialog(
        context,
        title: 'Google bilan davom etish',
        message:
            'Bu funksiya tez kunda qo\'shiladi. Hozircha email va parol orqali ro\'yxatdan o\'ting.',
      );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [kAuthAccent, kAuthAccent2],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: kAuthAccent.withValues(alpha: 0.4),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.auto_awesome,
                                color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Nexus AI',
                            style: TextStyle(
                              color: kAuthText,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      )
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .slideY(begin: -0.2, curve: Curves.easeOut),
                      const SizedBox(height: 40),
                      const Text(
                        'Create Your Chatbot AI\nAccount Now',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          color: kAuthText,
                        ),
                      ).animate().fadeIn(delay: 150.ms),
                      const SizedBox(height: 8),
                      const Text(
                        'Nexus AI bilan ishlashni boshlang',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kAuthMuted, fontSize: 14),
                      ).animate().fadeIn(delay: 250.ms),
                      const SizedBox(height: 32),
                      AuthTextField(
                        controller: _fullName,
                        hint: 'To\'liq ism (ixtiyoriy)',
                        icon: Icons.person_outline,
                        keyboardType: TextInputType.name,
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        controller: _email,
                        hint: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: validateEmail,
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        controller: _password,
                        hint: 'Parol (kamida 6 belgi)',
                        icon: Icons.lock_outline,
                        obscure: true,
                        textInputAction: TextInputAction.done,
                        validator: validatePassword,
                        onSubmitted: (_) => _submit(),
                      ),
                      if (state.error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          state.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 24),
                      AuthButton(
                        label: 'Create account',
                        isLoading: state.isLoading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 24),
                      const OrDivider(label: 'Or continue with'),
                      const SizedBox(height: 20),
                      Center(
                        child: GoogleSignInButton(onTap: _googleSoon),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Hisobingiz bormi? ',
                            style: TextStyle(color: kAuthMuted),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: const Text(
                              'Login',
                              style: TextStyle(
                                color: kAuthLink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
