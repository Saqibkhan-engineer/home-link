import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../data/database/app_database.dart';
import '../../data/database/tables/messages_table.dart';
import '../../core/utils/id_generator.dart';
import '../encryption/encryption_service.dart';
import '../identity/identity_service.dart';
import '../p2p/p2p_message_handler.dart';
import '../p2p/p2p_service.dart';

/// Handles offline message queuing and automatic sync on peer reconnection.
///
/// Workflow:
/// 1. **Send**: When sending a message, if the peer is offline, save with
///    status `QUEUED` instead of sending over P2P.
/// 2. **Reconnect**: When a peer reconnects, query all QUEUED messages for
///    that peer and send them in chronological order.
/// 3. **ACK**: When a delivery ACK is received, update message status to
///    `DELIVERED`.
/// 4. **Dedup**: On the receiving side, check message ID before inserting
///    to prevent duplicates.
class SyncService {
  final AppDatabase _db;
  final P2PService _p2pService;
  final P2PMessageHandler _messageHandler;
  final EncryptionService _encryptionService;
  final IdentityService _identityService;

  StreamSubscription? _connectionSub;
  StreamSubscription? _ackSub;
  StreamSubscription? _syncRequestSub;
  StreamSubscription? _incomingMessageSub;

  SyncService({
    required AppDatabase db,
    required P2PService p2pService,
    required P2PMessageHandler messageHandler,
    required EncryptionService encryptionService,
    required IdentityService identityService,
  })  : _db = db,
        _p2pService = p2pService,
        _messageHandler = messageHandler,
        _encryptionService = encryptionService,
        _identityService = identityService;

  /// Start listening for connection changes and incoming messages.
  void startSync() {
    _messageHandler.startListening();

    // Listen for connection state changes to trigger sync
    _connectionSub = _p2pService.connectionStateStream.listen((state) {
      if (state == P2PConnectionState.connected) {
        _onPeerConnected();
      }
    });

    // Listen for delivery ACKs to update message status
    _ackSub = _messageHandler.deliveryAcks.listen(_handleDeliveryAck);

    // Listen for incoming sync requests
    _syncRequestSub = _messageHandler.syncRequests.listen(_handleSyncRequest);

    // Listen for incoming text messages
    _incomingMessageSub = _messageHandler.textMessages.listen(
      _handleIncomingMessage,
    );

    debugPrint('[Sync] Started.');
  }

  /// Stop all sync listeners.
  void dispose() {
    _connectionSub?.cancel();
    _ackSub?.cancel();
    _syncRequestSub?.cancel();
    _incomingMessageSub?.cancel();
    _messageHandler.dispose();
    debugPrint('[Sync] Disposed.');
  }

  // ─── Sending Messages ───

  /// Send a text message. If peer is offline, queues it for later delivery.
  Future<Message> sendTextMessage({
    required String conversationId,
    required String peerId,
    required String content,
    String? peerPublicKey,
  }) async {
    final messageId = IdGenerator.generateMessageId();
    final now = DateTime.now();
    final isOnline = _p2pService.isConnected;

    // Encrypt the message content if we have the peer's public key
    String? encryptedContent;
    if (peerPublicKey != null) {
      try {
        encryptedContent = await _encryptionService.encrypt(
          content,
          peerPublicKey,
        );
      } catch (e) {
        debugPrint('[Sync] Encryption failed, sending unencrypted: $e');
      }
    }

    // Determine initial status
    final initialStatus = isOnline ? MessageStatus.sending : MessageStatus.queued;

    // Save to local database
    final companion = MessagesCompanion.insert(
      id: messageId,
      conversationId: conversationId,
      senderId: _identityService.userId,
      content: content,
      encryptedContent: Value(encryptedContent),
      type: MessageType.text,
      status: initialStatus,
      isMine: const Value(true),
      timestamp: Value(now),
    );

    await _db.messageDao.insertMessage(companion);

    // Update conversation's last message
    await _db.conversationDao.updateLastMessage(
      conversationId,
      content,
      now,
    );

    // If online, send immediately
    if (isOnline) {
      final sent = await _p2pService.sendPayload(P2PPayload(
        type: PayloadType.textMessage,
        senderId: _identityService.userId,
        targetId: peerId,
        data: {
          'messageId': messageId,
          'conversationId': conversationId,
          'content': encryptedContent ?? content,
          'isEncrypted': encryptedContent != null,
          'timestamp': now.toIso8601String(),
        },
        timestamp: now,
      ));

      // Update status based on send result
      await _db.messageDao.updateStatus(
        messageId,
        sent ? MessageStatus.sent : MessageStatus.failed,
      );
    }

    // Return the saved message
    final saved = await _db.messageDao.getMessageById(messageId);
    return saved!;
  }

  // ─── Sync on Reconnection ───

