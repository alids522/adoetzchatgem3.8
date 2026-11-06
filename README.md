# Adoetz Chat 2 (`com.adoetzchat2.chat`) — v2.0

Implementasi produksi lengkap sesuai **PRD & UI/UX Architecture Specification v2.0** untuk **Adoetz Chat 2 (`com.adoetzchat2.chat`)**.

## Ringkasan Arsitektur & Keputusan yang Dikunci (PRD v2.0)

- **Identitas Paket & Namespace:** `com.adoetzchat2.chat` (`minSdk = 29` Android 10, `targetSdk = 35` Android 15)
- **Deep Link Contract:** `adoetzchat2://chat/{conversation_id}`, `adoetzchat2://call/{call_id}`, `adoetzchat2://user/{username}`, dan `waclonegem3.8://`
- **Bahasa Desain UI/UX:** **Precision Neutral Messenger v2.0**
  - **Dark Mode (Default Charcoal):** Canvas `#0E1013`, Surface `#15181E`, Elevated `#1E232B`, Overlay `#272D37`, Outgoing Bubble `#1E3E5C`, Incoming Bubble `#1D222A`, Brand Accent `#3B82C4`
  - **Light Mode (Crisp Alabaster):** Canvas `#F6F7F9`, Surface `#FFFFFF`, Elevated `#EFF2F6`, Overlay `#E4E9F0`, Outgoing Bubble `#D8ECFF`, Incoming Bubble `#FFFFFF` (border `#E2E7EE`), Brand Accent `#1F5F99`
- **Protokol Kriptografi E2EE:**
  - **X3DH + Signal Double Ratchet:** Identity Key (`X25519` / `Ed25519`), Signed PreKey, 100 One-Time PreKeys (auto-replenish +80 saat `< 20`), ephemeral message key per pesan (*forward secrecy*).
  - **Enkripsi Lampiran File:** `AES-256-GCM` AEAD per berkas `.enc` disertai verifikasi hash `SHA-256`.
  - **Safety Number Verification (UI-13):** Iterated `SHA-512` menghasilkan **60 digit (12 blok × 5 digit)** dalam font `Roboto Mono` (`13sp`) + QR Code.
- **Penyimpanan Lokal Terenkripsi:**
  - **SQLCipher (`adoetz_vault.db`)** yang kuncinya dibungkus oleh **Android Hardware-backed Keystore (`com.adoetzchat2.chat.master_key`)**.
  - **100% Pencarian Lokal FTS5 (`messages_fts`)** dan antrean `outbox_queue` idempoten pada `(sender_id, client_message_id)` dengan *exponential backoff* (`1s, 2s, 4s, 8s...`).
  - `android:allowBackup="false"` dan `android:fullBackupContent="false"` di `AndroidManifest.xml`.
- **Backend Supabase (`https://supabase.adoetz52.my.id`, schema `waclonegem3.8` / `public`):**
  - Migrasi SQL lengkap di `supabase/migrations/20261106000000_adoetz_chat_v2_schema.sql` dengan Trigger pendaftaran atomik `private.handle_new_user_signup()` (`SECURITY DEFINER`) dan fungsi RLS `public.is_caller_active()`.
  - 8 Deno Edge Functions di `supabase/functions/`:
    1. `auth-login-identifier`
    2. `check-username`
    3. `register-device-key`
    4. `claim-prekey-bundle`
    5. `send-encrypted-message`
    6. `issue-attachment-grant`
    7. `call-signaling`
    8. `admin-manage-user`
- **CI/CD GitHub Actions (`.github/workflows/release-android.yml`):**
  - Tahap 1: Secret scan, `flutter analyze --fatal-infos`, dan `flutter test`
  - Tahap 2: Keystore injection (`UPLOAD_KEYSTORE_BASE64`) & `--dart-define`
  - Tahap 3: Build APK Split-per-ABI, Universal APK (`com.adoetzchat2.chat-v2.0.0.apk`), AAB, `SHA256SUMS.txt`, dan publikasi otomatis ke **GitHub Releases**.
