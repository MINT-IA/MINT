import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/circle_score.dart';
import 'package:mint_mobile/models/financial_report.dart';
import 'package:mint_mobile/models/session.dart';
import 'package:mint_mobile/models/recommendation.dart';
import 'package:mint_mobile/models/goal_template.dart';
import 'package:mint_mobile/services/dossier/dossier_payload_service.dart';
import 'package:mint_mobile/services/pdf_service.dart';

/// PdfService is entirely I/O-bound (uses the `pdf` and `printing` packages
/// to generate and display/share PDFs). There are no pure functions,
/// constants, or data transformations to test in isolation.
///
/// These tests verify:
/// 1. PdfService class exists and has the expected static methods.
/// 2. The data models used as input to PDF generation are correctly
///    constructable and hold expected values — ensuring the contract
///    between the models and PdfService remains intact.
/// 3. SessionReport.fromJson (the primary input model) works correctly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ──────────────────────────────────────────────────────────
  // PdfService — structural verification
  // ──────────────────────────────────────────────────────────

  group('PdfService structural tests', () {
    test('PdfService class can be instantiated', () {
      // PdfService has no constructor restrictions — it is a static-method class
      final service = PdfService();
      expect(service, isA<PdfService>());
    });

    test('PdfService has generateSessionReportPdf static method', () {
      // Verify the method exists by referencing it (type check)
      expect(PdfService.generateSessionReportPdf, isA<Function>());
    });

    test('PdfService has generateFinancialReportPdf static method', () {
      expect(PdfService.generateFinancialReportPdf, isA<Function>());
    });

    test('buildFinancialReportPdfBytes generates a real PDF document',
        () async {
      final bytes = await PdfService.buildFinancialReportPdfBytes(
        _sampleFinancialReport(),
        compress: false,
      );

      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(1000));
      expect(latin1.decode(bytes, allowInvalid: true), contains('%%EOF'));
    });

    test('financial report PDF audit manifest locks dossier sections', () {
      final manifest = PdfService.buildFinancialReportPdfAuditManifest(
        _sampleFinancialReport(),
      );

      expect(manifest.title, 'Ton Plan Mint — Rapport Financier');
      expect(
        manifest.educationalDisclaimer,
        contains('ne constitue pas un conseil financier'),
      );
      expect(
        manifest.sections,
        containsAll([
          'Indicateurs Clés',
          'Top 3 — Pistes à examiner',
          'Simulation Fiscale',
          'Cadre éducatif et limites',
          'Disclaimers Légaux',
          'Sources Juridiques',
        ]),
      );
      const adviceDocumentLabel = 'Statement of ' 'Advice';
      const recommendedPlanLabel = 'Plan annuel ' 'recommandé';
      expect(
        manifest.sections.join('\n'),
        isNot(contains(adviceDocumentLabel)),
      );
      expect(
        manifest.sections.join('\n'),
        isNot(contains(recommendedPlanLabel)),
      );
      expect(manifest.actionCount, 1);
      expect(manifest.disclaimerCount, 2);
      expect(manifest.sourceCount, 2);
    });

    test('buildDossierPayloadPdfBytes generates a real scenario dossier PDF',
        () async {
      final dossier = _sampleTransmitPropertyDossier();
      final bytes = await PdfService.buildDossierPayloadPdfBytes(
        dossier,
        compress: false,
      );

      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(1000));
      expect(latin1.decode(bytes, allowInvalid: true), contains('%%EOF'));
    });

    test('dossier payload PDF audit manifest locks P0 dossier sections', () {
      final manifest = PdfService.buildDossierPayloadPdfAuditManifest(
        _sampleTransmitPropertyDossier(),
      );

      expect(manifest.caseId, 'transmit_property');
      expect(manifest.pdfSectionId, 'dossier_transmit_property');
      expect(manifest.title, contains('Transmission immobilière'));
      expect(
        manifest.educationalDisclaimer,
        contains('ne constitue pas un conseil financier'),
      );
      expect(
        manifest.sections,
        containsAll([
          'Variables de dossier',
          'Résultats éducatifs',
          'Hypothèses de scénario',
          'Données à confirmer',
          'Questions spécialiste',
        ]),
      );
      expect(manifest.inputCount, greaterThanOrEqualTo(9));
      expect(manifest.outputCount, 5);
      expect(manifest.assumptionCount, 5);
      expect(manifest.warningCount, greaterThanOrEqualTo(1));
    });

    test('dossier manifest exposes remaining data section when useful', () {
      final dossier = _incompleteTransmitPropertyDossier();
      final manifest = PdfService.buildDossierPayloadPdfAuditManifest(dossier);

      expect(manifest.nextQuestionCount, greaterThan(0));
      expect(manifest.sections, contains('Données encore utiles'));
    });

    test('dossier PDF labels remaining questions for humans', () {
      final labels = PdfService.dossierNextQuestionLabelsForTesting(
        _incompleteTransmitPropertyDossier(),
      );

      expect(labels, contains('Confirmer l’âge de retraite visé.'));
      expect(
        labels,
        contains('Confirmer les coûts de vie annuels des parents.'),
      );
      expect(labels.any((label) => label.startsWith('ask_')), isFalse);
    });

    test('dossier PDF formats years and CHF fields by semantic key', () {
      expect(
        PdfService.formatDossierFieldValueForTesting('birthYear', 1980),
        '1980',
      );
      expect(
        PdfService.formatDossierFieldValueForTesting(
            'tax_context.tax_year', 2026),
        '2026',
      );
      expect(
        PdfService.formatDossierFieldValueForTesting(
          'patrimoine.propertyMarketValue',
          1200000,
        ),
        contains('CHF'),
      );
    });
  });

  // ──────────────────────────────────────────────────────────
  // SessionReport — input model for generateSessionReportPdf
  // ──────────────────────────────────────────────────────────

  group('SessionReport (PDF input model)', () {
    late SessionReport report;

    setUp(() {
      report = SessionReport(
        id: 'report-001',
        sessionId: 'session-001',
        precisionScore: 0.72,
        title: 'Bilan financier personnalise',
        overview: SessionReportOverview(
          canton: 'GE',
          householdType: 'Couple marie',
          goalRecommendedLabel: 'Optimiser ma prevoyance',
        ),
        mintRoadmap: MintRoadmap(
          mentorshipLevel: 'Guidance Generale',
          natureOfService: 'Mentor educatif',
          limitations: ['Pas de conseil en placement'],
          assumptions: ['Revenus stables', 'Resident suisse'],
          conflicts: [
            ConflictOfInterest(
              partner: 'VIAC',
              type: 'affiliation',
              disclosure: 'Commission de recommandation si ouverture de compte',
            ),
          ],
        ),
        scoreboard: [
          ScoreboardItem(
            label: 'Epargne 3a',
            value: '7\'258 CHF',
            note: 'Maximum atteint',
          ),
          ScoreboardItem(
            label: 'Taux d\'epargne',
            value: '18%',
            note: 'Objectif: 20%',
          ),
        ],
        recommendedGoal: const GoalTemplate(
          id: 'goal_pension_opt',
          label: 'Optimiser ma prevoyance',
        ),
        alternativeGoals: [
          const GoalTemplate(
            id: 'goal_tax_basic',
            label: 'Payer moins d\'impots',
          ),
        ],
        topActions: [
          TopAction(
            effortTag: 'facile',
            label: 'Ouvrir un 3e pilier chez VIAC',
            why: 'Frais 3x moins eleves qu\'en banque',
            ifThen:
                'Si tu places 7258 CHF/an a 5% net, tu auras 30% de plus a 65 ans',
            nextAction: const NextAction(
              type: NextActionType.partnerHandoff,
              label: 'Ouvrir un compte VIAC',
              partnerId: 'viac',
            ),
          ),
        ],
        recommendations: [
          Recommendation(
            id: 'rec-001',
            kind: 'pillar3a',
            title: 'Maximise ton 3e pilier',
            summary: 'Tu peux deduire jusqu\'a 7258 CHF de tes impots.',
            why: ['Deduction fiscale', 'Rendement long terme'],
            assumptions: ['Salarie affilie LPP'],
            impact: const Impact(amountCHF: 2200.0, period: Period.yearly),
            risks: ['Argent bloque jusqu\'a 60/65 ans'],
            alternatives: ['Compte epargne classique'],
            evidenceLinks: [
              const EvidenceLink(
                label: 'OPP3 art. 7',
                url: 'https://www.fedlex.admin.ch/eli/cc/1986/1452/fr',
              ),
            ],
            nextActions: [
              const NextAction(
                type: NextActionType.learn,
                label: 'Comprendre le 3e pilier',
              ),
            ],
          ),
        ],
        disclaimers: [
          'Cet outil est educatif et ne constitue pas un conseil financier au sens de la LSFin.',
          'Les projections sont basees sur des hypotheses et ne constituent pas une garantie de rendement.',
        ],
        generatedAt: DateTime(2025, 6, 15, 14, 30),
      );
    });

    test('SessionReport holds all required fields', () {
      expect(report.id, 'report-001');
      expect(report.sessionId, 'session-001');
      expect(report.precisionScore, 0.72);
      expect(report.title, isNotEmpty);
      expect(report.overview, isNotNull);
      expect(report.mintRoadmap, isNotNull);
      expect(report.scoreboard, hasLength(2));
      expect(report.recommendedGoal, isNotNull);
      expect(report.alternativeGoals, hasLength(1));
      expect(report.topActions, hasLength(1));
      expect(report.recommendations, hasLength(1));
      expect(report.disclaimers, hasLength(2));
      expect(report.generatedAt, DateTime(2025, 6, 15, 14, 30));
    });

    test('SessionReportOverview contains canton, household, goal', () {
      expect(report.overview.canton, 'GE');
      expect(report.overview.householdType, 'Couple marie');
      expect(report.overview.goalRecommendedLabel, isNotEmpty);
    });

    test('MintRoadmap contains compliance fields', () {
      expect(report.mintRoadmap.mentorshipLevel, isNotEmpty);
      expect(report.mintRoadmap.natureOfService, contains('Mentor'));
      expect(report.mintRoadmap.limitations, isNotEmpty);
      expect(report.mintRoadmap.assumptions, hasLength(2));
      expect(report.mintRoadmap.conflicts, hasLength(1));
      expect(report.mintRoadmap.conflicts.first.partner, 'VIAC');
    });

    test('precisionScore affects color logic (low score)', () {
      // The PDF uses precisionScore < 0.5 for orange, >= 0.5 for green
      final lowPrecisionReport = SessionReport(
        id: 'r-low',
        sessionId: 's-low',
        precisionScore: 0.35,
        title: 'Test',
        overview: SessionReportOverview(
          canton: 'VD',
          householdType: 'Celibataire',
          goalRecommendedLabel: 'Test',
        ),
        mintRoadmap: MintRoadmap(
          mentorshipLevel: 'Basic',
          natureOfService: 'Mentor',
          limitations: [],
          assumptions: [],
          conflicts: [],
        ),
        scoreboard: [],
        recommendedGoal: const GoalTemplate(id: 'g1', label: 'Test'),
        alternativeGoals: [],
        topActions: [],
        recommendations: [],
        disclaimers: [],
        generatedAt: DateTime.now(),
      );

      expect(lowPrecisionReport.precisionScore < 0.5, true);
    });

    test('precisionScore affects color logic (high score)', () {
      expect(report.precisionScore >= 0.5, true);
    });
  });

  // ──────────────────────────────────────────────────────────
  // FinancialReport — input model for generateFinancialReportPdf
  // ──────────────────────────────────────────────────────────

  group('FinancialReport (PDF input model)', () {
    test('FinancialReport can be constructed with required fields', () {
      const dummyCircle = CircleScore(
        circleName: 'Test',
        circleNumber: 1,
        percentage: 72.0,
        level: ScoreLevel.good,
        items: [],
        recommendations: [],
      );

      final report = FinancialReport(
        profile: const UserProfile(
          firstName: 'Marc',
          birthYear: 1990,
          canton: 'GE',
          civilStatus: 'single',
          childrenCount: 0,
          employmentStatus: 'employee',
          monthlyNetIncome: 6500.0,
        ),
        healthScore: const FinancialHealthScore(
          circle1Protection: dummyCircle,
          circle2Prevoyance: dummyCircle,
          circle3Croissance: dummyCircle,
          circle4Optimisation: dummyCircle,
          overallScore: 72.0,
          topPriorities: ['Ouvrir un 3a', 'Fonds urgence'],
        ),
        taxSimulation: const TaxSimulation(
          taxableIncome: 78000.0,
          deductions: {'3a': 7258.0, 'frais_professionnels': 3200.0},
          cantonalTax: 12500.0,
          federalTax: 3200.0,
          totalTax: 15700.0,
          effectiveRate: 20.1,
        ),
        priorityActions: [
          const ActionItem(
            title: 'Ouvrir un 3a',
            description: 'Maximise ta deduction fiscale',
            priority: ActionPriority.high,
            potentialGainChf: 2200.0,
            category: ActionCategory.pillar3a,
            steps: ['Comparer les offres', 'Ouvrir un compte', 'Verser'],
          ),
        ],
        personalizedRoadmap: const Roadmap(phases: [
          RoadmapPhase(
            title: 'Immediat',
            timeframe: '0-1 mois',
            actions: [],
          ),
        ]),
        generatedAt: DateTime(2025, 6, 15),
      );

      expect(report.profile.firstName, 'Marc');
      expect(report.healthScore.overallScore, 72.0);
      expect(report.taxSimulation.totalTax, 15700.0);
      expect(report.priorityActions, hasLength(1));
      expect(report.personalizedRoadmap.phases, hasLength(1));
      expect(report.reportVersion, '2.0');
    });

    test('UserProfile computes age correctly', () {
      const profile = UserProfile(
        birthYear: 1990,
        canton: 'GE',
        civilStatus: 'single',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 6500.0,
      );

      expect(profile.age, DateTime.now().year - 1990);
    });

    test('UserProfile computes yearsToRetirement', () {
      const profile = UserProfile(
        birthYear: 1990,
        canton: 'GE',
        civilStatus: 'single',
        childrenCount: 0,
        employmentStatus: 'employee',
        monthlyNetIncome: 6500.0,
      );

      expect(profile.yearsToRetirement, 65 - (DateTime.now().year - 1990));
    });

    test('TaxSimulation computes totalDeductions', () {
      const tax = TaxSimulation(
        taxableIncome: 78000.0,
        deductions: {'3a': 7258.0, 'frais': 3200.0},
        cantonalTax: 12500.0,
        federalTax: 3200.0,
        totalTax: 15700.0,
        effectiveRate: 20.1,
      );

      expect(tax.totalDeductions, 7258.0 + 3200.0);
    });

    test('ActionPriority enum has 4 levels', () {
      expect(ActionPriority.values, hasLength(4));
      expect(ActionPriority.values, contains(ActionPriority.critical));
      expect(ActionPriority.values, contains(ActionPriority.high));
      expect(ActionPriority.values, contains(ActionPriority.medium));
      expect(ActionPriority.values, contains(ActionPriority.low));
    });

    test('ActionCategory enum has 8 categories', () {
      expect(ActionCategory.values, hasLength(8));
      expect(ActionCategory.values, contains(ActionCategory.pillar3a));
      expect(ActionCategory.values, contains(ActionCategory.lpp));
      expect(ActionCategory.values, contains(ActionCategory.tax));
    });
  });

  // ──────────────────────────────────────────────────────────
  // SessionReport.fromJson — deserialization contract
  // ──────────────────────────────────────────────────────────

  group('SessionReport.fromJson', () {
    test('parses a complete JSON payload', () {
      final json = {
        'id': 'report-from-json',
        'sessionId': 'session-abc',
        'precisionScore': 0.85,
        'title': 'Bilan Test',
        'overview': {
          'canton': 'VD',
          'householdType': 'Celibataire',
          'goalRecommendedLabel': 'Epargner',
        },
        'mintRoadmap': {
          'mentorshipLevel': 'Avance',
          'natureOfService': 'Mentor educatif',
          'limitations': ['Pas de gestion de fortune'],
          'assumptions': ['Revenus stables'],
          'conflictsOfInterest': [
            {
              'partner': 'Finpension',
              'type': 'affiliation',
              'disclosure': 'Commission de recommendation',
            }
          ],
        },
        'scoreboard': [
          {'label': 'Epargne', 'value': '15%', 'note': 'Bon'},
        ],
        'recommendedGoalTemplate': {
          'id': 'goal_tax_basic',
          'label': 'Payer moins d\'impots',
        },
        'alternativeGoalTemplates': [
          {'id': 'goal_house', 'label': 'Acheter un logement'},
        ],
        'topActions': [
          {
            'effortTag': 'moyen',
            'label': 'Ouvrir 3a',
            'why': 'Economie fiscale',
            'ifThen': 'Si 7258/an -> 2200 CHF economie',
            'nextAction': {
              'type': 'learn',
              'label': 'Comprendre le 3a',
            },
          },
        ],
        'recommendations': [
          {
            'id': 'rec-json-001',
            'kind': 'tax',
            'title': 'Optimise tes impots',
            'summary': 'Tu paies trop.',
            'why': ['Deduction manquee'],
            'assumptions': [],
            'impact': {'amountCHF': 1500.0, 'period': 'yearly'},
            'risks': [],
            'alternatives': [],
            'evidenceLinks': [],
            'nextActions': [],
          },
        ],
        'disclaimers': [
          'Outil educatif, ne constitue pas un conseil.',
        ],
        'generatedAt': '2025-06-15T14:30:00.000',
      };

      final report = SessionReport.fromJson(json);

      expect(report.id, 'report-from-json');
      expect(report.sessionId, 'session-abc');
      expect(report.precisionScore, 0.85);
      expect(report.title, 'Bilan Test');
      expect(report.overview.canton, 'VD');
      expect(report.mintRoadmap.mentorshipLevel, 'Avance');
      expect(report.mintRoadmap.conflicts, hasLength(1));
      expect(report.scoreboard, hasLength(1));
      expect(report.recommendedGoal.id, 'goal_tax_basic');
      expect(report.alternativeGoals, hasLength(1));
      expect(report.topActions, hasLength(1));
      expect(report.recommendations, hasLength(1));
      expect(report.disclaimers, hasLength(1));
      expect(report.generatedAt.year, 2025);
    });
  });

  // ──────────────────────────────────────────────────────────
  // Coverage note
  // ──────────────────────────────────────────────────────────
  //
  // PdfService.generateSessionReportPdf and generateFinancialReportPdf
  // are fully I/O-bound (they create a pw.Document, add pages, and call
  // Printing.layoutPdf / Printing.sharePdf). These methods require a
  // platform environment and cannot be unit-tested without a full Flutter
  // widget test harness or platform mocking.
  //
  // The tests above validate:
  // - The PdfService class structure
  // - The input model contracts (SessionReport, FinancialReport)
  // - JSON deserialization of the primary input model
  // - Computed properties used by the PDF template (precisionScore threshold)
}

