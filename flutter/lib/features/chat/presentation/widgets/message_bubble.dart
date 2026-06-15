import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../domain/entities/chat_message.dart';
import 'agent_steps_panel.dart';
import 'chat_colors.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  /// Xato bubble'idagi "Qayta urinish" tugmasi uchun.
  final VoidCallback? onRetry;

  const MessageBubble({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (message.isError) return _ErrorBubble(message: message, onRetry: onRetry);

    // Foydalanuvchi: o'ng tomonda kulrang bubble.
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: const BoxDecoration(
            color: ChatColors.userBubble,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(
            message.content,
            style: const TextStyle(
                color: ChatColors.text, fontSize: 15, height: 1.4),
          ),
        ),
      );
    }

    // AI: chap tomonda fonsiz (oq), pastida amal tugmalari.
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AiAvatar(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.agentUsed != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${message.agentUsed} · ${message.modelUsed}',
                            style: const TextStyle(
                              color: ChatColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (message.content.isNotEmpty || !message.hasImage)
                        MarkdownBody(
                          data:
                              message.content.isEmpty ? '…' : message.content,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              color: ChatColors.text,
                              fontSize: 15,
                              height: 1.5,
                            ),
                            code: const TextStyle(
                              color: Color(0xFFB91C1C),
                              backgroundColor: Color(0xFFF3F4F6),
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: const Color(0xFFF6F8FA),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: ChatColors.border),
                            ),
                            blockquoteDecoration: BoxDecoration(
                              color: ChatColors.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      if (message.hasImage)
                        _GeneratedImage(
                          base64Data: message.imageBase64,
                          imageUrl: message.imageUrl,
                        ),
                      if (message.hasSteps) AgentStepsPanel(steps: message.steps),
                    ],
                  ),
                ),
              ],
            ),
            // Amal tugmalari (faqat yakunlangan, bo'sh bo'lmagan javobda).
            if (message.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 42, top: 4),
                child: _ActionRow(content: message.content),
              ),
          ],
        ),
      ),
    );
  }
}

/// AI yaratgan rasm — tashqi URL (Image.network) yoki base64 (Image.memory).
class _GeneratedImage extends StatelessWidget {
  final String? base64Data;
  final String? imageUrl;
  const _GeneratedImage({this.base64Data, this.imageUrl});

  Uint8List? _decode() {
    final data = base64Data;
    if (data == null || data.isEmpty) return null;
    try {
      // `data:image/png;base64,...` prefiksi bo'lsa olib tashlaymiz.
      final raw =
          data.contains(',') ? data.substring(data.indexOf(',') + 1) : data;
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  Widget _frame(Widget child) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: child,
        ),
      );

  Widget _message(String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          text,
          style: const TextStyle(color: ChatColors.muted, fontSize: 13),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Avval base64 (inline) rasm — backend yuklab bergan bo'lsa shu ishlatiladi.
    final bytes = _decode();
    if (bytes != null) {
      return _frame(
        Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _message('Rasmni ochib bo\'lmadi.'),
        ),
      );
    }

    // Zaxira: tashqi URL (masalan Pollinations.ai) — to'g'ridan-to'g'ri tarmoqdan.
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return _frame(
        Image.network(
          url,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return const SizedBox(
              height: 220,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ChatColors.accent,
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => _message('Rasmni yuklab bo\'lmadi.'),
        ),
      );
    }

    // Na base64, na URL bo'lmasa.
    return _message('Rasmni ko\'rsatib bo\'lmadi.');
  }
}

class _AiAvatar extends StatelessWidget {
  const _AiAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ChatColors.accent, Color(0xFF6C63FF)],
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 17),
    );
  }
}

/// AI javobi ostidagi like / dislike / copy tugmalari.
class _ActionRow extends StatefulWidget {
  final String content;
  const _ActionRow({required this.content});

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  int _vote = 0; // -1 dislike, 0 neytral, 1 like
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.content));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _smallBtn(
          icon: _vote == 1 ? Icons.thumb_up : Icons.thumb_up_outlined,
          active: _vote == 1,
          tooltip: 'Yoqdi',
          onTap: () => setState(() => _vote = _vote == 1 ? 0 : 1),
        ),
        _smallBtn(
          icon: _vote == -1 ? Icons.thumb_down : Icons.thumb_down_outlined,
          active: _vote == -1,
          tooltip: 'Yoqmadi',
          onTap: () => setState(() => _vote = _vote == -1 ? 0 : -1),
        ),
        _smallBtn(
          icon: _copied ? Icons.check : Icons.copy_outlined,
          active: _copied,
          tooltip: _copied ? 'Nusxalandi' : 'Nusxalash',
          onTap: _copy,
        ),
      ],
    );
  }

  Widget _smallBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return IconButton(
      icon: Icon(icon, size: 16),
      tooltip: tooltip,
      onPressed: onTap,
      color: active ? ChatColors.accent : ChatColors.muted,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
    );
  }
}

/// Xato holatini ko'rsatuvchi och qizil bubble: xato matni + "Qayta urinish".
class _ErrorBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;

  const _ErrorBubble({required this.message, this.onRetry});

  static const _errorColor = Color(0xFFE11D48);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 24),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.86,
        ),
        decoration: BoxDecoration(
          color: _errorColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _errorColor.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: _errorColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message.content,
                      style: const TextStyle(
                        color: _errorColor,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: _errorColor,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text(
                      'Qayta urinish',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
