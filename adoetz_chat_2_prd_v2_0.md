# ADOETZ CHAT 2
## Product Requirements Document (PRD) & UI/UX Architecture Specification — v2.0

**Nama Produk:** Adoetz Chat 2  
**Android Application ID / Namespace:** `com.adoetzchat2.chat`  
**Deep Link Scheme:** `adoetzchat2://` & App Links HTTPS  
**Platform Utama:** Android (Flutter Stable + Rust/Native FFI untuk Kriptografi)  
**Minimum SDK Target:** Android 10 (API Level 29) — Target SDK: Android 15 (API Level 35)  
**Backend:** Supabase Managed (Auth, PostgreSQL 15+, Realtime Broadcast/Presence, Private Storage, Deno Edge Functions)  
**Notifikasi & Panggilan Latar:** Firebase Cloud Messaging (FCM HTTP v1) + Android `ConnectionService` / `Notification.CallStyle`  
**Infrastruktur Real-Time Media:** WebRTC (DTLS-SRTP) + Managed Coturn (STUN/TURN dengan kredensial HMAC ephemeral)  
**Distribusi:** Private Signed APK & AAB melalui GitHub Actions CI/CD & GitHub Releases  
**Bahasa Desain UI/UX:** **Precision Neutral Messenger v2.0** — *Matte Charcoal Dark & Crisp Alabaster Light, Muted Steel-Blue Accents, Zero-AI-Clutter*  
**Status Dokumen:** Blueprint Engineering & Desain Final (Siap Eksekusi)  
**Tanggal Revisi:** 6 November 2026  

---

# 0. Analisis Kritis PRD v1.2 & Perombakan Arsitektur ke v2.0

Sebelum masuk ke spesifikasi utama, berikut adalah hasil audit terhadap PRD v1.2 beserta perombakan fundamental yang diterapkan pada **v2.0 (`com.adoetzchat2.chat`)**:

1. **Eliminasi *Split-State* saat Registrasi (Perbaikan ERR-38 v1.2):**
   * *Masalah di v1.2:* Pembuatan akun di `auth.users` dan pembuatan baris di `profiles` / `user_roles` dilakukan terpisah via Edge Function setelah signup, sehingga berisiko melahirkan akun "setengah jadi" jika jaringan putus di tengah jalan.
   * *Solusi v2.0:* Menggunakan **PostgreSQL Trigger `AFTER INSERT ON auth.users` (`SECURITY DEFINER`)** yang secara atomik memvalidasi format username dari metadata awal, membuat baris di `public.profiles`, `public.user_roles` (terkunci ke `'user'`), `public.account_status`, dan `public.user_preferences` dalam satu transaksi database. Jika username tabrakan atau tidak valid, seluruh transaksi `auth.users` dibatalkan (*rolled back*).
2. **Keputusan Tegas atas "Open Decisions" (Tidak Ada Lagi Ambiguitas):**
   * *Masalah di v1.2:* Terlalu banyak label `PROPOSED` dan `OPEN DECISION` (seperti kebijakan sesi multi-device vs single-device E2EE, pilihan library kriptografi, dan mekanisme anti-bot).
   * *Solusi v2.0:* Seluruh keputusan kritis kini berstatus **LOCKED**. Versi 2.0 menerapkan **Strict Single-Active-Device** (satu sesi aktif + satu identitas E2EE per akun). Login di perangkat baru wajib melewati layar **Device Replacement Handshake** yang mencabut sesi perangkat lama dan merotasi Identity Key secara eksplisit.
3. **Transformasi Spesifikasi UI/UX Menjadi *Pixel-Level Blueprint*:**
   * *Masalah di v1.2:* Aturan desain hanya berupa panduan filosofis dan tabel 1 baris per layar tanpa ukuran pasti, anatomi komponen, proporsi *padding/margin*, atau perilaku *viewport* saat keyboard muncul.
   * *Solusi v2.0:* Menyediakan **Anatomi Layout Presisi** (ukuran dalam `dp`/`sp`, kurva animasi, *state machine* untuk *chat composer*, *voice note recorder*, dan *call overlay*), serta blueprint struktural lengkap untuk seluruh 25 layar.
4. **Identitas Paket & Namespace Baru (`com.adoetzchat2.chat`):**
   * Seluruh konfigurasi *build*, *deep linking*, izin sistem Android (`AndroidManifest.xml`), *signing config*, dan saluran notifikasi FCM diselaraskan secara eksklusif ke `com.adoetzchat2.chat`.

---

# 1. Ringkasan Eksekutif & Keputusan Produk yang Dikunci

**Adoetz Chat 2 (`com.adoetzchat2.chat`)** adalah aplikasi pesan instan privat *Android-first* berbasis Flutter yang mengutamakan **kecepatan interaksi lokal, ketahanan sinkronisasi saat koneksi buruk (*offline-first*), kepastian enkripsi *end-to-end* (E2EE), dan ergonomi antarmuka sekelas aplikasi pesan profesional matang**.

Pengguna mendaftar secara terbuka (*open registration*) hanya dengan **username, email, dan password** tanpa kode undangan dan tanpa hambatan verifikasi email wajib, namun dilindungi secara ketat di sisi server dengan **Cloudflare Turnstile (invisible/managed challenge)** dan *rate-limiting* berlapis. Setiap akun baru otomatis terkunci pada role `user`. Admin memiliki panel utilitas di dalam aplikasi untuk menangguhkan akun (*suspend*), mereset password paksa (*force reset*), mencabut sesi, dan menghapus pengguna tanpa pernah bisa membaca isi percakapan maupun kunci privat E2EE.

## 1.1 Matriks Keputusan Arsitektur (LOCKED untuk v2.0)

| Domain | Keputusan Final v2.0 (`com.adoetzchat2.chat`) | Status |
|---|---|---|
| **Identitas Paket** | Application ID, Gradle Namespace, dan FCM Package dikunci pada `com.adoetzchat2.chat`. | **LOCKED** |
| **Alur Pendaftaran** | Open registration tanpa *invite code* & tanpa konfirmasi email wajib. Dilindungi Cloudflare Turnstile pada Supabase Auth + Database Trigger atomik. | **LOCKED** |
| **Model Perangkat** | **Strict Single-Active-Device (1 Akun = 1 Perangkat Aktif)**. Login di HP baru memicu pencabutan sesi HP lama + rotasi Identity Key E2EE. | **LOCKED** |
| **Protokol E2EE** | Implementasi berbasis **Signal Protocol (X3DH + Double Ratchet)** untuk teks/kontrol & **XChaCha20-Poly1305 / AES-256-GCM** untuk lampiran file. | **LOCKED** |
| **Penyimpanan Lokal** | Database lokal terenkripsi penuh dengan **SQLCipher (Drift + `sqlcipher_flutter_libs`)**. Kunci database dibungkus di **Android Keystore (Hardware-backed AES-256)**. | **LOCKED** |
| **Pencarian Pesan** | 100% dilakukan di perangkat lokal menggunakan indeks FTS5 di dalam SQLCipher. Server sama sekali tidak memiliki fitur *search message*. | **LOCKED** |
| **Pemulihan Password** | Karena email tidak diverifikasi saat daftar, lupa password hanya dapat diatasi melalui **Admin Force-Reset** (prosedur *out-of-band*) dan **tidak** memulihkan riwayat chat lama. | **LOCKED** |
| **Estetika UI/UX** | **Precision Neutral Messenger**: Charcoal Dark (`#0E1013`) & Crisp Light (`#F6F7F9`), aksen Steel Blue (`#2B6CB0` / `#4A90D9`). Bebas neon, *glow*, dan *glassmorphism*. | **LOCKED** |

---

# 2. Target Kinerja (SLA Internal), Batasan, & Matriks Perizinan (RBAC)

## 2.1 Sasaran Kinerja Terukur (Acceptance Targets)

| Kode | Metrik Kinerja & Keandalan | Target Uji Penerimaan |
|---|---|---|
| **OBJ-01** | Keberhasilan registrasi atomik (input valid) | $\ge 99.5\%$ tanpa *orphan row* antara `auth.users` dan `public.profiles` |
| **OBJ-02** | Latensi respons interaksi UI lokal (buka chat, ketik, *scroll*) | $\text{p95} < 16\text{ ms}$ (*frame render* $60\text{ fps}$ stabil) dan $< 100\text{ ms}$ transisi halaman |
| **OBJ-03** | *Cold start* ke daftar percakapan ter-cache (*warm SQLCipher*) | $\text{p95} < 1.2\text{ detik}$ pada perangkat Android kelas menengah (RAM $4\text{ GB}$) |
| **OBJ-04** | Latensi pengiriman pesan *end-to-end* (kedua perangkat online) | $\text{p95} < 1.5\text{ detik}$ dari ketuk *Send* hingga status `delivered` |
| **OBJ-05** | Kehilangan atau duplikasi pesan saat jaringan putus-nyambung | $0$ pesan hilang dan $0$ duplikasi berkat `client_message_id` idempoten |
| **OBJ-06** | Kebocoran *plaintext* ke server / log / FCM | $0\text{ byte}$ *plaintext* pesan/lampiran/kunci privat di luar perangkat |
| **OBJ-07** | Keamanan otorisasi & isolasi data antar-pengguna (RLS) | $100\%$ pengujian penetrasi *direct REST/Realtime API* ditolak server |
| **OBJ-08** | Stabilitas sesi & keberhasilan pembaruan APK | *Crash-free sessions* $\ge 99.6\%$; *upgrade* APK $N \rightarrow N+1$ mulus $100\%$ |

## 2.2 Matriks Role-Based Access Control (RBAC)

Sistem hanya mengenal dua role aplikasi (`user` dan `admin`) yang disimpan di tabel terproteksi `public.user_roles` dan disinkronkan ke klaim JWT `app_metadata.role` (bukan `user_metadata` yang dapat dimodifikasi klien).

