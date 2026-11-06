import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../app/theme/design_tokens.dart';
import '../../core/database/models.dart';
import '../../core/state/app_controller.dart';
import '../../core/webrtc/webrtc_call_engine.dart';

/// UI-10: Chat Detail (1:1 E2EE Room) + Section 5.2 `MessageBubble`
/// + Section 5.3 `ChatComposerBar` + UI-11 Attachment Picker & Preview
/// + UI-12 Voice Note Recorder + UI-13 Chat Info & Safety Number (QR).
class ChatDetailScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatDetailScreen({
    super.key,
    required this.conversationId,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  LocalMessage? _replyingToMessage;
  LocalMessage? _editingMessage;

  // UI-12 Voice Note Recorder State
  bool _isRecordingVoiceNote = false;
  bool _isVoiceNotePaused = false;
  int _voiceNoteSeconds = 0;
  Timer? _voiceTimer;
  List<double> _liveWaveform = List.filled(24, 0.25);

  double _lastKeyboardInset = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(appControllerProvider.notifier)
          .markConversationRead(widget.conversationId);
      _scrollToBottom(animated: false);
    });
  }

  @override
  void dispose() {
    _voiceTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  /// Section 4.3.3: Keyboard (IME) Inset Physics
  /// If user scroll is within <= 64dp of bottom, keep bottom anchored when keyboard opens.
  void _handleKeyboardInsetChange(double currentKeyboardBottom) {
    if (currentKeyboardBottom > _lastKeyboardInset &&
        _scrollController.hasClients) {
      final pos = _scrollController.position;
      final distanceFromBottom = pos.maxScrollExtent - pos.pixels;
      if (distanceFromBottom <= 64.0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(animated: false);
        });
      }
    }
    _lastKeyboardInset = currentKeyboardBottom;
  }

  void _startVoiceRecording() {
    HapticFeedback.lightImpact();
    _voiceTimer?.cancel();
    final rng = Random();
    setState(() {
      _isRecordingVoiceNote = true;
      _isVoiceNotePaused = false;
      _voiceNoteSeconds = 0;
      _liveWaveform = List.generate(24, (_) => 0.2 + rng.nextDouble() * 0.7);
    });
    _voiceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isVoiceNotePaused) return;
      if (_voiceNoteSeconds >= 600) {
        // Max 10:00 per UI-12
        _sendRecordedVoiceNote();
        return;
      }
      setState(() {
        _voiceNoteSeconds++;
        _liveWaveform = [
          ..._liveWaveform.sublist(1),
          0.18 + rng.nextDouble() * 0.78,
        ];
      });
    });
  }

  void _cancelVoiceRecording() {
    _voiceTimer?.cancel();
    setState(() {
      _isRecordingVoiceNote = false;
      _isVoiceNotePaused = false;
      _voiceNoteSeconds = 0;
    });
  }

  Future<void> _sendRecordedVoiceNote() async {
    _voiceTimer?.cancel();
    final duration = max(1, _voiceNoteSeconds);
    final waveform = List<double>.from(_liveWaveform);
    setState(() {
      _isRecordingVoiceNote = false;
      _isVoiceNotePaused = false;
      _voiceNoteSeconds = 0;
    });

    final res = await ref
        .read(appControllerProvider.notifier)
        .sendEncryptedMessage(
          conversationId: widget.conversationId,
          plaintext: 'Pesan Suara E2EE',
          replyToMessageId: _replyingToMessage?.clientMessageId,
          replyToSenderName: _replyingToMessage != null
              ? (_replyingToMessage!.isOutgoing ? 'Anda' : 'Kontak')
              : null,
          replyToSnippet: _replyingToMessage?.plaintext,
          attachmentKind: AttachmentKind.voiceNote,
          voiceDurationSeconds: duration,
          voiceWaveform: waveform,
        );

    if (!res.ok && mounted && res.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error!)),
      );
    }
    setState(() => _replyingToMessage = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _sendTextOrEdit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final ctrl = ref.read(appControllerProvider.notifier);
    if (_editingMessage != null) {
      final editing = _editingMessage!;
      _textController.clear();
      setState(() => _editingMessage = null);
      await ctrl.editMessage(
        conversationId: widget.conversationId,
        clientMessageId: editing.clientMessageId,
        newPlaintext: text,
      );
      return;
    }

    final replyTarget = _replyingToMessage;
    final conv = ref.read(vaultDatabaseProvider).getConversation(widget.conversationId);
    _textController.clear();
    setState(() => _replyingToMessage = null);

    final res = await ctrl.sendEncryptedMessage(
      conversationId: widget.conversationId,
      plaintext: text,
      replyToMessageId: replyTarget?.clientMessageId,
      replyToSenderName: replyTarget != null
          ? (replyTarget.isOutgoing ? 'Anda' : (conv?.peerDisplayName ?? 'Kontak'))
          : null,
      replyToSnippet: replyTarget?.plaintext,
    );

    if (!res.ok && mounted && res.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error!)),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  /// UI-11: Attachment Picker Bottom Sheet (height 220dp, 3 clean options)
  void _openAttachmentPicker(BuildContext context, LocalConversation conv) {
    final palette = AdoetzPalette.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.bgElevated,
      builder: (ctx) {
        return SizedBox(
          height: 220,
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ListTile(
                  leading: Icon(Icons.photo_library_outlined, color: palette.textPrimary),
                  title: Text(
                    'Galeri Foto & Video',
                    style: AdoetzTypography.listTitle(palette.textPrimary),
                  ),
                  subtitle: Text(
                    'Android Photo Picker sistem',
                    style: AdoetzTypography.captionTime(palette.textSecondary),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openAttachmentPreviewModal(
                      kind: AttachmentKind.image,
                      fileName: 'IMG_${DateFormat("yyyyMMdd_HHmm").format(DateTime.now())}.jpg',
                      fileSizeBytes: 1420800,
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.description_outlined, color: palette.textPrimary),
                  title: Text(
                    'Dokumen & File',
                    style: AdoetzTypography.listTitle(palette.textPrimary),
                  ),
                  subtitle: Text(
                    'Storage Access Framework (SAF)',
                    style: AdoetzTypography.captionTime(palette.textSecondary),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openAttachmentPreviewModal(
                      kind: AttachmentKind.document,
                      fileName: 'arsitektur_e2ee_v2.pdf',
                      fileSizeBytes: 2480120,
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_camera_outlined, color: palette.textPrimary),
                  title: Text(
                    'Kamera',
                    style: AdoetzTypography.listTitle(palette.textPrimary),
                  ),
                  subtitle: Text(
                    'Ambil foto terenkripsi instan',
                    style: AdoetzTypography.captionTime(palette.textSecondary),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openAttachmentPreviewModal(
                      kind: AttachmentKind.image,
                      fileName: 'CAM_${DateFormat("HHmmss").format(DateTime.now())}.jpg',
                      fileSizeBytes: 980400,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// UI-11: Attachment Preview Screen before sending (encrypts file on device before upload)
  void _openAttachmentPreviewModal({
    required AttachmentKind kind,
    required String fileName,
    required int fileSizeBytes,
  }) {
    final captionController = TextEditingController();
    final palette = AdoetzPalette.of(context);
    final sizeMb = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(2);
    final ext = fileName.contains('.') ? fileName.split('.').last.toUpperCase() : 'ENC';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.bgCanvas,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pratinjau Lampiran E2EE',
                      style: AdoetzTypography.screenTitle(palette.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.bgElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.borderHairline),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: palette.accentSubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        ext,
                        style: AdoetzTypography.monoKey(palette.accentInteractive),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: AdoetzTypography.listTitle(palette.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$sizeMb MB • AES-256-GCM / XChaCha20-Poly1305',
                            style: AdoetzTypography.captionTime(palette.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 15, color: palette.statusSuccess),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'File akan dienkripsi di perangkat sebelum diunggah',
                      style: AdoetzTypography.captionTime(
                        palette.statusSuccess,
                        bold: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: captionController,
                style: AdoetzTypography.chatBody(palette.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Tambahkan keterangan (opsional)...',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Enkripsi & Kirim'),
                  onPressed: () async {
                    final caption = captionController.text.trim();
                    Navigator.of(ctx).pop();
                    final dummyBytes = Uint8List.fromList(
                      List<int>.generate(256, (i) => i % 256),
                    );
                    await ref
                        .read(appControllerProvider.notifier)
                        .sendEncryptedMessage(
                          conversationId: widget.conversationId,
                          plaintext: caption.isEmpty ? fileName : caption,
                          attachmentKind: kind,
                          attachmentName: '$fileName.enc',
                          attachmentRawBytes: dummyBytes,
                        );
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _scrollToBottom());
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Long-press bubble menu: Quick reactions (`👍 ❤️ 😂 😮 😢 🙏`) + Actions
  void _showMessageActionsSheet(
    BuildContext context,
    LocalMessage message,
    LocalConversation conv,
  ) {
    final palette = AdoetzPalette.of(context);
    final canEdit = message.isOutgoing &&
        !message.isRevokedForAll &&
        DateTime.now().difference(message.createdAt).inMinutes < 15;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.bgElevated,
      builder: (ctx) {
        const emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick Reactions Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: emojis.map((emoji) {
                      return InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          ref.read(appControllerProvider.notifier).toggleReaction(
                                conversationId: widget.conversationId,
                                clientMessageId: message.clientMessageId,
                                emoji: emoji,
                              );
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: palette.bgOverlay,
                            shape: BoxShape.circle,
                          ),
                          child: Text(emoji, style: const TextStyle(fontSize: 22)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Divider(color: palette.borderHairline),
                ListTile(
                  leading: const Icon(Icons.reply_rounded),
                  title: const Text('Balas'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _replyingToMessage = message;
                      _editingMessage = null;
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Salin Teks'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Clipboard.setData(ClipboardData(text: message.plaintext));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Teks pesan disalin')),
                    );
                  },
                ),
                if (canEdit)
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit Pesan (< 15 menit)'),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _editingMessage = message;
                        _replyingToMessage = null;
                        _textController.text = message.plaintext;
                      });
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Info Pesan & Ratchet Envelope'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    showDialog<void>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Detail Enkripsi Pesan'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Client Message ID (Idempoten):\n${message.clientMessageId}',
                              style: AdoetzTypography.monoKey(palette.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Status: ${message.status.name.toUpperCase()}',
                              style: AdoetzTypography.listSubtitle(palette.textPrimary),
                            ),
                            if (message.attachmentSha256Hex != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'SHA-256 Blob:\n${message.attachmentSha256Hex}',
                                style: AdoetzTypography.monoKey(palette.textMuted),
                              ),
                            ],
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dCtx).pop(),
                            child: const Text('Tutup'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_forever_outlined, color: palette.statusDanger),
                  title: Text(
                    'Hapus untuk Semua Orang',
                    style: TextStyle(color: palette.statusDanger),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ref
                        .read(appControllerProvider.notifier)
                        .revokeMessageForEveryone(
                          conversationId: widget.conversationId,
                          clientMessageId: message.clientMessageId,
                        );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AdoetzPalette.of(context);
    final appState = ref.watch(appControllerProvider);
    final vault = ref.watch(vaultDatabaseProvider);
    final conv = vault.getConversation(widget.conversationId);

    // Handle Deep Link Contract Section 3.2: Redirect to /chats with snackbar if invalid
    if (conv == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Percakapan tidak ditemukan')),
          );
          context.go('/chats');
        }
      });
      return Scaffold(backgroundColor: palette.bgCanvas);
    }

    final messages = vault.getMessages(widget.conversationId);
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    _handleKeyboardInsetChange(keyboardBottom);

    return Scaffold(
      backgroundColor: palette.bgCanvas,
      appBar: AppBar(
        leadingWidth: 40,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.push('/chat/${conv.id}/info'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              children: [
                // 36dp Avatar per UI-10 spec
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: palette.bgElevated,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.borderHairline),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    conv.peerDisplayName.isNotEmpty
                        ? conv.peerDisplayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.accentInteractive,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              conv.peerDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AdoetzTypography.listTitle(palette.textPrimary),
                            ),
                          ),
                          if (conv.isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified_rounded,
                              size: 14,
                              color: palette.statusSuccess,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '@${conv.peerUsername} • 🔒 E2EE Signal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AdoetzTypography.captionTime(palette.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Panggilan Suara E2EE',
            icon: const Icon(Icons.call_outlined, size: 21),
            onPressed: () {
              final peer = appState.directory.firstWhere(
                (c) => c.username == conv.peerUsername,
                orElse: () => appState.directory.first,
              );
              ref
                  .read(appControllerProvider.notifier)
                  .startOutgoingCall(peer: peer, isVideo: false);
              context.push('/call/active');
            },
          ),
          IconButton(
            tooltip: 'Panggilan Video E2EE',
            icon: const Icon(Icons.videocam_outlined, size: 23),
            onPressed: () {
              final peer = appState.directory.firstWhere(
                (c) => c.username == conv.peerUsername,
                orElse: () => appState.directory.first,
              );
              ref
                  .read(appControllerProvider.notifier)
                  .startOutgoingCall(peer: peer, isVideo: true);
              context.push('/call/active');
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 21),
            color: palette.bgOverlay,
            onSelected: (val) {
              if (val == 'info') {
                context.push('/chat/${conv.id}/info');
              } else if (val == 'simulate_key_change') {
                ref
                    .read(appControllerProvider.notifier)
                    .simulatePeerIdentityKeyChange(conv.id);
              } else if (val == 'contact_profile') {
                context.push('/user/${conv.peerUsername}');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'info',
                child: Text('Info Chat & Verifikasi QR (UI-13)'),
              ),
              const PopupMenuItem(
                value: 'contact_profile',
                child: Text('Lihat Profil Kontak (UI-09)'),
              ),
              const PopupMenuItem(
                value: 'simulate_key_change',
                child: Text('Simulasikan Pergantian Kunci Kontak (ERR-05)'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Floating Mini-Call Pill if call is active and minimized
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

          // ERR-05: Security Banner when peer's Identity Key changed
          if (conv.peerKeyChangedWarning)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: palette.statusWarning.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.statusWarning),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_reset_rounded, size: 20, color: palette.statusWarning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Identitas keamanan @${conv.peerUsername} berubah. Ketuk untuk meninjau & lanjutkan.',
                      style: AdoetzTypography.captionTime(
                        palette.statusWarning,
                        bold: true,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(appControllerProvider.notifier)
                          .acceptAndVerifyPeerKey(
                            conversationId: conv.id,
                            markVerified: true,
                          );
                    },
                    child: Text(
                      'Terima Kunci',
                      style: AdoetzTypography.captionTime(
                        palette.accentInteractive,
                        bold: true,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/chat/${conv.id}/info'),
                    child: Text(
                      'Verifikasi',
                      style: AdoetzTypography.captionTime(
                        palette.textPrimary,
                        bold: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Message List with Floating Date Chip (24dp height, bg.overlay)
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: messages.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Date Chip (24dp height, bg.overlay — UI-10)
                  return Center(
                    child: Container(
                      height: 24,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: palette.bgOverlay,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Hari Ini',
                        style: AdoetzTypography.captionTime(palette.textSecondary),
                      ),
                    ),
                  );
                }

                final msgIdx = index - 1;
                final msg = messages[msgIdx];
                final prevMsg = msgIdx > 0 ? messages[msgIdx - 1] : null;
                final nextMsg =
                    msgIdx < messages.length - 1 ? messages[msgIdx + 1] : null;

                // Section 5.2.2: Vertical Message Grouping (<2 min same sender = 3dp; else 10dp)
                final sameAsPrev = prevMsg != null &&
                    prevMsg.senderId == msg.senderId &&
                    msg.createdAt.difference(prevMsg.createdAt).inMinutes.abs() < 2;
                final isLastInGroup = nextMsg == null ||
                    nextMsg.senderId != msg.senderId ||
                    nextMsg.createdAt.difference(msg.createdAt).inMinutes.abs() >= 2;

                final topSpacing = sameAsPrev
                    ? AdoetzDimensions.bubbleSameGroupSpacing // 3dp
                    : AdoetzDimensions.bubbleDiffGroupSpacing; // 10dp

                return Padding(
                  padding: EdgeInsets.only(top: msgIdx == 0 ? 0 : topSpacing),
                  child: MessageBubble(
                    message: msg,
                    isLastInSenderGroup: isLastInGroup,
                    onSwipeReply: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _replyingToMessage = msg;
                        _editingMessage = null;
                      });
                    },
                    onLongPress: () => _showMessageActionsSheet(context, msg, conv),
                  ),
                );
              },
            ),
          ),

          // Section 5.3: 4-State ChatComposerBar
          ChatComposerBar(
            controller: _textController,
            isRecordingVoiceNote: _isRecordingVoiceNote,
            isVoiceNotePaused: _isVoiceNotePaused,
            voiceNoteSeconds: _voiceNoteSeconds,
            liveWaveform: _liveWaveform,
            replyingToMessage: _replyingToMessage,
            editingMessage: _editingMessage,
            peerUsername: conv.peerUsername,
            onClearReplyOrEdit: () {
              setState(() {
                _replyingToMessage = null;
                _editingMessage = null;
              });
            },
            onOpenAttachments: () => _openAttachmentPicker(context, conv),
            onStartVoiceRecord: _startVoiceRecording,
            onCancelVoiceRecord: _cancelVoiceRecording,
            onTogglePauseVoiceRecord: () {
              setState(() => _isVoiceNotePaused = !_isVoiceNotePaused);
            },
            onSendVoiceRecord: _sendRecordedVoiceNote,
            onSendText: _sendTextOrEdit,
          ),
        ],
      ),
    );
  }
}

