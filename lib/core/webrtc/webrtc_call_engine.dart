enum ActiveCallPhase {
  idle,
  outgoingRinging,
  incomingRinging,
  connected,
  reconnectingIce,
  ended,
  declined,
  missed,
}

class ActiveCallSession {
  final String callId;
  final String peerUserId;
  final String peerUsername;
  final String peerDisplayName;
  final bool isVideo;
  final ActiveCallPhase phase;
  final bool isMuted;
  final bool isSpeakerOn;
  final bool isCameraOn;
  final bool isFrontCamera;
  final bool isMinimizedToPill;
  final int elapsedSeconds;
  final int expiresAtMs;
  final Map<String, dynamic> turnConfig;

  const ActiveCallSession({
    required this.callId,
    required this.peerUserId,
    required this.peerUsername,
    required this.peerDisplayName,
    required this.isVideo,
    required this.phase,
    this.isMuted = false,
    this.isSpeakerOn = false,
    this.isCameraOn = true,
    this.isFrontCamera = true,
    this.isMinimizedToPill = false,
    this.elapsedSeconds = 0,
    required this.expiresAtMs,
    required this.turnConfig,
  });

  String get formattedDuration {
    final mm = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  /// ERR-06: Checks if incoming call payload has exceeded its 40-second TTL.
  bool isExpiredAt(int currentEpochMs) => currentEpochMs > expiresAtMs;

  ActiveCallSession copyWith({
    ActiveCallPhase? phase,
    bool? isMuted,
    bool? isSpeakerOn,
    bool? isCameraOn,
    bool? isFrontCamera,
    bool? isMinimizedToPill,
    int? elapsedSeconds,
    Map<String, dynamic>? turnConfig,
  }) {
    return ActiveCallSession(
      callId: callId,
      peerUserId: peerUserId,
      peerUsername: peerUsername,
      peerDisplayName: peerDisplayName,
      isVideo: isVideo,
      phase: phase ?? this.phase,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isCameraOn: isCameraOn ?? this.isCameraOn,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      isMinimizedToPill: isMinimizedToPill ?? this.isMinimizedToPill,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      expiresAtMs: expiresAtMs,
      turnConfig: turnConfig ?? this.turnConfig,
    );
  }
}
