# Wave Music (Standalone Music Player)

Aplikasi pemutar musik mandiri berpenampilan Spotify Premium dengan audio stream YouTube bebas iklan, cover art resmi Deezer HD 1:1, sinkronisasi cloud Firebase, unduhan offline, dan lirik sinkron.

## Seluruh Fitur yang Tersedia

### 1. Fitur Premium Playback & Desain Modern
- Bebas Iklan 100% (ekstraksi stream audio murni).
- On-Demand Playback & Unlimited Skips (tanpa shuffle paksa dan tanpa batas skip).
- Scrubbing Seekbar bebas maju-mundur detik lagu.
- Background & Lockscreen Playback dengan kontrol media Android.
- **Glassmorphic Mini Player**: Latar buram frosted glass dinamis, animasi Mini Equalizer 3-bar berdenyut saat lagu diputar, dan gestur geser horizontal (*swipe left/right*) untuk berpindah lagu berikutnya/sebelumnya dengan haptic feedback.
- **Mode Piringan Hitam (Vinyl Disc)**: Pilihan tampilan cover art klasik atau piringan hitam vinyl berputar mulus 360 derajat lengkap dengan alur refleksi cahaya realistis.
- **Dynamic Ambient Glow & Artwork Breathing**: Pantulan cahaya radial di belakang album art yang membesar saat lagu diputar dan mengecil lembut saat dijeda.

### 2. Fitur Audio Tuning & Kenyamanan
- Dynamic Ambient Background Glow (warna latar player berganti mengikuti cover art).
- Sleep Timer dengan gradual volume fade-out (5m, 15m, 30m, 45m, 1 jam, dan selesai lagu).
- Kontrol Kecepatan Pemutaran (0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 2.0x).
- Equalizer & Bass Boost (Preset Flat, Bass Boost, Rock, Pop, Vocal, Acoustic, Electronic, dan slider bass boost).
- Pitch Shift & Mode Vokal (Transpose nada semitone naik/turun, preset Karaoke, Slowed + Reverb, dan Nightcore).
- Crossfade Transisi (Pilihan 0-12 detik untuk perpindahan lagu mulus tanpa jeda sunyi).
- Pilihan Kualitas Audio Bitrate (Hemat 64 kbps, Standar 128 kbps, Tinggi HQ 160-256 kbps, Maksimal 320 kbps).
- **Smart Autoplay (Track Radio)**: Otomatis mengambil dan memutar lagu-lagu serupa/rekomendasi artis terkait saat antrean habis (misal saat mencari 1 lagu) tanpa membuat pemutaran berhenti, dapat diaktifkan/dinonaktifkan via tombol toggle di opsi pemutar.
- Antrean Lagu Interaktif (Queue Sheet dengan fitur geser urutan / drag-and-drop).
- Riwayat "Baru Saja Diputar" (Recently Played).

### 3. Eksplorasi & Beranda Pintar
- **Spotify 6-Grid Quick Access**: Pintasan cepat 6 kartu lagu teratas dan lagu baru diputar tepat di bawah ucapan selamat datang beranda.
- **Filter Mood & Kategori**: Filter chip instan (Semua, Pop Indonesia, Top Global, Lofi Santai, Rock, Akustik, K-Pop) dengan pembaruan daftar lagu instan.
- **Genre & Mood Browse Hub**: 10 kartu kategori gradien kontras tinggi pada layar pencarian untuk eksplorasi lagu cepat 1-ketukan.
- **Riwayat Pencarian Terkini**: Tag pencarian terakhir yang dapat dipilih kembali atau dihapus.
- **Generator Kartu Kutipan Lirik (Spotify Story Card)**: Bagikan kutipan lirik favorit ke media sosial lengkap dengan background gradien, cover album, dan nama artis.

### 4. Koleksi, Impor & Offline Mode
- Unduh Offline File Fisik (.m4a) ke memori HP.
- Ekspor ke Folder Publik (.mp3) dengan penanaman ID3 Tag dan Cover Art HD otomatis.
- Impor Playlist dari Tautan Spotify dan YouTube Playlist secara instan.
- Pemindai File Audio Lokal HP (.mp3, .m4a, .flac, .wav) langsung dari tab Koleksi.
- Bulk Download ("Download Semua") untuk seluruh lagu di playlist/liked sekaligus.
- Cloud Sync Liked Songs & Playlists via Cloud Firestore.
- Autentikasi Username & Password via Firebase Auth.

## Build APK Rilis

File APK versi terbaru siap instal tersedia di dua lokasi:
- `release_apk/WaveMusic-release.apk` (Salinan aman permanen)
- `build/app/outputs/flutter-apk/app-release.apk` (Output Gradle)