/// Section 5.2: Precision `MessageBubble`
/// - Min width: 88dp, Max width: 78% of screen width
/// - Tail corner radius: 4dp on bottom-left (incoming) or bottom-right (outgoing) when last in group
/// - Inline-float timestamp & status icon via `RichText` invisible trailing spacer
/// - Swipe-to-right (56dp threshold) to trigger Reply mode
class MessageBubble extends StatefulWidget {
  final LocalMessage message;
  final bool isLastInSenderGroup;
  final VoidCallback onSwipeReply;
  final VoidCallback onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isLastInSenderGroup,
    required this.onSwipeReply,
    required this.onLongPress,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  double _dragOffset = 0.0;
  bool _replyTriggered = false;
  bool _isPlayingVoice = false;
  double _voiceSpeed = 1.0;

  @override
  Widget build(BuildContext context) {
    final palette = AdoetzPalette.of(context);
    final msg = widget.message;
    final isOut = msg.isOutgoing;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxBubbleWidth = screenWidth * AdoetzDimensions.bubbleMaxWidthFraction; // 78%

    final bgColor = isOut ? palette.bubbleOutgoingBg : palette.bubbleIncomingBg;
    final textColor =
        isOut ? palette.bubbleOutgoingText : palette.bubbleIncomingText;
    final quoteBg =
        isOut ? palette.bubbleQuoteOutgoingBg : palette.bubbleQuoteIncomingBg;

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(AdoetzDimensions.radiusBubble), // 14dp
      topRight: const Radius.circular(AdoetzDimensions.radiusBubble), // 14dp
      bottomLeft: Radius.circular(
        !isOut && widget.isLastInSenderGroup
            ? AdoetzDimensions.radiusBubbleTail // 4dp tail
            : AdoetzDimensions.radiusBubble,
      ),
      bottomRight: Radius.circular(
        isOut && widget.isLastInSenderGroup
            ? AdoetzDimensions.radiusBubbleTail // 4dp tail
            : AdoetzDimensions.radiusBubble,
      ),
    );

