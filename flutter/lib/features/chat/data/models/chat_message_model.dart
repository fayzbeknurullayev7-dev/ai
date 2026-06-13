import 'package:uuid/uuid.dart';
import '../../domain/entities/chat_message.dart';
import 'tool_step_model.dart';

const _uuid = Uuid();

class ChatMessageModel extends ChatMessage {
  const ChatMessageModel({
    required super.id,
    required super.content,
    required super.role,
    required super.timestamp,
    super.agentUsed,
    super.modelUsed,
    super.steps,
  });

  /// `/chat/` va `/agent/run` ikkala javobini ham parse qiladi.
  /// `/agent/run` qo'shimcha `steps` massivini qaytaradi (Planner trace).
  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    // FIX (#1): Backend `id` qaytarmaydi — klientda generatsiya qilinadi.
    final rawSteps = (json['steps'] as List?) ?? const [];
    return ChatMessageModel(
      id: json['id'] as String? ?? _uuid.v4(),
      content: json['reply'] as String,
      role: 'assistant',
      timestamp: DateTime.now(),
      agentUsed: json['agent_used'] as String?,
      modelUsed: json['model_used'] as String?,
      steps: rawSteps
          .whereType<Map>()
          .map((e) => ToolStepModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toHistoryJson() {
    return {'role': role, 'content': content};
  }
}
