import 'package:drift/drift.dart';

/// Database table for conversations (1:1 and group).
class Conversations extends Table {
  /// Unique conversation ID (UUID).
  TextColumn get id => text()();

  /// For 1:1 chats: the peer's user ID. For groups: null.
  TextColumn get peerId => text().nullable()();

  /// Display title (peer's name or group name).
  TextColumn get title => text().withLength(min: 1, max: 200)();

  /// Avatar path (peer's avatar or group avatar).
  TextColumn get avatarPath => text().nullable()();

  /// Whether this is a group conversation.
  BoolColumn get isGroup => boolean().withDefault(const Constant(false))();

  /// Snippet of the last message for display in the chat list.
  TextColumn get lastMessage => text().nullable()();

  /// Timestamp of the last message.
  DateTimeColumn get lastMessageTime => dateTime().nullable()();

  /// Number of unread messages in this conversation.
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();

  /// Whether the peer is currently online (for display in chat list).
  BoolColumn get isPeerOnline =>
      boolean().withDefault(const Constant(false))();

  /// When this conversation was created.
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