| Operasi / Kapabilitas | Tamu (Unauthenticated) | Role: `user` | Role: `admin` | Service Worker / DB Trigger |
|---|---|---|---|---|
| Registrasi akun baru (`user` default) | Diizinkan (dengan Turnstile) | Tidak relevan | Tidak relevan | Menetapkan role `'user'` secara atomik |
| Login dengan Username atau Email | Diizinkan (Rate-limited) | Diizinkan | Diizinkan | Memetakan username $\rightarrow$ email di sisi server |
| Mengubah profil sendiri (Nama, Bio, Avatar) | Ditolak | Diizinkan | Diizinkan | Validasi ukuran & sanitasi |
| Mencari pengguna berdasarkan `@username` | Ditolak | Diizinkan (Rate-limited) | Diizinkan | Membatasi enumerasi massal |
| Mengirim / menerima pesan & panggilan E2EE | Ditolak | Hanya partisipan aktif | Hanya partisipan aktif | Merutekan *ciphertext* tanpa akses baca |
| Membaca *plaintext* percakapan pengguna lain | Ditolak | **Ditolak Keras** | **Ditolak Keras (Mustahil secara Kriptografis)** | **Ditolak Keras** |
| Melihat daftar pengguna & status akun sistem | Ditolak | Ditolak | Diizinkan (Paginated) | Menjalankan query terotentikasi |
| *Suspend* / *Unsuspend* / *Revoke Session* akun lain | Ditolak | Ditolak | Diizinkan (Wajib alasan + Audit) | Menjalankan pencabutan sesi & blokir akses |
| *Force Password Reset* akun pengguna lain | Ditolak | Ditolak | Diizinkan (Wajib Re-auth Admin) | Mengatur ulang kredensial Auth & catat audit |
| Menghapus akun pengguna (*Soft / Hard Delete*) | Ditolak | Hanya akun sendiri | Diizinkan (Kecuali diri sendiri / admin terakhir) | Membersihkan objek *storage* & sesi |

---

# 3. Arsitektur Informasi (IA), Navigasi, & Kontrak Deep Link

## 3.1 Peta Navigasi Hirarkis

Aplikasi menggunakan pola **Single-Activity Architecture** dengan deklaratif router (`GoRouter`) dan *state guard* reaktif.

```text
[App Launch: com.adoetzchat2.chat]
 │
 ├─► UI-01 Splash & SQLCipher Bootstrap
 │    ├─► [Belum Login] ────────────► UI-02 Welcome
 │    │                                ├─► UI-03 Sign Up (Open Reg + Turnstile)
 │    │                                └─► UI-04 Sign In (Username/Email)
 │    │                                     └─► UI-05 Auth / Anti-Abuse / Device Conflict Modal
 │    ├─► [Sesi Dicabut / Suspended] ► UI-25 Universal Blocker (Suspended / Session Expired)
 │    ├─► [App Lock Aktif] ─────────► Biometric / PIN Lock Screen
 │    └─► [Sesi Valid & Kunci Siap] ─► UI-06 Contextual Onboarding Check ──► [Main Shell]
 │
 └─► [Main Shell: Bottom Navigation Bar (4 Tab Tetap)]
      │
      ├── TAB 1: CHATS (UI-07) [Default Landing]
      │    ├─► UI-08 Contact Search (FAB / Search Action)
      │    └─► UI-10 Chat Detail (1:1 E2EE Room)
      │         ├─► UI-11 Attachment Picker & Preview Sheet/Screen
      │         ├─► UI-12 Voice Note Recorder (Inline Composer State)
      │         ├─► UI-13 Chat Info, Media Grid & Safety Number Verification (QR)
      │         └─► UI-09 Contact Profile Sheet/Screen
      │
      ├── TAB 2: CALLS (UI-14)
      │    ├─► UI-15 Outgoing Call Screen
      │    ├─► UI-16 Incoming Call Screen (Full-Screen Lock / Heads-Up Overlay)
      │    └─► UI-17 Active Voice / Video Call Screen (+ Floating Mini-Call Pill saat Back)
      │
      ├── TAB 3: CONTACTS (UI-08 / Directory View)
      │    └─► UI-09 Contact Profile ──► Mulai Chat (UI-10) / Mulai Panggilan (UI-15)
      │
      └── TAB 4: SETTINGS (UI-18)
           ├─► UI-19 Appearance & Theme Preview
           ├─► UI-20 Privacy, App Lock & Security Preferences
           ├─► UI-21 My Account & Active Device Identity
           └─► [Hanya muncul jika role == 'admin']
                └─► UI-22 Admin Dashboard & User Directory
                     ├─► UI-23 Admin User Detail & Privileged Actions
                     └─► UI-24 Admin Security & Audit Log Viewer
```

## 3.2 Kontrak Deep Link (`com.adoetzchat2.chat`)

Semua *deep link* dan *notification intent* harus melewati **Auth & App-Lock Gate** sebelum merender layar tujuan:
- `adoetzchat2://chat/{conversation_id}`: Membuka `UI-10 Chat Detail` pada percakapan terkait. Jika percakapan tidak ditemukan di database lokal, lakukan *delta sync* terlebih dahulu; jika tetap tidak sah, arahkan ke `UI-07 Chats` dengan *snackbar* `"Percakapan tidak ditemukan"`.
- `adoetzchat2://call/{call_id}`: Membuka `UI-16 Incoming Call` atau `UI-17 Active Call` setelah memvalidasi bahwa `call_id` belum melampaui TTL.
- `adoetzchat2://user/{username}`: Membuka `UI-09 Contact Profile` untuk `@username`.

---

# 4. Sistem Desain UI/UX v2.0: "Precision Neutral Messenger"

Bagian ini mendefinisikan spesifikasi visual yang wajib dipatuhi oleh seluruh komponen Flutter. Tujuannya adalah menghadirkan antarmuka yang **tenang, padat informasi, berfokus pada keterbacaan teks, responsif seketika, dan bebas dari ornamen buatan AI** (tanpa gradien neon, tanpa kartu mengambang berlapis-lapis, tanpa *glow shadow*).

## 4.1 Palet Warna Semantik (Design Tokens)

Seluruh pasangan warna teks dan latar belakang di bawah ini telah dikalibrasi untuk melampaui standar kontras **WCAG 2.2 Level AA** ($\ge 4.5:1$ untuk teks normal dan $\ge 3.0:1$ untuk teks besar/komponen).

| Kategori | Nama Token | Dark Mode (Default Charcoal) | Light Mode (Crisp Alabaster) | Kegunaan Spesifik |
|---|---|---|---|---|
| **Background** | `bg.canvas` | `#0E1013` | `#F6F7F9` | Latar belakang utama layar & latar ruang chat |
| **Surface 1** | `bg.surface` | `#15181E` | `#FFFFFF` | App Bar, baris daftar chat, *bottom nav*, *settings group* |
| **Surface 2** | `bg.elevated` | `#1E232B` | `#EFF2F6` | *Search bar*, kolom input *composer*, *bottom sheet*, dialog |
| **Surface 3** | `bg.overlay` | `#272D37` | `#E4E9F0` | Menu *pop-up*, *chip* tanggal mengambang, *pressed state* |
| **Brand** | `accent.primary` | `#3B82C4` | `#1F5F99` | Tombol utama (CTA), ikon *Send*, *badge unread* |
| **Brand Text** | `accent.onPrimary` | `#FFFFFF` | `#FFFFFF` | Teks dan ikon di atas `accent.primary` |
| **Brand Link** | `accent.interactive` | `#6BA8E5` | `#1D5B94` | Tautan URL, teks tombol sekunder, indikator tab aktif |
| **Brand Tint** | `accent.subtle` | `#1A2B3C` | `#E3EFFA` | Sorotan baris chat yang sedang dipilih (*selected state*) |
| **Chat Bubble** | `bubble.incoming.bg` | `#1D222A` | `#FFFFFF` | Gelembung pesan masuk (pada Light Mode ditambah *border* `#E2E7EE`) |
| **Chat Bubble** | `bubble.incoming.text` | `#F1F5F9` | `#141920` | Teks pesan utama di dalam gelembung masuk |
| **Chat Bubble** | `bubble.outgoing.bg` | `#1E3E5C` | `#D8ECFF` | Gelembung pesan keluar (*muted steel blue*, nyaman di mata) |
| **Chat Bubble** | `bubble.outgoing.text` | `#F3F7FB` | `#102233` | Teks pesan utama di dalam gelembung keluar |
| **Chat Bubble** | `bubble.quote.bg` | `#142B40` / `#151920` | `#C5E1FC` / `#F2F4F7` | Kotak kutipan balasan (*reply box*) di dalam gelembung |
| **Typography** | `text.primary` | `#F1F5F9` | `#141920` | Judul halaman, nama kontak, isi pesan |
| **Typography** | `text.secondary` | `#94A0B0` | `#5A6573` | *Preview* pesan di daftar, *subtitle*, bio, *placeholder* |
| **Typography** | `text.muted` | `#687382` | `#7E8997` | *Timestamp* kecil, label seksi, teks *disabled* |
| **Border** | `border.hairline` | `#232933` | `#E3E8EF` | Garis pemisah (*divider*) $0.5\text{ dp}$–$1.0\text{ dp}$ |
| **Status** | `status.success` | `#48B884` | `#1E7E52` | Indikator terverifikasi, panggilan tersambung |
| **Status** | `status.warning` | `#E5A93B` | `#B2720E` | Banner jaringan lambat, perubahan kunci keamanan |
| **Status** | `status.danger` | `#EE6B6B` | `#C82323` | Pesan gagal kirim, tombol *End Call*, aksi hapus/blokir |
| **Receipts** | `tick.read` | `#64B5F6` | `#1976D2` | Ikon centang dua saat pesan telah dibaca (`read`) |

## 4.2 Skala Tipografi Presisi

Menggunakan rantai *font* sistem Android (**Roboto** / **Noto Sans**) agar menyatu sempurna dengan OS dan mendukung seluruh karakter Unicode/Emoji tanpa beban *bundle* tambahan.

