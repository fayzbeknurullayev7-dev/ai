import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../chat/presentation/widgets/chat_colors.dart';
import '../../chat_mode.dart';
import '../widgets/mode_picker_sheet.dart';

/// Hali tayyor bo'lmagan tablar (Slayd, Video) uchun "Tez kunda" sahifasi.
class ComingSoonPage extends ConsumerWidget {
  final ChatMode mode;
  const ComingSoonPage({super.key, required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ChatColors.bg,
      appBar: AppBar(
        backgroundColor: ChatColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: ChatColors.text),
        title: Text(
          mode.label,
          style: const TextStyle(
            color: ChatColors.text,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            tooltip: 'Rejimni tanlash',
            onPressed: () => showModePickerSheet(context, ref),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: ChatColors.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(mode.activeIcon, size: 40, color: ChatColors.accent),
            ),
            const SizedBox(height: 24),
            Text(
              mode.label,
              style: const TextStyle(
                color: ChatColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: ChatColors.accentSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Tez kunda',
                style: TextStyle(
                  color: ChatColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Bu imkoniyat ustida ish olib borilmoqda.\nYaqin orada foydalanishingiz mumkin bo\'ladi.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ChatColors.textSecondary, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
