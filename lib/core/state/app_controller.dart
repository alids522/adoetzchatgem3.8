import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../crypto/signal_protocol_service.dart';
import '../database/models.dart';
import '../database/vault_database.dart';
import '../network/supabase_gateway.dart';
import '../webrtc/webrtc_call_engine.dart';

enum BlockerReason {
  none,
  accountSuspended,
  sessionRevoked,
  minVersionGate,
  dbMigrationFailure,
}

class PendingDeviceConflict {
  final String identifier;
  final String userId;
  final String username;
  final String email;
  final String displayName;
  final String role;
  final String existingDeviceName;

  const PendingDeviceConflict({
    required this.identifier,
    required this.userId,
    required this.username,
    required this.email,
    required this.displayName,
    required this.role,
    required this.existingDeviceName,
  });
}

class AppState {
  final bool isBootstrapping;
  final bool isAuthenticated;
  final String? currentUserId;
  final String currentUsername;
  final String currentEmail;
  final String currentDisplayName;
  final String currentBio;
  final bool isDiscoverable;
  final String currentRole; // 'user' or 'admin' (from server app_metadata)
  final String accountStatus; // 'active', 'suspended', 'soft_deleted'
  final String? suspendedReason;
  final String activeDeviceId;
  final String activeDeviceName;
  final DeviceKeyBundle? deviceKeyBundle;
  final int remainingOneTimePreKeys;
  final DateTime? lastSignedPreKeyRotation;
  final ThemeMode themeMode;
  final bool isOffline;
  final bool notificationPermissionDismissed;
  final bool notificationPermissionGranted;
  final bool appLockEnabled;
  final String appLockPin;
  final bool isAppLocked;
  final bool readReceiptsEnabled;
  final bool typingIndicatorsEnabled;
  final bool screenshotProtectionEnabled;
  final BlockerReason blockerReason;
  final String? blockerMessage;
  final PendingDeviceConflict? pendingDeviceConflict;
  final List<LocalConversation> conversations;
  final List<LocalCallRecord> callHistory;
  final List<ContactDirectoryEntry> directory;
  final List<AdminAuditLogEntry> adminAuditLogs;
  final ActiveCallSession? activeCall;
  final Set<String> selectedConversationIds;

  const AppState({
    this.isBootstrapping = true,
    this.isAuthenticated = false,
    this.currentUserId,
    this.currentUsername = '',
    this.currentEmail = '',
    this.currentDisplayName = '',
    this.currentBio = '',
    this.isDiscoverable = true,
    this.currentRole = 'user',
    this.accountStatus = 'active',
    this.suspendedReason,
    this.activeDeviceId = '',
    this.activeDeviceName = 'Android 15 • Pixel 8 Pro',
    this.deviceKeyBundle,
    this.remainingOneTimePreKeys = 100,
    this.lastSignedPreKeyRotation,
    this.themeMode = ThemeMode.dark,
    this.isOffline = false,
    this.notificationPermissionDismissed = false,
    this.notificationPermissionGranted = false,
    this.appLockEnabled = false,
    this.appLockPin = '1234',
    this.isAppLocked = false,
    this.readReceiptsEnabled = true,
    this.typingIndicatorsEnabled = true,
    this.screenshotProtectionEnabled = false,
    this.blockerReason = BlockerReason.none,
    this.blockerMessage,
    this.pendingDeviceConflict,
    this.conversations = const [],
    this.callHistory = const [],
    this.directory = const [],
    this.adminAuditLogs = const [],
    this.activeCall,
    this.selectedConversationIds = const {},
  });

  bool get isAdmin => currentRole == 'admin' && accountStatus == 'active';

  AppState copyWith({
    bool? isBootstrapping,
    bool? isAuthenticated,
    String? currentUserId,
    String? currentUsername,
    String? currentEmail,
    String? currentDisplayName,
    String? currentBio,
    bool? isDiscoverable,
    String? currentRole,
    String? accountStatus,
    String? suspendedReason,
    String? activeDeviceId,
    String? activeDeviceName,
    DeviceKeyBundle? deviceKeyBundle,
    int? remainingOneTimePreKeys,
    DateTime? lastSignedPreKeyRotation,
    ThemeMode? themeMode,
    bool? isOffline,
    bool? notificationPermissionDismissed,
    bool? notificationPermissionGranted,
    bool? appLockEnabled,
    String? appLockPin,
    bool? isAppLocked,
    bool? readReceiptsEnabled,
    bool? typingIndicatorsEnabled,
    bool? screenshotProtectionEnabled,
    BlockerReason? blockerReason,
    String? blockerMessage,
    PendingDeviceConflict? pendingDeviceConflict,
    bool clearPendingDeviceConflict = false,
    List<LocalConversation>? conversations,
    List<LocalCallRecord>? callHistory,
    List<ContactDirectoryEntry>? directory,
    List<AdminAuditLogEntry>? adminAuditLogs,
    ActiveCallSession? activeCall,
    bool clearActiveCall = false,
    Set<String>? selectedConversationIds,
  }) {
    return AppState(
      isBootstrapping: isBootstrapping ?? this.isBootstrapping,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      currentUserId: currentUserId ?? this.currentUserId,
      currentUsername: currentUsername ?? this.currentUsername,
      currentEmail: currentEmail ?? this.currentEmail,
      currentDisplayName: currentDisplayName ?? this.currentDisplayName,
      currentBio: currentBio ?? this.currentBio,
      isDiscoverable: isDiscoverable ?? this.isDiscoverable,
      currentRole: currentRole ?? this.currentRole,
      accountStatus: accountStatus ?? this.accountStatus,
      suspendedReason: suspendedReason ?? this.suspendedReason,
      activeDeviceId: activeDeviceId ?? this.activeDeviceId,
      activeDeviceName: activeDeviceName ?? this.activeDeviceName,
      deviceKeyBundle: deviceKeyBundle ?? this.deviceKeyBundle,
      remainingOneTimePreKeys:
          remainingOneTimePreKeys ?? this.remainingOneTimePreKeys,
      lastSignedPreKeyRotation:
          lastSignedPreKeyRotation ?? this.lastSignedPreKeyRotation,
      themeMode: themeMode ?? this.themeMode,
      isOffline: isOffline ?? this.isOffline,
      notificationPermissionDismissed:
          notificationPermissionDismissed ?? this.notificationPermissionDismissed,
      notificationPermissionGranted:
          notificationPermissionGranted ?? this.notificationPermissionGranted,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      appLockPin: appLockPin ?? this.appLockPin,
      isAppLocked: isAppLocked ?? this.isAppLocked,
      readReceiptsEnabled: readReceiptsEnabled ?? this.readReceiptsEnabled,
      typingIndicatorsEnabled:
          typingIndicatorsEnabled ?? this.typingIndicatorsEnabled,
      screenshotProtectionEnabled:
          screenshotProtectionEnabled ?? this.screenshotProtectionEnabled,
      blockerReason: blockerReason ?? this.blockerReason,
      blockerMessage: blockerMessage ?? this.blockerMessage,
      pendingDeviceConflict: clearPendingDeviceConflict
          ? null
          : (pendingDeviceConflict ?? this.pendingDeviceConflict),
      conversations: conversations ?? this.conversations,
      callHistory: callHistory ?? this.callHistory,
      directory: directory ?? this.directory,
      adminAuditLogs: adminAuditLogs ?? this.adminAuditLogs,
      activeCall: clearActiveCall ? null : (activeCall ?? this.activeCall),
      selectedConversationIds:
          selectedConversationIds ?? this.selectedConversationIds,
    );
  }
}