| Token Tipografi | Ukuran (`sp`) | Tinggi Baris (`sp`) | Bobot (*Weight*) | *Letter Spacing* | Penggunaan Utama |
|---|---|---|---|---|---|
| `type.screenTitle` | $20\text{ sp}$ | $26\text{ sp}$ | SemiBold ($600$) | $-0.01\text{ em}$ | Judul utama pada Top App Bar (`Chats`, `Settings`) |
| `type.sectionHeader` | $13\text{ sp}$ | $18\text{ sp}$ | SemiBold ($600$) | $+0.02\text{ em}$ | Sub-judul grup di Settings & Admin Panel |
| `type.listTitle` | $16\text{ sp}$ | $22\text{ sp}$ | Medium ($500$) | $0.00\text{ em}$ | Nama kontak di daftar chat (Menjadi Bold $600$ saat *unread*) |
| `type.chatBody` | $15.5\text{ sp}$ | $21.5\text{ sp}$ | Regular ($400$) | $0.00\text{ em}$ | Isi teks pesan di dalam gelembung chat & input *composer* |
| `type.listSubtitle` | $14\text{ sp}$ | $19\text{ sp}$ | Regular ($400$) | $+0.005\text{ em}$ | Cuplikan pesan terakhir (*snippet*), bio, deskripsi menu |
| `type.buttonLabel` | $14.5\text{ sp}$ | $20\text{ sp}$ | Medium ($500$) | $+0.01\text{ em}$ | Label tombol utama, tombol aksi dialog, tab |
| `type.captionTime` | $11.5\text{ sp}$ | $15\text{ sp}$ | Regular ($400$) | $+0.01\text{ em}$ | Jam di pojok gelembung pesan, jam di daftar chat, *badge* |
| `type.monoKey` | $13\text{ sp}$ | $19\text{ sp}$ | Medium ($500$) | $+0.04\text{ em}$ | *Safety Number* $60\text{-digit}$ (`Roboto Mono`), kode diagnostik |

## 4.3 Grid Spasial, Dimensi Komponen, & Fisika Keyboard

1. **Grid Dasar:** Kelipatan $4\text{ dp}$ ($4, 8, 12, 16, 20, 24, 32\text{ dp}$). Untuk penyesuaian optik mikro pada teks/ikon diizinkan $2\text{ dp}$ atau $6\text{ dp}$.
2. **Dimensi Standar Komponen:**
   * **Top App Bar:** Tinggi tetap $56\text{ dp}$ (+ `MediaQuery.paddingOf(context).top` untuk *status bar*).
   * **Bottom Navigation Bar:** Tinggi $64\text{ dp}$ (+ `MediaQuery.paddingOf(context).bottom` untuk *gesture bar*). Menggunakan indikator pil tipis ($56 \times 30\text{ dp}$) berwarna `accent.subtle` di sekitar ikon aktif.
   * **Touch Target Minimum:** Seluruh tombol ikon dan area interaktif wajib memiliki area ketuk minimal $48 \times 48\text{ dp}$ meskipun ukuran visual ikonnya $22\text{ dp}$ atau $24\text{ dp}$.
   * **Corner Radius:**
     * Tombol & Input Form: $10\text{ dp}$
     * *Search Bar* & *Composer Field*: $22\text{ dp}$ (membulat proporsional, berubah menjadi $14\text{ dp}$ saat *multiline* $> 2$ baris)
     * Gelembung Chat (*Chat Bubble*): $14\text{ dp}$ pada tiga sudut, dan **$4\text{ dp}$ pada sudut ekor** (kiri-bawah untuk pesan masuk, kanan-bawah untuk pesan keluar) jika pesan tersebut merupakan pesan terakhir dalam kelompok pengirim yang sama.
     * Dialog & *Bottom Sheet*: $16\text{ dp}$ (hanya sudut atas untuk *bottom sheet*).
3. **Fisika *Keyboard (IME) Inset* pada Ruang Chat:**
   * Saat keyboard muncul (`viewInsets.bottom > 0`), bilah *composer* menempel tepat di atas keyboard tanpa jeda atau lompatan *frame*.
   * Jika posisi *scroll* pengguna berada di dasar percakapan ($\le 64\text{ dp}$ dari pesan paling bawah), daftar pesan otomatis bergeser naik bersama keyboard sehingga pesan terakhir tetap terlihat. Jika pengguna sedang membaca pesan lama di atas, posisi baca tidak boleh ditarik paksa ke bawah.

---

# 5. Spesifikasi Komponen UI Mikro & Anatomi Interaksi

## 5.1 Anatomi Baris Daftar Chat (`ChatListItem` — Tinggi $74\text{ dp}$)

```text
|<── 16dp ──>|<── 48dp ──>|<── 12dp ──>|<────────── Expanded (Flex 1) ──────────>|<─ 8dp ─>|<── Auto ──>|<── 16dp ──>|
+--------------------------------------------------------------------------------------------------------------------+
|            |   .----.   |            | [Pin] Nama Kontak / @username           |         |   09:42    |            |
|            |  /      \  |            |       (16sp Medium, 1 baris ellipsis)   |         |  (11.5sp)  |            |
|            | | Avatar | |            |-----------------------------------------|         |------------|            |
|            |  \ 48dp /  |            | [✓✓] Cuplikan pesan terdekripsi...      |         | [Mute] (2) |            |
|            |   '----'   |            |      (14sp Secondary, 1 baris ellipsis) |         |  Badge 20dp|            |
+--------------------------------------------------------------------------------------------------------------------+
|            |                         |_____________________________________________________________________________|
|                                       ^-- Hairline Divider (0.5dp, inset kiri = 76dp, inset kanan = 0dp)
```

* **Aturan Ketat Baris Chat:**
  * *Padding* horizontal luar: $16\text{ dp}$ kiri dan kanan; *padding* vertikal: $13\text{ dp}$ atas dan bawah.
  * Garis pemisah (*divider*) dimulai dari koordinat $X = 76\text{ dp}$ ($16\text{ dp} + 48\text{ dp} + 12\text{ dp}$) agar sejajar lurus dengan awal teks nama kontak.
  * Jika ada pesan belum dibaca (*unread* $> 0$): teks jam (`09:42`) berubah warna menjadi `accent.interactive` (Medium $500$), dan di bawahnya tampil lencana bulat (`height: 20dp, minWidth: 20dp, padding: 6dp`) berwarna `accent.primary` dengan angka putih $11.5\text{ sp}$ Bold.

## 5.2 Anatomi Gelembung Pesan (`MessageBubble`)

1. **Batas Lebar:** Lebar minimum $88\text{ dp}$, lebar maksimum **$78\%$ dari lebar layar** (misal pada layar $360\text{ dp}$, lebar maksimum adalah $280\text{ dp}$).
2. **Pengelompokan Vertikal (*Message Grouping*):**
   * Jarak antar-pesan dari **pengirim yang sama** dalam rentang waktu $< 2\text{ menit}$: **$3\text{ dp}$**.
   * Jarak ketika **berganti pengirim** atau jeda waktu $\ge 2\text{ menit}$: **$10\text{ dp}$**.
3. **Tata Letak *Timestamp* & Indikator Status (*Inline Wrap*):**
   * Jam (`09:42`) dan ikon status (`✓` / `✓✓`) berukuran $14\text{ dp}$ ditempatkan di pojok kanan bawah gelembung secara *inline-float* (menggunakan `RichText` dengan *invisible trailing spacer* sepanjang lebar jam + $12\text{ dp}$ agar teks pendek tetap satu baris dengan jam, sedangkan teks panjang membungkus rapi tanpa menabrak jam).
4. **Indikator Status Pengiriman (Wajib Dibedakan Secara Bentuk, Bukan Hanya Warna):**
   * `queued` / `encrypting`: Ikon Jam Kecil ($13\text{ dp}$, warna `text.muted`).
   * `sending`: Lingkaran progres tipis berputar ($12\text{ dp}$, *stroke* $1.5\text{ dp}$).
   * `sent`: Satu centang `✓` ($14\text{ dp}$, warna `text.secondary`).
   * `delivered`: Dua centang rapat `✓✓` ($14\text{ dp}$, warna `text.secondary`).
   * `read`: Dua centang rapat `✓✓` ($14\text{ dp}$, warna `tick.read`).
   * `failed`: Ikon Tanda Seru dalam lingkaran merah `!` ($15\text{ dp}$, warna `status.danger`) + label kecil `"Gagal • Ketuk untuk ulangi"` tepat di bawah gelembung.

## 5.3 Mesin Status Bilah Komposer (`ChatComposerBar`)

Bilah komposer di bagian bawah `UI-10 Chat Detail` memiliki 4 keadaan (*states*) yang bertransisi secara mulus ($150\text{ ms}$ `Curves.easeOutCubic`):

```text
[STATE A: IDLE / KOSONG]
┌──────────────────────────────────────────────────────────────────────────┐
│  [+] (44dp)   ┌──────────────────────────────────────────┐   [🎤] (44dp) │
│  Lampiran     │ Ketik pesan...                  [😊]     │   Rekam Suara │
│               └──────────────────────────────────────────┘               │
└──────────────────────────────────────────────────────────────────────────┘

[STATE B: MENGETIK TEKS / ADA LAMPIRAN]
┌──────────────────────────────────────────────────────────────────────────┐
│  [+] (44dp)   ┌──────────────────────────────────────────┐   [➤] (44dp)  │
│               │ Halo, dokumen sudah siap dikirim  [😊]   │   Kirim (Biru)│
│               └──────────────────────────────────────────┘               │
└──────────────────────────────────────────────────────────────────────────┘

[STATE C: MEREKAM VOICE NOTE (TERKUNCI / LOCKED)]
┌──────────────────────────────────────────────────────────────────────────┐
│  [🔴 00:14]   ‖▍▊▎▋▍▉▊▏▍▋▎▊▉▍ (Waveform Live)    [Hapus 🗑]   [➤] (44dp)  │
└──────────────────────────────────────────────────────────────────────────┘

[STATE D: MODE BALAS (REPLY) ATAU EDIT AKTIF]
┌──────────────────────────────────────────────────────────────────────────┐
│  ┌─┃ Membalas @alex ────────────────────────────────────────────── [✕] ┐ │
│  │ ┃ "Besok kita bahas arsitektur database..."                         │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
│  [+] (44dp)   ┌──────────────────────────────────────────┐   [➤] (44dp)  │
│               │ Siap, jam 10 pagi ya              [😊]   │               │
└──────────────────────────────────────────────────────────────────────────┘
```

