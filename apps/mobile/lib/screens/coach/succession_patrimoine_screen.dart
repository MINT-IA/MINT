// Succession & Patrimoine — Sprint S44 (Phase 2 — AgeBand 65+).
//
// Écran éducatif sur la succession et la transmission du patrimoine.
// Cible : profils AgeBand.retirement (65+), particulièrement 70+.
//
// Sources légales : CC art. 457-640, LPP art. 20, OPP3 art. 2.
// Disclaimer LSFin obligatoire (outil éducatif, pas un conseil juridique).
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/data_quest/data_quest_service.dart';
import 'package:mint_mobile/services/dossier/dossier_payload_service.dart';
import 'package:mint_mobile/services/financial_core/property_transmission_calculator.dart';
import 'package:mint_mobile/services/startup_route_override.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/coach/edu_shared_widgets.dart';
import 'package:mint_mobile/widgets/coach/testament_invisible_widget.dart';
import 'package:mint_mobile/widgets/coach/avancement_hoirie_widget.dart';
import 'package:mint_mobile/widgets/coach/death_urgency_guide_widget.dart';
import 'package:mint_mobile/widgets/data_quest/data_quest_proof_strip.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:provider/provider.dart';

const bool _runtimeProofSemanticsEnabled =
    kDebugMode || bool.fromEnvironment('MINT_ENABLE_RUNTIME_PROOF_SEMANTICS');

const String _propertyMarketValueFieldPath = 'patrimoine.propertyMarketValue';
const List<String> _parentAnnualRetirementIncomeAnswerKeys = [
  'q_parent_annual_retirement_income',
  '_transmit_property_parent_annual_retirement_income',
];

String _propertyLedgerSource(CoachProfile? profile) {
  return profile?.dataSources[_propertyMarketValueFieldPath]?.name ?? 'missing';
}

String _propertyLedgerConfidence(CoachProfile? profile) {
  if (profile?.patrimoine.propertyMarketValue == null) return 'missing';
  return switch (profile?.dataSources[_propertyMarketValueFieldPath]) {
    ProfileDataSource.certificate ||
    ProfileDataSource.openBanking ||
    ProfileDataSource.crossValidated =>
      'high',
    ProfileDataSource.userInput || ProfileDataSource.estimated => 'medium',
    null => 'missing',
  };
}

String _scenarioConfidenceLabel(S l, PropertyScenarioConfidence confidence) {
  return switch (confidence) {
    PropertyScenarioConfidence.none => l.successionScenarioConfidenceNone,
    PropertyScenarioConfidence.medium => l.successionScenarioConfidenceMedium,
  };
}

String _propertyTransmissionText(S l, String key) {
  return switch (key) {
    'successionPropertyTransmissionArticleThesis' =>
      l.successionPropertyTransmissionArticleThesis,
    'successionPropertyTransmissionConfidenceLimitLegal' =>
      l.successionPropertyTransmissionConfidenceLimitLegal,
    'successionPropertyTransmissionConfidenceLimitAccuracy' =>
      l.successionPropertyTransmissionConfidenceLimitAccuracy,
    'successionPropertyTransmissionConfidenceLimitFreshness' =>
      l.successionPropertyTransmissionConfidenceLimitFreshness,
    'successionPropertyTransmissionConfidenceLimitLiquidityBufferAssumption' =>
      l.successionPropertyTransmissionConfidenceLimitLiquidityBufferAssumption,
    'successionPropertyTransmissionConfidenceLimitLppCapitalTax' =>
      l.successionPropertyTransmissionConfidenceLimitLppCapitalTax,
    'successionPropertyTransmissionScopeSpousePartner' =>
      l.successionPropertyTransmissionScopeSpousePartner,
    'successionPropertyTransmissionScopeMatrimonialRegime' =>
      l.successionPropertyTransmissionScopeMatrimonialRegime,
    'successionPropertyTransmissionScopeLegalShares' =>
      l.successionPropertyTransmissionScopeLegalShares,
    'successionPropertyTransmissionScopeEstateInstrument' =>
      l.successionPropertyTransmissionScopeEstateInstrument,
    'successionPropertyTransmissionScopeEstateComposition' =>
      l.successionPropertyTransmissionScopeEstateComposition,
    'successionPropertyTransmissionScopeCantonalRelationship' =>
      l.successionPropertyTransmissionScopeCantonalRelationship,
    'successionPropertyTransmissionMissingRequiredInputs' =>
      l.successionPropertyTransmissionMissingRequiredInputs,
    'successionPropertyTransmissionCantonalTaxNoFederalDonationTax' =>
      l.successionPropertyTransmissionCantonalTaxNoFederalDonationTax,
    'successionPropertyTransmissionCantonalTaxBeneficiaryPays' =>
      l.successionPropertyTransmissionCantonalTaxBeneficiaryPays,
    'successionPropertyTransmissionCantonalTaxImmovableLocation' =>
      l.successionPropertyTransmissionCantonalTaxImmovableLocation,
    'successionPropertyTransmissionCantonalTaxDescendantOftenExempt' =>
      l.successionPropertyTransmissionCantonalTaxDescendantOftenExempt,
    'successionPropertyTransmissionCantonalTaxRetainedRightCanChangeTax' =>
      l.successionPropertyTransmissionCantonalTaxRetainedRightCanChangeTax,
    'successionPropertyTransmissionRetainedRightHabitationLabel' =>
      l.successionPropertyTransmissionRetainedRightHabitationLabel,
    'successionPropertyTransmissionRetainedRightUsufructLabel' =>
      l.successionPropertyTransmissionRetainedRightUsufructLabel,
    'successionPropertyTransmissionRetainedRightNoneLabel' =>
      l.successionPropertyTransmissionRetainedRightNoneLabel,
    'successionPropertyTransmissionRetainedRightHabitationStay' =>
      l.successionPropertyTransmissionRetainedRightHabitationStay,
    'successionPropertyTransmissionRetainedRightHabitationPersonal' =>
      l.successionPropertyTransmissionRetainedRightHabitationPersonal,
    'successionPropertyTransmissionRetainedRightHabitationTaxCharges' =>
      l.successionPropertyTransmissionRetainedRightHabitationTaxCharges,
    'successionPropertyTransmissionRetainedRightUsufructUseOrRent' =>
      l.successionPropertyTransmissionRetainedRightUsufructUseOrRent,
    'successionPropertyTransmissionRetainedRightUsufructCharges' =>
      l.successionPropertyTransmissionRetainedRightUsufructCharges,
    'successionPropertyTransmissionRetainedRightUsufructValueAgeCanton' =>
      l.successionPropertyTransmissionRetainedRightUsufructValueAgeCanton,
    'successionPropertyTransmissionRetainedRightNoneHousingCosts' =>
      l.successionPropertyTransmissionRetainedRightNoneHousingCosts,
    'successionPropertyTransmissionVariantMarketSaleLabel' =>
      l.successionPropertyTransmissionVariantMarketSaleLabel,
    'successionPropertyTransmissionVariantMarketSaleTradeoff' =>
      l.successionPropertyTransmissionVariantMarketSaleTradeoff,
    'successionPropertyTransmissionVariantAdvanceInheritanceLabel' =>
      l.successionPropertyTransmissionVariantAdvanceInheritanceLabel,
    'successionPropertyTransmissionVariantAdvanceInheritanceTradeoff' =>
      l.successionPropertyTransmissionVariantAdvanceInheritanceTradeoff,
    'successionPropertyTransmissionVariantMixedDonationLabel' =>
      l.successionPropertyTransmissionVariantMixedDonationLabel,
    'successionPropertyTransmissionVariantMixedDonationTradeoff' =>
      l.successionPropertyTransmissionVariantMixedDonationTradeoff,
    'successionPropertyTransmissionVariantRetainedRightLabel' =>
      l.successionPropertyTransmissionVariantRetainedRightLabel,
    'successionPropertyTransmissionVariantRetainedRightTradeoff' =>
      l.successionPropertyTransmissionVariantRetainedRightTradeoff,
    'successionPropertyTransmissionFormalityEstimateValue' =>
      l.successionPropertyTransmissionFormalityEstimateValue,
    'successionPropertyTransmissionFormalityMortgageLiquidity' =>
      l.successionPropertyTransmissionFormalityMortgageLiquidity,
    'successionPropertyTransmissionFormalityRetirementCapacity' =>
      l.successionPropertyTransmissionFormalityRetirementCapacity,
    'successionPropertyTransmissionFormalityDocumentAdvanceInheritance' =>
      l.successionPropertyTransmissionFormalityDocumentAdvanceInheritance,
    'successionPropertyTransmissionFormalityNotary' =>
      l.successionPropertyTransmissionFormalityNotary,
    'successionPropertyTransmissionFormalityLandRegistry' =>
      l.successionPropertyTransmissionFormalityLandRegistry,
    'successionPropertyTransmissionRetirementReasonNegativeMargin' =>
      l.successionPropertyTransmissionRetirementReasonNegativeMargin,
    'successionPropertyTransmissionRetirementReasonLiquidityCoverageBelowThreeYears' =>
      l.successionPropertyTransmissionRetirementReasonLiquidityCoverageBelowThreeYears,
    'successionPropertyTransmissionFamilyEqualizationNoOtherHeir' =>
      l.successionPropertyTransmissionFamilyEqualizationNoOtherHeir,
    'successionPropertyTransmissionFamilyEqualizationAdvanceInheritance' =>
      l.successionPropertyTransmissionFamilyEqualizationAdvanceInheritance,
    'successionPropertyTransmissionFamilyEqualizationDispense' =>
      l.successionPropertyTransmissionFamilyEqualizationDispense,
    'successionPropertyTransmissionFamilyEqualizationOtherHeirsEquity' =>
      l.successionPropertyTransmissionFamilyEqualizationOtherHeirsEquity,
    _ => key,
  };
}

