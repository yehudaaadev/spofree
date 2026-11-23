# Wave Music

<p align="center">
  <a href="https://github.com/yehudaaadev/spofree/releases/latest/download/WaveMusic-arm64-v8a.apk">
    <img src="https://img.shields.io/badge/Download_64--bit-F43F5E?style=for-the-badge&logo=android&logoColor=white" alt="Download APK 64-bit">
  </a>
  <a href="https://github.com/yehudaaadev/spofree/releases/latest/download/WaveMusic-armeabi-v7a.apk">
    <img src="https://img.shields.io/badge/Download_32--bit-16161B?style=for-the-badge&logo=android&logoColor=white" alt="Download APK 32-bit">
  </a>
</p>

<p align="center">
  <a href="https://github.com/yehudaaadev/spofree/releases/latest">
    <img src="https://img.shields.io/github/v/release/yehudaaadev/spofree?style=for-the-badge&color=F43F5E&label=versi" alt="Versi terbaru">
  </a>
  <img src="https://img.shields.io/badge/Android-7%2B-16161B?style=for-the-badge&logo=android" alt="Android 7+">
  <img src="https://img.shields.io/badge/Windows-Desktop-16161B?style=for-the-badge&logo=windows" alt="Windows Desktop">
  <a href="LICENSE"><img src="https://img.shields.io/badge/Lisensi-MIT-F43F5E?style=for-the-badge" alt="Lisensi MIT"></a>
</p>

<p align="center">
  <strong>Versi 1.1.0 · build 6</strong>
</p>

| Pilih APK | Untuk perangkat | Catatan |
|---|---|---|
| **`WaveMusic-arm64-v8a.apk`** | HP Android **64-bit** — mayoritas HP 2016 ke atas | Disarankan, ukuran lebih kecil |
| **`WaveMusic-armeabi-v7a.apk`** | HP Android **32-bit** — HP lama / entry-level | Untuk HP yang tidak mendukung 64-bit |

> **Ini bukan beda versi Android.** Keduanya mendukung Android 7+. Bedanya
> adalah arsitektur CPU: **64-bit (arm64-v8a)** vs **32-bit (armeabi-v7a)**.
> Kalau ragu, coba yang **64-bit** dulu; kalau gagal dipasang, gunakan yang
> **32-bit**.

> **Status distribusi:** Wave Music adalah proyek pribadi/edukasi. APK saat ini
> dibangun tanpa keystore rilis resmi, jadi gunakan untuk pengujian pribadi.
> Jangan menyebarkan APK yang memuat rekaman berhak cipta.

Aplikasi pemutar musik mandiri berpenampilan modern dalam tema **Rose Pink & Obsidian Charcoal** (`#F43F5E` & `#0E0E11`) dengan audio stream YouTube bebas iklan, cover art resmi Deezer HD 1:1, unduhan offline, lirik sinkron, dan dukungan pemutaran audio lintas-platform (Android & Windows Desktop).

**Tanpa login, tanpa akun, tanpa cloud.** Dilengkapi layar pengenalan (*onboarding walkthrough*) 3 slide interaktif pada pemasangan pertama. Lagu disukai, playlist, dan riwayat disimpan 100% lokal di perangkat.

## Seluruh Fitur yang Tersedia

### 1. Fitur Premium Playback & Desain Modern
- **Tema Visual Duo A (Rose & Obsidian)**: Perpaduan aksen Rose Pink (`#F43F5E`) dan latar belakang Obsidian Charcoal (`#0E0E11` & `#16161B`) yang dirancang khusus agar tidak norak, berkontras tajam (lolos WCAG AA/AAA), dan hemat daya pada layar OLED/AMOLED.
- **Layar Onboarding Penuh (3 Slide)**: Sambutan visual interaktif bagi pengguna baru (Piringan Hitam Bebas Akun, Fitur Studio & SponsorBlock, Transparansi Lisensi & Pengembang) sebelum masuk ke pemutar musik.
- Bebas Iklan 100% (ekstraksi stream audio murni).
- On-Demand Playback & Unlimited Skips (tanpa shuffle paksa dan tanpa batas skip).
- Scrubbing Seekbar bebas maju-mundur detik lagu.
- Background & Lockscreen Playback dengan kontrol media Android 13+ (`POST_NOTIFICATIONS`).
- **Dukungan Audio Windows Desktop**: Dilengkapi backend Media Foundation native (`just_audio_windows`) sehingga lagu dapat berbunyi langsung di Windows Desktop selain di Android.
- **Solid Rose Mini Player**: Permukaan solid arang gelap (`#16161B`), animasi Mini Equalizer dinamis beraksen Rose Pink saat lagu diputar, dan gestur geser horizontal (*swipe left/right*) untuk berpindah lagu dengan haptic feedback.
- **Proteksi Audio & Headset**: Otomatis menjeda musik saat earphone/Bluetooth dicabut (`becomingNoisy`) dan menangani interupsi panggilan telepon secara cerdas.
- **Pengecekan Pembaruan & Bantuan Baterai**: Pengecekan update APK otomatis dari GitLab dan tombol pintasan optimasi baterai (Doze mode) untuk ponsel Xiaomi/HyperOS, Oppo, Vivo, dan Samsung.
- **Mode Piringan Hitam (Vinyl Disc)**: Pilihan tampilan cover art klasik atau piringan hitam vinyl berputar mulus 360 derajat lengkap dengan alur refleksi cahaya realistis.
- **Dynamic Ambient Glow & Artwork Breathing**: Pantulan cahaya radial di belakang album art yang membesar saat lagu diputar dan mengecil lembut saat dijeda.