* **Tinggi Input Dinamis:** Dimulai dari $44\text{ dp}$ (1 baris) dan membesar otomatis mengikuti teks hingga maksimum **5 baris ($124\text{ dp}$)** sebelum berubah menjadi *scrollable* di dalam kotak input.

---

# 6. Blueprint Layout Detail & Spesifikasi 25 Layar (UI-01 s.d. UI-25)

Setiap layar di bawah ini wajib mengimplementasikan 6 kondisi visual: **Default/Loaded, Empty, Loading, Offline Banner, Permission Denied (jika relevan), dan Error Recovery**.

## 6.1 Kelompok Autentikasi & Onboarding (UI-01 s.d. UI-06)

### UI-01: Splash & SQLCipher Bootstrap
* **Struktur Layout:**
  * Latar penuh `bg.canvas` (`#0E1013` pada Dark Mode, mencegah *white flash* saat aplikasi dibuka lewat `styles.xml` Android).
  * Tengah vertikal & horizontal: Logomark geometris datar Adoetz Chat 2 ($72 \times 72\text{ dp}$), jarak $16\text{ dp}$ ke teks `Adoetz Chat 2` ($18\text{ sp}$ SemiBold).
  * Bawah layar (jarak $40\text{ dp}$ dari *safe area* bawah): Indikator progres melingkar kecil ($18\text{ dp}$, *stroke* $2\text{ dp}$, hanya muncul jika proses buka kunci SQLCipher $> 300\text{ ms}$) dan teks versi `v2.0.0 (com.adoetzchat2.chat)` ($11.5\text{ sp}$ `text.muted`).
* **Perilaku Kegagalan:** Jika setelah $8\text{ detik}$ validasi sesi menggantung karena jaringan, otomatis masuk ke `UI-07 Chats` menggunakan data *cache* lokal SQLCipher jika kunci valid. Jika database lokal korup, tampilkan panel pemulihan dengan tombol `Coba Lagi` dan `Salin Kode Diagnostik`.

### UI-02: Welcome Screen
* **Struktur Layout (Padding Horizontal $24\text{ dp}$):**
  * **Bagian Atas ($15\%$ tinggi layar):** Tombol pemilih tema cepat (`Sistem / Gelap / Terang`) di pojok kanan atas.
  * **Bagian Tengah (Expanded):** Ikon perisai pesan minimalis ($56\text{ dp}$, `accent.primary`), judul `"Komunikasi Privat Tanpa Nomor Telepon"` ($22\text{ sp}$ SemiBold), dan deskripsi 2 baris `"Pesan dan panggilan dienkripsi end-to-end langsung di perangkat Anda."` ($14\text{ sp}$ `text.secondary`).
  * **Bagian Bawah (Sticky di atas *Safe Area*):**
    * Tombol Utama (Filled `accent.primary`, tinggi $50\text{ dp}$, lebar $100\%$): `Masuk ke Akun` $\rightarrow$ menuju `UI-04`.
    * Jarak $12\text{ dp}$.
    * Tombol Sekunder (Outlined `border.hairline`, tinggi $50\text{ dp}$, lebar $100\%$): `Buat Akun Baru` $\rightarrow$ menuju `UI-03`.
    * Jarak $16\text{ dp}$: Teks kecil ketentuan privasi & penjelasan singkat E2EE.

### UI-03: Sign Up (Registrasi Terbuka Tanpa Undangan)
* **Struktur Layout (`SingleChildScrollView`, Padding $20\text{ dp}$):**
  * **Top Bar:** Tombol Kembali (`‹`) + Judul `Buat Akun Baru`.
  * **Banner Informasi (Kotak `bg.elevated`, padding $12\text{ dp}$, radius $8\text{ dp}$):** Ikon info + teks `"Pendaftaran terbuka. Karena email tidak diverifikasi secara otomatis, simpan password Anda dengan aman."`
  * **Form Input (Jarak antar-field $16\text{ dp}$):**
    1. **Username:** Prefix tetap `@`, input huruf kecil/angka/garis bawah ($3\text{--}24$ karakter). Di sebelah kanan dalam *field* terdapat indikator status *real-time* (debounce $400\text{ ms}$): spinner kecil $\rightarrow$ centang hijau `Tersedia` atau silang merah `Sudah dipakai`.
    2. **Email:** Input `TextInputType.emailAddress`, validasi format RFC standar.
    3. **Password:** Minimal $12\text{ karakter}$, tombol ikon mata (*show/hide*), bar indikator kekuatan 4 segmen di bawah *field*.
    4. **Konfirmasi Password:** Validasi kecocokan *real-time*.
  * **Widget Anti-Bot:** Komponen **Cloudflare Turnstile** (*managed/invisible widget* tinggi $65\text{ dp}$ bila interaktif).
  * **Checkbox Persetujuan:** Centang persetujuan Ketentuan Layanan & Kebijakan Privasi E2EE.
  * **Tombol CTA (`Buat Akun & Buat Kunci Enkripsi`, tinggi $50\text{ dp}$):** Saat diketuk, tombol terkunci dan menampilkan tahapan: `(1/2) Mendaftarkan akun...` $\rightarrow$ `(2/2) Mengamankan kunci perangkat...`.

### UI-04: Sign In & UI-05: Auth Error / Device Conflict Modal
* **Struktur Layout UI-04 (Padding $20\text{ dp}$):**
  * Field 1: `Username atau Email` (mendukung input `@username`, `username`, atau `nama@domain.com`).
  * Field 2: `Password` dengan ikon *show/hide*.
  * Tombol Utama: `Masuk` (tinggi $50\text{ dp}$).
  * Bantuan di bawah tombol: `"Lupa password? Hubungi Administrator komunitas untuk reset kredensial."`
* **UI-05 (Bottom Sheet / Modal Konflik Perangkat & Error):**
  * Jika pengguna login di HP baru sementara akun sudah memiliki perangkat E2EE aktif, muncul **Modal Peringatan Pergantian Perangkat**:
    * Judul: `"Ganti Perangkat Aktif?"`
    * Penjelasan: `"Akun ini sedang aktif di perangkat lain. Karena Adoetz Chat 2 menggunakan enkripsi 1-perangkat, melanjutkan login di sini akan mengeluarkan perangkat lama dan membuat kunci enkripsi baru. Riwayat chat lama tidak akan ikut berpindah."`
    * Tombol Aksi: `Batalkan` (Sekunder) | `Ganti Perangkat & Lanjutkan` (Danger/Primary).

### UI-06: First-Run Contextual Permissions
* Tidak pernah memunculkan 4 dialog izin sekaligus saat pertama kali masuk.
* Hanya menampilkan satu kartu penjelasan tipis di bagian atas `UI-07 Chats` jika izin Notifikasi (Android 13+) belum diberikan: `"Aktifkan notifikasi agar pesan dan panggilan masuk tidak terlewat"` dengan tombol `Aktifkan` dan `Nanti`. Izin mikrofon, kamera, dan penyimpanan baru diminta tepat saat pengguna menekan tombol rekam suara, panggilan, atau lampiran.

---

## 6.2 Kelompok Percakapan Utama & Kontak (UI-07 s.d. UI-13)

### UI-07: Chats List (Layar Utama)

```text
┌──────────────────────────────────────────────────────────┐
│  Adoetz Chat 2                           [🔍]  [✎]  [⚙]  │ ◄── Top App Bar (56dp, bg.surface)
├──────────────────────────────────────────────────────────┤
│  [⚡ Sedang offline • Pesan antre akan dikirim otomatis] │ ◄── Conditional Banner (32dp, hanya jika offline)
├──────────────────────────────────────────────────────────┤
│  ┌────┐  Alex Pratama                        📌 09:42    │ ◄── Row 1: Pinned & Unread (74dp)
│  │ AP │  Besok kita review skema Supabase ya      (2)    │     Nama: 16sp SemiBold, Badge: 20dp Biru
│  └────┘  ─────────────────────────────────────────────── │
│  ┌────┐  Nadia Putri                            Kemarin  │ ◄── Row 2: Outgoing Read (74dp)
│  │ NP │  ✓✓ [Foto] Lampiran desain v2.0                  │     Ticks: 14dp tick.read
│  └────┘  ─────────────────────────────────────────────── │
│  ┌────┐  Budi Santoso                           Selasa   │ ◄── Row 3: Outgoing Queued (74dp)
│  │ BS │  🕒 Siap, tunggu sebentar                        │     Clock icon: 13dp text.muted
│  └────┘  ─────────────────────────────────────────────── │
│                                                          │
│                                                  ┌────┐  │
│                                                  │ 💬+│  │ ◄── FAB (52x52dp, radius 14dp, accent.primary)
│                                                  └────┘  │
├──────────────────────────────────────────────────────────┤
│     [💬 Chats]     [📞 Calls]    [👥 Contacts]  [⚙ Set]  │ ◄── Bottom Navigation (64dp)
└──────────────────────────────────────────────────────────┘
```

* **Interaksi *Long-Press* pada Baris Chat:** Memilih baris dengan warna latar `accent.subtle` dan mengubah Top App Bar menjadi *Contextual Action Bar*: `[✕ Batal]  1 dipilih  [📌 Pin] [🔕 Mute] [🗑 Hapus Chat Lokal]`.