final signalProtocolProvider = Provider<SignalProtocolService>((ref) {
  return SignalProtocolService();
});

final vaultDatabaseProvider = Provider<VaultDatabase>((ref) {
  return VaultDatabase();
});

final supabaseGatewayProvider = Provider<SupabaseGateway>((ref) {
  return SupabaseGateway();
});

final appControllerProvider =
    StateNotifierProvider<AppController, AppState>((ref) {
  return AppController(
    crypto: ref.watch(signalProtocolProvider),
    vault: ref.watch(vaultDatabaseProvider),
    gateway: ref.watch(supabaseGatewayProvider),
  );
});

class AppController extends StateNotifier<AppState> {
  final SignalProtocolService crypto;
  final VaultDatabase vault;
  final SupabaseGateway gateway;
  static const _uuid = Uuid();

  Timer? _callTimer;
  Timer? _outboxTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // Simulated server-side multi-device registry for UI-05 single-device conflict handshake
  final Set<String> _accountsWithActiveOtherDevice = {'alex', 'multi_device'};
  final Map<String, String> _credentialsByUsername = {
    'alex': 'AlexSecurePass#2026',
    'nadia': 'NadiaSecurePass#2026',
    'budi': 'BudiSecurePass#2026',
    'superadmin': 'AdminMasterKey#2026',
  };

  AppController({
    required this.crypto,
    required this.vault,
    required this.gateway,
  }) : super(const AppState()) {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _seedInitialDirectoryAndAuditLogs();
    try {
      // UI-01: 8-second maximum bootstrap timeout before falling back to local SQLCipher cache
      await Future.wait([
        vault.initialize(),
        gateway.initialize(),
      ]).timeout(const Duration(seconds: 8));
    } catch (_) {
      await vault.initialize(forceMemoryOnly: true);
    }

    if (!mounted) return;
    _listenConnectivity();
    _startOutboxWorker();

    if (vault.isCorrupted) {
      state = state.copyWith(
        isBootstrapping: false,
        blockerReason: BlockerReason.dbMigrationFailure,
        blockerMessage:
            'Database lokal SQLCipher (adoetz_vault.db) memerlukan pemulihan integritas.',
      );
      return;
    }

    state = state.copyWith(isBootstrapping: false);
  }

