import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../chat/domain/entities/agent_event.dart';
import '../../../chat/domain/entities/chat_message.dart';
import '../../../chat/domain/usecases/stream_message_usecase.dart';
import '../../../chat/presentation/providers/chat_provider.dart'
    show streamMessageUseCaseProvider;
import '../../chat_mode.dart';

const _uuid = Uuid();

/// Rasm / Kod tablari uchun yengil suhbat holati (sidebar/tarixsiz, sessiya
/// davomida saqlanadi). `ChatNotifier`dan farqi — Hive persistensiyasi yo'q
/// va backendga `mode` (image/code) majburlab yuboriladi.
class ModeChatState {
  final List<ChatMessage> messages;
  final bool isLoading; // birinchi event kelguncha "yozmoqda"
  final bool isStreaming; // so'rov boshidan oxirigacha (Stop sharti)

  const ModeChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isStreaming = false,
  });

  ModeChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isStreaming,
  }) {
    return ModeChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class ModeChatNotifier extends StateNotifier<ModeChatState> {
  final StreamMessageUseCase _streamUseCase;
  final ChatMode _mode;

  final String _sessionId = _uuid.v4();
  CancelToken? _cancelToken;

  // "Qayta urinish" uchun oxirgi kontekst.
  String? _lastMessage;
  List<ChatMessage> _lastHistory = const [];

  ModeChatNotifier(this._streamUseCase, this._mode)
      : super(const ModeChatState());

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isStreaming) return;

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      content: trimmed,
      role: 'user',
      timestamp: DateTime.now(),
    );
    final history = List<ChatMessage>.from(state.messages);
    state = state.copyWith(messages: [...state.messages, userMsg]);

    await _runStream(trimmed, history);
  }

  Future<void> retry() async {
    final msg = _lastMessage;
    if (msg == null || state.isStreaming) return;

    final cleaned = List<ChatMessage>.from(state.messages);
    while (cleaned.isNotEmpty) {
      final last = cleaned.last;
      final isEmptyAssistant = last.role == 'assistant' &&
          last.content.isEmpty &&
          !last.hasImage;
      if (last.isError || isEmptyAssistant) {
        cleaned.removeLast();
      } else {
        break;
      }
    }
    state = state.copyWith(messages: cleaned);
    await _runStream(msg, _lastHistory);
  }

  void stopStream() {
    _cancelToken?.cancel('user stopped');
    _cancelToken = null;
    state = state.copyWith(isLoading: false, isStreaming: false);
  }

  void clear() {
    _cancelToken?.cancel('clear');
    _cancelToken = null;
    state = const ModeChatState();
  }

  Future<void> _runStream(String text, List<ChatMessage> history) async {
    _lastMessage = text;
    _lastHistory = history;

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    state = state.copyWith(isLoading: true, isStreaming: true);

    final assistantId = _uuid.v4();
    var placeholderAdded = false;
    String? errorMsg;

    void ensureAssistant({String? agent, String? model}) {
      if (placeholderAdded) {
        if (agent != null) {
          _update(assistantId,
              (m) => m.copyWith(agentUsed: agent, modelUsed: model));
        }
        return;
      }
      final assistant = ChatMessage(
        id: assistantId,
        content: '',
        role: 'assistant',
        timestamp: DateTime.now(),
        agentUsed: agent,
        modelUsed: model,
      );
      state = state.copyWith(
        messages: [...state.messages, assistant],
        isLoading: false,
      );
      placeholderAdded = true;
    }

    try {
      final stream = _streamUseCase(
        message: text,
        history: history,
        sessionId: _sessionId,
        planner: false,
        mode: _mode.apiMode,
        cancelToken: cancelToken,
      );

      await for (final event in stream) {
        switch (event) {
          case StartEvent(:final agent, :final model):
            ensureAssistant(agent: agent, model: model);
          case TokenEvent(:final content):
            ensureAssistant();
            _update(
                assistantId, (m) => m.copyWith(content: m.content + content));
          case ImageEvent(:final base64, :final caption):
            ensureAssistant();
            _update(
              assistantId,
              (m) => m.copyWith(
                imageBase64: base64,
                content: caption != null && caption.isNotEmpty
                    ? caption
                    : m.content,
              ),
            );
          case StepEvent():
            break; // Rasm/Kod tablarida planner qadamlari ishlatilmaydi.
          case DoneEvent():
            break;
          case ErrorEvent(:final detail):
            errorMsg = detail;
        }
      }
    } catch (e) {
      if (!cancelToken.isCancelled) errorMsg = 'Kutilmagan xato: $e';
    } finally {
      if (identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
        if (errorMsg != null) _appendError(errorMsg);
        state = state.copyWith(isLoading: false, isStreaming: false);
      }
    }
  }

  void _appendError(String detail) {
    final errorMsg = ChatMessage(
      id: _uuid.v4(),
      content: detail,
      role: 'error',
      timestamp: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, errorMsg]);
  }

  void _update(String id, ChatMessage Function(ChatMessage) transform) {
    state = state.copyWith(
      messages: [
        for (final m in state.messages) m.id == id ? transform(m) : m,
      ],
    );
  }
}

/// Rejim bo'yicha alohida holat — `ChatMode` kaliti bilan (image/code).
final modeChatProvider =
    StateNotifierProvider.family<ModeChatNotifier, ModeChatState, ChatMode>(
  (ref, mode) =>
      ModeChatNotifier(ref.watch(streamMessageUseCaseProvider), mode),
);
