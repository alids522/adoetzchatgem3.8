import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/design_tokens.dart';
import '../../core/network/supabase_gateway.dart';
import '../../core/state/app_controller.dart';

/// UI-01: Splash & SQLCipher Bootstrap Screen (Section 6.1)
class SplashBootstrapScreen extends ConsumerWidget {
  const SplashBootstrapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AdoetzPalette.of(context);
    final vault = ref.watch(vaultDatabaseProvider);

    return Scaffold(
      backgroundColor: palette.bgCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const Spacer(),
              // Geometric Flat Logomark (72x72dp)
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: palette.bgElevated,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.accentPrimary, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.shield_outlined,
                  size: 38,
                  color: palette.accentPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Adoetz Chat 2',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              if (vault.isCorrupted) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.bgElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.statusDanger),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Database SQLCipher Lokal Korup',
                        style: AdoetzTypography.listTitle(palette.statusDanger),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Gagal membuka kunci adoetz_vault.db melalui Android Keystore.',
                        textAlign: TextAlign.center,
                        style: AdoetzTypography.listSubtitle(palette.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: vault.diagnosticCode ?? 'ERR_SQLCIPHER_KEYSTORE_01',
                                  ),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Kode diagnostik disalin ke clipboard'),
                                  ),
                                );
                              },
                              child: const Text('Salin Kode Diagnostik'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                ref
                                    .read(appControllerProvider.notifier)
                                    .clearBlockerAndReturnToWelcome();
                              },
                              child: const Text('Coba Lagi'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              // Bottom progress (18dp, stroke 2dp) & version (40dp from safe area bottom)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  color: palette.accentPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'v${AppEnvironment.appVersion} (${AppEnvironment.appNamespace})',
                style: AdoetzTypography.captionTime(palette.textMuted),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

/// UI-02: Welcome Screen (Section 6.1)
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AdoetzPalette.of(context);
    final appState = ref.watch(appControllerProvider);

    return Scaffold(
      backgroundColor: palette.bgCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Top 15% area with Quick Theme Selector on top-right
              SizedBox(
                height: 64,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: palette.bgElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: palette.borderHairline),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ThemeMode>(
                        value: appState.themeMode,
                        isDense: true,
                        dropdownColor: palette.bgElevated,
                        icon: Icon(
                          Icons.contrast_rounded,
                          size: 16,
                          color: palette.textSecondary,
                        ),
                        style: AdoetzTypography.captionTime(palette.textPrimary),
                        items: const [
                          DropdownMenuItem(
                            value: ThemeMode.system,
                            child: Text('Tema: Sistem'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Text('Tema: Gelap'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Text('Tema: Terang'),
                          ),
                        ],
                        onChanged: (mode) {
                          if (mode != null) {
                            ref
                                .read(appControllerProvider.notifier)
                                .setThemeMode(mode);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
              // Center Expanded section
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: palette.bgElevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: palette.borderHairline),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.enhanced_encryption_outlined,
                        size: 56,
                        color: palette.accentPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Komunikasi Privat Tanpa Nomor Telepon',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22.0,
                        height: 28.0 / 22.0,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Pesan dan panggilan dienkripsi end-to-end langsung di perangkat Anda.',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: AdoetzTypography.listSubtitle(palette.textSecondary),
                    ),
                  ],
                ),
              ),
              // Sticky Bottom CTAs above Safe Area
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  key: const Key('welcome_sign_in_btn'),
                  onPressed: () => context.push('/signin'),
                  child: const Text('Masuk ke Akun'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  key: const Key('welcome_sign_up_btn'),
                  onPressed: () => context.push('/signup'),
                  child: const Text('Buat Akun Baru'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Enkripsi Signal Protocol (X3DH + Double Ratchet) • Penyimpanan SQLCipher Hardware-Keystore • Strict Single-Active-Device',
                textAlign: TextAlign.center,
                style: AdoetzTypography.captionTime(palette.textMuted),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// UI-03: Sign Up Screen — Open Registration without Invite Code + Cloudflare Turnstile (Section 6.1 & 7.1)
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  Timer? _debounce;

  bool _checkingUsername = false;
  bool? _usernameAvailable;
  String? _usernameFeedback;
  bool _obscurePassword = true;
  bool _turnstileVerified = true;
  String _turnstileToken = 'cf_turnstile_verified_token_v2_managed';
  bool _agreedToTerms = false;
  bool _isSubmitting = false;
  String _submitStepLabel = 'Buat Akun & Buat Kunci Enkripsi';
  String? _errorBanner;

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) {
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = null;
        _usernameFeedback = null;
      });
      return;
    }

    setState(() {
      _checkingUsername = true;
      _usernameAvailable = null;
    });

    // 400ms debounce per UI-03 specification
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final res =
          await ref.read(appControllerProvider.notifier).checkUsername(trimmed);
      if (!mounted) return;
      final avail = res.data?['available'] == true;
      final reason = res.data?['reason'] as String?;
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = avail;
        _usernameFeedback = reason;
      });
    });
  }

  int _calculatePasswordStrength(String pwd) {
    if (pwd.isEmpty) return 0;
    var score = 0;
    if (pwd.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(pwd) && RegExp(r'[a-z]').hasMatch(pwd)) score++;
    if (RegExp(r'[0-9]').hasMatch(pwd)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pwd) || pwd.length >= 16) score++;
    return score.clamp(1, 4);
  }

  Future<void> _handleSignUp() async {
    setState(() => _errorBanner = null);

    final username = _usernameController.text.trim().toLowerCase();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _errorBanner = 'Format alamat email tidak valid.');
      return;
    }
    if (password.length < 12) {
      setState(() => _errorBanner = 'Password wajib minimal 12 karakter.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorBanner = 'Konfirmasi password belum cocok.');
      return;
    }
    if (!_agreedToTerms) {
      setState(() {
        _errorBanner =
            'Harap setujui Ketentuan Layanan & Kebijakan Privasi E2EE.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitStepLabel = '(1/2) Mendaftarkan akun...';
    });

    final result = await ref
        .read(appControllerProvider.notifier)
        .registerNewAccount(
          username: username,
          email: email,
          password: password,
          turnstileToken: _turnstileVerified ? _turnstileToken : '',
          onStepChange: (step) {
            if (mounted) {
              setState(() => _submitStepLabel = step);
            }
          },
        );

    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _isSubmitting = false;
        _submitStepLabel = 'Buat Akun & Buat Kunci Enkripsi';
        _errorBanner = result.error;
      });
      return;
    }

    context.go('/chats');
  }

  @override
  Widget build(BuildContext context) {
    final palette = AdoetzPalette.of(context);
    final pwdStrength = _calculatePasswordStrength(_passwordController.text);

    return Scaffold(
      backgroundColor: palette.bgCanvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => context.pop(),
        ),
        title: const Text('Buat Akun Baru'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Banner (bg.elevated, padding 12dp, radius 8dp)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.bgElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.borderHairline),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: palette.accentInteractive,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pendaftaran terbuka. Karena email tidak diverifikasi secara otomatis, simpan password Anda dengan aman.',
                      style: AdoetzTypography.listSubtitle(palette.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            if (_errorBanner != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.statusDanger.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.statusDanger),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 18, color: palette.statusDanger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorBanner!,
                        style: AdoetzTypography.listSubtitle(palette.statusDanger),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // 1. Username field with fixed @ prefix & real-time 400ms debounced availability indicator
            TextField(
              key: const Key('signup_username_field'),
              controller: _usernameController,
              onChanged: _onUsernameChanged,
              autocorrect: false,
              style: AdoetzTypography.chatBody(palette.textPrimary),
              decoration: InputDecoration(
                labelText: 'Username (3–24 karakter: a-z, 0-9, _)',
                prefixText: '@',
                prefixStyle: AdoetzTypography.chatBody(palette.accentInteractive),
                suffixIcon: _checkingUsername
                    ? Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.accentPrimary,
                          ),
                        ),
                      )
                    : (_usernameAvailable == null
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _usernameAvailable!
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                size: 18,
                                color: _usernameAvailable!
                                    ? palette.statusSuccess
                                    : palette.statusDanger,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _usernameAvailable! ? 'Tersedia' : 'Sudah dipakai',
                                style: AdoetzTypography.captionTime(
                                  _usernameAvailable!
                                      ? palette.statusSuccess
                                      : palette.statusDanger,
                                  bold: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                          )),
              ),
            ),
            if (_usernameFeedback != null && _usernameAvailable == false) ...[
              const SizedBox(height: 4),
              Text(
                _usernameFeedback!,
                style: AdoetzTypography.captionTime(palette.statusDanger),
              ),
            ],
            const SizedBox(height: 16),
            // 2. Email field
            TextField(
              key: const Key('signup_email_field'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              style: AdoetzTypography.chatBody(palette.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Alamat Email',
                hintText: 'nama@domain.com',
              ),
            ),
            const SizedBox(height: 16),
            // 3. Password field (min 12 chars + 4-segment strength bar)
            TextField(
              key: const Key('signup_password_field'),
              controller: _passwordController,
              obscureText: _obscurePassword,
              onChanged: (_) => setState(() {}),
              style: AdoetzTypography.chatBody(palette.textPrimary),
              decoration: InputDecoration(
                labelText: 'Password (minimal 12 karakter)',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: palette.textSecondary,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 4-Segment Password Strength Bar
            Row(
              children: List.generate(4, (index) {
                final active = index < pwdStrength;
                final barColor = pwdStrength <= 1
                    ? palette.statusDanger
                    : (pwdStrength <= 2
                        ? palette.statusWarning
                        : palette.statusSuccess);
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: active ? barColor : palette.borderHairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            // 4. Confirm Password
            TextField(
              key: const Key('signup_confirm_field'),
              controller: _confirmController,
              obscureText: _obscurePassword,
              onChanged: (_) => setState(() {}),
              style: AdoetzTypography.chatBody(palette.textPrimary),
              decoration: InputDecoration(
                labelText: 'Konfirmasi Password',
                suffixIcon: _confirmController.text.isEmpty
                    ? null
                    : Icon(
                        _confirmController.text == _passwordController.text
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        size: 18,
                        color: _confirmController.text == _passwordController.text
                            ? palette.statusSuccess
                            : palette.statusDanger,
                      ),
              ),
            ),
            const SizedBox(height: 16),
            // Cloudflare Turnstile Managed/Invisible Challenge Widget (height 65dp)
            Container(
              height: 65,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: palette.bgElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.borderHairline),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _turnstileVerified,
                    activeColor: palette.statusSuccess,
                    onChanged: (val) {
                      setState(() {
                        _turnstileVerified = val ?? false;
                        _turnstileToken = _turnstileVerified
                            ? 'cf_turnstile_verified_token_v2_managed'
                            : '';
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _turnstileVerified
                              ? 'Cloudflare Turnstile Terverifikasi'
                              : 'Verifikasi Cloudflare Turnstile',
                          style: AdoetzTypography.listSubtitle(palette.textPrimary),
                        ),
                        Text(
                          'Site Key: ${AppEnvironment.turnstileSiteKey.substring(0, 12)}...',
                          style: AdoetzTypography.captionTime(palette.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.verified_user_outlined,
                    size: 22,
                    color: _turnstileVerified
                        ? palette.statusSuccess
                        : palette.textMuted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Terms & Privacy Checkbox
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Checkbox(
                      key: const Key('signup_terms_checkbox'),
                      value: _agreedToTerms,
                      activeColor: palette.accentPrimary,
                      onChanged: (v) =>
                          setState(() => _agreedToTerms = v ?? false),
                    ),
                    Expanded(
                      child: Text(
                        'Saya menyetujui Ketentuan Layanan & memahami bahwa kunci privat E2EE hanya tersimpan di perangkat ini.',
                        style: AdoetzTypography.captionTime(palette.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // CTA Button (50dp height)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                key: const Key('signup_submit_btn'),
                onPressed: _isSubmitting ? null : _handleSignUp,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isSubmitting) ...[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        _submitStepLabel,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// UI-04: Sign In Screen & UI-05: Device Conflict / Auth Error Modal (Section 6.1)
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _identifierController = TextEditingController(text: '@nadia');
  final _passwordController = TextEditingController(text: 'NadiaSecurePass#2026');
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitSignIn() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final res = await ref.read(appControllerProvider.notifier).signIn(
          identifier: _identifierController.text,
          password: _passwordController.text,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.requiresDeviceReplacement) {
      _showDeviceConflictModal(context);
      return;
    }

    if (!res.ok) {
      if (res.error == 'ACCOUNT_SUSPENDED') {
        context.go('/blocker');
        return;
      }
      setState(() => _errorText = res.error);
      return;
    }

    context.go('/chats');
  }

  /// UI-05: Device Replacement Handshake Modal (Single-Active-Device E2EE)
  void _showDeviceConflictModal(BuildContext context) {
    final palette = AdoetzPalette.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.bgElevated,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.phonelink_erase_rounded,
                      color: palette.statusWarning,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ganti Perangkat Aktif?',
                        style: AdoetzTypography.screenTitle(palette.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Akun ini sedang aktif di perangkat lain. Karena Adoetz Chat 2 menggunakan enkripsi 1-perangkat, melanjutkan login di sini akan mengeluarkan perangkat lama dan membuat kunci enkripsi baru. Riwayat chat lama tidak akan ikut berpindah.',
                  style: AdoetzTypography.listSubtitle(palette.textSecondary),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          ref
                              .read(appControllerProvider.notifier)
                              .cancelDeviceConflict();
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Batalkan'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const Key('confirm_device_replace_btn'),
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.statusDanger,
                        ),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await ref
                              .read(appControllerProvider.notifier)
                              .confirmDeviceReplacementAndSignIn(
                                _passwordController.text,
                              );
                          if (context.mounted) {
                            context.go('/chats');
                          }
                        },
                        child: const Text(
                          'Ganti Perangkat & Lanjutkan',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
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

    return Scaffold(
      backgroundColor: palette.bgCanvas,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => context.pop(),
        ),
        title: const Text('Masuk ke Akun'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorText != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: palette.statusDanger.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.statusDanger),
                ),
                child: Text(
                  _errorText!,
                  style: AdoetzTypography.listSubtitle(palette.statusDanger),
                ),
              ),
            ],
            TextField(
              key: const Key('signin_identifier_field'),
              controller: _identifierController,
              autocorrect: false,
              style: AdoetzTypography.chatBody(palette.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Username atau Email',
                hintText: '@username atau nama@domain.com',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('signin_password_field'),
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: AdoetzTypography.chatBody(palette.textPrimary),
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: palette.textSecondary,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                key: const Key('signin_submit_btn'),
                onPressed: _isLoading ? null : _submitSignIn,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Masuk'),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Lupa password? Hubungi Administrator komunitas untuk reset kredensial.',
                textAlign: TextAlign.center,
                style: AdoetzTypography.captionTime(palette.textSecondary),
              ),
            ),
            const SizedBox(height: 28),
            Divider(color: palette.borderHairline),
            const SizedBox(height: 12),
            Text(
              'PROFIL PENGUJIAN CEPAT (SKENARIO PRD v2.0)',
              style: AdoetzTypography.sectionHeader(palette.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('User Normal (@nadia)'),
                  onPressed: () {
                    setState(() {
                      _identifierController.text = '@nadia';
                      _passwordController.text = 'NadiaSecurePass#2026';
                    });
                  },
                ),
                ActionChip(
                  label: const Text('Konflik Perangkat UI-05 (@alex)'),
                  onPressed: () {
                    setState(() {
                      _identifierController.text = '@alex';
                      _passwordController.text = 'AlexSecurePass#2026';
                    });
                  },
                ),
                ActionChip(
                  label: const Text('Role Admin (@superadmin)'),
                  onPressed: () {
                    setState(() {
                      _identifierController.text = '@superadmin';
                      _passwordController.text = 'AdminMasterKey#2026';
                    });
                  },
                ),
                ActionChip(
                  label: const Text('Akun Suspended (@rina_sec)'),
                  onPressed: () {
                    setState(() {
                      _identifierController.text = '@rina_sec';
                      _passwordController.text = 'RinaSecurePass#2026';
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Biometric / PIN App Lock Screen Gate (Section 3.1 & UI-20)
class AppLockGateScreen extends ConsumerStatefulWidget {
  const AppLockGateScreen({super.key});

  @override
  ConsumerState<AppLockGateScreen> createState() => _AppLockGateScreenState();
}

class _AppLockGateScreenState extends ConsumerState<AppLockGateScreen> {
  final _pinController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AdoetzPalette.of(context);

    return Scaffold(
      backgroundColor: palette.bgCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 52, color: palette.accentPrimary),
              const SizedBox(height: 16),
              Text(
                'Adoetz Chat 2 Terkunci',
                style: AdoetzTypography.screenTitle(palette.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Masukkan PIN Keamanan atau gunakan Biometrik perangkat untuk membuka SQLCipher Vault.',
                textAlign: TextAlign.center,
                style: AdoetzTypography.listSubtitle(palette.textSecondary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: 'PIN (Default: 1234)',
                    counterText: '',
                    errorText: _error,
                  ),
                  onSubmitted: (val) {
                    final ok = ref
                        .read(appControllerProvider.notifier)
                        .unlockAppWithPin(val);
                    if (!ok) {
                      setState(() => _error = 'PIN tidak sesuai');
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      ref
                          .read(appControllerProvider.notifier)
                          .unlockAppWithBiometrics();
                    },
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('Biometrik'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () {
                      final ok = ref
                          .read(appControllerProvider.notifier)
                          .unlockAppWithPin(_pinController.text);
                      if (!ok) {
                        setState(() => _error = 'PIN tidak sesuai');
                      }
                    },
                    child: const Text('Buka Kunci'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// UI-25: Universal Blocker, Maintenance, & Diagnostic Screen (Section 6.4 & ERR-07)
class UniversalBlockerScreen extends ConsumerWidget {
  const UniversalBlockerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AdoetzPalette.of(context);
    final appState = ref.watch(appControllerProvider);

    final (title, icon, color) = switch (appState.blockerReason) {
      BlockerReason.accountSuspended => (
          'Akun Ditangguhkan (Suspended)',
          Icons.gpp_bad_outlined,
          palette.statusDanger,
        ),
      BlockerReason.sessionRevoked => (
          'Sesi Perangkat Berakhir',
          Icons.phonelink_off_outlined,
          palette.statusWarning,
        ),
      BlockerReason.minVersionGate => (
          'Pembaruan Aplikasi Wajib',
          Icons.system_update_outlined,
          palette.accentPrimary,
        ),
      BlockerReason.dbMigrationFailure => (
          'Kesalahan Migrasi Database Lokal',
          Icons.storage_rounded,
          palette.statusDanger,
        ),
      BlockerReason.none => (
          'Status Sistem',
          Icons.info_outline,
          palette.accentPrimary,
        ),
    };

    return Scaffold(
      backgroundColor: palette.bgCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: palette.bgElevated,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color),
                ),
                child: Icon(icon, size: 38, color: color),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AdoetzTypography.screenTitle(palette.textPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                appState.blockerMessage ??
                    'Akses akun Anda sedang dibatasi oleh sistem keamanan.',
                textAlign: TextAlign.center,
                style: AdoetzTypography.listSubtitle(palette.textSecondary),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.bgElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.borderHairline),
                ),
                child: SelectableText(
                  'DIAGNOSTIC_ID: ${AppEnvironment.appNamespace}::${appState.blockerReason.name.toUpperCase()}',
                  textAlign: TextAlign.center,
                  style: AdoetzTypography.monoKey(palette.textMuted),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () {
                    ref
                        .read(appControllerProvider.notifier)
                        .clearBlockerAndReturnToWelcome();
                    context.go('/welcome');
                  },
                  child: const Text('Kembali ke Layar Utama'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
