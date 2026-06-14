import 'package:flutter/material.dart';
import 'chat_colors.dart';

/// Minimal "Ask anything" kompozitor: matn maydoni + ostida ikonlar qatori
/// (attach · web · idea/planner · more · send). Oqim ketayotganda send → stop.
class ChatInput extends StatefulWidget {
  final void Function(String) onSend;
  final VoidCallback onStop;
  final VoidCallback onTogglePlanner;
  final VoidCallback onMore;
  final bool isStreaming;
  final bool plannerMode;

  const ChatInput({
    super.key,
    required this.onSend,
    required this.onStop,
    required this.onTogglePlanner,
    required this.onMore,
    required this.isStreaming,
    required this.plannerMode,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isStreaming) return;
    widget.onSend(text);
    _controller.clear();
    _focus.requestFocus();
  }

  void _soon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label — tez orada'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: ChatColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: ChatColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Matn maydoni
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                maxLines: 5,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(color: ChatColors.text, fontSize: 15),
                cursorColor: ChatColors.accent,
                decoration: const InputDecoration(
                  hintText: 'Ask anything',
                  hintStyle: TextStyle(color: ChatColors.muted, fontSize: 15),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Ikonlar qatori
            Row(
              children: [
                _IconBtn(
                  icon: Icons.add,
                  tooltip: 'Biriktirish',
                  onTap: () => _soon('Fayl biriktirish'),
                ),
                _IconBtn(
                  icon: Icons.language,
                  tooltip: 'Web qidiruv',
                  onTap: () => _soon('Web qidiruv'),
                ),
                _IconBtn(
                  icon: Icons.lightbulb_outline,
                  tooltip: 'Planner rejimi',
                  active: widget.plannerMode,
                  onTap: widget.onTogglePlanner,
                ),
                _IconBtn(
                  icon: Icons.more_horiz,
                  tooltip: 'Rejimni tanlash',
                  onTap: widget.onMore,
                ),
                const Spacer(),
                _SendButton(
                  isStreaming: widget.isStreaming,
                  enabled: _hasText,
                  onSend: _submit,
                  onStop: widget.onStop,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 22),
      tooltip: tooltip,
      onPressed: onTap,
      color: active ? ChatColors.accent : ChatColors.textSecondary,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: active ? ChatColors.accentSoft : Colors.transparent,
        shape: const CircleBorder(),
      ),
    );
  }
}

/// Yuborish tugmasi — oqim ketayotganda to'xtatish (stop) tugmasiga aylanadi.
class _SendButton extends StatelessWidget {
  final bool isStreaming;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onStop;

  const _SendButton({
    required this.isStreaming,
    required this.enabled,
    required this.onSend,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    if (isStreaming) {
      return _circle(
        bg: ChatColors.text,
        icon: Icons.stop_rounded,
        onTap: onStop,
      );
    }
    return _circle(
      bg: enabled ? ChatColors.text : ChatColors.border,
      icon: Icons.arrow_upward_rounded,
      onTap: enabled ? onSend : null,
    );
  }

  Widget _circle({
    required Color bg,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
