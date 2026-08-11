import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/id_generator.dart';
import '../encryption/encryption_service.dart';

/// Manages the local user's identity: unique ID, name, avatar, and keys.
///
/// On first launch, the user enters their name and optionally picks an avatar.
/// The service generates a unique User ID and an X25519 key pair.
/// The profile is persisted in SharedPreferences (non-sensitive data)
/// and FlutterSecureStorage (private key).
class IdentityService {
  static const _keyUserId = 'homelink_user_id';
  static const _keyUserName = 'homelink_user_name';
  static const _keyAvatarPath = 'homelink_avatar_path';
  static const _keyIsOnboarded = 'homelink_is_onboarded';

  final EncryptionService _encryptionService;

  String? _userId;
  String? _userName;
  String? _avatarPath;
  String? _publicKey;
  bool _isOnboarded = false;

  IdentityService(this._encryptionService);

  /// Initialize: load the saved profile (if any).
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString(_keyUserId);
    _userName = prefs.getString(_keyUserName);
    _avatarPath = prefs.getString(_keyAvatarPath);
    _isOnboarded = prefs.getBool(_keyIsOnboarded) ?? false;

    if (_isOnboarded) {
      await _encryptionService.initialize();
      _publicKey = await _encryptionService.getPublicKeyBase64();
    }

    debugPrint('[Identity] Loaded: id=$_userId, name=$_userName, onboarded=$_isOnboarded');
  }

  /// Create a new user profile during onboarding.
  Future<void> createProfile({
    required String name,
    String? avatarPath,
  }) async {
    // Generate unique user ID
    _userId = IdGenerator.generateUserId();
    _userName = name;
    _avatarPath = avatarPath;

    // Generate encryption key pair
    await _encryptionService.generateKeyPair();
    _publicKey = await _encryptionService.getPublicKeyBase64();

    // Persist to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, _userId!);
    await prefs.setString(_keyUserName, _userName!);
    if (_avatarPath != null) {
      await prefs.setString(_keyAvatarPath, _avatarPath!);
    }
    await prefs.setBool(_keyIsOnboarded, true);
    _isOnboarded = true;

    debugPrint('[Identity] Profile created: $_userId ($_userName)');
  }

  /// Update the user's display name.
  Future<void> updateName(String name) async {
    _userName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
  }

  /// Update the user's avatar path.
  Future<void> updateAvatar(String path) async {
    _avatarPath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAvatarPath, path);
  }

  /// Serialize this user's public info for sharing with peers.
  Map<String, dynamic> toPublicInfo() => {
        'userId': _userId,
        'userName': _userName,
        'avatarPath': _avatarPath,
        'publicKey': _publicKey,
      };

  // ─── Getters ───

  String get userId => _userId ?? '';
  String get userName => _userName ?? 'Unknown';
  String? get avatarPath => _avatarPath;
  String? get publicKey => _publicKey;
  bool get isOnboarded => _isOnboarded;
}
