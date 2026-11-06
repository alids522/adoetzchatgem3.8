import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/theme/design_tokens.dart';
import '../../core/database/models.dart';
import '../../core/state/app_controller.dart';
import '../../core/webrtc/webrtc_call_engine.dart';

/// UI-14: Calls History Screen (Section 6.3)
/// - 68dp row height, 44dp Avatar, Contact Name
/// - Direction icon: `↙ Masuk`, `↗ Keluar`, `↙ Tak Terjawab` (`status.danger`)
/// - Time & Duration (`Hari ini, 14:20 • 05:12`)
/// - 1-tap voice/video callback button on the right
class CallsHistoryScreen extends ConsumerWidget {
  const CallsHistoryScreen({super.key});

  String _formatDuration(int sec) {
    final mm = (sec ~/ 60).toString().padLeft(2, '0');
    final ss = (sec % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AdoetzPalette.of(context);
    final appState = ref.watch(appControllerProvider);

    return Scaffold(
      backgroundColor: palette.bgCanvas,
      appBar: AppBar(
        title: const Text('Panggilan E2EE'),
        actions: [
          IconButton(
            tooltip: 'Simulasikan Panggilan Masuk (UI-16)',
            icon: const Icon(Icons.ring_volume_outlined, size: 21),
            onPressed: () {
              final peer = appState.directory.first;
              ref
                  .read(appControllerProvider.notifier)
                  .receiveIncomingCall(peer: peer, isVideo: false);
              context.push('/incoming-call');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Active Call Pill if minimized
          if (appState.activeCall != null &&
              appState.activeCall!.isMinimizedToPill &&
              appState.activeCall!.phase != ActiveCallPhase.ended)
            InkWell(
              onTap: () {
                ref
                    .read(appControllerProvider.notifier)
                    .setCallMinimizedToPill(false);
                context.push('/call/${appState.activeCall!.callId}');
              },
              child: Container(
                width: double.infinity,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: palette.statusSuccess,
                alignment: Alignment.centerLeft,
                child: Text(
                  '📞 Panggilan berlangsung • ${appState.activeCall!.formattedDuration} — Ketuk untuk kembali',
                  style: AdoetzTypography.captionTime(Colors.white, bold: true),
                ),
              ),
            ),

          Expanded(
            child: appState.callHistory.isEmpty
                ? Center(
                    child: Text(
                      'Belum ada riwayat panggilan WebRTC DTLS-SRTP.',
                      style: AdoetzTypography.listSubtitle(palette.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: appState.callHistory.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 0.5,
                      thickness: 0.5,
                      indent: 72,
                      color: palette.borderHairline,
                    ),
                    itemBuilder: (context, index) {
                      final rec = appState.callHistory[index];
                      final isMissed = rec.direction == CallDirection.missed;
                      final dirLabel = switch (rec.direction) {
                        CallDirection.incoming => '↙ Masuk',
                        CallDirection.outgoing => '↗ Keluar',
                        CallDirection.missed => '↙ Tak Terjawab',
                      };
                      final timeStr = DateFormat('dd MMM, HH:mm').format(rec.startedAt);
                      final subtitleStr = isMissed
                          ? '$dirLabel • $timeStr'
                          : '$dirLabel • $timeStr • ${_formatDuration(rec.durationSeconds)}';

                      return Container(
                        height: AdoetzDimensions.callListItemHeight, // 68dp
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        color: palette.bgSurface,
                        child: Row(
                          children: [
                            // 44dp Avatar
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: palette.bgElevated,
                                shape: BoxShape.circle,
                                border: Border.all(color: palette.borderHairline),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                rec.peerDisplayName.isNotEmpty
                                    ? rec.peerDisplayName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: palette.accentInteractive,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rec.peerDisplayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AdoetzTypography.listTitle(
                                      isMissed
                                          ? palette.statusDanger
                                          : palette.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitleStr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AdoetzTypography.captionTime(
                                      isMissed
                                          ? palette.statusDanger
                                          : palette.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 1-Tap Callback Button
                            IconButton(
                              tooltip: rec.isVideo
                                  ? 'Panggil Video Kembali'
                                  : 'Panggil Suara Kembali',
                              icon: Icon(
                                rec.isVideo
                                    ? Icons.videocam_outlined
                                    : Icons.call_outlined,
                                color: palette.accentInteractive,
                                size: 22,
                              ),
                              onPressed: () {
                                final peer = appState.directory.firstWhere(
                                  (c) => c.username == rec.peerUsername,
                                  orElse: () => appState.directory.first,
                                );
                                ref
                                    .read(appControllerProvider.notifier)
                                    .startOutgoingCall(
                                      peer: peer,
                                      isVideo: rec.isVideo,
                                    );
                                context.push('/call/active');
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// UI-16: Incoming Call Screen (Full-Screen Lock / Heads-Up Overlay — Section 6.3)
/// - 96dp Avatar, Name, `@username`, `"Panggilan Suara Masuk..."`
/// - 64dp Red `✕ Tolak` & 64dp Green `📞 Terima`
class IncomingCallScreen extends ConsumerWidget {
  const IncomingCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AdoetzPalette.of(context);
    final appState = ref.watch(appControllerProvider);
    final call = appState.activeCall;

    final peerName = call?.peerDisplayName ?? 'Alex Pratama';
    final peerUsername = call?.peerUsername ?? 'alex';
    final isVideo = call?.isVideo ?? false;

    return Scaffold(
      backgroundColor: palette.bgCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 16, color: palette.statusSuccess),
                  const SizedBox(width: 6),
                  Text(
                    'Enkripsi End-to-End (DTLS-SRTP)',
                    style: AdoetzTypography.captionTime(
                      palette.statusSuccess,
                      bold: true,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // 96dp Avatar per UI-16 ASCII diagram
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: palette.bgElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.accentPrimary, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  peerName.isNotEmpty ? peerName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    color: palette.accentInteractive,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                peerName,
                style: AdoetzTypography.screenTitle(palette.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                '@$peerUsername',
                style: AdoetzTypography.listSubtitle(palette.accentInteractive),
              ),
              const SizedBox(height: 12),
              Text(
                isVideo ? 'Panggilan Video Masuk...' : 'Panggilan Suara Masuk...',
                style: AdoetzTypography.listSubtitle(palette.textSecondary),
              ),
              const Spacer(),
              // 64dp Red Tolak & 64dp Green Terima Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: IconButton(
                          key: const Key('incoming_call_decline_btn'),
                          style: IconButton.styleFrom(
                            backgroundColor: palette.statusDanger,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.close_rounded, size: 30),
                          onPressed: () {
                            ref
                                .read(appControllerProvider.notifier)
                                .endOrDeclineCall(declined: true);
                            context.pop();
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tolak',
                        style: AdoetzTypography.buttonLabel(palette.textSecondary),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: IconButton(
                          key: const Key('incoming_call_accept_btn'),
                          style: IconButton.styleFrom(
                            backgroundColor: palette.statusSuccess,
                            foregroundColor: Colors.white,
                          ),
                          icon: Icon(
                            isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                            size: 28,
                          ),
                          onPressed: () {
                            ref
                                .read(appControllerProvider.notifier)
                                .acceptIncomingOrConnectCall();
                            context.pushReplacement('/call/active');
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Terima',
                        style: AdoetzTypography.buttonLabel(palette.textPrimary),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// UI-15: Outgoing Call & UI-17: Active Voice / Video Call Screen (Section 6.3)
/// - Supports Back navigation into Floating Mini-Call Pill without dropping the call
/// - Supports Network Switch ICE Restart (`restartIce()` — ERR-08)
/// - 5 Bottom Controls: `[🔇 Mute] [🔊 Spkr] [📹 Cam] [🔄 Flip] [📞 End]`
class ActiveCallScreen extends ConsumerWidget {
  final String callId;

  const ActiveCallScreen({
    super.key,
    required this.callId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AdoetzPalette.of(context);
    final appState = ref.watch(appControllerProvider);
    final call = appState.activeCall;

    if (call == null) {
      return Scaffold(
        backgroundColor: palette.bgCanvas,
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/chats'),
            child: const Text('Panggilan Selesai • Kembali'),
          ),
        ),
      );
    }

    final isReconnecting = call.phase == ActiveCallPhase.reconnectingIce;
    final isOutgoingRinging = call.phase == ActiveCallPhase.outgoingRinging;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        // Minimize to Floating Mini-Call Pill when user presses Back!
        ref.read(appControllerProvider.notifier).setCallMinimizedToPill(true);
      },
      child: Scaffold(
        backgroundColor: palette.bgCanvas,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Kecilkan ke Mini-Call Pill',
            icon: const Icon(Icons.chevron_left, size: 28),
            onPressed: () {
              ref
                  .read(appControllerProvider.notifier)
                  .setCallMinimizedToPill(true);
              context.pop();
            },
          ),
          title: Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: palette.statusSuccess),
              const SizedBox(width: 6),
              Text(
                'Enkripsi E2EE',
                style: AdoetzTypography.listSubtitle(palette.textPrimary),
              ),
            ],
          ),
          actions: [
            // Network Stability / ICE Restart Chip (ERR-08)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                ref.read(appControllerProvider.notifier).triggerCallIceRestart();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 14),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isReconnecting
                      ? palette.statusWarning.withValues(alpha: 0.2)
                      : palette.statusSuccess.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isReconnecting
                        ? palette.statusWarning
                        : palette.statusSuccess,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isReconnecting
                          ? Icons.sync_problem_rounded
                          : Icons.signal_cellular_alt_rounded,
                      size: 14,
                      color: isReconnecting
                          ? palette.statusWarning
                          : palette.statusSuccess,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isReconnecting ? 'Menghubungkan kembali...' : 'Stabil (TURN)',
                      style: AdoetzTypography.captionTime(
                        isReconnecting
                            ? palette.statusWarning
                            : palette.statusSuccess,
                        bold: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Remote Peer Video or Voice Call Avatar Area + Local PiP
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: palette.bgSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.borderHairline),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  color: palette.bgElevated,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: palette.accentPrimary,
                                    width: 2,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  call.peerDisplayName.isNotEmpty
                                      ? call.peerDisplayName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w600,
                                    color: palette.accentInteractive,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                call.peerDisplayName,
                                style: AdoetzTypography.screenTitle(
                                  palette.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '@${call.peerUsername}',
                                style: AdoetzTypography.listSubtitle(
                                  palette.accentInteractive,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                call.isVideo && call.isCameraOn
                                    ? 'VIDEO REMOTE PEER (DTLS-SRTP 1080p)'
                                    : 'PANGGILAN SUARA E2EE',
                                style: AdoetzTypography.captionTime(
                                  palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Local PiP Box in bottom-right corner
                        if (call.isVideo)
                          Positioned(
                            right: 14,
                            bottom: 14,
                            child: Container(
                              width: 92,
                              height: 128,
                              decoration: BoxDecoration(
                                color: palette.bgElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: palette.accentPrimary,
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    call.isCameraOn
                                        ? Icons.person_outline_rounded
                                        : Icons.videocam_off_outlined,
                                    color: palette.textSecondary,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    call.isFrontCamera ? 'Local PiP' : 'Rear Cam',
                                    style: AdoetzTypography.captionTime(
                                      palette.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Call Duration or Ringing Status
                Text(
                  isOutgoingRinging
                      ? 'Memanggil @${call.peerUsername} (Ringing)...'
                      : '${call.formattedDuration} (Durasi)',
                  style: AdoetzTypography.listTitle(
                    palette.textPrimary,
                    unread: true,
                  ),
                ),
                const SizedBox(height: 16),
                // Bottom Control Bar: [🔇 Mute] [🔊 Spkr] [📹 Cam] [🔄 Flip] [📞 End]
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: palette.bgSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.borderHairline),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _CallControlButton(
                        icon: call.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        label: 'Mute',
                        active: call.isMuted,
                        onTap: () => ref
                            .read(appControllerProvider.notifier)
                            .toggleCallMute(),
                      ),
                      _CallControlButton(
                        icon: call.isSpeakerOn
                            ? Icons.volume_up_rounded
                            : Icons.volume_down_rounded,
                        label: 'Spkr',
                        active: call.isSpeakerOn,
                        onTap: () => ref
                            .read(appControllerProvider.notifier)
                            .toggleCallSpeaker(),
                      ),
                      _CallControlButton(
                        icon: call.isCameraOn
                            ? Icons.videocam_rounded
                            : Icons.videocam_off_rounded,
                        label: 'Cam',
                        active: call.isCameraOn,
                        onTap: () => ref
                            .read(appControllerProvider.notifier)
                            .toggleCallCamera(),
                      ),
                      _CallControlButton(
                        icon: Icons.cameraswitch_outlined,
                        label: 'Flip',
                        active: !call.isFrontCamera,
                        onTap: () => ref
                            .read(appControllerProvider.notifier)
                            .flipCallCamera(),
                      ),
                      _CallControlButton(
                        icon: Icons.call_end_rounded,
                        label: 'End',
                        isDanger: true,
                        onTap: () {
                          ref
                              .read(appControllerProvider.notifier)
                              .endOrDeclineCall();
                          context.pop();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool isDanger;
  final VoidCallback onTap;

  const _CallControlButton({
    required this.icon,
    required this.label,
    this.active = false,
    this.isDanger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AdoetzPalette.of(context);
    final bg = isDanger
        ? palette.statusDanger
        : (active ? palette.accentPrimary : palette.bgElevated);
    final fg = (isDanger || active) ? Colors.white : palette.textPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
            ),
            icon: Icon(icon, size: 22),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AdoetzTypography.captionTime(palette.textSecondary),
        ),
      ],
    );
  }
}
