import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/presentation/pages/chat_page.dart';
import '../../chat_mode.dart';
import '../providers/home_mode_provider.dart';
import 'coming_soon_page.dart';

/// Asosiy qobiq. Rejim (Chat · Rasm · Kod · Slayd · Video) `homeModeProvider`
/// orqali boshqariladi — pastki tab bar o'rniga chat input'dagi "..." tugmasi
/// ochadigan bottom sheet'dan tanlanadi.
///
/// Chat, Rasm va Kod rejimlari BITTA asosiy chat sahifasida ishlaydi
/// (`ChatPage`) — yuborilgan xabar joriy rejimga mos agentga ketadi, javob
/// (jumladan rasm) shu chat ichida ko'rsatiladi. Slayd/Video hozircha
/// "tez kunda" sahifasi.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(homeModeProvider);
    if (mode.isComingSoon) {
      return ComingSoonPage(mode: mode);
    }
    // Chat holati provider'da saqlanadi — widget qayta qurilsa ham yo'qolmaydi.
    return const ChatPage();
  }
}
