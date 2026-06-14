import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/presentation/widgets/chat_colors.dart';
import '../../../chat/presentation/widgets/message_bubble.dart';
import '../../../chat/presentation/widgets/typing_indicator.dart';
import '../../chat_mode.dart';
import '../providers/mode_chat_provider.dart';
import '../widgets/simple_input.dart';

/// Rasm va Kod tablari uchun umumiy sahifa. `mode` orqali agent (image/code),
/// matnlar va takliflar farqlanadi. Holat `modeChatProvider(mode)`da.
class ModeChatPage extends ConsumerStatefulWidget {
  final ChatMode mode;
  const ModeChatPage({super.key, required this.mode});

  @override
  ConsumerState<ModeChatPage> createState() => _ModeChatPageState();
}

class _ModeChatPageState extends ConsumerState<ModeChatPage> {
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

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final state = ref.watch(modeChatProvider(mode));
    final notifier = ref.read(modeChatProvider(mode).notifier);

    ref.listen(modeChatProvider(mode), (_, __) => _autoScroll());

    return Scaffold(
      backgroundColor: ChatColors.bg,
      appBar: AppBar(
        backgroundColor: ChatColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: ChatColors.text),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(mode.activeIcon, color: ChatColors.accent, size: 18),
            const SizedBox(width: 8),
            Text(
              mode.appBarTitle,
              style: const TextStyle(
                color: ChatColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          if (state.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Tozalash',
              onPressed: notifier.clear,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.messages.isEmpty
                ? _EmptyState(
                    mode: mode,
                    onSuggestion: notifier.sendMessage,
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
                        onRetry: notifier.retry,
                      );
                    },
                  ),
          ),
          SimpleInput(
            isStreaming: state.isStreaming,
            hint: mode.inputHint,
            onSend: notifier.sendMessage,
            onStop: notifier.stopStream,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ChatMode mode;
  final void Function(String) onSuggestion;
  const _EmptyState({required this.mode, required this.onSuggestion});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ChatColors.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(mode.activeIcon, size: 32, color: ChatColors.accent),
            ),
            const SizedBox(height: 20),
            Text(
              mode.emptyTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ChatColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final (label, icon) in mode.suggestions)
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
