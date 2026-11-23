import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class TermsDisclaimerDialog extends StatelessWidget {
  static const String prefKey = 'has_accepted_terms_v1';

  const TermsDisclaimerDialog({super.key});

  /// Menampilkan dialog ketentuan jika pengguna belum pernah menyetujuinya.
  static Future<bool> checkAndShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasAccepted = prefs.getBool(prefKey) ?? false;
    if (hasAccepted) return true;

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const TermsDisclaimerDialog(),
    );

    return result ?? false;
  }

  Future<void> _handleAccept(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, true);
    if (context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: AppTheme.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.divider),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0x1FF43F5E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppTheme.primaryGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ketentuan & Penafian',
                          style: TextStyle(
                            fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Wave Music oleh David Yehuda Surbakti',
                          style: TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _DisclaimerItem(
                          number: '1',
                          title: 'Pengembang & Tujuan Aplikasi',
                          description:
                              'Wave Music dikembangkan secara independen oleh David Yehuda Surbakti untuk keperluan edukasi, riset teknologi, dan pemutaran musik pribadi non-komersial.',
                        ),
                        SizedBox(height: 12),
                        _DisclaimerItem(
                          number: '2',
                          title: 'Lisensi Perangkat Lunak (MIT License)',
                          description:
                              'Aplikasi ini dilisensikan di bawah MIT License. Hak Cipta (c) 2026 David Yehuda Surbakti. Disediakan "sebagaimana adanya" (as-is) tanpa jaminan apa pun.',
                        ),
                        SizedBox(height: 12),
                        _DisclaimerItem(
                          number: '3',
                          title: 'Sumber Aliran Konten',
                          description:
                              'Aplikasi tidak meng-host, menyimpan, atau mendistribusikan berkas berhak cipta pada peladen mandiri. Seluruh audio dialirkan secara langsung dari sumber publik pihak ketiga (YouTube), sedangkan metadata dan cover art berasal dari Deezer.',
                        ),
                        SizedBox(height: 12),
                        _DisclaimerItem(
                          number: '4',
                          title: 'Hak Cipta Musik & Aset',
                          description:
                              'Seluruh hak cipta lagu, rekaman suara, nama artis, dan sampul album sepenuhnya merupakan hak milik pencipta dan pemilik lisensi aslinya.',
                        ),
                        SizedBox(height: 12),
                        _DisclaimerItem(
                          number: '5',
                          title: 'Tanggung Jawab Pengguna',
                          description:
                              'Pengguna bertanggung jawab penuh atas segala aktivitas pemutaran musik, streaming, atau penyimpanan lokal yang dilakukan pada perangkat masing-masing.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _handleAccept(context),
                  child: Text(
                    'Saya Mengerti & Setuju',
                    style: TextStyle(
                      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisclaimerItem extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _DisclaimerItem({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: AppTheme.primaryGreen,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