### 2. Fitur Audio Tuning & Kenyamanan
- Dynamic Ambient Background Glow (warna latar player berganti mengikuti cover art).
- Sleep Timer dengan gradual volume fade-out (5m, 15m, 30m, 45m, 1 jam, dan selesai lagu).
- Kontrol Kecepatan Pemutaran (0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 2.0x).
- Equalizer & Bass Boost (Preset Flat, Bass Boost, Rock, Pop, Vocal, Acoustic, Electronic, dan slider bass boost). Equalizer native hanya berjalan di Android; di platform lain kontrol Equalizer dinonaktifkan otomatis dan disertai keterangan.
- Pitch Shift & Mode Vokal (Transpose nada semitone naik/turun, preset Karaoke, Slowed + Reverb, dan Nightcore).
- Fade-out Antar-Lagu (0-12 detik): volume lagu lama menurun sebelum lagu baru mulai. Ini bukan crossfade sejati; masih ada jeda singkat antar-lagu.
- **SponsorBlock Otomatis**: Otomatis mendeteksi dan melewati bagian percakapan non-musik, intro hening, outro panjang, atau sponsor pada audio video YouTube via API SponsorBlock (`sponsor.ajay.app`).
- **Dua Lapis Antrean ("Putar Berikutnya" / Play Next)**: Menyisipkan lagu tepat setelah lagu yang sedang diputar sebelum melanjutkan urutan album/playlist asli.
- **Cadangan Universal (M3U & JSON Backup)**: Ekspor dan pulihkan seluruh lagu disukai dan playlist ke format berkas M3U standar atau JSON mandiri.
- Pilihan Kualitas Audio (Hemat 64 kbps, Standar 128 kbps, Tinggi 160 kbps, dan Otomatis). Bitrate aktual mengikuti stream YouTube yang tersedia (umumnya maksimal ~160 kbps); label "320 kbps" pada versi lama tidak pernah tercapai.
- **Smart Autoplay / Track Radio**: Saat antrean habis, aplikasi mengambil daftar dari endpoint `artist/{id}/radio` Deezer yang disusun berdasarkan karakter lagu (genre/era), bukan sekadar nama artis — jadi dari "Tulus" radio bisa menyeber ke genre lain, bukan numpuk lagu Tulus. Lagu yang sudah diputar dicatat di riwayat radio agar tidak diulang. Tersedia opsi "CAMPUR LAGU GLOBAL" untuk menyisipkan lagu chart global, dan dapat diaktifkan/dinonaktifkan lewat toggle di opsi pemutar.
- Antrean Lagu Interaktif (Queue Sheet dengan fitur geser urutan / drag-and-drop).
- Riwayat "Baru Saja Diputar" (Recently Played).

