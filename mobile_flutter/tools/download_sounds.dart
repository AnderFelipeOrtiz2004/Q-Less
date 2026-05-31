import 'dart:io';
import 'package:http/http.dart' as http;

/// Simple script to download sample sound files into `assets/sounds/`.
/// Run from the repo root with:
///
/// dart run tools/download_sounds.dart

final files = {
  'click.mp3': [
    'https://www.soundjay.com/button/sounds/button-3.mp3',
    'https://www.soundjay.com/button/sounds/button-4.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'
  ],
  'success.mp3': [
    'https://www.soundjay.com/misc/sounds/bell-ringing-05.mp3',
    'https://www.soundjay.com/misc/sounds/bell-ringing-3.mp3',
    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3'
  ],
};

Future<void> main() async {
  final outDir = Directory('assets/sounds');
  if (!await outDir.exists()) {
    await outDir.create(recursive: true);
    stdout.writeln('Created ${outDir.path}');
  }

  for (final entry in files.entries) {
    final filename = entry.key;
    final candidates = List<String>.from(entry.value as List);
    final outFile = File('${outDir.path}/$filename');
    bool saved = false;
    for (final url in candidates) {
      try {
        stdout.writeln('Trying $url ...');
        final resp = await http.get(Uri.parse(url));
        if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
          await outFile.writeAsBytes(resp.bodyBytes);
          stdout.writeln('Saved ${outFile.path} (from $url)');
          saved = true;
          break;
        } else {
          stdout.writeln('No content or ${resp.statusCode} from $url');
        }
      } catch (e) {
        stdout.writeln('Error downloading $url: $e');
      }
    }
    if (!saved) {
      stdout.writeln(
        'Could not download any candidate for $filename. Keeping placeholder.',
      );
    }
  }

  stdout.writeln('Done. Now run: flutter pub get && flutter run');
}
