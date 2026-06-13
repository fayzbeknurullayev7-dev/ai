import 'dart:async';
import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../domain/entities/agent_event.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../models/chat_message_model.dart';
import '../models/tool_step_model.dart';
import '../../../../core/constants/api_constants.dart';

class ChatRepositoryImpl implements ChatRepository {
  final Dio _dio;

  ChatRepositoryImpl(this._dio);

  List<Map<String, String>> _historyJson(List<ChatMessage> history) =>
      history.map((m) => {'role': m.role, 'content': m.content}).toList();

  Map<String, dynamic> _body(
          String message, List<ChatMessage> history, String sessionId) =>
      {
        'message': message,
        'history': _historyJson(history),
        'session_id': sessionId,
      };

  // ---- Non-stream ---------------------------------------------------------
  @override
  Future<Either<String, ChatMessage>> sendMessage({
    required String message,
    required List<ChatMessage> history,
    required String sessionId,
  }) {
    return _post(ApiConstants.chatEndpoint, message, history, sessionId);
  }

  @override
  Future<Either<String, ChatMessage>> runAgent({
    required String message,
    required List<ChatMessage> history,
    required String sessionId,
  }) {
    return _post(ApiConstants.agentRunEndpoint, message, history, sessionId);
  }

  Future<Either<String, ChatMessage>> _post(
    String endpoint,
    String message,
    List<ChatMessage> history,
    String sessionId,
  ) async {
    try {
      final response = await _dio.post(
        endpoint,
        data: _body(message, history, sessionId),
      );
      return Right(ChatMessageModel.fromJson(response.data));
    } on DioException catch (e) {
      return Left(e.message ?? 'Network error');
    } catch (e) {
      return Left(e.toString());
    }
  }

  // ---- Stream (SSE) -------------------------------------------------------
  @override
  Stream<AgentEvent> streamMessage({
    required String message,
    required List<ChatMessage> history,
    required String sessionId,
    required bool planner,
    CancelToken? cancelToken,
  }) async* {
    final endpoint = planner
        ? ApiConstants.agentStreamEndpoint
        : ApiConstants.chatStreamEndpoint;
    try {
      final response = await _dio.post(
        endpoint,
        data: _body(message, history, sessionId),
        options: Options(responseType: ResponseType.stream),
        cancelToken: cancelToken,
      );
      final body = response.data as ResponseBody;
      yield* _parseSse(body.stream);
    } on DioException catch (e) {
      // Foydalanuvchi "To'xtatish" bossa — bu xato emas, oqim jim yopiladi.
      if (CancelToken.isCancel(e)) return;
      yield ErrorEvent(_friendlyDioError(e));
    } catch (e) {
      yield ErrorEvent('Kutilmagan xato: $e');
    }
  }

  /// DioException'ni o'zbekcha, foydalanuvchiga tushunarli matnga aylantiradi.
  String _friendlyDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return 'So\'rov vaqti tugadi — server javob bermayapti (timeout).';
      case DioExceptionType.receiveTimeout:
        return 'Javobni kutish vaqti tugadi (timeout). Qaytadan urinib ko\'ring.';
      case DioExceptionType.connectionError:
        return 'Serverga ulanib bo\'lmadi. Internet aloqasini tekshiring.';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        final detail = e.response?.data is Map
            ? (e.response?.data['detail']?.toString())
            : null;
        return 'Server xatosi'
            '${code != null ? ' ($code)' : ''}'
            '${detail != null ? ': $detail' : ''}.';
      case DioExceptionType.badCertificate:
        return 'Xavfsizlik sertifikati xatosi.';
      case DioExceptionType.cancel:
        return 'So\'rov bekor qilindi.';
      case DioExceptionType.unknown:
        final msg = e.message ?? '';
        if (msg.contains('SocketException') ||
            msg.contains('Connection closed')) {
          return 'Server bilan aloqa uzildi (socket closed).';
        }
        return 'Tarmoq xatosi: ${e.message ?? 'noma\'lum'}.';
    }
  }

  /// Bayt oqimini SSE satrlariga, so'ng AgentEvent'larga aylantiradi.
  /// Har bir event bitta `data: {json}` satrida keladi.
  Stream<AgentEvent> _parseSse(Stream<List<int>> byteStream) async* {
    final lines = byteStream
        .map((bytes) => utf8.decode(bytes, allowMalformed: true))
        .transform(const LineSplitter());
    await for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data.isEmpty || data == '[DONE]') continue;
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final event = _eventFromJson(json);
        if (event != null) yield event;
      } catch (_) {}
    }
  }

  AgentEvent? _eventFromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'start':
        return StartEvent(
          agent: json['agent'] as String? ?? 'Agent',
          model: json['model'] as String?,
        );
      case 'token':
        return TokenEvent(json['content'] as String? ?? '');
      case 'step':
        final step = (json['step'] as Map?)?.cast<String, dynamic>();
        if (step == null) return null;
        return StepEvent(ToolStepModel.fromJson(step));
      case 'done':
        return const DoneEvent();
      case 'error':
        return ErrorEvent(json['detail'] as String? ?? 'Server error');
      default:
        return null;
    }
  }
}
