import 'dart:typed_data';
import 'package:adoetz_chat_2/app/theme/design_tokens.dart';
import 'package:adoetz_chat_2/core/crypto/signal_protocol_service.dart';
import 'package:adoetz_chat_2/core/database/models.dart';
import 'package:adoetz_chat_2/core/database/vault_database.dart';
import 'package:adoetz_chat_2/core/network/supabase_gateway.dart';
import 'package:adoetz_chat_2/core/state/app_controller.dart';
import 'package:adoetz_chat_2/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Adoetz Chat 2 v2.0 (com.adoetzchat2.chat) — Cryptography & Signal Protocol Tests', () {
    late SignalProtocolService crypto;

    setUp(() {
      crypto = SignalProtocolService();
    });

    test('Generates Identity Key, Signed PreKey, and 100 One-Time PreKeys', () async {
      final bundle = await crypto.generateDeviceKeyBundle(oneTimePreKeyCount: 100);
      expect(bundle.identityPublicKeyB64, isNotEmpty);
      expect(bundle.signedPreKeyPublicB64, isNotEmpty);
      expect(bundle.signedPreKeySignatureB64, isNotEmpty);
      expect(bundle.oneTimePreKeys.length, equals(100));
    });

    test('X3DH + Double Ratchet encrypts and decrypts with forward secrecy', () async {
      final aliceKeys = await crypto.generateDeviceKeyBundle(oneTimePreKeyCount: 5);
      final bobKeys = await crypto.generateDeviceKeyBundle(oneTimePreKeyCount: 5);

      var aliceSession = await crypto.createDeterministicSession(
        localUserId: 'usr_alice',
        peerUserId: 'usr_bob',
        peerDeviceId: 'dev_bob',
        localIdentityPublicKeyB64: aliceKeys.identityPublicKeyB64,
        peerIdentityPublicKeyB64: bobKeys.identityPublicKeyB64,
      );

      var bobSession = await crypto.createDeterministicSession(
        localUserId: 'usr_bob',
        peerUserId: 'usr_alice',
        peerDeviceId: 'dev_alice',
        localIdentityPublicKeyB64: bobKeys.identityPublicKeyB64,
        peerIdentityPublicKeyB64: aliceKeys.identityPublicKeyB64,
      );

      final encrypted1 = await crypto.encryptMessage(
        session: aliceSession,
        plaintextPayload: {'body': 'Pesan rahasia #1', 'seq': 1},
      );
      aliceSession = encrypted1.nextSessionState;
      expect(aliceSession.sendMessageNumber, equals(1));

      final decrypted1 = await crypto.decryptMessage(
        session: bobSession,
        ciphertextB64: encrypted1.ciphertextB64,
      );
      bobSession = decrypted1.nextSessionState;
      expect(decrypted1.payload['body'], equals('Pesan rahasia #1'));
      expect(bobSession.receiveMessageNumber, equals(1));
    });

    test('AEAD Attachment Encryption & SHA-256 integrity verification succeeds and rejects tampering', () async {
      final plainBytes = Uint8List.fromList('Dokumen Rahasia Adoetz Chat 2'.codeUnits);
      final encrypted = await crypto.encryptAttachment(plainBytes);

      final decrypted = await crypto.decryptAttachment(
        encryptedBlob: encrypted.encryptedBytes,
        fileKeyB64: encrypted.fileKeyB64,
        nonceB64: encrypted.nonceB64,
        expectedSha256Hex: encrypted.sha256Hex,
      );
      expect(decrypted, equals(plainBytes));

      // Tamper with SHA-256
      expect(
        () => crypto.decryptAttachment(
          encryptedBlob: encrypted.encryptedBytes,
          fileKeyB64: encrypted.fileKeyB64,
          nonceB64: encrypted.nonceB64,
          expectedSha256Hex: '0000000000000000000000000000000000000000000000000000000000000000',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('Computes symmetric 60-digit Safety Number (12 groups x 5 digits) & QR payload', () {
      final safetyAB = crypto.computeSafetyNumber(
        localUserId: 'usr_a',
        localIdentityKeyB64: 'id_key_a',
        peerUserId: 'usr_b',
        peerIdentityKeyB64: 'id_key_b',
      );
      final safetyBA = crypto.computeSafetyNumber(
        localUserId: 'usr_b',
        localIdentityKeyB64: 'id_key_b',
        peerUserId: 'usr_a',
        peerIdentityKeyB64: 'id_key_a',
      );

      expect(safetyAB.blocks.length, equals(12));
      for (final block in safetyAB.blocks) {
        expect(block.length, equals(5));
      }
      expect(safetyAB.formatted60Digits, equals(safetyBA.formatted60Digits));
      expect(safetyAB.qrPayload, equals(safetyBA.qrPayload));
    });
  });

  group('Outbox Deduplication, FTS5 Local Search, & Identity Key Change (ERR-01, ERR-02, ERR-05)', () {
    late VaultDatabase vault;

    setUp(() async {
      vault = VaultDatabase();
      await vault.initialize(forceMemoryOnly: true);
    });

    test('Deduplicates outbox messages with identical (senderId, clientMessageId) (OBJ-05 & ERR-02)', () async {
      final conv = LocalConversation(
        id: 'conv_test',
        peerUserId: 'usr_peer',
        peerUsername: 'peer',
        peerDisplayName: 'Peer User',
        peerIdentityKeyB64: 'peer_key_v1',
        lastMessageSnippet: '',
        lastEventAt: DateTime.now(),
      );
      await vault.upsertConversation(conv);

      final msg = LocalMessage(
        clientMessageId: 'uuid_idempotent_123',
        conversationId: 'conv_test',
        senderId: 'usr_me',
        isOutgoing: true,
        plaintext: 'Uji idempoten tanpa duplikasi',
        ciphertextB64: 'cipher_123',
        status: MessageDeliveryStatus.queued,
        createdAt: DateTime.now(),
      );

      final firstInsert = await vault.saveMessageAndOutboxAtomically(
        message: msg,
        enqueueInOutbox: true,
      );
      final duplicateRetry = await vault.saveMessageAndOutboxAtomically(
        message: msg.copyWith(status: MessageDeliveryStatus.sent),
        enqueueInOutbox: true,
      );

      expect(firstInsert, isTrue);
      expect(duplicateRetry, isFalse);
      expect(vault.getMessages('conv_test').length, equals(1));
      expect(vault.getPendingOutboxEntries().length, equals(1));

      // Exponential backoff check (ERR-01: 1s, 2s, 4s, 8s...)
      final now = DateTime.now().toUtc();
      vault.recordOutboxRetryFailure('usr_me', 'uuid_idempotent_123', now);
      final retry1 = vault.getPendingOutboxEntries().first;
      expect(retry1.retryCount, equals(1));
      expect(retry1.nextAttemptAt.difference(now).inSeconds, equals(2));
    });

    test('Detects Peer Identity Key change (ERR-05) and performs 100% local FTS search', () async {
      final conv = LocalConversation(
        id: 'conv_alex',
        peerUserId: 'usr_alex',
        peerUsername: 'alex',
        peerDisplayName: 'Alex Pratama',
        peerIdentityKeyB64: 'initial_key_v1',
        isVerified: true,
        lastMessageSnippet: 'Awal',
        lastEventAt: DateTime.now(),
      );
      await vault.upsertConversation(conv);
      expect(vault.getConversation('conv_alex')!.peerKeyChangedWarning, isFalse);

      // Peer changes phone / rotates identity key
      await vault.upsertConversation(
        conv.copyWith(peerIdentityKeyB64: 'rotated_key_v2'),
      );
      final afterRotation = vault.getConversation('conv_alex')!;
      expect(afterRotation.peerKeyChangedWarning, isTrue);
      expect(afterRotation.isVerified, isFalse);

      // Local FTS5 search
      await vault.saveMessageAndOutboxAtomically(
        message: LocalMessage(
          clientMessageId: 'm1',
          conversationId: 'conv_alex',
          senderId: 'usr_alex',
          isOutgoing: false,
          plaintext: 'Arsitektur SQLCipher dan Coturn WebRTC',
          ciphertextB64: 'ct1',
          status: MessageDeliveryStatus.read,
          createdAt: DateTime.now(),
        ),
      );

      final hits = vault.searchLocalMessagesFts('SQLCipher');
      expect(hits.length, equals(1));
      expect(hits.first.message.clientMessageId, equals('m1'));
    });
  });

  group('Atomic Signup Security, Single-Device Handshake, Call TTL, & Admin Audit (DoD #2..#5)', () {
    late AppController controller;

    setUp(() {
      controller = AppController(
        crypto: SignalProtocolService(),
        vault: VaultDatabase(),
        gateway: SupabaseGateway(),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('Rejects signup without Turnstile token or with privilege escalation metadata (DoD #2)', () async {
      final noTurnstile = await controller.registerNewAccount(
        username: 'valid_user',
        email: 'valid@adoetz52.my.id',
        password: 'StrongPassword#2026',
        turnstileToken: '',
        onStepChange: (_) {},
      );
      expect(noTurnstile.ok, isFalse);
      expect(noTurnstile.error, contains('TURNSTILE_REQUIRED'));

      final adminInjection = await controller.registerNewAccount(
        username: 'hacker_user',
        email: 'hacker@adoetz52.my.id',
        password: 'StrongPassword#2026',
        turnstileToken: 'cf_valid_token',
        injectedMetadata: {'role': 'admin'},
        onStepChange: (_) {},
      );
      expect(adminInjection.ok, isFalse);
      expect(adminInjection.error, contains('PRIVILEGE_ESCALATION_DENIED'));
    });

    test('Enforces Single-Active-Device conflict on login (ERR-04) and 40s Call TTL (ERR-06)', () async {
      final conflictLogin = await controller.signIn(
        identifier: '@alex',
        password: 'AlexSecurePass#2026',
      );
      expect(conflictLogin.requiresDeviceReplacement, isTrue);
      expect(controller.state.pendingDeviceConflict, isNotNull);

      // Confirm device replacement
      await controller.confirmDeviceReplacementAndSignIn('AlexSecurePass#2026');
      expect(controller.state.isAuthenticated, isTrue);

      // ERR-06: Expired incoming call (>40s TTL) records Missed Call without ringing
      final peer = controller.state.directory.first;
      final didRing = await controller.receiveIncomingCall(
        peer: peer,
        isVideo: false,
        customExpiresAtMs: DateTime.now().millisecondsSinceEpoch - 60000,
      );
      expect(didRing, isFalse);
      expect(controller.state.activeCall, isNull);
      expect(
        controller.state.callHistory.first.direction,
        equals(CallDirection.missed),
      );
    });

    test('Admin Force Password Reset returns 1-time password without leaking it into Audit Log (UI-23 & UI-24)', () async {
      await controller.signIn(
        identifier: '@superadmin',
        password: 'AdminMasterKey#2026',
      );
      expect(controller.state.isAdmin, isTrue);

      final target = controller.state.directory.firstWhere((u) => u.username == 'budi');
      final res = await controller.adminExecuteAction(
        targetUserId: target.userId,
        action: 'FORCE_RESET_PASSWORD',
        reason: 'Permintaan pengguna terverifikasi out-of-band',
        adminPasswordConfirmation: 'AdminMasterKey#2026',
      );

      expect(res.ok, isTrue);
      expect(res.oneTimePassword, isNotNull);
      expect(res.oneTimePassword!.length, equals(16));

      final latestLog = controller.state.adminAuditLogs.first;
      expect(latestLog.action, equals('FORCE_RESET_PASSWORD'));
      expect(latestLog.reason.contains(res.oneTimePassword!), isFalse);
    });
  });

  testWidgets('Precision Neutral Messenger v2.0 UI renders Welcome Screen & Design Tokens', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AdoetzChat2App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Komunikasi Privat Tanpa Nomor Telepon'), findsOneWidget);
    expect(find.byKey(const Key('welcome_sign_in_btn')), findsOneWidget);
    expect(find.byKey(const Key('welcome_sign_up_btn')), findsOneWidget);

    // Verify Precision Neutral Dark Mode token (#0E1013)
    expect(AdoetzPalette.dark.bgCanvas, equals(const Color(0xFF0E1013)));
    expect(AdoetzPalette.light.bgCanvas, equals(const Color(0xFFF6F7F9)));
  });
}
