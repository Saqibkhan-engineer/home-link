import 'package:intl/intl.dart';

/// Utility for formatting dates and times in chat UI.
class DateFormatter {
  DateFormatter._();

  /// Formats a timestamp for the chat list (e.g., "2:30 PM", "Yesterday", "12/25/2025").
  static String formatChatListTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return DateFormat('h:mm a').format(dateTime);
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (messageDate == yesterday) {
      return 'Yesterday';
    }

    final weekAgo = today.subtract(const Duration(days: 7));
    if (messageDate.isAfter(weekAgo)) {
      return DateFormat('EEEE').format(dateTime); // e.g., "Monday"
    }

    return DateFormat('M/d/yyyy').format(dateTime);
  }

  /// Formats a timestamp for inside a chat bubble (e.g., "2:30 PM").
  static String formatMessageTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  /// Formats a call duration (e.g., "02:34").
  static String formatCallDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final hours = duration.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  /// Formats "last seen" text (e.g., "last seen today at 2:30 PM").
  static String formatLastSeen(DateTime? dateTime) {
    if (dateTime == null) return 'Offline';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final seenDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final time = DateFormat('h:mm a').format(dateTime);

    if (seenDate == today) {
      return 'last seen today at $time';
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (seenDate == yesterday) {
      return 'last seen yesterday at $time';
    }

    final date = DateFormat('M/d/yyyy').format(dateTime);
    return 'last seen $date at $time';
  }

  /// Formats a date header for chat grouping (e.g., "Today", "Yesterday", "August 10, 2025").
  static String formatDateHeader(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) return 'Today';

    final yesterday = today.subtract(const Duration(days: 1));
    if (messageDate == yesterday) return 'Yesterday';

    return DateFormat('MMMM d, yyyy').format(dateTime);
  }
}
