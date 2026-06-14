import 'package:flutter/material.dart';

// Aurora AI auth palitrasi (dark, ko'k-binafsha urg'u).
const kAuthAccent = Color(0xFF3B82F6); // asosiy ko'k tugma
const kAuthAccent2 = Color(0xFF6C63FF); // gradient binafsha urg'u
const kAuthLink = Color(0xFF60A5FA); // havola ranggi
const kAuthField = Color(0xFF141A2B); // input foni
const kAuthFieldBorder = Color(0xFF222A3F); // input chegarasi
const kAuthText = Color(0xFFE8EAF0);
const kAuthHint = Color(0xFF6B7280);
const kAuthMuted = Color(0xFF8892A4);

/// Auth ekranlari uchun umumiy matn maydoni.
/// `obscure: true` bo'lsa — ko'rish/yashirish (eye) tugmasi avtomatik chiqadi.
class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final void Function(String)? onSubmitted;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      style: const TextStyle(color: kAuthText, fontSize: 15),
      cursorColor: kAuthAccent,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(color: kAuthHint),
        prefixIcon: Icon(widget.icon, color: kAuthMuted, size: 20),
        suffixIcon: widget.obscure
            ? IconButton(
                icon: Icon(
                  _hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: kAuthMuted,
                  size: 20,
                ),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
        filled: true,
        fillColor: kAuthField,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kAuthFieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kAuthFieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kAuthAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }
}

/// Auth ekranlari uchun asosiy ko'k gradient tugma — loading holatini ko'rsatadi.
class AuthButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const AuthButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [kAuthAccent, kAuthAccent2],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kAuthAccent.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

/// "Or continue with" tipidagi matnli ajratuvchi chiziq.
class OrDivider extends StatelessWidget {
  final String label;
  const OrDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    const line = Expanded(child: Divider(color: kAuthFieldBorder, height: 1));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(color: kAuthMuted, fontSize: 12),
          ),
        ),
        line,
      ],
    );
  }
}

/// Google bilan kirish/davom etish tugmasi (keng, ikonali pill).
/// Hozircha OAuth tayyor emas — bosilganda "Tez kunda" oynasi chiqadi.
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback onTap;
  const GoogleSignInButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: kAuthField,
          foregroundColor: kAuthText,
          side: const BorderSide(color: kAuthFieldBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const _GoogleGlyph(),
        label: const Text(
          'Google bilan davom etish',
          style: TextStyle(
            color: kAuthText,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// "G" harfi — Google brendi ranglarisiz, neytral oq doira ichida.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// "Tez kunda" ma'lumot oynasi (OAuth va boshqa kelajak funksiyalar uchun).
Future<void> showComingSoonDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kAuthField,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          const Icon(Icons.rocket_launch_outlined, color: kAuthAccent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: kAuthText,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(color: kAuthMuted, fontSize: 14, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          style: TextButton.styleFrom(foregroundColor: kAuthLink),
          child: const Text('Tushunarli',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

/// Ijtimoiy tarmoq orqali kirish tugmasi (yumaloq, ikonali).
class SocialButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const SocialButton({super.key, required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 64,
        height: 52,
        decoration: BoxDecoration(
          color: kAuthField,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kAuthFieldBorder),
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// Aurora uslubidagi qorong'u ko'k gradient fon + yumshoq yog'du dog'lari.
class AuroraBackground extends StatelessWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0E1A), Color(0xFF0C1326), Color(0xFF080B14)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: _glow(const Color(0xFF3B82F6), 320),
          ),
          Positioned(
            top: -60,
            right: -100,
            child: _glow(const Color(0xFF6C63FF), 280),
          ),
          Positioned(
            bottom: -140,
            right: -60,
            child: _glow(const Color(0xFF2563EB), 300),
          ),
          child,
        ],
      ),
    );
  }

  Widget _glow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }
}

/// Email uchun oddiy validator (backend regex bilan mos).
String? validateEmail(String? v) {
  final value = (v ?? '').trim();
  if (value.isEmpty) return 'Email kiriting';
  final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!re.hasMatch(value)) return 'Email formati noto\'g\'ri';
  return null;
}

/// Parol validatori (backend: min 6 belgi).
String? validatePassword(String? v) {
  final value = v ?? '';
  if (value.isEmpty) return 'Parol kiriting';
  if (value.length < 6) return 'Parol kamida 6 ta belgi bo\'lsin';
  return null;
}
