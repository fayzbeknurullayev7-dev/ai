import 'tool_step.dart';

class ChatMessage {
  final String id;
  final String content;
  final String role; // 'user' | 'assistant' | 'error'
  final DateTime timestamp;
  final String? agentUsed;
  final String? modelUsed;
  final List<ToolStep> steps; // Planner Agent ReAct izi (bo'lmasa bo'sh)

  /// AI yaratgan rasm (PNG/JPEG) base64 ko'rinishida — bo'lsa bubble'da ko'rsatiladi.
  final String? imageBase64;

  /// AI yaratgan rasm tashqi URL'i (masalan Pollinations.ai) — Image.network.
  final String? imageUrl;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.agentUsed,
    this.modelUsed,
    this.steps = const [],
    this.imageBase64,
    this.imageUrl,
  });

  bool get isUser => role == 'user';
  bool get isError => role == 'error';
  bool get hasSteps => steps.isNotEmpty;
  bool get hasImage =>
      (imageBase64 != null && imageBase64!.isNotEmpty) ||
      (imageUrl != null && imageUrl!.isNotEmpty);

  /// Streaming paytida xabarni inkremental yangilash uchun.
  ChatMessage copyWith({
    String? content,
    String? agentUsed,
    String? modelUsed,
    List<ToolStep>? steps,
    String? imageBase64,
    String? imageUrl,
  }) {
    return ChatMessage(
      id: id,
      content: content ?? this.content,
      role: role,
      timestamp: timestamp,
      agentUsed: agentUsed ?? this.agentUsed,
      modelUsed: modelUsed ?? this.modelUsed,
      steps: steps ?? this.steps,
      imageBase64: imageBase64 ?? this.imageBase64,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  /// Local storage (Hive) uchun serializatsiya.
  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'role': role,
        'timestamp': timestamp.toIso8601String(),
        'agentUsed': agentUsed,
        'modelUsed': modelUsed,
        'steps': steps.map((s) => s.toJson()).toList(),
        'imageBase64': imageBase64,
        'imageUrl': imageUrl,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawSteps = (json['steps'] as List?) ?? const [];
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String? ?? '',
      role: json['role'] as String? ?? 'assistant',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      agentUsed: json['agentUsed'] as String?,
      modelUsed: json['modelUsed'] as String?,
      steps: rawSteps
          .whereType<Map>()
          .map((e) => ToolStep.fromJson(e.cast<String, dynamic>()))
          .toList(),
      imageBase64: json['imageBase64'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}
