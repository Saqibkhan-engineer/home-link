import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/messages_table.dart';

part 'message_dao.g.dart';

/// Data Access Object for the [Messages] table.
@DriftAccessor(tables: [Messages])
class MessageDao extends DatabaseAccessor<AppDatabase> with _$MessageDaoMixin {
  MessageDao(super.db);

  /// Insert a new message.
  Future<void> insertMessage(MessagesCompanion message) async {
    await into(messages).insert(message);
  }

  /// Get a message by its ID.
  Future<Message?> getMessageById(String id) async {
    return (select(messages)..where((m) => m.id.equals(id)))
        .getSingleOrNull();
  }

  /// Watch messages for a conversation (reactive stream, ordered by time ASC).
  Stream<List<Message>> watchMessages(String conversationId) {
    return (select(messages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]))
        .watch();
  }

  /// Get all messages for a conversation.
  Future<List<Message>> getMessages(String conversationId) async {
    return (select(messages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]))
        .get();
  }

  /// Get all QUEUED messages for a specific peer (for sync on reconnection).
  Future<List<Message>> getQueuedMessagesForPeer(String peerId) async {
    return (select(messages)
          ..where((m) => m.status.equals(MessageStatus.queued.name))
          ..where((m) => m.isMine.equals(true))
          ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]))
        .get();
    // Note: In production, you'd also filter by the peer's conversation.
    // This is simplified — the SyncService handles peer-level filtering.
  }

  /// Get all queued messages for a specific conversation.
  Future<List<Message>> getQueuedMessagesForConversation(
    String conversationId,
  ) async {
    return (select(messages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..where((m) => m.status.equals(MessageStatus.queued.name))
          ..where((m) => m.isMine.equals(true))
          ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]))
        .get();
  }

  /// Update a message's delivery status.
  Future<void> updateStatus(String messageId, MessageStatus newStatus) async {
    final updates = <String, dynamic>{'status': newStatus.name};
    if (newStatus == MessageStatus.delivered) {
      updates['delivered_at'] = DateTime.now().toIso8601String();
    } else if (newStatus == MessageStatus.read) {
      updates['read_at'] = DateTime.now().toIso8601String();
    }

    await (update(messages)..where((m) => m.id.equals(messageId))).write(
      MessagesCompanion(
        status: Value(newStatus),
        deliveredAt: newStatus == MessageStatus.delivered
            ? Value(DateTime.now())
            : const Value.absent(),
        readAt: newStatus == MessageStatus.read
            ? Value(DateTime.now())
            : const Value.absent(),
      ),
    );
  }

  /// Batch update message statuses (for sync responses).
  Future<void> batchUpdateStatus(
    List<String> messageIds,
    MessageStatus newStatus,
  ) async {
    await (update(messages)..where((m) => m.id.isIn(messageIds))).write(
      MessagesCompanion(status: Value(newStatus)),
    );
  }

  /// Check if a message already exists (for deduplication during sync).
  Future<bool> messageExists(String id) async {
    final msg = await getMessageById(id);
    return msg != null;
  }

  /// Delete all messages in a conversation.
  Future<void> deleteConversationMessages(String conversationId) async {
    await (delete(messages)
          ..where((m) => m.conversationId.equals(conversationId)))
        .go();
  }

  /// Count total messages (for storage usage display).
  Future<int> countAllMessages() async {
    final result = await customSelect(
      'SELECT COUNT(*) AS c FROM messages',
    ).getSingle();
    return result.read<int>('c');
  }
}
