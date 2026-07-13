import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/financial_report.dart';

void main() {
  test('retirement projection requires an explicit current income', () {
    final source = File('lib/models/financial_report.dart').readAsStringSync();
    final start = source.indexOf('class RetirementProjection');
    final end = source.indexOf('class LppBuybackStrategy');

    expect(start, isNonNegative);
    expect(end, greaterThan(start));
    final projection = source.substring(start, end);

    expect(projection, contains('required this.currentMonthlyIncome'));
    expect(projection, isNot(contains('this.currentMonthlyIncome = 7800.0')));
  });

  test('total capital stays unknown when 3a is unknown', () {
    const projection = RetirementProjection(
      yearsUntilRetirement: 12,
      lppCapital: 250000,
      pillar3aCapital: null,
      monthlyAvsRent: 2000,
      monthlyLppRent: 1800,
      currentMonthlyIncome: 8000,
    );

    expect(projection.totalCapital, isNull);
  });
}
