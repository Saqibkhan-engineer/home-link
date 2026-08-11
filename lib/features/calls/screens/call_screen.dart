import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_formatter.dart';

/// Full-screen voice call UI.
class CallScreen extends ConsumerStatefulWidget {
  final String peerId;
  final String peerName;
  final String? peerAvatar;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.peerAvatar,
    this.isIncoming = false,
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen>
    with SingleTickerProviderStateMixin {
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isConnected = false;
  Duration _callDuration = Duration.zero;
  Timer? _durationTimer;
  String _callStatus = '';

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _callStatus =
        widget.isIncoming ? AppStrings.incoming : AppStrings.calling;

    // Simulate call connection (in production, this would use WebRTC)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isConnected = true;
          _callStatus = AppStrings.inCall;
        });
        _startDurationTimer();
      }
    });
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration += const Duration(seconds: 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _endCall() {
    _durationTimer?.cancel();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Peer avatar with pulse animation
            AnimatedBuilder(
              listenable: _pulseController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!_isConnected) ...[
                      // Outer pulse
                      Transform.scale(
                        scale: 1 + (_pulseController.value * 0.4),
                        child: Opacity(
                          opacity: 1 - _pulseController.value,
                          child: Container(
                            width: 140,
                            height: 140,
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
                    ],
                    // Avatar
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: AppColors.darkSurface,
                      backgroundImage: widget.peerAvatar != null
                          ? FileImage(File(widget.peerAvatar!))
                          : null,
                      child: widget.peerAvatar == null
                          ? Text(
                              widget.peerName.isNotEmpty
                                  ? widget.peerName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            )
                          : null,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 28),

            // Peer name
            Text(
              widget.peerName,
              style: Theme.of(context).textTheme.headlineMedium,
            ),

            const SizedBox(height: 8),

            // Call status / duration
            Text(
              _isConnected
                  ? DateFormatter.formatCallDuration(_callDuration)
                  : _callStatus,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _isConnected
                        ? AppColors.accent
                        : AppColors.textSecondary,
                    fontSize: 16,
                  ),
            ),

            const Spacer(flex: 3),

            // Call action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute
                  _CallActionButton(
                    icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: 'Mute',
                    isActive: _isMuted,
                    onTap: () {
                      setState(() => _isMuted = !_isMuted);
                    },
                  ),

                  // End Call
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.call_end_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),

                  // Speaker
                  _CallActionButton(
                    icon: _isSpeaker
                        ? Icons.volume_up_rounded
                        : Icons.volume_down_rounded,
                    label: 'Speaker',
                    isActive: _isSpeaker,
                    onTap: () {
                      setState(() => _isSpeaker = !_isSpeaker);
                    },
                  ),
                ],
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.textPrimary.withOpacity(0.2)
                  : AppColors.darkSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive ? AppColors.accent : AppColors.textSecondary,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
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
    required Listenable listenable,
    required this.builder,
  }) : super(listenable: listenable);

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}
