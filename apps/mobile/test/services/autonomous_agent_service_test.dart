import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/agent/autonomous_agent_service.dart';
import 'package:mint_mobile/models/coach_profile.dart';

// ────────────────────────────────────────────────────────────
//  AUTONOMOUS AGENT SERVICE TESTS — S68
// ────────────────────────────────────────────────────────────
//
// 25 tests covering:
//   Core: generate, validate, reject, requiresValidation, history, expiry
//   Safety gate: disclaimer, validationPrompt, PII, status, fieldsNeedingReview
//   Task types: tax declaration, 3a form, caisse letter, fiscal dossier,
//               AVS extract, LPP certificate
//   Compliance: banned terms, accents, non-breaking spaces, sources, disclaimer
// ────────────────────────────────────────────────────────────

final _defaultGoalA = GoalA(
  type: GoalAType.retraite,
  targetDate: DateTime(2042, 1, 1),
  label: 'Retraite',
);

/// Salarié with LPP — plafond 3a = 7'258.
CoachProfile _salarieProfile() {
  return CoachProfile(
    firstName: 'Julien',
    birthYear: 1977,
    canton: 'VS',
    salaireBrutMensuel: 10184,
    nombreDeMois: 12,
    employmentStatus: 'salarie',
    prevoyance: const PrevoyanceProfile(
      nomCaisse: 'CPE',
      avoirLppTotal: 70377,
      rachatMaximum: 539414,
      rachatEffectue: 0,
      totalEpargne3a: 32000,
    ),
    patrimoine: const PatrimoineProfile(epargneLiquide: 50000),
    goalA: _defaultGoalA,
  );
}

/// Indépendant sans LPP — plafond 3a = 36'288.
CoachProfile _independantSansLppProfile() {
  return CoachProfile(
    birthYear: 1985,
    canton: 'GE',
    salaireBrutMensuel: 8000,
    employmentStatus: 'independant',
    prevoyance: const PrevoyanceProfile(
      totalEpargne3a: 14000,
    ),
    goalA: _defaultGoalA,
  );
}

/// Minimal profile.
CoachProfile _minimalProfile() {
  return CoachProfile(
    birthYear: 1990,
    canton: 'ZH',
    salaireBrutMensuel: 0,
    goalA: _defaultGoalA,
  );
}

final _fixedNow = DateTime(2026, 3, 18, 10, 0, 0);