double? _scenarioDouble(Object? value) {
  if (value == null || value is bool) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String? _scenarioString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

bool? _scenarioBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    switch (value.toLowerCase().trim()) {
      case 'true':
      case 'yes':
      case 'oui':
      case '1':
        return true;
      case 'false':
      case 'no':
      case 'non':
      case '0':
        return false;
    }
  }
  return null;
}

Object? _firstScenarioAnswer(
  Map<String, dynamic> answers,
  List<String> keys,
) {
  for (final key in keys) {
    if (answers.containsKey(key)) return answers[key];
  }
  return null;
}

bool _hasKnownScenarioField(CoachProfile profile, String fieldPath) {
  return profile.dataSources.containsKey(fieldPath) ||
      profile.userProvidedFields.contains(fieldPath);
}

DateTime? _oldestScenarioEvidenceDate(
  CoachProfile profile,
  List<String> fieldPaths,
) {
  DateTime? oldest;
  for (final fieldPath in fieldPaths) {
    final candidate =
        profile.dataSourceDates[fieldPath] ?? profile.dataTimestamps[fieldPath];
    if (candidate == null) continue;
    if (oldest == null || candidate.isBefore(oldest)) {
      oldest = candidate;
    }
  }
  return oldest;
}

_RetirementIncomeSnapshot _parentAnnualRetirementIncomeSnapshot(
  CoachProfile profile,
  Map<String, dynamic> answers,
) {
  final explicit = _scenarioDouble(
    _firstScenarioAnswer(answers, _parentAnnualRetirementIncomeAnswerKeys),
  );
  if (explicit != null) {
    return _RetirementIncomeSnapshot(
      value: explicit,
      source: ProfileDataSource.userInput.name,
      sourceDate: _oldestScenarioEvidenceDate(
        profile,
        const ['parentAnnualRetirementIncome'],
      ),
    );
  }

  final prevoyance = profile.prevoyance;
  final avsMonthly = prevoyance.renteAVSEstimeeMensuelle;
  final lppAnnual = prevoyance.projectedRenteLpp;
  if (avsMonthly == null || lppAnnual == null) {
    return const _RetirementIncomeSnapshot(
      value: null,
      source: 'missing',
    );
  }
  final derivedFrom = <String>[
    'prevoyance.renteAVSEstimeeMensuelle',
    'prevoyance.projectedRenteLpp',
  ];
  return _RetirementIncomeSnapshot(
    value: (avsMonthly * 12) + lppAnnual,
    source: ProfileDataSource.estimated.name,
    derivedFrom: derivedFrom,
    sourceDate: _oldestScenarioEvidenceDate(profile, derivedFrom),
  );
}

DateTime? _oldestScenarioSourceDate(
  CoachProfile profile,
  List<String> fieldPaths,
) {
  DateTime? oldest;
  for (final fieldPath in fieldPaths) {
    final candidate =
        profile.dataSourceDates[fieldPath] ?? profile.dataTimestamps[fieldPath];
    if (candidate == null) continue;
    if (oldest == null || candidate.isBefore(oldest)) {
      oldest = candidate;
    }
  }
  return oldest;
}

