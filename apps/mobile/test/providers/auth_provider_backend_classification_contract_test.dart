import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backend French classifiers stay exact without becoming UI copy', () {
    final source = File('lib/providers/auth_provider.dart').readAsStringSync();

    expect(source, contains(r"lower.contains('existe d\u00e9j\u00e0')"));
    expect(source, contains(r"lower.contains('non v\u00e9rifi\u00e9')"));
    expect(source, contains('Backend error fragments are classifier inputs'));
    expect(source, isNot(contains("lower.contains('existe déjà')")));
    expect(source, isNot(contains("lower.contains('non vérifié')")));
  });
}
