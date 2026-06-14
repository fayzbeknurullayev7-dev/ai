import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/agent_event.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../data/datasources/conversation_store.dart';
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

final conversationStoreProvider = Provider((ref) => ConversationStore());

// State
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading; // birinchi event kelguncha "yozmoqda" indikatori
  final bool isStreaming; // so'rov boshidan oxirigacha (Stop tugmasi shartisi)
  final bool plannerMode; // true → /agent/stream (steps), false → /chat/stream

  // Saqlangan suhbatlar (sidebar ro'yxati) va joriy ochiq suhbat id'si.
  final List<Conversation> conversations;
  final String? activeId;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isStreaming = false,
    this.plannerMode = false,
    this.conversations = const [],
    this.activeId,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isStreaming,
    bool? plannerMode,
    List<Conversation>? conversations,
    String? activeId,
    bool clearActiveId = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isStreaming: isStreaming ?? this.isStreaming,
      plannerMode: plannerMode ?? this.plannerMode,
      conversations: conversations ?? this.conversations,
      activeId: clearActiveId ? null : (activeId ?? this.activeId),
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final StreamMessageUseCase _streamUseCase;
  final ConversationStore _store;

  // Ilova sessiyasi uchun barqaror id — backend xotirasini izolyatsiya qiladi.
  final String _sessionId = _uuid.v4();

  // Joriy oqimni bekor qilish uchun token (Stop tugmasi shu orqali ishlaydi).
  CancelToken? _cancelToken;

  // "Qayta urinish" uchun oxirgi so'rov konteksti.
  String? _lastMessage;
  List<ChatMessage> _lastHistory = const [];
  // Oxirgi yuborilgan rejim ("chat" | "image" | "code") — retry uchun.
  String _lastMode = 'chat';

  ChatNotifier(this._streamUseCase, this._store)
      : super(const ChatState()) {
    // Saqlangan suhbatlarni diskdan yuklaymiz (sidebar uchun).
    state = state.copyWith(conversations: _store.loadAll());
  }

  void togglePlannerMode() =>
      state = state.copyWith(plannerMode: !state.plannerMode);

  /// Yangi (bo'sh) suhbat — eski suhbatlar saqlanib qoladi.
  void newChat() {
    _cancelToken?.cancel('new chat');
    _cancelToken = null;
    state = state.copyWith(
      messages: const [],
      isLoading: false,
      isStreaming: false,
      clearActiveId: true,
    );
  }

  /// Logout paytida ko'rinishni tozalaydi (saqlangan suhbatlarga tegmaydi).
  void clearChat() => newChat();

  /// Saqlangan suhbatni ochadi.
  void loadConversation(String id) {
    if (state.isStreaming) return;
    Conversation? conv;
    for (final c in state.conversations) {
      if (c.id == id) {
        conv = c;
        break;
      }
    }
    if (conv == null) return;
    state = state.copyWith(
      messages: List<ChatMessage>.from(conv.messages),
      activeId: conv.id,
      isLoading: false,
      isStreaming: false,
    );
  }

  /// Suhbatni o'chiradi (joriy bo'lsa — ko'rinishni ham tozalaydi).
  Future<void> deleteConversation(String id) async {
    final updated =
        state.conversations.where((c) => c.id != id).toList(growable: false);
    final wasActive = state.activeId == id;
    state = state.copyWith(
      conversations: updated,
      messages: wasActive ? const [] : state.messages,
      clearActiveId: wasActive,
    );
    await _store.saveAll(updated);
  }

  /// Yangi xabar yuboradi: user bubble qo'shadi va oqimni boshlaydi.
  /// [mode] — "chat" (umumiy yordamchi), "image" (rasm yaratish) yoki "code".
  Future<void> sendMessage(String text, {String mode = 'chat'}) async {
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
    await _persistActive(); // user xabari yo'qolmasin

    await _runStream(trimmed, history, mode);
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
      final isEmptyAssistant = last.role == 'assistant' &&
          last.content.isEmpty &&
          !last.hasSteps &&
          !last.hasImage;
      if (last.isError || isEmptyAssistant) {
        cleaned.removeLast();
      } else {
        break;
      }
    }
    state = state.copyWith(messages: cleaned);

    await _runStream(msg, _lastHistory, _lastMode);
  }

  /// Joriy oqimni to'xtatadi (foydalanuvchi "⏹ To'xtatish" bossa).
  void stopStream() {
    _cancelToken?.cancel('user stopped');
    _cancelToken = null;
    state = state.copyWith(isLoading: false, isStreaming: false);
  }

  // ---- Oqim yadrosi --------------------------------------------------------
  Future<void> _runStream(
      String text, List<ChatMessage> history, String mode) async {
    _lastMessage = text;
    _lastHistory = history;
    _lastMode = mode;

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
        // Planner faqat "chat" rejimida (umumiy yordamchi) qo'llanadi.
        // "image"/"code" rejimlari /chat/stream orqali mos agentga ketadi.
        planner: mode == 'chat' && state.plannerMode,
        mode: mode,
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
          case ImageEvent(:final base64, :final imageUrl, :final caption):
            ensureAssistant();
            _update(
              assistantId,
              (m) => m.copyWith(
                imageBase64: base64,
                imageUrl: imageUrl,
                content: caption != null && caption.isNotEmpty
                    ? caption
                    : m.content,
              ),
            );
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
        await _persistActive(); // javob saqlansin
      }
    }
  }

  /// Joriy suhbatni qurilma xotirasiga yozadi (yangi bo'lsa yaratadi).
  Future<void> _persistActive() async {
    final msgs = state.messages;
    if (msgs.isEmpty) return;

    final id = state.activeId ?? _uuid.v4();
    final title = _titleFrom(msgs);
    final conv = Conversation(
      id: id,
      title: title,
      messages: List<ChatMessage>.from(msgs),
      updatedAt: DateTime.now(),
    );

    final list = List<Conversation>.from(state.conversations);
    final idx = list.indexWhere((c) => c.id == id);
    if (idx >= 0) {
      list[idx] = conv;
    } else {
      list.add(conv);
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    state = state.copyWith(conversations: list, activeId: id);
    await _store.saveAll(list);
  }

  /// Suhbat sarlavhasi — birinchi foydalanuvchi xabaridan (qisqartirilgan).
  String _titleFrom(List<ChatMessage> msgs) {
    final first = msgs.firstWhere(
      (m) => m.isUser && m.content.trim().isNotEmpty,
      orElse: () => msgs.first,
    );
    final text = first.content.trim().replaceAll('\n', ' ');
    if (text.isEmpty) return 'Yangi suhbat';
    return text.length > 40 ? '${text.substring(0, 40)}…' : text;
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
  return ChatNotifier(
    ref.watch(streamMessageUseCaseProvider),
    ref.watch(conversationStoreProvider),
  );
});