### UI-08: Contact Search & Directory
* **Top Bar:** Kolom pencarian langsung fokus (`Cari @username...`, tinggi $42\text{ dp}$, latar `bg.elevated`, tombol `✕` untuk hapus teks).
* **Aturan Pencarian:** Minimal $2\text{ karakter}$, *debounce* $350\text{ ms}$. Menampilkan daftar hasil dengan Avatar $44\text{ dp}$, `Display Name` ($15.5\text{ sp}$ Medium), dan `@username` ($13.5\text{ sp}$ `accent.interactive`). Mengetuk baris membuka `UI-09 Contact Profile`.

### UI-09: Contact Profile Sheet / Screen
* **Anatomi Layout:**
  * Avatar lingkaran besar ($84\text{ dp}$) di tengah atas, diikuti `Display Name` ($20\text{ sp}$ SemiBold) dan chip `@username` (dapat diketuk untuk *copy*).
  * Kotak Bio ($14\text{ sp}$, maksimal 4 baris).
  * **Baris Aksi Cepat (3 Tombol Sejajar, tinggi $64\text{ dp}$ masing-masing dalam kotak `bg.elevated` radius $12\text{ dp}$):**
    1. `[💬 Kirim Pesan]`
    2. `[📞 Panggilan Suara]`
    3. `[📹 Panggilan Video]`
  * **Kartu Status Enkripsi:** Menampilkan `"Enkripsi End-to-End Aktif"` + status verifikasi *Safety Number* (`Terverifikasi` atau `Ketuk untuk memverifikasi kode keamanan`).
  * **Bagian Bawah (Destructive):** Baris `Blokir @username` dan `Laporkan Akun` dengan warna `status.danger`.

### UI-10: Chat Detail (Ruang Percakapan 1:1 E2EE)

```text
┌──────────────────────────────────────────────────────────┐
│ ‹  [Avatar 36dp]  Alex Pratama               [📞] [📹] [⋮]│ ◄── App Bar (56dp): Nama + @alex di bawahnya
├──────────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────────┐  │
│  │ 🔒 Kunci keamanan @alex berubah. [Verifikasi]      │  │ ◄── Security Banner (Hanya jika key berubah)
│  └────────────────────────────────────────────────────┘  │
│                       ┌──────────┐                       │
│                       │ Hari Ini │                       │ ◄── Date Chip (24dp tinggi, bg.overlay)
│                       └──────────┘                       │
│  ┌────────────────────────────────────┐                  │
│  │ Halo, apakah file APK sudah siap?  │                  │ ◄── Bubble Incoming (bg: bubble.incoming.bg)
│  │                              09:40 │                  │     Max width: 78% layar, radius: 14/14/14/4dp
│  └────────────────────────────────────┘                  │
│          ┌────────────────────────────────────────────┐  │
│          │ ┌─┃ Alex Pratama ────────────────────────┐ │  │ ◄── Bubble Outgoing + Reply Quote
│          │ │ ┃ Halo, apakah file APK sudah siap?    │ │  │     (bg: bubble.outgoing.bg)
│          │ └────────────────────────────────────────┘ │  │
│          │ Sudah siap, ini sedang di-build di CI.     │  │
│          │                                  09:41 ✓✓  │  │
│          └────────────────────────────────────────────┘  │
│          ┌────────────────────────────────────────────┐  │
│          │ [▶] ━━━●━━━━━━━━━━━ 0:18 / 0:42   09:42 ✓✓ │  │ ◄── Bubble Voice Note (1x/1.5x/2x toggle)
│          └────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────────────┤
│  [+]   ┌──────────────────────────────────────┐   [🎤]   │ ◄── Composer Bar (Min 56dp, bg.surface)
│        │ Ketik pesan...                  [😊] │          │
│        └──────────────────────────────────────┘          │
└──────────────────────────────────────────────────────────┘
```

* **Interaksi Pesan:**
  * *Swipe* gelembung ke kanan (ambang tarik $56\text{ dp}$ dengan getaran *haptic* ringan): Memasukkan pesan ke dalam **Mode Balas (Reply)** di komposer.
  * *Long-press* gelembung: Menampilkan deretan reaksi cepat (`👍 ❤️ 😂 😮 😢 🙏`) di atas gelembung dan menu aksi di bawahnya (`Balas`, `Salin Teks`, `Edit Pesan` [jika milik sendiri & $< 15\text{ menit}$], `Info Pesan`, `Hapus untuk Saya`, `Hapus untuk Semua Orang`).

### UI-11: Attachment Picker & Preview
* **Bottom Sheet Pemilih (`tinggi 220dp`):** 3 pilihan bersih tanpa ikon warna-warni berlebihan:
  1. `Galeri Foto & Video` (membuka Android Photo Picker sistem).
  2. `Dokumen & File` (membuka Android Storage Access Framework / SAF).
  3. `Kamera` (mengambil foto instan).
* **Layar Preview Sebelum Kirim:** Menampilkan pratinjau gambar/video atau kartu informasi dokumen (nama file, ekstensi, ukuran dalam $\text{MB}$), kolom input *caption* di bagian bawah, dan indikator `"File akan dienkripsi di perangkat sebelum diunggah"`.

### UI-12: Voice Note Recorder (Terintegrasi di Composer)
* Mendukung dua gestur: **Ketuk sekali pada mikrofon** untuk langsung masuk ke mode rekam terkunci (*hands-free*), atau **Tekan-dan-tahan** lalu geser ke atas untuk mengunci / geser ke kiri untuk membatalkan.
* Menampilkan waktu berjalan (`00:00` hingga maks `10:00`), grafik gelombang suara (*waveform*) 24 batang yang bergerak mengikuti amplitudo mikrofon, tombol `🗑 Batal`, tombol `⏸ Jeda / ▶ Putar Ulang`, dan tombol `➤ Kirim`.

### UI-13: Chat Info & Verifikasi Safety Number (QR)
* Menampilkan profil lawan bicara, daftar **Media, File, & Voice Note Bersama** (diambil dari penyimpanan lokal yang telah didekripsi, dibagi dalam 3 tab: `Media`, `Dokumen`, `Suara`), serta menu **Verifikasi Enkripsi End-to-End**.
* **Layar Verifikasi Keamanan:** Menampilkan kode QR yang merepresentasikan gabungan *Identity Key* kedua belah pihak, ditambah **12 kelompok angka 5-digit ($60\text{ digit}$ total)** menggunakan font `type.monoKey` (`Roboto Mono` $13\text{ sp}$), tombol `Pindai QR Kontak`, dan sakelar `Tandai Sebagai Terverifikasi`.

---

## 6.3 Kelompok Panggilan Suara & Video (UI-14 s.d. UI-17)

### UI-14: Calls History
* Daftar riwayat panggilan datar (tinggi baris $68\text{ dp}$): Avatar $44\text{ dp}$, Nama Kontak, ikon arah panggilan (`↙ Masuk`, `↗ Keluar`, `↙ Tak Terjawab` berwarna `status.danger`) + waktu & durasi (`Hari ini, 14:20 • 05:12`), serta tombol ikon telepon/video di sisi kanan untuk menelepon kembali dengan 1 ketukan.

### UI-15: Outgoing Call, UI-16: Incoming Call, & UI-17: Active Call

```text
[UI-16: INCOMING CALL]                  [UI-17: ACTIVE VOICE / VIDEO CALL]
┌────────────────────────────────────┐  ┌────────────────────────────────────┐
│      🔒 Enkripsi End-to-End        │  │ ‹  🔒 Enkripsi E2EE     [📶 Stabil]│
│                                    │  │                                    │
│              .------.              │  │   ┌────────────────────────────┐   │
│             /        \             │  │   │                            │   │
│            |  Avatar  |            │  │   │     VIDEO REMOTE PEER      │   │
│             \  96dp  /             │  │   │    (Atau Avatar jika       │   │
│              '------'              │  │   │     Panggilan Suara)       │   │
│            Alex Pratama            │  │   │                   ┌──────┐ │   │
│              @alex                 │  │   │                   │Local │ │   │
│     Panggilan Suara Masuk...       │  │   │                   │PiP   │ │   │
│                                    │  │   └───────────────────┴──────┴─┘   │
│    ┌────────┐        ┌────────┐    │  │            04:28 (Durasi)          │
│    │   ✕    │        │   📞   │    │  │  ┌──────────────────────────────┐  │
│    │ Tolak  │        │ Terima │    │  │  │ [🔇]   [🔊]   [📹]   [🔄]  [📞]│  │
│    └────────┘        └────────┘    │  │  │ Mute   Spkr   Cam   Flip  End│  │
│   (64dp Merah)      (64dp Hijau)   │  │  └──────────────────────────────┘  │
└────────────────────────────────────┘  └────────────────────────────────────┘
```

* **Perilaku Layar Terkunci & Background (Android 14+):**
  * Menggunakan `Notification.CallStyle.forIncomingCall` dengan *PendingIntent* untuk `Terima` dan `Tolak`.
  * Jika izin `USE_FULL_SCREEN_INTENT` diberikan oleh sistem/pengguna saat layar terkunci, otomatis membuka `UI-16 Incoming Call`. Jika layar sedang aktif digunakan, tampilkan sebagai *Heads-Up Notification Banner* di bagian atas agar tidak membajak aktivitas pengguna.
* **Mini-Call Pill:** Jika pengguna menekan tombol *Back* saat panggilan berlangsung di `UI-17`, panggilan tidak terputus; layar kembali ke ruang chat dan muncul bar hijau/biru tipis ($36\text{ dp}$) di bawah Top App Bar: `"📞 Panggilan berlangsung • 04:28 — Ketuk untuk kembali"`.

---

## 6.4 Kelompok Pengaturan & Utilitas Admin (UI-18 s.d. UI-25)

