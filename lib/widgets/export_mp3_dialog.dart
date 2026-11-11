import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track_model.dart';
import '../providers/library_provider.dart';
import '../theme/app_theme.dart';

class ExportMp3Dialog extends StatefulWidget {
  final TrackModel track;

  const ExportMp3Dialog({super.key, required this.track});

  static void show(BuildContext context, TrackModel track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ExportMp3Dialog(track: track),
      ),
    );
  }

  @override
  State<ExportMp3Dialog> createState() => _ExportMp3DialogState();
}

class _ExportMp3DialogState extends State<ExportMp3Dialog> {
  final TextEditingController _customFolderController = TextEditingController();
  String _selectedFolder = 'Download';
  bool _isSaving = false;

  final List<Map<String, String>> _presetFolders = [
    {'name': 'Download', 'desc': 'Folder Download HP (/storage/emulated/0/Download)'},
    {'name': 'Music', 'desc': 'Folder Musik HP (/storage/emulated/0/Music)'},
    {'name': 'Documents', 'desc': 'Folder Dokumen HP (/storage/emulated/0/Documents)'},
    {'name': 'WaveMusic', 'desc': 'Folder Khusus (/storage/emulated/0/WaveMusic)'},
  ];

  @override
  void dispose() {
    _customFolderController.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final library = context.read<LibraryProvider>();
    final targetFolder = _customFolderController.text.trim().isNotEmpty
        ? _customFolderController.text.trim()
        : _selectedFolder;

    setState(() => _isSaving = true);

    final savedPath = await library.exportTrackToMp3(widget.track, folderName: targetFolder);

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);

      if (savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.surface,
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'MP3 tersimpan di: $savedPath',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Simpan Lagu sebagai .MP3',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.track.artist} - ${widget.track.title}.mp3',
                style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'FORMAT .MP3',
                      style: TextStyle(color: AppTheme.primaryGreen, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ID3v2 Tag + Cover Art HD Tanam',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
              const Divider(color: AppTheme.divider, height: 20),

              const Text(
                'PILIH FOLDER PENYIMPANAN DI HP:',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              ..._presetFolders.map((folder) {
                final isSelected = _selectedFolder == folder['name'] && _customFolderController.text.isEmpty;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.folder,
                    color: isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary,
                  ),
                  title: Text(
                    folder['name']!,
                    style: TextStyle(
                      color: isSelected ? AppTheme.primaryGreen : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    folder['desc']!,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.radio_button_checked, color: AppTheme.primaryGreen)
                      : const Icon(Icons.radio_button_unchecked, color: AppTheme.textSecondary),
                  onTap: () {
                    setState(() {
                      _selectedFolder = folder['name']!;
                      _customFolderController.clear();
                    });
                  },
                );
              }),

              const SizedBox(height: 12),
              const Text(
                'ATAU KETIK NAMA FOLDER SENDIRI:',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _customFolderController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Contoh: MusikSaya / Flashdisk / Mobil',
                  hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  filled: true,
                  fillColor: AppTheme.card,
                  prefixIcon: const Icon(Icons.create_new_folder, color: AppTheme.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.save_alt),
                  label: Text(
                    _isSaving ? 'Menyimpan...' : 'Simpan File .MP3 Sekarang',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: _isSaving ? null : _export,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
