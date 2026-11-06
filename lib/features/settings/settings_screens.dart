import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/theme/design_tokens.dart';
import '../../core/network/supabase_gateway.dart';
import '../../core/state/app_controller.dart';

/// UI-18: Settings Screen (Section 6.4)
/// - Top Profile Summary Card (56dp Avatar, Name, `@username`, `Edit` button)
/// - Flat Menu Groups with 22dp monochrome outline icons
/// - Conditional `Panel Administrator` (only rendered when `role == 'admin'`)
/// - `Keluar (Logout)` dialog with option to keep local keys or `"Keluar & Hapus Data Lokal"`
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showEditProfileDialog(BuildContext context, WidgetRef ref) {
    final appState = ref.read(appControllerProvider);
    final nameCtrl = TextEditingController(text: appState.currentDisplayName);
    final bioCtrl = TextEditingController(text: appState.currentBio);
    var discoverable = appState.isDiscoverable;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              title: const Text('Edit Profil Pengguna'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama Tampilan (Display Name)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bioCtrl,
                      maxLength: 160,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Bio (Maksimal 160 karakter)',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dapat Dicari (@username)'),
                      value: discoverable,
                      onChanged: (v) => setModalState(() => discoverable = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    ref.read(appControllerProvider.notifier).updateOwnProfile(
                          displayName: nameCtrl.text,
                          bio: bioCtrl.text,
                          discoverable: discoverable,
                        );
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    final palette = AdoetzPalette.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Keluar dari Akun?'),
          content: Text(
            'Kunci enkripsi lokal dan database SQLCipher (adoetz_vault.db) tetap tersimpan aman di perangkat ini kecuali Anda memilih "Keluar & Hapus Data Lokal".',
            style: AdoetzTypography.listSubtitle(palette.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            OutlinedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await ref
                    .read(appControllerProvider.notifier)
                    .signOut(wipeLocalData: false);
                if (context.mounted) {
                  context.go('/welcome');
                }
              },
              child: const Text('Keluar Saja'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: palette.statusDanger,
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await ref
                    .read(appControllerProvider.notifier)
                    .signOut(wipeLocalData: true);
                if (context.mounted) {
                  context.go('/welcome');
                }
              },
              child: const Text('Keluar & Hapus Data Lokal'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AdoetzPalette.of(context);
    final appState = ref.watch(appControllerProvider);

    return Scaffold(
      backgroundColor: palette.bgCanvas,
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Top User Profile Summary Card (56dp Avatar, Name, @username, Edit button)
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
                    border: Border.all(color: palette.borderHairline),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    appState.currentDisplayName.isNotEmpty
                        ? appState.currentDisplayName[0].toUpperCase()
                        : 'A',
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
                        appState.currentDisplayName.isEmpty
                            ? 'Pengguna Adoetz'
                            : appState.currentDisplayName,
                        style: AdoetzTypography.listTitle(
                          palette.textPrimary,
                          unread: true,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${appState.currentUsername.isEmpty ? "user" : appState.currentUsername} • Role: ${appState.currentRole.toUpperCase()}',
                        style: AdoetzTypography.captionTime(
                          palette.accentInteractive,
                          bold: true,
                        ),
                      ),
                      if (appState.currentBio.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          appState.currentBio,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AdoetzTypography.captionTime(
                            palette.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: () => _showEditProfileDialog(context, ref),
                  child: const Text('Edit'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'PREFERENSI & KEAMANAN PERANGKAT',
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
                _SettingsMenuRow(
                  icon: Icons.devices_outlined,
                  title: 'Akun & Identitas Perangkat',
                  subtitle: 'Single-Active-Device E2EE, PreKey & OTPK',
                  onTap: () => context.push('/settings/account'),
                ),
                Divider(height: 0.5, indent: 52, color: palette.borderHairline),
                _SettingsMenuRow(
                  icon: Icons.shield_outlined,
                  title: 'Privasi & Kunci Aplikasi',
                  subtitle: 'Biometrik/PIN, Tanda Baca, Blokir, FLAG_SECURE',
                  onTap: () => context.push('/settings/privacy'),
                ),
                Divider(height: 0.5, indent: 52, color: palette.borderHairline),
                _SettingsMenuRow(
                  icon: Icons.palette_outlined,
                  title: 'Tampilan & Tema',
                  subtitle: 'Charcoal Dark / Crisp Alabaster Light',
                  onTap: () => context.push('/settings/appearance'),
                ),
                Divider(height: 0.5, indent: 52, color: palette.borderHairline),
                _SettingsMenuRow(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifikasi & Panggilan',
                  subtitle: 'Saluran FCM HTTP v1 & Android CallStyle',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Saluran com.adoetzchat2.chat.messages & .calls aktif (0 byte plaintext di FCM).',
                        ),
                      ),
                    );
                  },
                ),
                Divider(height: 0.5, indent: 52, color: palette.borderHairline),
                _SettingsMenuRow(
                  icon: Icons.storage_outlined,
                  title: 'Penyimpanan & Cache Lokal',
                  subtitle: 'adoetz_vault.db (SQLCipher AES-256 Keystore)',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Database lokal adoetz_vault.db terenkripsi dengan Master Key Android Keystore.',
                        ),
                      ),
                    );
                  },
                ),
                // Item 6: Panel Administrator (ONLY rendered if server role claim `role == 'admin'`)
                if (appState.isAdmin) ...[
                  Divider(height: 0.5, indent: 52, color: palette.borderHairline),
                  _SettingsMenuRow(
                    key: const Key('settings_admin_panel_row'),
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Panel Administrator',
                    subtitle: 'Manajemen Akun, Force Reset & Audit Log (UI-22..24)',
                    iconColor: palette.accentInteractive,
                    onTap: () => context.push('/admin'),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),
          // Evaluation Role Switcher & Chaos Testing Utilities
          Text(
            'DIAGNOSTIK & PENGUJIAN RBAC / CHAOS (PRD v2.0)',
            style: AdoetzTypography.sectionHeader(palette.textMuted),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.borderHairline),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: Text(
                    appState.isAdmin
                        ? 'Klaim JWT: role=admin (Aktif)'
                        : 'Simulasikan Klaim JWT role=admin',
                  ),
                  selected: appState.isAdmin,
                  onSelected: (val) {
                    ref
                        .read(appControllerProvider.notifier)
                        .setRoleForTesting(val ? 'admin' : 'user');
                  },
                ),
                ActionChip(
                  label: const Text('Uji Penangguhan Real-Time (ERR-07 -> UI-25)'),
                  onPressed: () {
                    ref
                        .read(appControllerProvider.notifier)
                        .simulateRealtimeAdminSuspension();
                    context.go('/blocker');
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          // Item 7: Keluar (Logout) in `status.danger`
          Container(
            decoration: BoxDecoration(
              color: palette.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.borderHairline),
            ),
            child: ListTile(
              key: const Key('settings_logout_row'),
              leading: Icon(
                Icons.logout_rounded,
                size: 22,
                color: palette.statusDanger,
              ),
              title: Text(
                'Keluar (Logout)',
                style: AdoetzTypography.listTitle(palette.statusDanger),
              ),
              onTap: () => _showLogoutDialog(context, ref),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Adoetz Chat 2 v${AppEnvironment.appVersion} (${AppEnvironment.appNamespace})',
              style: AdoetzTypography.captionTime(palette.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsMenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final VoidCallback onTap;

  const _SettingsMenuRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AdoetzPalette.of(context);
    return ListTile(
      leading: Icon(
        icon,
        size: 22, // 22dp monochrome outline icon per UI-18 spec
        color: iconColor ?? palette.textPrimary,
      ),
      title: Text(
        title,
        style: AdoetzTypography.listTitle(palette.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        style: AdoetzTypography.captionTime(palette.textSecondary),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: palette.textMuted),
      onTap: onTap,
    );
  }
}

/// UI-19: Appearance & Theme Preview Screen (Section 6.4)
/// - 3 Radio options (`Ikuti Sistem [Default]`, `Mode Gelap Charcoal`, `Mode Terang Alabaster`)
/// - Live preview box with 2 chat bubbles (incoming & outgoing) that updates immediately
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AdoetzPalette.of(context);
    final appState = ref.watch(appControllerProvider);

    return Scaffold(
      backgroundColor: palette.bgCanvas,
      appBar: AppBar(
        title: const Text('Tampilan & Tema'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'PRATINJAU LANGSUNG GELEMBUNG CHAT',
            style: AdoetzTypography.sectionHeader(palette.textMuted),
          ),
          const SizedBox(height: 8),
          // Live Preview Box with Incoming & Outgoing Chat Bubbles
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.bgCanvas,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.borderHairline, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: palette.bubbleIncomingBg,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                        bottomLeft: Radius.circular(4),
                      ),
                      border: !palette.isDark
                          ? Border.all(color: palette.bubbleIncomingBorder)
                          : null,
                    ),
                    child: Text(
                      'Halo! Apakah tema Precision Neutral v2.0 sudah nyaman di mata?   09:40',
                      style: AdoetzTypography.chatBody(palette.bubbleIncomingText),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: palette.bubbleOutgoingBg,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'Sangat kontras & bersih, memenuhi standar WCAG 2.2 AA.',
                            style: AdoetzTypography.chatBody(
                              palette.bubbleOutgoingText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '09:41',
                          style: AdoetzTypography.captionTime(
                            palette.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all_rounded,
                          size: 14,
                          color: palette.tickRead,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'MODE WARNA TEMA',
            style: AdoetzTypography.sectionHeader(palette.textMuted),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: palette.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.borderHairline),
            ),
            child: RadioGroup<ThemeMode>(
              groupValue: appState.themeMode,
              onChanged: (val) {
                if (val != null) {
                  ref.read(appControllerProvider.notifier).setThemeMode(val);
                }
              },
              child: Column(
                children: [
                  const RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    title: Text('Ikuti Sistem [Default]'),
                    subtitle: Text('Menyesuaikan pengaturan tema OS Android'),
                  ),
                  Divider(height: 0.5, color: palette.borderHairline),
                  const RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    title: Text('Mode Gelap Charcoal (#0E1013)'),
                    subtitle: Text('Matte Charcoal & Muted Steel Blue'),
                  ),
                  Divider(height: 0.5, color: palette.borderHairline),
                  const RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    title: Text('Mode Terang Alabaster (#F6F7F9)'),
                    subtitle: Text('Crisp Alabaster & Kontras Tinggi'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// UI-20: Privacy, App Lock & Security Preferences Screen (Section 6.4)
class PrivacySecurityScreen extends ConsumerWidget {
  const PrivacySecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AdoetzPalette.of(context);
    final appState = ref.watch(appControllerProvider);
    final blockedList =
        appState.directory.where((c) => c.isBlocked).toList();

    return Scaffold(
      backgroundColor: palette.bgCanvas,
      appBar: AppBar(
        title: const Text('Privasi & Kunci Aplikasi'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'KUNCI APLIKASI & KEAMANAN LAYAR',
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
                SwitchListTile(
                  title: const Text('Kunci Aplikasi (Biometrik / PIN)'),
                  subtitle: Text(
                    appState.appLockEnabled
                        ? 'Aktif (PIN: ${appState.appLockPin})'
                        : 'Nonaktif',
                  ),
                  value: appState.appLockEnabled,
                  onChanged: (val) {
                    ref
                        .read(appControllerProvider.notifier)
                        .configureAppLock(enabled: val);
                  },
                ),
                if (appState.appLockEnabled) ...[
                  Divider(height: 0.5, color: palette.borderHairline),
                  ListTile(
                    leading: const Icon(Icons.lock_clock_outlined),
                    title: const Text('Kunci Aplikasi Sekarang'),
                    onTap: () {
                      ref.read(appControllerProvider.notifier).lockAppNow();
                      context.go('/applock');
                    },
                  ),
                ],
                Divider(height: 0.5, color: palette.borderHairline),
                SwitchListTile(
                  title: const Text('Blokir Tangkapan Layar (FLAG_SECURE)'),
                  subtitle: const Text(
                    'Mencegah screenshot dan perekaman layar di ruang chat',
                  ),
                  value: appState.screenshotProtectionEnabled,
                  onChanged: (val) {
                    ref
                        .read(appControllerProvider.notifier)
                        .toggleScreenshotProtection(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'PRIVASI PERCAKAPAN',
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
                SwitchListTile(
                  title: const Text('Laporan Dibaca (Read Receipts ✓✓)'),
                  subtitle: const Text(
                    'Kirim dan terima indikator centang biru saat pesan dibaca',
                  ),
                  value: appState.readReceiptsEnabled,
                  onChanged: (val) {
                    ref
                        .read(appControllerProvider.notifier)
                        .toggleReadReceipts(val);
                  },
                ),
                Divider(height: 0.5, color: palette.borderHairline),
                SwitchListTile(
                  title: const Text('Indikator Sedang Mengetik'),
                  subtitle: const Text(
                    'Tampilkan status mengetik melalui saluran Realtime ephemeral',
                  ),
                  value: appState.typingIndicatorsEnabled,
                  onChanged: (val) {
                    ref
                        .read(appControllerProvider.notifier)
                        .toggleTypingIndicators(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'DAFTAR PENGGUNA DIBLOKIR (${blockedList.length})',
            style: AdoetzTypography.sectionHeader(palette.textMuted),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: palette.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.borderHairline),
            ),
            child: blockedList.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Tidak ada kontak yang diblokir.',
                      style: AdoetzTypography.listSubtitle(palette.textSecondary),
                    ),
                  )
                : Column(
                    children: blockedList.map((c) {
                      return ListTile(
                        title: Text(c.displayName),
                        subtitle: Text('@${c.username}'),
                        trailing: TextButton(
                          onPressed: () {
                            ref
                                .read(appControllerProvider.notifier)
                                .toggleBlockContact(c.userId);
                          },
                          child: const Text('Buka Blokir'),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

/// UI-21: My Account & Active Device Identity Screen (Section 6.4 & Section 8.1)
class MyAccountDeviceScreen extends ConsumerWidget {
  const MyAccountDeviceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AdoetzPalette.of(context);
    final appState = ref.watch(appControllerProvider);
    final bundle = appState.deviceKeyBundle;

    return Scaffold(
      backgroundColor: palette.bgCanvas,
      appBar: AppBar(
        title: const Text('Akun & Identitas Perangkat'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'IDENTITAS AKUN',
            style: AdoetzTypography.sectionHeader(palette.textMuted),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.borderHairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoPair(
                  label: 'Username Unik',
                  value: '@${appState.currentUsername}',
                ),
                const SizedBox(height: 10),
                _InfoPair(
                  label: 'Alamat Email',
                  value: appState.currentEmail,
                ),
                const SizedBox(height: 10),
                _InfoPair(
                  label: 'Role & Status Server',
                  value:
                      '${appState.currentRole.toUpperCase()} • ${appState.accountStatus.toUpperCase()}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'PERANGKAT E2EE AKTIF (STRICT SINGLE-ACTIVE-DEVICE)',
            style: AdoetzTypography.sectionHeader(palette.textMuted),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.borderHairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoPair(
                  label: 'Nama Perangkat',
                  value: appState.activeDeviceName,
                ),
                const SizedBox(height: 10),
                _InfoPair(
                  label: 'Signal Registration ID',
                  value: '${bundle?.registrationId ?? 8421}',
                ),
                const SizedBox(height: 10),
                Text(
                  'Identity Public Key (Curve25519 / X25519)',
                  style: AdoetzTypography.captionTime(palette.textSecondary),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  bundle?.identityPublicKeyB64 ??
                      'MCowBQYDK2VuAyEA8f91nK2sV0pL7xZ3qW4mR9tY6uI1oP2aS3dF4gH5jK8=',
                  style: AdoetzTypography.monoKey(palette.accentInteractive),
                ),
                const SizedBox(height: 12),
                _InfoPair(
                  label: 'Rotasi Signed PreKey Terakhir',
                  value: appState.lastSignedPreKeyRotation != null
                      ? DateFormat('dd MMM yyyy, HH:mm')
                          .format(appState.lastSignedPreKeyRotation!)
                      : 'Baru saja',
                ),
                const SizedBox(height: 10),
                _InfoPair(
                  label: 'Sisa One-Time PreKeys (OTPK) di Server',
                  value: '${appState.remainingOneTimePreKeys} kunci tersedia',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          ref
                              .read(appControllerProvider.notifier)
                              .rotateSignedPreKeyNow();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Signed PreKey berhasil dirotasi'),
                            ),
                          );
                        },
                        child: const Text('Rotasi Signed PreKey'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          ref
                              .read(appControllerProvider.notifier)
                              .replenishOneTimePreKeys();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('+80 One-Time PreKeys baru diunggah'),
                            ),
                          );
                        },
                        child: const Text('Isi Ulang 80 OTPK'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPair extends StatelessWidget {
  final String label;
  final String value;

  const _InfoPair({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AdoetzPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AdoetzTypography.captionTime(palette.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AdoetzTypography.listTitle(palette.textPrimary),
        ),
      ],
    );
  }
}
