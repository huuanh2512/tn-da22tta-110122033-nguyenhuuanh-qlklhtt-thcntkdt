import 'dart:io';

void main() {
  final directory = Directory('.');
  final files = directory.listSync(recursive: false);

  for (final entity in files) {
    if (entity is File && entity.path.endsWith('.md')) {
      final content = entity.readAsStringSync();

      final singleLineContent = content
          .replaceAll('\r\n', r'\n')
          .replaceAll('\n', r'\n')
          .replaceAll('"', r'\"');

      final outputPath = entity.path.replaceAll('.md', '_single_line.txt');
      final outputFile = File(outputPath);
      outputFile.writeAsStringSync(singleLineContent);
    }
  }
}
