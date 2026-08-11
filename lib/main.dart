import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database/app_database.dart';
import 'services/encryption/encryption_service.dart';
import 'services/identity/identity_service.dart';
import 'services/p2p/android_p2p_service.dart';
import 'services/p2p/p2p_message_handler.dart';
import 'services/p2p/p2p_service.dart';
import 'services/sync/sync_service.dart';

// ─── Global Service Providers ───

/// Drift database — singleton for the app lifetime.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// P2P connectivity service.
final p2pServiceProvider = Provider<P2PService>((ref) {
  final service = AndroidP2PService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Encryption service.
final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});

/// Identity service (depends on encryption).
final identityServiceProvider = Provider<IdentityService>((ref) {
  final encryption = ref.watch(encryptionServiceProvider);
  return IdentityService(encryption);
});

/// P2P message handler (depends on P2P service).
final messageHandlerProvider = Provider<P2PMessageHandler>((ref) {
  final p2p = ref.watch(p2pServiceProvider);
  final handler = P2PMessageHandler(p2p);
  ref.onDispose(() => handler.dispose());
  return handler;
});

/// Sync service (depends on all core services).
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final p2p = ref.watch(p2pServiceProvider);
  final handler = ref.watch(messageHandlerProvider);
  final encryption = ref.watch(encryptionServiceProvider);
  final identity = ref.watch(identityServiceProvider);

  return SyncService(
    db: db,
    p2pService: p2p,
    messageHandler: handler,
    encryptionService: encryption,
    identityService: identity,
  );
});

/// Whether onboarding has been completed.
final isOnboardedProvider = StateProvider<bool>((ref) => false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Set system UI overlay style for immersive dark theme
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF111B21),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(
    const ProviderScope(
      child: HomeLinkApp(),
    ),
  );
}