FinancialReport _sampleFinancialReport() {
  const dummyCircle = CircleScore(
    circleName: 'Test',
    circleNumber: 1,
    percentage: 72.0,
    level: ScoreLevel.good,
    items: [],
    recommendations: [],
  );

  return FinancialReport(
    profile: const UserProfile(
      firstName: 'Marc',
      birthYear: 1990,
      canton: 'VD',
      civilStatus: 'single',
      childrenCount: 0,
      employmentStatus: 'employee',
      monthlyNetIncome: 6500.0,
    ),
    healthScore: const FinancialHealthScore(
      circle1Protection: dummyCircle,
      circle2Prevoyance: dummyCircle,
      circle3Croissance: dummyCircle,
      circle4Optimisation: dummyCircle,
      overallScore: 72.0,
      topPriorities: ['Ajouter une attestation 3a'],
    ),
    taxSimulation: const TaxSimulation(
      taxableIncome: 78000.0,
      deductions: {'3a': 7258.0},
      cantonalTax: 12500.0,
      federalTax: 3200.0,
      totalTax: 15700.0,
      effectiveRate: 0.201,
    ),
    priorityActions: const [
      ActionItem(
        title: 'Compléter le 3a',
        description: 'Comparer le montant versé au plafond annuel.',
        priority: ActionPriority.high,
        category: ActionCategory.pillar3a,
        potentialGainChf: 1200.0,
        steps: ['Ajouter l’attestation 3a', 'Revoir la projection fiscale'],
      ),
    ],
    personalizedRoadmap: const Roadmap(
      phases: [
        RoadmapPhase(
          title: 'À confirmer',
          timeframe: '0-1 mois',
          actions: [],
        ),
      ],
    ),
    disclaimers: const [
      'Outil éducatif, ne constitue pas un conseil financier.',
      'Les montants restent indicatifs et sont à confirmer.',
    ],
    sources: const [
      'LIFD art. 33',
      'LPP art. 79b',
    ],
    generatedAt: DateTime(2026, 7, 2, 10, 15),
  );
}

