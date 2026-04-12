/// LetterGenerationService — Agent Autonome v1 (S68).
///
/// 17 tests covering:
///  1.  Pension fund request has subject and body
///  2.  Pension fund request uses formal "vous" (not "tu")
///  3.  Pension fund request contains caisse name from profile
///  4.  Pension fund request contains placeholder for personal name
///  5.  Pension fund request contains placeholder for address
///  6.  LPP transfer letter has subject and body
///  7.  LPP transfer letter contains placeholder fields
///  8.  AVS extract letter has subject and body
///  9.  AVS extract letter contains SSN placeholder (not actual SSN)
/// 10.  MINT never pre-fills name — always placeholder
/// 11.  MINT never pre-fills address — always placeholder
/// 12.  MINT never pre-fills SSN — always placeholder
/// 13.  requiresValidation is always true on all letter types
/// 14.  Disclaimer present and non-empty on all letter types
/// 15.  All letters have non-empty placeholders list
/// 16.  No banned terms in any generated text
/// 17.  Golden: pension request for Julien (CPE caisse) mentions CPE
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
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

/// Julien — golden couple salarié avec LPP (CPE).
CoachProfile _julienProfile() {
  return CoachProfile(
    firstName: 'Julien',
    birthYear: 1977,
    canton: 'VS',
    nationality: 'CH',
    salaireBrutMensuel: 10183.92,
    nombreDeMois: 12,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.marie,
    nombreEnfants: 2,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2042, 1, 1),
      label: 'Retraite',
    ),
    prevoyance: const PrevoyanceProfile(
      nomCaisse: 'CPE',
      avoirLppTotal: 70377,
      rachatMaximum: 539414,
      rachatEffectue: 0,
      totalEpargne3a: 32000,
    ),
    patrimoine: const PatrimoineProfile(epargneLiquide: 50000),
  );
}

/// MINT compliance: banned terms.
const _bannedTerms = [
  'garanti',
  'certain',
  'sans risque',
  'optimal',
  'meilleur',
  'parfait',
  'conseiller',
  'garantie',
  'optimale',
  'meilleure',
  'parfaite',
];

final _fixedNow = DateTime(2026, 3, 21);

// ════════════════════════════════════════════════════════════════
//  TESTS
// ════════════════════════════════════════════════════════════════