PropertyTransmissionInputs _propertyTransmissionInputsFromProfile(
  CoachProfile profile,
  Map<String, dynamic> scenarioAssumptions,
  Map<String, dynamic> answers,
) {
  final retirementIncome =
      _parentAnnualRetirementIncomeSnapshot(profile, answers);
  final dataQuestFacts = DossierPayloadService.dataQuestFactsFromProfile(
    profile: profile,
    answers: answers,
  );
  final livingCostsFact = dataQuestFacts['parentAnnualLivingCosts'];
  final annualLivingCosts = _scenarioDouble(livingCostsFact?.value);
  final liquidAssets = profile.patrimoine.epargneLiquide;
  final hasKnownLiquidAssets = liquidAssets > 0 ||
      _hasKnownScenarioField(profile, 'patrimoine.epargneLiquide');
  final propertyValueSourceDate = _oldestScenarioSourceDate(profile, const [
    'patrimoine.propertyMarketValue',
  ]);
  final mortgageSourceDate = _oldestScenarioSourceDate(profile, const [
    'patrimoine.mortgageBalance',
  ]);
  final liquidAssetsSourceDate = _oldestScenarioSourceDate(profile, const [
    'patrimoine.epargneLiquide',
  ]);
  final sourceDates = <String, DateTime>{
    if (propertyValueSourceDate != null)
      'propertyMarketValue': propertyValueSourceDate,
    if (mortgageSourceDate != null) 'mortgageBalance': mortgageSourceDate,
    if (liquidAssetsSourceDate != null)
      'parentLiquidAssets': liquidAssetsSourceDate,
    if (retirementIncome.sourceDate != null)
      'parentAnnualRetirementIncome': retirementIncome.sourceDate!,
    if (livingCostsFact?.sourceDate != null)
      'parentAnnualLivingCosts': livingCostsFact!.sourceDate!,
  };

  return PropertyTransmissionInputs(
    canton: profile.canton.isEmpty ? 'VD' : profile.canton,
    propertyMarketValue: profile.patrimoine.propertyMarketValue,
    mortgageBalance: profile.patrimoine.mortgageBalance,
    cashPaidByRecipient:
        _scenarioDouble(scenarioAssumptions['cashPaidByRecipient']),
    mortgageAssumedByRecipient:
        _scenarioDouble(scenarioAssumptions['mortgageAssumedByRecipient']),
    parentLiquidAssets: hasKnownLiquidAssets ? liquidAssets : null,
    parentAnnualRetirementIncome: retirementIncome.value,
    parentAnnualRetirementIncomeSource: retirementIncome.calculatorSource,
    parentAnnualRetirementIncomeSourceKeys: retirementIncome.derivedFrom,
    inputSourceDates: sourceDates,
    parentAnnualLivingCosts: annualLivingCosts,
    heirsCount: profile.nombreEnfants,
    recipientRelationship:
        _scenarioString(scenarioAssumptions['recipientRelationship']) ??
            'descendant',
    retainedRight:
        _scenarioString(scenarioAssumptions['retainedRight']) ?? 'none',
    avancementHoirie:
        _scenarioBool(scenarioAssumptions['avancementHoirie']) ?? true,
  );
}

class _RetirementIncomeSnapshot {
  final double? value;
  final String source;
  final List<String> derivedFrom;
  final DateTime? sourceDate;

  const _RetirementIncomeSnapshot({
    required this.value,
    required this.source,
    this.derivedFrom = const [],
    this.sourceDate,
  });

  String? get calculatorSource => source == 'missing' ? null : source;
}

class SuccessionPatrimoineScreen extends StatelessWidget {
  const SuccessionPatrimoineScreen({super.key});

  bool _canRenderEstateIllustrations(CoachProfile? profile) {
    if (profile == null) return false;
    final hasTargetRetirementAge = profile.targetRetirementAge != null;
    final hasLpp = profile.prevoyance.avoirLppTotal != null &&
        profile.prevoyance.avoirLppTotal! > 0;
    final hasPillar3a = profile.prevoyance.totalEpargne3a > 0;
    final hasLiquidity = profile.patrimoine.epargneLiquide > 0;
    final hasPropertyValue = profile.patrimoine.propertyMarketValue != null &&
        profile.patrimoine.propertyMarketValue! > 0;
    return hasTargetRetirementAge &&
        hasLpp &&
        hasPillar3a &&
        hasLiquidity &&
        hasPropertyValue;
  }

