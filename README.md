# Wave Music (Standalone Music Player)

[![Download APK](https://img.shields.io/badge/Download_APK-Langsung_Pasang_(26_MB)-2ea44f?style=for-the-badge&logo=android&logoColor=white)](https://gitlab.com/davidyehudaaa/spotify-gratis/-/raw/main/apk/WaveMusic.apk?inline=false)

> **Unduh & Pasang Langsung di HP Android:**
> - [Download WaveMusic.apk (ARM64 - Rekomendasi Semua HP Modern)](https://gitlab.com/davidyehudaaa/spotify-gratis/-/raw/main/apk/WaveMusic.apk?inline=false)
> - [Download WaveMusic-arm32.apk (Alternatif HP Android Lama)](https://gitlab.com/davidyehudaaa/spotify-gratis/-/raw/main/apk/WaveMusic-arm32.apk?inline=false)
>
> *Cara Pasang:* Ketuk link di atas untuk download langsung, lalu buka file APK di HP dan aktifkan izin "Install unknown apps" jika diminta.

Aplikasi pemutar musik mandiri berpenampilan Spotify Premium dengan audio stream YouTube bebas iklan, cover art resmi Deezer HD 1:1, unduhan offline, dan lirik sinkron.

**Tanpa login, tanpa akun, tanpa cloud.** Aplikasi langsung terbuka ke beranda musik saat dipasang. Lagu disukai, playlist, dan riwayat disimpan lokal di perangkat.

## Seluruh Fitur yang Tersedia

### 1. Fitur Premium Playback & Desain Modern
- Bebas Iklan 100% (ekstraksi stream audio murni).
- On-Demand Playback & Unlimited Skips (tanpa shuffle paksa dan tanpa batas skip).
- Scrubbing Seekbar bebas maju-mundur detik lagu.
- Background & Lockscreen Playback dengan kontrol media Android 13+ (`POST_NOTIFICATIONS`).
- **Solid Spotify Mini Player**: Permukaan solid gelap khas Spotify (`#282828` dengan batas `#383838`), animasi Mini Equalizer 3-bar dinamis saat lagu diputar, dan gestur geser horizontal (*swipe left/right*) untuk berpindah lagu dengan haptic feedback.
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
- Crossfade Transisi (Pilihan 0-12 detik untuk perpindahan lagu mulus tanpa jeda sunyi).
- Pilihan Kualitas Audio Bitrate (Hemat 64 kbps, Standar 128 kbps, Tinggi HQ 160-256 kbps, Maksimal 320 kbps).
- **Smart Autoplay / Track Radio**: Saat antrean habis, aplikasi mengambil daftar dari endpoint `artist/{id}/radio` Deezer yang disusun berdasarkan karakter lagu (genre/era), bukan sekadar nama artis — jadi dari "Tulus" radio bisa menyeber ke genre lain, bukan numpuk lagu Tulus. Lagu yang sudah diputar dicatat di riwayat radio agar tidak diulang. Tersedia opsi "CAMPUR LAGU GLOBAL" untuk menyisipkan lagu chart global, dan dapat diaktifkan/dinonaktifkan lewat toggle di opsi pemutar.
- Antrean Lagu Interaktif (Queue Sheet dengan fitur geser urutan / drag-and-drop).
- Riwayat "Baru Saja Diputar" (Recently Played).

### 3. Eksplorasi & Beranda Pintar
- **Spotify 6-Grid Quick Access**: Pintasan cepat 6 kartu lagu teratas dan lagu baru diputar tepat di bawah ucapan selamat datang beranda.
- **Filter Mood & Kategori**: Filter chip instan (Semua, Pop Indonesia, Top Global, Lofi Santai, Rock, Akustik, K-Pop) dengan pembaruan daftar lagu instan.
- **Genre & Mood Browse Hub**: 10 kartu kategori gradien kontras tinggi pada layar pencarian untuk eksplorasi lagu cepat 1-ketukan.
- **Riwayat Pencarian Terkini**: Tag pencarian terakhir yang dapat dipilih kembali atau dihapus.
- **Generator Kartu Kutipan Lirik (Spotify Story Card)**: Bagikan kutipan lirik favorit ke media sosial lengkap dengan background gradien, cover album, dan nama artis.

### 4. Koleksi, Impor & Offline Mode
- Unduh Offline File Fisik ke memori HP dengan **ekstensi sesuai format asli** (`.mp3`, `.m4a`, `.webm`, `.opus`, `.flac`, `.wav`), dideteksi otomatis dari magic bytes berkas.
- Ekspor ke Folder Publik HP dengan penyematan ID3 Tag + Cover Art HD otomatis **untuk berkas MP3**; kontainer lain diekspor apa adanya dengan ekstensi yang benar (tidak ada lagi pemalsuan ekstensi `.mp3`).
- Impor Playlist dari Tautan Spotify dan YouTube Playlist secara instan.
- Pemindai File Audio Lokal HP (.mp3, .m4a, .flac, .wav, .aac, .ogg, .opus, .webm) langsung dari tab Koleksi.
- Bulk Download ("Download Semua") untuk seluruh lagu di playlist/liked sekaligus.
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
│  ├─ download_service.dart  Unduh offline (per potongan), deteksi format, ekspor + ID3
│  ├─ audio_format.dart      Deteksi kontainer dari magic bytes
│  ├─ storage_permission_service.dart  Jembatan izin storage ke native Android
│  ├─ local_library_service.dart  Penyimpanan koleksi (disukai + playlist) di perangkat
│  ├─ local_audio_service.dart  Pindai file audio lokal
│  ├─ id3_writer.dart        Penulis tag ID3v2.3 (TIT2/TPE1/TALB/APIC)
│  └─ (tanpa Firebase / tanpa service auth)
├─ screens/                  main_screen, home_tab, search_tab, library_tab
└─ widgets/                  player_sheet, mini_player, queue_sheet, equalizer_sheet,
                              sleep_timer_dialog, playback_options_sheet, vinyl_disc_widget,
                              mini_visualizer, lyric_share_dialog, export_audio_dialog,
                              import_playlist_dialog, app_logo
```

Catatan perilaku penting:
- Semua permintaan playback diserialisasi (antrean internal) sehingga tap cepat tidak menimpa sumber audio; permintaan lama yang sudah digantikan dibatalkan. Future `play()` tidak pernah di-await di dalam antrean tersebut, karena future itu baru selesai saat lagu berakhir dan akan mengunci antrean.
- **Stream YouTube diambil per potongan dengan header `Range`.** CDN `googlevideo.com` membalas HTTP 403 untuk permintaan tanpa `Range`, untuk `Range` tanpa batas atas (`bytes=0-`), dan untuk rentang yang terlalu besar. ExoPlayer membuka media progresif tanpa `Range`, sehingga audio tidak bisa diberikan langsung sebagai `AudioSource.uri`. Aplikasi memakai `YouTubeStreamSource` (API `StreamAudioSource` dari just_audio) yang menarik data per 256 KB dengan `Range` eksplisit, lalu disajikan ke ExoPlayer lewat proxy lokal just_audio.
- URL stream YouTube memiliki masa hidup singkat dan terikat pada IP perangkat: cache dibatasi 3 jam, dan saat CDN membalas 403 aplikasi otomatis me-resolve URL baru lalu melanjutkan.
- **Satu URL stream = satu "sesi" dengan kuota data.** CDN hanya mengizinkan pembacaan berurutan mulai dari byte 0 dalam jumlah tertentu sebelum membalas 403. Aplikasi menanganinya dengan membuat sesi baru lewat manifest baru lalu melanjutkan pembacaan. Bila CDN membatasi keras (mis. IP datacenter atau akses terbatasi), aplikasi menampilkan pesan yang jelas, bukan menggantung di detik 0.
- Permintaan antar potongan dijeda 150 ms agar pola lalu lintas tidak dianggap mencurigakan oleh CDN.
- Bila stream Opus/WebM gagal dimuat atau tidak bisa didekode perangkat, aplikasi mencoba sekali lagi dengan stream MP4 (AAC) yang lebih universal.
- Bila sumber audio tidak selesai dimuat dalam 30 detik, pemutar berhenti menampilkan spinner dan menampilkan pesan error beserta tombol "Coba lagi".
- Unduhan offline memakai mekanisme `Range` yang sama. Bila CDN membatasi, berkas yang terpotong **tidak** disimpan dan pengguna diberi tahu, bukan disimpan sebagai berkas rusak.
- Error playback ditampilkan di level utama aplikasi (bukan hanya di panel pemutar penuh), sehingga tetap terlihat saat lagu diputar dari Home, Pencarian, atau Koleksi.
- Shuffle memakai generator acak sejati, bukan `DateTime.now().millisecond`.
- Antrean dibatasi 300 lagu dan tambahan autoplay dibatasi 15 lagu per siklus.

## Izin Penyimpanan (Android 11+)

Android 11 menghapus `requestLegacyExternalStorage`. Aplikasi kini meminta izin
"Akses semua file" (`MANAGE_EXTERNAL_STORAGE`) melalui MethodChannel
`com.david.spotify_pribadi/storage` ketika pengguna exporting berkas ke folder
HP atau memindai berkas audio lokal. Izin yang ditolak ditangani dengan pesan
yang jelas, bukan diam-diam gagal.

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

3. Lokasi APK:

   - `release_apk/` (Salinan aman permanen, sudah dipecah per-ABI agar unduhan hemat kuota)
   - `build/app/outputs/flutter-apk/` (Output Gradle)

   Berkas per-ABI:
   - `app-arm64-v8a-release.apk` — HP modern (Android 7+ ARM 64-bit), **paling hemat kuota**.
   - `app-armeabi-v7a-release.apk` — HP lama ARM 32-bit.
   - `app-x86_64-release.apk` — hanya untuk emulator.

   Pasang di HP: salin APK ke HP lalu ketuk file-nya (aktifkan "Install unknown apps" bila diminta).

## Pengujian

```bash
flutter analyze
flutter test
```

Tes unit mencakup deteksi format audio, pemetaan kualitas bitrate dan pemilihan
stream, parser lirik LRC, serialisasi `TrackModel`, penulisan tag ID3, pembuatan
nama berkas ekspor, serta parsing header `Range`/`Content-Range` untuk pengambilan
stream YouTube.
