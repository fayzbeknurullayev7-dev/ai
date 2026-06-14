import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/presentation/pages/chat_page.dart';
import '../../../chat/presentation/widgets/chat_colors.dart';
import '../../chat_mode.dart';
import '../providers/home_mode_provider.dart';
import 'coming_soon_page.dart';
import 'mode_chat_page.dart';

/// Asosiy qobiq. Rejim (Chat · Rasm · Kod · Slayd · Video) `homeModeProvider`
/// orqali boshqariladi — pastki tab bar o'rniga chat input'dagi "..." tugmasi
/// ochadigan bottom sheet'dan tanlanadi.
///
/// Sahifalar holati `IndexedStack` orqali saqlanadi (rejim almashganda suhbat
/// yo'qolmaydi).
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _modes = ChatMode.values; // chat, image, code, slides, video

  Widget _pageFor(ChatMode mode) => switch (mode) {
        ChatMode.chat => const ChatPage(),
        ChatMode.image => const ModeChatPage(mode: ChatMode.image),
        ChatMode.code => const ModeChatPage(mode: ChatMode.code),
        ChatMode.slides => const ComingSoonPage(mode: ChatMode.slides),
        ChatMode.video => const ComingSoonPage(mode: ChatMode.video),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(homeModeProvider);
    return Scaffold(
      backgroundColor: ChatColors.bg,
      body: IndexedStack(
        index: mode.index,
        children: [for (final m in _modes) _pageFor(m)],
      ),
    );
  }
}
