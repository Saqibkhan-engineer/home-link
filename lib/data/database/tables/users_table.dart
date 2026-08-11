import 'package:drift/drift.dart';

/// Database table for storing known users (local user + discovered peers).
class Users extends Table {
  /// Unique User ID (e.g., "A3F2-K9B1-M7D4").
  TextColumn get id => text()();

  /// Display name.
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// Local file path to the avatar image.
  TextColumn get avatarPath => text().nullable()();

  /// Base64-encoded X25519 public key for encryption.
  TextColumn get publicKey => text().nullable()();

  /// Whether this peer is currently connected via P2P.
  BoolColumn get isOnline => boolean().withDefault(const Constant(false))();

  /// Last time this peer was seen online.
  DateTimeColumn get lastSeen => dateTime().nullable()();

  /// When this user record was created.
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
