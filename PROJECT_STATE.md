# PROJECT STATE

## Overview
- Project Name: Wave Music (`spotify_pribadi`)
- Architecture: Standalone client-side music player (Zero-login, No-Firebase, 100% local persistence)
- Catalog & Streaming: Deezer API (metadata/cover art) + YouTube audio streams via custom chunked `Range` requests (`YouTubeStreamSource`)
- State Management: Provider (`PlayerProvider`, `LibraryProvider`)

## Critical Architecture Decisions
1. **Streaming Stability**: YouTube CDN (`googlevideo.com`) strictly enforces chunked `Range` requests (256 KB slices) and 150ms pauses between chunks. Exoplayer connects via just_audio's local proxy at `127.0.0.1` (`network_security_config.xml` restricts cleartext to localhost).
2. **Local Persistence**: All user data (Liked Songs, Custom Playlists, Recently Played) are stored locally via `LocalLibraryService` using `SharedPreferences`. No external cloud or database dependencies.
3. **Audio Export & Tagging**: Audio files are saved with native formats detected by header magic bytes (`AudioFormat.detect`). MP3 files receive ID3v2.3 tags (`Id3Writer`).
4. **Storage Permissions**: Android 11+ scoped storage / `MANAGE_EXTERNAL_STORAGE` bridged through `StoragePermissionService` MethodChannel (`com.david.spotify_pribadi/storage`).

## Verification Status
- Static Analysis: `flutter analyze` passed (0 issues).
- Unit Tests: `flutter test` passed (45/45 tests passing).
- Build: Release split-per-ABI APKs generated in `release_apk/`.
