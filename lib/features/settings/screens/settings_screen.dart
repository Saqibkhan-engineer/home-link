import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../main.dart';
import '../../../services/p2p/p2p_service.dart';

/// Settings screen — user profile, QR code, network status, storage usage.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(identityServiceProvider);
    final p2p = ref.watch(p2pServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkAppBar,
        title: const Text(AppStrings.settings),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),

          // ─── Profile Card ───
          _buildProfileCard(context, identity),

          const SizedBox(height: 24),

          // ─── My Unique ID with QR ───
          _buildIdCard(context, identity),

          const SizedBox(height: 24),

          // ─── Network Status ───
          _buildSettingsSection(
            context,
            title: AppStrings.networkStatus,
            children: [
              _buildSettingsTile(
                context,
                icon: Icons.wifi_tethering_rounded,
                iconColor: p2p.isConnected ? AppColors.online : AppColors.offline,
                title: 'P2P Connection',
                subtitle: p2p.isConnected
                    ? 'Connected (${p2p.currentRole.name})'
                    : 'Disconnected',
              ),
              _buildSettingsTile(
                context,
                icon: Icons.devices_rounded,
                iconColor: AppColors.primaryLight,
                title: 'Connected Devices',
                subtitle: '${p2p.connectedPeerIds.length} device(s)',
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ─── About ───
          _buildSettingsSection(
            context,
            title: AppStrings.about,
            children: [
              _buildSettingsTile(
                context,
                icon: Icons.info_outline_rounded,
                iconColor: AppColors.textSecondary,
                title: AppStrings.appName,
                subtitle: AppStrings.version,
              ),
              _buildSettingsTile(
                context,
                icon: Icons.lock_outline_rounded,
                iconColor: AppColors.accent,
                title: 'End-to-End Encryption',
                subtitle: 'All messages are encrypted with AES-256-GCM',
              ),
              _buildSettingsTile(
                context,
                icon: Icons.cloud_off_rounded,
                iconColor: AppColors.warning,
                title: '100% Offline',
                subtitle: 'No internet, no servers, no data collection',
              ),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, dynamic identity) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.darkInput,
            backgroundImage: identity.avatarPath != null
                ? FileImage(File(identity.avatarPath!))
                : null,
            child: identity.avatarPath == null
                ? Text(
                    identity.userName.isNotEmpty
                        ? identity.userName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  identity.userName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  identity.userId,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.accent,
                        letterSpacing: 1,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.edit_rounded,
              color: AppColors.textSecondary,
            ),
            onPressed: () {
              // TODO: Edit profile
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIdCard(BuildContext context, dynamic identity) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Text(
            AppStrings.yourUniqueId,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          // QR Code
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: identity.userId,
              version: QrVersions.auto,
              size: 160,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                color: Color(0xFF075E54),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                color: Color(0xFF111B21),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ID text
          SelectableText(
            identity.userId,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Other family members can scan this QR\nor enter your ID to connect.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: onTap,
    );
  }
}
