import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/conversation.dart';

/// Suhbatlarni qurilma xotirasida (Hive) saqlaydigan local datasource.
///
/// Barcha suhbatlar `chat_history` box ichida bitta `conversations` kaliti
/// ostida JSON ro'yxat sifatida saqlanadi — atomar yozish/o'qish uchun.
class ConversationStore {
  static const _boxName = 'chat_history';
  static const _key = 'conversations';

  Box get _box => Hive.box(_boxName);

  /// Saqlangan barcha suhbatlar (eng yangisi birinchi).
  List<Conversation> loadAll() {
    final raw = _box.get(_key);
    if (raw is! String || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => Conversation.fromJson(e.cast<String, dynamic>()))
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Suhbatlar ro'yxatini to'liq qayta yozadi.
  Future<void> saveAll(List<Conversation> conversations) async {
    final encoded =
        jsonEncode(conversations.map((c) => c.toJson()).toList());
    await _box.put(_key, encoded);
  }
}
