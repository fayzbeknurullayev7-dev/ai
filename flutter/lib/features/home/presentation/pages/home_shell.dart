import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/presentation/pages/chat_page.dart';
import '../../../slides/presentation/slides_page.dart';
import '../../../video/presentation/video_page.dart';
import '../../chat_mode.dart';
import '../providers/home_mode_provider.dart';

/// Asosiy qobiq. Rejim (Chat · Rasm · Kod · Slayd · Video) `homeModeProvider`
/// orqali boshqariladi — pastki tab bar o'rniga chat input'dagi "..." tugmasi
/// ochadigan bottom sheet'dan tanlanadi.
///
/// Chat, Rasm va Kod rejimlari BITTA asosiy chat sahifasida ishlaydi
/// (`ChatPage`) — yuborilgan xabar joriy rejimga mos agentga ketadi, javob
/// (jumladan rasm) shu chat ichida ko'rsatiladi. Slayd va Video — alohida
/// sahifalar (.pptx yaratish / Kling AI video).
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(homeModeProvider);
    switch (mode) {
      case ChatMode.slides:
        return const SlidesPage();
      case ChatMode.video:
        return const VideoPage();
      case ChatMode.chat:
      case ChatMode.image:
      case ChatMode.code:
        // Chat holati provider'da saqlanadi — qayta qurilsa ham yo'qolmaydi.
        return const ChatPage();
    }
  }
}