  double _illustrationPatrimoine(CoachProfile profile) {
    final total = profile.patrimoine.totalPatrimoine;
    if (total > 0) return total;
    return profile.patrimoine.propertyMarketValue ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final provider = context.watch<CoachProfileProvider>();
    final profile = provider.profile;
    final dataQuestPlan = DataQuestService.planCase(
      caseId: 'transmit_property',
      answers: provider.answersSnapshot,
      factsByLedgerKey: profile == null
          ? const {}
          : DossierPayloadService.dataQuestFactsFromProfile(
              profile: profile,
              answers: provider.answersSnapshot,
            ),
      now: DateTime.now(),
      includeUseful: true,
    );
    final hasOpenGuardAsk =
        dataQuestPlan.asks.any((ask) => ask.stage == DataQuestStage.guard);
    final nextDataQuestAsk =
        dataQuestPlan.asks.isEmpty ? null : dataQuestPlan.asks.first;
    final canRenderEstateIllustrations =
        !hasOpenGuardAsk && _canRenderEstateIllustrations(profile);
    final illustrationPatrimoine =
        profile == null ? 0.0 : _illustrationPatrimoine(profile).toDouble();

    return Scaffold(
      backgroundColor: MintColors.white,
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: CustomScrollView(
                slivers: [
                  // ── AppBar white standard ──────────────────────────────
                  SliverAppBar(
                    expandedHeight: 100,
                    pinned: true,
                    backgroundColor: MintColors.white,
                    surfaceTintColor: MintColors.white,
                    foregroundColor: MintColors.textPrimary,
                    title: Text(
                      l.successionTitle,
                      style: MintTextStyles.headlineMedium(),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MintSpacing.lg,
                      vertical: MintSpacing.lg,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Put the article-based CASE first; runtime proof hooks
                        // stay below it so debug QA does not dominate the journey.
                        const _PropertyTransmissionCaseBlock(),
                        const SizedBox(height: MintSpacing.lg),
                        DataQuestNextQuestionCard(
                          plan: dataQuestPlan,
                          semanticsPrefix: 'succession',
                        ),
                        if (nextDataQuestAsk?.mode ==
                                DataQuestAskMode.scenarioAssumption &&
                            _ScenarioAssumptionCollector.supports(
                                nextDataQuestAsk!.inputKey)) ...[
                          const SizedBox(height: MintSpacing.md),
                          _ScenarioAssumptionCollector(ask: nextDataQuestAsk),
                        ],
                        const SizedBox(height: MintSpacing.lg),

                        if (_runtimeProofSemanticsEnabled)
                          const _SuccessionRuntimeProofBlock()
                        else
                          const _SuccessionRuntimeProofGate(),

                        // ── Chiffre choc ─────────────────────────────
                        _AlertCard(
                          icon: Icons.warning_amber_outlined,
                          title: l.successionAlertTitle,
                          body: l.successionAlertBody,
                          color: MintColors.urgentOrange,
                        ),
                        const SizedBox(height: MintSpacing.lg),

                        if (canRenderEstateIllustrations) ...[
                          // ── P8-A : Testament invisible ───────────────
                          TestamentInvisibleWidget(
                            patrimoine: illustrationPatrimoine,
                            initialStatus: FamilyStatus.concubin,
                          ),
                          const SizedBox(height: MintSpacing.lg),

                          // ── P8-E : Avancement d'hoirie ────────────────
                          AvancementHoirieWidget(
                            totalPatrimoine: illustrationPatrimoine,
                            donationAmount: illustrationPatrimoine * 0.1,
                            donationRecipientIndex: 0,
                            children: const [
                              HoirieChild(name: 'Enfant 1', emoji: ''),
                              HoirieChild(name: 'Enfant 2', emoji: ''),
                            ],
                          ),
                          const SizedBox(height: MintSpacing.lg),
                        ] else ...[
                          const _SuccessionGuardMissingState(),
                          const SizedBox(height: MintSpacing.lg),
                        ],

                        // ── Concepts clés ────────────────────────────
                        MintEntrance(
                            child:
                                EduSectionTitle(text: l.successionNotionsCles)),
                        const SizedBox(height: MintSpacing.sm + 4),

                        _ConceptCard(
                          icon: Icons.shield_outlined,
                          title: l.successionReservesTitle,
                          subtitle: l.successionReservesSubtitle,
                          body: l.successionReservesBody,
                          color: MintColors.info,
                        ),
                        const SizedBox(height: MintSpacing.sm + 2),

                        _ConceptCard(
                          icon: Icons.pie_chart_outline,
                          title: l.successionQuotiteTitle,
                          subtitle: l.successionQuotiteSubtitle,
                          body: l.successionQuotiteBody,
                          color: MintColors.purple,
                        ),
                        const SizedBox(height: MintSpacing.sm + 2),

                        _ConceptCard(
                          icon: Icons.description_outlined,
                          title: l.successionTestamentTitle,
                          subtitle: l.successionTestamentSubtitle,
                          body: l.successionTestamentBody,
                          color: MintColors.withdrawalOptim,
                        ),
                        const SizedBox(height: MintSpacing.sm + 2),

                        _ConceptCard(
                          icon: Icons.card_giftcard_outlined,
                          title: l.successionDonationTitle,
                          subtitle: l.successionDonationSubtitle,
                          body: l.successionDonationBody,
                          color: MintColors.successionDark,
                        ),
                        const SizedBox(height: MintSpacing.sm + 2),

                        _ConceptCard(
                          icon: Icons.how_to_reg_outlined,
                          title: l.successionBeneficiairesTitle,
                          subtitle: l.successionBeneficiairesSubtitle,
                          body: l.successionBeneficiairesBody,
                          color: MintColors.urgentOrange,
                        ),
                        const SizedBox(height: MintSpacing.lg),

                        // ── P14-A : Guide de première urgence ────────────
                        MintEntrance(
                            delay: const Duration(milliseconds: 100),
                            child:
                                EduSectionTitle(text: l.successionDecesProche)),
                        const SizedBox(height: MintSpacing.sm + 4),
                        MintEntrance(
                            delay: const Duration(milliseconds: 200),
                            child: DeathUrgencyGuideWidget(
                              phases: [
                                UrgencyPhase(
                                  timeframe:
                                      l.successionUrgencyTimeframeImmediate,
                                  emoji: '',
                                  title: l.successionUrgence,
                                  color: MintColors.urgentOrange,
                                  actions: [
                                    l.successionUrgenceAction1,
                                    l.successionUrgenceAction2,
                                    l.successionUrgenceAction3,
                                    l.successionUrgenceAction4,
                                  ],
                                ),
                                UrgencyPhase(
                                  timeframe:
                                      l.successionUrgencyTimeframeFormalities,
                                  emoji: '',
                                  title: l.successionDemarches,
                                  color: MintColors.orangeDarkDeep,
                                  actions: [
                                    l.successionDemarchesAction1,
                                    l.successionDemarchesAction2,
                                    l.successionDemarchesAction3,
                                    l.successionDemarchesAction4,
                                    l.successionDemarchesAction5,
                                  ],
                                ),
                                UrgencyPhase(
                                  timeframe:
                                      l.successionUrgencyTimeframeSettlement,
                                  emoji: '',
                                  title: l.successionLegale,
                                  color: MintColors.successDeep,
                                  actions: [
                                    l.successionLegaleAction1,
                                    l.successionLegaleAction2,
                                    l.successionLegaleAction3,
                                    l.successionLegaleAction4,
                                  ],
                                ),
                              ],
                            )),
                        const SizedBox(height: MintSpacing.lg),

                        // ── Checklist pratique ────────────────────────
                        MintEntrance(
                            delay: const Duration(milliseconds: 300),
                            child: EduSectionTitle(
                                text: l.successionChecklistTitle)),
                        const SizedBox(height: MintSpacing.sm + 4),
                        _ChecklistCard(
                          items: [
                            l.successionCheck1,
                            l.successionCheck2,
                            l.successionCheck3,
                            l.successionCheck4,
                            l.successionCheck5,
                          ],
                        ),
                        const SizedBox(height: MintSpacing.lg),

                        // ── CTA spécialiste ───────────────────────────
                        MintEntrance(
                            delay: const Duration(milliseconds: 400),
                            child: EduSpecialistCta(
                              icon: Icons.gavel_outlined,
                              color: MintColors.successionDark,
                              title: l.successionSpecialisteTitle,
                              body: l.successionSpecialisteBody,
                            )),
                        const SizedBox(height: MintSpacing.lg),

                        // ── Sources légales ───────────────────────────
                        EduLegalSources(sources: l.successionSources),
                        const SizedBox(height: MintSpacing.md),

                        // ── Disclaimer LSFin ──────────────────────────
                        EduDisclaimer(text: l.successionDisclaimer),
                        const SizedBox(height: MintSpacing.xl),
                      ]),
                    ),
                  ),
                ],
              ))),
    );
  }
}

// ── Widgets internes ─────────────────────────────────────────

class _ScenarioAssumptionCollector extends StatefulWidget {
  final DataQuestAsk ask;