### UI-18: Settings, UI-19: Appearance, UI-20: Privacy, & UI-21: My Account
* **UI-18 (Settings):** Bagian atas menampilkan kartu ringkas profil pengguna (Avatar $56\text{ dp}$, Nama, `@username`, tombol `Edit`), diikuti grup daftar menu datar dengan ikon *outline* monokrom $22\text{ dp}$:
  1. `Akun & Identitas Perangkat` (`UI-21`)
  2. `Privasi & Kunci Aplikasi` (`UI-20`)
  3. `Tampilan & Tema` (`UI-19`)
  4. `Notifikasi & Panggilan`
  5. `Penyimpanan & Cache Lokal`
  6. `Panel Administrator` (Hanya dirender jika klaim server `role == 'admin'`)
  7. `Keluar (Logout)` (Teks berwarna `status.danger`, menampilkan dialog konfirmasi bahwa kunci enkripsi lokal tetap tersimpan aman di perangkat kecuali pengguna memilih opsi `"Keluar & Hapus Data Lokal"`).
* **UI-19 (Appearance):** Menampilkan 3 pilihan radio (`Ikuti Sistem [Default]`, `Mode Gelap Charcoal`, `Mode Terang Alabaster`) dan kotak pratinjau langsung berisi 2 gelembung chat (*incoming* & *outgoing*) yang berubah seketika tanpa me-restart navigasi.

### UI-22: Admin Dashboard, UI-23: Admin User Detail, & UI-24: Admin Audit Log
* **Prinsip Desain Admin:** Utilitarian, bersih, dan padat informasi seperti konsol manajemen modern.
* **UI-22 (Admin Dashboard):**
  * Baris ringkasan 3 metrik teks di bagian atas (`Total Akun`, `Aktif`, `Ditangguhkan`).
  * Kolom pencarian (`Cari @username, email, atau UUID...`) + *Filter Chips* (`Semua`, `User`, `Admin`, `Suspended`).
  * Daftar pengguna terpaginasi ($25\text{ baris}$ per halaman): menampilkan `@username`, email, badge status (`ACTIVE` hijau / `SUSPENDED` merah), dan tanggal daftar.
* **UI-23 (Admin User Detail):**
  * Menampilkan metadata akun lengkap (tanpa akses apa pun ke percakapan/kunci E2EE).
  * **Menu Tindakan Terotentikasi (Setiap aksi membuka dialog konfirmasi + input wajib `Alasan Tindakan` untuk Audit Log):**
    1. `Tangguhkan Akun (Suspend)` / `Aktifkan Kembali (Unsuspend)`
    2. `Cabut Seluruh Sesi Login (Revoke Sessions)`
    3. `Reset Password Paksa (Force Password Reset)`: Menghasilkan password sementara satu-kali-pakai yang ditampilkan **hanya sekali di layar modal admin** dengan tombol `Salin` untuk diberikan ke pengguna secara *out-of-band*, dan tidak pernah dicatat ke dalam log.
    4. `Ubah Role (User <-> Admin)`: Dilindungi *step-up authentication* (input password admin kembali) dan pencegahan pencabutan admin terakhir.
    5. `Hapus Akun`: Pilihan *Soft Delete* (masa tenggang 7 hari) atau *Hard Delete*.
* **UI-24 (Admin Security & Audit Log):** Daftar kronologis *append-only* yang menampilkan `Waktu`, `Admin Pelaku`, `Aksi`, `Target Akun`, `Alasan`, dan `Request ID`.

### UI-25: Universal Blocker, Maintenance, & Diagnostic Screen
* Layar khusus satu halaman penuh untuk menangani kondisi tingkat sistem: `Akun Ditangguhkan (Suspended)`, `Sesi Berakhir`, `Pembaruan Aplikasi Wajib (Min-Version Gate)`, atau `Kesalahan Migrasi Database Lokal`. Selalu menyediakan penjelasan yang jujur dan tombol aksi pemulihan tunggal.

---

# 7. Alur End-to-End (Sequence & State Flows)

## 7.1 Alur Registrasi Terbuka Atomik (Anti-Split-State)

```text
[Flutter Client]                 [Supabase Auth + Turnstile]          [PostgreSQL Trigger (SECURITY DEFINER)]
       │                                      │                                          │
       ├── 1. Cek @username (Debounce RPC) ──►│                                          │
       │◄─ Tersedia ──────────────────────────┤                                          │
       │                                      │                                          │
       ├── 2. signUp(email, password,         │                                          │
       │      captchaToken,                   │                                          │
       │      data: {username: 'alex'}) ─────►│                                          │
       │                                      ├── 3. Verifikasi Turnstile & Rate Limit   │
       │                                      ├── 4. INSERT auth.users ─────────────────►│
       │                                      │                                          ├── 5. Validasi regex & unik @username
       │                                      │                                          ├── 6. INSERT public.profiles
       │                                      │                                          ├── 7. INSERT public.user_roles ('user')
       │                                      │                                          ├── 8. INSERT public.account_status ('active')
       │                                      │◄─ 9. Transaksi Commit (Atau Rollback!) ──┤
       │◄─ 10. Return Session JWT ────────────┤                                          │
       │                                      │                                          │
       ├── 11. Generate Identity Key,         │                                          │
       │       Signed PreKey, 100 One-Time    │                                          │
       │       PreKeys di SQLCipher/Keystore  │                                          │
       ├── 12. POST /register-device-key ────►│ (Simpan Public Keys & Aktifkan Device)   │
       ▼                                      ▼                                          ▼
[Masuk ke UI-07 Chats]
```

## 7.2 Alur Pengiriman Pesan E2EE & Rekonsiliasi Offline

1. **Komposisi & Penyimpanan Lokal (*Optimistic Outbox*):**
   * Pengguna mengetik pesan dan menekan `Kirim`.
   * Klien menghasilkan `client_message_id` (UUID v4) dan menyimpannya ke tabel lokal SQLCipher `local_messages` dengan status `queued` serta memasukkannya ke tabel `outbox_queue`. Gelembung pesan langsung muncul di layar dalam $< 16\text{ ms}$.
2. **Negosiasi Kunci & Enkripsi (X3DH + Double Ratchet):**
   * Jika belum ada sesi kriptografi dengan penerima, klien memanggil Edge Function `get-prekey-bundle` untuk mengambil *Identity Key*, *Signed PreKey*, dan satu *One-Time PreKey* milik perangkat aktif penerima, lalu menginisialisasi sesi X3DH.
   * Pesan (beserta metadata kutipan/lampiran) diserialisasi ke format biner ringkas (Protobuf/JSON terkompresi) lalu dienkripsi dengan langkah *Double Ratchet* menghasilkan `ciphertext` dan `envelope_header`.
   * State *ratchet* terbaru dan *ciphertext* disimpan secara **atomik dalam satu transaksi SQLCipher** sebelum paket dikirim ke jaringan.
3. **Pengiriman Idempoten ke Server:**
   * Klien memanggil RPC/Edge Function pengiriman pesan dengan `(sender_id, client_message_id)` sebagai kunci unik. Jika jaringan terputus tepat setelah server menyimpan namun sebelum klien menerima respons, percobaan ulang (*retry*) dari `outbox_queue` akan mengenali `client_message_id` yang sama dan mengembalikan `server_message_id` beserta `server_created_at` yang asli tanpa membuat pesan ganda.
4. **Distribusi *Real-time* & *Wake-up Push*:**
   * Server memancarkan *event* melalui saluran privat **Supabase Realtime Broadcast** (`conversation:{id}`) dan memicu worker pengiriman **FCM Data Message** (hanya berisi `event_type: 'new_message'`, `conversation_id`, dan `server_message_id` — **0 byte plaintext**).
5. **Dekripsi & Tanda Terima (*Receipts*):**
   * Perangkat penerima mengambil *ciphertext*, mendekripsinya di SQLCipher lokal, menampilkan notifikasi lokal (jika diizinkan pengaturan privasi), dan mengirim balik tanda terima `delivered`. Ketika pengguna membuka ruang chat, klien mengirim tanda terima `read` (jika fitur *read receipts* diaktifkan).

---

# 8. Arsitektur Kriptografi E2EE & Penyimpanan Lokal

## 8.1 Spesifikasi Protokol Kriptografi

| Komponen | Algoritma / Standar yang Dikunci | Penyimpanan & Siklus Hidup |
|---|---|---|
| **Identity Key Pair** | Curve25519 / Ed25519 (`X25519` / `EdDSA`) | Dibuat saat registrasi / ganti perangkat. Kunci privat disimpan di SQLCipher yang kuncinya dibungkus Android Keystore. |
| **Signed PreKey** | Curve25519 ditandatangani dengan Identity Key | Dirotasi secara berkala setiap $7\text{--}14\text{ hari}$. |
| **One-Time PreKeys (OTPK)** | Curve25519 ($100\text{ kunci}$ saat awal) | Dikonsumsi secara atomik (`DELETE ... RETURNING`) di server. Jika sisa $< 20$, klien otomatis mengunggah $80$ kunci baru. |
| **Session Ratchet** | Signal Double Ratchet (Root Key, Chain Key, Message Key dengan HKDF-SHA256 & AES-256-CBC/HMAC atau AEAD) | Setiap pesan menggunakan kunci unik sementara (*ephemeral message key*) yang langsung dihapus setelah dekripsi (*forward secrecy*). |
| **Enkripsi Lampiran File** | **XChaCha20-Poly1305** atau **AES-256-GCM** | Klien membuat kunci acak $256\text{-bit}$ + *nonce* per file, mengenkripsi file menjadi *blob* `.enc`, mengunggahnya ke Supabase Private Bucket, lalu mengirim kunci file + *hash* SHA-256 di dalam pesan teks E2EE. |
| **Safety Number (Verifikasi)** | Iterated SHA-512 atas `(Version || IdentityKey_A || UserID_A || IdentityKey_B || UserID_B)` | Diformat menjadi $60\text{ digit}$ numerik (12 blok $\times$ 5 digit) dan payload QR Code. |

## 8.2 Keamanan Penyimpanan Lokal di Android (`com.adoetzchat2.chat`)

