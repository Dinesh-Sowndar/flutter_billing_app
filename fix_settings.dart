import 'dart:io';
void main() {
  final file = File('lib/features/settings/presentation/pages/settings_page.dart');
  var text = file.readAsStringSync();
  text = text.replaceAll('gradient: LinearEffect.gradient(), // Will be removed below. Just plain color.', '');
  file.writeAsStringSync(text);
}
