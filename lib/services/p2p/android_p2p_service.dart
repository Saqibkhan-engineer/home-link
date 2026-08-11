import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:permission_handler/permission_handler.dart';

import 'p2p_service.dart';

/// Android implementation of [P2PService] using flutter_p2p_connection.
///
/// Uses the Host/Client role-based architecture:
/// - **Host**: Creates a Wi-Fi Direct group (hotspot) and accepts connections.
/// - **Client**: Discovers hosts via BLE and connects to them.
///
/// The first device in the household to open the app becomes the Host.
/// Subsequent devices join as Clients.
class AndroidP2PService implements P2PService {
  FlutterP2pHost? _host;
  FlutterP2pClient? _client;

  P2PRole _role = P2PRole.none;
  P2PConnectionState _state = P2PConnectionState.idle;

  final _discoveredPeersController = StreamController<List<DiscoveredPeer>>.broadcast();
  final _incomingPayloadController = StreamController<P2PPayload>.broadcast();
  final _connectionStateController = StreamController<P2PConnectionState>.broadcast();
  final _fileProgressController = StreamController<double>.broadcast();

  final List<DiscoveredPeer> _discoveredPeers = [];
  final List<String> _connectedPeers = [];

  @override
  Future<bool> initialize() async {
    try {
      // Request all necessary permissions for Wi-Fi Direct
      final statuses = await [
        Permission.nearbyWifiDevices,
        Permission.locationWhenInUse,
        Permission.bluetooth,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.storage,
      ].request();

      final allGranted = statuses.values.every(
        (s) => s.isGranted || s.isLimited,
      );

      if (!allGranted) {
        debugPrint('[P2P] Not all permissions granted: $statuses');
        return false;
      }

      debugPrint('[P2P] All permissions granted. Ready.');
      return true;
    } catch (e) {
      debugPrint('[P2P] Initialize error: $e');
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    await stopHost();
    await stopDiscovery();
    _host?.dispose();
    _client?.dispose();
    _discoveredPeersController.close();
    _incomingPayloadController.close();
    _connectionStateController.close();
    _fileProgressController.close();
  }

  // ─── Host Operations ───

  @override
  Future<bool> startHost() async {
    try {
      _host = FlutterP2pHost();
      await _host!.initialize();

      _role = P2PRole.host;
      _updateState(P2PConnectionState.discovering);

      // Start the host's Wi-Fi Direct group
      await _host!.createGroup();

      // Listen for incoming client connections
      _host!.streamClientList().listen((clients) {
        _connectedPeers.clear();
        for (final client in clients) {
          _connectedPeers.add(client.id);
        }
        if (_connectedPeers.isNotEmpty) {
          _updateState(P2PConnectionState.connected);
        }
        debugPrint('[P2P Host] Connected clients: ${_connectedPeers.length}');
      });

      // Listen for incoming text messages from clients
      _host!.streamReceivedTexts().listen((message) {
        _handleIncomingText(message);
      });

      debugPrint('[P2P] Host started successfully.');
      return true;
    } catch (e) {
      debugPrint('[P2P] Start host error: $e');
      _updateState(P2PConnectionState.error);
      return false;
    }
  }

  @override
  Future<void> stopHost() async {
    try {
      await _host?.removeGroup();
      _role = P2PRole.none;
      _connectedPeers.clear();
      _updateState(P2PConnectionState.idle);
      debugPrint('[P2P] Host stopped.');
    } catch (e) {
      debugPrint('[P2P] Stop host error: $e');
    }
  }

  // ─── Client Operations ───

  @override
  Future<bool> startDiscovery() async {
    try {
      _client = FlutterP2pClient();
      await _client!.initialize();

      _role = P2PRole.client;
      _updateState(P2PConnectionState.discovering);
      _discoveredPeers.clear();

      // Start BLE-based discovery for nearby hosts
      await _client!.startScan((hosts) {
        _discoveredPeers.clear();
        for (final host in hosts) {
          _discoveredPeers.add(DiscoveredPeer(
            deviceId: host.deviceAddress,
            displayName: host.deviceName,
            originalDevice: host,
          ));
        }
        _discoveredPeersController.add(List.from(_discoveredPeers));
        debugPrint('[P2P Client] Discovered ${_discoveredPeers.length} hosts.');
      });

      // Listen for incoming text messages from host
      _client!.streamReceivedTexts().listen((message) {
        _handleIncomingText(message);
      });

      debugPrint('[P2P] Client discovery started.');
      return true;
    } catch (e) {
      debugPrint('[P2P] Start discovery error: $e');
      _updateState(P2PConnectionState.error);
      return false;
    }
  }

  @override
  Future<void> stopDiscovery() async {
    try {
      await _client?.stopScan();
      _discoveredPeers.clear();
      _discoveredPeersController.add([]);
      debugPrint('[P2P] Discovery stopped.');
    } catch (e) {
      debugPrint('[P2P] Stop discovery error: $e');
    }
  }

  @override
  Future<bool> connectToPeer(DiscoveredPeer peer) async {
    try {
      _updateState(P2PConnectionState.connecting);

      // Connect to the host using its discovered credentials
      await _client!.connectWithDevice(peer.originalDevice as BleDiscoveredDevice);

      _connectedPeers.add(peer.deviceId);
      _updateState(P2PConnectionState.connected);
      debugPrint('[P2P] Connected to peer: ${peer.displayName}');
      return true;
    } catch (e) {
      debugPrint('[P2P] Connect error: $e');
      _updateState(P2PConnectionState.error);
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      if (_role == P2PRole.client) {
        await _client?.disconnect();
      } else if (_role == P2PRole.host) {
        await stopHost();
      }
      _connectedPeers.clear();
      _updateState(P2PConnectionState.disconnected);
      debugPrint('[P2P] Disconnected.');
    } catch (e) {
      debugPrint('[P2P] Disconnect error: $e');
    }
  }

  // ─── Data Transfer ───

  @override
  Future<bool> sendPayload(P2PPayload payload) async {
    try {
      final jsonStr = jsonEncode(payload.toJson());

      if (_role == P2PRole.host) {
        // Broadcast to all connected clients, or target specific one
        _host!.broadcastText(jsonStr);
      } else if (_role == P2PRole.client) {
        _client!.broadcastText(jsonStr);
      } else {
        debugPrint('[P2P] Cannot send: no active role.');
        return false;
      }

      debugPrint('[P2P] Payload sent: ${payload.type.name}');
      return true;
    } catch (e) {
      debugPrint('[P2P] Send payload error: $e');
      return false;
    }
  }

  @override
  Future<bool> sendFile(String filePath, {String? targetId}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('[P2P] File not found: $filePath');
        return false;
      }

      // Check file size limit (50MB)
      final size = await file.length();
      if (size > 50 * 1024 * 1024) {
        debugPrint('[P2P] File too large: ${size ~/ (1024 * 1024)}MB (max 50MB)');
        return false;
      }

      if (_role == P2PRole.host) {
        await _host!.broadcastFile(file);
      } else if (_role == P2PRole.client) {
        await _client!.broadcastFile(file);
      } else {
        return false;
      }

      debugPrint('[P2P] File sent: $filePath');
      return true;
    } catch (e) {
      debugPrint('[P2P] Send file error: $e');
      return false;
    }
  }

  // ─── Internal Helpers ───

  void _handleIncomingText(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final payload = P2PPayload.fromJson(json);
      _incomingPayloadController.add(payload);
      debugPrint('[P2P] Received payload: ${payload.type.name} from ${payload.senderId}');
    } catch (e) {
      debugPrint('[P2P] Failed to parse incoming text: $e');
    }
  }

  void _updateState(P2PConnectionState newState) {
    _state = newState;
    _connectionStateController.add(newState);
    debugPrint('[P2P] State -> ${newState.name}');
  }

  // ─── Streams ───

  @override
  Stream<List<DiscoveredPeer>> get discoveredPeersStream =>
      _discoveredPeersController.stream;

  @override
  Stream<P2PPayload> get incomingPayloadStream =>
      _incomingPayloadController.stream;

  @override
  Stream<P2PConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  @override
  Stream<double> get fileTransferProgressStream =>
      _fileProgressController.stream;

  // ─── State Getters ───

  @override
  P2PConnectionState get currentState => _state;

  @override
  P2PRole get currentRole => _role;

  @override
  List<String> get connectedPeerIds => List.unmodifiable(_connectedPeers);

  @override
  bool get isConnected => _state == P2PConnectionState.connected;
}
