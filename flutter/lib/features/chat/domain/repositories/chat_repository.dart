import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../entities/agent_event.dart';
import '../entities/chat_message.dart';

abstract class ChatRepository {
  /// Oddiy chat (non-stream) — keyword routing backendda.
  Future<Either<String, ChatMessage>> sendMessage({
    required String message,
    required List<ChatMessage> history,
    required String sessionId,
  });

  /// Planner Agent (non-stream) — javob `steps` (trace) bilan.
  Future<Either<String, ChatMessage>> runAgent({
    required String message,
    required List<ChatMessage> history,
    required String sessionId,
  });

  /// SSE oqimi. `planner=true` → /agent/stream (qadamlar + token),
  /// aks holda /chat/stream (keyword routing). Eventlar real vaqtda keladi.
  /// `cancelToken` orqali foydalanuvchi oqimni to'xtatishi mumkin.
  Stream<AgentEvent> streamMessage({
    required String message,
    required List<ChatMessage> history,
    required String sessionId,
    required bool planner,
    CancelToken? cancelToken,
  });
}
