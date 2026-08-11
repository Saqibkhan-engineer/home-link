import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/database/tables/messages_table.dart';
import '../../../main.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input_bar.dart';

/// Provider that watches messages for a specific conversation.
final messagesStreamProvider =
    StreamProvider.family<List<dynamic>, String>((ref, conversationId) {
  final db = ref.watch(databaseProvider);
  return db.messageDao.watchMessages(conversationId);
});

/// Provider that watches a peer's online status.
final peerOnlineProvider =
    StreamProvider.family<bool, String>((ref, peerId) async* {
  final db = ref.watch(databaseProvider);
  await for (final users in db.userDao.watchAllUsers()) {
    final peer = users.where((u) => u.id == peerId).firstOrNull;
    yield peer?.isOnline ?? false;
  }
});

/// Individual chat room screen (WhatsApp-style).
class ChatRoomScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String peerId;
  final String peerName;
  final String? peerAvatar;
  final String? peerPublicKey;

  const ChatRoomScreen({
    super.key,
    required this.conversationId,
    required this.peerId,
    required this.peerName,
    this.peerAvatar,
    this.peerPublicKey,
  });

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _scrollController = ScrollController();
  String? _peerPublicKey;

  @override
  void initState() {
    super.initState();
    _loadPeerKey();
  }

  Future<void> _loadPeerKey() async {
    if (widget.peerPublicKey != null) {
      _peerPublicKey = widget.peerPublicKey;
      return;
    }
    // Load from database
    final db = ref.read(databaseProvider);
    final peer = await db.userDao.getUserById(widget.peerId);
    setState(() {
      _peerPublicKey = peer?.publicKey;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage(String content) async {
    final syncService = ref.read(syncServiceProvider);

    await syncService.sendTextMessage(
      conversationId: widget.conversationId,
      peerId: widget.peerId,
      content: content,
      peerPublicKey: _peerPublicKey,
    );

    // Scroll to bottom after sending
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  Future<void> _handleAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      // TODO: Send file via P2P service
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File selected: ${file.name}'),
            backgroundColor: AppColors.primaryLight,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync =
        ref.watch(messagesStreamProvider(widget.conversationId));
    final peerOnlineAsync = ref.watch(peerOnlineProvider(widget.peerId));

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkAppBar,
        leadingWidth: 28,
        title: Row(
          children: [
            // Peer avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.darkInput,
              backgroundImage: widget.peerAvatar != null
                  ? FileImage(File(widget.peerAvatar!))
                  : null,
              child: widget.peerAvatar == null
                  ? Text(
                      widget.peerName.isNotEmpty
                          ? widget.peerName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            // Name + online status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.peerName,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  peerOnlineAsync.when(
                    data: (isOnline) => Text(
                      isOnline ? AppStrings.online : AppStrings.offline,
                      style: TextStyle(
                        fontSize: 12,
                        color: isOnline
                            ? AppColors.online
                            : AppColors.textSecondary,
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Voice call button
          IconButton(
            icon: const Icon(Icons.call_rounded),
            color: AppColors.textSecondary,
            onPressed: () {
              Navigator.pushNamed(context, '/call', arguments: {
                'peerId': widget.peerId,
                'peerName': widget.peerName,
                'peerAvatar': widget.peerAvatar,
                'isIncoming': false,
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          size: 28,
                          color: AppColors.accent.withOpacity(0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Messages are end-to-end encrypted',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary.withOpacity(0.6),
                              ),
                        ),
                      ],
                    ),
                  );
                }

                // Scroll to bottom when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];

                    // Show date header if different day from previous message
                    Widget? dateHeader;
                    if (index == 0 ||
                        !_isSameDay(
                          messages[index - 1].timestamp,
                          msg.timestamp,
                        )) {
                      dateHeader = _buildDateHeader(context, msg.timestamp);
                    }

                    return Column(
                      children: [
                        if (dateHeader != null) dateHeader,
                        MessageBubble(
                          content: msg.content,
                          timestamp: msg.timestamp,
                          isMine: msg.isMine,
                          status: msg.status,
                          messageType: msg.type,
                          fileName: msg.fileName,
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),

          // Input bar
          ChatInputBar(
            onSend: _sendMessage,
            onAttachment: _handleAttachment,
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateHeader(BuildContext context, DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        DateFormatter.formatDateHeader(date),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}
