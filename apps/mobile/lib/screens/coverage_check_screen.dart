import 'package:flutter/material.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/assurances_service.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_narrative_card.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────
//  COVERAGE CHECK SCREEN — Sprint S13 / Chantier 7
// ────────────────────────────────────────────────────────────
//
// Interactive screen for evaluating insurance coverage.
// Includes profile toggles, coverage switches, score gauge,
// checklist cards with urgency badges, and recommendations.
// ────────────────────────────────────────────────────────────

class CoverageCheckScreen extends StatefulWidget {
  const CoverageCheckScreen({super.key});

  @override
  State<CoverageCheckScreen> createState() => _CoverageCheckScreenState();
}

class _CoverageCheckScreenState extends State<CoverageCheckScreen> {
  // ── State — Scenario/current coverage levers ───────────────
  bool _voyagesFrequents = false;
  bool? _aIjmCollective;
  bool? _aLaa;
  bool _aRcPrivee = false;
  bool _aMenage = false;
  bool _aProtectionJuridique = false;
  bool _aAssuranceVoyage = false;
  bool _aAssuranceDeces = false;

  CoachProfileProvider? _profileProvider(BuildContext context) {
    try {
      return context.watch<CoachProfileProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  CoverageCheckResult? _resultFor(_CoverageProfileFacts facts) {
    if (!facts.isComplete) return null;
    return CoverageCheckService.evaluateCoverage(
      statutProfessionnel:
          _coverageServiceEmploymentStatus(facts.statutProfessionnel!),
      aHypotheque: facts.aHypotheque!,
      aFamille: facts.aFamille!,
      estLocataire: facts.estLocataire!,
      voyagesFrequents: _voyagesFrequents,
      aIjmCollective: _effectiveIjmCollective(facts),
      aLaa: _effectiveLaa(facts),
      aRcPrivee: _aRcPrivee,
      aMenage: _aMenage,
      aProtectionJuridique: _aProtectionJuridique,
      aAssuranceVoyage: _aAssuranceVoyage,
      aAssuranceDeces: _aAssuranceDeces,
      canton: facts.canton!,
    );
  }

  bool _effectiveIjmCollective(_CoverageProfileFacts facts) {
    return _aIjmCollective ?? facts.statutProfessionnel != 'independant';
  }

  bool _effectiveLaa(_CoverageProfileFacts facts) {
    return _aLaa ?? facts.statutProfessionnel != 'independant';
  }

  String _coverageServiceEmploymentStatus(String status) {
    return switch (status) {
      'independant' => 'independant',
      'chomage' || 'sans_emploi' => 'sans_emploi',
      _ => 'salarie',
    };
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = _profileProvider(context);
    final facts = _CoverageProfileFacts.fromProfile(provider?.profile);
    final result = _resultFor(facts);

    return Scaffold(
      backgroundColor: MintColors.background,
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(context),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        MintEntrance(
                            child: MintNarrativeCard(
                          headline: S.of(context)!.narrativeCoverageHeadline,
                          body: S.of(context)!.narrativeCoverageBody,
                          tone: MintSurfaceTone.bleu,
                          badge: S.of(context)!.narrativeCoverageBadge,
                        )),
                        const SizedBox(height: 12),
                        _buildHeader(),
                        const SizedBox(height: 20),

                        // Profile section
                        _buildProfileSection(facts),
                        const SizedBox(height: 24),

                        // Current coverage section
                        _buildCoverageSection(facts),
                        const SizedBox(height: 24),

                        // Results
                        if (result != null) ...[
                          Semantics(
                            key: const Key('coverage_result_section'),
                            identifier: 'coverage_result_section',
                            child: _buildScoreGauge(result),
                          ),
                          const SizedBox(height: 20),
                          _buildChecklist(result),
                          const SizedBox(height: 20),
                          _buildRecommendations(result),
                          const SizedBox(height: 20),
                        ],

                        // Disclaimer
                        _buildDisclaimer(),
                        const SizedBox(height: 16),

                        // Sources
                        _buildSourcesFooter(),
                        const SizedBox(height: 100),
                      ]),
                    ),
                  ),
                ],
              ))),
    );
  }

  // ── App Bar ────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    final s = S.of(context)!;
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => safePop(context),
      ),
      title: Text(
        s.coverageCheckAppBarTitle,
        style: MintTextStyles.headlineMedium(),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.indigoBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.verified_user,
            color: MintColors.indigoDeep,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of(context)!.coverageCheckTitle,
                style: MintTextStyles.headlineMedium(),
              ),
              const SizedBox(height: 4),
              Text(
                S.of(context)!.coverageCheckSubtitle,
                style:
                    MintTextStyles.bodyMedium(color: MintColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Profile section ────────────────────────────────────────

  Widget _buildProfileSection(_CoverageProfileFacts facts) {
    return Semantics(
      key: const Key('coverage_ledger_facts'),
      identifier: 'coverage_ledger_facts',
      container: true,
      child: MintSurface(
        padding: const EdgeInsets.all(20),
        elevated: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  facts.isComplete
                      ? Icons.check_circle_outline
                      : Icons.manage_search_outlined,
                  color: facts.isComplete
                      ? MintColors.success
                      : MintColors.warning,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    facts.isComplete
                        ? S.of(context)!.dataQualityKnownSection
                        : S.of(context)!.dataQualityMissingSection,
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Semantics(
                  identifier: 'coverage_profile_enrich_cta',
                  container: true,
                  button: true,
                  child: TextButton.icon(
                    key: const Key('coverage_profile_enrich_cta'),
                    onPressed: () => context.push(facts.enrichmentRoute),
                    icon: Icon(
                      facts.isComplete
                          ? Icons.edit_outlined
                          : Icons.add_circle_outline,
                      size: 18,
                    ),
                    label: Text(
                      facts.isComplete
                          ? S.of(context)!.commonEdit
                          : S.of(context)!.dataQualityEnrich,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFactRow(
              key: const Key('coverage_status_fact'),
              identifier: 'coverage_status_fact',
              label: S.of(context)!.coverageCheckStatut,
              value: _employmentLabel(facts.statutProfessionnel),
              isMissing: facts.statutProfessionnel == null,
            ),
            const SizedBox(height: 12),
            _buildFactRow(
              key: const Key('coverage_canton_fact'),
              identifier: 'coverage_canton_fact',
              label: S.of(context)!.fiscalCanton,
              value: facts.canton ?? S.of(context)!.dataBlockStatusMissing,
              isMissing: facts.canton == null,
            ),
            const SizedBox(height: 12),
            _buildFactRow(
              key: const Key('coverage_family_fact'),
              identifier: 'coverage_family_fact',
              label: S.of(context)!.coverageCheckPersonnesCharge,
              value: facts.children == null
                  ? S.of(context)!.dataBlockStatusMissing
                  : '${facts.children}',
              isMissing: facts.children == null,
            ),
            const SizedBox(height: 12),
            _buildFactRow(
              key: const Key('coverage_housing_fact'),
              identifier: 'coverage_housing_fact',
              label: S.of(context)!.coverageCheckLocataire,
              value: _housingLabel(facts.housingStatus),
              isMissing: facts.housingStatus == null,
            ),
            const SizedBox(height: 12),
            _buildFactRow(
              key: const Key('coverage_mortgage_fact'),
              identifier: 'coverage_mortgage_fact',
              label: S.of(context)!.coverageCheckHypotheque,
              value: _mortgageLabel(facts),
              isMissing: facts.aHypotheque == null,
            ),
            if (!facts.isComplete) ...[
              const SizedBox(height: 16),
              Semantics(
                key: const Key('coverage_missing_profile_facts'),
                identifier: 'coverage_missing_profile_facts',
                container: true,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MintColors.warning.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: MintColors.warning.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: MintColors.warning,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          S.of(context)!.dataQualityMissingSection,
                          style: MintTextStyles.bodySmall(
                            color: MintColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFactRow({
    required Key key,
    required String identifier,
    required String label,
    required String value,
    required bool isMissing,
  }) {
    return Semantics(
      key: key,
      identifier: identifier,
      label: '$label, $value',
      container: true,
      child: Row(
        children: [
          Icon(
            isMissing ? Icons.help_outline : Icons.check_circle_outline,
            color: isMissing ? MintColors.warning : MintColors.success,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: MintTextStyles.bodySmall(
                color: isMissing ? MintColors.warning : MintColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _employmentLabel(String? value) {
    return switch (value) {
      null => S.of(context)!.dataBlockStatusMissing,
      'salarie' => S.of(context)!.coverageCheckSalarie,
      'independant' => S.of(context)!.coverageCheckIndependant,
      'chomage' || 'sans_emploi' => S.of(context)!.coverageCheckSansEmploi,
      'retraite' => S.of(context)!.employmentRetraite,
      'etudiant' => S.of(context)!.coverageCheckEtudiant,
      'mixte' => S.of(context)!.renteVsCapitalMixteLabel,
      _ => value,
    };
  }

  String _housingLabel(String? value) {
    return switch (value) {
      null => S.of(context)!.dataBlockStatusMissing,
      'owner' ||
      'proprietaire' ||
      'propri\u00e9taire' =>
        S.of(context)!.householdOwnerBadge,
      'renter' || 'locataire' => S.of(context)!.coverageCheckLocataire,
      'family' => S.of(context)!.dataBlockMenageHousingFamily,
      _ => value,
    };
  }

  String _mortgageLabel(_CoverageProfileFacts facts) {
    if (facts.aHypotheque == null) {
      return S.of(context)!.dataBlockStatusMissing;
    }
    return formatChfWithPrefix(facts.mortgageAmount ?? 0);
  }

  // ── Coverage section ───────────────────────────────────────

  Widget _buildCoverageSection(_CoverageProfileFacts facts) {
    return MintSurface(
      padding: const EdgeInsets.all(20),
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MintEntrance(
              child: Text(
            S.of(context)!.coverageCheckCouvertureActuelle,
            style: MintTextStyles.titleMedium(),
          )),
          const SizedBox(height: 12),
          MintEntrance(
              delay: const Duration(milliseconds: 100),
              child: _buildCoverageSwitch(S.of(context)!.coverageCheckIjm,
                  _effectiveIjmCollective(facts), (v) {
                setState(() => _aIjmCollective = v);
              })),
          MintEntrance(
              delay: const Duration(milliseconds: 200),
              child: _buildCoverageSwitch(
                  S.of(context)!.coverageCheckLaa, _effectiveLaa(facts), (v) {
                setState(() => _aLaa = v);
              })),
          MintEntrance(
              delay: const Duration(milliseconds: 300),
              child: _buildCoverageSwitch(
                  S.of(context)!.coverageCheckRcPrivee, _aRcPrivee, (v) {
                setState(() => _aRcPrivee = v);
              })),
          MintEntrance(
              delay: const Duration(milliseconds: 400),
              child: _buildCoverageSwitch(
                  S.of(context)!.coverageCheckMenage, _aMenage, (v) {
                setState(() => _aMenage = v);
              })),
          _buildCoverageSwitch(
              S.of(context)!.coverageCheckVoyages, _voyagesFrequents, (v) {
            setState(() => _voyagesFrequents = v);
          }),
          _buildCoverageSwitch(
              S.of(context)!.coverageCheckProtJuridique, _aProtectionJuridique,
              (v) {
            setState(() => _aProtectionJuridique = v);
          }),
          _buildCoverageSwitch(
              S.of(context)!.coverageCheckVoyage, _aAssuranceVoyage, (v) {
            setState(() => _aAssuranceVoyage = v);
          }),
          _buildCoverageSwitch(
              S.of(context)!.coverageCheckDeces, _aAssuranceDeces, (v) {
            setState(() => _aAssuranceDeces = v);
          }),
        ],
      ),
    );
  }

  Widget _buildCoverageSwitch(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: MintColors.success,
          ),
        ],
      ),
    );
  }

  // ── Score gauge ────────────────────────────────────────────

  Widget _buildScoreGauge(CoverageCheckResult result) {
    final score = result.scoreCouverture;
    final color = score < 40
        ? MintColors.error
        : score < 70
            ? MintColors.warning
            : MintColors.success;

    return MintSurface(
      padding: const EdgeInsets.all(24),
      elevated: true,
      child: Column(
        children: [
          Text(
            S.of(context)!.coverageCheckScore,
            style: MintTextStyles.titleMedium(),
          ),
          const SizedBox(height: 20),

          // Score circle
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 10,
                    backgroundColor: MintColors.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$score',
                      style: MintTextStyles.displayMedium(color: color),
                    ),
                    Text(
                      '/ 100',
                      style: MintTextStyles.labelSmall(
                          color: MintColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Critical gaps badge
          if (result.lacunesCritiques > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: MintColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: MintColors.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: MintColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${result.lacunesCritiques}',
                      style: MintTextStyles.labelSmall(color: MintColors.white)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: MintSpacing.sm),
                  Text(
                    result.lacunesCritiques > 1
                        ? S.of(context)!.coverageCriticalGapPlural
                        : S.of(context)!.coverageCriticalGapSingular,
                    style: MintTextStyles.bodySmall(color: MintColors.error)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Checklist ──────────────────────────────────────────────

  Widget _buildChecklist(CoverageCheckResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.checklist, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              S.of(context)!.coverageCheckAnalyseTitle,
              style: MintTextStyles.bodySmall(color: MintColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...result.checklist.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildChecklistCard(item),
            )),
      ],
    );
  }

  Widget _buildChecklistCard(CoverageCheckItem item) {
    return MintSurface(
      padding: const EdgeInsets.all(16),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildIconForType(item.iconType),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: MintTextStyles.titleMedium(),
                ),
              ),
              _buildUrgencyBadge(item.urgency),
            ],
          ),
          const SizedBox(height: 8),

          // Status indicator
          _buildStatusIndicator(item.status),
          const SizedBox(height: 8),

          Text(
            item.description,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.sm),

          Row(
            children: [
              Expanded(
                child: Text(
                  item.estimatedCostRange,
                  style: MintTextStyles.labelSmall(color: MintColors.textMuted),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  item.source,
                  textAlign: TextAlign.right,
                  style: MintTextStyles.micro(color: MintColors.textMuted)
                      .copyWith(fontStyle: FontStyle.normal),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconForType(IconType type) {
    final iconData = switch (type) {
      IconType.shield => Icons.shield_outlined,
      IconType.home => Icons.home_outlined,
      IconType.gavel => Icons.gavel,
      IconType.flight => Icons.flight_outlined,
      IconType.favorite => Icons.favorite_outline,
      IconType.localHospital => Icons.local_hospital_outlined,
      IconType.warning => Icons.warning_outlined,
      IconType.work => Icons.work_outline,
    };

    return Icon(iconData, size: 20, color: MintColors.textSecondary);
  }

  Widget _buildUrgencyBadge(String urgency) {
    final (label, color) = switch (urgency) {
      'critique' => (S.of(context)!.coverageCheckCritique, MintColors.error),
      'haute' => (S.of(context)!.coverageCheckHaute, MintColors.warning),
      'moyenne' => (S.of(context)!.coverageCheckMoyenne, MintColors.info),
      _ => (S.of(context)!.coverageCheckBasse, MintColors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: MintTextStyles.micro(color: color)
            .copyWith(fontWeight: FontWeight.w700, fontStyle: FontStyle.normal),
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    final (icon, label, color) = switch (status) {
      'couvert' => (
          Icons.check_circle,
          S.of(context)!.coverageCheckCouvert,
          MintColors.success
        ),
      'non_couvert' => (
          Icons.cancel,
          S.of(context)!.coverageCheckNonCouvert,
          MintColors.error
        ),
      _ => (
          Icons.help_outline,
          S.of(context)!.coverageCheckAVerifier,
          MintColors.warning
        ),
    };

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: MintTextStyles.labelSmall(color: color)
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ── Recommendations ────────────────────────────────────────

  Widget _buildRecommendations(CoverageCheckResult result) {
    if (result.recommandations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline,
                size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              S.of(context)!.coverageCheckRecommandationsTitle,
              style: MintTextStyles.bodySmall(color: MintColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...result.recommandations.map((rec) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MintSurface(
                padding: const EdgeInsets.all(16),
                radius: 16,
                child: Text(
                  rec,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ),
            )),
      ],
    );
  }

  // ── Disclaimer ─────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              S.of(context)!.coverageCheckDisclaimer,
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sources footer ─────────────────────────────────────────

  Widget _buildSourcesFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.coverageCheckSources,
          style: MintTextStyles.labelSmall(color: MintColors.textMuted)
              .copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: MintSpacing.xs + 2),
        Text(
          S.of(context)!.coverageCheckSourcesBody,
          style: MintTextStyles.micro(color: MintColors.textMuted)
              .copyWith(fontStyle: FontStyle.normal),
        ),
      ],
    );
  }
}

class _CoverageProfileFacts {
  final String? statutProfessionnel;
  final String? canton;
  final int? children;
  final String? housingStatus;
  final double? mortgageAmount;
  final bool? aHypotheque;
  final bool? aFamille;
  final bool? estLocataire;
  final String enrichmentRoute;

  const _CoverageProfileFacts({
    required this.statutProfessionnel,
    required this.canton,
    required this.children,
    required this.housingStatus,
    required this.mortgageAmount,
    required this.aHypotheque,
    required this.aFamille,
    required this.estLocataire,
    required this.enrichmentRoute,
  });

  bool get isComplete =>
      statutProfessionnel != null &&
      canton != null &&
      children != null &&
      housingStatus != null &&
      aHypotheque != null &&
      aFamille != null &&
      estLocataire != null;

  factory _CoverageProfileFacts.fromProfile(CoachProfile? profile) {
    if (profile == null) {
      return const _CoverageProfileFacts(
        statutProfessionnel: null,
        canton: null,
        children: null,
        housingStatus: null,
        mortgageAmount: null,
        aHypotheque: null,
        aFamille: null,
        estLocataire: null,
        enrichmentRoute: '/data-block/revenu?inputKey=q_canton',
      );
    }

    final knownEmployment =
        profile.userProvidedFields.contains('employmentStatus');
    final knownCanton = profile.userProvidedFields.contains('canton');
    final knownChildren = profile.userProvidedFields.contains('children');
    final knownHousing = profile.userProvidedFields.contains('housingStatus');
    final rawHousing = knownHousing ? profile.housingStatus : null;
    final isTenant = rawHousing == 'locataire' || rawHousing == 'renter';
    final isOwner = rawHousing == 'proprietaire' ||
        rawHousing == 'propri\u00e9taire' ||
        rawHousing == 'owner';
    final isFamilyHousing = rawHousing == 'family';
    final hasValidHousing = isTenant || isOwner || isFamilyHousing;
    final housing = hasValidHousing ? rawHousing : null;
    final mortgageAmount = profile.dettes.hypotheque;
    final bool? hasMortgage = isTenant
        ? false
        : isFamilyHousing
            ? false
            : isOwner
                ? (mortgageAmount == null ? null : mortgageAmount > 0)
                : null;
    final bool? hasFamily = knownChildren
        ? (profile.nombreEnfants > 0 || profile.conjoint != null)
        : null;

    return _CoverageProfileFacts(
      statutProfessionnel: knownEmployment ? profile.employmentStatus : null,
      canton: knownCanton ? profile.canton : null,
      children: knownChildren ? profile.nombreEnfants : null,
      housingStatus: housing,
      mortgageAmount: mortgageAmount,
      aHypotheque: hasMortgage,
      aFamille: hasFamily,
      estLocataire:
          isTenant ? true : ((isOwner || isFamilyHousing) ? false : null),
      enrichmentRoute: _firstMissingRoute(
        knownCanton: knownCanton,
        knownEmployment: knownEmployment,
        knownChildren: knownChildren,
        knownHousing: hasValidHousing,
        hasMortgage: hasMortgage,
      ),
    );
  }

  static String _firstMissingRoute({
    required bool knownCanton,
    required bool knownEmployment,
    required bool knownChildren,
    required bool knownHousing,
    required bool? hasMortgage,
  }) {
    if (!knownCanton) return '/data-block/revenu?inputKey=q_canton';
    if (!knownEmployment) return '/coach/chat?topic=employmentStatus';
    if (!knownChildren || !knownHousing) {
      return '/data-block/composition_menage';
    }
    if (hasMortgage == null) return '/coach/chat?topic=hypotheque';
    return '/data-block/revenu?inputKey=q_canton';
  }
}
