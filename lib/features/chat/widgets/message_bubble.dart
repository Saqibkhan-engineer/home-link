import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/database/tables/messages_table.dart';
import 'message_status_icon.dart';

/// A single chat bubble (WhatsApp-style).
/// Right-aligned teal for sent; left-aligned dark grey for received.
class MessageBubble extends StatelessWidget {
  final String content;
  final DateTime timestamp;
  final bool isMine;
  final MessageStatus status;
  final MessageType messageType;
  final String? fileName;

  const MessageBubble({
    super.key,
    required this.content,
    required this.timestamp,
    required this.isMine,
    required this.status,
    this.messageType = MessageType.text,
    this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: EdgeInsets.only(
          left: isMine ? 64 : 12,
          right: isMine ? 12 : 64,
          top: 2,
          bottom: 2,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMine ? AppColors.sentBubble : AppColors.receivedBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMine ? 12 : 2),
            bottomRight: Radius.circular(isMine ? 2 : 12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Message content
            if (messageType == MessageType.file && fileName != null)
              _buildFileAttachment(context)
            else
              Text(
                content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
              ),

            const SizedBox(height: 3),

            // Timestamp + status ticks
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormatter.formatMessageTime(timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withOpacity(0.7),
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  MessageStatusIcon(status: status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileAttachment(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.insert_drive_file_rounded,
            color: AppColors.accent,
            size: 28,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            fileName ?? 'File',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
