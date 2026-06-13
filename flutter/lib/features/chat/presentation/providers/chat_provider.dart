import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/agent_event.dart';
import '../../domain/entities/chat_message.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/usecases/stream_message_usecase.dart';
import '../../../../core/providers/core_providers.dart';

const _uuid = Uuid();

final chatRepositoryProvider = Provider((ref) {
  return ChatRepositoryImpl(ref.watch(dioProvider));
});

final streamMessageUseCaseProvider = Provider((ref) {
  return StreamMessageUseCase(ref.watch(chatRepositoryProvider));
});

// State
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading; // birinchi event kelguncha "yozmoqda" indikatori
  final bool isStreaming; // so'rov boshidan oxirigacha (Stop tugmasi shartisi)
  final bool plannerMode; // true → /agent/stream (steps), false → /chat/stream

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isStreaming = false,
    this.plannerMode = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isStreaming,
    bool? plannerMode,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isStreaming: isStreaming ?? this.isStreaming,
      plannerMode: plannerMode ?? this.plannerMode,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final StreamMessageUseCase _streamUseCase;

  // Ilova sessiyasi uchun barqaror id — backend xotirasini izolyatsiya qiladi.
  final String _sessionId = _uuid.v4();

  // Joriy oqimni bekor qilish uchun token (Stop tugmasi shu orqali ishlaydi).
  CancelToken? _cancelToken;

  // "Qayta urinish" uchun oxirgi so'rov konteksti.
  String? _lastMessage;
  List<ChatMessage> _lastHistory = const [];

  ChatNotifier(this._streamUseCase) : super(const ChatState());

  void togglePlannerMode() =>
      state = state.copyWith(plannerMode: !state.plannerMode);

  void clearChat() {
    _cancelToken?.cancel('chat cleared');
    _cancelToken = null;
    state = ChatState(plannerMode: state.plannerMode);
  }

  /// Yangi xabar yuboradi: user bubble qo'shadi va oqimni boshlaydi.
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

  /// Oxirgi muvaffaqiyatsiz so'rovni qaytadan yuboradi.
  /// Xato bubble'ini (va bo'sh assistant joy egasini) olib tashlaydi.
  Future<void> retry() async {
    final msg = _lastMessage;
    if (msg == null || state.isStreaming) return;

    // Oxirgi user xabaridan keyingi xato/bo'sh assistant bubble'larini tozalaymiz.
    final cleaned = List<ChatMessage>.from(state.messages);
    while (cleaned.isNotEmpty) {
      final last = cleaned.last;
      final isEmptyAssistant =
          last.role == 'assistant' && last.content.isEmpty && !last.hasSteps;
      if (last.isError || isEmptyAssistant) {
        cleaned.removeLast();
      } else {
        break;
      }
    }
    state = state.copyWith(messages: cleaned);

    await _runStream(msg, _lastHistory);
  }

  /// Joriy oqimni to'xtatadi (foydalanuvchi "⏹ To'xtatish" bossa).
  void stopStream() {
    _cancelToken?.cancel('user stopped');
    _cancelToken = null;
    state = state.copyWith(isLoading: false, isStreaming: false);
  }

  // ---- Oqim yadrosi --------------------------------------------------------
  Future<void> _runStream(String text, List<ChatMessage> history) async {
    _lastMessage = text;
    _lastHistory = history;

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    state = state.copyWith(isLoading: true, isStreaming: true);

    final assistantId = _uuid.v4();
    var placeholderAdded = false;
    String? errorMsg;

    // Assistant "joy egasi"ni faqat birinchi event kelganda qo'shamiz —
    // shu paytgacha "yozmoqda" indikatori ko'rinadi.
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
        planner: state.plannerMode,
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
          case StepEvent(:final step):
            ensureAssistant();
            _update(assistantId, (m) => m.copyWith(steps: [...m.steps, step]));
          case DoneEvent():
            break; // switch'dan chiqadi; oqim tabiiy yopiladi
          case ErrorEvent(:final detail):
            errorMsg = detail;
        }
      }
    } catch (e) {
      // Foydalanuvchi to'xtatgan bo'lsa (token bekor) — xato sifatida ko'rsatmaymiz.
      if (!(cancelToken.isCancelled)) errorMsg = 'Kutilmagan xato: $e';
    } finally {
      // Bu oqim hali ham joriy bo'lsa — holatni yopamiz (eskisi bekor qilingan bo'lishi mumkin).
      if (identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
        if (errorMsg != null) _appendError(errorMsg);
        state = state.copyWith(isLoading: false, isStreaming: false);
      }
    }
  }

  /// Chatga qizil xato bubble'ini qo'shadi ("Qayta urinish" tugmasi bilan).
  void _appendError(String detail) {
    final errorMsg = ChatMessage(
      id: _uuid.v4(),
      content: detail,
      role: 'error',
      timestamp: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, errorMsg]);
  }

  /// `messages` ichidagi `id` li xabarni transformatsiya bilan yangilaydi.
  void _update(String id, ChatMessage Function(ChatMessage) transform) {
    state = state.copyWith(
      messages: [
        for (final m in state.messages) m.id == id ? transform(m) : m,
      ],
    );
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref.watch(streamMessageUseCaseProvider));
});
