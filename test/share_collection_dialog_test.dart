import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:spotify_pribadi/models/track_model.dart';
import 'package:spotify_pribadi/widgets/share_collection_dialog.dart';

void main() {
  TrackModel track(int index) {
    return TrackModel(
      id: 'yt_$index',
      title: 'Lagu $index',
      artist: 'Artis $index',
      album: 'Album',
      artworkUrl: '',
      durationMs: 180000,
      youtubeId: '$index',
    );
  }

  Widget host({required String name, required List<TrackModel> tracks}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () =>
                ShareCollectionDialog.show(context, name: name, tracks: tracks),
            child: const Text('Buka'),
          ),
        ),
      ),
    );
  }

  testWidgets('playlist kecil menampilkan QR dan tombol salin', (tester) async {
    await tester.pumpWidget(
      host(name: 'Kecil', tracks: [track(1), track(2), track(3)]),
    );
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Salin Kode'), findsOneWidget);
    expect(find.textContaining('WAVE1.'), findsOneWidget);
  });

  testWidgets('playlist sangat besar menyembunyikan QR dan menawarkan salin', (
    tester,
  ) async {
    final tracks = List.generate(
      400,
      (i) => TrackModel(
        id: 'yt_big_$i',
        title: 'Judul Lagu Yang Panjang Sekali Nomor $i',
        artist: 'Nama Artis Yang Juga Panjang $i',
        album: 'Nama Album Yang Panjang $i',
        artworkUrl: '',
        durationMs: 200000 + i,
        youtubeId: 'big$i',
      ),
    );

    await tester.pumpWidget(host(name: 'Besar', tracks: tracks));
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Playlist ini terlalu besar untuk QR'), findsOneWidget);
    expect(find.text('Salin Kode'), findsOneWidget);
  });
}
