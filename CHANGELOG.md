# Changelog

Semua perubahan penting pada Wave Music dicatat di sini.
Format mengikuti [Keep a Changelog](https://keepachangelog.com/id/1.1.0/),
dan versi mengikuti [Semantic Versioning](https://semver.org/lang/id/).

## [Unreleased]

### Ditambahkan
- **Berbagi playlist/lagu disukai tanpa server.** Setiap playlist punya tombol
  bagikan; seluruh Lagu Disukai bisa dibagikan dari panel Informasi & Bantuan.
  Data dipadatkan menjadi kode `WAVE1.` (gzip + base64url) yang bisa disalin,
  dikirim lewat aplikasi chat, atau ditampilkan sebagai QR.
- **Penerima kode & pemindai QR.** Panel "Terima Kode Playlist" menerima kode
  yang ditempel, seluruh teks pesan chat, atau hasil scan QR. Impor playlist
  bernama sama akan digabung tanpa duplikat; lagu yang sudah ada di Lagu
  Disukai dilewati.
- **Validasi kode berlapis.** Prefix/versi format, CRC gzip, batas panjang
  kode, batas hasil dekompresi (4 MB), batas jumlah lagu, dan pembersihan teks
  kontrol. Kode versi format baru menampilkan pesan agar aplikasi diperbarui.
- **QR scanner Android/iOS/macOS** lewat `mobile_scanner`; di Windows kode
  tetap bisa ditempel/dibagikan karena kamera tidak tersedia untuk fitur ini.
- Dependensi baru: `qr_flutter`, `mobile_scanner`, dan `share_plus`.

### Catatan
- Fitur ini sudah lolos `flutter analyze`, tes unit/widget, dan build APK
  rilis, tetapi **belum diuji pada perangkat fisik**. APK rilis publik terbaru
  masih v1.2.0 dan belum memuat fitur berbagi kode/QR. Build pengembangan
  sumber ini memakai versi 1.3.0 (Build 8).
- Ukuran APK bertambah karena ML Kit bawaan `mobile_scanner`; pemindaian QR
  dapat ditolak izin kameranya tanpa memblokir impor manual.

## [1.2.0] - 2026-11-23

### Ditambahkan
- **Pembaruan via GitHub Releases.** Pengecekan versi membaca `version.json`
  dari repo GitHub dan hanya membuka tautan resmi `github.com/yehudaaadev/spofree`.
- **Checksum SHA-256.** Workflow rilis membuat `SHA256SUMS.txt`; aplikasi
  menampilkan tombol untuk membuka berkas checksum.
- **Panel Penyimpanan.** Melihat ukuran cache audio, jumlah/ukuran unduhan
  offline, dan sisa ruang perangkat; bisa menghapus cache atau semua unduhan.
- **Lanjutkan antrean terakhir.** Antrean, indeks, dan posisi lagu disimpan
  otomatis dan dipulihkan saat aplikasi dibuka kembali (tanpa autoplay).
- **Pencarian dalam koleksi.** Cari berdasarkan judul, artis, atau album pada
  tab Lagu Disukai, Offline, dan File Lokal.
- **Cache lirik offline + offset.** Lirik disimpan 30 hari dan bisa digeser
  ±0,5 detik per lagu untuk menyelaraskan dengan audio.
- **Mode unduh hanya via Wi-Fi.** Mencegah kuota seluler terpakai saat
  mengunduh lagu offline.
- **Signing rilis permanen.** APK v1.2.0 ditandatangani dengan release key
  Wave Music (RSA 4096, berlaku sampai 2054), sehingga pembaruan berikutnya
  bisa dipasang di atas versi lama tanpa uninstall. CI memakai secret
  keystore; tanpa secret, build memakai debug key.
- Dokumentasi: `CHANGELOG.md`, `CONTRIBUTING.md`, issue template, dan Dependabot.

### Diubah
- README menjelaskan dua APK per-ABI (64-bit dan 32-bit), checksum, dan cara
  verifikasi unduhan.
- Tautan pembaruan di aplikasi tidak lagi mengarah ke GitLab.

### Diperbaiki
- Posisi lagu tidak lagi hilang setelah aplikasi ditutup.
- Pemeriksaan pembaruan tidak lagi terhalang offset `versionCode` APK
  `--split-per-abi`; perbandingan memakai `versionName` lebih dulu.
- `flutter analyze` tetap bersih dengan Flutter 3.47.7.

## [1.1.0] - 2026-11-23

### Ditambahkan
- Distribusi APK melalui GitHub Releases dengan aset `WaveMusic-arm64-v8a.apk`
  dan `WaveMusic-armeabi-v7a.apk`.
- Tombol unduh langsung dan badge versi di bagian atas README.
- Workflow GitHub Actions: analyze, test, build per-ABI, dan publikasi rilis
  otomatis saat tag `v*` di-push.

### Diubah
- Repo utama pindah ke `github.com/yehudaaadev/spofree`; GitLab tetap sebagai
  remote cadangan.
- Binary APK tidak lagi disimpan di Git.

## [1.0.0] - 2026-11-20

### Ditambahkan
- Pemutar musik Flutter dengan pencarian Deezer/YouTube, unduhan offline,
  lirik tersinkron, SponsorBlock, equalizer, dan tema Rose & Obsidian.
- Dukungan Android dan Windows Desktop.
