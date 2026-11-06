import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/design_tokens.dart';
import '../../core/database/models.dart';
import '../../core/state/app_controller.dart';

/// UI-08: Contact Search & Directory Screen (Section 6.2)
/// - 42dp search input in `bg.elevated`, `✕` clear button
/// - Minimum 2 characters, 350ms debounce
/// - 44dp Avatar, Display Name (15.5sp Medium), `@username` (13.5sp `accent.interactive`)
class ContactsDirectoryScreen extends ConsumerStatefulWidget {
  final bool autoFocusSearch;

  const ContactsDirectoryScreen({
    super.key,
    this.autoFocusSearch = false,
  });

  @override
  ConsumerState<ContactsDirectoryScreen> createState() =>
      _ContactsDirectoryScreenState();
}

class _ContactsDirectoryScreenState
    extends ConsumerState<ContactsDirectoryScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _debouncedQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String raw) {
    _debounce?.cancel();
    // 350ms debounce per UI-08 specification
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          _debouncedQuery = raw.trim().toLowerCase().replaceAll('@', '');
        });
      }
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = AdoetzPalette.of(context);
    final appState = ref.watch(appControllerProvider);

    final rawLen = _searchController.text.trim().replaceAll('@', '').length;
    final filteredContacts = appState.directory.where((c) {
      if (c.username == appState.currentUsername) return false;
      if (_debouncedQuery.isEmpty) return true;
      if (_debouncedQuery.length < 2) return false;
      return c.username.toLowerCase().contains(_debouncedQuery) ||
          c.displayName.toLowerCase().contains(_debouncedQuery);
    }).toList();

    return Scaffold(
      backgroundColor: palette.bgCanvas,
      appBar: AppBar(
        titleSpacing: 16,
        title: SizedBox(
          height: 42, // 42dp height per UI-08
          child: TextField(
            key: const Key('contact_search_input'),
            controller: _searchController,
            autofocus: widget.autoFocusSearch,
            onChanged: _onSearchChanged,
            style: AdoetzTypography.chatBody(palette.textPrimary),
            decoration: InputDecoration(
              hintText: 'Cari @username...',
              filled: true,
              fillColor: palette.bgElevated,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: palette.textSecondary,
              ),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: palette.textSecondary,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _debouncedQuery = '');
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AdoetzDimensions.radiusSearchOrComposer,
                ),
                borderSide: BorderSide(color: palette.borderHairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AdoetzDimensions.radiusSearchOrComposer,
                ),
                borderSide: BorderSide(color: palette.borderHairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AdoetzDimensions.radiusSearchOrComposer,
                ),
                borderSide: BorderSide(color: palette.accentPrimary, width: 1.4),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rawLen == 1)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Ketik minimal 2 karakter untuk mencari @username.',
                style: AdoetzTypography.captionTime(palette.textSecondary),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              _debouncedQuery.length >= 2
                  ? 'HASIL PENCARIAN (@$_debouncedQuery)'
                  : 'DIREKTORI KONTAK TERENKRIPSI',
              style: AdoetzTypography.sectionHeader(palette.textMuted),
            ),
          ),
          Expanded(
            child: filteredContacts.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada pengguna dengan @$_debouncedQuery',
                      style: AdoetzTypography.listSubtitle(palette.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredContacts.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 0.5,
                      thickness: 0.5,
                      indent: 72,
                      color: palette.borderHairline,
                    ),
                    itemBuilder: (context, index) {
                      final contact = filteredContacts[index];
                      return InkWell(
                        onTap: () => context.push('/user/${contact.username}'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          color: palette.bgSurface,
                          child: Row(
                            children: [
                              // 44dp Avatar per UI-08
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: palette.bgElevated,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: palette.borderHairline,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  contact.displayName.isNotEmpty
                                      ? contact.displayName[0].toUpperCase()
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            contact.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w500,
                                              color: palette.textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (contact.isVerified) ...[
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.verified_rounded,
                                            size: 14,
                                            color: palette.statusSuccess,
                                          ),
                                        ],
                                        if (contact.isBlocked) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            '[Diblokir]',
                                            style: AdoetzTypography.captionTime(
                                              palette.statusDanger,
                                              bold: true,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '@${contact.username}',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: palette.accentInteractive,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: palette.textMuted,
                              ),
                            ],
                          ),
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

/// UI-09: Contact Profile Sheet / Screen (Section 6.2)
/// - 84dp large circular avatar at top center
/// - Display Name (20sp SemiBold) + tap-to-copy `@username` chip
/// - Bio box (14sp, max 4 lines)
/// - 3 Quick Action Buttons (height 64dp each, radius 12dp `bg.elevated`)
/// - Encryption Status Card + Destructive Block & Report rows
class ContactProfileScreen extends ConsumerWidget {
  final String username;

  const ContactProfileScreen({
    super.key,
    required this.username,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AdoetzPalette.of(context);
    final appState = ref.watch(appControllerProvider);
    final cleanUsername = username.replaceAll('@', '').toLowerCase();

    final contact = appState.directory.firstWhere(
      (c) => c.username.toLowerCase() == cleanUsername,
      orElse: () => ContactDirectoryEntry(
        userId: 'usr_$cleanUsername',
        username: cleanUsername,
        displayName: cleanUsername,
        bio: 'Pengguna terenkripsi Adoetz Chat 2',
        identityPublicKeyB64: 'key_$cleanUsername',
        createdAt: DateTime.now(),
      ),
    );

    return Scaffold(
      backgroundColor: palette.bgCanvas,
      appBar: AppBar(
        title: const Text('Profil Kontak'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // 84dp Circle Avatar at top center
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: palette.bgElevated,
                shape: BoxShape.circle,
                border: Border.all(color: palette.borderHairline, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                contact.displayName.isNotEmpty
                    ? contact.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: palette.accentInteractive,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              contact.displayName,
              textAlign: TextAlign.center,
              style: AdoetzTypography.screenTitle(palette.textPrimary),
            ),
            const SizedBox(height: 6),
            // Tap-to-copy @username chip
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Clipboard.setData(ClipboardData(text: '@${contact.username}'));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('@${contact.username} disalin ke clipboard'),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: palette.bgElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.borderHairline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '@${contact.username}',
                      style: AdoetzTypography.listSubtitle(
                        palette.accentInteractive,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: palette.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bio Box (14sp, max 4 lines)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.borderHairline),
              ),
              child: Text(
                contact.bio.isEmpty ? 'Tidak ada bio.' : contact.bio,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AdoetzTypography.listSubtitle(palette.textSecondary),
              ),
            ),
            const SizedBox(height: 16),

            // Quick Action Row (3 equal buttons, height 64dp each, bg.elevated radius 12dp)
            Row(
              children: [
                Expanded(
                  child: _QuickActionBox(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Kirim Pesan',
                    onTap: () async {
                      final convId = await ref
                          .read(appControllerProvider.notifier)
                          .startOrGetConversationWithContact(contact);
                      if (context.mounted) {
                        context.push('/chat/$convId');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionBox(
                    icon: Icons.call_outlined,
                    label: 'Panggilan Suara',
                    onTap: () {
                      ref
                          .read(appControllerProvider.notifier)
                          .startOutgoingCall(peer: contact, isVideo: false);
                      context.push('/call/active');
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionBox(
                    icon: Icons.videocam_outlined,
                    label: 'Panggilan Video',
                    onTap: () {
                      ref
                          .read(appControllerProvider.notifier)
                          .startOutgoingCall(peer: contact, isVideo: true);
                      context.push('/call/active');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Encryption Status Card
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final convId = await ref
                    .read(appControllerProvider.notifier)
                    .startOrGetConversationWithContact(contact);
                if (context.mounted) {
                  context.push('/chat/$convId/info');
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.borderHairline),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 24,
                      color: contact.isVerified
                          ? palette.statusSuccess
                          : palette.accentPrimary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enkripsi End-to-End Aktif',
                            style: AdoetzTypography.listTitle(palette.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            contact.isVerified
                                ? 'Terverifikasi (Safety Number 60-Digit)'
                                : 'Ketuk untuk memverifikasi kode keamanan',
                            style: AdoetzTypography.captionTime(
                              contact.isVerified
                                  ? palette.statusSuccess
                                  : palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: palette.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Destructive Actions (Blokir @username & Laporkan Akun)
            Container(
              decoration: BoxDecoration(
                color: palette.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.borderHairline),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.block_rounded, color: palette.statusDanger),
                    title: Text(
                      contact.isBlocked
                          ? 'Buka Blokir @${contact.username}'
                          : 'Blokir @${contact.username}',
                      style: AdoetzTypography.listTitle(palette.statusDanger),
                    ),
                    onTap: () {
                      ref
                          .read(appControllerProvider.notifier)
                          .toggleBlockContact(contact.userId);
                    },
                  ),
                  Divider(height: 0.5, color: palette.borderHairline),
                  ListTile(
                    leading: Icon(
                      Icons.flag_outlined,
                      color: palette.statusDanger,
                    ),
                    title: Text(
                      'Laporkan Akun',
                      style: AdoetzTypography.listTitle(palette.statusDanger),
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Laporan terhadap @${contact.username} telah dikirim ke antrean moderasi Admin.',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionBox({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AdoetzPalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 64, // 64dp height per UI-09 spec
        decoration: BoxDecoration(
          color: palette.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.borderHairline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: palette.accentInteractive),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AdoetzTypography.captionTime(
                palette.textPrimary,
                bold: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
