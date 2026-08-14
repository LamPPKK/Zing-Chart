import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android backup covers DataStore and legacy SharedPreferences', () {
    for (final path in [
      'android/app/src/main/res/xml/backup_rules.xml',
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ]) {
      final rules = File(path).readAsStringSync();
      expect(rules, contains('domain="file"'));
      expect(
        rules,
        contains('datastore/FlutterSharedPreferences.preferences_pb'),
      );
      expect(rules, contains('domain="sharedpref"'));
    }
  });
}
