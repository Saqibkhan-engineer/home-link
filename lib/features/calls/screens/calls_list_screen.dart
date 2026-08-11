import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/database/tables/call_logs_table.dart';
import '../../../data/database/app_database.dart';
import '../../../main.dart';

/// Reactive provider that watches all call logs.
final callLogsStreamProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.callLogDao.watchAllCallLogs();
});

/// Call history list tab.
class CallsListScreen extends ConsumerWidget {
  const CallsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callLogsAsync = ref.watch(callLogsStreamProvider);

    return callLogsAsync.when(
      data: (logs) {
        if (logs.isEmpty) {
          return _buildEmptyState(context);
        }

        return ListView.builder(
          itemCount: logs.length,
          padding: const EdgeInsets.only(top: 8),
          itemBuilder: (context, index) {
            final log = logs[index];
            return _buildCallTile(context, log);
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (e, _) => Center(
        child:
            Text('Error: $e', style: const TextStyle(color: AppColors.error)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.1),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.call_outlined,
              size: 56,
              color: AppColors.accent.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.noCalls,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.noCallsSubtitle,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCallTile(BuildContext context, CallLog log) {
    final isMissed = log.status == CallStatus.missed;
    final isOutgoing = log.status == CallStatus.outgoing;

    IconData statusIcon = Icons.call_missed_rounded;
    Color statusColor = AppColors.error;

    switch (log.status) {
      case CallStatus.missed:
        statusIcon = Icons.call_missed_rounded;
        statusColor = AppColors.error;
        break;
      case CallStatus.answered:
        statusIcon = Icons.call_received_rounded;
        statusColor = AppColors.accent;
        break;
      case CallStatus.outgoing:
        statusIcon = Icons.call_made_rounded;
        statusColor = AppColors.accent;
        break;
      case CallStatus.rejected:
        statusIcon = Icons.call_missed_outgoing_rounded;
        statusColor = AppColors.error;
        break;
    }

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.darkInput,
        child: Text(
          log.peerName.isNotEmpty ? log.peerName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Text(
        log.peerName,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: isMissed ? AppColors.error : AppColors.textPrimary,
            ),
      ),
      subtitle: Row(
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 4),
          Text(
            DateFormatter.formatChatListTime(log.timestamp),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (log.durationSeconds > 0) ...[
            const SizedBox(width: 8),
            Text(
              DateFormatter.formatCallDuration(
                Duration(seconds: log.durationSeconds),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.call_rounded, color: AppColors.accent),
        onPressed: () {
          Navigator.pushNamed(context, '/call', arguments: {
            'peerId': log.peerId,
            'peerName': log.peerName,
            'peerAvatar': null,
            'isIncoming': false,
          });
        },
      ),
    );
  }
}