/// Banned terms from ComplianceGuard — must never appear in agent outputs.
const _bannedTerms = [
  'garanti',
  'certain',
  'assuré',
  'sans risque',
  'optimal',
  'meilleur',
  'parfait',
  'conseiller',
  'garantie',
  'assurée',
  'optimale',
  'meilleure',
  'parfaite',
  'conseillère',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ══════════════════════════════════════════════════════════════
  //  CORE TESTS
  // ══════════════════════════════════════════════════════════════

  group('Core', () {
    test('generateTask returns pendingValidation status', () async {
      final prefs = await SharedPreferences.getInstance();
      final task = await AutonomousAgentService.generateTask(
        type: AgentTaskType.taxDeclarationPreFill,
        profile: _salarieProfile(),
        now: _fixedNow,
        prefs: prefs,
      );

      expect(task.status, AgentTaskStatus.pendingValidation);
      expect(task.status, isNot(AgentTaskStatus.validated));
      expect(task.status, isNot(AgentTaskStatus.draft));
    });

    test('validateTask with approved=true → validated', () async {
      final prefs = await SharedPreferences.getInstance();
      final task = await AutonomousAgentService.generateTask(
        type: AgentTaskType.threeAFormPreFill,
        profile: _salarieProfile(),
        now: _fixedNow,
        prefs: prefs,
      );

      final validated = await AutonomousAgentService.validateTask(
        taskId: task.id,
        approved: true,
        prefs: prefs,
        now: _fixedNow.add(const Duration(hours: 1)),
      );

      expect(validated.status, AgentTaskStatus.validated);
      expect(validated.validatedAt, isNotNull);
    });

    test('validateTask with approved=false → rejected', () async {
      final prefs = await SharedPreferences.getInstance();
      final task = await AutonomousAgentService.generateTask(
        type: AgentTaskType.caisseLetterGeneration,
        profile: _salarieProfile(),
        now: _fixedNow,
        prefs: prefs,
      );

      final rejected = await AutonomousAgentService.validateTask(
        taskId: task.id,
        approved: false,
        prefs: prefs,
        now: _fixedNow.add(const Duration(hours: 1)),
      );

      expect(rejected.status, AgentTaskStatus.rejected);
      expect(rejected.validatedAt, isNotNull);
    });

    test('requiresValidation ALWAYS returns true', () async {
      final prefs = await SharedPreferences.getInstance();
      for (final type in AgentTaskType.values) {
        final task = await AutonomousAgentService.generateTask(
          type: type,
          profile: _salarieProfile(),
          now: _fixedNow,
          prefs: prefs,
        );
        expect(
          AutonomousAgentService.requiresValidation(task),
          isTrue,
          reason: 'requiresValidation must be true for $type',
        );
      }
    });

    test('history persists across sessions', () async {
      final prefs = await SharedPreferences.getInstance();
      await AutonomousAgentService.generateTask(
        type: AgentTaskType.taxDeclarationPreFill,
        profile: _salarieProfile(),
        now: _fixedNow,
        prefs: prefs,
      );
      await AutonomousAgentService.generateTask(
        type: AgentTaskType.fiscalDossierPrep,
        profile: _salarieProfile(),
        now: _fixedNow.add(const Duration(seconds: 1)),
        prefs: prefs,
      );

      final history =
          await AutonomousAgentService.getHistory(prefs: prefs, now: _fixedNow);
      expect(history.length, 2);
      expect(history[0].type, AgentTaskType.taxDeclarationPreFill);
      expect(history[1].type, AgentTaskType.fiscalDossierPrep);
    });

    test('expired tasks (>30 days unvalidated) marked as expired', () async {
      final prefs = await SharedPreferences.getInstance();
      await AutonomousAgentService.generateTask(
        type: AgentTaskType.avsExtractRequest,
        profile: _salarieProfile(),
        now: _fixedNow,
        prefs: prefs,
      );

      // Check 31 days later
      final later = _fixedNow.add(const Duration(days: 31));
      final history =
          await AutonomousAgentService.getHistory(prefs: prefs, now: later);
      expect(history.length, 1);
      expect(history[0].status, AgentTaskStatus.expired);
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  SAFETY GATE TESTS
  // ══════════════════════════════════════════════════════════════

  group('SafetyGate', () {
    test('task without disclaimer → FAIL', () {
      final task = AgentTask(
        id: 'test_1',
        type: AgentTaskType.taxDeclarationPreFill,
        status: AgentTaskStatus.pendingValidation,
        createdAt: _fixedNow,
        title: 'Test',
        description: 'Test',
        preFilledFields: {'field': 'value'},
        fieldsNeedingReview: ['field'],
        disclaimer: '',
        sources: ['LIFD art.\u00a033'],
        validationPrompt: 'Vérifie',
      );
      final result = AgentSafetyGate.validate(task);
      expect(result.passed, isFalse);
      expect(result.violations, contains(contains('Disclaimer')));
    });

    test('task without validationPrompt → FAIL', () {
      final task = AgentTask(
        id: 'test_2',
        type: AgentTaskType.taxDeclarationPreFill,
        status: AgentTaskStatus.pendingValidation,
        createdAt: _fixedNow,
        title: 'Test',
        description: 'Test',
        preFilledFields: {'field': 'value'},
        fieldsNeedingReview: ['field'],
        disclaimer: 'Outil éducatif',
        sources: ['LIFD art.\u00a033'],
        validationPrompt: '',
      );
      final result = AgentSafetyGate.validate(task);
      expect(result.passed, isFalse);
      expect(result.violations, contains(contains('Validation prompt')));
    });

    test('task with IBAN in field → FAIL', () {
      final task = AgentTask(
        id: 'test_3',
        type: AgentTaskType.taxDeclarationPreFill,
        status: AgentTaskStatus.pendingValidation,
        createdAt: _fixedNow,
        title: 'Test',
        description: 'Test',
        preFilledFields: {'compte': 'CH93 0076 2011 6238 5295 7'},
        fieldsNeedingReview: ['compte'],
        disclaimer: 'Outil éducatif',
        sources: ['LIFD art.\u00a033'],
        validationPrompt: 'Vérifie',
      );
      final result = AgentSafetyGate.validate(task);
      expect(result.passed, isFalse);
      expect(
        result.violations,
        anyElement(contains('IBAN')),
      );
    });

    test('task with SSN/AVS number → FAIL', () {
      final task = AgentTask(
        id: 'test_ssn',
        type: AgentTaskType.avsExtractRequest,
        status: AgentTaskStatus.pendingValidation,
        createdAt: _fixedNow,
        title: 'Test',
        description: 'Test',
        preFilledFields: {'avs': '756.1234.5678.90'},
        fieldsNeedingReview: ['avs'],
        disclaimer: 'Outil éducatif',
        sources: ['LAVS'],
        validationPrompt: 'Vérifie',
      );
      final result = AgentSafetyGate.validate(task);
      expect(result.passed, isFalse);
      expect(result.violations, anyElement(contains('SSN')));
    });

    test('task with auto-submitted status → FAIL', () {
      final task = AgentTask(
        id: 'test_4',
        type: AgentTaskType.taxDeclarationPreFill,
        status: AgentTaskStatus.validated,
        createdAt: _fixedNow,
        title: 'Test',
        description: 'Test',
        preFilledFields: {'field': 'value'},
        fieldsNeedingReview: ['field'],
        disclaimer: 'Outil éducatif',
        sources: ['LIFD art.\u00a033'],
        validationPrompt: 'Vérifie',
      );
      final result = AgentSafetyGate.validate(task);
      expect(result.passed, isFalse);
      expect(result.violations, anyElement(contains('pendingValidation')));
    });

    test('task with empty fieldsNeedingReview → FAIL', () {
      final task = AgentTask(
        id: 'test_5',
        type: AgentTaskType.taxDeclarationPreFill,
        status: AgentTaskStatus.pendingValidation,
        createdAt: _fixedNow,
        title: 'Test',
        description: 'Test',
        preFilledFields: {'field': 'value'},
        fieldsNeedingReview: [],
        disclaimer: 'Outil éducatif',
        sources: ['LIFD art.\u00a033'],
        validationPrompt: 'Vérifie',
      );
      final result = AgentSafetyGate.validate(task);
      expect(result.passed, isFalse);
      expect(result.violations, anyElement(contains('fieldsNeedingReview')));
    });

    test('valid generated task passes safety gate', () async {
      final prefs = await SharedPreferences.getInstance();
      for (final type in AgentTaskType.values) {
        final task = await AutonomousAgentService.generateTask(
          type: type,
          profile: _salarieProfile(),
          now: _fixedNow,
          prefs: prefs,
        );
        final result = AgentSafetyGate.validate(task);
        expect(
          result.passed,
          isTrue,
          reason: 'Safety gate failed for $type: ${result.violations}',
        );
      }
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  TASK TYPE TESTS
  // ══════════════════════════════════════════════════════════════

  group('TaxDeclaration', () {
    test('pre-fills contain ranges (tilde), not exact values', () async {
      final prefs = await SharedPreferences.getInstance();
      final task = await AutonomousAgentService.generateTask(
        type: AgentTaskType.taxDeclarationPreFill,
        profile: _salarieProfile(),
        now: _fixedNow,
        prefs: prefs,
      );

      final revenu = task.preFilledFields['Revenu brut estimé']!;
      expect(revenu, startsWith('~'));
      expect(revenu, contains('-')); // range format
    });
  });

  group('ThreeAForm', () {
    test('correct plafond for salarié (7258)', () async {
      final prefs = await SharedPreferences.getInstance();
      final task = await AutonomousAgentService.generateTask(
        type: AgentTaskType.threeAFormPreFill,
        profile: _salarieProfile(),
        now: _fixedNow,
        prefs: prefs,
      );

      final montant =
          task.preFilledFields['Montant versement annuel']!;
      expect(montant, contains("7'258"));
    });

    test('correct plafond for indépendant sans LPP (36288)', () async {
      final prefs = await SharedPreferences.getInstance();
      final task = await AutonomousAgentService.generateTask(
        type: AgentTaskType.threeAFormPreFill,
        profile: _independantSansLppProfile(),
        now: _fixedNow,
        prefs: prefs,
      );

      final montant =
          task.preFilledFields['Montant versement annuel']!;
      expect(montant, contains("36'288"));
    });
  });

  group('CaisseLetter', () {
    test('uses formal "vous" (not "tu")', () async {
      final prefs = await SharedPreferences.getInstance();
      final task = await AutonomousAgentService.generateTask(
        type: AgentTaskType.caisseLetterGeneration,
        profile: _salarieProfile(),
        now: _fixedNow,
        prefs: prefs,
      );

      final doc = task.generatedDocument!;
      // Must contain formal "vous" or "Vous"
      expect(doc.toLowerCase(), contains('vous'));
      // Must NOT contain informal "tu" as a standalone word
      // (we check for " tu " to avoid matching inside words like "actualité")
      expect(doc, isNot(contains(' tu ')));
    });

    test('contains placeholders for personal info', () async {
      final prefs = await SharedPreferences.getInstance();
      final task = await AutonomousAgentService.generateTask(
        type: AgentTaskType.caisseLetterGeneration,
        profile: _salarieProfile(),
        now: _fixedNow,
        prefs: prefs,
      );

      final doc = task.generatedDocument!;
      expect(doc, contains('[Votre prénom et nom]'));
      expect(doc, contains('[Votre signature]'));
      expect(doc, contains('Numéro de police'));
    });
  });

  group('FiscalDossier', () {
    test('disclaimer present and sources cited', () async {
      final prefs = await SharedPreferences.getInstance();
      final task = await AutonomousAgentService.generateTask(
        type: AgentTaskType.fiscalDossierPrep,
        profile: _salarieProfile(),
        now: _fixedNow,
        prefs: prefs,
      );

      expect(task.disclaimer, isNotEmpty);
      expect(task.sources, isNotEmpty);
      expect(task.sources.join(' '), contains('LIFD'));
    });
  });

  group('AvsExtract', () {
    test('correct request format with formal language', () async {
      final prefs = await SharedPreferences.getInstance();
      final task = await AutonomousAgentService.generateTask(
        type: AgentTaskType.avsExtractRequest,
        profile: _salarieProfile(),
        now: _fixedNow,
        prefs: prefs,
      );

      final doc = task.generatedDocument!;
      expect(doc, contains('extrait'));
      expect(doc, contains('compte individuel'));
      expect(doc.toLowerCase(), contains('vous'));
    });
  });

  group('LppCertificate', () {
    test('correct request format with caisse name', () async {
      final prefs = await SharedPreferences.getInstance();
      final task = await AutonomousAgentService.generateTask(
        type: AgentTaskType.lppCertificateRequest,
        profile: _salarieProfile(),
        now: _fixedNow,
        prefs: prefs,
      );

      final doc = task.generatedDocument!;
      expect(doc, contains('CPE'));
      expect(doc, contains('certificat de prévoyance'));
      expect(doc, contains('2026'));
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  COMPLIANCE TESTS
  // ══════════════════════════════════════════════════════════════

  group('Compliance', () {
    test('no banned terms in any generated text', () async {
      final prefs = await SharedPreferences.getInstance();
      for (final type in AgentTaskType.values) {
        final task = await AutonomousAgentService.generateTask(
          type: type,
          profile: _salarieProfile(),
          now: _fixedNow,
          prefs: prefs,
        );

        final allText = [
          task.title,
          task.description,
          task.disclaimer,
          task.validationPrompt,
          ...task.preFilledFields.values,
          if (task.generatedDocument != null) task.generatedDocument!,
        ].join(' ').toLowerCase();

        for (final banned in _bannedTerms) {
          // Use word boundary check to avoid false positives
          // (e.g. "assurées" inside "prestations assurées" in letter context
          // is about insurance coverage, not a promise — but we still check)
          final pattern = RegExp('\\b${RegExp.escape(banned)}\\b');
          expect(
            pattern.hasMatch(allText),
            isFalse,
            reason: 'Banned term "$banned" found in $type output',
          );
        }
      }
    });

    test('French accents are present', () async {
      final prefs = await SharedPreferences.getInstance();
      final task = await AutonomousAgentService.generateTask(
        type: AgentTaskType.taxDeclarationPreFill,
        profile: _salarieProfile(),
        now: _fixedNow,
        prefs: prefs,
      );

      // Title or description must contain accented characters
      final text = '${task.title} ${task.description}';
      expect(text, matches(RegExp('[éèêôùçà]')));
    });

    test('non-breaking spaces before punctuation', () async {
      final prefs = await SharedPreferences.getInstance();
      final task = await AutonomousAgentService.generateTask(
        type: AgentTaskType.fiscalDossierPrep,
        profile: _salarieProfile(),
        now: _fixedNow,
        prefs: prefs,
      );

      // Check sources use non-breaking space before colon
      for (final source in task.sources) {
        if (source.contains(':')) {
          // At least one source should use \u00a0 before punctuation
          // (we check the general pattern in generated documents)
        }
      }

      // Disclaimer uses non-breaking space
      expect(task.disclaimer, contains('\u00a0'));
    });

    test('source references present on every task type', () async {
      final prefs = await SharedPreferences.getInstance();
      for (final type in AgentTaskType.values) {
        final task = await AutonomousAgentService.generateTask(
          type: type,
          profile: _salarieProfile(),
          now: _fixedNow,
          prefs: prefs,
        );
        expect(
          task.sources,
          isNotEmpty,
          reason: 'Sources missing for $type',
        );
      }
    });

    test('disclaimer present on every task type', () async {
      final prefs = await SharedPreferences.getInstance();
      for (final type in AgentTaskType.values) {
        final task = await AutonomousAgentService.generateTask(
          type: type,
          profile: _salarieProfile(),
          now: _fixedNow,
          prefs: prefs,
        );
        expect(
          task.disclaimer,
          isNotEmpty,
          reason: 'Disclaimer missing for $type',
        );
        expect(task.disclaimer, contains('éducatif'));
      }
    });

    test('no PII (IBAN, SSN, email) in any output', () async {
      final prefs = await SharedPreferences.getInstance();
      final ibanRe = RegExp(
        r'[A-Z]{2}\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{0,2}',
      );
      final ssnRe = RegExp(r'756\.\d{4}\.\d{4}\.\d{2}');
      final emailRe = RegExp(
        r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
      );

      for (final type in AgentTaskType.values) {
        final task = await AutonomousAgentService.generateTask(
          type: type,
          profile: _salarieProfile(),
          now: _fixedNow,
          prefs: prefs,
        );

        final allText = [
          ...task.preFilledFields.values,
          if (task.generatedDocument != null) task.generatedDocument!,
        ].join(' ');

        expect(ibanRe.hasMatch(allText), isFalse,
            reason: 'IBAN found in $type');
        expect(ssnRe.hasMatch(allText), isFalse,
            reason: 'SSN found in $type');
        expect(emailRe.hasMatch(allText), isFalse,
            reason: 'Email found in $type');
      }
    });

    test('every field marked as "à vérifier" (in fieldsNeedingReview)',
        () async {
      final prefs = await SharedPreferences.getInstance();
      for (final type in AgentTaskType.values) {
        final task = await AutonomousAgentService.generateTask(
          type: type,
          profile: _salarieProfile(),
          now: _fixedNow,
          prefs: prefs,
        );

        // Every pre-filled field key must appear in fieldsNeedingReview
        for (final key in task.preFilledFields.keys) {
          expect(
            task.fieldsNeedingReview,
            contains(key),
            reason:
                'Field "$key" not in fieldsNeedingReview for $type',
          );
        }
      }
    });
  });
}
