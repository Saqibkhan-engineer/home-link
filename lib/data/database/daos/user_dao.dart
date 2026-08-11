import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/users_table.dart';

part 'user_dao.g.dart';

/// Data Access Object for the [Users] table.
@DriftAccessor(tables: [Users])
class UserDao extends DatabaseAccessor<AppDatabase> with _$UserDaoMixin {
  UserDao(super.db);

  /// Insert or update a user record.
  Future<void> upsertUser(UsersCompanion user) async {
    await into(users).insertOnConflictUpdate(user);
  }

  /// Get a user by their unique ID.
  Future<User?> getUserById(String id) async {
    return (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();
  }

  /// Get all known users.
  Future<List<User>> getAllUsers() async {
    return select(users).get();
  }

  /// Watch all online users (reactive stream).
  Stream<List<User>> watchOnlineUsers() {
    return (select(users)..where((u) => u.isOnline.equals(true))).watch();
  }

  /// Watch all known users.
  Stream<List<User>> watchAllUsers() {
    return select(users).watch();
  }

  /// Update a user's online status.
  Future<void> setOnlineStatus(String id, bool isOnline) async {
    await (update(users)..where((u) => u.id.equals(id))).write(
      UsersCompanion(
        isOnline: Value(isOnline),
        lastSeen: isOnline ? const Value.absent() : Value(DateTime.now()),
      ),
    );
  }

  /// Delete a user by ID.
  Future<void> deleteUser(String id) async {
    await (delete(users)..where((u) => u.id.equals(id))).go();
  }
}