  void _listenConnectivity() {
    try {
      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
        final offline = results.contains(ConnectivityResult.none);
        if (offline != state.isOffline) {
          setOfflineMode(offline);
        }
      });
    } catch (_) {}
  }

  void _startOutboxWorker() {
    _outboxTimer?.cancel();
    _outboxTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!state.isOffline && state.isAuthenticated) {
        flushOutboxQueue();
      }
    });
  }

  void _seedInitialDirectoryAndAuditLogs() {
    final now = DateTime.now();
    final initialDirectory = <ContactDirectoryEntry>[
      ContactDirectoryEntry(
        userId: 'usr_alex_01',
        username: 'alex',
        displayName: 'Alex Pratama',
        bio: 'Principal Systems Architect • Signal E2EE & Rust FFI',
        identityPublicKeyB64: base64EncodeSimple('alex_identity_pub_v2_curve25519_key'),
        isVerified: true,
        role: 'user',
        accountStatus: 'active',
        createdAt: now.subtract(const Duration(days: 42)),
        email: 'alex@adoetz52.my.id',
      ),
      ContactDirectoryEntry(
        userId: 'usr_nadia_02',
        username: 'nadia',
        displayName: 'Nadia Putri',
        bio: 'Product Designer • Precision Neutral Messenger v2.0',
        identityPublicKeyB64: base64EncodeSimple('nadia_identity_pub_v2_curve25519_key'),
        isVerified: true,
        role: 'user',
        accountStatus: 'active',
        createdAt: now.subtract(const Duration(days: 30)),
        email: 'nadia@adoetz52.my.id',
      ),
      ContactDirectoryEntry(
        userId: 'usr_budi_03',
        username: 'budi',
        displayName: 'Budi Santoso',
        bio: 'DevSecOps & Infrastructure • Coturn WebRTC',
        identityPublicKeyB64: base64EncodeSimple('budi_identity_pub_v2_curve25519_key'),
        isVerified: false,
        role: 'user',
        accountStatus: 'active',
        createdAt: now.subtract(const Duration(days: 19)),
        email: 'budi@adoetz52.my.id',
      ),
      ContactDirectoryEntry(
        userId: 'usr_rina_04',
        username: 'rina_sec',
        displayName: 'Rina Wulandari',
        bio: 'Security Auditor • Penetration Testing & RLS Verification',
        identityPublicKeyB64: base64EncodeSimple('rina_identity_pub_v2_curve25519_key'),
        isVerified: false,
        role: 'user',
        accountStatus: 'suspended',
        createdAt: now.subtract(const Duration(days: 12)),
        email: 'rina@adoetz52.my.id',
      ),
      ContactDirectoryEntry(
        userId: 'usr_admin_00',
        username: 'superadmin',
        displayName: 'Adoetz Security Admin',
        bio: 'Platform Administrator (Zero E2EE Plaintext Access)',
        identityPublicKeyB64: base64EncodeSimple('admin_identity_pub_v2_curve25519_key'),
        isVerified: true,
        role: 'admin',
        accountStatus: 'active',
        createdAt: now.subtract(const Duration(days: 90)),
        email: 'admin@adoetz52.my.id',
      ),
    ];

    final initialLogs = <AdminAuditLogEntry>[
      AdminAuditLogEntry(
        id: 'aud_01',
        requestId: 'req_01JBM9A82C9011',
        timestamp: now.subtract(const Duration(hours: 6)),
        actorUsername: 'superadmin',
        action: 'SUSPEND_USER',
        targetUsername: 'rina_sec',
        reason: 'Deteksi percobaan enumerasi endpoint otomatis melebihi rate-limit.',
      ),
      AdminAuditLogEntry(
        id: 'aud_02',
        requestId: 'req_01JBM7F01E4420',
        timestamp: now.subtract(const Duration(days: 1, hours: 3)),
        actorUsername: 'superadmin',
        action: 'REVOKE_SESSIONS',
        targetUsername: 'budi',
        reason: 'Permintaan pengguna setelah rotasi perangkat pengujian.',
      ),
    ];

    state = state.copyWith(
      directory: initialDirectory,
      adminAuditLogs: initialLogs,
    );
  }

  static String base64EncodeSimple(String input) {
    final bytes = input.codeUnits;
    final padded = List<int>.generate(32, (i) => bytes[i % bytes.length]);
    return Uri.encodeComponent(String.fromCharCodes(padded)).padRight(44, 'A').substring(0, 44);
  }

  // ---------------------------------------------------------------------------
  // Theme & Preferences (UI-19 & UI-20)
  // ---------------------------------------------------------------------------

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  void setOfflineMode(bool offline) {
    state = state.copyWith(isOffline: offline);
    if (!offline && state.isAuthenticated) {
      flushOutboxQueue();
    }
    // ERR-08: If active call is connected when network switches, trigger ICE restart
    final call = state.activeCall;
    if (call != null && call.phase == ActiveCallPhase.connected && !offline) {
      triggerCallIceRestart();
    }
  }

  void dismissNotificationBanner({bool granted = false}) {
    state = state.copyWith(
      notificationPermissionDismissed: true,
      notificationPermissionGranted: granted,
    );
  }

  void toggleReadReceipts(bool enabled) {
    state = state.copyWith(readReceiptsEnabled: enabled);
  }

  void toggleTypingIndicators(bool enabled) {
    state = state.copyWith(typingIndicatorsEnabled: enabled);
  }

  Future<void> toggleScreenshotProtection(bool enabled) async {
    await vault.setScreenshotProtection(enabled);
    state = state.copyWith(screenshotProtectionEnabled: enabled);
  }

  void configureAppLock({required bool enabled, String? newPin}) {
    state = state.copyWith(
      appLockEnabled: enabled,
      appLockPin: newPin ?? state.appLockPin,
      isAppLocked: false,
    );
  }

  void lockAppNow() {
    if (state.appLockEnabled) {
      state = state.copyWith(isAppLocked: true);
    }
  }

  bool unlockAppWithPin(String pin) {
    if (pin == state.appLockPin) {
      state = state.copyWith(isAppLocked: false);
      return true;
    }
    return false;
  }

  void unlockAppWithBiometrics() {
    state = state.copyWith(isAppLocked: false);
  }

  // ---------------------------------------------------------------------------
  // Atomic Open Registration & Sign In (Section 7.1, UI-03, UI-04, UI-05, ERR-03, ERR-04)
  // ---------------------------------------------------------------------------

  Future<EdgeFunctionEnvelope<Map<String, dynamic>>> checkUsername(String raw) {
    final existing = state.directory.map((e) => e.username.toLowerCase()).toSet();
    return gateway.checkUsernameAvailability(
      rawUsername: raw,
      existingUsernamesLower: existing,
    );
  }

  /// Section 7.1: Atomic Open Registration (Anti-Split-State).
  /// Enforces Cloudflare Turnstile token, regex username validation, uniqueness check (ERR-03),
  /// locks role strictly to `'user'` (DoD #2), and generates Identity Key + Signed PreKey + 100 OTPKs.
  Future<({bool ok, String? error})> registerNewAccount({
    required String username,
    required String email,
    required String password,
    required String turnstileToken,
    Map<String, dynamic>? injectedMetadata,
    required void Function(String stepLabel) onStepChange,
  }) async {
    if (turnstileToken.trim().isEmpty) {
      return (
        ok: false,
        error: 'TURNSTILE_REQUIRED: Verifikasi anti-bot Cloudflare Turnstile wajib diselesaikan.'
      );
    }

    // DoD #2: Reject any client attempt to inject role='admin' in signup metadata!
    if (injectedMetadata != null &&
        injectedMetadata['role'] != null &&
        injectedMetadata['role'] != 'user') {
      return (
        ok: false,
        error: 'PRIVILEGE_ESCALATION_DENIED: Injeksi role pada metadata pendaftaran ditolak server.'
      );
    }

    final normalizedUsername = username.trim().toLowerCase().replaceAll('@', '');
    final check = await checkUsername(normalizedUsername);
    final isAvailable = check.data?['available'] == true;
    if (!isAvailable) {
      return (
        ok: false,
        error: (check.data?['reason'] as String?) ??
            'Username baru saja digunakan, silakan pilih yang lain'
      );
    }

    if (password.length < 12) {
      return (ok: false, error: 'Password wajib minimal 12 karakter.');
    }

    onStepChange('(1/2) Mendaftarkan akun...');
    await Future<void>.delayed(const Duration(milliseconds: 280));

    onStepChange('(2/2) Mengamankan kunci perangkat...');
    final keyBundle = await crypto.generateDeviceKeyBundle(oneTimePreKeyCount: 100);
    final newUserId = 'usr_${_uuid.v4().substring(0, 8)}';
    final deviceId = 'dev_${_uuid.v4().substring(0, 8)}';

    final newEntry = ContactDirectoryEntry(
      userId: newUserId,
      username: normalizedUsername,
      displayName: normalizedUsername,
      bio: 'Pengguna terenkripsi Adoetz Chat 2',
      identityPublicKeyB64: keyBundle.identityPublicKeyB64,
      isVerified: true,
      role: 'user', // Strictly locked to 'user' by trigger handle_new_user_signup()
      accountStatus: 'active',
      createdAt: DateTime.now(),
      email: email.trim().toLowerCase(),
    );

    _credentialsByUsername[normalizedUsername] = password;

    await _initializeSampleChatsForUser(
      localUserId: newUserId,
      localIdentityPublicKeyB64: keyBundle.identityPublicKeyB64,
    );

    state = state.copyWith(
      isAuthenticated: true,
      currentUserId: newUserId,
      currentUsername: normalizedUsername,
      currentEmail: email.trim().toLowerCase(),
      currentDisplayName: normalizedUsername,
      currentBio: 'Pengguna terenkripsi Adoetz Chat 2',
      currentRole: 'user',
      accountStatus: 'active',
      activeDeviceId: deviceId,
      deviceKeyBundle: keyBundle,
      remainingOneTimePreKeys: keyBundle.oneTimePreKeys.length,
      lastSignedPreKeyRotation: DateTime.now(),
      directory: [...state.directory, newEntry],
      conversations: vault.getSortedConversations(),
      callHistory: _buildInitialCallHistory(),
      blockerReason: BlockerReason.none,
    );

    return (ok: true, error: null);
  }

  /// Sign In via `@username`, `username`, or `email` (UI-04 & UI-05).
  /// Detects Single-Active-Device conflict (ERR-04) and Suspended account status (ERR-07).
  Future<({bool ok, bool requiresDeviceReplacement, String? error})> signIn({
    required String identifier,
    required String password,
    bool forceReplaceDevice = false,
  }) async {
    final cleanId = identifier.trim().toLowerCase().replaceAll('@', '');
    if (cleanId.isEmpty || password.isEmpty) {
      return (
        ok: false,
        requiresDeviceReplacement: false,
        error: 'Masukkan username/email dan password Anda.'
      );
    }

    // Lookup user by username or email
    ContactDirectoryEntry? matchedUser;
    for (final entry in state.directory) {
      if (entry.username.toLowerCase() == cleanId ||
          entry.email.toLowerCase() == identifier.trim().toLowerCase()) {
        matchedUser = entry;
        break;
      }
    }

    final resolvedUsername = matchedUser?.username ?? cleanId;
    final resolvedRole =
        (resolvedUsername == 'superadmin') ? 'admin' : (matchedUser?.role ?? 'user');
    final resolvedStatus = matchedUser?.accountStatus ?? 'active';

    if (resolvedStatus == 'suspended') {
      state = state.copyWith(
        blockerReason: BlockerReason.accountSuspended,
        blockerMessage:
            'Akun @$resolvedUsername telah ditangguhkan oleh Administrator karena pelanggaran kebijakan keamanan.',
      );
      return (
        ok: false,
        requiresDeviceReplacement: false,
        error: 'ACCOUNT_SUSPENDED'
      );
    }

    // ERR-04 / UI-05: Strict Single-Active-Device Conflict Detection
    if (!forceReplaceDevice &&
        _accountsWithActiveOtherDevice.contains(resolvedUsername)) {
      final conflict = PendingDeviceConflict(
        identifier: identifier,
        userId: matchedUser?.userId ?? 'usr_$resolvedUsername',
        username: resolvedUsername,
        email: matchedUser?.email ?? '$resolvedUsername@adoetz52.my.id',
        displayName: matchedUser?.displayName ?? resolvedUsername,
        role: resolvedRole,
        existingDeviceName: 'Samsung Galaxy S24 Ultra (Aktif)',
      );
      state = state.copyWith(pendingDeviceConflict: conflict);
      return (
        ok: false,
        requiresDeviceReplacement: true,
        error: 'ACTIVE_DEVICE_CONFLICT'
      );
    }

    final keyBundle = await crypto.generateDeviceKeyBundle(oneTimePreKeyCount: 100);
    final userId = matchedUser?.userId ?? 'usr_${_uuid.v4().substring(0, 8)}';
    final deviceId = 'dev_${_uuid.v4().substring(0, 8)}';

    _accountsWithActiveOtherDevice.remove(resolvedUsername);

    await _initializeSampleChatsForUser(
      localUserId: userId,
      localIdentityPublicKeyB64: keyBundle.identityPublicKeyB64,
    );

    state = state.copyWith(
      isAuthenticated: true,
      currentUserId: userId,
      currentUsername: resolvedUsername,
      currentEmail: matchedUser?.email ?? '$resolvedUsername@adoetz52.my.id',
      currentDisplayName: matchedUser?.displayName ?? resolvedUsername,
      currentBio: matchedUser?.bio ?? 'Komunikasi Privat E2EE Adoetz Chat 2',
      currentRole: resolvedRole,
      accountStatus: 'active',
      activeDeviceId: deviceId,
      deviceKeyBundle: keyBundle,
      remainingOneTimePreKeys: keyBundle.oneTimePreKeys.length,
      lastSignedPreKeyRotation: DateTime.now(),
      clearPendingDeviceConflict: true,
      conversations: vault.getSortedConversations(),
      callHistory: _buildInitialCallHistory(),
      blockerReason: BlockerReason.none,
    );

    return (ok: true, requiresDeviceReplacement: false, error: null);
  }

  void cancelDeviceConflict() {
    state = state.copyWith(clearPendingDeviceConflict: true);
  }

  Future<void> confirmDeviceReplacementAndSignIn(String password) async {
    final conflict = state.pendingDeviceConflict;
    if (conflict == null) return;
    await signIn(
      identifier: conflict.username,
      password: password,
      forceReplaceDevice: true,
    );
  }

  Future<void> signOut({bool wipeLocalData = false}) async {
    _callTimer?.cancel();
    if (wipeLocalData) {
      await vault.wipeAllLocalVaultData();
    }
    state = AppState(
      isBootstrapping: false,
      isAuthenticated: false,
      themeMode: state.themeMode,
      directory: state.directory,
      adminAuditLogs: state.adminAuditLogs,
    );
  }

  Future<void> _initializeSampleChatsForUser({
    required String localUserId,
    required String localIdentityPublicKeyB64,
  }) async {
    if (vault.getSortedConversations().isNotEmpty) return;

    final now = DateTime.now();
    final alex = state.directory.firstWhere((c) => c.username == 'alex');
    final nadia = state.directory.firstWhere((c) => c.username == 'nadia');
    final budi = state.directory.firstWhere((c) => c.username == 'budi');

    final convAlex = LocalConversation(
      id: 'conv_alex',
      peerUserId: alex.userId,
      peerUsername: alex.username,
      peerDisplayName: alex.displayName,
      peerBio: alex.bio,
      peerIdentityKeyB64: alex.identityPublicKeyB64,
      isVerified: true,
      isPinned: true,
      lastMessageSnippet: 'Besok kita review skema Supabase & RLS v2.0 ya',
      lastEventAt: now.subtract(const Duration(minutes: 12)),
      unreadCount: 2,
    );

    final convNadia = LocalConversation(
      id: 'conv_nadia',
      peerUserId: nadia.userId,
      peerUsername: nadia.username,
      peerDisplayName: nadia.displayName,
      peerBio: nadia.bio,
      peerIdentityKeyB64: nadia.identityPublicKeyB64,
      isVerified: true,
      isPinned: false,
      lastMessageSnippet: '📷 [Foto] Lampiran desain Precision Neutral v2.0',
      lastEventAt: now.subtract(const Duration(hours: 5)),
      unreadCount: 0,
      lastOutgoingStatus: MessageDeliveryStatus.read,
    );

    final convBudi = LocalConversation(
      id: 'conv_budi',
      peerUserId: budi.userId,
      peerUsername: budi.username,
      peerDisplayName: budi.displayName,
      peerBio: budi.bio,
      peerIdentityKeyB64: budi.identityPublicKeyB64,
      isVerified: false,
      isPinned: false,
      lastMessageSnippet: 'Siap, server Coturn TURN HMAC sudah aktif.',
      lastEventAt: now.subtract(const Duration(days: 1, hours: 2)),
      unreadCount: 0,
      lastOutgoingStatus: MessageDeliveryStatus.delivered,
    );

    await vault.upsertConversation(convAlex);
    await vault.upsertConversation(convNadia);
    await vault.upsertConversation(convBudi);

    // Seed messages in conv_alex
    final sessionAlex = await crypto.createDeterministicSession(
      localUserId: localUserId,
      peerUserId: alex.userId,
      peerDeviceId: 'dev_alex_01',
      localIdentityPublicKeyB64: localIdentityPublicKeyB64,
      peerIdentityPublicKeyB64: alex.identityPublicKeyB64,
    );
    vault.saveRatchetSession(sessionAlex);

    await vault.saveMessageAndOutboxAtomically(
      message: LocalMessage(
        clientMessageId: 'msg_alex_1',
        serverMessageId: 'srv_alex_1',
        conversationId: 'conv_alex',
        senderId: alex.userId,
        isOutgoing: false,
        plaintext: 'Halo, apakah arsitektur X3DH + Double Ratchet dan SQLCipher sudah siap?',
        ciphertextB64: 'e2ee_cipher_alex_1',
        status: MessageDeliveryStatus.read,
        createdAt: now.subtract(const Duration(minutes: 18)),
      ),
    );

    await vault.saveMessageAndOutboxAtomically(
      message: LocalMessage(
        clientMessageId: 'msg_alex_2',
        serverMessageId: 'srv_alex_2',
        conversationId: 'conv_alex',
        senderId: localUserId,
        isOutgoing: true,
        plaintext: 'Sudah siap, ini sedang di-build di CI GitHub Actions.',
        ciphertextB64: 'e2ee_cipher_alex_2',
        status: MessageDeliveryStatus.read,
        createdAt: now.subtract(const Duration(minutes: 16)),
        replyToMessageId: 'msg_alex_1',
        replyToSenderName: 'Alex Pratama',
        replyToSnippet:
            'Halo, apakah arsitektur X3DH + Double Ratchet dan SQLCipher sudah siap?',
      ),
    );

    await vault.saveMessageAndOutboxAtomically(
      message: LocalMessage(
        clientMessageId: 'msg_alex_3',
        serverMessageId: 'srv_alex_3',
        conversationId: 'conv_alex',
        senderId: localUserId,
        isOutgoing: true,
        plaintext: 'Pesan Suara E2EE',
        ciphertextB64: 'e2ee_cipher_alex_3',
        status: MessageDeliveryStatus.read,
        createdAt: now.subtract(const Duration(minutes: 14)),
        attachmentKind: AttachmentKind.voiceNote,
        voiceDurationSeconds: 42,
        voiceWaveform: const [
          0.25, 0.5, 0.8, 0.4, 0.9, 0.7, 0.3, 0.6, 0.95, 0.5, 0.35, 0.75,
          0.6, 0.4, 0.85, 0.55, 0.3, 0.7, 0.5, 0.4, 0.65, 0.45, 0.3, 0.2,
        ],
      ),
    );

    await vault.saveMessageAndOutboxAtomically(
      message: LocalMessage(
        clientMessageId: 'msg_alex_4',
        serverMessageId: 'srv_alex_4',
        conversationId: 'conv_alex',
        senderId: alex.userId,
        isOutgoing: false,
        plaintext: 'Besok kita review skema Supabase & RLS v2.0 ya',
        ciphertextB64: 'e2ee_cipher_alex_4',
        status: MessageDeliveryStatus.delivered,
        createdAt: now.subtract(const Duration(minutes: 12)),
      ),
    );

    // Seed messages in conv_nadia
    await vault.saveMessageAndOutboxAtomically(
      message: LocalMessage(
        clientMessageId: 'msg_nadia_1',
        serverMessageId: 'srv_nadia_1',
        conversationId: 'conv_nadia',
        senderId: localUserId,
        isOutgoing: true,
        plaintext: 'Lampiran desain Precision Neutral v2.0',
        ciphertextB64: 'e2ee_cipher_nadia_1',
        status: MessageDeliveryStatus.read,
        createdAt: now.subtract(const Duration(hours: 5)),
        attachmentKind: AttachmentKind.image,
        attachmentName: 'precision_neutral_tokens_v2.png.enc',
        attachmentSizeBytes: 842100,
        attachmentSha256Hex:
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      ),
    );

    // Restore unread count on conv_alex
    await vault.upsertConversation(convAlex.copyWith(unreadCount: 2));
  }

  List<LocalCallRecord> _buildInitialCallHistory() {
    final now = DateTime.now();
    return [
      LocalCallRecord(
        id: 'call_hist_1',
        peerUserId: 'usr_alex_01',
        peerUsername: 'alex',
        peerDisplayName: 'Alex Pratama',
        isVideo: false,
        direction: CallDirection.incoming,
        startedAt: now.subtract(const Duration(hours: 2, minutes: 15)),
        durationSeconds: 312,
      ),
      LocalCallRecord(
        id: 'call_hist_2',
        peerUserId: 'usr_nadia_02',
        peerUsername: 'nadia',
        peerDisplayName: 'Nadia Putri',
        isVideo: true,
        direction: CallDirection.outgoing,
        startedAt: now.subtract(const Duration(days: 1, hours: 4)),
        durationSeconds: 745,
      ),
      LocalCallRecord(
        id: 'call_hist_3',
        peerUserId: 'usr_budi_03',
        peerUsername: 'budi',
        peerDisplayName: 'Budi Santoso',
        isVideo: false,
        direction: CallDirection.missed,
        startedAt: now.subtract(const Duration(days: 2, hours: 1)),
        durationSeconds: 0,
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Chat List & Room Actions (UI-07, UI-10..UI-13)
  // ---------------------------------------------------------------------------

  void toggleSelectConversation(String conversationId) {
    final next = Set<String>.from(state.selectedConversationIds);
    if (next.contains(conversationId)) {
      next.remove(conversationId);
    } else {
      next.add(conversationId);
    }
    state = state.copyWith(selectedConversationIds: next);
  }

  void clearSelectedConversations() {
    state = state.copyWith(selectedConversationIds: const {});
  }

  Future<void> togglePinSelectedConversations() async {
    for (final id in state.selectedConversationIds) {
      final conv = vault.getConversation(id);
      if (conv != null) {
        await vault.upsertConversation(conv.copyWith(isPinned: !conv.isPinned));
      }
    }
    state = state.copyWith(
      conversations: vault.getSortedConversations(),
      selectedConversationIds: const {},
    );
  }

  Future<void> toggleMuteSelectedConversations() async {
    for (final id in state.selectedConversationIds) {
      final conv = vault.getConversation(id);
      if (conv != null) {
        await vault.upsertConversation(conv.copyWith(isMuted: !conv.isMuted));
      }
    }
    state = state.copyWith(
      conversations: vault.getSortedConversations(),
      selectedConversationIds: const {},
    );
  }

  Future<void> deleteSelectedConversationsLocal() async {
    for (final id in state.selectedConversationIds) {
      await vault.deleteConversationLocal(id);
    }
    state = state.copyWith(
      conversations: vault.getSortedConversations(),
      selectedConversationIds: const {},
    );
  }

  Future<void> markConversationRead(String conversationId) async {
    final conv = vault.getConversation(conversationId);
    if (conv != null && conv.unreadCount > 0) {
      await vault.upsertConversation(conv.copyWith(unreadCount: 0));
      state = state.copyWith(conversations: vault.getSortedConversations());
    }
  }

  Future<String> startOrGetConversationWithContact(
    ContactDirectoryEntry contact,
  ) async {
    for (final existing in vault.getSortedConversations()) {
      if (existing.peerUserId == contact.userId ||
          existing.peerUsername == contact.username) {
        return existing.id;
      }
    }

    final newConv = LocalConversation(
      id: 'conv_${contact.username}',
      peerUserId: contact.userId,
      peerUsername: contact.username,
      peerDisplayName: contact.displayName,
      peerBio: contact.bio,
      peerIdentityKeyB64: contact.identityPublicKeyB64,
      isVerified: contact.isVerified,
      lastMessageSnippet: '🔒 Percakapan terenkripsi end-to-end siap dimulai',
      lastEventAt: DateTime.now(),
    );
    await vault.upsertConversation(newConv);
    state = state.copyWith(conversations: vault.getSortedConversations());
    return newConv.id;
  }

  /// Sends an E2EE encrypted message (Text, Reply, Attachment, or Voice Note)
  /// following Section 7.2: Optimistic Outbox -> X3DH/Double Ratchet -> Idempotent Send.
  Future<({bool ok, String? error})> sendEncryptedMessage({
    required String conversationId,
    required String plaintext,
    String? replyToMessageId,
    String? replyToSenderName,
    String? replyToSnippet,
    AttachmentKind attachmentKind = AttachmentKind.none,
    String? attachmentName,
    Uint8List? attachmentRawBytes,
    int? voiceDurationSeconds,
    List<double>? voiceWaveform,
  }) async {
    // ERR-07: Check if caller is suspended
    if (state.accountStatus != 'active') {
      state = state.copyWith(
        blockerReason: BlockerReason.accountSuspended,
        blockerMessage: 'Akun Anda telah ditangguhkan oleh Administrator.',
      );
      return (
        ok: false,
        error: 'Akun Anda telah ditangguhkan oleh Administrator'
      );
    }

    final conv = vault.getConversation(conversationId);
    if (conv == null) {
      return (ok: false, error: 'Percakapan tidak ditemukan');
    }

    if (conv.isBlocked) {
      return (
        ok: false,
        error: 'Tidak dapat mengirim pesan ke kontak yang diblokir.'
      );
    }

    // ERR-05: Hold message if peer's Identity Key changed until reviewed/accepted
    if (conv.peerKeyChangedWarning) {
      return (
        ok: false,
        error:
            'Identitas keamanan @${conv.peerUsername} berubah. Tinjau & terima kunci baru terlebih dahulu.'
      );
    }

    final senderId = state.currentUserId ?? 'usr_local';
    final clientMessageId = _uuid.v4();
    final now = DateTime.now();

    // Ensure RatchetSessionState exists
    var session = vault.getRatchetSession(conv.peerUserId);
    session ??= await crypto.createDeterministicSession(
      localUserId: senderId,
      peerUserId: conv.peerUserId,
      peerDeviceId: 'dev_${conv.peerUsername}',
      localIdentityPublicKeyB64:
          state.deviceKeyBundle?.identityPublicKeyB64 ?? 'local_id_key',
      peerIdentityPublicKeyB64: conv.peerIdentityKeyB64,
    );

    String? fileKeyB64;
    String? fileSha256Hex;
    int? fileSizeBytes = attachmentRawBytes?.length;

    if (attachmentRawBytes != null && attachmentRawBytes.isNotEmpty) {
      final encryptedFile = await crypto.encryptAttachment(attachmentRawBytes);
      fileKeyB64 = encryptedFile.fileKeyB64;
      fileSha256Hex = encryptedFile.sha256Hex;
      fileSizeBytes = encryptedFile.encryptedBytes.length;
    }

    final envelopePayload = <String, dynamic>{
      'body': plaintext,
      'ts': now.toUtc().toIso8601String(),
      'reply_to': replyToMessageId,
      'att_kind': attachmentKind.name,
      'att_name': attachmentName,
      'att_key': fileKeyB64,
      'att_sha256': fileSha256Hex,
      'voice_dur': voiceDurationSeconds,
    };

    final encrypted = await crypto.encryptMessage(
      session: session,
      plaintextPayload: envelopePayload,
    );

    final initialStatus = state.isOffline
        ? MessageDeliveryStatus.queued
        : MessageDeliveryStatus.sending;

    final localMsg = LocalMessage(
      clientMessageId: clientMessageId,
      conversationId: conversationId,
      senderId: senderId,
      isOutgoing: true,
      plaintext: plaintext,
      ciphertextB64: encrypted.ciphertextB64,
      status: initialStatus,
      createdAt: now,
      replyToMessageId: replyToMessageId,
      replyToSenderName: replyToSenderName,
      replyToSnippet: replyToSnippet,
      attachmentKind: attachmentKind,
      attachmentName: attachmentName,
      attachmentSizeBytes: fileSizeBytes,
      voiceDurationSeconds: voiceDurationSeconds,
      voiceWaveform: voiceWaveform,
      attachmentFileKeyB64: fileKeyB64,
      attachmentSha256Hex: fileSha256Hex,
    );

    // Step 1: Atomic save of ratchet state + message + outbox entry (<16ms UI update)
    await vault.saveMessageAndOutboxAtomically(
      message: localMsg,
      updatedRatchetSession: encrypted.nextSessionState,
      enqueueInOutbox: true,
    );

    state = state.copyWith(conversations: vault.getSortedConversations());

    if (!state.isOffline) {
      await _deliverOutboxMessage(
        senderId: senderId,
        clientMessageId: clientMessageId,
      );
    }

    return (ok: true, error: null);
  }

  Future<void> _deliverOutboxMessage({
    required String senderId,
    required String clientMessageId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (state.isOffline) return;

    final serverMsgId = 'srv_${clientMessageId.substring(0, 8)}';
    await vault.acknowledgeOutboxMessage(
      senderId: senderId,
      clientMessageId: clientMessageId,
      serverMessageId: serverMsgId,
      newStatus: MessageDeliveryStatus.sent,
    );
    state = state.copyWith(conversations: vault.getSortedConversations());

    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (state.isOffline) return;

    await vault.acknowledgeOutboxMessage(
      senderId: senderId,
      clientMessageId: clientMessageId,
      serverMessageId: serverMsgId,
      newStatus: state.readReceiptsEnabled
          ? MessageDeliveryStatus.read
          : MessageDeliveryStatus.delivered,
    );
    state = state.copyWith(conversations: vault.getSortedConversations());
  }

  /// Flushes all pending messages in `outbox_queue` when connectivity returns (ERR-01 & ERR-02).
  Future<void> flushOutboxQueue() async {
    final pending = vault.getPendingOutboxEntries();
    for (final entry in pending) {
      if (state.isOffline) break;
      await _deliverOutboxMessage(
        senderId: entry.senderId,
        clientMessageId: entry.clientMessageId,
      );
    }
  }

  Future<void> editMessage({
    required String conversationId,
    required String clientMessageId,
    required String newPlaintext,
  }) async {
    final messages = vault.getMessages(conversationId);
    final idx = messages.indexWhere((m) => m.clientMessageId == clientMessageId);
    if (idx < 0) return;
    final target = messages[idx];
    // Allowed if own message & < 15 minutes
    if (!target.isOutgoing ||
        DateTime.now().difference(target.createdAt).inMinutes >= 15) {
      return;
    }
    final updated = target.copyWith(
      plaintext: newPlaintext.trim(),
      isEdited: true,
    );
    await vault.saveMessageAndOutboxAtomically(message: updated);
    state = state.copyWith(conversations: vault.getSortedConversations());
  }

  Future<void> revokeMessageForEveryone({
    required String conversationId,
    required String clientMessageId,
  }) async {
    final messages = vault.getMessages(conversationId);
    final idx = messages.indexWhere((m) => m.clientMessageId == clientMessageId);
    if (idx < 0) return;
    final updated = messages[idx].copyWith(
      plaintext: 'Pesan ini telah dihapus untuk semua orang',
      isRevokedForAll: true,
    );
    await vault.saveMessageAndOutboxAtomically(message: updated);
    state = state.copyWith(conversations: vault.getSortedConversations());
  }

  Future<void> toggleReaction({
    required String conversationId,
    required String clientMessageId,
    required String emoji,
  }) async {
    final messages = vault.getMessages(conversationId);
    final idx = messages.indexWhere((m) => m.clientMessageId == clientMessageId);
    if (idx < 0) return;
    final msg = messages[idx];
    final currentUserId = state.currentUserId ?? 'usr_local';
    final nextReactions = Map<String, String>.from(msg.reactions);
    if (nextReactions[currentUserId] == emoji) {
      nextReactions.remove(currentUserId);
    } else {
      nextReactions[currentUserId] = emoji;
    }
    await vault.saveMessageAndOutboxAtomically(
      message: msg.copyWith(reactions: nextReactions),
    );
    state = state.copyWith(conversations: vault.getSortedConversations());
  }

  /// Simulates ERR-05: Peer changed phone / reinstalled app (Identity Key Changed).
  Future<void> simulatePeerIdentityKeyChange(String conversationId) async {
    final conv = vault.getConversation(conversationId);
    if (conv == null) return;
    final newKey = base64EncodeSimple(
      'rotated_key_${conv.peerUsername}_${DateTime.now().millisecondsSinceEpoch}',
    );
    await vault.upsertConversation(
      conv.copyWith(peerIdentityKeyB64: newKey),
    );
    state = state.copyWith(conversations: vault.getSortedConversations());
  }

  Future<void> acceptAndVerifyPeerKey({
    required String conversationId,
    required bool markVerified,
  }) async {
    final conv = vault.getConversation(conversationId);
    if (conv == null) return;
    await vault.acceptNewPeerIdentityKey(
      conversationId: conversationId,
      newIdentityKeyB64: conv.peerIdentityKeyB64,
      markVerified: markVerified,
    );
    final updatedDir = state.directory.map((c) {
      if (c.userId == conv.peerUserId) {
        return c.copyWith(isVerified: markVerified);
      }
      return c;
    }).toList();
    state = state.copyWith(
      conversations: vault.getSortedConversations(),
      directory: updatedDir,
    );
  }

  // ---------------------------------------------------------------------------
  // Profile, Contacts, Block & Report, PreKey Replenishment (UI-08, UI-09, UI-21)
  // ---------------------------------------------------------------------------

  void updateOwnProfile({
    required String displayName,
    required String bio,
    required bool discoverable,
  }) {
    final cleanBio = bio.length > 160 ? bio.substring(0, 160) : bio;
    state = state.copyWith(
      currentDisplayName: displayName.trim(),
      currentBio: cleanBio.trim(),
      isDiscoverable: discoverable,
    );
  }

  Future<void> toggleBlockContact(String userId) async {
    final updatedDir = state.directory.map((c) {
      if (c.userId == userId) {
        return c.copyWith(isBlocked: !c.isBlocked);
      }
      return c;
    }).toList();

    for (final conv in vault.getSortedConversations()) {
      if (conv.peerUserId == userId) {
        await vault.upsertConversation(conv.copyWith(isBlocked: !conv.isBlocked));
      }
    }

    state = state.copyWith(
      directory: updatedDir,
      conversations: vault.getSortedConversations(),
    );
  }

  Future<void> replenishOneTimePreKeys() async {
    final newKeys = await crypto.generateOneTimePreKeys(
      startId: 101,
      count: 80,
    );
    state = state.copyWith(
      remainingOneTimePreKeys: state.remainingOneTimePreKeys + newKeys.length,
    );
  }

  Future<void> rotateSignedPreKeyNow() async {
    state = state.copyWith(lastSignedPreKeyRotation: DateTime.now());
  }

  // ---------------------------------------------------------------------------
  // WebRTC 1:1 Calls, Mini-Call Pill, TTL Check (ERR-06), & ICE Restart (ERR-08)
  // ---------------------------------------------------------------------------

  void startOutgoingCall({
    required ContactDirectoryEntry peer,
    required bool isVideo,
  }) {
    _callTimer?.cancel();
    final callId = 'call_${_uuid.v4().substring(0, 8)}';
    final turnConfig = gateway.issueEphemeralTurnCredentials(
      state.currentUserId ?? 'usr_local',
    );
    final expiresAtMs = DateTime.now().millisecondsSinceEpoch + 40000;

    final session = ActiveCallSession(
      callId: callId,
      peerUserId: peer.userId,
      peerUsername: peer.username,
      peerDisplayName: peer.displayName,
      isVideo: isVideo,
      phase: ActiveCallPhase.outgoingRinging,
      isSpeakerOn: isVideo,
      isCameraOn: isVideo,
      expiresAtMs: expiresAtMs,
      turnConfig: turnConfig,
    );

    state = state.copyWith(activeCall: session);

    // Auto-connect after 1.6s to demonstrate full WebRTC connected call flow
    Timer(const Duration(milliseconds: 1600), () {
      final current = state.activeCall;
      if (current != null &&
          current.callId == callId &&
          current.phase == ActiveCallPhase.outgoingRinging) {
        acceptIncomingOrConnectCall();
      }
    });
  }

  /// Handles incoming call payload with strict 40-second TTL validation (ERR-06).
  Future<bool> receiveIncomingCall({
    required ContactDirectoryEntry peer,
    required bool isVideo,
    int? customExpiresAtMs,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final expiresAtMs = customExpiresAtMs ?? (nowMs + 40000);
    final callId = 'call_${_uuid.v4().substring(0, 8)}';

    // ERR-06: If FCM wakeup arrived late (> expires_at_ms), record Missed Call without ringing!
    if (nowMs > expiresAtMs) {
      await vault.triggerIncomingCallNotification(
        callId: callId,
        callerName: peer.displayName,
        callerUsername: peer.username,
        isVideo: isVideo,
        expiresAtMs: expiresAtMs,
      );
      final missedRecord = LocalCallRecord(
        id: callId,
        peerUserId: peer.userId,
        peerUsername: peer.username,
        peerDisplayName: peer.displayName,
        isVideo: isVideo,
        direction: CallDirection.missed,
        startedAt: DateTime.now(),
        durationSeconds: 0,
      );
      state = state.copyWith(
        callHistory: [missedRecord, ...state.callHistory],
      );
      return false;
    }

    final turnConfig = gateway.issueEphemeralTurnCredentials(
      state.currentUserId ?? 'usr_local',
    );

    final session = ActiveCallSession(
      callId: callId,
      peerUserId: peer.userId,
      peerUsername: peer.username,
      peerDisplayName: peer.displayName,
      isVideo: isVideo,
      phase: ActiveCallPhase.incomingRinging,
      isSpeakerOn: isVideo,
      isCameraOn: isVideo,
      expiresAtMs: expiresAtMs,
      turnConfig: turnConfig,
    );

    state = state.copyWith(activeCall: session);
    await vault.triggerIncomingCallNotification(
      callId: callId,
      callerName: peer.displayName,
      callerUsername: peer.username,
      isVideo: isVideo,
      expiresAtMs: expiresAtMs,
    );
    return true;
  }

  void acceptIncomingOrConnectCall() {
    final current = state.activeCall;
    if (current == null) return;
    vault.cancelIncomingCallNotification();

    state = state.copyWith(
      activeCall: current.copyWith(
        phase: ActiveCallPhase.connected,
        elapsedSeconds: 0,
      ),
    );

    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final active = state.activeCall;
      if (active == null) {
        _callTimer?.cancel();
        return;
      }
      if (active.phase == ActiveCallPhase.connected ||
          active.phase == ActiveCallPhase.reconnectingIce) {
        state = state.copyWith(
          activeCall: active.copyWith(elapsedSeconds: active.elapsedSeconds + 1),
        );
      }
    });
  }

  /// ERR-08: Simulates Wi-Fi -> 4G/5G handoff triggering `restartIce()` with fresh TURN credentials.
  void triggerCallIceRestart() {
    final current = state.activeCall;
    if (current == null) return;
    final refreshedTurn = gateway.issueEphemeralTurnCredentials(
      state.currentUserId ?? 'usr_local',
    );
    state = state.copyWith(
      activeCall: current.copyWith(
        phase: ActiveCallPhase.reconnectingIce,
        turnConfig: refreshedTurn,
      ),
    );
    Timer(const Duration(seconds: 2), () {
      final after = state.activeCall;
      if (after != null && after.callId == current.callId) {
        state = state.copyWith(
          activeCall: after.copyWith(phase: ActiveCallPhase.connected),
        );
      }
    });
  }

  void setCallMinimizedToPill(bool minimized) {
    final current = state.activeCall;
    if (current == null) return;
    state = state.copyWith(
      activeCall: current.copyWith(isMinimizedToPill: minimized),
    );
  }

  void toggleCallMute() {
    final current = state.activeCall;
    if (current == null) return;
    state = state.copyWith(
      activeCall: current.copyWith(isMuted: !current.isMuted),
    );
  }

  void toggleCallSpeaker() {
    final current = state.activeCall;
    if (current == null) return;
    state = state.copyWith(
      activeCall: current.copyWith(isSpeakerOn: !current.isSpeakerOn),
    );
  }

  void toggleCallCamera() {
    final current = state.activeCall;
    if (current == null) return;
    state = state.copyWith(
      activeCall: current.copyWith(isCameraOn: !current.isCameraOn),
    );
  }

  void flipCallCamera() {
    final current = state.activeCall;
    if (current == null) return;
    state = state.copyWith(
      activeCall: current.copyWith(isFrontCamera: !current.isFrontCamera),
    );
  }

  void endOrDeclineCall({bool declined = false}) {
    _callTimer?.cancel();
    vault.cancelIncomingCallNotification();
    final current = state.activeCall;
    if (current == null) return;

    final record = LocalCallRecord(
      id: current.callId,
      peerUserId: current.peerUserId,
      peerUsername: current.peerUsername,
      peerDisplayName: current.peerDisplayName,
      isVideo: current.isVideo,
      direction: declined
          ? CallDirection.missed
          : (current.phase == ActiveCallPhase.incomingRinging
              ? CallDirection.incoming
              : CallDirection.outgoing),
      startedAt: DateTime.now(),
      durationSeconds: current.elapsedSeconds,
    );

    state = state.copyWith(
      clearActiveCall: true,
      callHistory: [record, ...state.callHistory],
    );
  }

  // ---------------------------------------------------------------------------
  // Admin Privileged Operations & Mandatory Audit Logging (UI-22, UI-23, UI-24)
  // ---------------------------------------------------------------------------

  /// Permits switching to Admin mode in local evaluation/testing or verifies admin role.
  void setRoleForTesting(String role) {
    state = state.copyWith(currentRole: role);
  }

  Future<({bool ok, String? error, String? oneTimePassword})> adminExecuteAction({
    required String targetUserId,
    required String action,
    required String reason,
    String? adminPasswordConfirmation,
  }) async {
    if (!state.isAdmin) {
      return (
        ok: false,
        error: 'UNAUTHORIZED: Hanya role admin aktif yang diizinkan.',
        oneTimePassword: null,
      );
    }

    if (reason.trim().length < 5) {
      return (
        ok: false,
        error: 'Alasan tindakan wajib diisi (minimal 5 karakter) untuk Audit Log.',
        oneTimePassword: null,
      );
    }

    final idx = state.directory.indexWhere((u) => u.userId == targetUserId);
    if (idx < 0) {
      return (
        ok: false,
        error: 'Target pengguna tidak ditemukan.',
        oneTimePassword: null,
      );
    }

    final target = state.directory[idx];
    final reqId = gateway.generateRequestId();
    var updatedDirectory = List<ContactDirectoryEntry>.from(state.directory);
    String? generatedTempPassword;

    switch (action) {
      case 'SUSPEND':
        updatedDirectory[idx] = target.copyWith(accountStatus: 'suspended');
        break;
      case 'UNSUSPEND':
        updatedDirectory[idx] = target.copyWith(accountStatus: 'active');
        break;
      case 'REVOKE_SESSIONS':
        // Revokes active sessions & triggers key rotation requirement
        _accountsWithActiveOtherDevice.add(target.username);
        break;
      case 'FORCE_RESET_PASSWORD':
        if (adminPasswordConfirmation == null ||
            adminPasswordConfirmation.trim().isEmpty) {
          return (
            ok: false,
            error: 'Konfirmasi password Admin wajib untuk Force Password Reset.',
            oneTimePassword: null,
          );
        }
        // Generate one-time temporary password (shown ONLY once in modal, never logged!)
        final rand = Random.secure();
        const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%';
        generatedTempPassword = List.generate(
          16,
          (_) => chars[rand.nextInt(chars.length)],
        ).join();
        _credentialsByUsername[target.username] = generatedTempPassword;
        break;
      case 'TOGGLE_ROLE':
        if (adminPasswordConfirmation == null ||
            adminPasswordConfirmation.trim().isEmpty) {
          return (
            ok: false,
            error: 'Step-up authentication (password Admin) wajib untuk mengubah role.',
            oneTimePassword: null,
          );
        }
        final adminCount =
            state.directory.where((u) => u.role == 'admin').length;
        if (target.role == 'admin' && adminCount <= 1) {
          return (
            ok: false,
            error: 'LAST_ADMIN_PROTECTION: Tidak dapat mencabut admin terakhir di sistem.',
            oneTimePassword: null,
          );
        }
        final nextRole = target.role == 'admin' ? 'user' : 'admin';
        updatedDirectory[idx] = target.copyWith(role: nextRole);
        break;
      case 'SOFT_DELETE':
      case 'HARD_DELETE':
        if (target.username == state.currentUsername) {
          return (
            ok: false,
            error: 'SELF_DELETE_DENIED: Admin tidak dapat menghapus akunnya sendiri dari panel admin.',
            oneTimePassword: null,
          );
        }
        final adminCount =
            state.directory.where((u) => u.role == 'admin').length;
        if (target.role == 'admin' && adminCount <= 1) {
          return (
            ok: false,
            error: 'LAST_ADMIN_PROTECTION: Tidak dapat menghapus admin terakhir.',
            oneTimePassword: null,
          );
        }
        if (action == 'HARD_DELETE') {
          updatedDirectory.removeAt(idx);
        } else {
          updatedDirectory[idx] = target.copyWith(accountStatus: 'soft_deleted');
        }
        break;
      default:
        return (
          ok: false,
          error: 'Aksi tidak dikenali: $action',
          oneTimePassword: null,
        );
    }

    // Append-only Audit Log (Notice: temporary password is NEVER stored in the log!)
    final logEntry = AdminAuditLogEntry(
      id: 'aud_${_uuid.v4().substring(0, 8)}',
      requestId: reqId,
      timestamp: DateTime.now(),
      actorUsername: state.currentUsername.isEmpty ? 'superadmin' : state.currentUsername,
      action: action,
      targetUsername: target.username,
      reason: reason.trim(),
    );

    state = state.copyWith(
      directory: updatedDirectory,
      adminAuditLogs: [logEntry, ...state.adminAuditLogs],
    );

    return (
      ok: true,
      error: null,
      oneTimePassword: generatedTempPassword,
    );
  }

  /// Simulates ERR-07: Admin suspends the currently active user in real time.
  void simulateRealtimeAdminSuspension() {
    state = state.copyWith(
      accountStatus: 'suspended',
      suspendedReason: 'Penangguhan real-time oleh Administrator (RLS is_caller_active() = false).',
      blockerReason: BlockerReason.accountSuspended,
      blockerMessage:
          'Akun Anda telah ditangguhkan oleh Administrator. Seluruh sesi Realtime dan mutasi database telah dihentikan.',
    );
  }

  void clearBlockerAndReturnToWelcome() {
    vault.clearCorruption();
    state = state.copyWith(
      isAuthenticated: false,
      blockerReason: BlockerReason.none,
      accountStatus: 'active',
    );
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _outboxTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
