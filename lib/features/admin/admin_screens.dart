import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/theme/design_tokens.dart';
import '../../core/database/models.dart';
import '../../core/state/app_controller.dart';

/// UI-22: Admin Dashboard & User Directory (Section 6.4)
/// - 3 Summary Metrics (`Total Akun`, `Aktif`, `Ditangguhkan`)
/// - Search input (`Cari @username, email, atau UUID...`) + Filter Chips (`Semua`, `User`, `Admin`, `Suspended`)
/// - Paginated User List (25 rows/page): `@username`, email, `ACTIVE` / `SUSPENDED` badge, registration date
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'Semua'; // Semua, User, Admin, Suspended

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AdoetzPalette.of(context);
    final appState = ref.watch(appControllerProvider);

    if (!appState.isAdmin) {
      return Scaffold(
        backgroundColor: palette.bgCanvas,
        appBar: AppBar(title: const Text('Akses Ditolak')),
        body: Center(
          child: Text(
            'RBAC_FORBIDDEN: Hanya pengguna dengan klaim server role=admin yang diizinkan.',
            textAlign: TextAlign.center,
            style: AdoetzTypography.listSubtitle(palette.statusDanger),
          ),
        ),
      );
    }

    final allUsers = appState.directory;
    final totalCount = allUsers.length;
    final activeCount =
        allUsers.where((u) => u.accountStatus == 'active').length;
    final suspendedCount =
        allUsers.where((u) => u.accountStatus == 'suspended').length;

    final q = _searchController.text.trim().toLowerCase();
    final filtered = allUsers.where((u) {
      if (_selectedFilter == 'User' && u.role != 'user') return false;
      if (_selectedFilter == 'Admin' && u.role != 'admin') return false;
      if (_selectedFilter == 'Suspended' && u.accountStatus != 'suspended') {
        return false;
      }
      if (q.isEmpty) return true;
      return u.username.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.userId.toLowerCase().contains(q);
    }).take(25).toList(); // Paginated 25 rows per page

    return Scaffold(
      backgroundColor: palette.bgCanvas,
      appBar: AppBar(
        title: const Text('Panel Administrator'),
        actions: [
          TextButton.icon(
            key: const Key('admin_open_audit_log_btn'),
            onPressed: () => context.push('/admin/audit-logs'),
            icon: Icon(
              Icons.receipt_long_outlined,
              size: 18,
              color: palette.accentInteractive,
            ),
            label: Text(
              'Audit Log',
              style: AdoetzTypography.buttonLabel(palette.accentInteractive),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Top Summary Metrics Row (`Total Akun`, `Aktif`, `Ditangguhkan`)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Total Akun',
                    value: '$totalCount',
                    valueColor: palette.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    label: 'Aktif',
                    value: '$activeCount',
                    valueColor: palette.statusSuccess,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    label: 'Ditangguhkan',
                    value: '$suspendedCount',
                    valueColor: palette.statusDanger,
                  ),
                ),
              ],
            ),
          ),

          // Search Input (`Cari @username, email, atau UUID...`)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: AdoetzTypography.chatBody(palette.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Cari @username, email, atau UUID...',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: palette.textSecondary,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ),

          // Filter Chips (`Semua`, `User`, `Admin`, `Suspended`)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: ['Semua', 'User', 'Admin', 'Suspended'].map((chip) {
                final selected = _selectedFilter == chip;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(chip),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedFilter = chip),
                  ),
                );
              }).toList(),
            ),
          ),

          Divider(height: 0.5, color: palette.borderHairline),

          // Paginated User List (25 rows/page)
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (context, index) => Divider(
                height: 0.5,
                color: palette.borderHairline,
              ),
              itemBuilder: (context, index) {
                final user = filtered[index];
                final isSuspended = user.accountStatus == 'suspended';
                final badgeColor = isSuspended
                    ? palette.statusDanger
                    : palette.statusSuccess;
                final badgeLabel =
                    user.accountStatus.toUpperCase(); // ACTIVE or SUSPENDED

                return ListTile(
                  tileColor: palette.bgSurface,
                  onTap: () => context.push('/admin/user/${user.userId}'),
                  title: Row(
                    children: [
                      Text(
                        '@${user.username}',
                        style: AdoetzTypography.listTitle(
                          palette.textPrimary,
                          unread: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (user.role == 'admin')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: palette.accentSubtle,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ADMIN',
                            style: AdoetzTypography.captionTime(
                              palette.accentInteractive,
                              bold: true,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    '${user.email} • Daftar: ${DateFormat("dd/MM/yyyy").format(user.createdAt)}',
                    style: AdoetzTypography.captionTime(palette.textSecondary),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: badgeColor),
                    ),
                    child: Text(
                      badgeLabel,
                      style: AdoetzTypography.captionTime(
                        badgeColor,
                        bold: true,
                      ),
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

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AdoetzPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AdoetzTypography.captionTime(palette.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// UI-23: Admin User Detail & Privileged Actions (Section 6.4)
/// Every action opens a confirmation dialog + mandatory `Alasan Tindakan` input for Audit Log.
/// Force Password Reset generates a one-time temporary password shown ONLY once in modal!
class AdminUserDetailScreen extends ConsumerWidget {
  final String userId;

  const AdminUserDetailScreen({
    super.key,
    required this.userId,
  });

  void _promptPrivilegedAction({
    required BuildContext context,
    required WidgetRef ref,
    required ContactDirectoryEntry target,
    required String actionCode,
    required String actionTitle,
    required bool requiresAdminStepUpPassword,
  }) {
    final reasonController = TextEditingController();
    final stepUpPwdController = TextEditingController();
    String? errorMsg;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        final palette = AdoetzPalette.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              title: Text(actionTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target: @${target.username} (${target.userId})',
                      style: AdoetzTypography.captionTime(
                        palette.accentInteractive,
                        bold: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('admin_action_reason_field'),
                      controller: reasonController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Alasan Tindakan (Wajib untuk Audit Log)',
                        hintText: 'Contoh: Pelanggaran kebijakan keamanan...',
                      ),
                    ),
                    if (requiresAdminStepUpPassword) ...[
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('admin_step_up_password_field'),
                        controller: stepUpPwdController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Konfirmasi Password Admin (Step-Up Auth)',
                        ),
                      ),
                    ],
                    if (errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMsg!,
                        style: AdoetzTypography.captionTime(
                          palette.statusDanger,
                          bold: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  key: const Key('admin_confirm_action_btn'),
                  onPressed: () async {
                    final res = await ref
                        .read(appControllerProvider.notifier)
                        .adminExecuteAction(
                          targetUserId: target.userId,
                          action: actionCode,
                          reason: reasonController.text,
                          adminPasswordConfirmation: stepUpPwdController.text,
                        );
                    if (!res.ok) {
                      setModalState(() => errorMsg = res.error);
                      return;
                    }
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();

                    // If Force Password Reset, display one-time password modal ONCE!
                    if (res.oneTimePassword != null && context.mounted) {
                      _showOneTimePasswordModal(
                        context,
                        target.username,
                        res.oneTimePassword!,
                      );
                    } else if (actionCode == 'HARD_DELETE' && context.mounted) {
                      context.pop();
                    }
                  },
                  child: const Text('Eksekusi & Catat Audit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Displays the generated one-time temporary password ONLY ONCE in the Admin Modal (UI-23).
  void _showOneTimePasswordModal(
    BuildContext context,
    String username,
    String oneTimePassword,
  ) {
    final palette = AdoetzPalette.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Password Sementara Satu-Kali-Pakai'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Berikan password sementara ini kepada @$username melalui jalur terverifikasi (out-of-band). Password ini HANYA ditampilkan sekali dan TIDAK dicatat ke dalam Audit Log.',
                style: AdoetzTypography.listSubtitle(palette.textSecondary),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.bgCanvas,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.accentPrimary),
                ),
                child: SelectableText(
                  oneTimePassword,
                  textAlign: TextAlign.center,
                  style: AdoetzTypography.monoKey(palette.accentInteractive),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Catatan: Reset password tidak memulihkan riwayat chat E2EE lama pengguna.',
                style: AdoetzTypography.captionTime(palette.statusWarning),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Salin Password'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: oneTimePassword));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password sementara disalin ke clipboard'),
                  ),
                );
              },
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Selesai & Tutup'),
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
    final idx = appState.directory.indexWhere((u) => u.userId == userId);

    if (idx < 0) {
      return Scaffold(
        backgroundColor: palette.bgCanvas,
        appBar: AppBar(title: const Text('Detail Pengguna')),
        body: const Center(child: Text('Pengguna telah dihapus atau tidak ditemukan.')),
      );
    }

    final user = appState.directory[idx];
    final isSuspended = user.accountStatus == 'suspended';

    return Scaffold(
      backgroundColor: palette.bgCanvas,
      appBar: AppBar(
        title: Text('Kelola @${user.username}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Zero-Knowledge E2EE Notice Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.bgElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.borderHairline),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 18, color: palette.statusSuccess),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Isolasi Kriptografis E2EE: Administrator hanya melihat metadata akun dan tidak pernah memiliki akses ke isi pesan maupun kunci privat.',
                    style: AdoetzTypography.captionTime(palette.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Metadata Card
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
                Text(
                  user.displayName,
                  style: AdoetzTypography.screenTitle(palette.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${user.username} • ${user.email}',
                  style: AdoetzTypography.listSubtitle(palette.accentInteractive),
                ),
                const SizedBox(height: 12),
                Text(
                  'UUID: ${user.userId}\nRole: ${user.role.toUpperCase()}\nStatus: ${user.accountStatus.toUpperCase()}\nTerdaftar: ${DateFormat("dd MMM yyyy, HH:mm").format(user.createdAt)}',
                  style: AdoetzTypography.monoKey(palette.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'TINDAKAN TEROTENTIKASI (WAJIB ALASAN AUDIT LOG)',
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
                // 1. Suspend / Unsuspend
                ListTile(
                  leading: Icon(
                    isSuspended
                        ? Icons.check_circle_outline
                        : Icons.pause_circle_outline,
                    color: isSuspended
                        ? palette.statusSuccess
                        : palette.statusWarning,
                  ),
                  title: Text(
                    isSuspended
                        ? 'Aktifkan Kembali Akun (Unsuspend)'
                        : 'Tangguhkan Akun (Suspend)',
                  ),
                  subtitle: const Text(
                    'Memutus akses RLS is_caller_active() & saluran Realtime seketika',
                  ),
                  onTap: () => _promptPrivilegedAction(
                    context: context,
                    ref: ref,
                    target: user,
                    actionCode: isSuspended ? 'UNSUSPEND' : 'SUSPEND',
                    actionTitle: isSuspended
                        ? 'Aktifkan Kembali @${user.username}'
                        : 'Tangguhkan @${user.username}',
                    requiresAdminStepUpPassword: false,
                  ),
                ),
                Divider(height: 0.5, color: palette.borderHairline),

                // 2. Revoke Sessions
                ListTile(
                  leading: Icon(
                    Icons.phonelink_off_outlined,
                    color: palette.textPrimary,
                  ),
                  title: const Text('Cabut Seluruh Sesi Login (Revoke Sessions)'),
                  subtitle: const Text(
                    'Mencabut token refresh & memaksa jabatan tangan perangkat baru',
                  ),
                  onTap: () => _promptPrivilegedAction(
                    context: context,
                    ref: ref,
                    target: user,
                    actionCode: 'REVOKE_SESSIONS',
                    actionTitle: 'Cabut Sesi Login @${user.username}',
                    requiresAdminStepUpPassword: false,
                  ),
                ),
                Divider(height: 0.5, color: palette.borderHairline),

                // 3. Force Password Reset
                ListTile(
                  key: const Key('admin_force_reset_pwd_tile'),
                  leading: Icon(
                    Icons.password_rounded,
                    color: palette.accentInteractive,
                  ),
                  title: const Text('Reset Password Paksa (Force Password Reset)'),
                  subtitle: const Text(
                    'Menghasilkan password sementara 1x-tampil (wajib re-auth Admin)',
                  ),
                  onTap: () => _promptPrivilegedAction(
                    context: context,
                    ref: ref,
                    target: user,
                    actionCode: 'FORCE_RESET_PASSWORD',
                    actionTitle: 'Force Password Reset @${user.username}',
                    requiresAdminStepUpPassword: true,
                  ),
                ),
                Divider(height: 0.5, color: palette.borderHairline),

                // 4. Change Role (User <-> Admin)
                ListTile(
                  leading: Icon(
                    Icons.security_rounded,
                    color: palette.textPrimary,
                  ),
                  title: Text(
                    user.role == 'admin'
                        ? 'Ubah Role ke User Biasa'
                        : 'Promosikan Role ke Admin',
                  ),
                  subtitle: const Text(
                    'Dilindungi step-up authentication & proteksi admin terakhir',
                  ),
                  onTap: () => _promptPrivilegedAction(
                    context: context,
                    ref: ref,
                    target: user,
                    actionCode: 'TOGGLE_ROLE',
                    actionTitle: 'Ubah Role @${user.username}',
                    requiresAdminStepUpPassword: true,
                  ),
                ),
                Divider(height: 0.5, color: palette.borderHairline),

                // 5. Soft / Hard Delete Account
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_outlined,
                    color: palette.statusDanger,
                  ),
                  title: Text(
                    'Hapus Akun (Soft / Hard Delete)',
                    style: TextStyle(color: palette.statusDanger),
                  ),
                  subtitle: const Text(
                    'Soft Delete (masa tenggang 7 hari) atau Hard Delete permanen',
                  ),
                  onTap: () => _promptPrivilegedAction(
                    context: context,
                    ref: ref,
                    target: user,
                    actionCode: 'SOFT_DELETE',
                    actionTitle: 'Soft Delete @${user.username} (Tenggang 7 Hari)',
                    requiresAdminStepUpPassword: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// UI-24: Admin Security & Audit Log Viewer (Section 6.4)
/// Append-only chronological list displaying `Waktu`, `Admin Pelaku`, `Aksi`, `Target Akun`, `Alasan`, and `Request ID`.
class AdminAuditLogScreen extends ConsumerWidget {
  const AdminAuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AdoetzPalette.of(context);
    final logs = ref.watch(appControllerProvider).adminAuditLogs;

    return Scaffold(
      backgroundColor: palette.bgCanvas,
      appBar: AppBar(
        title: const Text('Log Audit Keamanan (Append-Only)'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: logs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final entry = logs[index];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.bgSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.borderHairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.accentSubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        entry.action,
                        style: AdoetzTypography.monoKey(
                          palette.accentInteractive,
                        ),
                      ),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm:ss').format(entry.timestamp),
                      style: AdoetzTypography.captionTime(palette.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Admin Pelaku: @${entry.actorUsername}  →  Target Akun: @${entry.targetUsername}',
                  style: AdoetzTypography.listTitle(palette.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Alasan: "${entry.reason}"',
                  style: AdoetzTypography.listSubtitle(palette.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Request ID: ${entry.requestId}',
                  style: AdoetzTypography.monoKey(palette.textMuted),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
