import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AiCoachHistoryMessage {
  const AiCoachHistoryMessage({
    required this.text,
    required this.isUser,
    this.hasImage = false,
  });

  final String text;
  final bool isUser;
  final bool hasImage;

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'hasImage': hasImage,
      };

  static AiCoachHistoryMessage? fromJson(Object? value) {
    if (value is! Map) return null;
    final text = value['text']?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return AiCoachHistoryMessage(
      text: text,
      isUser: value['isUser'] == true,
      hasImage: value['hasImage'] == true,
    );
  }
}

class AiCoachHistoryStore {
  static const _key = 'ai_light_coach_history_v1';
  static const _maxMessages = 80;
  static const _maxMessageLength = 1600;

  Future<List<AiCoachHistoryMessage>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map(AiCoachHistoryMessage.fromJson)
          .whereType<AiCoachHistoryMessage>()
          .take(_maxMessages)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<AiCoachHistoryMessage> messages) async {
    final nonEmpty =
        messages.where((message) => message.text.trim().isNotEmpty).toList();
    final recent = nonEmpty.length <= _maxMessages
        ? nonEmpty
        : nonEmpty.sublist(nonEmpty.length - _maxMessages);
    final sanitized = recent
        .map((message) => AiCoachHistoryMessage(
              text: message.text.trim().substring(
                  0,
                  message.text
                      .trim()
                      .length
                      .clamp(0, _maxMessageLength)
                      .toInt()),
              isUser: message.isUser,
              hasImage: message.hasImage,
            ))
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key,
        jsonEncode(sanitized.map((message) => message.toJson()).toList()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