  /// Called when a peer (re)connects. Sends all queued messages.
  Future<void> _onPeerConnected() async {
    debugPrint('[Sync] Peer connected — checking for queued messages...');

    // Send a sync request to let the peer know we're online
    await _p2pService.sendPayload(P2PPayload(
      type: PayloadType.syncRequest,
      senderId: _identityService.userId,
      data: {
        'peerInfo': _identityService.toPublicInfo(),
      },
    ));

    // Find and send all queued messages
    // In a real app, you'd filter by the specific peer's conversation
    final allConversations =
        await _db.conversationDao.watchAllConversations().first;

    for (final convo in allConversations) {
      final queuedMessages =
          await _db.messageDao.getQueuedMessagesForConversation(convo.id);

      if (queuedMessages.isEmpty) continue;

      debugPrint(
        '[Sync] Sending ${queuedMessages.length} queued messages for ${convo.title}',
      );

      for (final msg in queuedMessages) {
        // Re-send each queued message
        final sent = await _p2pService.sendPayload(P2PPayload(
          type: PayloadType.textMessage,
          senderId: _identityService.userId,
          targetId: convo.peerId,
          data: {
            'messageId': msg.id,
            'conversationId': msg.conversationId,
            'content': msg.encryptedContent ?? msg.content,
            'isEncrypted': msg.encryptedContent != null,
            'timestamp': msg.timestamp.toIso8601String(),
          },
        ));

        if (sent) {
          await _db.messageDao.updateStatus(msg.id, MessageStatus.sent);
        }
      }
    }
  }

  // ─── Handle Incoming Messages ───

  Future<void> _handleIncomingMessage(P2PPayload payload) async {
    final data = payload.data;
    final messageId = data['messageId'] as String;

    // Deduplication check
    if (await _db.messageDao.messageExists(messageId)) {
      debugPrint('[Sync] Duplicate message ignored: $messageId');
      return;
    }

    final conversationId = data['conversationId'] as String;
    final rawContent = data['content'] as String;
    final isEncrypted = data['isEncrypted'] as bool? ?? false;
    final timestamp = DateTime.parse(data['timestamp'] as String);

    // Decrypt if encrypted
    String plaintext = rawContent;
    if (isEncrypted) {
      try {
        // Get sender's public key from our database
        final sender = await _db.userDao.getUserById(payload.senderId);
        if (sender?.publicKey != null) {
          plaintext = await _encryptionService.decrypt(
            rawContent,
            sender!.publicKey!,
          );
        }
      } catch (e) {
        debugPrint('[Sync] Decryption failed: $e');
        plaintext = '[Encrypted message — key mismatch]';
      }
    }

    // Ensure conversation exists
    final existingConvo =
        await _db.conversationDao.getConversationById(conversationId);
    if (existingConvo == null) {
      // Create a new conversation for this peer
      final sender = await _db.userDao.getUserById(payload.senderId);
      await _db.conversationDao.upsertConversation(
        ConversationsCompanion.insert(
          id: conversationId,
          peerId: Value(payload.senderId),
          title: sender?.name ?? payload.senderId,
          avatarPath: Value(sender?.avatarPath),
          isPeerOnline: const Value(true),
        ),
      );
    }

    // Save the message locally
    await _db.messageDao.insertMessage(MessagesCompanion.insert(
      id: messageId,
      conversationId: conversationId,
      senderId: payload.senderId,
      content: plaintext,
      encryptedContent: Value(isEncrypted ? rawContent : null),
      type: MessageType.text,
      status: MessageStatus.delivered,
      isMine: const Value(false),
      timestamp: Value(timestamp),
    ));

    // Update conversation's last message and increment unread
    await _db.conversationDao.updateLastMessage(
      conversationId,
      plaintext,
      timestamp,
    );
    await _db.conversationDao.incrementUnread(conversationId);

    // Send delivery ACK back to sender
    await _p2pService.sendPayload(P2PPayload(
      type: PayloadType.deliveryAck,
      senderId: _identityService.userId,
      targetId: payload.senderId,
      data: {'messageId': messageId},
    ));

    debugPrint('[Sync] Message received and ACKed: $messageId');
  }

  // ─── Handle ACKs ───

  Future<void> _handleDeliveryAck(P2PPayload payload) async {
    final messageId = payload.data['messageId'] as String;
    await _db.messageDao.updateStatus(messageId, MessageStatus.delivered);
    debugPrint('[Sync] Message delivered: $messageId');
  }

  // ─── Handle Sync Requests ───

  Future<void> _handleSyncRequest(P2PPayload payload) async {
    debugPrint('[Sync] Sync request from ${payload.senderId}');

    // Update peer info in our database
    final peerInfo = payload.data['peerInfo'] as Map<String, dynamic>?;
    if (peerInfo != null) {
      await _db.userDao.upsertUser(UsersCompanion(
        id: Value(peerInfo['userId'] as String),
        name: Value(peerInfo['userName'] as String? ?? 'Unknown'),
        publicKey: Value(peerInfo['publicKey'] as String?),
        isOnline: const Value(true),
        lastSeen: Value(DateTime.now()),
      ));
    }

    // Send our own info back
    await _p2pService.sendPayload(P2PPayload(
      type: PayloadType.peerInfo,
      senderId: _identityService.userId,
      targetId: payload.senderId,
      data: {'peerInfo': _identityService.toPublicInfo()},
    ));
  }
}
