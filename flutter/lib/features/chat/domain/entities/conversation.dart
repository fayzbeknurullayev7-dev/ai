import 'chat_message.dart';

/// Bitta saqlangan suhbat: sidebar ro'yxatida ko'rsatiladi va qayta yuklanadi.
class Conversation {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime updatedAt;

  const Conversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.updatedAt,
  });

  Conversation copyWith({
    String? title,
    List<ChatMessage>? messages,
    DateTime? updatedAt,
  }) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final rawMsgs = (json['messages'] as List?) ?? const [];
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Suhbat',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      messages: rawMsgs
          .whereType<Map>()
          .map((e) => ChatMessage.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}
