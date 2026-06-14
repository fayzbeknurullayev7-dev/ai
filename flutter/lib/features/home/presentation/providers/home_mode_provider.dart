import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat_mode.dart';

/// Joriy tanlangan rejim (Chat · Rasm · Kod · Slayd · Video).
///
/// Avval pastki tab bar bilan boshqarilardi; endi rejim chat input'dagi "..."
/// tugmasi orqali ochiladigan bottom sheet'dan tanlanadi. `HomeShell` shu
/// provider'ni kuzatib, mos sahifani ko'rsatadi.
final homeModeProvider =
    StateProvider<ChatMode>((ref) => ChatMode.chat);
