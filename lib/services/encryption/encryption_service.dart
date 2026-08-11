import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// End-to-end encryption service using X25519 key exchange and AES-256-GCM.
///
/// Flow:
/// 1. On profile creation, generate an X25519 key pair.
/// 2. Store private key in secure storage; share public key with peers.
/// 3. When messaging, derive a shared secret via X25519 (our private + peer's public).
/// 4. Encrypt messages with AES-256-GCM using the shared secret.
class EncryptionService {
  static const _privateKeyStorageKey = 'homelink_private_key';
  static const _publicKeyStorageKey = 'homelink_public_key';

  final _secureStorage = const FlutterSecureStorage();
  final _keyExchange = X25519();
  final _cipher = AesGcm.with256bits();

  SimpleKeyPair? _keyPair;

  /// Initialize the encryption service: load or generate the key pair.
  Future<void> initialize() async {
    final storedPrivate = await _secureStorage.read(key: _privateKeyStorageKey);
    final storedPublic = await _secureStorage.read(key: _publicKeyStorageKey);

    if (storedPrivate != null && storedPublic != null) {
      // Restore existing key pair
      final privateBytes = base64Decode(storedPrivate);
      final publicBytes = base64Decode(storedPublic);

      final privateKey = SimpleKeyPairData(
        privateBytes,
        publicKey: SimplePublicKey(publicBytes, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );

      _keyPair = privateKey;
      debugPrint('[Encryption] Key pair loaded from secure storage.');
    } else {
      // Generate a new key pair
      await generateKeyPair();
    }
  }

  /// Generate a new X25519 key pair and store it securely.
  Future<void> generateKeyPair() async {
    final newPair = await _keyExchange.newKeyPair();
    _keyPair = newPair;

    // Extract and store the raw bytes
    final privateData = await newPair.extractPrivateKeyBytes();
    final publicKey = await newPair.extractPublicKey();

    await _secureStorage.write(
      key: _privateKeyStorageKey,
      value: base64Encode(privateData),
    );
    await _secureStorage.write(
      key: _publicKeyStorageKey,
      value: base64Encode(publicKey.bytes),
    );

    debugPrint('[Encryption] New key pair generated and stored.');
  }

  /// Get this device's public key as a base64-encoded string.
  /// This is shared with peers so they can encrypt messages to us.
  Future<String> getPublicKeyBase64() async {
    if (_keyPair == null) await initialize();
    final publicKey = await _keyPair!.extractPublicKey();
    return base64Encode(publicKey.bytes);
  }

  /// Derive a shared secret from our private key and the peer's public key.
  Future<SecretKey> _deriveSharedSecret(String peerPublicKeyBase64) async {
    if (_keyPair == null) await initialize();

    final peerPublicBytes = base64Decode(peerPublicKeyBase64);
    final peerPublicKey = SimplePublicKey(
      peerPublicBytes,
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _keyExchange.sharedSecretKey(
      keyPair: _keyPair!,
      remotePublicKey: peerPublicKey,
    );

    return sharedSecret;
  }

  /// Encrypt a plaintext message for a specific peer.
  ///
  /// Returns a JSON string containing the nonce and ciphertext,
  /// both base64-encoded.
  Future<String> encrypt(String plaintext, String peerPublicKeyBase64) async {
    final sharedSecret = await _deriveSharedSecret(peerPublicKeyBase64);
    final plaintextBytes = utf8.encode(plaintext);

    final secretBox = await _cipher.encrypt(
      plaintextBytes,
      secretKey: sharedSecret,
    );

    final result = {
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };

    return jsonEncode(result);
  }

  /// Decrypt a message from a specific peer.
  ///
  /// [encryptedJson] is the JSON string produced by [encrypt].
  Future<String> decrypt(
    String encryptedJson,
    String peerPublicKeyBase64,
  ) async {
    final sharedSecret = await _deriveSharedSecret(peerPublicKeyBase64);
    final parts = jsonDecode(encryptedJson) as Map<String, dynamic>;

    final nonce = base64Decode(parts['nonce'] as String);
    final ciphertext = base64Decode(parts['ciphertext'] as String);
    final mac = Mac(base64Decode(parts['mac'] as String));

    final secretBox = SecretBox(ciphertext, nonce: nonce, mac: mac);

    final decryptedBytes = await _cipher.decrypt(
      secretBox,
      secretKey: sharedSecret,
    );

    return utf8.decode(decryptedBytes);
  }

  /// Check if the encryption service has been initialized with a key pair.
  bool get isInitialized => _keyPair != null;
}
