import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/biography/freshness_decay_service.dart';

void main() {
  test('scan biography writer delegates freshness tiers to the canonical SOT',
      () {
    final source = File(
      'lib/screens/document_scan/extraction_review_screen.dart',
    ).readAsStringSync();

    expect(FreshnessDecayService.categoryFor(FactType.taxRate), 'annual');
    expect(
        FreshnessDecayService.categoryFor(FactType.mortgageDebt), 'volatile');
    expect(
      source,
      contains(
        'freshnessCategory: FreshnessDecayService.categoryFor(factType),',
      ),
    );
    expect(source, isNot(contains('_freshnessCategoryFor')));
  });
}
