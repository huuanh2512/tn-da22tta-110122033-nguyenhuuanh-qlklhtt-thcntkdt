import 'dart:convert';
import 'dart:io';

void main() {
  final targetDirectories = ['lib', 'modules'];
  final graph = <String, List<String>>{};

  for (final dirPath in targetDirectories) {
    final directory = Directory(dirPath);
    if (!directory.existsSync()) {
      continue;
    }

    final files = directory.listSync(recursive: true);

    for (final entity in files) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final path = entity.path.replaceAll('\\', '/');
        final lines = entity.readAsLinesSync();
        final dependencies = <String>[];

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('import ') || trimmed.startsWith('part ')) {
            final firstQuote = trimmed.indexOf("'");
            final lastQuote = trimmed.lastIndexOf("'");

            if (firstQuote != -1 && lastQuote != -1 && firstQuote < lastQuote) {
              dependencies.add(trimmed.substring(firstQuote + 1, lastQuote));
            } else {
              final firstDoubleQuote = trimmed.indexOf('"');
              final lastDoubleQuote = trimmed.lastIndexOf('"');
              if (firstDoubleQuote != -1 &&
                  lastDoubleQuote != -1 &&
                  firstDoubleQuote < lastDoubleQuote) {
                dependencies.add(
                  trimmed.substring(firstDoubleQuote + 1, lastDoubleQuote),
                );
              }
            }
          }
        }
        graph[path] = dependencies;
      }
    }
  }

  final file = File('code_graph.json');
  file.writeAsStringSync(jsonEncode(graph));
}