### 3. Eksplorasi & Beranda Pintar
- **Hasil Teratas Kanonikal (Top Result Card)**: Algoritma pencarian kanonikal yang memprioritaskan versi resmi berotoritas tinggi (popularitas organik YouTube & Deezer, kesepakatan konsensus ganda, serta kanal Topic/VEVO resmi) disajikan dalam kartu sorotan "Hasil Teratas" modern lengkap dengan badge rekomendasi utama dan tombol putar instan.
- **Menu Tindakan Cepat Lagu (Titik Tiga)**: Tombol opsi (`more_vert`) pada seluruh item hasil pencarian (Hasil Teratas dan daftar lagu) yang membuka menu pintasan: Sukai lagu (Like), Download offline instan 1-ketukan, Tambah ke Playlist (lengkap dengan pembuatan playlist baru instan), Putar Berikutnya (Play Next), dan Tambah ke Antrean.
- **Quick Access 6-Grid**: Pintasan cepat 6 kartu lagu teratas dan lagu baru diputar tepat di bawah ucapan selamat datang beranda.
- **Filter Mood & Kategori**: Filter chip instan (Semua, Pop Indonesia, Top Global, Lofi Santai, Rock, Akustik, K-Pop) dengan pembaruan daftar lagu instan.
- **Genre & Mood Browse Hub**: 10 kartu kategori gradien kontras tinggi pada layar pencarian untuk eksplorasi lagu cepat 1-ketukan.
- **Riwayat Pencarian Terkini**: Tag pencarian terakhir yang dapat dipilih kembali atau dihapus.
- **Generator Kartu Kutipan Lirik**: Bagikan kutipan lirik favorit ke media sosial lengkap dengan background gradien, cover album, dan nama artis.

### 4. Koleksi, Impor & Offline Mode
- Unduh Offline File Fisik ke memori HP dengan **ekstensi sesuai format asli** (`.mp3`, `.m4a`, `.webm`, `.opus`, `.flac`, `.wav`), dideteksi otomatis dari magic bytes berkas.
- Ekspor ke Folder Publik HP dengan penyematan ID3 Tag + Cover Art HD otomatis **untuk berkas MP3**; kontainer lain diekspor apa adanya dengan ekstensi yang benar (tidak ada lagi pemalsuan ekstensi `.mp3`).
- Impor Playlist dari Tautan Spotify dan YouTube Playlist secara instan.
- Pemindai File Audio Lokal HP (.mp3, .m4a, .flac, .wav, .aac, .ogg, .opus, .webm) langsung dari tab Koleksi.
- Bulk Download ("Download Semua") untuk seluruh lagu di playlist/liked sekaligus.
- **Pengurutan Kronologis Lagu Disukai (LIFO / Timestamp)**: Menyimpan timestamp `likedAt` saat lagu disukai pengguna dan otomatis menempatkan lagu yang baru disukai di posisi teratas koleksi secara kronologis beserta tanggal penambahan.
- Koleksi tersimpan lokal di perangkat: Lagu Disukai, Playlist, dan riwayat "Baru Saja Diputar" tetap ada antar-jalankan aplikasi (tanpa perlu akun).

## Arsitektur Singkat

```
lib/
├─ main.dart                 MultiProvider (Library, Player) -> MainScreen (langsung, tanpa login)
├─ models/track_model.dart   TrackModel + mimeType + durasi jujur (0 = tidak diketahui)
├─ providers/                LibraryProvider, PlayerProvider (ChangeNotifier)
├─ services/
│  ├─ music_service.dart     Deezer (katalog) + resolusi stream YouTube (cache TTL 3 jam)
│  ├─ youtube_client.dart    Klien YoutubeExplode tunggal (mencegah kebocoran koneksi)
│  ├─ youtube_stream_source.dart  Stream audio YouTube via Range request terbatasi
│  ├─ ranged_http_client.dart      Klien HTTP dengan header `Range` terbatasi
│  ├─ playlist_import_service.dart  Impor playlist Spotify (embed __NEXT_DATA__) & YouTube
│  ├─ lyrics_service.dart    LRCLIB + parser LRC murni (dapat diuji)
│  ├─ download_service.dart  Unduh offline (per potongan), validasi utuh, ekspor + ID3
│  ├─ audio_cache_service.dart  Cache LRU 300 MB dengan permintaan Range + validasi
│  ├─ audio_format.dart      Deteksi kontainer dari magic bytes
│  ├─ stable_hash.dart       Hash FNV-1a stabil untuk nama cache/ID lokal
│  ├─ storage_permission_service.dart  Jembatan izin storage/notifikasi ke native Android
│  ├─ local_library_service.dart  Penyimpanan koleksi (disukai + playlist) di perangkat
│  ├─ local_audio_service.dart  Pindai file audio lokal
│  ├─ id3_writer.dart        Penulis tag ID3v2.3 (TIT2/TPE1/TALB/APIC)
│  └─ (tanpa Firebase / tanpa service auth)
├─ screens/                  main_screen, onboarding_screen, home_tab, search_tab, library_tab
└─ widgets/                  player_sheet, mini_player, queue_sheet, equalizer_sheet,
                              sleep_timer_dialog, playback_options_sheet, vinyl_disc_widget,
                              mini_visualizer, lyric_share_dialog, export_audio_dialog,
                              import_playlist_dialog, app_logo, terms_dialog
```

