import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'chat_colors.dart';

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [ChatColors.accent, Color(0xFF6C63FF)],
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child:
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 12),
            ...List.generate(3, (i) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: ChatColors.muted,
                  shape: BoxShape.circle,
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .fadeIn(delay: Duration(milliseconds: i * 150))
                  .then()
                  .fadeOut(duration: 400.ms);
            }),
          ],
        ),
      ),
    );
  }
}
