import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/presentation/widgets/chat_colors.dart';
import '../../home/presentation/widgets/mode_picker_sheet.dart';
import 'video_provider.dart';

/// Video bo'limi (Kling AI). UI tayyor; backend Kling API key sozlanmagani
/// uchun hozircha "Kling API key kerak" ogohlantirishini ko'rsatadi.
class VideoPage extends ConsumerStatefulWidget {
  const VideoPage({super.key});

  @override
  ConsumerState<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends ConsumerState<VideoPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _generate() {
    FocusScope.of(context).unfocus();
    ref.read(videoProvider.notifier).generate(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(videoProvider);

    return Scaffold(
      backgroundColor: ChatColors.bg,
      appBar: AppBar(
        backgroundColor: ChatColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: ChatColors.text),
        title: const Text(
          'Video yaratish',
          style: TextStyle(
            color: ChatColors.text,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            tooltip: 'Rejimni tanlash',
            onPressed: () => showModePickerSheet(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Header(),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                minLines: 3,
                maxLines: 6,
                enabled: !state.isLoading,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(color: ChatColors.text, fontSize: 15),
                decoration: InputDecoration(
                  hintText:
                      'Masalan: "Tog\'lar ortidan quyosh chiqishi, sekin kamera harakati"',
                  hintStyle: const TextStyle(color: ChatColors.muted),
                  filled: true,
                  fillColor: ChatColors.surface,
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: ChatColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: ChatColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: ChatColors.accent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: state.isLoading ? null : _generate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ChatColors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: ChatColors.muted,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: state.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.movie_creation, size: 20),
                  label: Text(
                    state.isLoading ? 'Yaratilmoqda...' : 'Video yarat',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (state.status == VideoStatus.keyRequired)
                _NoticeCard(
                  message: state.message ?? 'Kling API key kerak',
                ),
              if (state.status == VideoStatus.error)
                _NoticeCard(
                  message: state.message ?? 'Xato yuz berdi',
                  isError: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: ChatColors.accentSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.movie_creation,
              color: ChatColors.accent, size: 24),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            'Kling AI bilan matndan video. Kuniga 66 bepul kredit.',
            style: TextStyle(color: ChatColors.textSecondary, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

/// Ogohlantirish (key kerak — sariq) yoki xato (qizil) kartasi.
class _NoticeCard extends StatelessWidget {
  final String message;
  final bool isError;
  const _NoticeCard({required this.message, this.isError = false});

  @override
  Widget build(BuildContext context) {
    final bg = isError ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED);
    final border = isError ? const Color(0xFFFECACA) : const Color(0xFFFED7AA);
    final fg = isError ? const Color(0xFFB91C1C) : const Color(0xFF9A3412);
    final icon = isError ? Icons.error_outline : Icons.key_outlined;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: fg, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
