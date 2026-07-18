import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/financial_report.dart';
import 'package:mint_mobile/models/lpp_capital_notice_specialist_handoff.dart';
import 'package:mint_mobile/services/financial_report_service.dart';

const _referenceId = '22222222-2222-4222-8222-222222222222';
final _confirmedAt = DateTime.utc(2026, 7, 18, 10, 15, 30);

LppCapitalNoticeSpecialistHandoff _handoff() {
  final capitalNoticeEvidence = SpecialistReferenceEvidence.tryFromJson(
    <String, dynamic>{
      'referenceId': _referenceId,
      'kind': 'lppCapitalNotice',
      'ownerKind': 'self',
      'source': 'certificate',
      'sourceDate': '2026-02-03',
      'legalYear': 2026,
      'confirmedAt': _confirmedAt.toIso8601String(),
      'deadlineDate': '2026-09-30',
    },
    expectedKind: SpecialistReferenceKind.lppCapitalNotice,
    now: _confirmedAt.add(const Duration(seconds: 1)),
  );
  final regulationEvidence = SpecialistReferenceEvidence.tryFromJson(
    <String, dynamic>{
      'referenceId': '11111111-1111-4111-8111-111111111111',
      'kind': 'lppRegulation',
      'ownerKind': 'self',
      'source': 'certificate',
      'sourceDate': '2026-02-03',
      'legalYear': 2026,
      'confirmedAt': _confirmedAt.toIso8601String(),
      'fundRelationship': 'currentFund',
    },
    expectedKind: SpecialistReferenceKind.lppRegulation,
    now: _confirmedAt.add(const Duration(seconds: 1)),
  );
  return LppCapitalNoticeSpecialistHandoff.tryFromResolvedEvidence(
    capitalNoticeEvidence: capitalNoticeEvidence,
    regulationEvidence: regulationEvidence,
  )!;
}

Map<String, dynamic> _answers() => <String, dynamic>{
      'q_birth_year': 1990,
      'q_canton': 'VD',
      'q_civil_status': 'single',
      'q_children': '0',
      'q_employment_status': 'employee',
      'q_net_income_period_chf': 6000.0,
    };

Map<String, dynamic> _financialFingerprint(FinancialReport report) =>
    <String, dynamic>{
      'profile': <Object?>[
        report.profile.birthYear,
        report.profile.canton,
        report.profile.civilStatus,
        report.profile.childrenCount,
        report.profile.employmentStatus,
        report.profile.monthlyNetIncome,
      ],
      'healthScore': <String, dynamic>{
        'overall': report.healthScore.overallScore,
        'priorities': report.healthScore.topPriorities,
        'circles': report.healthScore.allCircles
            .map(
              (circle) => <String, dynamic>{
                'percentage': circle.percentage,
                'level': circle.level.name,
                'items': circle.items
                    .map(
                      (item) => <Object?>[
                        item.label,
                        item.status.name,
                        item.detail,
                        item.weight,
                      ],
                    )
                    .toList(),
                'recommendations': circle.recommendations,
              },
            )
            .toList(),
      },
      'taxSimulation': <Object?>[
        report.taxSimulation.taxableIncome,
        report.taxSimulation.deductions,
        report.taxSimulation.cantonalTax,
        report.taxSimulation.federalTax,
        report.taxSimulation.totalTax,
        report.taxSimulation.effectiveRate,
        report.taxSimulation.taxWithLppBuyback,
        report.taxSimulation.taxSavingsFromBuyback,
      ],
      'retirementProjection': report.retirementProjection == null
          ? null
          : <Object?>[
              report.retirementProjection!.retirementAge,
              report.retirementProjection!.yearsUntilRetirement,
              report.retirementProjection!.lppCapital,
              report.retirementProjection!.pillar3aCapital,
              report.retirementProjection!.otherAssets,
              report.retirementProjection!.monthlyAvsRent,
              report.retirementProjection!.monthlyLppRent,
              report.retirementProjection!.currentMonthlyIncome,
              report.retirementProjection!.replacementRate,
            ],
      'lppBuybackStrategy': report.lppBuybackStrategy == null
          ? null
          : <String, dynamic>{
              'available': report.lppBuybackStrategy!.totalBuybackAvailable,
              'taxSavings': report.lppBuybackStrategy!.totalTaxSavings,
              'plan': report.lppBuybackStrategy!.yearlyPlan
                  .map(
                    (entry) => <Object?>[
                      entry.year,
                      entry.amount,
                      entry.estimatedTaxSavings,
                    ],
                  )
                  .toList(),
            },
      'priorityActions': report.priorityActions
          .map(
            (action) => <Object?>[
              action.title,
              action.description,
              action.priority.name,
              action.potentialGainChf,
              action.category.name,
              action.steps,
            ],
          )
          .toList(),
      'roadmap': report.personalizedRoadmap.phases
          .map(
            (phase) => <Object?>[
              phase.title,
              phase.timeframe,
              phase.actions
                  .map(
                    (action) => <Object?>[
                      action.title,
                      action.description,
                      action.priority.name,
                      action.potentialGainChf,
                      action.category.name,
                      action.steps,
                    ],
                  )
                  .toList(),
            ],
          )
          .toList(),
      'disclaimers': report.disclaimers,
      'sources': report.sources,
      'confidenceScore': report.confidenceScore,
      'enrichmentPrompts': report.enrichmentPrompts,
      'simulationAssumptions': report.simulationAssumptions,
    };

void main() {
  test(
      'report service defaults null and passes typed capital handoff unchanged',
      () {
    final service = FinancialReportService();
    final without = service.generateReport(_answers());
    expect(without.lppCapitalNoticeHandoff, isNull);

    final handoff = _handoff();
    final withHandoff = service.generateReport(
      _answers(),
      lppCapitalNoticeHandoff: handoff,
    );
    expect(withHandoff.lppCapitalNoticeHandoff, same(handoff));
    expect(
      _financialFingerprint(withHandoff),
      _financialFingerprint(without),
      reason: 'metadata-only handoff must not influence financial outputs',
    );
  });

  test('report service never derives capital authority from raw answers', () {
    final answers = _answers()
      ..['_coach_lpp_evidence_v1'] = <String, dynamic>{
        'referenceId': _referenceId,
        'authorityReferenceId': '11111111-1111-4111-8111-111111111111',
        'snapshotId': '33333333-3333-4333-8333-333333333333',
        'kind': 'lppCapitalNotice',
        'deadlineDate': '2026-09-30',
      };

    final report = FinancialReportService().generateReport(answers);
    expect(report.lppCapitalNoticeHandoff, isNull);

    final source =
        File('lib/services/financial_report_service.dart').readAsStringSync();
    expect(source, isNot(contains("['_coach_lpp_evidence_v1']")));
    expect(source, isNot(contains('authorityReferenceId')));
    expect(source, isNot(contains('toLocalJson')));
  });
}