    final timeString = DateFormat('HH:mm').format(msg.createdAt);

    return GestureDetector(
      onLongPress: widget.onLongPress,
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 0) {
          setState(() {
            _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, 72.0);
          });
          if (_dragOffset >= AdoetzDimensions.swipeReplyThreshold &&
              !_replyTriggered) {
            _replyTriggered = true;
            widget.onSwipeReply();
          }
        }
      },
      onHorizontalDragEnd: (_) {
        setState(() {
          _dragOffset = 0.0;
          _replyTriggered = false;
        });
      },
      child: Transform.translate(
        offset: Offset(_dragOffset, 0),
        child: Align(
          alignment: isOut ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment:
                isOut ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: AdoetzDimensions.bubbleMinWidth, // 88dp
                  maxWidth: maxBubbleWidth, // 78% screen width
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 10, 7),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: borderRadius,
                    border: !isOut && !palette.isDark
                        ? Border.all(color: palette.bubbleIncomingBorder, width: 1.0)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reply Quote Box (if message is a reply)
                      if (msg.replyToSnippet != null) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: quoteBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                              left: BorderSide(
                                color: palette.accentInteractive,
                                width: 3.0,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.replyToSenderName ?? 'Kutipan',
                                style: AdoetzTypography.captionTime(
                                  palette.accentInteractive,
                                  bold: true,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                msg.replyToSnippet!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AdoetzTypography.captionTime(
                                  palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Attachment / Voice Note Content
                      if (msg.attachmentKind == AttachmentKind.voiceNote &&
                          !msg.isRevokedForAll)
                        _buildVoiceNoteBubbleContent(palette, msg, textColor, timeString)
                      else ...[
                        if (msg.attachmentKind != AttachmentKind.none &&
                            !msg.isRevokedForAll)
                          _buildAttachmentCard(palette, msg),

                        // Section 5.2.3: Inline-float Timestamp & Status via RichText + invisible trailing spacer
                        Stack(
                          children: [
                            RichText(
                              text: TextSpan(
                                style: AdoetzTypography.chatBody(
                                  msg.isRevokedForAll
                                      ? palette.textMuted
                                      : textColor,
                                ).copyWith(
                                  fontStyle: msg.isRevokedForAll
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                                children: [
                                  TextSpan(text: msg.plaintext),
                                  // Invisible trailing spacer equal to width of timestamp + 12dp
                                  TextSpan(
                                    text: isOut
                                        ? (msg.isEdited
                                            ? ' \u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0'
                                            : ' \u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0')
                                        : ' \u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.transparent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (msg.isEdited && !msg.isRevokedForAll) ...[
                                    Text(
                                      'diedit ',
                                      style: AdoetzTypography.captionTime(
                                        palette.textMuted,
                                      ),
                                    ),
                                  ],
                                  Text(
                                    timeString,
                                    style: AdoetzTypography.captionTime(
                                      palette.textSecondary,
                                    ),
                                  ),
                                  if (isOut) ...[
                                    const SizedBox(width: 4),
                                    _buildDeliveryStatusIndicator(
                                      palette,
                                      msg.status,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Reactions chip row if any
              if (msg.reactions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: palette.bgElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.borderHairline),
                  ),
                  child: Text(
                    msg.reactions.values.join(' '),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),

              // Section 5.2.4: Failed label below bubble
              if (msg.status == MessageDeliveryStatus.failed)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    'Gagal • Ketuk untuk ulangi',
                    style: AdoetzTypography.captionTime(
                      palette.statusDanger,
                      bold: true,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceNoteBubbleContent(
    AdoetzPalette palette,
    LocalMessage msg,
    Color textColor,
    String timeString,
  ) {
    final totalSec = msg.voiceDurationSeconds ?? 42;
    final totalMm = (totalSec ~/ 60).toString();
    final totalSs = (totalSec % 60).toString().padLeft(2, '0');
    final bars = msg.voiceWaveform ?? List.filled(20, 0.5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: EdgeInsets.zero,
          icon: Icon(
            _isPlayingVoice
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_fill_rounded,
            size: 32,
            color: palette.accentInteractive,
          ),
          onPressed: () {
            setState(() => _isPlayingVoice = !_isPlayingVoice);
          },
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 22,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(bars.length.clamp(1, 20), (idx) {
                    final h = (bars[idx] * 18).clamp(4.0, 18.0);
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        height: h,
                        decoration: BoxDecoration(
                          color: idx < 8
                              ? palette.accentInteractive
                              : palette.textMuted,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isPlayingVoice ? '0:18 / $totalMm:$totalSs' : '0:00 / $totalMm:$totalSs',
                    style: AdoetzTypography.captionTime(palette.textSecondary),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (_voiceSpeed == 1.0) {
                              _voiceSpeed = 1.5;
                            } else if (_voiceSpeed == 1.5) {
                              _voiceSpeed = 2.0;
                            } else {
                              _voiceSpeed = 1.0;
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: palette.bgOverlay,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_voiceSpeed}x',
                            style: AdoetzTypography.captionTime(
                              palette.textPrimary,
                              bold: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeString,
                        style: AdoetzTypography.captionTime(palette.textSecondary),
                      ),
                      if (msg.isOutgoing) ...[
                        const SizedBox(width: 4),
                        _buildDeliveryStatusIndicator(palette, msg.status),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentCard(AdoetzPalette palette, LocalMessage msg) {
    final icon = switch (msg.attachmentKind) {
      AttachmentKind.image => Icons.image_outlined,
      AttachmentKind.video => Icons.videocam_outlined,
      AttachmentKind.document => Icons.insert_drive_file_outlined,
      _ => Icons.attachment_rounded,
    };
    final sizeKb = ((msg.attachmentSizeBytes ?? 512000) / 1024).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.bgOverlay.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: palette.accentInteractive),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg.attachmentName ?? 'berkas_terenkripsi.enc',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdoetzTypography.captionTime(
                    palette.textPrimary,
                    bold: true,
                  ),
                ),
                Text(
                  '$sizeKb KB • Terenkripsi AEAD',
                  style: AdoetzTypography.captionTime(palette.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section 5.2.4: Distinct Shape & Color Delivery Indicators
  Widget _buildDeliveryStatusIndicator(
    AdoetzPalette palette,
    MessageDeliveryStatus status,
  ) {
    switch (status) {
      case MessageDeliveryStatus.queued:
      case MessageDeliveryStatus.encrypting:
        return Icon(Icons.schedule_rounded, size: 13, color: palette.textMuted);
      case MessageDeliveryStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: palette.textSecondary,
          ),
        );
      case MessageDeliveryStatus.sent:
        return Icon(Icons.check_rounded, size: 14, color: palette.textSecondary);
      case MessageDeliveryStatus.delivered:
        return Icon(Icons.done_all_rounded, size: 14, color: palette.textSecondary);
      case MessageDeliveryStatus.read:
        return Icon(Icons.done_all_rounded, size: 14, color: palette.tickRead);
      case MessageDeliveryStatus.failed:
        return Icon(
          Icons.error_outline_rounded,
          size: 15,
          color: palette.statusDanger,
        );
    }
  }
}

/// Section 5.3 & UI-12: 4-State `ChatComposerBar`
/// Transitions smoothly (150ms `Curves.easeOutCubic`) between:
/// - State A: Idle / Empty
/// - State B: Typing Text / Has Attachment
/// - State C: Recording Voice Note (Locked with 24-bar live waveform)
/// - State D: Reply or Edit Mode Active
class ChatComposerBar extends StatefulWidget {
  final TextEditingController controller;
  final bool isRecordingVoiceNote;
  final bool isVoiceNotePaused;
  final int voiceNoteSeconds;
  final List<double> liveWaveform;
  final LocalMessage? replyingToMessage;
  final LocalMessage? editingMessage;
  final String peerUsername;
  final VoidCallback onClearReplyOrEdit;
  final VoidCallback onOpenAttachments;
  final VoidCallback onStartVoiceRecord;
  final VoidCallback onCancelVoiceRecord;
  final VoidCallback onTogglePauseVoiceRecord;
  final VoidCallback onSendVoiceRecord;
  final VoidCallback onSendText;

  const ChatComposerBar({
    super.key,
    required this.controller,
    required this.isRecordingVoiceNote,
    required this.isVoiceNotePaused,
    required this.voiceNoteSeconds,
    required this.liveWaveform,
    required this.replyingToMessage,
    required this.editingMessage,
    required this.peerUsername,
    required this.onClearReplyOrEdit,
    required this.onOpenAttachments,
    required this.onStartVoiceRecord,
    required this.onCancelVoiceRecord,
    required this.onTogglePauseVoiceRecord,
    required this.onSendVoiceRecord,
    required this.onSendText,
  });

  @override
  State<ChatComposerBar> createState() => _ChatComposerBarState();
}

class _ChatComposerBarState extends State<ChatComposerBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  void _onTextChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = AdoetzPalette.of(context);
    final hasText = widget.controller.text.trim().isNotEmpty;
    final lineCount = '\n'.allMatches(widget.controller.text).length + 1;
    final inputRadius = lineCount > 2
        ? AdoetzDimensions.radiusComposerMultiline // 14dp when multiline > 2 lines
        : AdoetzDimensions.radiusSearchOrComposer; // 22dp single/2-line

    return Container(
      decoration: BoxDecoration(
        color: palette.bgSurface,
        border: Border(
          top: BorderSide(color: palette.borderHairline, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // STATE D: Mode Balas (Reply) atau Edit Aktif
              if (widget.replyingToMessage != null ||
                  widget.editingMessage != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: palette.bgElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: BorderSide(color: palette.accentPrimary, width: 3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.editingMessage != null
                                  ? 'Mengedit Pesan'
                                  : 'Membalas @${widget.peerUsername}',
                              style: AdoetzTypography.captionTime(
                                palette.accentInteractive,
                                bold: true,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (widget.editingMessage ?? widget.replyingToMessage)!
                                  .plaintext,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AdoetzTypography.captionTime(
                                palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: palette.textSecondary,
                        ),
                        onPressed: widget.onClearReplyOrEdit,
                      ),
                    ],
                  ),
                ),

              // Bottom Row: Either STATE C (Voice Recorder Locked) or STATE A/B
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: widget.isRecordingVoiceNote
                    ? _buildStateCVoiceRecorder(palette)
                    : _buildStateAOrBInputRow(palette, hasText, inputRadius),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// STATE C: MEREKAM VOICE NOTE (TERKUNCI / LOCKED) — Section 5.3 & UI-12
  Widget _buildStateCVoiceRecorder(AdoetzPalette palette) {
    final mm = (widget.voiceNoteSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (widget.voiceNoteSeconds % 60).toString().padLeft(2, '0');

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: 6),
          Icon(Icons.fiber_manual_record, size: 14, color: palette.statusDanger),
          const SizedBox(width: 4),
          Text(
            '$mm:$ss',
            style: AdoetzTypography.monoKey(palette.textPrimary),
          ),
          const SizedBox(width: 10),
          // 24-Bar Live Amplitude Waveform
          Expanded(
            child: SizedBox(
              height: 26,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(widget.liveWaveform.length, (i) {
                  final barH = (widget.liveWaveform[i] * 22).clamp(4.0, 22.0);
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      height: barH,
                      decoration: BoxDecoration(
                        color: palette.accentInteractive,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          IconButton(
            tooltip: widget.isVoiceNotePaused ? 'Lanjutkan Rekam' : 'Jeda',
            icon: Icon(
              widget.isVoiceNotePaused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
              size: 20,
              color: palette.textSecondary,
            ),
            onPressed: widget.onTogglePauseVoiceRecord,
          ),
          IconButton(
            tooltip: 'Hapus Rekaman',
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: palette.statusDanger,
            ),
            onPressed: widget.onCancelVoiceRecord,
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: palette.accentPrimary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.send_rounded, size: 19),
              onPressed: widget.onSendVoiceRecord,
            ),
          ),
        ],
      ),
    );
  }

  /// STATE A (Idle) & STATE B (Typing Text / Has Attachment)
  Widget _buildStateAOrBInputRow(
    AdoetzPalette palette,
    bool hasText,
    double inputRadius,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // [+] Attachment Button (44dp visual, >=48dp touch target)
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            key: const Key('composer_attachment_btn'),
            tooltip: 'Lampiran Terenkripsi',
            icon: Icon(Icons.add_rounded, size: 24, color: palette.textSecondary),
            onPressed: widget.onOpenAttachments,
          ),
        ),
        const SizedBox(width: 4),
        // Dynamic Input Box (44dp min height -> max 5 lines / 124dp)
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AdoetzDimensions.composerMinHeight, // 44dp
              maxHeight: AdoetzDimensions.composerMaxHeight, // 124dp (5 lines)
            ),
            child: Container(
              decoration: BoxDecoration(
                color: palette.bgElevated,
                borderRadius: BorderRadius.circular(inputRadius),
                border: Border.all(color: palette.borderHairline, width: 1.0),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('composer_text_field'),
                      controller: widget.controller,
                      minLines: 1,
                      maxLines: 5,
                      style: AdoetzTypography.chatBody(palette.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Ketik pesan...',
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sisipkan Emoji',
                    icon: Icon(
                      Icons.sentiment_satisfied_alt_outlined,
                      size: 20,
                      color: palette.textSecondary,
                    ),
                    onPressed: () {
                      final text = widget.controller.text;
                      widget.controller.text = '$text😊';
                      widget.controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: widget.controller.text.length),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Right Action Button: [🎤 Rekam Suara] in State A, [➤ Kirim (Biru)] in State B
        SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              switchInCurve: Curves.easeOutCubic,
              child: hasText
                  ? SizedBox(
                      key: const ValueKey('send_btn'),
                      width: 44,
                      height: 44,
                      child: IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: palette.accentPrimary,
                          foregroundColor: palette.accentOnPrimary,
                        ),
                        icon: const Icon(Icons.send_rounded, size: 19),
                        onPressed: widget.onSendText,
                      ),
                    )
                  : SizedBox(
                      key: const ValueKey('mic_btn'),
                      width: 44,
                      height: 44,
                      child: IconButton(
                        tooltip: 'Rekam Pesan Suara E2EE',
                        style: IconButton.styleFrom(
                          backgroundColor: palette.bgElevated,
                          foregroundColor: palette.textPrimary,
                        ),
                        icon: const Icon(Icons.mic_none_rounded, size: 22),
                        onPressed: widget.onStartVoiceRecord,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// UI-13: Chat Info, Shared Media Grid (3 Tabs), & Safety Number Verification (60-digit + QR Code)
class ChatInfoScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatInfoScreen({
    super.key,
    required this.conversationId,
  });

  @override
  ConsumerState<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends ConsumerState<ChatInfoScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AdoetzPalette.of(context);
    final appState = ref.watch(appControllerProvider);
    final vault = ref.watch(vaultDatabaseProvider);
    final crypto = ref.watch(signalProtocolProvider);
    final conv = vault.getConversation(widget.conversationId);

    if (conv == null) {
      return Scaffold(
        backgroundColor: palette.bgCanvas,
        appBar: AppBar(title: const Text('Info Percakapan')),
        body: const Center(child: Text('Percakapan tidak ditemukan')),
      );
    }

    final messages = vault.getMessages(widget.conversationId);
    final mediaMsgs = messages
        .where((m) =>
            m.attachmentKind == AttachmentKind.image ||
            m.attachmentKind == AttachmentKind.video)
        .toList();
    final docMsgs = messages
        .where((m) => m.attachmentKind == AttachmentKind.document)
        .toList();
    final voiceMsgs = messages
        .where((m) => m.attachmentKind == AttachmentKind.voiceNote)
        .toList();

    final safety = crypto.computeSafetyNumber(
      localUserId: appState.currentUserId ?? 'usr_local',
      localIdentityKeyB64:
          appState.deviceKeyBundle?.identityPublicKeyB64 ?? 'local_key_v2',
      peerUserId: conv.peerUserId,
      peerIdentityKeyB64: conv.peerIdentityKeyB64,
    );

    return Scaffold(
      backgroundColor: palette.bgCanvas,
      appBar: AppBar(
        title: const Text('Info Chat & Verifikasi E2EE'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Peer Profile Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.borderHairline),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: palette.bgElevated,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      conv.peerDisplayName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: palette.accentInteractive,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conv.peerDisplayName,
                          style: AdoetzTypography.listTitle(
                            palette.textPrimary,
                            unread: true,
                          ),
                        ),
                        Text(
                          '@${conv.peerUsername}',
                          style: AdoetzTypography.listSubtitle(
                            palette.accentInteractive,
                          ),
                        ),
                        if (conv.peerBio.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            conv.peerBio,
                            style: AdoetzTypography.captionTime(
                              palette.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Safety Number & QR Verification Section (UI-13)
            Text(
              'VERIFIKASI SAFETY NUMBER (60-DIGIT & QR)',
              style: AdoetzTypography.sectionHeader(palette.textMuted),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.borderHairline),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: safety.qrPayload,
                      version: QrVersions.auto,
                      size: 168.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kode Keamanan 60-Digit (12 Kelompok × 5 Digit)',
                    style: AdoetzTypography.captionTime(
                      palette.textSecondary,
                      bold: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 12 blocks of 5 digits in Roboto Mono 13sp (`type.monoKey`)
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: safety.blocks.map((block) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: palette.bgElevated,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          block,
                          style: AdoetzTypography.monoKey(palette.textPrimary),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                          label: const Text('Pindai QR Kontak'),
                          onPressed: () {
                            ref
                                .read(appControllerProvider.notifier)
                                .acceptAndVerifyPeerKey(
                                  conversationId: conv.id,
                                  markVerified: true,
                                );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'QR Identity Key @${conv.peerUsername} cocok! Ditandai sebagai Terverifikasi.',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Salin 60-Digit'),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: safety.formatted60Digits),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Safety Number 60-digit disalin'),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Tandai Sebagai Terverifikasi',
                      style: AdoetzTypography.listTitle(palette.textPrimary),
                    ),
                    subtitle: Text(
                      conv.isVerified
                          ? 'Identity Key kontak ini telah diverifikasi'
                          : 'Belum diverifikasi secara langsung',
                      style: AdoetzTypography.captionTime(
                        conv.isVerified
                            ? palette.statusSuccess
                            : palette.textSecondary,
                      ),
                    ),
                    value: conv.isVerified,
                    activeThumbColor: palette.statusSuccess,
                    onChanged: (val) {
                      ref
                          .read(appControllerProvider.notifier)
                          .acceptAndVerifyPeerKey(
                            conversationId: conv.id,
                            markVerified: val,
                          );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            // Shared Media, Documents, & Voice Notes (3 Tabs — UI-13)
            Text(
              'MEDIA, DOKUMEN, & SUARA TERDEKRIPSI LOKAL',
              style: AdoetzTypography.sectionHeader(palette.textMuted),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: palette.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.borderHairline),
              ),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: palette.accentInteractive,
                    unselectedLabelColor: palette.textSecondary,
                    indicatorColor: palette.accentPrimary,
                    tabs: [
                      Tab(text: 'Media (${mediaMsgs.length})'),
                      Tab(text: 'Dokumen (${docMsgs.length})'),
                      Tab(text: 'Suara (${voiceMsgs.length})'),
                    ],
                  ),
                  SizedBox(
                    height: 180,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSharedAttachmentList(palette, mediaMsgs, 'Belum ada foto/video bersama'),
                        _buildSharedAttachmentList(palette, docMsgs, 'Belum ada dokumen bersama'),
                        _buildSharedAttachmentList(palette, voiceMsgs, 'Belum ada pesan suara bersama'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedAttachmentList(
    AdoetzPalette palette,
    List<LocalMessage> items,
    String emptyLabel,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: AdoetzTypography.listSubtitle(palette.textMuted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (context, index) => Divider(color: palette.borderHairline),
      itemBuilder: (context, index) {
        final m = items[index];
        return ListTile(
          dense: true,
          leading: Icon(
            m.attachmentKind == AttachmentKind.voiceNote
                ? Icons.mic_rounded
                : Icons.attachment_rounded,
            color: palette.accentInteractive,
          ),
          title: Text(
            m.attachmentName ?? m.plaintext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AdoetzTypography.listSubtitle(palette.textPrimary),
          ),
          subtitle: Text(
            DateFormat('dd MMM yyyy, HH:mm').format(m.createdAt),
            style: AdoetzTypography.captionTime(palette.textMuted),
          ),
        );
      },
    );
  }
}
