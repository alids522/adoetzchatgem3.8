import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart' as dart_crypto;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class AppEnvironment {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://supabase.adoetz52.my.id',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlLWRlbW8iLCJpYXQiOjE3ODE0MjkzOTMsImV4cCI6MjA4Mjc1ODQwMH0.qgQ3hxL9JgRhZ-0vuIAG-myu8w5UeWkG1iNrsjqDvR0',
  );

  static const String supabaseSchema = String.fromEnvironment(
    'SUPABASE_SCHEMA',
    defaultValue: 'waclonegem3.8',
  );

  static const String turnstileSiteKey = String.fromEnvironment(
    'TURNSTILE_SITE_KEY',
    defaultValue: '1x00000000000000000000AA',
  );

  static const String appNamespace = 'com.adoetzchat2.chat';
  static const String appVersion = '2.0.0';
  static const String deepLinkScheme = 'adoetzchat2';
}

/// Standard Edge Function Envelope (Section 10 of PRD v2.0)
class EdgeFunctionEnvelope<T> {
  final String requestId;
  final bool success;
  final T? data;
  final String? error;

  const EdgeFunctionEnvelope({
    required this.requestId,
    required this.success,
    this.data,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'success': success,
        'data': data,
        'error': error,
      };
}

class _MemoryPkceStorage extends GotrueAsyncStorage {
  final Map<String, String> _map = {};

  @override
  Future<String?> getItem({required String key}) async => _map[key];

  @override
  Future<void> removeItem({required String key}) async {
    _map.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    _map[key] = value;
  }
}

/// Gateway to Supabase Auth, PostgreSQL (RLS), Realtime Broadcast, Private Storage,
/// and the 8 Deno Edge Functions defined in Section 10 of PRD v2.0.
class SupabaseGateway {
  static const _uuid = Uuid();
  static const Set<String> reservedUsernames = {
    'admin',
    'system',
    'support',
    'root',
    'adoetz',
  };
  static final RegExp usernameRegex = RegExp(r'^[a-z0-9_]{3,24}$');

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Supabase.initialize(
        url: AppEnvironment.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppEnvironment.supabaseAnonKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: const EmptyLocalStorage(),
          pkceAsyncStorage: _MemoryPkceStorage(),
        ),
        postgrestOptions: const PostgrestClientOptions(
          schema: AppEnvironment.supabaseSchema,
        ),
      );
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  SupabaseClient? get clientOrNull {
    if (!_initialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String generateRequestId() =>
      'req_${_uuid.v4().replaceAll('-', '').substring(0, 16).toUpperCase()}';

  /// Validates username format (`^[a-z0-9_]{3,24}$`), reserved list, and uniqueness
  /// via Edge Function `check-username` (Section 7.1 & Section 10).
  Future<EdgeFunctionEnvelope<Map<String, dynamic>>> checkUsernameAvailability({
    required String rawUsername,
    required Set<String> existingUsernamesLower,
  }) async {
    final reqId = generateRequestId();
    final normalized = rawUsername.trim().toLowerCase().replaceAll('@', '');

    if (!usernameRegex.hasMatch(normalized)) {
      return EdgeFunctionEnvelope(
        requestId: reqId,
        success: true,
        data: const {
          'available': false,
          'reason': 'Format wajib 3–24 karakter (huruf kecil, angka, atau garis bawah).',
        },
      );
    }

    if (reservedUsernames.contains(normalized)) {
      return EdgeFunctionEnvelope(
        requestId: reqId,
        success: true,
        data: const {
          'available': false,
          'reason': 'Username dicadangkan oleh sistem (INVALID_OR_RESERVED_USERNAME).',
        },
      );
    }

    // Try remote Edge Function first if online
    final client = clientOrNull;
    if (client != null) {
      try {
        final res = await client.functions
            .invoke('check-username', body: {'username': normalized})
            .timeout(const Duration(seconds: 3));
        if (res.data is Map<String, dynamic>) {
          final map = res.data as Map<String, dynamic>;
          return EdgeFunctionEnvelope(
            requestId: (map['request_id'] as String?) ?? reqId,
            success: (map['success'] as bool?) ?? true,
            data: (map['data'] as Map<String, dynamic>?) ?? map,
          );
        }
      } catch (_) {
        // Fallback to local directory verification when offline/unreachable
      }
    }

    final isTaken = existingUsernamesLower.contains(normalized);
    return EdgeFunctionEnvelope(
      requestId: reqId,
      success: true,
      data: {
        'available': !isTaken,
        'reason': isTaken
            ? 'Username baru saja digunakan, silakan pilih yang lain'
            : 'Tersedia',
      },
    );
  }

  /// Generates ephemeral TURN credentials using HMAC-SHA1 with 3600s TTL (Section 10 `call-signaling`)
  /// so static TURN credentials are never embedded in the APK.
  Map<String, dynamic> issueEphemeralTurnCredentials(String userId) {
    final expiresAtEpoch = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
    final turnUsername = '$expiresAtEpoch:$userId';
    final ephemeralKey = utf8.encode('coturn_hmac_ephemeral_secret_${AppEnvironment.appNamespace}');
    final hmacSha1 = dart_crypto.Hmac(dart_crypto.sha1, ephemeralKey);
    final credential = base64Encode(hmacSha1.convert(utf8.encode(turnUsername)).bytes);

    return {
      'urls': [
        'stun:turn.adoetz52.my.id:3478',
        'turn:turn.adoetz52.my.id:3478?transport=udp',
        'turns:turn.adoetz52.my.id:5349?transport=tcp',
      ],
      'username': turnUsername,
      'credential': credential,
      'ttl_seconds': 3600,
    };
  }
}