void main() {
  // ── 1. Pension fund request has subject and body ──────────────
  testWidgets('1. Pension fund request has subject and body', (tester) async {
    final l = await _buildL10n(tester);
    final letter = LetterGenerationService.generatePensionFundRequest(
      profile: _julienProfile(),
      l: l,
      now: _fixedNow,
    );
    expect(letter.subject, isNotEmpty);
    expect(letter.body, isNotEmpty);
    expect(letter.type, 'pensionFundRequest');
  });

  // ── 2. Pension fund request uses formal "vous" ────────────────
  testWidgets('2. Pension fund request uses formal "vous" (not "tu")',
      (tester) async {
    final l = await _buildL10n(tester);
    final letter = LetterGenerationService.generatePensionFundRequest(
      profile: _julienProfile(),
      l: l,
      now: _fixedNow,
    );
    expect(letter.body.toLowerCase(), contains('vous'));
    // Must NOT contain standalone " tu " (avoid false positive on words like "actualisé")
    expect(letter.body, isNot(matches(RegExp(r'\btu\b'))));
  });

  // ── 3. Pension fund request contains caisse name from profile ─
  testWidgets('3. Pension fund request contains caisse name from profile',
      (tester) async {
    final l = await _buildL10n(tester);
    final letter = LetterGenerationService.generatePensionFundRequest(
      profile: _julienProfile(),
      l: l,
      now: _fixedNow,
    );
    expect(letter.body, contains('CPE'));
  });

  // ── 4. Pension fund request contains placeholder for name ─────
  testWidgets('4. Pension fund request contains placeholder for name',
      (tester) async {
    final l = await _buildL10n(tester);
    final letter = LetterGenerationService.generatePensionFundRequest(
      profile: _julienProfile(),
      l: l,
      now: _fixedNow,
    );
    expect(letter.body, contains(l.agentLetterPlaceholderName));
    expect(letter.placeholders, contains(l.agentLetterPlaceholderName));
  });

  // ── 5. Pension fund request contains placeholder for address ──
  testWidgets('5. Pension fund request contains placeholder for address',
      (tester) async {
    final l = await _buildL10n(tester);
    final letter = LetterGenerationService.generatePensionFundRequest(
      profile: _julienProfile(),
      l: l,
      now: _fixedNow,
    );
    expect(letter.body, contains(l.agentLetterPlaceholderAddress));
    expect(letter.placeholders, contains(l.agentLetterPlaceholderAddress));
  });

  // ── 6. LPP transfer letter has subject and body ───────────────
  testWidgets('6. LPP transfer letter has subject and body', (tester) async {
    final l = await _buildL10n(tester);
    final letter = LetterGenerationService.generateLppTransfer(
      profile: _julienProfile(),
      l: l,
      now: _fixedNow,
    );
    expect(letter.subject, isNotEmpty);
    expect(letter.body, isNotEmpty);
    expect(letter.type, 'lppTransfer');
  });

  // ── 7. LPP transfer letter contains placeholder fields ────────
  testWidgets('7. LPP transfer letter contains placeholder fields',
      (tester) async {
    final l = await _buildL10n(tester);
    final letter = LetterGenerationService.generateLppTransfer(
      profile: _julienProfile(),
      l: l,
      now: _fixedNow,
    );
    // Must have placeholders for personal data
    expect(letter.placeholders, isNotEmpty);
    expect(letter.body, contains('[À compléter]'));
  });

  // ── 8. AVS extract letter has subject and body ────────────────
  testWidgets('8. AVS extract letter has subject and body', (tester) async {
    final l = await _buildL10n(tester);
    final letter = LetterGenerationService.generateAvsExtractRequest(
      profile: _julienProfile(),
      l: l,
      now: _fixedNow,
    );
    expect(letter.subject, isNotEmpty);
    expect(letter.body, isNotEmpty);
    expect(letter.type, 'avsExtractRequest');
    expect(letter.body.toLowerCase(), contains('extrait'));
    expect(letter.body.toLowerCase(), contains('compte individuel'));
  });

  // ── 9. AVS extract letter uses SSN placeholder, not actual SSN ─
  testWidgets('9. AVS extract letter uses SSN placeholder, not actual SSN',
      (tester) async {
    final l = await _buildL10n(tester);
    final letter = LetterGenerationService.generateAvsExtractRequest(
      profile: _julienProfile(),
      l: l,
      now: _fixedNow,
    );
    // Must contain placeholder
    expect(letter.body, contains(l.agentLetterPlaceholderSsn));
    // Must NOT contain actual AVS number pattern
    final ssnRe = RegExp(r'756\.\d{4}\.\d{4}\.\d{2}');
    expect(ssnRe.hasMatch(letter.body), isFalse,
        reason: 'Actual SSN found in AVS letter body');
  });

  // ── 10. MINT never pre-fills name ─────────────────────────────
  testWidgets('10. MINT never pre-fills name — always placeholder',
      (tester) async {
    final l = await _buildL10n(tester);
    for (final letter in [
      LetterGenerationService.generatePensionFundRequest(
          profile: _julienProfile(), l: l, now: _fixedNow),
      LetterGenerationService.generateLppTransfer(
          profile: _julienProfile(), l: l, now: _fixedNow),
      LetterGenerationService.generateAvsExtractRequest(
          profile: _julienProfile(), l: l, now: _fixedNow),
    ]) {
      // "Julien" must NOT appear in letter body
      expect(
        letter.body.toLowerCase(),
        isNot(contains('julien')),
        reason: 'Name "Julien" found in letter ${letter.type}',
      );
    }
  });

  // ── 11. MINT never pre-fills address ──────────────────────────
  testWidgets('11. MINT never pre-fills address — always placeholder',
      (tester) async {
    final l = await _buildL10n(tester);
    for (final letter in [
      LetterGenerationService.generatePensionFundRequest(
          profile: _julienProfile(), l: l, now: _fixedNow),
      LetterGenerationService.generateAvsExtractRequest(
          profile: _julienProfile(), l: l, now: _fixedNow),
    ]) {
      // Actual street addresses must not appear (only [placeholder])
      // Profile has no address field, so check placeholder is there
      expect(letter.body, contains(l.agentLetterPlaceholderAddress),
          reason: 'Address placeholder missing in ${letter.type}');
    }
  });

  // ── 12. MINT never pre-fills SSN ──────────────────────────────
  testWidgets('12. MINT never pre-fills SSN — always placeholder',
      (tester) async {
    final l = await _buildL10n(tester);
    final ssnRe = RegExp(r'756\.\d{4}\.\d{4}\.\d{2}');
    for (final letter in [
      LetterGenerationService.generatePensionFundRequest(
          profile: _julienProfile(), l: l, now: _fixedNow),
      LetterGenerationService.generateLppTransfer(
          profile: _julienProfile(), l: l, now: _fixedNow),
      LetterGenerationService.generateAvsExtractRequest(
          profile: _julienProfile(), l: l, now: _fixedNow),
    ]) {
      expect(ssnRe.hasMatch(letter.body), isFalse,
          reason: 'SSN/AVS found in letter ${letter.type}');
    }
  });

  // ── 13. requiresValidation is always true on all letter types ─
  testWidgets('13. requiresValidation is always true', (tester) async {
    final l = await _buildL10n(tester);
    for (final letter in [
      LetterGenerationService.generatePensionFundRequest(
          profile: _julienProfile(), l: l, now: _fixedNow),
      LetterGenerationService.generateLppTransfer(
          profile: _julienProfile(), l: l, now: _fixedNow),
      LetterGenerationService.generateAvsExtractRequest(
          profile: _julienProfile(), l: l, now: _fixedNow),
    ]) {
      expect(
        letter.requiresValidation,
        isTrue,
        reason: 'requiresValidation must be true for ${letter.type}',
      );
    }
  });

  // ── 14. Disclaimer present and non-empty ─────────────────────
  testWidgets('14. Disclaimer present and non-empty', (tester) async {
    final l = await _buildL10n(tester);
    for (final letter in [
      LetterGenerationService.generatePensionFundRequest(
          profile: _julienProfile(), l: l, now: _fixedNow),
      LetterGenerationService.generateLppTransfer(
          profile: _julienProfile(), l: l, now: _fixedNow),
      LetterGenerationService.generateAvsExtractRequest(
          profile: _julienProfile(), l: l, now: _fixedNow),
    ]) {
      expect(letter.disclaimer, isNotEmpty,
          reason: 'Disclaimer missing on ${letter.type}');
    }
  });

  // ── 15. All letters have non-empty placeholders list ─────────
  testWidgets('15. All letters have non-empty placeholders list',
      (tester) async {
    final l = await _buildL10n(tester);
    for (final letter in [
      LetterGenerationService.generatePensionFundRequest(
          profile: _julienProfile(), l: l, now: _fixedNow),
      LetterGenerationService.generateLppTransfer(
          profile: _julienProfile(), l: l, now: _fixedNow),
      LetterGenerationService.generateAvsExtractRequest(
          profile: _julienProfile(), l: l, now: _fixedNow),
    ]) {
      expect(letter.placeholders, isNotEmpty,
          reason: 'Placeholders empty for ${letter.type}');
    }
  });

  // ── 16. No banned terms in any generated text ─────────────────
  testWidgets('16. No banned terms in any generated text', (tester) async {
    final l = await _buildL10n(tester);
    for (final letter in [
      LetterGenerationService.generatePensionFundRequest(
          profile: _julienProfile(), l: l, now: _fixedNow),
      LetterGenerationService.generateLppTransfer(
          profile: _julienProfile(), l: l, now: _fixedNow),
      LetterGenerationService.generateAvsExtractRequest(
          profile: _julienProfile(), l: l, now: _fixedNow),
    ]) {
      final allText =
          '${letter.subject} ${letter.body} ${letter.disclaimer}'.toLowerCase();
      for (final banned in _bannedTerms) {
        final pattern = RegExp('\\b${RegExp.escape(banned)}\\b');
        expect(
          pattern.hasMatch(allText),
          isFalse,
          reason: 'Banned term "$banned" found in letter ${letter.type}',
        );
      }
    }
  });

  // ── 17. Golden: pension request for Julien (CPE caisse) ───────
  testWidgets('17. Golden: pension request for Julien (CPE) mentions CPE',
      (tester) async {
    final l = await _buildL10n(tester);
    final letter = LetterGenerationService.generatePensionFundRequest(
      profile: _julienProfile(),
      l: l,
      now: _fixedNow,
    );
    // CPE should appear as caisse name
    expect(letter.body, contains('CPE'));
    // Year should be in the letter
    expect(letter.body, contains('2026'));
    // Has formal salutation
    expect(letter.body.toLowerCase(), contains('madame'));
    expect(letter.body.toLowerCase(), contains('monsieur'));
  });
}