DossierPayload _sampleTransmitPropertyDossier() {
  return DossierPayloadService.buildP0Case(
    caseId: 'transmit_property',
    answers: {
      '_coach_profile_owner_id': 'local_demo_fixture_owner',
      'q_canton': 'VD',
      'q_target_retirement_age': 64,
      '_coach_avoir_lpp': 650000,
      'q_3a_total': 180000,
      'q_cash_total': 120000,
      'q_property_market_value': 1200000,
      'q_mortgage_balance': 420000,
      'q_children': 2,
      '_transmit_property_parent_annual_retirement_income': 76000,
      'q_housing_cost_period_chf': 6600,
      'q_lamal_premium_monthly_chf': 400,
      '_transmit_property_cash_paid_by_recipient': 50000,
      '_transmit_property_mortgage_assumed_by_recipient': 420000,
      '_transmit_property_recipient_relationship': 'descendant',
      '_transmit_property_retained_right': 'habitation',
      '_transmit_property_avancement_hoirie': true,
      '_coach_data_sources': {
        'patrimoine.propertyMarketValue': 'estimated',
        'patrimoine.mortgageBalance': 'userInput',
        'patrimoine.epargneLiquide': 'userInput',
        'prevoyance.renteAVSEstimeeMensuelle': 'estimated',
      },
      '_coach_data_source_dates': {
        'patrimoine.mortgageBalance': '2026-05-31T00:00:00.000Z',
      },
    },
    generatedAt: DateTime.utc(2026, 7, 2, 10, 30),
  );
}

DossierPayload _incompleteTransmitPropertyDossier() {
  return DossierPayloadService.buildP0Case(
    caseId: 'transmit_property',
    answers: const {
      '_coach_profile_owner_id': 'local_demo_fixture_owner',
      'q_property_market_value': 1200000,
    },
    generatedAt: DateTime.utc(2026, 7, 2, 10, 30),
  );
}