Catatan perilaku penting:
- **Pencarian Cerdas Paralel (Hybrid Search Engine)**: Pencarian mengeksekusi Deezer API dan pencarian YouTube secara paralel, membersihkan judul video dari tag pengganggu seperti `[Official Video]`, `(Lyrics)`, menyaring video lirik amatir dan kompilasi durasi panjang (>15 menit), serta mengurutkan hasil berdasarkan bobot relevansi agar lagu artis resmi selalu di urutan teratas.
- Semua permintaan playback diserialisasi (antrean internal) sehingga tap cepat tidak menimpa sumber audio; permintaan lama yang sudah digantikan dibatalkan. Future `play()` tidak pernah di-await di dalam antrean tersebut, karena future itu baru selesai saat lagu berakhir dan akan mengunci antrean.
- **Pemutaran Instan & Direct Progressive Stream**: Resolusi stream audio YouTube menggunakan `requireWatchPage: false` (mempercepat pembuatan manifest dari ~1.5 detik menjadi ~350 ms). Mode **Otomatis** memprioritaskan stream progresif (`tag 18`, AAC stereo dalam MP4 dengan `ratebypass=yes`) yang diputar langsung via `AudioSource.uri(url, headers: ...)`. Pilihan 64/128/160 kbps memakai stream audio-only melalui proxy `YouTubeStreamSource` agar bitrate benar-benar diterapkan.
- **Fallback Stream Adaptif**: Jika stream progresif tidak tersedia, pemutar menggunakan `YouTubeStreamSource` (`StreamAudioSource`) dengan potongan aman 64 KB / 128 KB dan refresh URL otomatis.
- **Navigasi Antrean Berbasis Indeks Eksplisit**: Navigasi `playTrack`, `next()`, dan `previous()` menggunakan pelacakan indeks posisi antrean eksplisit sehingga lagu dengan ID serupa atau cover beruntun tidak menyebabkan snapping ke indeks awal.
- **Pre-resolusi Stream Lagu Berikutnya**: Saat sebuah lagu mulai diputar, URL stream lagu berikutnya di antrean di-resolve di latar belakang (tanpa mengunduh audio) agar perpindahan lagu lebih cepat. Cache audio hanya diisi setelah sumber benar-benar dipakai, sehingga tidak ada unduhan ganda.
- **Proteksi State Selesai (Zero-Second Completion Guard)**: Mencegah bug engine audio Windows (`just_audio_windows`) yang memancarkan status `completed` di detik 0 saat pembukaan media (`0 == 0`), sehingga lagu yang dipilih di Hasil Teratas maupun antrean tidak terlewat ke lagu berikutnya saat pertama kali diklik.
- URL stream YouTube memiliki masa hidup singkat dan terikat pada IP perangkat: cache dibatasi 3 jam, dan saat CDN membalas 403 aplikasi otomatis me-resolve URL baru lalu melanjutkan.
- Shuffle memakai generator acak sejati, bukan `DateTime.now().millisecond`.
- Antrean dibatasi 300 lagu dan tambahan autoplay dibatasi 15 lagu per siklus.

## Izin Penyimpanan (Android)

- `READ_EXTERNAL_STORAGE` dibatasi sampai Android 12 (`maxSdkVersion=32`).
- `WRITE_EXTERNAL_STORAGE` dibatasi sampai Android 10 (`maxSdkVersion=29`).
- `MANAGE_EXTERNAL_STORAGE` hanya diminta saat pengguna mengekspor lagu ke
  folder publik atau memindai berkas audio lokal. Aplikasi ini didistribusikan
  mandiri (bukan lewat Google Play), sehingga izin tersebut tidak melanggar
  kebijakan toko.
- `POST_NOTIFICATIONS` diminta saat aplikasi dibuka (Android 13+) agar kontrol
  pemutaran tampil di laci notifikasi.

Izin yang ditolak ditangani dengan pesan yang jelas, bukan diam-diam gagal.
Ekspor juga memiliki fallback ke folder dokumen aplikasi bila folder publik
tidak dapat ditulis.

## Cleartext HTTP Lokal (Android)

