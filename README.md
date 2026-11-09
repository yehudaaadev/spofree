# Spotify Free by David

Aplikasi pemutar musik mandiri berpenampilan Spotify Premium dengan antarmuka gelap, ekstraksi streaming audio YouTube bebas iklan, katalog metadata Deezer, sinkronisasi cloud Firestore, dan fitur unduhan offline.

## Fitur Utama

- Autentikasi Username & Password: Login dan registrasi mandiri menggunakan Firebase Auth tanpa perlu input email panjang.
- Tampilan Spotify Premium: Antarmuka gelap (Dark UI) dengan Mini-Player mengambang dan Full-Screen Player Sheet interaktif.
- Audio Tanpa Iklan: Ekstraksi stream audio langsung dari YouTube via `youtube_explode_dart`.
- Metadata & Cover Art HD: Mengambil judul rapi, artis, dan cover art kotak 1:1 dari Deezer Public API.
- Download Offline: Mengunduh file audio fisik (.m4a) ke penyimpanan lokal perangkat untuk diputar saat tanpa internet.
- Lirik Lagu Terjadwal (Synced Lyrics): Sinkronisasi lirik per detik otomatis dari LrcLib API.
- Background & Lockscreen Playback: Terintegrasi dengan Android Media Notification & Lockscreen controls menggunakan `just_audio_background`.
- CI/CD Otomatis: GitHub Actions workflow untuk pengujian dan build APK rilis otomatis di setiap push branch `main`.

## Arsitektur & Teknologi

- Framework: Flutter (Dart 3.7+)
- Mesin Audio: `just_audio`, `just_audio_background`, `audio_session`
- Scraper: `youtube_explode_dart`
- Cloud & Auth: `firebase_core`, `firebase_auth`, `cloud_firestore`
- Penyimpanan Lokal: `shared_preferences`, `path_provider`, `dio`
- State Management: `provider`
- Desain UI: `cached_network_image`, `lucide_icons`

## Menjalankan Proyek

1. Pasang dependencies:
   ```bash
   flutter pub get
   ```

2. Jalankan analisis statis:
   ```bash
   flutter analyze
   ```

3. Jalankan aplikasi di perangkat/emulator:
   ```bash
   flutter run
   ```

4. Bangun APK rilis:
   ```bash
   flutter build apk --release
   ```
