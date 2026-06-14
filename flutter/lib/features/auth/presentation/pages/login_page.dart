import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _rememberMe = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).login(
          email: _email.text.trim(),
          password: _password.text,
        );
    if (ok && mounted) context.go('/chat');
  }

  void _soon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label — tez orada'),
        backgroundColor: kAuthField,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Google bilan kirish hozircha tayyor emas — "Tez kunda" oynasi.
  void _googleSoon() => showComingSoonDialog(
        context,
        title: 'Google bilan kirish',
        message:
            'Bu funksiya tez kunda qo\'shiladi. Hozircha email va parol orqali kiring.',
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
                      // Logo + nom
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
                        'Access Your Chatbot AI\nAccount Now',
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
                        'Hisobingizga kirib, suhbatni davom ettiring',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kAuthMuted, fontSize: 14),
                      ).animate().fadeIn(delay: 250.ms),
                      const SizedBox(height: 32),
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
                        hint: 'Parol',
                        icon: Icons.lock_outline,
                        obscure: true,
                        textInputAction: TextInputAction.done,
                        validator: validatePassword,
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 12),
                      _RememberRow(
                        value: _rememberMe,
                        onChanged: (v) => setState(() => _rememberMe = v),
                        onForgot: () => _soon('Parolni tiklash'),
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
                        label: 'Login',
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
                            'Hisobingiz yo\'qmi? ',
                            style: TextStyle(color: kAuthMuted),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/register'),
                            child: const Text(
                              'Create an account',
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

/// "Remember me" checkbox + "Forget password?" havola qatori.
class _RememberRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onForgot;

  const _RememberRow({
    required this.value,
    required this.onChanged,
    required this.onForgot,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: value,
                    onChanged: (v) => onChanged(v ?? false),
                    activeColor: kAuthAccent,
                    checkColor: Colors.white,
                    side: const BorderSide(color: kAuthMuted, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Remember me',
                  style: TextStyle(color: kAuthMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: onForgot,
          child: const Text(
            'Forget password?',
            style: TextStyle(
              color: kAuthLink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