  const _ScenarioAssumptionCollector({required this.ask});

  static bool supports(String inputKey) {
    return inputKey == 'cashPaidByRecipient' ||
        inputKey == 'mortgageAssumedByRecipient' ||
        inputKey == 'recipientRelationship';
  }

  @override
  State<_ScenarioAssumptionCollector> createState() =>
      _ScenarioAssumptionCollectorState();
}

class _ScenarioAssumptionCollectorState
    extends State<_ScenarioAssumptionCollector> {
  final _amountController = TextEditingController();
  String? _selectedChoice;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String? get _answerKey => switch (widget.ask.inputKey) {
        'cashPaidByRecipient' => '_transmit_property_cash_paid_by_recipient',
        'mortgageAssumedByRecipient' =>
          '_transmit_property_mortgage_assumed_by_recipient',
        'recipientRelationship' => '_transmit_property_recipient_relationship',
        _ => null,
      };

  bool get _isNumericAssumption {
    return widget.ask.inputKey == 'cashPaidByRecipient' ||
        widget.ask.inputKey == 'mortgageAssumedByRecipient';
  }

  Key? get _fieldKey => switch (widget.ask.inputKey) {
        'cashPaidByRecipient' => const Key('cash_paid_by_recipient_input'),
        'mortgageAssumedByRecipient' =>
          const Key('mortgage_assumed_by_recipient_input'),
        _ => null,
      };

  ValueKey<String> get _cardKey => switch (widget.ask.inputKey) {
        'cashPaidByRecipient' =>
          const ValueKey('succession_scenario_assumption_cash_card'),
        'mortgageAssumedByRecipient' =>
          const ValueKey('succession_scenario_assumption_mortgage_card'),
        'recipientRelationship' =>
          const ValueKey('succession_scenario_assumption_recipient_card'),
        _ => const ValueKey('succession_scenario_assumption_unknown_card'),
      };

  String _fieldLabel(S l) => switch (widget.ask.inputKey) {
        'cashPaidByRecipient' => l.dataQuestFieldCashPaidByRecipient,
        'mortgageAssumedByRecipient' =>
          l.dataQuestFieldMortgageAssumedByRecipient,
        'recipientRelationship' => l.dataQuestFieldRecipientRelationship,
        _ => widget.ask.inputKey,
      };

  List<({String value, String label, Key key})> get _choiceOptions =>
      switch (widget.ask.inputKey) {
        'recipientRelationship' => const [
            (
              value: 'descendant',
              label: 'Descendant',
              key: Key('recipient_relationship_descendant_option'),
            ),
            (
              value: 'spouse_partner',
              label: 'Conjoint/partenaire',
              key: Key('recipient_relationship_spouse_partner_option'),
            ),
            (
              value: 'sibling',
              label: 'Fratrie',
              key: Key('recipient_relationship_sibling_option'),
            ),
            (
              value: 'other',
              label: 'Autre',
              key: Key('recipient_relationship_other_option'),
            ),
          ],
        _ => const [],
      };

  Future<void> _saveScenarioAssumption() async {
    final answerKey = _answerKey;
    if (answerKey == null) return;
    final Object value;
    if (_isNumericAssumption) {
      final amount = int.tryParse(_amountController.text.trim());
      if (amount == null || amount < 0) {
        setState(() => _error = S.of(context)!.dataBlockRevenueInvalidAmount);
        return;
      }
      value = amount;
    } else {
      final selectedChoice = _selectedChoice;
      if (selectedChoice == null) return;
      value = selectedChoice;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    await context.read<CoachProfileProvider>().mergeAnswers(
      {answerKey: value},
      source: ProfileDataSource.userInput,
    );

    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_answerKey == null) {
      return const SizedBox.shrink();
    }
    final l = S.of(context)!;
    return Semantics(
      identifier: 'succession_scenario_assumption_collector',
      value: widget.ask.inputKey,
      container: true,
      child: MintSurface(
        key: _cardKey,
        tone: MintSurfaceTone.porcelaine,
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 10,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isNumericAssumption)
              TextField(
                key: _fieldKey,
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: _fieldLabel(l),
                  prefixText: 'CHF ',
                ),
              )
            else ...[
              Text(
                _fieldLabel(l),
                style: MintTextStyles.bodyMedium(
                  color: MintColors.textPrimary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: MintSpacing.sm),
              Wrap(
                spacing: MintSpacing.xs,
                runSpacing: MintSpacing.xs,
                children: [
                  for (final option in _choiceOptions)
                    ChoiceChip(
                      key: option.key,
                      label: Text(option.label),
                      selected: _selectedChoice == option.value,
                      selectedColor: MintColors.primary.withAlpha(36),
                      checkmarkColor: MintColors.primary,
                      labelStyle: MintTextStyles.labelMedium(
                        color: _selectedChoice == option.value
                            ? MintColors.primary
                            : MintColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.w600),
                      side: BorderSide(
                        color: _selectedChoice == option.value
                            ? MintColors.primary
                            : MintColors.border,
                      ),
                      onSelected: (_) {
                        setState(() => _selectedChoice = option.value);
                        HapticFeedback.selectionClick();
                      },
                    ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: MintSpacing.xs),
              Text(
                _error!,
                style: MintTextStyles.labelSmall(color: MintColors.error),
              ),
            ],
            const SizedBox(height: MintSpacing.sm),
            FilledButton(
              key: const Key('succession_scenario_assumption_save_cta'),
              onPressed: _isSaving ||
                      (!_isNumericAssumption && _selectedChoice == null)
                  ? null
                  : _saveScenarioAssumption,
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                foregroundColor: MintColors.white,
              ),
              child: Text(l.dataBlockSaveIdle),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessionRuntimeProofGate extends StatefulWidget {
  const _SuccessionRuntimeProofGate();

  @override
  State<_SuccessionRuntimeProofGate> createState() =>
      _SuccessionRuntimeProofGateState();
}

class _SuccessionRuntimeProofGateState
    extends State<_SuccessionRuntimeProofGate> {
  late final Future<bool> _enabled = readMintRuntimeProofSemanticsEnabled();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _enabled,
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return const _SuccessionRuntimeProofBlock();
      },
    );
  }
}

class _SuccessionRuntimeProofBlock extends StatelessWidget {
  const _SuccessionRuntimeProofBlock();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SuccessionLedgerProofStrip(),
        SizedBox(height: MintSpacing.lg),
      ],
    );
  }
}

class _SuccessionLedgerProofStrip extends StatelessWidget {
  const _SuccessionLedgerProofStrip();

