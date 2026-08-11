import 'package:drift/drift.dart';

/// Call status types.
class CallStatusConverter extends TypeConverter<CallStatus, String> {
  const CallStatusConverter();

  @override
  CallStatus fromSql(String fromDb) => CallStatus.values.byName(fromDb);

  @override
  String toSql(CallStatus value) => value.name;
}

enum CallStatus {
  missed,
  answered,
  outgoing,
  rejected,
}

/// Database table for voice call history.
class CallLogs extends Table {
  /// Unique call ID (UUID).
  TextColumn get id => text()();

  /// User ID of the other party.
  TextColumn get peerId => text()();

  /// Peer's display name (denormalized for quick display).
  TextColumn get peerName => text()();

  /// Call status.
  TextColumn get status => text().map(const CallStatusConverter())();

  /// Call duration in seconds (0 for missed/rejected).
  IntColumn get durationSeconds =>
      integer().withDefault(const Constant(0))();

  /// When the call started.
  DateTimeColumn get timestamp =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
