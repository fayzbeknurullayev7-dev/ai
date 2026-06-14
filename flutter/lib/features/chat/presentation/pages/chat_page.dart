import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/chat_mode.dart';
import '../../../home/presentation/providers/home_mode_provider.dart';
import '../../../home/presentation/widgets/mode_picker_sheet.dart';
import '../../domain/entities/conversation.dart';
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
    final mode = ref.watch(homeModeProvider);

    // Yangi xabar/oqim kelganda pastga skroll.
    ref.listen(chatProvider, (_, __) => _autoScroll());

    return Scaffold(
      backgroundColor: ChatColors.bg,
      drawer: _ChatDrawer(
        userEmail: user?.email ?? '',
        userName: user?.fullName ?? '',
        plannerMode: state.plannerMode,
        conversations: state.conversations,
        activeId: state.activeId,
        onNewChat: () {
          ref.read(chatProvider.notifier).newChat();
          Navigator.pop(context);
        },
        onSelectConversation: (id) {
          ref.read(chatProvider.notifier).loadConversation(id);
          Navigator.pop(context);
        },
        onDeleteConversation: (id) =>
            ref.read(chatProvider.notifier).deleteConversation(id),
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
            // Joriy rejim belgisi (Chat'dan boshqa bo'lsa: RASM / KOD).
            if (mode != ChatMode.chat) ...[
              const SizedBox(width: 8),
              _ModeBadge(mode: mode),
            ],
            if (mode == ChatMode.chat && state.plannerMode) ...[
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
                    mode: mode,
                    onSuggestion: (text) => ref
                        .read(chatProvider.notifier)
                        .sendMessage(text, mode: mode.sendMode),
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
            hint: mode == ChatMode.chat ? 'Ask anything' : mode.inputHint,
            showPlanner: mode == ChatMode.chat,
            onSend: (text) => ref
                .read(chatProvider.notifier)
                .sendMessage(text, mode: mode.sendMode),
            onStop: () => ref.read(chatProvider.notifier).stopStream(),
            onTogglePlanner: () =>
                ref.read(chatProvider.notifier).togglePlannerMode(),
            onMore: () => showModePickerSheet(context, ref),
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

/// Bo'sh holat: markazda savol + taklif chiplari (joriy rejimga moslashadi).
class _EmptyState extends StatelessWidget {
  final ChatMode mode;
  final void Function(String) onSuggestion;
  const _EmptyState({required this.mode, required this.onSuggestion});

  static const _chatSuggestions = [
    ('G\'oya ber', Icons.lightbulb_outline),
    ('Matnni tarjima qil', Icons.translate),
    ('Savol ber', Icons.help_outline),
    ('Reja tuz', Icons.checklist_outlined),
  ];

  String get _title => switch (mode) {
        ChatMode.chat => 'What can I help with?',
        _ => mode.emptyTitle,
      };

  List<(String, IconData)> get _suggestions => switch (mode) {
        ChatMode.chat => _chatSuggestions,
        _ => mode.suggestions,
      };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (mode != ChatMode.chat) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: ChatColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(mode.activeIcon,
                    size: 32, color: ChatColors.accent),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              _title,
              textAlign: TextAlign.center,
              style: const TextStyle(
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

/// App bar'dagi joriy rejim belgisi (RASM / KOD).
class _ModeBadge extends StatelessWidget {
  final ChatMode mode;
  const _ModeBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: ChatColors.accentSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(mode.activeIcon, size: 11, color: ChatColors.accent),
          const SizedBox(width: 4),
          Text(
            mode.label.toUpperCase(),
            style: const TextStyle(
              color: ChatColors.accent,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
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

/// Yon menyu (sidebar): yangi chat, suhbatlar tarixi, planner rejimi, chiqish.
class _ChatDrawer extends StatelessWidget {
  final String userEmail;
  final String userName;
  final bool plannerMode;
  final List<Conversation> conversations;
  final String? activeId;
  final VoidCallback onNewChat;
  final void Function(String id) onSelectConversation;
  final void Function(String id) onDeleteConversation;
  final VoidCallback onTogglePlanner;
  final VoidCallback onLogout;

  const _ChatDrawer({
    required this.userEmail,
    required this.userName,
    required this.plannerMode,
    required this.conversations,
    required this.activeId,
    required this.onNewChat,
    required this.onSelectConversation,
    required this.onDeleteConversation,
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
            const Divider(color: ChatColors.border, height: 1),
            // Suhbatlar tarixi ro'yxati (saqlangan, eng yangisi tepada).
            Expanded(
              child: conversations.isEmpty
                  ? const _EmptyHistory()
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 8, 20, 6),
                          child: Text(
                            'Suhbatlar tarixi',
                            style: TextStyle(
                              color: ChatColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        for (final c in conversations)
                          _ConversationTile(
                            conversation: c,
                            active: c.id == activeId,
                            onTap: () => onSelectConversation(c.id),
                            onDelete: () =>
                                _confirmDelete(context, c, onDeleteConversation),
                          ),
                      ],
                    ),
            ),
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

  /// Suhbatni o'chirishdan oldin tasdiq oynasi.
  void _confirmDelete(
    BuildContext context,
    Conversation c,
    void Function(String id) onDelete,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Suhbatni o\'chirish',
            style: TextStyle(color: ChatColors.text)),
        content: Text(
          '"${c.title}" suhbati o\'chirilsinmi?',
          style: const TextStyle(color: ChatColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor qilish',
                style: TextStyle(color: ChatColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('O\'chirish',
                style: TextStyle(color: Color(0xFFE11D48))),
          ),
        ],
      ),
    );
    if (ok == true) onDelete(c.id);
  }
}

/// Tarix bo'sh bo'lganda ko'rsatiladigan holat.
class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, color: ChatColors.muted, size: 36),
            SizedBox(height: 12),
            Text(
              'Suhbatlar tarixi bo\'sh',
              textAlign: TextAlign.center,
              style: TextStyle(color: ChatColors.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sidebar'dagi bitta suhbat qatori (sarlavha + o'chirish tugmasi).
class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ConversationTile({
    required this.conversation,
    required this.active,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: active ? ChatColors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          Icons.chat_bubble_outline,
          size: 18,
          color: active ? ChatColors.accent : ChatColors.textSecondary,
        ),
        title: Text(
          conversation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: active ? ChatColors.accent : ChatColors.text,
            fontSize: 13.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          color: ChatColors.muted,
          tooltip: 'O\'chirish',
          visualDensity: VisualDensity.compact,
          onPressed: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }
}
