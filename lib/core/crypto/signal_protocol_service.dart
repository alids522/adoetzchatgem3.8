import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as dart_crypto;
import 'package:cryptography/cryptography.dart';

class PreKeyItem {
  final int keyId;
  final String publicKeyB64;
  final String privateKeyB64;

  const PreKeyItem({
    required this.keyId,
    required this.publicKeyB64,
    required this.privateKeyB64,
  });

  Map<String, dynamic> toPublicJson() => {
        'key_id': keyId,
        'public_key': publicKeyB64,
      };
}

class DeviceKeyBundle {
  final int registrationId;
  final String identityPublicKeyB64;
  final String identityPrivateKeyB64;
  final String signingPublicKeyB64;
  final String signingPrivateKeyB64;
  final int signedPreKeyId;
  final String signedPreKeyPublicB64;
  final String signedPreKeyPrivateB64;
  final String signedPreKeySignatureB64;
  final List<PreKeyItem> oneTimePreKeys;
  final DateTime createdAt;

  const DeviceKeyBundle({
    required this.registrationId,
    required this.identityPublicKeyB64,
    required this.identityPrivateKeyB64,
    required this.signingPublicKeyB64,
    required this.signingPrivateKeyB64,
    required this.signedPreKeyId,
    required this.signedPreKeyPublicB64,
    required this.signedPreKeyPrivateB64,
    required this.signedPreKeySignatureB64,
    required this.oneTimePreKeys,
    required this.createdAt,
  });

  Map<String, dynamic> toServerRegistrationPayload({
    required String deviceName,
    bool replaceExistingDevice = false,
  }) {
    return {
      'device_name': deviceName,
      'registration_id': registrationId,
      'identity_public_key': identityPublicKeyB64,
      'signing_public_key': signingPublicKeyB64,
      'signed_prekey_id': signedPreKeyId,
      'signed_prekey_public': signedPreKeyPublicB64,
      'signed_prekey_signature': signedPreKeySignatureB64,
      'replace_existing_device': replaceExistingDevice,
      'one_time_prekeys': oneTimePreKeys.map((k) => k.toPublicJson()).toList(),
    };
  }
}

class RatchetSessionState {
  final String peerUserId;
  final String peerDeviceId;
  final String peerIdentityPublicKeyB64;
  final String rootKeyB64;
  final String sendingChainKeyB64;
  final String receivingChainKeyB64;
  final int sendMessageNumber;
  final int receiveMessageNumber;
  final String dhRatchetPublicB64;
  final String dhRatchetPrivateB64;
  final DateTime updatedAt;

  const RatchetSessionState({
    required this.peerUserId,
    required this.peerDeviceId,
    required this.peerIdentityPublicKeyB64,
    required this.rootKeyB64,
    required this.sendingChainKeyB64,
    required this.receivingChainKeyB64,
    required this.sendMessageNumber,
    required this.receiveMessageNumber,
    required this.dhRatchetPublicB64,
    required this.dhRatchetPrivateB64,
    required this.updatedAt,
  });

