@echo off
title Wave Music - Reset & Jalankan dari Awal
echo Mereset riwayat dan persetujuan awal (Onboarding)...
powershell -Command "if (Test-Path '$env:APPDATA\com.david\spotify_pribadi\shared_preferences.json') { Remove-Item -Force '$env:APPDATA\com.david\spotify_pribadi\shared_preferences.json' }"
cd /d "%~dp0build\windows\x64\runner\Release"
echo Membuka Wave Music Desktop dari halaman Onboarding pertama kali...
start "" "spotify_pribadi.exe"
exit
