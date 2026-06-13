import 'package:flutter/material.dart';
import '../../domain/entities/tool_step.dart';

/// Planner Agent ReAct izini ko'rsatadigan yig'iladigan panel.
/// Assistant javobi `steps` bilan kelganda message_bubble ichida chiziladi.
class AgentStepsPanel extends StatelessWidget {
  final List<ToolStep> steps;
  const AgentStepsPanel({super.key, required this.steps});

  IconData _iconFor(String tool) {
    switch (tool) {
      case 'calculator':
        return Icons.calculate_outlined;
      case 'current_datetime':
        return Icons.schedule;
      case 'web_search':
        return Icons.travel_explore;
      case 'execute_python':
        return Icons.terminal;
      case 'remember_fact':
      case 'recall_facts':
        return Icons.psychology_outlined;
      default:
        return Icons.build_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      // ExpansionTile divider/randlarni neytrallaymiz.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0F14).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2A3040)),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          dense: true,
          leading: const Icon(Icons.account_tree_outlined,
              color: Color(0xFF6C63FF), size: 18),
          title: Text(
            'Agent rejasi · ${steps.length} qadam',
            style: const TextStyle(
              color: Color(0xFF8B85FF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: steps.map(_buildStep).toList(),
        ),
      ),
    );
  }

  Widget _buildStep(ToolStep s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconFor(s.tool),
                  size: 14, color: const Color(0xFF8892A4)),
              const SizedBox(width: 6),
              Text(
                '${s.step}. ${s.tool}',
                style: const TextStyle(
                  color: Color(0xFFE8EAF0),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                s.success ? Icons.check_circle : Icons.error_outline,
                size: 13,
                color: s.success
                    ? const Color(0xFF4ADE80)
                    : Colors.redAccent,
              ),
            ],
          ),
          if (s.args.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 2),
              child: Text(
                s.args.toString(),
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 2),
            child: Text(
              s.observation,
              style: const TextStyle(
                color: Color(0xFF8892A4),
                fontSize: 11.5,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
