/// AgentValidationGate — Agent Autonome v1 (S68).
///
/// 7 tests covering:
///  1.  Gate always returns true for FormPrefillOutput
///  2.  Gate always returns true for GeneratedLetterOutput
///  3.  FormPrefill passes through gate via convenience method
///  4.  GeneratedLetter passes through gate via convenience method
///  5.  Gate throws StateError if requiresValidation is somehow false
///  6.  All field userMustConfirm flags survive gate passage
///  7.  Gate works with both letter and form types in sequence
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/agent/agent_validation_gate.dart';
import 'package:mint_mobile/services/agent/form_prefill_service.dart';
import 'package:mint_mobile/services/agent/letter_generation_service.dart';

// ════════════════════════════════════════════════════════════════
//  HELPERS
// ════════════════════════════════════════════════════════════════

Future<S> _buildL10n(WidgetTester tester) async {
  late S result;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Builder(
        builder: (context) {
          result = S.of(context)!;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return result;
}

CoachProfile _salarieProfile() {
  return CoachProfile(
    firstName: 'Julien',
    birthYear: 1977,
    canton: 'VS',
    salaireBrutMensuel: 10183.92,
    nombreDeMois: 12,
    employmentStatus: 'salarie',
    prevoyance: const PrevoyanceProfile(
      nomCaisse: 'CPE',
      avoirLppTotal: 70377,
      rachatMaximum: 539414,
    ),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2042, 1, 1),
      label: 'Retraite',
    ),
  );
}

final _fixedNow = DateTime(2026, 3, 21);

/// A fake [AgentOutput] that returns false for [requiresValidation].
/// Used to test the gate throws on invalid output.
class _InvalidAgentOutput implements AgentOutput {
  @override
  bool get requiresValidation => false;

  @override
  String get disclaimer => 'Test disclaimer';
}

// ════════════════════════════════════════════════════════════════
//  TESTS
// ════════════════════════════════════════════════════════════════

void main() {
  // ── 1. Gate always returns true for FormPrefillOutput ─────────
  testWidgets('1. Gate always returns true for FormPrefillOutput',
      (tester) async {
    final l = await _buildL10n(tester);
    final prefill = FormPrefillService.prepareTaxDeclaration(
      profile: _salarieProfile(),
      taxYear: 2025,
      l: l,
    );
    final output = FormPrefillOutput(prefill);
    expect(AgentValidationGate.validate(output), isTrue);
  });

  // ── 2. Gate always returns true for GeneratedLetterOutput ─────
  testWidgets('2. Gate always returns true for GeneratedLetterOutput',
      (tester) async {
    final l = await _buildL10n(tester);
    final letter = LetterGenerationService.generatePensionFundRequest(
      profile: _salarieProfile(),
      l: l,
      now: _fixedNow,
    );
    final output = GeneratedLetterOutput(letter);
    expect(AgentValidationGate.validate(output), isTrue);
  });

  // ── 3. FormPrefill passes gate via convenience method ─────────
  testWidgets('3. FormPrefill passes gate via convenience method',
      (tester) async {
    final l = await _buildL10n(tester);
    final prefill = FormPrefillService.prepare3aForm(
      profile: _salarieProfile(),
      year: 2025,
      l: l,
    );
    expect(AgentValidationGate.validateFormPrefill(prefill), isTrue);
  });

  // ── 4. GeneratedLetter passes gate via convenience method ─────
  testWidgets('4. GeneratedLetter passes gate via convenience method',
      (tester) async {
    final l = await _buildL10n(tester);
    final letter = LetterGenerationService.generateAvsExtractRequest(
      profile: _salarieProfile(),
      l: l,
      now: _fixedNow,
    );
    expect(AgentValidationGate.validateLetter(letter), isTrue);
  });

  // ── 5. Gate throws StateError if requiresValidation is false ──
  test('5. Gate throws StateError if requiresValidation is false', () {
    final invalid = _InvalidAgentOutput();
    expect(
      () => AgentValidationGate.validate(invalid),
      throwsStateError,
    );
  });

  // ── 6. All field userMustConfirm flags survive gate passage ───
  testWidgets('6. All field userMustConfirm flags survive gate passage',
      (tester) async {
    final l = await _buildL10n(tester);
    final prefill = FormPrefillService.prepareLppBuyback(
      profile: _salarieProfile(),
      l: l,
    );
    // Gate validates
    final passed = AgentValidationGate.validateFormPrefill(prefill);
    expect(passed, isTrue);
    // After gate, all fields still require user confirmation
    for (final field in prefill.fields) {
      expect(field.userMustConfirm, isTrue,
          reason: 'Field "${field.label}" lost userMustConfirm after gate');
    }
  });

  // ── 7. Gate works with both types in sequence ─────────────────
  testWidgets('7. Gate works with both letter and form types in sequence',
      (tester) async {
    final l = await _buildL10n(tester);

    // All form types
    for (final prefill in [
      FormPrefillService.prepareTaxDeclaration(
          profile: _salarieProfile(), taxYear: 2025, l: l),
      FormPrefillService.prepare3aForm(
          profile: _salarieProfile(), year: 2025, l: l),
      FormPrefillService.prepareLppBuyback(
          profile: _salarieProfile(), l: l),
    ]) {
      expect(
        AgentValidationGate.validateFormPrefill(prefill),
        isTrue,
        reason: 'Gate failed for form type ${prefill.formType}',
      );
    }

    // All letter types
    for (final letter in [
      LetterGenerationService.generatePensionFundRequest(
          profile: _salarieProfile(), l: l, now: _fixedNow),
      LetterGenerationService.generateLppTransfer(
          profile: _salarieProfile(), l: l, now: _fixedNow),
      LetterGenerationService.generateAvsExtractRequest(
          profile: _salarieProfile(), l: l, now: _fixedNow),
    ]) {
      expect(
        AgentValidationGate.validateLetter(letter),
        isTrue,
        reason: 'Gate failed for letter type ${letter.type}',
      );
    }
  });
}
