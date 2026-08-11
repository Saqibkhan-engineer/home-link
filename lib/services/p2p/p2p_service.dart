import 'dart:async';

/// Represents a discovered peer on the local network.
class DiscoveredPeer {
  final String deviceId;
  final String displayName;
  final String? userId;
  final String? avatarPath;

  const DiscoveredPeer({
    required this.deviceId,
    required this.displayName,
    this.userId,
    this.avatarPath,
  });

  @override
  String toString() => 'DiscoveredPeer($displayName, $deviceId)';
}

/// Represents the current P2P connection state.
enum P2PConnectionState {
  idle,
  discovering,
  connecting,
  connected,
  disconnected,
  error,
}

/// Represents the role this device plays in the P2P network.
enum P2PRole { host, client, none }

/// Payload types sent over the P2P data channel.
enum PayloadType {
  textMessage,
  fileTransfer,
  deliveryAck,
  readAck,
  webrtcSignal,
  syncRequest,
  syncResponse,
  peerInfo,
  ping,
  pong,
}

/// A serializable payload for P2P communication.
class P2PPayload {
  final PayloadType type;
  final String senderId;
  final String? targetId;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  P2PPayload({
    required this.type,
    required this.senderId,
    this.targetId,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'senderId': senderId,
        'targetId': targetId,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  factory P2PPayload.fromJson(Map<String, dynamic> json) => P2PPayload(
        type: PayloadType.values.byName(json['type'] as String),
        senderId: json['senderId'] as String,
        targetId: json['targetId'] as String?,
        data: Map<String, dynamic>.from(json['data'] as Map),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// Abstract P2P service interface.
///
/// This allows us to swap implementations for different platforms:
/// - Android: [AndroidP2PService] (flutter_p2p_connection)
/// - iOS: Future implementation using MultipeerConnectivity
abstract class P2PService {
  /// Initialize the P2P service and request necessary permissions.
  Future<bool> initialize();

  /// Dispose of all resources.
  Future<void> dispose();

  // ─── Host Operations ───

  /// Start advertising this device as a host (creates Wi-Fi Direct group).
  Future<bool> startHost();

  /// Stop hosting.
  Future<void> stopHost();

  // ─── Client Operations ───

  /// Start scanning for nearby host devices.
  Future<bool> startDiscovery();

  /// Stop scanning.
  Future<void> stopDiscovery();

  /// Connect to a discovered peer.
  Future<bool> connectToPeer(DiscoveredPeer peer);

  /// Disconnect from the current peer.
  Future<void> disconnect();

  // ─── Data Transfer ───

  /// Send a text payload to connected peer(s).
  Future<bool> sendPayload(P2PPayload payload);

  /// Send a file to connected peer(s).
  Future<bool> sendFile(String filePath, {String? targetId});

  // ─── Streams ───

  /// Stream of discovered peers during scanning.
  Stream<List<DiscoveredPeer>> get discoveredPeersStream;

  /// Stream of incoming P2P payloads.
  Stream<P2PPayload> get incomingPayloadStream;

  /// Stream of connection state changes.
  Stream<P2PConnectionState> get connectionStateStream;

  /// Stream of file transfer progress (0.0 to 1.0).
  Stream<double> get fileTransferProgressStream;

  // ─── State ───

  /// Current connection state.
  P2PConnectionState get currentState;

  /// Current role (host/client/none).
  P2PRole get currentRole;

  /// List of currently connected peer IDs.
  List<String> get connectedPeerIds;

  /// Whether this device is currently connected to any peer.
  bool get isConnected;
}