  String _formatChf(num value) {
    final raw = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final left = raw.length - i;
      buffer.write(raw[i]);
      if (left > 1 && left % 3 == 1) buffer.write("'");
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final provider = context.watch<CoachProfileProvider>();
    final profile = provider.profile;
    final profileOwnerId = provider.runtimeProfileOwnerId;
    final scenarioId = provider.transmitPropertyScenarioId;
    final propertyValue = profile?.patrimoine.propertyMarketValue;
    final source = _propertyLedgerSource(profile);
    final confidence = _propertyLedgerConfidence(profile);
    final scenario = profile == null || propertyValue == null
        ? null
        : PropertyTransmissionCalculator.compute(
            _propertyTransmissionInputsFromProfile(
              profile,
              provider.transmitPropertyScenarioAssumptions,
              provider.answersSnapshot,
            ),
          );
    final scenarioStatusesLine = scenario == null
        ? 'scenario_statuses: missing_data'
        : 'scenario_statuses: '
            '${scenario.retirementAffordability.status.rawValue} | '
            'CHF ${_formatChf(scenario.computed.annualRetirementMargin)} | '
            '${scenario.familyEqualization.status.rawValue} | '
            'CHF ${_formatChf(scenario.familyEqualization.immediateEqualizationGap)}';
    final scenarioConfidenceLine = scenario == null
        ? 'scenario_confidence: none'
        : 'scenario_confidence: ${scenario.scenarioConfidence.rawValue}';
    final scenarioScopeLine = scenario == null
        ? 'classification=missing'
        : scenario.modelScope.semanticsValue;
    final scenarioTaxLine = scenario == null
        ? 'canton=missing'
        : scenario.cantonalTax.semanticsValue;
    final hasTransactionAssumptions = scenario != null &&
        (scenario.computed.cashPaidByRecipient > 0 ||
            scenario.computed.mortgageAssumedByRecipient > 0 ||
            scenario.retainedRight.type != 'none');
    final scenarioAssumptionLine = scenario == null
        ? l.successionScenarioConservativeAssumption
        : hasTransactionAssumptions
            ? l.successionScenarioTransactionAssumption
            : l.successionScenarioConservativeAssumption;
    final baseLine = propertyValue == null
        ? l.successionLedgerMissingPropertyValue
        : 'Base ledger: CHF ${_formatChf(propertyValue)}';

    return Semantics(
      identifier: 'succession_ledger_provenance',
      container: true,
      explicitChildNodes: true,
      child: MintSurface(
        key: const ValueKey('succession_ledger_provenance'),
        tone: MintSurfaceTone.porcelaine,
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 10,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              identifier: 'succession_ledger_property_value',
              value: propertyValue?.round().toString() ?? 'missing',
              container: true,
              child: Text(
                baseLine,
                style: MintTextStyles.labelMedium(
                  color: propertyValue == null
                      ? MintColors.textSecondary
                      : MintColors.info,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Semantics(
              identifier: 'succession_ledger_data_key',
              value: 'patrimoine.propertyMarketValue',
              container: true,
              child: Text(
                'data_ledger: patrimoine.propertyMarketValue',
                style:
                    MintTextStyles.labelSmall(color: MintColors.textSecondary),
              ),
            ),
            Semantics(
              identifier: 'succession_ledger_profile_owner_id',
              value: profileOwnerId,
              container: true,
              child: Text(
                'profile_owner_id: $profileOwnerId',
                style:
                    MintTextStyles.labelSmall(color: MintColors.textSecondary),
              ),
            ),
            Semantics(
              identifier: 'succession_ledger_scenario_id',
              value: scenarioId,
              container: true,
              child: Text(
                'scenario_id: $scenarioId',
                style:
                    MintTextStyles.labelSmall(color: MintColors.textSecondary),
              ),
            ),
            Semantics(
              identifier: 'succession_ledger_source',
              container: true,
              child: Text(
                'source: $source',
                style:
                    MintTextStyles.labelSmall(color: MintColors.textSecondary),
              ),
            ),
            Semantics(
              identifier: 'succession_ledger_confidence',
              container: true,
              child: Text(
                'confidence: $confidence',
                style:
                    MintTextStyles.labelSmall(color: MintColors.textSecondary),
              ),
            ),
            Semantics(
              identifier: 'succession_runtime_scenario_statuses',
              container: true,
              child: Text(
                scenarioStatusesLine,
                style: MintTextStyles.labelSmall(color: MintColors.textPrimary)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Semantics(
              identifier: 'succession_runtime_scenario_confidence',
              container: true,
              child: Text(
                scenarioConfidenceLine,
                style:
                    MintTextStyles.labelSmall(color: MintColors.textSecondary),
              ),
            ),
            Semantics(
              identifier: 'succession_runtime_scenario_model_scope',
              container: true,
              child: Text(
                scenarioScopeLine,
                style:
                    MintTextStyles.labelSmall(color: MintColors.textSecondary),
              ),
            ),
            Semantics(
              identifier: 'succession_runtime_scenario_cantonal_tax',
              container: true,
              child: Text(
                scenarioTaxLine,
                style:
                    MintTextStyles.labelSmall(color: MintColors.textSecondary),
              ),
            ),
            Semantics(
              identifier: 'succession_runtime_scenario_assumption',
              container: true,
              child: Text(
                scenarioAssumptionLine,
                style:
                    MintTextStyles.labelSmall(color: MintColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessionGuardMissingState extends StatelessWidget {
  const _SuccessionGuardMissingState();

  @override
  Widget build(BuildContext context) {
    return MintSurface(
      key: const ValueKey('succession_guard_missing_state'),
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 12,
      child: Text(
        S.of(context)!.successionGuardMissingState,
        style: MintTextStyles.bodySmall(
          color: MintColors.textSecondary,
        ).copyWith(height: 1.4, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PropertyTransmissionCaseBlock extends StatefulWidget {
  const _PropertyTransmissionCaseBlock();

  @override
  State<_PropertyTransmissionCaseBlock> createState() =>
      _PropertyTransmissionCaseBlockState();
}

class _PropertyTransmissionCaseBlockState
    extends State<_PropertyTransmissionCaseBlock> {
  final TextEditingController _propertyValueController =
      TextEditingController();
  final FocusNode _propertyValueFocusNode = FocusNode();
  bool _hasPendingPropertyValueEdit = false;
  int? _pendingPropertyValue;

  @override
  void dispose() {
    _propertyValueFocusNode.dispose();
    _propertyValueController.dispose();
    super.dispose();
  }

  void _syncController(num? propertyValue) {
    if (_propertyValueFocusNode.hasFocus) return;
    if (_hasPendingPropertyValueEdit) {
      if (propertyValue?.round() == _pendingPropertyValue) {
        _hasPendingPropertyValueEdit = false;
        _pendingPropertyValue = null;
      } else {
        return;
      }
    }
    final next = propertyValue == null ? '' : propertyValue.round().toString();
    if (_propertyValueController.text == next) return;
    _propertyValueController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  void _onValueChanged(BuildContext context, String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final parsedValue = digits.isEmpty ? null : int.tryParse(digits);
    final propertyValue = parsedValue?.clamp(0, 99999999).toInt();
    setState(() {
      _hasPendingPropertyValueEdit = true;
      _pendingPropertyValue = propertyValue;
    });
    context.read<CoachProfileProvider>().mergeAnswers(
      {'fp:patrimoine.propertyMarketValue': propertyValue},
      source: ProfileDataSource.userInput,
    );
  }

  void _focusPropertyValueInput() {
    _propertyValueFocusNode.requestFocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  String _formatChf(num value) {
    final raw = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final left = raw.length - i;
      buffer.write(raw[i]);
      if (left > 1 && left % 3 == 1) buffer.write("'");
    }
    return buffer.toString();
  }

  PropertyTransmissionInputs _inputsFromProfile(
    CoachProfile profile,
    Map<String, dynamic> scenarioAssumptions,
    Map<String, dynamic> answers,
  ) =>
      _propertyTransmissionInputsFromProfile(
        profile,
        scenarioAssumptions,
        answers,
      );

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final provider = context.watch<CoachProfileProvider>();
    final profile = provider.profile;
    final dataQuestPlan = DataQuestService.planCase(
      caseId: 'transmit_property',
      answers: provider.answersSnapshot,
      factsByLedgerKey: profile == null
          ? const {}
          : DossierPayloadService.dataQuestFactsFromProfile(
              profile: profile,
              answers: provider.answersSnapshot,
            ),
      now: DateTime.now(),
      includeUseful: true,
    );
    final propertyValue = profile?.patrimoine.propertyMarketValue;
    final source =
        profile?.dataSources[_propertyMarketValueFieldPath]?.name ?? 'missing';
    final scenario = profile == null || propertyValue == null
        ? null
        : PropertyTransmissionCalculator.compute(
            _inputsFromProfile(
              profile,
              provider.transmitPropertyScenarioAssumptions,
              provider.answersSnapshot,
            ),
          );
    _syncController(propertyValue);

    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            identifier: 'succession_parents_note_container',
            container: true,
            explicitChildNodes: true,
            child: Container(
              // Widget tests use this key; Maestro uses the inner Semantics id.
              key: const ValueKey('succession_parents_note'),
              padding: const EdgeInsets.all(MintSpacing.md),
              decoration: BoxDecoration(
                color: MintColors.info.withAlpha(12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: MintColors.info.withAlpha(70)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    identifier: 'succession_parents_note',
                    container: true,
                    child: Text(
                      l.successionParentsNoteTitle,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    l.successionParentsNoteBody,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary,
                    ).copyWith(height: 1.45),
                  ),
                  if (source == ProfileDataSource.userInput.name) ...[
                    const SizedBox(height: MintSpacing.sm),
                    Text(
                      l.successionParentsNoteSource,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.md),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _focusPropertyValueInput,
            child: Semantics(
              identifier: 'property_value_input',
              container: true,
              button: true,
              onTap: _focusPropertyValueInput,
              child: Text(
                l.donationValeurImmobiliere,
                style: MintTextStyles.bodyMedium().copyWith(
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.sm + 2),
          TextField(
            key: const ValueKey('property_value_input'),
            controller: _propertyValueController,
            focusNode: _propertyValueFocusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l.donationValeurImmobiliere,
              suffixText: 'CHF',
              border: const OutlineInputBorder(),
            ),
            onTap: _focusPropertyValueInput,
            onChanged: (raw) => _onValueChanged(context, raw),
          ),
          const SizedBox(height: MintSpacing.md),
          if (_runtimeProofSemanticsEnabled) ...[
            DataQuestProofStrip(
              plan: dataQuestPlan,
              semanticsPrefix: 'succession',
            ),
            const SizedBox(height: MintSpacing.md),
          ],
          if (scenario != null) ...[
            const SizedBox(height: MintSpacing.md),
            _SuccessionScenarioPreview(
              result: scenario,
              formatChf: _formatChf,
            ),
          ],
        ],
      ),
    );
  }
}

class _SuccessionScenarioPreview extends StatelessWidget {
  final PropertyTransmissionResult result;
  final String Function(num value) formatChf;

  const _SuccessionScenarioPreview({
    required this.result,
    required this.formatChf,
  });

  String _statusLabel(S l, PropertyTransmissionStatus status) {
    return switch (status) {
      PropertyTransmissionStatus.missingData =>
        l.successionScenarioStatusMissingData,
      PropertyTransmissionStatus.needsReview =>
        l.successionScenarioStatusNeedsReview,
      PropertyTransmissionStatus.atRisk => l.successionScenarioStatusAtRisk,
      PropertyTransmissionStatus.ok => l.successionScenarioStatusOk,
      PropertyTransmissionStatus.notApplicable =>
        l.successionScenarioStatusNotApplicable,
    };
  }

  Color _statusColor(PropertyTransmissionStatus status) {
    return switch (status) {
      PropertyTransmissionStatus.ok => MintColors.success,
      PropertyTransmissionStatus.notApplicable => MintColors.textSecondary,
      PropertyTransmissionStatus.missingData => MintColors.info,
      PropertyTransmissionStatus.needsReview => MintColors.warning,
      PropertyTransmissionStatus.atRisk => MintColors.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final scenarioDetailKeys = <String>[
      ...result.retirementAffordability.reasons,
      ...result.familyEqualization.notes,
      result.retainedRight.label,
      ...result.retainedRight.notes,
    ];
    final hasTransactionAssumptions = result.computed.cashPaidByRecipient > 0 ||
        result.computed.mortgageAssumedByRecipient > 0 ||
        result.retainedRight.type != 'none';
    final assumptionText = hasTransactionAssumptions
        ? l.successionScenarioTransactionAssumption
        : l.successionScenarioConservativeAssumption;
    final assumptionIdentifier = hasTransactionAssumptions
        ? 'succession_scenario_transaction_assumption'
        : 'succession_scenario_conservative_assumption';
    final assumptionValue = 'cashPaidByRecipient='
        '${result.computed.cashPaidByRecipient};'
        'mortgageAssumedByRecipient='
        '${result.computed.mortgageAssumedByRecipient};'
        'retainedRight=${result.retainedRight.type};'
        'avancementHoirie=${result.avancementHoirie}';
    return Semantics(
      identifier: 'succession_scenario_preview',
      container: true,
      explicitChildNodes: true,
      child: MintSurface(
        tone: MintSurfaceTone.blanc,
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.successionScenarioPreviewTitle,
              style: MintTextStyles.bodySmall(
                color: MintColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              _propertyTransmissionText(l, result.articleThesis),
              style: MintTextStyles.labelMedium(
                color: MintColors.textSecondary,
              ).copyWith(height: 1.4),
            ),
            const SizedBox(height: MintSpacing.sm),
            _ScenarioStatusRow(
              identifier: 'succession_scenario_retirement_status',
              label: l.successionScenarioRetirementStatus,
              statusLabel: _statusLabel(
                l,
                result.retirementAffordability.status,
              ),
              statusValue: result.retirementAffordability.status.rawValue,
              color: _statusColor(result.retirementAffordability.status),
              detail:
                  'CHF ${formatChf(result.computed.annualRetirementMargin)}',
            ),
            const SizedBox(height: MintSpacing.sm),
            _ScenarioStatusRow(
              identifier: 'succession_scenario_equalization_status',
              label: l.successionScenarioEqualizationStatus,
              statusLabel: _statusLabel(l, result.familyEqualization.status),
              statusValue: result.familyEqualization.status.rawValue,
              color: _statusColor(result.familyEqualization.status),
              detail:
                  'CHF ${formatChf(result.familyEqualization.immediateEqualizationGap)}',
            ),
            const SizedBox(height: MintSpacing.sm),
            Semantics(
              key: const ValueKey('succession_scenario_confidence'),
              identifier: 'succession_scenario_confidence',
              value:
                  '${result.scenarioConfidence.rawValue};${result.scenarioConfidenceRationale.semanticsValue}',
              container: true,
              child: Text(
                '${l.successionScenarioConfidence}: '
                '${_scenarioConfidenceLabel(l, result.scenarioConfidence)}',
                style: MintTextStyles.labelSmall(
                  color: MintColors.textSecondary,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (result.parentAnnualRetirementIncomeSource ==
                ProfileDataSource.estimated.name) ...[
              const SizedBox(height: MintSpacing.xs),
              Semantics(
                key: const ValueKey(
                  'succession_scenario_retirement_income_source',
                ),
                identifier: 'succession_scenario_retirement_income_source',
                value: 'parentAnnualRetirementIncome=estimated',
                container: true,
                child: Text(
                  l.successionScenarioRetirementIncomeSource,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textSecondary,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
            _ScenarioInfoRow(
              identifier: 'succession_scenario_model_scope',
              label: l.successionScenarioScopeLabel,
              valueLabel: l.successionScenarioScopeEducational,
              semanticsValue: result.modelScope.semanticsValue,
            ),
            const SizedBox(height: MintSpacing.xs),
            _ScenarioInfoRow(
              identifier: 'succession_scenario_cantonal_tax',
              label: l.successionScenarioCantonalTaxStatus,
              valueLabel:
                  '${result.cantonalTax.canton} · ${l.successionScenarioCantonalTaxReview}',
              semanticsValue: result.cantonalTax.semanticsValue,
            ),
            const SizedBox(height: MintSpacing.xs),
            Semantics(
              key: ValueKey(assumptionIdentifier),
              identifier: assumptionIdentifier,
              value: assumptionValue,
              container: true,
              child: Text(
                assumptionText,
                style: MintTextStyles.labelSmall(
                  color: MintColors.textSecondary,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (scenarioDetailKeys.isNotEmpty) ...[
              const SizedBox(height: MintSpacing.sm),
              for (final key in scenarioDetailKeys)
                Padding(
                  padding: const EdgeInsets.only(bottom: MintSpacing.xs),
                  child: Text(
                    '- ${_propertyTransmissionText(l, key)}',
                    style: MintTextStyles.labelSmall(
                      color: MintColors.textSecondary,
                    ).copyWith(height: 1.35),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScenarioInfoRow extends StatelessWidget {
  final String identifier;
  final String label;
  final String valueLabel;
  final String semanticsValue;

  const _ScenarioInfoRow({
    required this.identifier,
    required this.label,
    required this.valueLabel,
    required this.semanticsValue,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey(identifier),
      identifier: identifier,
      value: semanticsValue,
      container: true,
      child: Text(
        '$label: $valueLabel',
        style: MintTextStyles.labelSmall(
          color: MintColors.textSecondary,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ScenarioStatusRow extends StatelessWidget {
  final String identifier;
  final String label;
  final String statusLabel;
  final String statusValue;
  final String detail;
  final Color color;

  const _ScenarioStatusRow({
    required this.identifier,
    required this.label,
    required this.statusLabel,
    required this.statusValue,
    required this.detail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: identifier,
      value: statusValue,
      container: true,
      explicitChildNodes: true,
      child: Container(
        key: ValueKey(identifier),
        padding: const EdgeInsets.symmetric(
          horizontal: MintSpacing.sm,
          vertical: MintSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withAlpha(12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(55)),
        ),
        child: Row(
          children: [
            Icon(Icons.insights_outlined, color: color, size: 18),
            const SizedBox(width: MintSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: MintTextStyles.labelSmall(
                      color: MintColors.textSecondary,
                    ),
                  ),
                  Text(
                    statusLabel,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(width: MintSpacing.sm),
            Text(
              detail,
              style: MintTextStyles.labelSmall(color: color)
                  .copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _AlertCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.lg),
        decoration: BoxDecoration(
          color: color.withAlpha(12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: MintSpacing.sm + 2),
                Expanded(
                  child: Text(
                    title,
                    style: MintTextStyles.bodyMedium()
                        .copyWith(fontWeight: FontWeight.w600, height: 1.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm + 4),
            Text(
              body,
              style: MintTextStyles.bodyMedium().copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConceptCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String body;
  final Color color;

  const _ConceptCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: MintSurface(
        tone: MintSurfaceTone.porcelaine,
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: MintSpacing.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: MintTextStyles.bodySmall(
                                  color: MintColors.textPrimary)
                              .copyWith(fontWeight: FontWeight.w700)),
                      Text(subtitle,
                          style: MintTextStyles.labelSmall(color: color)
                              .copyWith(fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm + 2),
            Text(body,
                style: MintTextStyles.labelMedium().copyWith(height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  final List<String> items;
  const _ChecklistCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 14,
      child: Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: MintColors.primary, size: 18),
                    const SizedBox(width: MintSpacing.sm + 2),
                    Expanded(
                      child: Text(
                        item,
                        style: MintTextStyles.bodySmall(
                                color: MintColors.textPrimary)
                            .copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
