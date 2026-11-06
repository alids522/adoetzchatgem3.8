enum MessageDeliveryStatus {
  queued,
  encrypting,
  sending,
  sent,
  delivered,
  read,
  failed,
}

enum AttachmentKind {
  none,
  image,
  video,
  document,
  voiceNote,
}

enum CallDirection {
  incoming,
  outgoing,
  missed,
}

class LocalConversation {
  final String id;
  final String peerUserId;
  final String peerUsername;
  final String peerDisplayName;
  final String peerBio;
  final String? peerAvatarUrl;
  final String peerIdentityKeyB64;
  final bool peerKeyChangedWarning;
  final bool isVerified;
  final bool isPinned;
  final bool isMuted;
  final bool isBlocked;
  final String lastMessageSnippet;
  final DateTime lastEventAt;
  final int unreadCount;
  final MessageDeliveryStatus? lastOutgoingStatus;
  final String draftText;

  const LocalConversation({
    required this.id,
    required this.peerUserId,
    required this.peerUsername,
    required this.peerDisplayName,
    this.peerBio = '',
    this.peerAvatarUrl,
    required this.peerIdentityKeyB64,
    this.peerKeyChangedWarning = false,
    this.isVerified = false,
    this.isPinned = false,
    this.isMuted = false,
    this.isBlocked = false,
    required this.lastMessageSnippet,
    required this.lastEventAt,
    this.unreadCount = 0,
    this.lastOutgoingStatus,
    this.draftText = '',
  });

  LocalConversation copyWith({
    String? peerUsername,
    String? peerDisplayName,
    String? peerBio,
    String? peerAvatarUrl,
    String? peerIdentityKeyB64,
    bool? peerKeyChangedWarning,
    bool? isVerified,
    bool? isPinned,
    bool? isMuted,
    bool? isBlocked,
    String? lastMessageSnippet,
    DateTime? lastEventAt,
    int? unreadCount,
    MessageDeliveryStatus? lastOutgoingStatus,
    String? draftText,
  }) {
    return LocalConversation(
      id: id,
      peerUserId: peerUserId,
      peerUsername: peerUsername ?? this.peerUsername,
      peerDisplayName: peerDisplayName ?? this.peerDisplayName,
      peerBio: peerBio ?? this.peerBio,
      peerAvatarUrl: peerAvatarUrl ?? this.peerAvatarUrl,
      peerIdentityKeyB64: peerIdentityKeyB64 ?? this.peerIdentityKeyB64,
      peerKeyChangedWarning: peerKeyChangedWarning ?? this.peerKeyChangedWarning,
      isVerified: isVerified ?? this.isVerified,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      isBlocked: isBlocked ?? this.isBlocked,
      lastMessageSnippet: lastMessageSnippet ?? this.lastMessageSnippet,
      lastEventAt: lastEventAt ?? this.lastEventAt,
      unreadCount: unreadCount ?? this.unreadCount,
      lastOutgoingStatus: lastOutgoingStatus ?? this.lastOutgoingStatus,
      draftText: draftText ?? this.draftText,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'peer_user_id': peerUserId,
        'peer_username': peerUsername,
        'peer_display_name': peerDisplayName,
        'peer_bio': peerBio,
        'peer_avatar_url': peerAvatarUrl,
        'peer_identity_key_b64': peerIdentityKeyB64,
        'peer_key_changed_warning': peerKeyChangedWarning ? 1 : 0,
        'is_verified': isVerified ? 1 : 0,
        'is_pinned': isPinned ? 1 : 0,
        'is_muted': isMuted ? 1 : 0,
        'is_blocked': isBlocked ? 1 : 0,
        'last_message_snippet': lastMessageSnippet,
        'last_event_at': lastEventAt.toIso8601String(),
        'unread_count': unreadCount,
        'last_outgoing_status': lastOutgoingStatus?.name,
        'draft_text': draftText,
      };

  factory LocalConversation.fromMap(Map<String, dynamic> map) {
    final statusStr = map['last_outgoing_status'] as String?;
    return LocalConversation(
      id: map['id'] as String,
      peerUserId: map['peer_user_id'] as String,
      peerUsername: map['peer_username'] as String,
      peerDisplayName: map['peer_display_name'] as String,
      peerBio: (map['peer_bio'] as String?) ?? '',
      peerAvatarUrl: map['peer_avatar_url'] as String?,
      peerIdentityKeyB64: map['peer_identity_key_b64'] as String,
      peerKeyChangedWarning: (map['peer_key_changed_warning'] as int? ?? 0) == 1,
      isVerified: (map['is_verified'] as int? ?? 0) == 1,
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      isMuted: (map['is_muted'] as int? ?? 0) == 1,
      isBlocked: (map['is_blocked'] as int? ?? 0) == 1,
      lastMessageSnippet: map['last_message_snippet'] as String,
      lastEventAt: DateTime.parse(map['last_event_at'] as String),
      unreadCount: (map['unread_count'] as num?)?.toInt() ?? 0,
      lastOutgoingStatus: statusStr != null
          ? MessageDeliveryStatus.values.firstWhere(
              (e) => e.name == statusStr,
              orElse: () => MessageDeliveryStatus.sent,
            )
          : null,
      draftText: (map['draft_text'] as String?) ?? '',
    );
  }
}

class LocalMessage {
  final String clientMessageId;
  final String? serverMessageId;
  final String conversationId;
  final String senderId;
  final bool isOutgoing;
  final String plaintext;
  final String ciphertextB64;
  final MessageDeliveryStatus status;
  final DateTime createdAt;
  final String? replyToMessageId;
  final String? replyToSenderName;
  final String? replyToSnippet;
  final bool isEdited;
  final bool isRevokedForAll;
  final Map<String, String> reactions; // userId -> emoji
  final AttachmentKind attachmentKind;
  final String? attachmentName;
  final int? attachmentSizeBytes;
  final int? voiceDurationSeconds;
  final List<double>? voiceWaveform;
  final String? attachmentFileKeyB64;
  final String? attachmentSha256Hex;

