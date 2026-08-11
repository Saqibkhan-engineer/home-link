import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/users_table.dart';
import 'tables/conversations_table.dart';
import 'tables/messages_table.dart';
import 'tables/call_logs_table.dart';
import 'daos/user_dao.dart';
import 'daos/conversation_dao.dart';
import 'daos/message_dao.dart';
import 'daos/call_log_dao.dart';

part 'app_database.g.dart';

/// The main Drift database for HomeLink.
///
/// All chat history, user data, and call logs are stored locally.
/// No data ever leaves the device except through the encrypted P2P channel.
@DriftDatabase(
  tables: [Users, Conversations, Messages, CallLogs],
  daos: [UserDao, ConversationDao, MessageDao, CallLogDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// For testing: allows injecting a custom executor.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Future migrations go here
      },
    );
  }
}

/// Opens a persistent SQLite connection in the app's documents directory.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'homelink.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