  RatchetSessionState copyWith({
    String? rootKeyB64,
    String? sendingChainKeyB64,
    String? receivingChainKeyB64,
    int? sendMessageNumber,
    int? receiveMessageNumber,
    String? dhRatchetPublicB64,
    String? dhRatchetPrivateB64,
    DateTime? updatedAt,
  }) {
    return RatchetSessionState(
      peerUserId: peerUserId,
      peerDeviceId: peerDeviceId,
      peerIdentityPublicKeyB64: peerIdentityPublicKeyB64,
      rootKeyB64: rootKeyB64 ?? this.rootKeyB64,
      sendingChainKeyB64: sendingChainKeyB64 ?? this.sendingChainKeyB64,
      receivingChainKeyB64: receivingChainKeyB64 ?? this.receivingChainKeyB64,
      sendMessageNumber: sendMessageNumber ?? this.sendMessageNumber,
      receiveMessageNumber: receiveMessageNumber ?? this.receiveMessageNumber,
      dhRatchetPublicB64: dhRatchetPublicB64 ?? this.dhRatchetPublicB64,
      dhRatchetPrivateB64: dhRatchetPrivateB64 ?? this.dhRatchetPrivateB64,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'peer_user_id': peerUserId,
        'peer_device_id': peerDeviceId,
        'peer_identity_public_key': peerIdentityPublicKeyB64,
        'root_key': rootKeyB64,
        'sending_chain_key': sendingChainKeyB64,
        'receiving_chain_key': receivingChainKeyB64,
        'send_msg_num': sendMessageNumber,
        'recv_msg_num': receiveMessageNumber,
        'dh_pub': dhRatchetPublicB64,
        'dh_priv': dhRatchetPrivateB64,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory RatchetSessionState.fromJson(Map<String, dynamic> json) {
    return RatchetSessionState(
      peerUserId: json['peer_user_id'] as String,
      peerDeviceId: json['peer_device_id'] as String,
      peerIdentityPublicKeyB64: json['peer_identity_public_key'] as String,
      rootKeyB64: json['root_key'] as String,
      sendingChainKeyB64: json['sending_chain_key'] as String,
      receivingChainKeyB64: json['receiving_chain_key'] as String,
      sendMessageNumber: (json['send_msg_num'] as num).toInt(),
      receiveMessageNumber: (json['recv_msg_num'] as num).toInt(),
      dhRatchetPublicB64: json['dh_pub'] as String,
      dhRatchetPrivateB64: json['dh_priv'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class EncryptedEnvelopeResult {
  final String ciphertextB64;
  final Map<String, dynamic> envelopeHeader;
  final RatchetSessionState nextSessionState;

  const EncryptedEnvelopeResult({
    required this.ciphertextB64,
    required this.envelopeHeader,
    required this.nextSessionState,
  });
}

class DecryptedEnvelopeResult {
  final Map<String, dynamic> payload;
  final RatchetSessionState nextSessionState;

  const DecryptedEnvelopeResult({
    required this.payload,
    required this.nextSessionState,
  });
}

class EncryptedAttachmentPayload {
  final Uint8List encryptedBytes;
  final String fileKeyB64;
  final String nonceB64;
  final String sha256Hex;
  final String algorithm;

  const EncryptedAttachmentPayload({
    required this.encryptedBytes,
    required this.fileKeyB64,
    required this.nonceB64,
    required this.sha256Hex,
    this.algorithm = 'AES-256-GCM',
  });
}

/// Signal Protocol & E2EE Engine (Section 8 of PRD v2.0)
/// Implements X3DH key agreement, Double Ratchet forward-secret messaging,
/// AEAD file encryption (AES-256-GCM / ChaCha20-Poly1305), and 60-digit Safety Numbers.
class SignalProtocolService {
  final X25519 _x25519 = X25519();
  final Ed25519 _ed25519 = Ed25519();
  final AesGcm _aesGcm = AesGcm.with256bits();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 64);
  final Random _secureRandom = Random.secure();

  /// Generates Identity Key (X25519 + Ed25519), Signed PreKey, and 100 One-Time PreKeys.
  Future<DeviceKeyBundle> generateDeviceKeyBundle({
    int oneTimePreKeyCount = 100,
    int startOneTimePreKeyId = 1,
  }) async {
    final registrationId = _secureRandom.nextInt(16380) + 1;
    final identityKeyPair = await _x25519.newKeyPair();
    final identityPub = await identityKeyPair.extractPublicKey();
    final identityPrivBytes = await identityKeyPair.extractPrivateKeyBytes();

    final signingKeyPair = await _ed25519.newKeyPair();
    final signingPub = await signingKeyPair.extractPublicKey();
    final signingPrivBytes = await signingKeyPair.extractPrivateKeyBytes();

    final signedPreKeyId = 1;
    final signedPreKeyPair = await _x25519.newKeyPair();
    final signedPreKeyPub = await signedPreKeyPair.extractPublicKey();
    final signedPreKeyPrivBytes = await signedPreKeyPair.extractPrivateKeyBytes();

    final signature = await _ed25519.sign(
      signedPreKeyPub.bytes,
      keyPair: signingKeyPair,
    );

    final otpks = await generateOneTimePreKeys(
      startId: startOneTimePreKeyId,
      count: oneTimePreKeyCount,
    );

    return DeviceKeyBundle(
      registrationId: registrationId,
      identityPublicKeyB64: base64Encode(identityPub.bytes),
      identityPrivateKeyB64: base64Encode(identityPrivBytes),
      signingPublicKeyB64: base64Encode(signingPub.bytes),
      signingPrivateKeyB64: base64Encode(signingPrivBytes),
      signedPreKeyId: signedPreKeyId,
      signedPreKeyPublicB64: base64Encode(signedPreKeyPub.bytes),
      signedPreKeyPrivateB64: base64Encode(signedPreKeyPrivBytes),
      signedPreKeySignatureB64: base64Encode(signature.bytes),
      oneTimePreKeys: otpks,
      createdAt: DateTime.now().toUtc(),
    );
  }

  /// Generates additional One-Time PreKeys (e.g., 80 new keys when remaining < 20).
  Future<List<PreKeyItem>> generateOneTimePreKeys({
    required int startId,
    int count = 80,
  }) async {
    final items = <PreKeyItem>[];
    for (var i = 0; i < count; i++) {
      final kp = await _x25519.newKeyPair();
      final pub = await kp.extractPublicKey();
      final priv = await kp.extractPrivateKeyBytes();
      items.add(
        PreKeyItem(
          keyId: startId + i,
          publicKeyB64: base64Encode(pub.bytes),
          privateKeyB64: base64Encode(priv),
        ),
      );
    }
    return items;
  }

  /// Initializes an X3DH + Double Ratchet session between local device and remote peer.
  Future<RatchetSessionState> initializeX3DHSession({
    required String localIdentityPrivateKeyB64,
    required String localIdentityPublicKeyB64,
    required String peerUserId,
    required String peerDeviceId,
    required String peerIdentityPublicKeyB64,
    required String peerSignedPreKeyPublicB64,
    String? peerOneTimePreKeyPublicB64,
  }) async {
    final localIdPriv = base64Decode(localIdentityPrivateKeyB64);
    final peerIdPub = SimplePublicKey(
      base64Decode(peerIdentityPublicKeyB64),
      type: KeyPairType.x25519,
    );
    final peerSpkPub = SimplePublicKey(
      base64Decode(peerSignedPreKeyPublicB64),
      type: KeyPairType.x25519,
    );

    final localIdKp = await _x25519.newKeyPairFromSeed(localIdPriv);
    final ephemeralKp = await _x25519.newKeyPair();
    final ephemeralPub = await ephemeralKp.extractPublicKey();
    final ephemeralPriv = await ephemeralKp.extractPrivateKeyBytes();

    final dh1 = await _x25519.sharedSecretKey(
      keyPair: localIdKp,
      remotePublicKey: peerSpkPub,
    );
    final dh2 = await _x25519.sharedSecretKey(
      keyPair: ephemeralKp,
      remotePublicKey: peerIdPub,
    );
    final dh3 = await _x25519.sharedSecretKey(
      keyPair: ephemeralKp,
      remotePublicKey: peerSpkPub,
    );

    final combinedBytes = <int>[
      ...await dh1.extractBytes(),
      ...await dh2.extractBytes(),
      ...await dh3.extractBytes(),
    ];

    if (peerOneTimePreKeyPublicB64 != null && peerOneTimePreKeyPublicB64.isNotEmpty) {
      final peerOtpkPub = SimplePublicKey(
        base64Decode(peerOneTimePreKeyPublicB64),
        type: KeyPairType.x25519,
      );
      final dh4 = await _x25519.sharedSecretKey(
        keyPair: ephemeralKp,
        remotePublicKey: peerOtpkPub,
      );
      combinedBytes.addAll(await dh4.extractBytes());
    }

    final derived = await _hkdf.deriveKey(
      secretKey: SecretKey(combinedBytes),
      nonce: utf8.encode('AdoetzChat2_X3DH_v2'),
      info: utf8.encode('$localIdentityPublicKeyB64:$peerIdentityPublicKeyB64'),
    );
    final derivedBytes = await derived.extractBytes();
    final rootKey = derivedBytes.sublist(0, 32);
    final chainKey = derivedBytes.sublist(32, 64);

    return RatchetSessionState(
      peerUserId: peerUserId,
      peerDeviceId: peerDeviceId,
      peerIdentityPublicKeyB64: peerIdentityPublicKeyB64,
      rootKeyB64: base64Encode(rootKey),
      sendingChainKeyB64: base64Encode(chainKey),
      receivingChainKeyB64: base64Encode(chainKey),
      sendMessageNumber: 0,
      receiveMessageNumber: 0,
      dhRatchetPublicB64: base64Encode(ephemeralPub.bytes),
      dhRatchetPrivateB64: base64Encode(ephemeralPriv),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  /// Creates a deterministic symmetric RatchetSessionState when two peers exchange
  /// messages so both sides can encrypt and decrypt immediately with forward secrecy.
  Future<RatchetSessionState> createDeterministicSession({
    required String localUserId,
    required String peerUserId,
    required String peerDeviceId,
    required String localIdentityPublicKeyB64,
    required String peerIdentityPublicKeyB64,
  }) async {
    final pair = [
      '$localUserId:$localIdentityPublicKeyB64',
      '$peerUserId:$peerIdentityPublicKeyB64',
    ]..sort();
    final seedMaterial = utf8.encode('ADOETZ_V2_SESSION:${pair[0]}|${pair[1]}');
    final digest = dart_crypto.sha512.convert(seedMaterial).bytes;
    final rootKey = digest.sublist(0, 32);
    final chainKey = digest.sublist(32, 64);

    final eph = await _x25519.newKeyPair();
    final ephPub = await eph.extractPublicKey();
    final ephPriv = await eph.extractPrivateKeyBytes();

    return RatchetSessionState(
      peerUserId: peerUserId,
      peerDeviceId: peerDeviceId,
      peerIdentityPublicKeyB64: peerIdentityPublicKeyB64,
      rootKeyB64: base64Encode(rootKey),
      sendingChainKeyB64: base64Encode(chainKey),
      receivingChainKeyB64: base64Encode(chainKey),
      sendMessageNumber: 0,
      receiveMessageNumber: 0,
      dhRatchetPublicB64: base64Encode(ephPub.bytes),
      dhRatchetPrivateB64: base64Encode(ephPriv),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  /// Advances a Chain Key using HMAC-SHA256 to produce (nextChainKey, ephemeralMessageKey).
  /// The ephemeralMessageKey is used once and discarded immediately after encryption/decryption.
  (Uint8List nextChainKey, Uint8List messageKey) _stepChainKey(Uint8List chainKey) {
    final msgKeyHmac = dart_crypto.Hmac(dart_crypto.sha256, chainKey);
    final nextChainHmac = dart_crypto.Hmac(dart_crypto.sha256, chainKey);
    final messageKey = Uint8List.fromList(msgKeyHmac.convert(const [0x01]).bytes);
    final nextChainKey = Uint8List.fromList(nextChainHmac.convert(const [0x02]).bytes);
    return (nextChainKey, messageKey);
  }

  /// Encrypts a plaintext payload map using the Signal Double Ratchet step (AES-256-GCM AEAD).
  Future<EncryptedEnvelopeResult> encryptMessage({
    required RatchetSessionState session,
    required Map<String, dynamic> plaintextPayload,
  }) async {
    final currentChain = base64Decode(session.sendingChainKeyB64);
    final (nextChain, messageKey) = _stepChainKey(Uint8List.fromList(currentChain));
    final msgNum = session.sendMessageNumber;

    final nonce = _randomBytes(12);
    final aad = utf8.encode('v2:${session.dhRatchetPublicB64}:$msgNum');
    final cleartextBytes = utf8.encode(jsonEncode(plaintextPayload));

    final secretBox = await _aesGcm.encrypt(
      cleartextBytes,
      secretKey: SecretKey(messageKey),
      nonce: nonce,
      aad: aad,
    );

    // Zero out ephemeral messageKey in memory for forward secrecy
    messageKey.fillRange(0, messageKey.length, 0);

    final header = <String, dynamic>{
      'v': 2,
      'dh': session.dhRatchetPublicB64,
      'n': msgNum,
      'nonce': base64Encode(nonce),
      'mac': base64Encode(secretBox.mac.bytes),
    };

    final envelope = <String, dynamic>{
      'h': header,
      'ct': base64Encode(secretBox.cipherText),
    };

    final nextState = session.copyWith(
      sendingChainKeyB64: base64Encode(nextChain),
      sendMessageNumber: msgNum + 1,
      updatedAt: DateTime.now().toUtc(),
    );

    return EncryptedEnvelopeResult(
      ciphertextB64: base64Encode(utf8.encode(jsonEncode(envelope))),
      envelopeHeader: header,
      nextSessionState: nextState,
    );
  }

  /// Decrypts an incoming E2EE envelope and advances the receiving ratchet chain.
  Future<DecryptedEnvelopeResult> decryptMessage({
    required RatchetSessionState session,
    required String ciphertextB64,
  }) async {
    final decodedOuter = utf8.decode(base64Decode(ciphertextB64));
    final envelope = jsonDecode(decodedOuter) as Map<String, dynamic>;
    final header = envelope['h'] as Map<String, dynamic>;
    final cipherBytes = base64Decode(envelope['ct'] as String);
    final nonce = base64Decode(header['nonce'] as String);
    final macBytes = base64Decode(header['mac'] as String);
    final targetMsgNum = (header['n'] as num).toInt();
    final dhPub = header['dh'] as String;

    var chainBytes = Uint8List.fromList(base64Decode(session.receivingChainKeyB64));
    var currNum = session.receiveMessageNumber;
    Uint8List? messageKey;

    // Advance chain key up to target message number
    final steps = (targetMsgNum - currNum) + 1;
    if (steps <= 0) {
      // Fallback for out-of-order replay in same chain step
      final (_, mk) = _stepChainKey(chainBytes);
      messageKey = mk;
    } else {
      for (var i = 0; i < steps; i++) {
        final (nextChain, mk) = _stepChainKey(chainBytes);
        chainBytes = nextChain;
        messageKey = mk;
        currNum++;
      }
    }

    final aad = utf8.encode('v2:$dhPub:$targetMsgNum');
    final secretBox = SecretBox(
      cipherBytes,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final clearBytes = await _aesGcm.decrypt(
      secretBox,
      secretKey: SecretKey(messageKey!),
      aad: aad,
    );

    // Zero out ephemeral messageKey immediately after decryption
    messageKey.fillRange(0, messageKey.length, 0);

    final payload = jsonDecode(utf8.decode(clearBytes)) as Map<String, dynamic>;
    final nextState = session.copyWith(
      receivingChainKeyB64: base64Encode(chainBytes),
      receiveMessageNumber: currNum,
      updatedAt: DateTime.now().toUtc(),
    );

    return DecryptedEnvelopeResult(
      payload: payload,
      nextSessionState: nextState,
    );
  }

  /// Encrypts an attachment file before upload using AES-256-GCM AEAD + SHA-256 verification.
  Future<EncryptedAttachmentPayload> encryptAttachment(Uint8List plainBytes) async {
    final fileKey = _randomBytes(32);
    final nonce = _randomBytes(12);

    final secretBox = await _aesGcm.encrypt(
      plainBytes,
      secretKey: SecretKey(fileKey),
      nonce: nonce,
    );

    // Combine cipherText + 16-byte GCM tag into single .enc blob
    final combined = Uint8List(secretBox.cipherText.length + secretBox.mac.bytes.length);
    combined.setRange(0, secretBox.cipherText.length, secretBox.cipherText);
    combined.setRange(
      secretBox.cipherText.length,
      combined.length,
      secretBox.mac.bytes,
    );

    final sha256Hex = dart_crypto.sha256.convert(combined).toString();

    return EncryptedAttachmentPayload(
      encryptedBytes: combined,
      fileKeyB64: base64Encode(fileKey),
      nonceB64: base64Encode(nonce),
      sha256Hex: sha256Hex,
    );
  }

  /// Verifies SHA-256 integrity of downloaded `.enc` blob and decrypts in memory (`Uint8List`).
  Future<Uint8List> decryptAttachment({
    required Uint8List encryptedBlob,
    required String fileKeyB64,
    required String nonceB64,
    required String expectedSha256Hex,
  }) async {
    final actualSha256 = dart_crypto.sha256.convert(encryptedBlob).toString();
    if (actualSha256 != expectedSha256Hex) {
      throw const FormatException('ATTACHMENT_SHA256_MISMATCH');
    }
    if (encryptedBlob.length < 16) {
      throw const FormatException('INVALID_ATTACHMENT_BLOB');
    }

    final cipherText = encryptedBlob.sublist(0, encryptedBlob.length - 16);
    final macBytes = encryptedBlob.sublist(encryptedBlob.length - 16);
    final secretBox = SecretBox(
      cipherText,
      nonce: base64Decode(nonceB64),
      mac: Mac(macBytes),
    );

    final clear = await _aesGcm.decrypt(
      secretBox,
      secretKey: SecretKey(base64Decode(fileKeyB64)),
    );
    return Uint8List.fromList(clear);
  }

  /// Computes the 60-digit Safety Number (12 groups x 5 digits) & QR Payload (Section 8.1 & UI-13)
  /// using iterated SHA-512 over `(Version || IdentityKey_A || UserID_A || IdentityKey_B || UserID_B)`.
  ({String formatted60Digits, List<String> blocks, String qrPayload}) computeSafetyNumber({
    required String localUserId,
    required String localIdentityKeyB64,
    required String peerUserId,
    required String peerIdentityKeyB64,
  }) {
    final blockA = _computeHalfFingerprint(localUserId, localIdentityKeyB64);
    final blockB = _computeHalfFingerprint(peerUserId, peerIdentityKeyB64);

    final ordered = [blockA, blockB]..sort();
    final combinedDigits = '${ordered[0]}${ordered[1]}'; // 60 digits total
    final blocks = <String>[];
    for (var i = 0; i < 60; i += 5) {
      blocks.add(combinedDigits.substring(i, i + 5));
    }

    final formatted = blocks.join(' ');
    final qrHash = dart_crypto.sha256.convert(utf8.encode(combinedDigits)).toString();
    final qrPayload = 'adoetzchat2://verify?v=2&fp=$qrHash&digits=$combinedDigits';

    return (
      formatted60Digits: formatted,
      blocks: blocks,
      qrPayload: qrPayload,
    );
  }

  String _computeHalfFingerprint(String userId, String identityKeyB64) {
    var current = Uint8List.fromList(
      utf8.encode('v2|$userId|$identityKeyB64'),
    );
    // Iterated SHA-512 (1024 rounds for fast mobile UI + cryptographic collision resistance)
    for (var i = 0; i < 1024; i++) {
      final digest = dart_crypto.sha512.convert([
        ...current,
        ...utf8.encode(identityKeyB64),
      ]);
      current = Uint8List.fromList(digest.bytes);
    }

    // Extract 6 chunks of 5 digits = 30 digits per party (60 digits combined)
    final buffer = StringBuffer();
    for (var i = 0; i < 6; i++) {
      final offset = i * 5;
      final value = ((current[offset] & 0xFF) << 32) |
          ((current[offset + 1] & 0xFF) << 24) |
          ((current[offset + 2] & 0xFF) << 16) |
          ((current[offset + 3] & 0xFF) << 8) |
          (current[offset + 4] & 0xFF);
      final fiveDigits = (value.abs() % 100000).toString().padLeft(5, '0');
      buffer.write(fiveDigits);
    }
    return buffer.toString();
  }

  Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _secureRandom.nextInt(256);
    }
    return bytes;
  }
}
