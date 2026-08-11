import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/call_logs_table.dart';

part 'call_log_dao.g.dart';

/// Data Access Object for the [CallLogs] table.
@DriftAccessor(tables: [CallLogs])
class CallLogDao extends DatabaseAccessor<AppDatabase>
    with _$CallLogDaoMixin {
  CallLogDao(super.db);

  /// Insert a new call log entry.
  Future<void> insertCallLog(CallLogsCompanion callLog) async {
    await into(callLogs).insert(callLog);
  }

  /// Watch all call logs (reactive, newest first).
  Stream<List<CallLog>> watchAllCallLogs() {
    return (select(callLogs)
          ..orderBy([(c) => OrderingTerm.desc(c.timestamp)]))
        .watch();
  }

  /// Get all call logs.
  Future<List<CallLog>> getAllCallLogs() async {
    return (select(callLogs)
          ..orderBy([(c) => OrderingTerm.desc(c.timestamp)]))
        .get();
  }

  /// Get call logs for a specific peer.
  Future<List<CallLog>> getCallLogsForPeer(String peerId) async {
    return (select(callLogs)
          ..where((c) => c.peerId.equals(peerId))
          ..orderBy([(c) => OrderingTerm.desc(c.timestamp)]))
        .get();
  }

  /// Delete a call log entry.
  Future<void> deleteCallLog(String id) async {
    await (delete(callLogs)..where((c) => c.id.equals(id))).go();
  }

  /// Clear all call history.
  Future<void> clearAllCallLogs() async {
    await delete(callLogs).go();
  }
}
