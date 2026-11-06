import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/theme/design_tokens.dart';
import '../../core/database/models.dart';
import '../../core/state/app_controller.dart';
import '../../core/webrtc/webrtc_call_engine.dart';

/// UI-07: Chats List Screen + UI-06 Contextual Notification Permission Card
/// + Section 5.1 `ChatListItem` (74dp height, 76dp hairline divider indent)
/// + 100% Local SQLCipher FTS5 Message Search.
class ChatsListScreen extends ConsumerStatefulWidget {
  const ChatsListScreen({super.key});

  @override
  ConsumerState<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends ConsumerState<ChatsListScreen> {
  bool _isSearchingFts = false;
  final _ftsQueryController = TextEditingController();

  @override
  void dispose() {
    _ftsQueryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AdoetzPalette.of(context);
    final appState = ref.watch(appControllerProvider);
    final vault = ref.watch(vaultDatabaseProvider);
    final selectedIds = appState.selectedConversationIds;
    final hasSelection = selectedIds.isNotEmpty;

    final ftsResults = _isSearchingFts && _ftsQueryController.text.trim().isNotEmpty
        ? vault.searchLocalMessagesFts(_ftsQueryController.text)
        : const <({LocalConversation conversation, LocalMessage message})>[];

    return Scaffold(
      backgroundColor: palette.bgCanvas,
      appBar: hasSelection
          ? _buildContextualSelectionAppBar(context, palette, selectedIds.length)
          : _buildMainAppBar(context, palette),
      body: Column(
        children: [
          // Conditional Offline Banner (32dp height, only when offline — UI-07 & ERR-01)
          if (appState.isOffline)
            Container(
              width: double.infinity,
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: palette.statusWarning.withValues(alpha: 0.18),
              child: Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 16, color: palette.statusWarning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sedang offline • Pesan antre akan dikirim otomatis',
                      style: AdoetzTypography.captionTime(
                        palette.statusWarning,
                        bold: true,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(48, 28),
                    ),
                    onPressed: () {
                      ref
                          .read(appControllerProvider.notifier)
                          .setOfflineMode(false);
                    },
                    child: Text(
                      'Sambungkan',
                      style: AdoetzTypography.captionTime(
                        palette.accentInteractive,
                        bold: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Floating Mini-Call Pill (36dp height when active call is minimized — Section 6.3)
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
                child: Row(
                  children: [
                    const Icon(Icons.phone_in_talk_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Panggilan berlangsung (${appState.activeCall!.peerDisplayName}) • ${appState.activeCall!.formattedDuration} — Ketuk untuk kembali',
                        overflow: TextOverflow.ellipsis,
                        style: AdoetzTypography.captionTime(Colors.white, bold: true),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // UI-06: First-Run Contextual Notification Permission Card (Android 13+)
          if (!appState.notificationPermissionDismissed &&
              !appState.notificationPermissionGranted)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: palette.bgElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.borderHairline),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    size: 20,
                    color: palette.accentPrimary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Aktifkan notifikasi agar pesan dan panggilan masuk tidak terlewat',
                      style: AdoetzTypography.captionTime(palette.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(appControllerProvider.notifier)
                          .dismissNotificationBanner(granted: false);
                    },
                    child: Text(
                      'Nanti',
                      style: AdoetzTypography.captionTime(palette.textMuted),
                    ),
                  ),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.accentPrimary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(64, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () {
                      ref
                          .read(appControllerProvider.notifier)
                          .dismissNotificationBanner(granted: true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Saluran notifikasi FCM & CallStyle diaktifkan.',
                          ),
                        ),
                      );
                    },
                    child: const Text('Aktifkan', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

          // Main Content: Either Local FTS5 Search Results or Conversation List
          Expanded(
            child: _isSearchingFts && _ftsQueryController.text.trim().isNotEmpty
                ? _buildFtsSearchResults(context, palette, ftsResults)
                : (appState.conversations.isEmpty
                    ? _buildEmptyChatsState(context, palette)
                    : ListView.builder(
                        itemCount: appState.conversations.length,
                        itemBuilder: (context, index) {
                          final conv = appState.conversations[index];
                          final isSelected = selectedIds.contains(conv.id);
                          return ChatListItem(
                            conversation: conv,
                            isSelected: isSelected,
                            onTap: () {
                              if (hasSelection) {
                                ref
                                    .read(appControllerProvider.notifier)
                                    .toggleSelectConversation(conv.id);
                              } else {
                                ref
                                    .read(appControllerProvider.notifier)
                                    .markConversationRead(conv.id);
                                context.push('/chat/${conv.id}');
                              }
                            },
                            onLongPress: () {
                              ref
                                  .read(appControllerProvider.notifier)
                                  .toggleSelectConversation(conv.id);
                            },
                          );
                        },
                      )),
          ),
        ],
      ),
      // FAB (52x52dp, radius 14dp, accent.primary — Section 6.2 UI-07)
      floatingActionButton: SizedBox(
        width: 52,
        height: 52,
        child: FloatingActionButton(
          key: const Key('chats_new_chat_fab'),
          elevation: 1,
          backgroundColor: palette.accentPrimary,
          foregroundColor: palette.accentOnPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdoetzDimensions.radiusFab),
          ),
          onPressed: () => context.push('/contacts-search'),
          child: const Icon(Icons.add_comment_outlined, size: 22),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildMainAppBar(
    BuildContext context,
    AdoetzPalette palette,
  ) {
    if (_isSearchingFts) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () {
            setState(() {
              _isSearchingFts = false;
              _ftsQueryController.clear();
            });
          },
        ),
        title: SizedBox(
          height: 40,
          child: TextField(
            controller: _ftsQueryController,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: AdoetzTypography.chatBody(palette.textPrimary),
            decoration: InputDecoration(
              hintText: 'Cari pesan lokal (SQLCipher FTS5)...',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(color: palette.accentPrimary, width: 1),
              ),
              suffixIcon: _ftsQueryController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _ftsQueryController.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
      );
    }

    return AppBar(
      title: const Text('Adoetz Chat 2'),
      actions: [
        IconButton(
          tooltip: 'Cari Pesan Lokal (FTS5)',
          icon: const Icon(Icons.search_rounded, size: 22),
          onPressed: () => setState(() => _isSearchingFts = true),
        ),
        IconButton(
          tooltip: 'Cari Kontak @username',
          icon: const Icon(Icons.edit_square, size: 20),
          onPressed: () => context.push('/contacts-search'),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 22),
          color: palette.bgOverlay,
          onSelected: (value) {
            final ctrl = ref.read(appControllerProvider.notifier);
            final appState = ref.read(appControllerProvider);
            switch (value) {
              case 'toggle_offline':
                ctrl.setOfflineMode(!appState.isOffline);
                break;
              case 'simulate_incoming_call':
                final alex = appState.directory.first;
                ctrl.receiveIncomingCall(peer: alex, isVideo: false);
                context.push('/incoming-call');
                break;
              case 'simulate_expired_call_ttl':
                final alex = appState.directory.first;
                ctrl.receiveIncomingCall(
                  peer: alex,
                  isVideo: false,
                  customExpiresAtMs:
                      DateTime.now().millisecondsSinceEpoch - 60000,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'ERR-06: Payload FCM terlambat 60d (> TTL 40d). Dicatat sebagai Panggilan Tak Terjawab tanpa dering.',
                    ),
                  ),
                );
                break;
              case 'settings':
                context.go('/settings');
                break;
            }
          },
          itemBuilder: (ctx) {
            final isOffline = ref.read(appControllerProvider).isOffline;
            return [
              PopupMenuItem(
                value: 'toggle_offline',
                child: Text(
                  isOffline
                      ? 'Matikan Mode Offline (Kirim Antrean)'
                      : 'Simulasikan Jaringan Offline (ERR-01)',
                ),
              ),
              const PopupMenuItem(
                value: 'simulate_incoming_call',
                child: Text('Simulasikan Panggilan Masuk (UI-16)'),
              ),
              const PopupMenuItem(
                value: 'simulate_expired_call_ttl',
                child: Text('Uji FCM Panggilan Terlambat >40d (ERR-06)'),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Text('Pengaturan & Keamanan'),
              ),
            ];
          },
        ),
      ],
    );
  }

  /// Contextual Action Bar on Long-Press: `[✕ Batal] 1 dipilih [📌 Pin] [🔕 Mute] [🗑 Hapus Chat Lokal]`
  PreferredSizeWidget _buildContextualSelectionAppBar(
    BuildContext context,
    AdoetzPalette palette,
    int count,
  ) {
    final ctrl = ref.read(appControllerProvider.notifier);
    return AppBar(
      backgroundColor: palette.accentSubtle,
      leading: IconButton(
        tooltip: 'Batal',
        icon: const Icon(Icons.close, size: 22),
        onPressed: ctrl.clearSelectedConversations,
      ),
      title: Text(
        '$count dipilih',
        style: AdoetzTypography.listTitle(palette.textPrimary, unread: true),
      ),
      actions: [
        IconButton(
          tooltip: 'Pin Percakapan',
          icon: const Icon(Icons.push_pin_outlined, size: 21),
          onPressed: ctrl.togglePinSelectedConversations,
        ),
        IconButton(
          tooltip: 'Bisukan (Mute)',
          icon: const Icon(Icons.notifications_off_outlined, size: 21),
          onPressed: ctrl.toggleMuteSelectedConversations,
        ),
        IconButton(
          tooltip: 'Hapus Chat Lokal',
          icon: Icon(Icons.delete_outline, size: 22, color: palette.statusDanger),
          onPressed: ctrl.deleteSelectedConversationsLocal,
        ),
      ],
    );
  }

  Widget _buildFtsSearchResults(
    BuildContext context,
    AdoetzPalette palette,
    List<({LocalConversation conversation, LocalMessage message})> results,
  ) {
    if (results.isEmpty) {
      return Center(
        child: Text(
          'Tidak ditemukan pesan di indeks lokal FTS5 SQLCipher.',
          style: AdoetzTypography.listSubtitle(palette.textSecondary),
        ),
      );
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (context, index) => Divider(
        height: 0.5,
        thickness: 0.5,
        color: palette.borderHairline,
      ),
      itemBuilder: (context, index) {
        final item = results[index];
        return ListTile(
          tileColor: palette.bgSurface,
          title: Text(
            '${item.conversation.peerDisplayName} (@${item.conversation.peerUsername})',
            style: AdoetzTypography.listTitle(palette.textPrimary),
          ),
          subtitle: Text(
            item.message.plaintext,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AdoetzTypography.listSubtitle(palette.textSecondary),
          ),
          trailing: Text(
            DateFormat('HH:mm').format(item.message.createdAt),
            style: AdoetzTypography.captionTime(palette.textMuted),
          ),
          onTap: () => context.push('/chat/${item.conversation.id}'),
        );
      },
    );
  }

  Widget _buildEmptyChatsState(BuildContext context, AdoetzPalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 48, color: palette.textMuted),
            const SizedBox(height: 12),
            Text(
              'Belum Ada Percakapan Terenkripsi',
              style: AdoetzTypography.listTitle(palette.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Cari pengguna dengan @username untuk memulai percakapan 1:1 Signal E2EE.',
              textAlign: TextAlign.center,
              style: AdoetzTypography.listSubtitle(palette.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push('/contacts-search'),
              icon: const Icon(Icons.person_search_outlined, size: 18),
              label: const Text('Cari @username'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section 5.1: Precision Anatomy of `ChatListItem` (Height 74dp, Divider indent 76dp)
class ChatListItem extends StatelessWidget {
  final LocalConversation conversation;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ChatListItem({
    super.key,
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0 && now.day == dt.day) {
      return DateFormat('HH:mm').format(dt);
    } else if (diff.inDays <= 1) {
      return 'Kemarin';
    } else if (diff.inDays < 7) {
      const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      return days[dt.weekday - 1];
    }
    return DateFormat('dd/MM/yy').format(dt);
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AdoetzPalette.of(context);
    final hasUnread = conversation.unreadCount > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            height: AdoetzDimensions.chatListItemHeight, // 74dp
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 13.0),
            color: isSelected ? palette.accentSubtle : palette.bgSurface,
            child: Row(
              children: [
                // 48dp Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: palette.bgElevated,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? palette.accentPrimary : palette.borderHairline,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initials(conversation.peerDisplayName),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.accentInteractive,
                    ),
                  ),
                ),
                const SizedBox(width: 12), // 12dp gap -> X = 16 + 48 + 12 = 76dp
                // Expanded Flex 1
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (conversation.isPinned) ...[
                            Icon(
                              Icons.push_pin_rounded,
                              size: 14,
                              color: palette.accentInteractive,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              conversation.peerDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AdoetzTypography.listTitle(
                                palette.textPrimary,
                                unread: hasUnread,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (conversation.lastOutgoingStatus != null &&
                              !hasUnread) ...[
                            _buildStatusPreviewIcon(
                              palette,
                              conversation.lastOutgoingStatus!,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              conversation.draftText.isNotEmpty
                                  ? '[Draf] ${conversation.draftText}'
                                  : conversation.lastMessageSnippet,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AdoetzTypography.listSubtitle(
                                conversation.draftText.isNotEmpty
                                    ? palette.statusWarning
                                    : palette.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8), // 8dp gap
                // Right Column (Timestamp + Mute/Unread Badge 20dp)
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTimestamp(conversation.lastEventAt),
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 15.0 / 11.5,
                        fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                        color: hasUnread
                            ? palette.accentInteractive
                            : palette.textMuted,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (conversation.isMuted) ...[
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 15,
                            color: palette.textMuted,
                          ),
                          if (hasUnread) const SizedBox(width: 4),
                        ],
                        if (hasUnread)
                          Container(
                            height: 20,
                            constraints: const BoxConstraints(minWidth: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: palette.accentPrimary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${conversation.unreadCount}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Hairline Divider (0.5dp, inset left = 76dp, inset right = 0dp)
        Divider(
          height: 0.5,
          thickness: 0.5,
          indent: AdoetzDimensions.chatDividerIndent, // 76dp
          endIndent: 0,
          color: palette.borderHairline,
        ),
      ],
    );
  }

  Widget _buildStatusPreviewIcon(
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
        return Icon(Icons.error_outline_rounded, size: 15, color: palette.statusDanger);
    }
  }
}
