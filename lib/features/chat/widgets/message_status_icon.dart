import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../../../data/database/tables/messages_table.dart';

/// Displays message delivery status as tick icons (WhatsApp-style).
///
/// - `sending` / `queued`: Clock icon (grey)
/// - `sent`: Single tick (grey) ✓
/// - `delivered`: Double tick (grey) ✓✓
/// - `read`: Double tick (blue) ✓✓
/// - `failed`: Error icon (red)
class MessageStatusIcon extends StatelessWidget {
  final MessageStatus status;
  final double size;

  const MessageStatusIcon({
    super.key,
    required this.status,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
      case MessageStatus.queued:
        return Icon(
          Icons.access_time_rounded,
          size: size,
          color: AppColors.tickGrey,
        );
      case MessageStatus.sent:
        return Icon(
          Icons.check_rounded,
          size: size,
          color: AppColors.tickGrey,
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all_rounded,
          size: size,
          color: AppColors.tickGrey,
        );
      case MessageStatus.read:
        return Icon(
          Icons.done_all_rounded,
          size: size,
          color: AppColors.tickBlue,
        );
      case MessageStatus.failed:
        return Icon(
          Icons.error_outline_rounded,
          size: size,
          color: AppColors.error,
        );
    }
  }
}
