import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../main.dart';
import '../widgets/chat_tile.dart';

/// Reactive provider that watches all conversations from the database.
final conversationsStreamProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.conversationDao.watchAllConversations();
});

/// Chat list tab — shows recent conversations.
class ChatsListScreen extends ConsumerWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsStreamProvider);

    return conversationsAsync.when(
      data: (conversations) {
        if (conversations.isEmpty) {
          return _buildEmptyState(context);
        }
        return ListView.builder(
          itemCount: conversations.length,
          padding: const EdgeInsets.only(top: 8),
          itemBuilder: (context, index) {
            final convo = conversations[index];
            return ChatTile(
              name: convo.title,
              lastMessage: convo.lastMessage ?? '',
              timestamp: convo.lastMessageTime != null
                  ? DateFormatter.formatChatListTime(convo.lastMessageTime!)
                  : '',
              unreadCount: convo.unreadCount,
              isOnline: convo.isPeerOnline,
              avatarPath: convo.avatarPath,
              onTap: () {
                // Clear unread count
                ref
                    .read(databaseProvider)
                    .conversationDao
                    .clearUnread(convo.id);

                Navigator.pushNamed(
                  context,
                  '/chat',
                  arguments: {
                    'conversationId': convo.id,
                    'peerId': convo.peerId ?? '',
                    'peerName': convo.title,
                    'peerAvatar': convo.avatarPath,
                    'peerPublicKey': null, // Loaded in chat room
                  },
                );
              },
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: AppColors.error)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.1),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 56,
              color: AppColors.accent.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.noChats,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.noChatsSubtitle,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
