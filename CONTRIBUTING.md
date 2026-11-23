# Kontribusi

Terima kasih sudah tertarik membantu Wave Music. Proyek ini adalah aplikasi
pribadi/edukasi, tetapi kontribusi berupa laporan bug, perbaikan kecil, dan
dokumentasi tetap diterima.

## Menjalankan Proyek

Prasyarat:

- Flutter **3.47.7** (versi yang dipakai CI).
- Dart 3.13+.
- Untuk Android: JDK 17 dan Android SDK.
- Untuk Windows: Visual Studio dengan toolchain Desktop C++.

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows   # atau flutter run -d <device-android>
```

Tes integrasi jaringan bersifat opsional dan tidak berjalan di CI:

```bash
# PowerShell
$env:WAVE_NETWORK_TESTS=1; flutter test
```

## Aturan Perubahan

- Jalankan `flutter analyze` dan `flutter test` sebelum membuka pull request.
- Jangan mengklaim perilaku yang belum diuji sebagai "sudah beres".
- Pertahankan ID internal (`com.david.spotify_pribadi`) dan channel notifikasi
  lama agar pembaruan tidak bentrok.
- Jangan menambahkan binary APK/keystore ke Git. Distribusi lewat GitHub
  Releases.
- Ikuti gaya kode di sekitarnya: komentar bahasa Indonesia, nama class bahasa
  Inggris, dan penjelasan alasan pada logika yang tidak obvious.

## Format Commit

Gunakan Conventional Commits singkat:

```text
feat(storage): tambah panel pembersihan cache
fix(player): pulihkan posisi lagu setelah aplikasi ditutup
docs(readme): jelaskan perbedaan APK 64-bit dan 32-bit
```

## Rilis

1. Ubah `version` di `pubspec.yaml` dan `versionCode`/`versionName` di
   `version.json`.
2. Perbarui `CHANGELOG.md`.
3. Jalankan `flutter analyze` dan `flutter test`.
4. Commit, lalu push tag:

   ```bash
   git tag v1.2.0
   git push origin v1.2.0
   ```

5. Workflow `Build and Release Android APK` membangun kedua APK per-ABI,
   membuat `SHA256SUMS.txt`, dan mempublikasikan GitHub Release.

### Signing Rilis

Repo utama `yehudaaadev/spofree` sudah memakai signing resmi; keystore
disimpan di luar repo dan hanya dimasukkan ke secret. Untuk fork atau build
sendiri, tambahkan secret berikut di **Settings → Secrets and variables → Actions**:

| Secret | Isi |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | isi keystore `.jks` yang di-encode base64 |
| `ANDROID_KEYSTORE_PASSWORD` | password keystore |
| `ANDROID_KEY_ALIAS` | alias kunci |
| `ANDROID_KEY_PASSWORD` | password kunci |

Workflow akan membuat `android/key.properties` dan memakai keystore tersebut
hanya bila `ANDROID_KEYSTORE_BASE64` tersedia. Jangan pernah commit keystore
atau `key.properties`; keduanya sudah masuk `.gitignore`.

## Lisensi

Dengan berkontribusi, kamu setuju bahwa kontribusimu dilisensikan di bawah
[MIT](LICENSE).