  const LocalMessage({
    required this.clientMessageId,
    this.serverMessageId,
    required this.conversationId,
    required this.senderId,
    required this.isOutgoing,
    required this.plaintext,
    required this.ciphertextB64,
    required this.status,
    required this.createdAt,
    this.replyToMessageId,
    this.replyToSenderName,
    this.replyToSnippet,
    this.isEdited = false,
    this.isRevokedForAll = false,
    this.reactions = const {},
    this.attachmentKind = AttachmentKind.none,
    this.attachmentName,
    this.attachmentSizeBytes,
    this.voiceDurationSeconds,
    this.voiceWaveform,
    this.attachmentFileKeyB64,
    this.attachmentSha256Hex,
  });

  LocalMessage copyWith({
    String? serverMessageId,
    String? plaintext,
    String? ciphertextB64,
    MessageDeliveryStatus? status,
    DateTime? createdAt,
    bool? isEdited,
    bool? isRevokedForAll,
    Map<String, String>? reactions,
  }) {
    return LocalMessage(
      clientMessageId: clientMessageId,
      serverMessageId: serverMessageId ?? this.serverMessageId,
      conversationId: conversationId,
      senderId: senderId,
      isOutgoing: isOutgoing,
      plaintext: plaintext ?? this.plaintext,
      ciphertextB64: ciphertextB64 ?? this.ciphertextB64,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      replyToMessageId: replyToMessageId,
      replyToSenderName: replyToSenderName,
      replyToSnippet: replyToSnippet,
      isEdited: isEdited ?? this.isEdited,
      isRevokedForAll: isRevokedForAll ?? this.isRevokedForAll,
      reactions: reactions ?? this.reactions,
      attachmentKind: attachmentKind,
      attachmentName: attachmentName,
      attachmentSizeBytes: attachmentSizeBytes,
      voiceDurationSeconds: voiceDurationSeconds,
      voiceWaveform: voiceWaveform,
      attachmentFileKeyB64: attachmentFileKeyB64,
      attachmentSha256Hex: attachmentSha256Hex,
    );
  }
}

class OutboxEntry {
  final String clientMessageId;
  final String conversationId;
  final String senderId;
  final String ciphertextB64;
  final int retryCount;
  final DateTime nextAttemptAt;
  final DateTime createdAt;

  const OutboxEntry({
    required this.clientMessageId,
    required this.conversationId,
    required this.senderId,
    required this.ciphertextB64,
    this.retryCount = 0,
    required this.nextAttemptAt,
    required this.createdAt,
  });

  OutboxEntry incrementRetry(DateTime now) {
    final nextRetry = retryCount + 1;
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 32s (ERR-01)
    final delaySec = 1 << (nextRetry.clamp(0, 5));
    return OutboxEntry(
      clientMessageId: clientMessageId,
      conversationId: conversationId,
      senderId: senderId,
      ciphertextB64: ciphertextB64,
      retryCount: nextRetry,
      nextAttemptAt: now.add(Duration(seconds: delaySec)),
      createdAt: createdAt,
    );
  }
}

class LocalCallRecord {
  final String id;
  final String peerUserId;
  final String peerUsername;
  final String peerDisplayName;
  final bool isVideo;
  final CallDirection direction;
  final DateTime startedAt;
  final int durationSeconds;

  const LocalCallRecord({
    required this.id,
    required this.peerUserId,
    required this.peerUsername,
    required this.peerDisplayName,
    required this.isVideo,
    required this.direction,
    required this.startedAt,
    required this.durationSeconds,
  });
}

class ContactDirectoryEntry {
  final String userId;
  final String username;
  final String displayName;
  final String bio;
  final String identityPublicKeyB64;
  final bool isVerified;
  final bool isBlocked;
  final String role;
  final String accountStatus;
  final DateTime createdAt;
  final String email;

  const ContactDirectoryEntry({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.bio,
    required this.identityPublicKeyB64,
    this.isVerified = false,
    this.isBlocked = false,
    this.role = 'user',
    this.accountStatus = 'active',
    required this.createdAt,
    this.email = '',
  });

  ContactDirectoryEntry copyWith({
    String? displayName,
    String? bio,
    String? identityPublicKeyB64,
    bool? isVerified,
    bool? isBlocked,
    String? role,
    String? accountStatus,
  }) {
    return ContactDirectoryEntry(
      userId: userId,
      username: username,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      identityPublicKeyB64: identityPublicKeyB64 ?? this.identityPublicKeyB64,
      isVerified: isVerified ?? this.isVerified,
      isBlocked: isBlocked ?? this.isBlocked,
      role: role ?? this.role,
      accountStatus: accountStatus ?? this.accountStatus,
      createdAt: createdAt,
      email: email,
    );
  }
}

class AdminAuditLogEntry {
  final String id;
  final String requestId;
  final DateTime timestamp;
  final String actorUsername;
  final String action;
  final String targetUsername;
  final String reason;

  const AdminAuditLogEntry({
    required this.id,
    required this.requestId,
    required this.timestamp,
    required this.actorUsername,
    required this.action,
    required this.targetUsername,
    required this.reason,
  });
}
