import 'package:flutter/material.dart';
import '../../../chat/presentation/widgets/chat_colors.dart';

/// Rasm/Kod tablari uchun minimal kompozitor: matn maydoni + yuborish/to'xtatish
/// tugmasi. ChatInput'dan farqi — planner/attach tugmalari yo'q.
class SimpleInput extends StatefulWidget {
  final void Function(String) onSend;
  final VoidCallback onStop;
  final bool isStreaming;
  final String hint;

  const SimpleInput({
    super.key,
    required this.onSend,
    required this.onStop,
    required this.isStreaming,
    required this.hint,
  });

  @override
  State<SimpleInput> createState() => _SimpleInputState();
}

class _SimpleInputState extends State<SimpleInput> {
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

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final streaming = widget.isStreaming;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: ChatColors.bg,
        border: Border(top: BorderSide(color: ChatColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(color: ChatColors.text, fontSize: 15),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: const TextStyle(color: ChatColors.muted),
                  filled: true,
                  fillColor: ChatColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _SendButton(
              streaming: streaming,
              enabled: streaming || _hasText,
              onSend: _submit,
              onStop: widget.onStop,
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool streaming;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onStop;

  const _SendButton({
    required this.streaming,
    required this.enabled,
    required this.onSend,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? ChatColors.accent : ChatColors.border,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: !enabled ? null : (streaming ? onStop : onSend),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            streaming ? Icons.stop_rounded : Icons.arrow_upward_rounded,
            color: enabled ? Colors.white : ChatColors.muted,
            size: 22,
          ),
        ),
      ),
    );
  }
}
