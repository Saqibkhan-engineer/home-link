import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/conversations_table.dart';

part 'conversation_dao.g.dart';

/// Data Access Object for the [Conversations] table.
@DriftAccessor(tables: [Conversations])
class ConversationDao extends DatabaseAccessor<AppDatabase>
    with _$ConversationDaoMixin {
  ConversationDao(super.db);

  /// Insert or update a conversation.
  Future<void> upsertConversation(ConversationsCompanion conversation) async {
    await into(conversations).insertOnConflictUpdate(conversation);
  }

  /// Get a conversation by ID.
  Future<Conversation?> getConversationById(String id) async {
    return (select(conversations)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get a 1:1 conversation by peer ID.
  Future<Conversation?> getConversationByPeerId(String peerId) async {
    return (select(conversations)
          ..where((c) => c.peerId.equals(peerId))
          ..where((c) => c.isGroup.equals(false)))
        .getSingleOrNull();
  }

  /// Watch all conversations ordered by last message time (newest first).
  Stream<List<Conversation>> watchAllConversations() {
    return (select(conversations)
          ..orderBy([
            (c) => OrderingTerm.desc(c.lastMessageTime),
          ]))
        .watch();
  }

  /// Update the last message preview for a conversation.
  Future<void> updateLastMessage(
    String conversationId,
    String message,
    DateTime time,
  ) async {
    await (update(conversations)
          ..where((c) => c.id.equals(conversationId)))
        .write(ConversationsCompanion(
      lastMessage: Value(message),
      lastMessageTime: Value(time),
    ));
  }

  /// Increment the unread count for a conversation.
  Future<void> incrementUnread(String conversationId) async {
    await customStatement(
      'UPDATE conversations SET unread_count = unread_count + 1 WHERE id = ?',
      [conversationId],
    );
  }

  /// Reset the unread count to zero (when user opens the conversation).
  Future<void> clearUnread(String conversationId) async {
    await (update(conversations)
          ..where((c) => c.id.equals(conversationId)))
        .write(const ConversationsCompanion(unreadCount: Value(0)));
  }

  /// Update peer online status for a conversation.
  Future<void> setPeerOnline(String conversationId, bool isOnline) async {
    await (update(conversations)
          ..where((c) => c.id.equals(conversationId)))
        .write(ConversationsCompanion(isPeerOnline: Value(isOnline)));
  }

  /// Delete a conversation.
  Future<void> deleteConversation(String id) async {
    await (delete(conversations)..where((c) => c.id.equals(id))).go();
  }
}
