import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_ai_agent/features/chat/domain/entities/agent_event.dart';
import 'package:nexus_ai_agent/features/chat/domain/entities/chat_message.dart';
import 'package:nexus_ai_agent/features/chat/domain/repositories/chat_repository.dart';
import 'package:nexus_ai_agent/features/chat/domain/usecases/stream_message_usecase.dart';
import 'package:nexus_ai_agent/features/chat/presentation/providers/chat_provider.dart';

/// Stream'ni testdan boshqarish uchun qo'lda yozilgan soxta repository.
class FakeChatRepository implements ChatRepository {
  /// Har chaqiruvda qaytariladigan oqimni quradi (callCount asosida o'zgartirish mumkin).
  late Stream<AgentEvent> Function(int callCount) streamBuilder;
  int callCount = 0;
  CancelToken? lastCancelToken;

  @override
  Stream<AgentEvent> streamMessage({
    required String message,
    required List<ChatMessage> history,
    required String sessionId,
    required bool planner,
    CancelToken? cancelToken,
  }) {
    callCount++;
    lastCancelToken = cancelToken;
    return streamBuilder(callCount);
  }

  @override
  Future<Either<String, ChatMessage>> sendMessage(
          {required String message,
          required List<ChatMessage> history,
          required String sessionId}) =>
      throw UnimplementedError();

  @override
  Future<Either<String, ChatMessage>> runAgent(
          {required String message,
          required List<ChatMessage> history,
          required String sessionId}) =>
      throw UnimplementedError();
}

ChatNotifier _build(FakeChatRepository repo) =>
    ChatNotifier(StreamMessageUseCase(repo));

void main() {
  group('ChatNotifier — muvaffaqiyatli oqim', () {
    test('token oqimi assistant bubble hosil qiladi, oxirida streaming tugaydi',
        () async {
      final repo = FakeChatRepository();
      repo.streamBuilder = (_) => Stream.fromIterable(const [
            StartEvent(agent: 'CoderAgent', model: 'llama'),
            TokenEvent('Sa'),
            TokenEvent('lom'),
            DoneEvent(),
          ]);
      final n = _build(repo);

      await n.sendMessage('salom');

      expect(n.state.isStreaming, false);
      expect(n.state.isLoading, false);
      // user + assistant
      expect(n.state.messages.length, 2);
      final assistant = n.state.messages.last;
      expect(assistant.role, 'assistant');
      expect(assistant.content, 'Salom');
      expect(assistant.agentUsed, 'CoderAgent');
    });
  });

  group('ChatNotifier — xato holati', () {
    test('ErrorEvent qizil xato bubble qo\'shadi', () async {
      final repo = FakeChatRepository();
      repo.streamBuilder = (_) => Stream.fromIterable(const [
            ErrorEvent('Serverga ulanib bo\'lmadi.'),
          ]);
      final n = _build(repo);

      await n.sendMessage('salom');

      expect(n.state.isStreaming, false);
      final last = n.state.messages.last;
      expect(last.isError, true);
      expect(last.content, 'Serverga ulanib bo\'lmadi.');
    });

    test('retry() xato bubble\'ini olib tashlab, qaytadan yuboradi', () async {
      final repo = FakeChatRepository();
      repo.streamBuilder = (call) {
        if (call == 1) {
          return Stream.fromIterable(const [ErrorEvent('timeout')]);
        }
        return Stream.fromIterable(const [
          StartEvent(agent: 'CoderAgent', model: 'llama'),
          TokenEvent('OK'),
          DoneEvent(),
        ]);
      };
      final n = _build(repo);

      await n.sendMessage('salom');
      expect(n.state.messages.last.isError, true);

      await n.retry();

      // Xato bubble yo'qoldi, o'rniga muvaffaqiyatli javob.
      expect(repo.callCount, 2);
      expect(n.state.messages.any((m) => m.isError), false);
      expect(n.state.messages.length, 2); // user + assistant
      expect(n.state.messages.last.content, 'OK');
    });
  });

  group('ChatNotifier — to\'xtatish', () {
    test('stopStream() streaming holatini yopadi va tokenni bekor qiladi',
        () async {
      final repo = FakeChatRepository();
      final controller = StreamController<AgentEvent>();
      repo.streamBuilder = (_) => controller.stream;
      final n = _build(repo);

      // Oqimni boshlaymiz (kutmasdan — controller ochiq turadi).
      final fut = n.sendMessage('salom');
      controller.add(const StartEvent(agent: 'CoderAgent', model: 'llama'));
      await Future<void>.delayed(Duration.zero);
      expect(n.state.isStreaming, true);

      n.stopStream();
      expect(n.state.isStreaming, false);
      expect(n.state.isLoading, false);
      expect(repo.lastCancelToken?.isCancelled, true);

      await controller.close();
      await fut;
      // To'xtatishdan keyin xato bubble qo'shilmaydi.
      expect(n.state.messages.any((m) => m.isError), false);
    });
  });
}
