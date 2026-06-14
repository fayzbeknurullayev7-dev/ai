import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/presentation/widgets/chat_colors.dart';
import '../../chat_mode.dart';
import '../providers/home_mode_provider.dart';

/// Rejim tanlash bottom sheet'ini ochadi. Tanlangach `homeModeProvider`ni
/// yangilaydi — `HomeShell` mos sahifaga o'tadi.
///
/// Input'dagi "..." (more) tugmasi shu funksiyani chaqiradi.
Future<void> showModePickerSheet(BuildContext context, WidgetRef ref) async {
  final current = ref.read(homeModeProvider);
  final picked = await showModalBottomSheet<ChatMode>(
    context: context,
    backgroundColor: ChatColors.bg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _ModePickerSheet(current: current),
  );
  if (picked != null && picked != current) {
    ref.read(homeModeProvider.notifier).state = picked;
  }
}

class _ModePickerSheet extends StatelessWidget {
  final ChatMode current;
  const _ModePickerSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tortish (drag) belgisi.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: ChatColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                'Rejimni tanlang',
                style: TextStyle(
                  color: ChatColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final mode in ChatMode.values)
              _ModeTile(
                mode: mode,
                selected: mode == current,
                onTap: () => Navigator.pop(context, mode),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final ChatMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: selected ? ChatColors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? ChatColors.accent : ChatColors.border,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(
          selected ? mode.activeIcon : mode.icon,
          color: selected ? ChatColors.accent : ChatColors.textSecondary,
        ),
        title: Row(
          children: [
            Text(
              mode.label,
              style: TextStyle(
                color: selected ? ChatColors.accent : ChatColors.text,
                fontSize: 15.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (mode.isComingSoon) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ChatColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Tez kunda',
                  style: TextStyle(
                    color: ChatColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: selected
            ? const Icon(Icons.check_circle, color: ChatColors.accent, size: 20)
            : null,
        onTap: onTap,
      ),
    );
  }
}
