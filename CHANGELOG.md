# Changelog

Semua perubahan penting pada Wave Music dicatat di sini.
Format mengikuti [Keep a Changelog](https://keepachangelog.com/id/1.1.0/),
dan versi mengikuti [Semantic Versioning](https://semver.org/lang/id/).

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
- **Dukungan signing rilis di CI.** APK otomatis ditandatangani bila secret
  keystore tersedia; tanpa secret, build memakai debug key.
- Dokumentasi: `CHANGELOG.md`, `CONTRIBUTING.md`, issue template, dan Dependabot.

### Diubah
- README menjelaskan dua APK per-ABI (64-bit dan 32-bit), checksum, dan cara
  verifikasi unduhan.
- Tautan pembaruan di aplikasi tidak lagi mengarah ke GitLab.

### Diperbaiki
- Posisi lagu tidak lagi hilang setelah aplikasi ditutup.
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
