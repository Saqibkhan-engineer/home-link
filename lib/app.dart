import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'features/splash/splash_screen.dart';
import 'features/onboarding/screens/profile_setup_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/chat/screens/chat_room_screen.dart';
import 'features/chat/screens/new_chat_screen.dart';
import 'features/calls/screens/call_screen.dart';
import 'features/settings/screens/settings_screen.dart';

/// Root widget: applies the dark theme and defines all named routes.
class HomeLinkApp extends ConsumerWidget {
  const HomeLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const ProfileSetupScreen(),
        '/home': (context) => const HomeScreen(),
        '/new-chat': (context) => const NewChatScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
      // Dynamic routes for screens that need arguments
      onGenerateRoute: (settings) {
        if (settings.name == '/chat') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              conversationId: args['conversationId'] as String,
              peerId: args['peerId'] as String,
              peerName: args['peerName'] as String,
              peerAvatar: args['peerAvatar'] as String?,
              peerPublicKey: args['peerPublicKey'] as String?,
            ),
          );
        }
        if (settings.name == '/call') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => CallScreen(
              peerId: args['peerId'] as String,
              peerName: args['peerName'] as String,
              peerAvatar: args['peerAvatar'] as String?,
              isIncoming: args['isIncoming'] as bool? ?? false,
            ),
          );
        }
        return null;
      },
    );
  }
}
