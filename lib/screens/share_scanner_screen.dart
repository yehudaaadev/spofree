import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/playlist_share_service.dart';
import '../theme/app_theme.dart';

/// Layar pemindai QR untuk kode berbagi Wave Music.
class ShareCodeScannerScreen extends StatefulWidget {
  const ShareCodeScannerScreen({super.key});

  @override
  State<ShareCodeScannerScreen> createState() => _ShareCodeScannerScreenState();
}

class _ShareCodeScannerScreenState extends State<ShareCodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _handled = false;
  bool _torchEnabled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || !PlaylistShareService.looksLikeCode(raw)) continue;
      _handled = true;
      _controller.stop();
      if (mounted) Navigator.of(context).pop(raw);
      return;
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torchEnabled = !_torchEnabled);
    } catch (_) {
      // Sebagian perangkat tidak memiliki lampu kilat.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan QR Wave Music', style: TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            tooltip: _torchEnabled ? 'Matikan lampu' : 'Nyalakan lampu',
            onPressed: _toggleTorch,
            icon: Icon(
              _torchEnabled ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScannerError(error: error),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primaryGreen, width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87, Colors.black],
                ),
              ),
              child: const Text(
                'Arahkan kamera ke QR kode berbagi Wave Music.\n'
                'QR dari aplikasi lain akan diabaikan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  final MobileScannerException error;

  const _ScannerError({required this.error});

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              denied
                  ? Icons.no_photography_outlined
                  : Icons.camera_alt_outlined,
              size: 54,
              color: Colors.white38,
            ),
            const SizedBox(height: 16),
            Text(
              denied
                  ? 'Izin kamera belum diberikan. Aktifkan izin kamera untuk Wave Music di pengaturan Android, lalu coba lagi.'
                  : 'Kamera tidak dapat dibuka di perangkat ini. Kamu masih bisa menempel kode secara manual.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
