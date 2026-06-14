import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../chat/presentation/widgets/chat_colors.dart';
import '../../home/presentation/widgets/mode_picker_sheet.dart';
import '../data/slides_repository.dart';
import 'slides_provider.dart';

/// Slayd bo'limi: foydalanuvchi mavzu yozadi → backend .pptx yaratadi →
/// "Yuklab olish" tugmasi faylni brauzerda ochadi (yuklab oladi).
class SlidesPage extends ConsumerStatefulWidget {
  const SlidesPage({super.key});

  @override
  ConsumerState<SlidesPage> createState() => _SlidesPageState();
}

class _SlidesPageState extends ConsumerState<SlidesPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _generate() {
    FocusScope.of(context).unfocus();
    ref.read(slidesProvider.notifier).generate(_controller.text);
  }

  Future<void> _download(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Havolani ochib bo\'lmadi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(slidesProvider);

    return Scaffold(
      backgroundColor: ChatColors.bg,
      appBar: AppBar(
        backgroundColor: ChatColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: ChatColors.text),
        title: const Text(
          'Slayd yaratish',
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
                      'Masalan: "Quyosh energiyasi va uning kelajagi" haqida taqdimot',
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
                      : const Icon(Icons.slideshow, size: 20),
                  label: Text(
                    state.isLoading ? 'Yaratilmoqda...' : 'Slayd yarat',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (state.status == SlidesStatus.success && state.result != null)
                _ResultCard(
                  result: state.result!,
                  onDownload: () => _download(state.result!.downloadUrl),
                ),
              if (state.status == SlidesStatus.error)
                _ErrorCard(message: state.error ?? 'Xato yuz berdi'),
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
          child: const Icon(Icons.slideshow,
              color: ChatColors.accent, size: 24),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            'Mavzuni yozing — Nexus AI siz uchun professional .pptx taqdimot tayyorlaydi.',
            style: TextStyle(color: ChatColors.textSecondary, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final SlideResult result;
  final VoidCallback onDownload;
  const _ResultCard({required this.result, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ChatColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ChatColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle,
                  color: ChatColors.accent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Taqdimot tayyor',
                style: TextStyle(
                  color: ChatColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            result.title,
            style: const TextStyle(color: ChatColors.text, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '${result.slideCount} ta slayd',
            style: const TextStyle(color: ChatColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onDownload,
              style: OutlinedButton.styleFrom(
                foregroundColor: ChatColors.accent,
                side: const BorderSide(color: ChatColors.accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.download_rounded, size: 20),
              label: const Text(
                'Yuklab olish (.pptx)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
