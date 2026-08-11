import 'dart:convert';
import 'dart:math';
import 'package:uuid/uuid.dart';

/// Generates unique identifiers for users and messages.
class IdGenerator {
  IdGenerator._();

  static const _uuid = Uuid();

  /// Generates a unique User ID: 12-character alphanumeric hash.
  /// Format: XXXX-XXXX-XXXX (e.g., "A3F2-K9B1-M7D4")
  static String generateUserId() {
    final raw = _uuid.v4().replaceAll('-', '').toUpperCase();
    final segment1 = raw.substring(0, 4);
    final segment2 = raw.substring(4, 8);
    final segment3 = raw.substring(8, 12);
    return '$segment1-$segment2-$segment3';
  }

  /// Generates a UUID v4 for messages, conversations, etc.
  static String generateMessageId() => _uuid.v4();

  /// Generates a UUID v4 for conversations.
  static String generateConversationId() => _uuid.v4();

  /// Generates a random 6-character device display name suffix.
  static String generateDeviceSuffix() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
