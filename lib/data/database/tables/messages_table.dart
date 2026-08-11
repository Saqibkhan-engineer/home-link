import 'package:drift/drift.dart';

/// Message status lifecycle: sending → sent → delivered → read.
/// "queued" is used when the recipient is offline.
class MessageStatusConverter extends TypeConverter<MessageStatus, String> {
  const MessageStatusConverter();

  @override
  MessageStatus fromSql(String fromDb) => MessageStatus.values.byName(fromDb);

  @override
  String toSql(MessageStatus value) => value.name;
}

enum MessageStatus {
  sending,  // Being transmitted
  sent,     // Sent to P2P channel
  delivered,// Received by peer (ACK received)
  read,     // Read by peer
  queued,   // Peer offline, queued locally
  failed,   // Send failed
}

/// Message content type.
class MessageTypeConverter extends TypeConverter<MessageType, String> {
  const MessageTypeConverter();

  @override
  MessageType fromSql(String fromDb) => MessageType.values.byName(fromDb);

  @override
  String toSql(MessageType value) => value.name;
}

enum MessageType {
  text,
  image,
  file,
  audio,
  system, // e.g., "User joined", "Encryption enabled"
}

/// Database table for individual messages.
class Messages extends Table {
  /// Unique message ID (UUID).
  TextColumn get id => text()();

  /// Conversation this message belongs to.
  TextColumn get conversationId => text()();

  /// User ID of the sender.
  TextColumn get senderId => text()();

  /// Plaintext content (stored locally — E2E means it's only plaintext on this device).
  TextColumn get content => text()();

  /// Encrypted content as sent over the wire (for auditing/debugging).
  TextColumn get encryptedContent => text().nullable()();

  /// Message type.
  TextColumn get type => text().map(const MessageTypeConverter())();

  /// Message delivery status.
  TextColumn get status => text().map(const MessageStatusConverter())();

  /// For file messages: local file path.
  TextColumn get filePath => text().nullable()();

  /// For file messages: file name.
  TextColumn get fileName => text().nullable()();

  /// For file messages: file size in bytes.
  IntColumn get fileSize => integer().nullable()();

  /// Whether this message was sent by the local user.
  BoolColumn get isMine => boolean().withDefault(const Constant(true))();

  /// When this message was created/sent.
  DateTimeColumn get timestamp =>
      dateTime().withDefault(currentDateAndTime)();

  /// When this message was delivered to the peer.
  DateTimeColumn get deliveredAt => dateTime().nullable()();

  /// When this message was read by the peer.
  DateTimeColumn get readAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
