import 'dart:async';
import 'package:flutter/foundation.dart';

import 'p2p_service.dart';

/// Routes incoming P2P payloads to the correct handler based on [PayloadType].
///
/// This acts as a central dispatcher: the P2P service emits raw payloads,
/// and this handler routes them to chat, sync, call, or ACK handlers.
class P2PMessageHandler {
  final P2PService _p2pService;
  StreamSubscription? _subscription;

  // ─── Output Streams ───
  final _textMessageController = StreamController<P2PPayload>.broadcast();
  final _deliveryAckController = StreamController<P2PPayload>.broadcast();
  final _readAckController = StreamController<P2PPayload>.broadcast();
  final _webrtcSignalController = StreamController<P2PPayload>.broadcast();
  final _syncRequestController = StreamController<P2PPayload>.broadcast();
  final _syncResponseController = StreamController<P2PPayload>.broadcast();
  final _peerInfoController = StreamController<P2PPayload>.broadcast();
  final _fileTransferController = StreamController<P2PPayload>.broadcast();

  P2PMessageHandler(this._p2pService);

  /// Start listening for incoming payloads and routing them.
  void startListening() {
    _subscription?.cancel();
    _subscription = _p2pService.incomingPayloadStream.listen(
      _routePayload,
      onError: (e) => debugPrint('[MessageHandler] Stream error: $e'),
    );
    debugPrint('[MessageHandler] Started listening.');
  }

  /// Stop listening.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    debugPrint('[MessageHandler] Stopped listening.');
  }

  /// Dispose of all controllers.
  void dispose() {
    stopListening();
    _textMessageController.close();
    _deliveryAckController.close();
    _readAckController.close();
    _webrtcSignalController.close();
    _syncRequestController.close();
    _syncResponseController.close();
    _peerInfoController.close();
    _fileTransferController.close();
  }

  void _routePayload(P2PPayload payload) {
    debugPrint('[MessageHandler] Routing: ${payload.type.name}');

    switch (payload.type) {
      case PayloadType.textMessage:
        _textMessageController.add(payload);
        break;
      case PayloadType.fileTransfer:
        _fileTransferController.add(payload);
        break;
      case PayloadType.deliveryAck:
        _deliveryAckController.add(payload);
        break;
      case PayloadType.readAck:
        _readAckController.add(payload);
        break;
      case PayloadType.webrtcSignal:
        _webrtcSignalController.add(payload);
        break;
      case PayloadType.syncRequest:
        _syncRequestController.add(payload);
        break;
      case PayloadType.syncResponse:
        _syncResponseController.add(payload);
        break;
      case PayloadType.peerInfo:
        _peerInfoController.add(payload);
        break;
      case PayloadType.ping:
        // Respond with pong
        _p2pService.sendPayload(P2PPayload(
          type: PayloadType.pong,
          senderId: payload.targetId ?? '',
          targetId: payload.senderId,
          data: const {},
        ));
        break;
      case PayloadType.pong:
        // Heartbeat response — update peer's "last seen"
        debugPrint('[MessageHandler] Pong from ${payload.senderId}');
        break;
    }
  }

  // ─── Public Streams ───

  /// Stream of incoming text messages (chat messages).
  Stream<P2PPayload> get textMessages => _textMessageController.stream;

  /// Stream of delivery acknowledgements.
  Stream<P2PPayload> get deliveryAcks => _deliveryAckController.stream;

  /// Stream of read acknowledgements.
  Stream<P2PPayload> get readAcks => _readAckController.stream;

  /// Stream of WebRTC signaling messages (SDP, ICE).
  Stream<P2PPayload> get webrtcSignals => _webrtcSignalController.stream;

  /// Stream of sync requests (from a peer that just reconnected).
  Stream<P2PPayload> get syncRequests => _syncRequestController.stream;

  /// Stream of sync responses (queued messages being delivered).
  Stream<P2PPayload> get syncResponses => _syncResponseController.stream;

  /// Stream of peer info broadcasts (name, avatar, public key).
  Stream<P2PPayload> get peerInfoUpdates => _peerInfoController.stream;

  /// Stream of file transfer notifications.
  Stream<P2PPayload> get fileTransfers => _fileTransferController.stream;
}
