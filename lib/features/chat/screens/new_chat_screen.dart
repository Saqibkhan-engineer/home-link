import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/id_generator.dart';
import '../../../main.dart';
import '../../../services/p2p/p2p_service.dart';

/// Screen for discovering nearby peers via Wi-Fi Direct.
class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen>
    with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  List<DiscoveredPeer> _peers = [];
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _startScanning();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    final p2p = ref.read(p2pServiceProvider);
    p2p.stopDiscovery();
    super.dispose();
  }

  Future<void> _startScanning() async {
    setState(() => _isScanning = true);

    final p2p = ref.read(p2pServiceProvider);
    await p2p.startDiscovery();

    // Listen for discovered peers
    p2p.discoveredPeersStream.listen((peers) {
      if (mounted) {
        setState(() => _peers = peers);
      }
    });
  }

  Future<void> _connectToPeer(DiscoveredPeer peer) async {
    final p2p = ref.read(p2pServiceProvider);
    final db = ref.read(databaseProvider);
    final identity = ref.read(identityServiceProvider);

    // Show connecting state
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${AppStrings.connecting} ${peer.displayName}'),
        backgroundColor: AppColors.primaryLight,
      ),
    );

    final success = await p2p.connectToPeer(peer);

    if (success && mounted) {
      // Create a conversation for this peer
      final conversationId = IdGenerator.generateConversationId();
      final peerId = peer.userId ?? peer.deviceId;

      // Save peer to database
      await db.userDao.upsertUser(UsersCompanion(
        id: Value(peerId),
        name: Value(peer.displayName),
        isOnline: const Value(true),
      ));

      // Create conversation
      await db.conversationDao.upsertConversation(ConversationsCompanion(
        id: Value(conversationId),
        peerId: Value(peerId),
        title: Value(peer.displayName),
        isPeerOnline: const Value(true),
      ));

      // Send our identity info
      await p2p.sendPayload(P2PPayload(
        type: PayloadType.peerInfo,
        senderId: identity.userId,
        data: {'peerInfo': identity.toPublicInfo()},
      ));

      // Navigate to chat room
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/chat', arguments: {
          'conversationId': conversationId,
          'peerId': peerId,
          'peerName': peer.displayName,
          'peerAvatar': peer.avatarPath,
          'peerPublicKey': null,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkAppBar,
        title: const Text(AppStrings.newChat),
      ),
      body: Column(
        children: [
          // Scanning indicator
          if (_isScanning)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  // Animated radar pulse
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer pulse ring
                          Transform.scale(
                            scale: 1 + (_pulseController.value * 0.5),
                            child: Opacity(
                              opacity: 1 - _pulseController.value,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.accent,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Inner pulse ring
                          Transform.scale(
                            scale: 1 + (_pulseController.value * 0.3),
                            child: Opacity(
                              opacity: 0.8 - (_pulseController.value * 0.5),
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.accent.withOpacity(0.15),
                                ),
                              ),
                            ),
                          ),
                          // Center icon
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accent,
                            ),
                            child: const Icon(
                              Icons.wifi_tethering_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.scanning,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),

          const Divider(height: 1, color: AppColors.darkDivider),

          // Discovered peers list
          Expanded(
            child: _peers.isEmpty
                ? Center(
                    child: Text(
                      _isScanning
                          ? 'Looking for nearby devices...'
                          : AppStrings.noDevicesFound,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _peers.length,
                    padding: const EdgeInsets.only(top: 8),
                    itemBuilder: (context, index) {
                      final peer = _peers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.darkInput,
                          child: Text(
                            peer.displayName.isNotEmpty
                                ? peer.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        title: Text(
                          peer.displayName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          peer.userId ?? peer.deviceId,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            AppStrings.tapToConnect,
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        onTap: () => _connectToPeer(peer),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Helper widget that rebuilds when a [Listenable] changes.
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;

  const AnimatedBuilder({
    super.key,
    required Listenable animation,
    required this.builder,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}
