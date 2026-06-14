import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_colors.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/typing_indicator.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Chiqish', style: TextStyle(color: ChatColors.text)),
        content: const Text(
          'Hisobingizdan chiqmoqchimisiz?',
          style: TextStyle(color: ChatColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor qilish',
                style: TextStyle(color: ChatColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Chiqish',
                style: TextStyle(color: Color(0xFFE11D48))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    ref.read(chatProvider.notifier).clearChat();
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    final user = ref.watch(authProvider).user;

    // Yangi xabar/oqim kelganda pastga skroll.
    ref.listen(chatProvider, (_, __) => _autoScroll());

    return Scaffold(
      backgroundColor: ChatColors.bg,
      drawer: _ChatDrawer(
        userEmail: user?.email ?? '',
        userName: user?.fullName ?? '',
        plannerMode: state.plannerMode,
        onNewChat: () {
          ref.read(chatProvider.notifier).clearChat();
          Navigator.pop(context);
        },
        onTogglePlanner: () =>
            ref.read(chatProvider.notifier).togglePlannerMode(),
        onLogout: () {
          Navigator.pop(context);
          _logout();
        },
      ),
      appBar: AppBar(
        backgroundColor: ChatColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: ChatColors.text),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.view_sidebar_outlined),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
            tooltip: 'Menyu',
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nexus AI',
              style: TextStyle(
                color: ChatColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (state.plannerMode) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ChatColors.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PLANNER',
                  style: TextStyle(
                    color: ChatColors.accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _ProfileAvatar(
              name: user?.fullName ?? '',
              email: user?.email ?? '',
              onLogout: _logout,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.messages.isEmpty
                ? _EmptyState(
                    onSuggestion: (text) =>
                        ref.read(chatProvider.notifier).sendMessage(text),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    itemCount:
                        state.messages.length + (state.isLoading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == state.messages.length) {
                        return const TypingIndicator();
                      }
                      return MessageBubble(
                        message: state.messages[i],
                        onRetry: () => ref.read(chatProvider.notifier).retry(),
                      );
                    },
                  ),
          ),
          ChatInput(
            isStreaming: state.isStreaming,
            plannerMode: state.plannerMode,
            onSend: (text) => ref.read(chatProvider.notifier).sendMessage(text),
            onStop: () => ref.read(chatProvider.notifier).stopStream(),
            onTogglePlanner: () =>
                ref.read(chatProvider.notifier).togglePlannerMode(),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 10, top: 2),
            child: Text(
              'AI can make mistakes. Please double-check responses.',
              style: TextStyle(color: ChatColors.muted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bo'sh holat: markazda savol + taklif chiplari.
class _EmptyState extends StatelessWidget {
  final void Function(String) onSuggestion;
  const _EmptyState({required this.onSuggestion});

  static const _suggestions = [
    ('Python\'da kod yoz', Icons.code),
    ('Rasmni tahlil qil', Icons.image_outlined),
    ('G\'oya ber', Icons.lightbulb_outline),
    ('Matnni tarjima qil', Icons.translate),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'What can I help with?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ChatColors.text,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final (label, icon) in _suggestions)
                  _SuggestionChip(
                    label: label,
                    icon: icon,
                    onTap: () => onSuggestion(label),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: ChatColors.bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: ChatColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: ChatColors.accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: ChatColors.text,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Profil avatari — bosilganda menyu (email + chiqish).
class _ProfileAvatar extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback onLogout;

  const _ProfileAvatar({
    required this.name,
    required this.email,
    required this.onLogout,
  });

  String get _initial {
    final src = name.trim().isNotEmpty ? name.trim() : email.trim();
    return src.isNotEmpty ? src[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        if (v == 'logout') onLogout();
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (name.trim().isNotEmpty)
                Text(
                  name,
                  style: const TextStyle(
                    color: ChatColors.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              Text(
                email,
                style: const TextStyle(
                    color: ChatColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: Color(0xFFE11D48)),
              SizedBox(width: 10),
              Text('Chiqish', style: TextStyle(color: Color(0xFFE11D48))),
            ],
          ),
        ),
      ],
      child: CircleAvatar(
        radius: 16,
        backgroundColor: ChatColors.accent,
        child: Text(
          _initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// Yon menyu (sidebar): yangi chat, planner rejimi, chiqish.
class _ChatDrawer extends StatelessWidget {
  final String userEmail;
  final String userName;
  final bool plannerMode;
  final VoidCallback onNewChat;
  final VoidCallback onTogglePlanner;
  final VoidCallback onLogout;

  const _ChatDrawer({
    required this.userEmail,
    required this.userName,
    required this.plannerMode,
    required this.onNewChat,
    required this.onTogglePlanner,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: ChatColors.bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [ChatColors.accent, Color(0xFF6C63FF)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Nexus AI',
                    style: TextStyle(
                      color: ChatColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: ChatColors.border, height: 1),
            ListTile(
              leading: const Icon(Icons.add_comment_outlined,
                  color: ChatColors.text),
              title: const Text('Yangi suhbat',
                  style: TextStyle(color: ChatColors.text)),
              onTap: onNewChat,
            ),
            SwitchListTile(
              value: plannerMode,
              onChanged: (_) => onTogglePlanner(),
              activeThumbColor: ChatColors.accent,
              secondary: Icon(
                plannerMode ? Icons.account_tree : Icons.account_tree_outlined,
                color: plannerMode ? ChatColors.accent : ChatColors.text,
              ),
              title: const Text('Planner rejimi',
                  style: TextStyle(color: ChatColors.text)),
              subtitle: const Text(
                'Tool + xotira bilan reja tuzish',
                style: TextStyle(color: ChatColors.textSecondary, fontSize: 12),
              ),
            ),
            const Spacer(),
            const Divider(color: ChatColors.border, height: 1),
            ListTile(
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: ChatColors.accent,
                child: Text(
                  (userName.trim().isNotEmpty
                          ? userName.trim()
                          : (userEmail.isNotEmpty ? userEmail : '?'))[0]
                      .toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
              title: Text(
                userName.trim().isNotEmpty ? userName : userEmail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ChatColors.text, fontSize: 14),
              ),
              subtitle: userName.trim().isNotEmpty
                  ? Text(
                      userEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: ChatColors.textSecondary, fontSize: 12),
                    )
                  : null,
              trailing: IconButton(
                icon: const Icon(Icons.logout, color: Color(0xFFE11D48)),
                onPressed: onLogout,
                tooltip: 'Chiqish',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
