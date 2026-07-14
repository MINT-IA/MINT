import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fiscal bloc reads three latest-completeness selector statuses only',
      () {
    final source = File(
      'lib/services/financial_core/confidence_scorer.dart',
    ).readAsStringSync();
    final start = source.indexOf('// --- Fiscalite (virtual bloc');
    final end = source.indexOf(
      "blocs['fiscalite'] =",
      start,
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final body = source.substring(start, end);
    final codeOnly = body
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
        .replaceAll(RegExp(r'//[^\r\n]*'), '');

    final expectedFields = {
      'TaxSnapshotField.cantonalCommunalTaxableIncomeChf',
      'TaxSnapshotField.cantonalCommunalTaxableWealthChf',
      'TaxSnapshotField.explicitMarginalIncomeTaxRate',
    };
    final selectorCall = RegExp(
      r'FiscalSnapshotSelector\s*\.\s*selectAssessedBaseline\s*\('
      r'\s*profile\s*\.\s*fiscal\s*,'
      r'\s*const\s+FiscalSnapshotQuery\s*\.\s*latestCompleteness\s*\('
      r'\s*requestedField\s*:\s*'
      r'(TaxSnapshotField\s*\.\s*[A-Za-z0-9_]+)\s*,?\s*\)\s*,?\s*\)',
      multiLine: true,
    );
    final calls = selectorCall.allMatches(codeOnly).toList();
    final everySelectorCall = RegExp(
      r'FiscalSnapshotSelector\s*\.\s*selectAssessedBaseline\s*\(',
    ).allMatches(codeOnly);

    expect(everySelectorCall, hasLength(3));
    expect(calls, hasLength(3));
    expect(
      calls
          .map((match) => match.group(1)!.replaceAll(RegExp(r'\s+'), ''))
          .toSet(),
      expectedFields,
    );
    expect(RegExp(r'\.\s*status\b').allMatches(codeOnly), hasLength(3));
    expect(
      RegExp(r'\.\s*snapshot\b').allMatches(codeOnly),
      isEmpty,
    );
    expect(
      RegExp(r'profile\s*\.\s*fiscal\s*\.\s*snapshots\b').allMatches(codeOnly),
      isEmpty,
    );
  });
}
