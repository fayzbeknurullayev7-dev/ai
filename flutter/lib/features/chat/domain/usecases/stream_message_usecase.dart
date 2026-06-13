import 'package:dio/dio.dart';
import '../entities/agent_event.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

/// SSE oqimini ishga tushiradi — eventlar (start/token/step/done/error) real vaqtda.
class StreamMessageUseCase {
  final ChatRepository _repository;
  const StreamMessageUseCase(this._repository);

  Stream<AgentEvent> call({
    required String message,
    required List<ChatMessage> history,
    required String sessionId,
    required bool planner,
    CancelToken? cancelToken,
  }) {
    return _repository.streamMessage(
      message: message,
      history: history,
      sessionId: sessionId,
      planner: planner,
      cancelToken: cancelToken,
    );
  }
}
