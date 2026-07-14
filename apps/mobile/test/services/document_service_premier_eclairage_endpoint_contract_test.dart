import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('premier éclairage keeps its backend endpoint byte-identical', () {
    final source =
        File('lib/services/document_service.dart').readAsStringSync();
    const expectedEndpoint = '/documents/premier-eclairage';

    expect(source, contains('Fetch premier éclairage'));
    expect(
      RegExp("['\"]${RegExp.escape(expectedEndpoint)}['\"]").allMatches(source),
      hasLength(1),
    );
    expect(
      source,
      contains("Uri.parse('\$baseUrl\$_premierEclairageEndpoint')"),
    );
  });
}
