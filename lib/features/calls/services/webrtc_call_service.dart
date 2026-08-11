import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../p2p/p2p_message_handler.dart';
import '../p2p/p2p_service.dart';

/// WebRTC-based voice call service for P2P calls over the local network.
///
/// Since there is no server, signaling (SDP offer/answer + ICE candidates)
/// is exchanged over the existing P2P data channel.
///
/// Flow:
/// 1. Caller creates an SDP offer and sends it via P2P.
/// 2. Callee receives the offer, creates an SDP answer, sends it back.
/// 3. Both parties exchange ICE candidates via P2P.
/// 4. Audio stream is established directly between devices.
class WebRTCCallService {
  final P2PService _p2pService;
  final P2PMessageHandler _messageHandler;
  final String _localUserId;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  StreamSubscription? _signalSub;

  // Call state
  bool _isInCall = false;
  String? _remotePeerId;
  final _callStateController = StreamController<CallState>.broadcast();

  WebRTCCallService({
    required P2PService p2pService,
    required P2PMessageHandler messageHandler,
    required String localUserId,
  })  : _p2pService = p2pService,
        _messageHandler = messageHandler,
        _localUserId = localUserId;

  /// Start listening for incoming call signals.
  void initialize() {
    _signalSub = _messageHandler.webrtcSignals.listen(_handleSignal);
    debugPrint('[WebRTC] Initialized, listening for signals.');
  }

  /// Dispose of all resources.
  Future<void> dispose() async {
    _signalSub?.cancel();
    await endCall();
    _callStateController.close();
  }

  // ─── Outgoing Call ───

  /// Initiate a voice call to a peer.
  Future<void> startCall(String peerId) async {
    if (_isInCall) {
      debugPrint('[WebRTC] Already in a call.');
      return;
    }

    _remotePeerId = peerId;
    _updateCallState(CallState.calling);

    try {
      // Create peer connection
      await _createPeerConnection();

      // Get microphone audio
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });

      // Add audio track to peer connection
      _localStream!.getAudioTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // Create SDP offer
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // Send offer via P2P data channel
      await _p2pService.sendPayload(P2PPayload(
        type: PayloadType.webrtcSignal,
        senderId: _localUserId,
        targetId: peerId,
        data: {
          'signalType': 'offer',
          'sdp': offer.sdp,
          'sdpType': offer.type,
        },
      ));

      _isInCall = true;
      debugPrint('[WebRTC] Offer sent to $peerId.');
    } catch (e) {
      debugPrint('[WebRTC] Start call error: $e');
      _updateCallState(CallState.error);
    }
  }

  /// End the current call.
  Future<void> endCall() async {
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;

    await _peerConnection?.close();
    _peerConnection = null;

    if (_isInCall && _remotePeerId != null) {
      // Notify the remote peer
      await _p2pService.sendPayload(P2PPayload(
        type: PayloadType.webrtcSignal,
        senderId: _localUserId,
        targetId: _remotePeerId,
        data: {'signalType': 'hangup'},
      ));
    }

    _isInCall = false;
    _remotePeerId = null;
    _updateCallState(CallState.ended);
    debugPrint('[WebRTC] Call ended.');
  }

  // ─── Signaling Handler ───

  Future<void> _handleSignal(P2PPayload payload) async {
    final signalType = payload.data['signalType'] as String;

    switch (signalType) {
      case 'offer':
        await _handleOffer(payload);
        break;
      case 'answer':
        await _handleAnswer(payload);
        break;
      case 'candidate':
        await _handleCandidate(payload);
        break;
      case 'hangup':
        await endCall();
        break;
    }
  }

  Future<void> _handleOffer(P2PPayload payload) async {
    debugPrint('[WebRTC] Received offer from ${payload.senderId}.');
    _remotePeerId = payload.senderId;
    _updateCallState(CallState.ringing);

    // Auto-answer for now (in production, show incoming call UI)
    await _createPeerConnection();

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    _localStream!.getAudioTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    final remoteSdp = RTCSessionDescription(
      payload.data['sdp'] as String?,
      payload.data['sdpType'] as String?,
    );
    await _peerConnection!.setRemoteDescription(remoteSdp);

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    await _p2pService.sendPayload(P2PPayload(
      type: PayloadType.webrtcSignal,
      senderId: _localUserId,
      targetId: payload.senderId,
      data: {
        'signalType': 'answer',
        'sdp': answer.sdp,
        'sdpType': answer.type,
      },
    ));

    _isInCall = true;
    _updateCallState(CallState.connected);
    debugPrint('[WebRTC] Answer sent.');
  }

  Future<void> _handleAnswer(P2PPayload payload) async {
    debugPrint('[WebRTC] Received answer.');
    final remoteSdp = RTCSessionDescription(
      payload.data['sdp'] as String?,
      payload.data['sdpType'] as String?,
    );
    await _peerConnection!.setRemoteDescription(remoteSdp);
    _updateCallState(CallState.connected);
  }

  Future<void> _handleCandidate(P2PPayload payload) async {
    final candidate = RTCIceCandidate(
      payload.data['candidate'] as String?,
      payload.data['sdpMid'] as String?,
      payload.data['sdpMLineIndex'] as int?,
    );
    await _peerConnection!.addCandidate(candidate);
    debugPrint('[WebRTC] ICE candidate added.');
  }

  // ─── Peer Connection Setup ───

  Future<void> _createPeerConnection() async {
    // No STUN/TURN needed for local network
    final config = <String, dynamic>{
      'iceServers': <Map<String, dynamic>>[],
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(config);

    // Handle ICE candidates
    _peerConnection!.onIceCandidate = (candidate) {
      if (_remotePeerId != null) {
        _p2pService.sendPayload(P2PPayload(
          type: PayloadType.webrtcSignal,
          senderId: _localUserId,
          targetId: _remotePeerId,
          data: {
            'signalType': 'candidate',
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        ));
      }
    };

    // Handle connection state changes
    _peerConnection!.onConnectionState = (state) {
      debugPrint('[WebRTC] Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _updateCallState(CallState.error);
      }
    };

    // Handle remote audio stream
    _peerConnection!.onTrack = (event) {
      debugPrint('[WebRTC] Remote audio track received.');
      // Audio plays automatically through the device speaker
    };
  }

  // ─── State ───

  void _updateCallState(CallState state) {
    _callStateController.add(state);
  }

  Stream<CallState> get callStateStream => _callStateController.stream;
  bool get isInCall => _isInCall;
}

/// Possible call states.
enum CallState {
  idle,
  calling,
  ringing,
  connected,
  ended,
  error,
}
