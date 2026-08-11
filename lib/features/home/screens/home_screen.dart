import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../main.dart';
import '../../chat/screens/chats_list_screen.dart';
import '../../calls/screens/calls_list_screen.dart';

/// Home screen with TabBar: Chats and Calls (WhatsApp layout).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialize P2P and sync services on home screen load
    _initServices();
  }

  Future<void> _initServices() async {
    final p2pService = ref.read(p2pServiceProvider);
    await p2pService.initialize();

    final syncService = ref.read(syncServiceProvider);
    syncService.startSync();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkAppBar,
        title: Text(
          AppStrings.appName,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
        ),
        actions: [
          // Search
          IconButton(
            icon: const Icon(Icons.search_rounded),
            color: AppColors.textSecondary,
            onPressed: () {
              // TODO: Implement search
            },
          ),
          // 3-dot menu
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textSecondary,
            ),
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  Navigator.pushNamed(context, '/settings');
                  break;
                case 'my_id':
                  _showMyIdDialog(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'my_id',
                child: Text(AppStrings.myId),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Text(AppStrings.settings),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: AppStrings.chats),
            Tab(text: AppStrings.calls),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ChatsListScreen(),
          CallsListScreen(),
        ],
      ),
      // FAB changes based on current tab
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          return FloatingActionButton(
            onPressed: () {
              if (_tabController.index == 0) {
                Navigator.pushNamed(context, '/new-chat');
              }
            },
            backgroundColor: AppColors.accent,
            child: Icon(
              _tabController.index == 0
                  ? Icons.chat_rounded
                  : Icons.call_rounded,
              color: AppColors.darkBg,
            ),
          );
        },
      ),
    );
  }

  void _showMyIdDialog(BuildContext context) {
    final identity = ref.read(identityServiceProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          AppStrings.yourUniqueId,
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.darkInput,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                identity.userId,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Share this ID with family members\nso they can find you on the network.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper widget that rebuilds when a [Listenable] changes.
class AnimatedBuilder extends StatelessWidget {
  final Listenable animation;
  final Widget Function(BuildContext, Widget?) builder;

  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder2(
      animation: animation,
      builder: builder,
    );
  }
}

class AnimatedBuilder2 extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;

  const AnimatedBuilder2({
    super.key,
    required super.listenable,
    required this.builder,
  }) : super();

  Listenable get animation => listenable;

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}
