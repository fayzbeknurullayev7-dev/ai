import 'tool_step.dart';

class ChatMessage {
  final String id;
  final String content;
  final String role; // 'user' | 'assistant' | 'error'
  final DateTime timestamp;
  final String? agentUsed;
  final String? modelUsed;
  final List<ToolStep> steps; // Planner Agent ReAct izi (bo'lmasa bo'sh)

  const ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.agentUsed,
    this.modelUsed,
    this.steps = const [],
  });

  bool get isUser => role == 'user';
  bool get isError => role == 'error';
  bool get hasSteps => steps.isNotEmpty;

  /// Streaming paytida xabarni inkremental yangilash uchun.
  ChatMessage copyWith({
    String? content,
    String? agentUsed,
    String? modelUsed,
    List<ToolStep>? steps,
  }) {
    return ChatMessage(
      id: id,
      content: content ?? this.content,
      role: role,
      timestamp: timestamp,
      agentUsed: agentUsed ?? this.agentUsed,
      modelUsed: modelUsed ?? this.modelUsed,
      steps: steps ?? this.steps,
    );
  }
}
