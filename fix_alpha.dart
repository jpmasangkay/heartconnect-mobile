import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    var content = file.readAsStringSync();
    if (!content.contains(r'withValues(alpha: $replacement)')) continue;

    var lines = content.split('\n');
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains(r'withValues(alpha: $replacement)')) {
        String line = lines[i];
        String replacement = '0.5';

        if (line.contains('BoxShadow') || line.contains('shadowColor')) {
          replacement = '0.05';
        } else if (line.contains('border:') || line.contains('BorderSide(') || line.contains('Border.all(') || line.contains('Border(')) {
          replacement = '0.5';
        } else if (line.contains('_Orb(')) {
          replacement = '0.1';
        } else if (line.contains('Colors.red') || line.contains('0xFFFCA5A5') || line.contains('0xFF86EFAC')) {
          if (line.contains('border')) {
            replacement = '0.5';
          } else {
            replacement = '0.1';
          }
        } else if (line.contains('AppColors.navy.withValues')) {
          if (line.contains('BoxShadow') || line.contains('shape: BoxShape.circle')) {
            replacement = '0.08';
          } else {
            replacement = '0.1';
          }
        } else if (line.contains('AppColors.textMuted.withValues')) {
          replacement = '0.5';
        } else if (line.contains('AppColors.accent.withValues') || line.contains('AppColors.connecting.withValues')) {
          replacement = '0.1';
        } else if (line.contains('_gradientColor')) {
          replacement = '0.0';
        }

        lines[i] = line.replaceAll(r'withValues(alpha: $replacement)', 'withValues(alpha: $replacement)');
      }
    }
    file.writeAsStringSync(lines.join('\n'));
    stdout.writeln('Fixed ${file.path}');
  }
}
