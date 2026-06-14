import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/presentation/pages/chat_page.dart';
import '../../../chat/presentation/widgets/chat_colors.dart';
import '../../chat_mode.dart';
import 'coming_soon_page.dart';
import 'mode_chat_page.dart';

/// Asosiy qobiq: pastdan tab bar (Chat · Rasm · Kod · Slayd · Video).
/// Har bir tab o'z sahifasiga ega; holat `IndexedStack` orqali saqlanadi.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _tabs = ChatMode.values; // chat, image, code, slides, video

  Widget _pageFor(ChatMode mode) => switch (mode) {
        ChatMode.chat => const ChatPage(),
        ChatMode.image => const ModeChatPage(mode: ChatMode.image),
        ChatMode.code => const ModeChatPage(mode: ChatMode.code),
        ChatMode.slides => const ComingSoonPage(mode: ChatMode.slides),
        ChatMode.video => const ComingSoonPage(mode: ChatMode.video),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatColors.bg,
      body: IndexedStack(
        index: _index,
        children: [for (final mode in _tabs) _pageFor(mode)],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: ChatColors.bg,
          border: Border(top: BorderSide(color: ChatColors.border)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: ChatColors.bg,
            indicatorColor: ChatColors.accentSoft,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? ChatColors.accent : ChatColors.textSecondary,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                color: selected ? ChatColors.accent : ChatColors.textSecondary,
                size: 24,
              );
            }),
          ),
          child: NavigationBar(
            height: 64,
            selectedIndex: _index,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              for (final mode in _tabs)
                NavigationDestination(
                  icon: Icon(mode.icon),
                  selectedIcon: Icon(mode.activeIcon),
                  label: mode.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