just_audio menyajikan `StreamAudioSource` melalui server HTTP lokal, jadi
ExoPlayer perlu mengakses `127.0.0.1` lewat protokol cleartext. Untuk itu
`android/app/src/main/res/xml/network_security_config.xml` mengizinkan cleartext
**hanya** untuk `127.0.0.1` dan `localhost`; seluruh host lain tetap wajib
HTTPS. Jangan mengganti aturan ini dengan `android:usesCleartextTraffic="true"`.

## Build APK Rilis

1. Siapkan keystore rilis dan buat `android/key.properties` (file ini sudah masuk `.gitignore`):

   ```properties
   storeFile=../wave-music-release.jks
   storePassword=...
   keyAlias=wave-music
   keyPassword=...
   ```

   Tanpa `key.properties`, build rilis memakai debug key (hanya untuk pengujian
   lokal, tidak dapat dipublikasikan) dan Gradle akan menampilkan peringatan.

2. Build (tanpa Firebase, tanpa kredensial yang perlu diisi):

   ```bash
   flutter build apk --release --split-per-abi
   ```

3. Lokasi APK (hanya lokal, tidak di-commit ke Git):

   - `release_apk/` (salinan lokal yang sudah dipecah per-ABI)
   - `build/app/outputs/flutter-apk/` (output Gradle)

   Berkas per-ABI:
   - `app-arm64-v8a-release.apk` — HP Android **64-bit** (mayoritas HP 2016+), **disarankan**.
   - `app-armeabi-v7a-release.apk` — HP Android **32-bit** (HP lama / entry-level).
   - `app-x86_64-release.apk` — **hanya emulator**, jangan dipasang di HP.

   Keduanya mendukung Android 7+. Bedanya arsitektur CPU, bukan versi Android.

   Pasang di HP: salin APK ke HP lalu ketuk file-nya (aktifkan "Install unknown apps" bila diminta).

4. Untuk distribusi, push tag `v*` (misalnya `v1.1.1`). Workflow GitHub Actions
   otomatis membangun dan melampirkan kedua APK ke **GitHub Releases**. Repo ini
   tidak menyimpan binary APK.

## Pengujian

```bash
flutter analyze
flutter test
```

CI GitLab (`.gitlab-ci.yml`) menjalankan kedua perintah tersebut pada setiap
merge request dan branch.

Saat ini ada 99 tes yang lulus (4 tes integrasi CDN YouTube dilewati secara
default). Cakupannya: deteksi format audio, pemetaan kualitas bitrate dan
pemilihan stream, parser lirik LRC, serialisasi `TrackModel`, penulisan tag ID3,
pembuatan nama berkas ekspor, validasi `Range`/`Content-Range` (termasuk server
lokal), backup JSON v1/v2, antrean "Putar Berikutnya", dan SponsorBlock.

Tes integrasi CDN YouTube dilewati secara default. Jalankan dengan:

```bash
WAVE_NETWORK_TESTS=1 flutter test test/youtube_stream_source_test.dart
```

## Privasi

- Tidak ada akun, login, cloud sync, analytics, atau iklan pihak ketiga.
- Lagu disukai, playlist, riwayat, pengaturan, dan unduhan disimpan lokal di
  perangkat.
- Koneksi keluar hanya terjadi ke penyedia yang dibutuhkan fitur: Deezer
  (katalog/cover), YouTube (stream audio), LRCLIB (lirik), SponsorBlock
  (segmen sponsor), dan GitLab (cek versi).
- URL stream YouTube bersifat sementara dan tidak disimpan permanen.

## Lisensi, Merek & Pengembang

- **Pengembang**: David Yehuda Surbakti
- **Lisensi**: [MIT License](LICENSE) untuk kode sumber. Lisensi ini tidak
  memberikan hak atas konten musik, cover art, merek, atau layanan pihak ketiga.
- **Merek**: Wave Music tidak berafiliasi dengan Spotify, YouTube, Google, atau
  Deezer. Nama merek tersebut hanya digunakan secara nominatif untuk menjelaskan
  kompatibilitas impor/streaming.
- **Penafian Hak Cipta**: Wave Music tidak meng-host atau mendistribusikan berkas
  berhak cipta pada peladen mandiri. Seluruh lagu, rekaman suara, nama artis, dan
  sampul album sepenuhnya merupakan hak milik pencipta dan pemilik lisensi
  masing-masing. Pengguna bertanggung jawab mematuhi hukum dan Ketentuan Layanan
  penyedia sumber.
- **Penggunaan pribadi**: Repositori ini disediakan untuk pembelajaran dan
  penggunaan pribadi. Menyebarkan ulang APK atau konten berhak cipta dapat
  melanggar hukum dan Ketentuan Layanan pihak ketiga.
