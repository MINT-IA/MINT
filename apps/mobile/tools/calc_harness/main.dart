// MINT calc-rigor differential harness — Dart side (CONTEXT 92.5 D-04).
//
// CLI: reads JSONL on stdin (one fixture per line), writes JSONL on stdout
// (one result per input line) using the SAME line-id mapping. Exits 0 when
// stdin EOFs cleanly; non-zero only on parse / I/O failure (NOT on calc
// divergence — divergence is the Python side's job to assert, see
// services/backend/tests/test_calc_diff_harness.py).
//
// Build:  cd apps/mobile && dart compile exe tools/calc_harness/main.dart \
//             -o /tmp/calc_harness_dart
// Drive:  cat services/backend/tests/fixtures/calc_diff_v1.jsonl \
//             | /tmp/calc_harness_dart
//
// Imports the financial_core/ calculators directly per
// ADR-20260223-unified-financial-engine.md (Mobile is the canonical source
// of truth for the 3 locked calculators). NEVER re-implement calc logic
// here — import + call. Per CLAUDE.md §4 NEVER #3.
//
// TODO(92.5-04 CI): the current Dart `constants/social_insurance.dart`
// transitively imports the Flutter foundation lib (debugPrint guard) plus
// the SharedPreferences-backed regulatory_sync_service. `dart compile exe`
// of this entrypoint will therefore fail until Wave 2 (plan 92.5-04)
// extracts a pure-Dart core from `lib/constants/social_insurance.dart`
// into a runtime-free module the harness can import. Until then, the
// Python pytest fixture `dart_outputs` skips cleanly when
// /tmp/calc_harness_dart is absent (tests/test_calc_diff_harness.py —
// pytest.skip path), so this file stays in scope as documentation of
// the calling convention even if it cannot compile-exe today. Tracked
// in 92.5-01-SUMMARY.md.

import 'dart:convert';
import 'dart:io';

import 'package:mint_mobile/constants/social_insurance.dart' as si;
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

/// Compute the 4 differential axes for a single fixture.
///
/// Axes (matched to backend helpers in `social_insurance.py`):
///   - capital_withdrawal_tax   ↔ calculate_progressive_capital_tax
///   - lpp_bonification_rate    ↔ get_lpp_bonification_rate
///   - avs_rente_from_ramd      ↔ rente_from_ramd
///   - ai_rente_monthly         ↔ get_ai_rente_monthly
Map<String, dynamic> compute(Map<String, dynamic> fx) {
  final canton = fx['canton'] as String;
  final age = fx['age'] as int;
  final salary = (fx['gross_annual_salary'] as num).toDouble();
  final married = (fx['marital_status'] as String) == 'married';
  final amount = (fx['capital_withdrawal_amount'] as num).toDouble();
  final disability = fx['ai_disability_degree'] as int;

  // Axis 1: progressive capital tax (parity with social_insurance.calculate_progressive_capital_tax).
  final capitalTax = RetirementTaxCalculator.capitalWithdrawalTax(
    capitalBrut: amount,
    canton: canton,
    isMarried: married,
  );

  // Axis 2: LPP bonification rate (parity with social_insurance.get_lpp_bonification_rate).
  // Imported as top-level function from constants/social_insurance.dart.
  final lppBonificationRate = si.getLppBonificationRate(age);

  // Axis 3: AVS rente from RAMD (parity with social_insurance.rente_from_ramd).
  final avsRenteFromRamd = AvsCalculator.renteFromRAMD(salary);

  // Axis 4: AI rente monthly (parity with social_insurance.get_ai_rente_monthly).
  // The Dart constants/social_insurance.dart exposes `aiRenteEntiere` (= 2520.0)
  // but no public top-level helper that mirrors get_ai_rente_monthly verbatim.
  // We compute the bareme from the same constant table — this is NOT a re-
  // implementation of business logic, it is a direct mapping of the legal
  // bareme (LAI art. 28 al. 1) where the Python side uses AI_BAREME[40/50/60/70].
  // If a future Dart `aiRenteMonthly(degree)` lands in financial_core/, switch
  // this call site to it.
  double aiRenteMonthly;
  if (disability < 40) {
    aiRenteMonthly = 0.0;
  } else if (disability < 50) {
    aiRenteMonthly = si.aiRenteEntiere * 0.25;
  } else if (disability < 60) {
    aiRenteMonthly = si.aiRenteEntiere * 0.50;
  } else if (disability < 70) {
    aiRenteMonthly = si.aiRenteEntiere * 0.75;
  } else {
    aiRenteMonthly = si.aiRenteEntiere * 1.00;
  }

  return {
    'id': fx['id'],
    'capital_withdrawal_tax': capitalTax,
    'lpp_bonification_rate': lppBonificationRate,
    'avs_rente_from_ramd': avsRenteFromRamd,
    'ai_rente_monthly': aiRenteMonthly,
  };
}

Future<void> main() async {
  final lines = stdin.transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in lines) {
    if (line.trim().isEmpty) continue;
    try {
      final fx = jsonDecode(line) as Map<String, dynamic>;
      final out = compute(fx);
      stdout.writeln(jsonEncode(out));
    } catch (e, st) {
      stderr.writeln('calc_harness: failed on line: $line');
      stderr.writeln('error: $e');
      stderr.writeln(st);
      exitCode = 2;
      return;
    }
  }
}