1. **Android Keystore Master Key:** Saat inisialisasi pertama, aplikasi membuat kunci simetris AES-256-GCM di dalam **Android Hardware-backed Keystore** (`com.adoetzchat2.chat.master_key`).
2. **Database SQLCipher (`adoetz_vault.db`):** Kunci passhrase $32\text{-byte}$ untuk membuka SQLCipher dienkripsi menggunakan Master Key dari Android Keystore. Seluruh daftar percakapan, *plaintext* pesan yang sudah didekripsi di perangkat, *draft*, indeks pencarian FTS5, dan tabel *ratchet state* berada di dalam database terenkripsi ini.
3. **Penanganan File Media Sementara:** Saat pengguna memutar *voice note* atau membuka dokumen terenkripsi, dekripsi dilakukan di memori (`Uint8List`) atau ke direktori cache internal aplikasi (`getApplicationSupportDirectory()`) yang tidak dapat diakses aplikasi lain dan langsung dibersihkan saat keluar dari layar.
4. **Blokir Backup Otomatis OS:** Di `AndroidManifest.xml`, atribut `android:allowBackup="false"` dan `android:fullBackupContent="false"` wajib diterapkan agar kunci kriptografi tidak bocor ke cloud backup OS atau tidak mengalami ketidakcocokan dengan Android Keystore saat pindah HP.

---

# 9. Skema Database Backend (Supabase PostgreSQL DDL & RLS)

Seluruh tabel di skema `public` wajib mengaktifkan **Row Level Security (RLS)**. Tabel sensitif internal (seperti pencatatan anti-abuse dan antrean push) ditempatkan di skema `private` yang tidak diekspos ke PostgREST Data API.

## 9.1 Struktur Tabel & Trigger Inti (SQL Blueprint)

```sql
-- 1. Enums
CREATE TYPE public.app_role AS ENUM ('user', 'admin');
CREATE TYPE public.user_account_status AS ENUM ('active', 'suspended', 'soft_deleted');
CREATE TYPE public.device_status AS ENUM ('active', 'revoked');
CREATE TYPE public.receipt_status AS ENUM ('delivered', 'read');
CREATE TYPE public.call_state AS ENUM ('ringing', 'connected', 'ended', 'declined', 'missed', 'busy', 'failed');

-- 2. Profiles (1-to-1 dengan auth.users)
CREATE TABLE public.profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT NOT NULL,
    username_normalized TEXT GENERATED ALWAYS AS (LOWER(TRIM(username))) STORED UNIQUE,
    display_name TEXT NOT NULL,
    bio TEXT DEFAULT '' NOT NULL CHECK (CHAR_LENGTH(bio) <= 160),
    avatar_path TEXT,
    discoverable BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    CONSTRAINT username_format_chk CHECK (username_normalized ~ '^[a-z0-9_]{3,24}$')
);

-- 3. Roles & Status Akun (Hanya dapat ditulis oleh Server / Trigger / Admin Function)
CREATE TABLE public.user_roles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role public.app_role DEFAULT 'user'::public.app_role NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE public.account_status (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    status public.user_account_status DEFAULT 'active'::public.user_account_status NOT NULL,
    suspended_reason TEXT,
    suspended_until TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 4. Perangkat E2EE (Strict Single-Active-Device via Partial Unique Index)
CREATE TABLE public.devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_name TEXT NOT NULL,
    registration_id INTEGER NOT NULL,
    identity_public_key TEXT NOT NULL,
    signed_prekey_id INTEGER NOT NULL,
    signed_prekey_public TEXT NOT NULL,
    signed_prekey_signature TEXT NOT NULL,
    status public.device_status DEFAULT 'active'::public.device_status NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    last_seen_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Invariant: Maksimal 1 perangkat berstatus 'active' per user_id
CREATE UNIQUE INDEX idx_single_active_device_per_user
    ON public.devices(user_id)
    WHERE status = 'active'::public.device_status;

CREATE TABLE public.device_one_time_prekeys (
    id BIGSERIAL PRIMARY KEY,
    device_id UUID NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
    key_id INTEGER NOT NULL,
    public_key TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    UNIQUE (device_id, key_id)
);

-- 5. Percakapan & Pesan (Hanya Ciphertext)
CREATE TABLE public.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    direct_pair_key TEXT UNIQUE NOT NULL, -- Format: LEAST(uid1,uid2) || ':' || GREATEST(uid1,uid2)
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    last_event_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE public.conversation_members (
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    last_read_server_ts TIMESTAMPTZ,
    is_muted BOOLEAN DEFAULT FALSE NOT NULL,
    is_pinned BOOLEAN DEFAULT FALSE NOT NULL,
    PRIMARY KEY (conversation_id, user_id)
);

CREATE TABLE public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id),
    sender_device_id UUID NOT NULL REFERENCES public.devices(id),
    recipient_device_id UUID NOT NULL REFERENCES public.devices(id),
    client_message_id UUID NOT NULL,
    protocol_version SMALLINT DEFAULT 2 NOT NULL,
    message_kind TEXT NOT NULL CHECK (message_kind IN ('ciphertext', 'control_edit', 'control_revoke', 'key_change')),
    ciphertext_b64 TEXT NOT NULL,
    attachment_object_id UUID,
    server_created_at TIMESTAMPTZ DEFAULT clock_timestamp() NOT NULL,
    UNIQUE (sender_id, client_message_id)
);

CREATE INDEX idx_messages_conv_cursor ON public.messages (conversation_id, server_created_at ASC, id ASC);
```

## 9.2 Trigger Pendaftaran Atomik (`handle_new_user`)

```sql
CREATE OR REPLACE FUNCTION private.handle_new_user_signup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_username TEXT;
    v_display_name TEXT;
BEGIN
    v_username := LOWER(TRIM(COALESCE(NEW.raw_user_meta_data->>'username', '')));
    v_display_name := TRIM(COALESCE(NEW.raw_user_meta_data->>'display_name', v_username));

    IF v_username !~ '^[a-z0-9_]{3,24}$' OR v_username IN ('admin', 'system', 'support', 'root', 'adoetz') THEN
        RAISE EXCEPTION 'INVALID_OR_RESERVED_USERNAME';
    END IF;

    INSERT INTO public.profiles (user_id, username, display_name)
    VALUES (NEW.id, v_username, v_display_name);

    INSERT INTO public.user_roles (user_id, role)
    VALUES (NEW.id, 'user'::public.app_role);

    INSERT INTO public.account_status (user_id, status)
    VALUES (NEW.id, 'active'::public.user_account_status);

    -- Sinkronkan klaim app_metadata agar JWT selalu membawa role 'user' yang sah
    UPDATE auth.users
    SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('role', 'user', 'status', 'active')
    WHERE id = NEW.id;

    RETURN NEW;
END;
$$;
```

## 9.3 Fungsi Helper Otorisasi RLS

Setiap kebijakan RLS pada tabel `messages`, `conversations`, `devices`, dan `calls` wajib memanggil fungsi pemeriksaan status aktif:
* `public.is_caller_active()`: Memastikan `auth.uid()` memiliki baris di `public.account_status` dengan `status = 'active'`. Dengan demikian, meskipun JWT pengguna yang baru saja di-*suspend* oleh admin belum kedaluwarsa (masih sisa beberapa menit), **seluruh query database, pengiriman pesan, dan akses Realtime langsung ditolak detik itu juga**.

---

# 10. Spesifikasi Edge Functions & Kontrak API

Seluruh endpoint Deno Edge Function menggunakan amplop respons JSON standar:
```json
{
  "request_id": "req_01JBM9...",
  "success": true,
  "data": {},
  "error": null
}
```

| Nama Edge Function | Metode | Fungsi & Validasi Keamanan Server-Side |
|---|---|---|
| `auth-login-identifier` | `POST` | Menerima `{ identifier, password, turnstile_token }`. Jika `identifier` tidak mengandung `@`, melakukan *lookup* `username_normalized` ke email secara internal di server (tanpa pernah membocorkan email ke klien), lalu mengeksekusi login dan memeriksa apakah akun sudah memiliki perangkat aktif lain. |
| `check-username` | `POST` | Menerima `{ username }`. Dibatasi *rate-limit* ketat per IP. Mengembalikan `{ available: boolean, reason: string }` setelah memeriksa format regex, daftar kata terlarang (*reserved words*), dan keunikan di tabel `profiles`. |
| `register-device-key` | `POST` | Menerima bundel kunci publik (`identity_public_key`, `signed_prekey`, dan array $100$ `one_time_prekeys`). Jika parameter `replace_existing_device == true`, mencabut perangkat lama (`status = 'revoked'`), mencabut sesi lama, dan mengaktifkan perangkat baru dalam satu transaksi. |
| `claim-prekey-bundle` | `POST` | Dipanggil pengirim sebelum memulai sesi E2EE baru. Mengambil `identity_public_key` + `signed_prekey` milik perangkat aktif penerima, serta mengambil dan menghapus (`DELETE ... RETURNING`) tepat **1 baris** `device_one_time_prekeys` secara atomik. |
| `send-encrypted-message` | `POST` | Memvalidasi keanggotaan percakapan, status blokir di `blocked_users`, status akun aktif, dan batas ukuran *ciphertext*. Melakukan `INSERT ... ON CONFLICT (sender_id, client_message_id) DO NOTHING` dan memicu *Broadcast* Realtime + antrean *wake-up* FCM. |
| `issue-attachment-grant` | `POST` | Memvalidasi kuota & keanggotaan ruang chat, lalu mengeluarkan *Signed Upload URL* berumur pendek ($120\text{ detik}$) ke bucket privat `encrypted-attachments/{conversation_id}/{random_uuid}.enc`. |
| `call-signaling` | `POST` | Mengelola siklus hidup panggilan (`initiate`, `ringing_ack`, `accept`, `decline`, `ice_candidate`, `hangup`) serta menerbitkan kredensial TURN sementara (`HMAC-SHA1` dengan TTL $3600\text{ detik}$) agar kredensial statis TURN tidak pernah tertanam di dalam APK. |
| `admin-manage-user` | `POST` | Memverifikasi secara langsung di database bahwa pemanggil memiliki `role = 'admin'` dan `status = 'active'`. Menangani operasi `suspend`, `unsuspend`, `force_reset_password`, `revoke_sessions`, `change_role`, dan `delete_user` disertai pencatatan wajib ke `private.admin_audit_logs`. |

