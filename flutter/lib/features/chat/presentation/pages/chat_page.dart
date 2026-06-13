import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/typing_indicator.dart';

class ChatPage extends ConsumerWidget {
  const ChatPage({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B25),
        title: const Text('Chiqish',
            style: TextStyle(color: Color(0xFFE8EAF0))),
        content: const Text(
          'Hisobingizdan chiqmoqchimisiz?',
          style: TextStyle(color: Color(0xFF8892A4)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor qilish',
                style: TextStyle(color: Color(0xFF8892A4))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Chiqish',
                style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // Chatni tozalab, sessiyani yopamiz — router avtomatik /login'ga olib boradi.
    ref.read(chatProvider.notifier).clearChat();
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF6C63FF), size: 20),
            const SizedBox(width: 8),
            const Text('Nexus AI'),
            if (state.plannerMode) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PLANNER',
                  style: TextStyle(
                    color: Color(0xFF8B85FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Oqim ketayotganda — "To'xtatish" tugmasi (boshqa amallar yashiriladi).
          if (state.isStreaming)
            TextButton.icon(
              onPressed: () => ref.read(chatProvider.notifier).stopStream(),
              icon: const Icon(Icons.stop_circle_outlined,
                  color: Color(0xFFFF6B6B), size: 20),
              label: const Text(
                'To\'xtatish',
                style: TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else ...[
            IconButton(
              icon: Icon(
                state.plannerMode
                    ? Icons.account_tree
                    : Icons.account_tree_outlined,
                color: state.plannerMode
                    ? const Color(0xFF6C63FF)
                    : const Color(0xFF8892A4),
              ),
              onPressed: () =>
                  ref.read(chatProvider.notifier).togglePlannerMode(),
              tooltip: state.plannerMode
                  ? 'Planner rejimi yoqilgan (tool + xotira)'
                  : 'Planner rejimini yoqish',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => ref.read(chatProvider.notifier).clearChat(),
              tooltip: 'Chatni tozalash',
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Color(0xFF8892A4)),
              onPressed: () => _logout(context, ref),
              tooltip: 'Chiqish',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.messages.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.messages.length +
                        (state.isLoading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == state.messages.length) {
                        return const TypingIndicator();
                      }
                      return MessageBubble(
                        message: state.messages[i],
                        onRetry: () =>
                            ref.read(chatProvider.notifier).retry(),
                      );
                    },
                  ),
          ),
          ChatInput(
            onSend: (text) =>
                ref.read(chatProvider.notifier).sendMessage(text),
            isLoading: state.isStreaming,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome, size: 56, color: Color(0xFF6C63FF)),
          const SizedBox(height: 16),
          Text(
            'Nexus AI bilan suhbat boshlang',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kod yozish · Media tahlil · Savol-javob',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