---

# 11. Matriks Penanganan Error, Edge Cases, & Chaos Recovery

Sistem dirancang dengan asumsi jaringan seluler sering terputus, proses aplikasi dapat dimatikan OS kapan saja, dan input pengguna tidak pernah bisa dipercaya.

| Kode | Skenario Kegagalan / Edge Case | Perilaku UI/UX yang Wajib Tampil | Mekanisme Pemulihan Teknis (Engineering) |
|---|---|---|---|
| **ERR-01** | Koneksi putus di tengah pengiriman pesan | Gelembung tampil dengan ikon jam `🕒` (`queued`); tidak ada modal error yang mengganggu ketikan berikutnya. | `OutboxWorker` menyimpan pesan di SQLCipher dan melakukan *exponential backoff* ($1\text{s}, 2\text{s}, 4\text{s}, 8\text{s} \dots$) saat `ConnectivityPlus` mendeteksi jaringan aktif kembali. |
| **ERR-02** | Server sukses menyimpan pesan, tapi koneksi terputus sebelum HTTP 200 diterima klien | Status tetap `sending`/`queued`, lalu berubah menjadi `sent ✓` setelah *retry* otomatis без membuat gelembung kedua. | Deduplikasi mutlak menggunakan constraint unik `UNIQUE(sender_id, client_message_id)` di PostgreSQL. |
| **ERR-03** | Dua pengguna mendaftarkan `@username` yang sama pada milidetik yang sama | Salah satu pengguna berhasil masuk ke `UI-07`; pengguna lainnya tetap di `UI-03` dengan pesan inline `"Username baru saja digunakan, silakan pilih yang lain"`. | Constraint `UNIQUE(username_normalized)` di dalam Trigger `handle_new_user_signup()` membatalkan pembuatan akun kedua secara utuh tanpa menyisakan akun yatim (*orphan auth user*). |
| **ERR-04** | Pengguna login di HP kedua (Konflik Single-Device) | Muncul modal `UI-05`: meminta konfirmasi eksplisit untuk mengganti perangkat aktif dan merotasi kunci E2EE. | Jika disetujui, server mengubah perangkat lama menjadi `revoked` dan mengeluarkan sesi lama; semua lawan bicara menerima event `key_change` di ruang chat mereka. |
| **ERR-05** | Lawan bicara mengganti HP / menginstal ulang aplikasi (Identity Key Berubah) | Pengiriman pesan baru ke kontak tersebut ditahan sementara; muncul banner kuning di dalam `UI-10`: `"Identitas keamanan @user berubah. Ketuk untuk meninjau & lanjutkan."` | Klien mendeteksi perbedaan `identity_public_key` penerima; setelah pengguna mengetuk `Terima Kunci Baru` atau memverifikasi QR di `UI-13`, sesi *ratchet* baru diinisialisasi dan antrean pesan dikirim. |
| **ERR-06** | Notifikasi FCM panggilan masuk terlambat $60\text{ detik}$ karena mode Doze Android | Aplikasi **tidak** membunyikan nada dering palsu; hanya menampilkan notifikasi panggilan tak terjawab (`Missed Call`). | Setiap payload FCM panggilan membawa `expires_at_ms` (TTL $40\text{ detik}$). Jika `now > expires_at_ms`, *handler* background langsung membatalkan *ringing UI*. |
| **ERR-07** | Admin menangguhkan (*suspend*) pengguna yang sedang aktif *chatting* | Pesan yang baru diketik gagal terkirim dengan banner `"Akun Anda telah ditangguhkan oleh Administrator"`, lalu layar beralih ke `UI-25`. | Fungsi RLS `is_caller_active()` langsung menolak seluruh mutasi database dan Edge Function mencabut token refresh serta memutuskan saluran Realtime. |
| **ERR-08** | Jaringan berpindah dari Wi-Fi ke 4G/5G saat panggilan suara/video berlangsung | Muncul chip kecil `"Menghubungkan kembali..."` dengan bunyi *beep* halus tanpa menutup layar panggilan. | WebRTC memicu `restartIce()` menggunakan kandidat TURN terbaru; jika tersambung kembali dalam $\le 25\text{ detik}$, panggilan berlanjut normal. |

---

# 12. Arsitektur Modul Flutter, CI/CD GitHub Actions, & Definition of Done

## 12.1 Struktur Proyek Flutter (`com.adoetzchat2.chat`)

```text
adoetz_chat_2/
├── android/
│   └── app/
│       ├── build.gradle              # applicationId & namespace = "com.adoetzchat2.chat"
│       └── src/main/AndroidManifest.xml
├── lib/
│   ├── main.dart                     # Bootstrap, ErrorBoundary, ProviderScope
│   ├── app/
│   │   ├── router/                   # GoRouter + Auth/AppLock/Role Guards
│   │   └── theme/                    # Tokens, Dark/Light ThemeData, Typography
│   ├── core/
│   │   ├── crypto/                   # Signal Protocol Wrapper (X3DH, Double Ratchet, AEAD File)
│   │   ├── database/                 # Drift + SQLCipher Schema, FTS5 Search, Outbox DAO
│   │   ├── network/                  # Supabase Client, Edge Function Caller, Connectivity
│   │   ├── notifications/            # FCM Background Handler, CallStyle Notification, DeepLinks
│   │   └── webrtc/                   # PeerConnection Manager, TURN Fetcher, AudioRouter
│   └── features/
│       ├── auth/                     # UI-01..UI-05 (Welcome, SignUp, SignIn, DeviceConflict)
│       ├── chats/                    # UI-07, UI-10..UI-13 (List, Room, Composer, Media, QR)
│       ├── contacts/                 # UI-08, UI-09 (Search, Profile, Block/Report)
│       ├── calls/                    # UI-14..UI-17 (History, Outgoing, Incoming, Active Call)
│       ├── settings/                 # UI-18..UI-21 (Settings, Appearance, Privacy, Account)
│       └── admin/                    # UI-22..UI-24 (Dashboard, User Detail, Audit Log)
└── supabase/
    ├── migrations/                   # DDL, RLS Policies, Atomic Signup Trigger
    └── functions/                    # Deno Edge Functions
```

## 12.2 Pipeline CI/CD GitHub Actions & Penandatanganan APK

1. **Konfigurasi Identitas Android (`android/app/build.gradle`):**
   * `namespace "com.adoetzchat2.chat"`
   * `applicationId "com.adoetzchat2.chat"`
   * `minSdkVersion 29` (Android 10)
   * `targetSdkVersion 35` (Android 15)
2. **Alur Otomatisasi GitHub Actions (`.github/workflows/release-android.yml`):**
   * **Tahap 1 (Quality & Security Gate):** Menjalankan `flutter analyze --fatal-infos`, `flutter test` (unit test state machine, outbox deduplication, dan kriptografi), serta pemeriksaan kebocoran *secret* di repositori.
   * **Tahap 2 (Keystore Injection):** Mendekode *Release Keystore* (`UPLOAD_KEYSTORE_BASE64`) dari GitHub Actions Secrets ke runner sementara, menyuntikkan variabel lingkungan publik (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `TURNSTILE_SITE_KEY`) melalui `--dart-define`.
   * **Tahap 3 (Build & Checksum):** Membangun APK terpisah per ABI (`--split-per-abi` untuk mengecilkan ukuran unduhan) serta APK Universal (`app-release.apk` dengan nama file `com.adoetzchat2.chat-v2.0.X.apk`), menghasilkan berkas checksum `SHA256SUMS.txt`, lalu menerbitkannya ke **GitHub Releases**.
   * **Invarian Pembaruan:** Keystore penandatanganan wajib dijaga tetap sama di seluruh rilis agar pengguna dapat menginstal pembaruan APK (`v2.0.0` $\rightarrow$ `v2.0.1`) secara langsung (*in-place upgrade*) tanpa pernah kehilangan database SQLCipher maupun kunci identitas E2EE mereka.

## 12.3 Definition of Done (DoD) Rilis Produksi v2.0

Adoetz Chat 2 (`com.adoetzchat2.chat`) dinyatakan lulus dan siap rilis apabila memenuhi seluruh kriteria berikut:
1. **Identitas & Pembaruan Paket:** APK terinstal dengan *package name* `com.adoetzchat2.chat` dan dapat diperbarui (*update*) di atas versi sebelumnya tanpa merusak database lokal SQLCipher.
2. **Registrasi Atomik & Anti-Abuse:** Pendaftaran terbuka tanpa kode undangan berjalan atomik melalui trigger database; upaya melewati UI dengan memanggil endpoint Auth secara langsung tanpa token Turnstile atau mencoba menyuntikkan `"role": "admin"` di metadata terbukti ditolak $100\%$.
3. **Kepatuhan Desain Visual (Visual Quality Gate):** Seluruh 25 layar menggunakan token **Precision Neutral Messenger v2.0** (Dark Charcoal & Crisp Light), lulus uji skala huruf sistem $200\%$, bebas dari efek neon/gradien AI, dan menjaga kelancaran $60\text{ fps}$ saat melakukan *scroll* ruang chat.
4. **Ketahanan E2EE & Offline:** Seluruh pesan teks, lampiran dokumen/media, dan *voice note* terbukti terenkripsi sebelum meninggalkan perangkat; skenario putus koneksi di tengah pengiriman berhasil pulih otomatis tanpa duplikasi pesan.
5. **Keandalan Panggilan & Kendali Admin:** Panggilan WebRTC 1:1 berfungsi lintas jaringan seluler melalui TURN ephemeral; seluruh tindakan admin tercatat di *audit log* dan penangguhan akun langsung memutus akses pengguna secara *real-time*.