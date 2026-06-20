import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/smart_onboarding_draft_service.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/widgets/profile/hero_gap_card.dart';
import 'package:mint_mobile/widgets/profile/financial_drawer.dart';
import 'package:mint_mobile/widgets/profile/patrimoine_drawer_content.dart';
import 'package:mint_mobile/widgets/profile/dettes_drawer_content.dart';
import 'package:mint_mobile/widgets/profile/futur_drawer_content.dart';
import 'package:mint_mobile/widgets/profile/enrichment_cta.dart';
import 'package:mint_mobile/widgets/common/mint_empty_state.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

// NOTE: This screen is a deep-dive view. Primary display is now in PulseScreen
// via BudgetSnapshot. Keep for /profile/bilan deep link and ProfileScreen access.

/// Écran "Mon aperçu" — Le Gap + 3 Tiroirs
///
/// Architecture Option B : stock pur (patrimoine + dettes + projection retraite).
/// Le flux mensuel (waterfall, revenus, dépenses) vit dans l'écran Budget.
///
/// Accessible depuis /profile/bilan et depuis le ProfileScreen.
class FinancialSummaryScreen extends StatelessWidget {
  const FinancialSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final coachProvider = context.watch<CoachProfileProvider>();
    final profile = coachProvider.profile;

    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(context),
                  _buildBodySliver(context, profile),
                ],
              ))),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  APP BAR
  // ══════════════════════════════════════════════════════════════

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.porcelaine,
      surfaceTintColor: MintColors.porcelaine,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => safePop(context),
      ),
      title: Text(
        S.of(context)!.financialSummaryTitle,
        style: MintTextStyles.titleMedium(
          color: MintColors.textPrimary,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  EMPTY STATE
  // ══════════════════════════════════════════════════════════════

  Widget _buildEmptyState(BuildContext context) {
    return SliverFillRemaining(
      child: MintEmptyState(
        icon: Icons.person_off_outlined,
        title: S.of(context)!.financialSummaryNoProfile,
        subtitle: '', // No subtitle in original
        ctaLabel: S.of(context)!.financialSummaryStartDiagnostic,
        onCta: () => context.go('/coach/chat'),
      ),
    );
  }

  Widget _buildBodySliver(BuildContext context, CoachProfile? profile) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ReportPersistenceService.loadMint2AxisHandoff(),
      builder: (context, snapshot) {
        final mint2AxisHandoff = snapshot.data ?? const <String, dynamic>{};
        final hasMint2AxisHandoff = _hasMint2LiveAxis(mint2AxisHandoff);
        if (profile == null ||
            !profile.hasMaterialData ||
            !_hasDefensibleDossierForFinancialSummary(profile)) {
          if (!hasMint2AxisHandoff) return _buildEmptyState(context);
          return _buildHandoffOnlyContent(context);
        }
        return _buildContent(context, profile);
      },
    );
  }

  bool _hasDefensibleDossierForFinancialSummary(CoachProfile profile) {
    final sourceCounts = _dossierSourceCounts(profile);
    if ((sourceCounts[ProfileDataSource.estimated] ?? 0) > 0) {
      return false;
    }
    return (sourceCounts[ProfileDataSource.userInput] ?? 0) +
            (sourceCounts[ProfileDataSource.crossValidated] ?? 0) +
            (sourceCounts[ProfileDataSource.certificate] ?? 0) +
            (sourceCounts[ProfileDataSource.openBanking] ?? 0) >
        0;
  }

  Widget _buildHandoffOnlyContent(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: _buildMint2HandoffDossierSummary(context),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  MAIN CONTENT — Hero Gap + 3 Tiroirs + CTA + Disclaimer
  // ══════════════════════════════════════════════════════════════

  Widget _buildContent(BuildContext context, CoachProfile profile) {
    final s = S.of(context)!;
    final prev = profile.prevoyance;
    final det = profile.dettes;
    final pat = profile.patrimoine;

    // ── Compute once: NetIncomeBreakdown ──
    final gross = profile.revenuBrutAnnuel;
    final breakdown = gross > 0
        ? NetIncomeBreakdown.compute(
            grossSalary: gross,
            canton: profile.canton.isNotEmpty ? profile.canton : 'ZH',
            age: profile.age,
            // FIX-P1-4: Pass etatCivil + nombreEnfants for correct tax calc.
            etatCivil: profile.etatCivil.name,
            nombreEnfants: profile.nombreEnfants,
          )
        : null;

    // ── Hero Gap data ──
    final currentMonthlyNet =
        breakdown != null ? breakdown.disposableIncome / 12 : 0.0;
    final renteAvs = prev.renteAVSEstimeeMensuelle ?? 0;
    // Rente mensuelle via la source canonique (financial_core L1) : un seul
    // taux de conversion par cas (taux de caisse + réduction retraite anticipée
    // LPP art. 13 al. 2), identique à tous les autres écrans de rente.
    final renteLpp = LppCalculator.monthlyRenteFromAvoir(
      avoir: prev.avoirLppTotal ?? 0,
      baseRate: prev.tauxConversion,
      retirementAge: profile.effectiveRetirementAge,
    );
    final projectedMonthly = renteAvs + renteLpp;

    // ── Confidence ──
    final knownCount = [
      profile.salaireBrutMensuel > 0,
      profile.canton.isNotEmpty,
      prev.avoirLppTotal != null && prev.avoirLppTotal! > 0,
      prev.totalEpargne3a > 0,
      pat.epargneLiquide > 0,
      profile.depenses.loyer > 0 ||
          (det.hypotheque != null && det.hypotheque! > 0),
      profile.depenses.assuranceMaladie > 0,
    ].where((b) => b).length;
    final confidence = (knownCount / 7 * 100).clamp(0.0, 100.0);
    final missingCount = 7 - knownCount;

    // ── Patrimoine net (hero value for tiroir 1) ──
    final prevCapital = (prev.avoirLppTotal ?? 0) +
        prev.totalEpargne3a +
        prev.totalLibrePassage;
    final conjointPrevCapital = profile.isCouple
        ? ((profile.conjoint?.prevoyance?.avoirLppTotal ?? 0) +
            (profile.conjoint?.prevoyance?.totalEpargne3a ?? 0) +
            (profile.conjoint?.prevoyance?.totalLibrePassage ?? 0))
        : 0.0;
    final patrimoineBrut = pat.epargneLiquide +
        pat.investissements +
        pat.immobilierEffectif +
        prevCapital +
        conjointPrevCapital;
    final patrimoineNet = patrimoineBrut - det.totalDettes;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDossierSummary(context, profile),
            const SizedBox(height: 12),

            // ── TIROIR 1: Ce que tu as ──
            MintEntrance(
                delay: const Duration(milliseconds: 100),
                child: FinancialDrawer(
                  title: s.drawerCeQueTuAs,
                  subtitle: s.drawerCeQueTuAsSubtitle,
                  heroValue: formatChfCompact(patrimoineNet),
                  icon: Icons.savings_outlined,
                  accentColor: MintColors.success,
                  initiallyExpanded: true,
                  onEdit: () => _showEditSheet(
                    context,
                    title: s.financialSummaryModifierPatrimoine,
                    fields: [
                      _EditField(
                        label: s.financialSummaryEditEpargneLiquide,
                        initialValue:
                            pat.epargneLiquide > 0 ? pat.epargneLiquide : null,
                        key: 'epargneLiquide',
                      ),
                      _EditField(
                        label: s.financialSummaryEditInvestissements,
                        initialValue: pat.investissements > 0
                            ? pat.investissements
                            : null,
                        key: 'investissements',
                      ),
                      _EditField(
                        label: s.financialSummaryEditAvoirLpp,
                        initialValue: prev.avoirLppTotal,
                        key: 'avoirLppTotal',
                      ),
                      _EditField(
                        label: s.financialSummaryEditNombre3a,
                        initialValue:
                            prev.nombre3a > 0 ? prev.nombre3a.toDouble() : null,
                        key: 'nombre3a',
                      ),
                      _EditField(
                        label: s.financialSummaryEditTotal3a,
                        initialValue: prev.totalEpargne3a > 0
                            ? prev.totalEpargne3a
                            : null,
                        key: 'totalEpargne3a',
                      ),
                    ],
                  ),
                  content: PatrimoineDrawerContent(profile: profile),
                )),
            const SizedBox(height: 12),

            // ── TIROIR 2: Ce que tu dois ──
            MintEntrance(
                delay: const Duration(milliseconds: 200),
                child: FinancialDrawer(
                  title: s.drawerCeQueTuDois,
                  subtitle: s.drawerCeQueTuDoisSubtitle,
                  heroValue: det.hasDette
                      ? formatChfCompact(det.totalDettes)
                      : '\u2014',
                  icon: Icons.credit_card_outlined,
                  accentColor:
                      det.hasDette ? MintColors.error : MintColors.textMuted,
                  onEdit: () => _showEditSheet(
                    context,
                    title: s.financialSummaryModifierDettes,
                    fields: [
                      _EditField(
                        label: s.financialSummaryEditHypotheque,
                        initialValue: det.hypotheque,
                        key: 'hypotheque',
                      ),
                      _EditField(
                        label: s.financialSummaryEditCreditConsommation,
                        initialValue: det.creditConsommation,
                        key: 'creditConsommation',
                      ),
                      _EditField(
                        label: s.financialSummaryEditLeasing,
                        initialValue: det.leasing,
                        key: 'leasing',
                      ),
                      _EditField(
                        label: s.financialSummaryEditAutresDettes,
                        initialValue: det.autresDettes,
                        key: 'autresDettes',
                      ),
                    ],
                  ),
                  content: DettesDrawerContent(profile: profile),
                )),
            const SizedBox(height: 12),

            // ── TIROIR 3: Ce que tu auras ──
            MintEntrance(
                delay: const Duration(milliseconds: 300),
                child: FinancialDrawer(
                  title: s.drawerCeQueTuAuras,
                  subtitle: s.drawerCeQueTuAurasSubtitle,
                  heroValue: projectedMonthly > 0
                      ? formatChfCompact(projectedMonthly)
                      : '\u2014',
                  heroSuffix: s.heroGapPerMonth,
                  icon: Icons.trending_up,
                  accentColor: MintColors.info,
                  onEdit: () => _showEditSheet(
                    context,
                    title: s.financialSummaryModifierPrevoyance,
                    fields: [
                      _EditField(
                        label: s.financialSummaryEditAvoirLpp,
                        initialValue: prev.avoirLppTotal,
                        key: 'avoirLppTotal',
                      ),
                      _EditField(
                        label: s.financialSummaryEditNombre3a,
                        initialValue:
                            prev.nombre3a > 0 ? prev.nombre3a.toDouble() : null,
                        key: 'nombre3a',
                      ),
                      _EditField(
                        label: s.financialSummaryEditTotal3a,
                        initialValue: prev.totalEpargne3a > 0
                            ? prev.totalEpargne3a
                            : null,
                        key: 'totalEpargne3a',
                      ),
                      _EditField(
                        label: s.financialSummaryEditRachatLpp,
                        initialValue: profile.totalLppBuybackMensuel > 0
                            ? profile.totalLppBuybackMensuel
                            : null,
                        key: 'rachatLppMensuel',
                      ),
                    ],
                  ),
                  content: FuturDrawerContent(profile: profile),
                )),
            const SizedBox(height: 20),

            // ── ENRICHMENT CTA ──
            if (missingCount > 0)
              EnrichmentCta(
                missingFieldsCount: missingCount,
                onTap: () => context.push('/scan'),
              ),
            if (missingCount > 0) const SizedBox(height: 16),

            // ── PROJECTION RETRAITE — secondary synthesis after dossier facts ──
            MintEntrance(
                delay: const Duration(milliseconds: 350),
                child: HeroGapCard(
                  currentMonthlyNet: currentMonthlyNet,
                  projectedMonthlyRetirement: projectedMonthly,
                  confidencePercent: confidence,
                  missingFieldsCount: missingCount > 0 ? missingCount : null,
                  confidenceBoostPercent: missingCount > 0
                      ? (missingCount * 10).clamp(5, 30)
                      : null,
                  onScanTap:
                      missingCount > 0 ? () => context.push('/scan') : null,
                )),
            const SizedBox(height: 20),

            // ── DISCLAIMER ──
            MintEntrance(
                delay: const Duration(milliseconds: 400),
                child: _buildDisclaimer(context)),
            const SizedBox(height: 24),

            // ── PHASE 52 SYNC STATUS ROW ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg),
              child: _buildSyncStatusRow(context),
            ),
            const SizedBox(height: 24),

            // ── RESTART DIAGNOSTIC ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await context.read<CoachProfileProvider>().clear();
                  await SmartOnboardingDraftService.clearDraft();
                  if (context.mounted) {
                    context.go('/coach/chat');
                  }
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(
                  S.of(context)!.financialSummaryRestartDiagnostic,
                  style: MintTextStyles.bodyMedium(color: MintColors.error)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MintColors.error,
                  side: BorderSide(
                      color: MintColors.error.withValues(alpha: 0.3)),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: MintSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildDossierSummary(BuildContext context, CoachProfile profile) {
    final s = S.of(context)!;
    final sourceCounts = _dossierSourceCounts(profile);
    final declared = (sourceCounts[ProfileDataSource.userInput] ?? 0) +
        (sourceCounts[ProfileDataSource.crossValidated] ?? 0);
    final certified = (sourceCounts[ProfileDataSource.certificate] ?? 0) +
        (sourceCounts[ProfileDataSource.openBanking] ?? 0);
    final estimated = sourceCounts[ProfileDataSource.estimated] ?? 0;
    final totalFacts = sourceCounts.values.fold<int>(0, (sum, n) => sum + n);

    return MintEntrance(
      child: MintSurface(
        tone: MintSurfaceTone.blanc,
        padding: const EdgeInsets.all(MintSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              identifier: 'profile_dossier_facts_summary',
              container: true,
              child: Container(
                key: const ValueKey('profile_dossier_facts_summary'),
                width: double.infinity,
                color: MintColors.transparent,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.folder_shared_outlined,
                      color: MintColors.textPrimary,
                      size: 22,
                    ),
                    const SizedBox(width: MintSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.financialSummaryDossierTitle,
                            style: MintTextStyles.titleMedium(
                              color: MintColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.financialSummaryDossierSubtitle,
                            style: MintTextStyles.bodySmall(
                              color: MintColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: MintColors.appleSurface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$totalFacts ${s.financialSummaryDossierFactCountLabel}',
                        style: MintTextStyles.labelMedium(
                          color: MintColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: MintSpacing.md),
            Semantics(
              identifier: 'profile_dossier_provenance_summary',
              container: true,
              child: Container(
                key: const ValueKey('profile_dossier_provenance_summary'),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MintColors.appleSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      s.financialSummaryDossierSourcesTitle,
                      style: MintTextStyles.labelMedium(
                        color: MintColors.textSecondary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    _sourcePill(
                      label: s.sourceBadgeDeclared,
                      count: declared,
                      color: MintColors.success,
                    ),
                    _sourcePill(
                      label: s.sourceBadgeEstimated,
                      count: estimated,
                      color: MintColors.warning,
                    ),
                    _sourcePill(
                      label: s.sourceBadgeCertified,
                      count: certified,
                      color: MintColors.info,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: MintSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                identifier: 'profile_dossier_correction_action',
                button: true,
                child: TextButton.icon(
                  key: const ValueKey('profile_dossier_correction_action'),
                  onPressed: () => _showEditSheet(
                    context,
                    title: s.financialSummaryDossierCorrectionSheetTitle,
                    fields: [
                      _EditField(
                        label: s.financialSummaryEditRevenusMensuels,
                        initialValue: profile.salaireBrutMensuel > 0
                            ? profile.salaireBrutMensuel
                            : null,
                        key: 'salaireBrutMensuel',
                      ),
                      _EditField(
                        label: s.financialSummaryEditLoyerMensuel,
                        initialValue: profile.depenses.loyer > 0
                            ? profile.depenses.loyer
                            : null,
                        key: 'loyer',
                      ),
                      _EditField(
                        label: s.financialSummaryEditLamalMensuelle,
                        initialValue: profile.depenses.assuranceMaladie > 0
                            ? profile.depenses.assuranceMaladie
                            : null,
                        key: 'assuranceMaladie',
                      ),
                      _EditField(
                        label: s.financialSummaryEditEpargneLiquide,
                        initialValue: profile.patrimoine.epargneLiquide > 0
                            ? profile.patrimoine.epargneLiquide
                            : null,
                        key: 'epargneLiquide',
                      ),
                      _EditField(
                        label: s.financialSummaryEditInvestissements,
                        initialValue: profile.patrimoine.investissements > 0
                            ? profile.patrimoine.investissements
                            : null,
                        key: 'investissements',
                      ),
                      _EditField(
                        label: s.financialSummaryEditAvoirLpp,
                        initialValue: profile.prevoyance.avoirLppTotal,
                        key: 'avoirLppTotal',
                      ),
                      _EditField(
                        label: s.financialSummaryEditTotal3a,
                        initialValue: profile.prevoyance.totalEpargne3a > 0
                            ? profile.prevoyance.totalEpargne3a
                            : null,
                        key: 'totalEpargne3a',
                      ),
                      _EditField(
                        label: s.financialSummaryEditHypotheque,
                        initialValue: profile.dettes.hypotheque,
                        key: 'hypotheque',
                      ),
                      _EditField(
                        label: s.financialSummaryEditCreditConsommation,
                        initialValue: profile.dettes.creditConsommation,
                        key: 'creditConsommation',
                      ),
                      _EditField(
                        label: s.financialSummaryEditLeasing,
                        initialValue: profile.dettes.leasing,
                        key: 'leasing',
                      ),
                      _EditField(
                        label: s.financialSummaryEditAutresDettes,
                        initialValue: profile.dettes.autresDettes,
                        key: 'autresDettes',
                      ),
                    ],
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(s.financialSummaryDossierCorrectionCta),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMint2HandoffDossierSummary(BuildContext context) {
    final s = S.of(context)!;
    return MintEntrance(
      child: MintSurface(
        tone: MintSurfaceTone.blanc,
        padding: const EdgeInsets.all(MintSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              identifier: 'profile_dossier_facts_summary',
              container: true,
              child: Container(
                key: const ValueKey('profile_dossier_facts_summary'),
                width: double.infinity,
                color: MintColors.transparent,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.folder_shared_outlined,
                      color: MintColors.textPrimary,
                      size: 22,
                    ),
                    const SizedBox(width: MintSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.financialSummaryDossierTitle,
                            style: MintTextStyles.titleMedium(
                              color: MintColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.financialSummaryDossierSubtitle,
                            style: MintTextStyles.bodySmall(
                              color: MintColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: MintColors.appleSurface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '1 ${s.financialSummaryDossierFactCountLabel}',
                        style: MintTextStyles.labelMedium(
                          color: MintColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: MintSpacing.md),
            Semantics(
              identifier: 'profile_dossier_provenance_summary',
              container: true,
              child: Container(
                key: const ValueKey('profile_dossier_provenance_summary'),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MintColors.appleSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      s.financialSummaryDossierSourcesTitle,
                      style: MintTextStyles.labelMedium(
                        color: MintColors.textSecondary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    _sourcePill(
                      label: s.sourceBadgeDeclared,
                      count: 0,
                      color: MintColors.success,
                    ),
                    _sourcePill(
                      label: s.sourceBadgeEstimated,
                      count: 0,
                      color: MintColors.warning,
                    ),
                    _sourcePill(
                      label: s.sourceBadgeCertified,
                      count: 0,
                      color: MintColors.info,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: MintSpacing.md),
            _buildMint2AxisHandoffCard(context),
          ],
        ),
      ),
    );
  }

  bool _hasMint2LiveAxis(Map<String, dynamic> handoff) {
    return FeatureFlags.enableMint2FirstExperienceEntry &&
        handoff['onb_axis_v2'] == 'lpp_rente_capital' &&
        handoff['onb_axis_schema_version'] == 2;
  }

  Widget _buildMint2AxisHandoffCard(BuildContext context) {
    final s = S.of(context)!;
    return Semantics(
      identifier: 'profile_dossier_axis_handoff',
      container: true,
      child: Container(
        key: const ValueKey('profile_dossier_axis_handoff'),
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: MintColors.appleSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.account_tree_outlined,
              color: MintColors.textPrimary,
              size: 20,
            ),
            const SizedBox(width: MintSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.mint2FirstExperienceLppLabel,
                    style: MintTextStyles.titleMedium(
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Wrap(
                    spacing: MintSpacing.xs,
                    runSpacing: MintSpacing.xs,
                    children: [
                      _axisStatePill(
                        label: s
                            .renteVsCapitalReceiptReadinessMissingRequiredInputs,
                        color: MintColors.warning,
                      ),
                      _axisStatePill(
                        label: s.renteVsCapitalReceiptReadinessMissing,
                        color: MintColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _axisStatePill({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: MintTextStyles.labelSmall(color: color)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _sourcePill({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $count',
        style: MintTextStyles.labelSmall(color: color)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Map<ProfileDataSource, int> _dossierSourceCounts(CoachProfile profile) {
    ProfileDataSource sourceFor(String key) {
      if (key == 'salaireBrutMensuel') {
        final salarySource = profile.dataSources['salaireBrutMensuel'] ??
            profile.dataSources['revenuBrutAnnuel'];
        if (salarySource != null) return salarySource;
        if (profile.userProvidedFields.contains('salary')) {
          return ProfileDataSource.userInput;
        }
      }
      return profile.dataSources[key] ??
          (profile.userProvidedFields.contains(key)
              ? ProfileDataSource.userInput
              : ProfileDataSource.estimated);
    }

    ProfileDataSource sourceForAny(List<String> keys) {
      final sources = keys
          .map((key) => profile.dataSources[key])
          .whereType<ProfileDataSource>()
          .toSet();
      if (sources.contains(ProfileDataSource.openBanking)) {
        return ProfileDataSource.openBanking;
      }
      if (sources.contains(ProfileDataSource.certificate)) {
        return ProfileDataSource.certificate;
      }
      if (sources.contains(ProfileDataSource.crossValidated)) {
        return ProfileDataSource.crossValidated;
      }
      if (sources.contains(ProfileDataSource.userInput)) {
        return ProfileDataSource.userInput;
      }
      return ProfileDataSource.estimated;
    }

    final fields = <ProfileDataSource>[];
    if (profile.revenuBrutAnnuel > 0) {
      fields.add(sourceFor('salaireBrutMensuel'));
    }
    if (profile.depenses.loyer > 0) {
      fields.add(sourceFor('depenses.loyer'));
    }
    if (profile.depenses.assuranceMaladie > 0) {
      fields.add(sourceFor('depenses.assuranceMaladie'));
    }
    if (profile.patrimoine.epargneLiquide > 0) {
      fields.add(sourceFor('patrimoine.epargneLiquide'));
    }
    if (profile.patrimoine.investissements > 0) {
      fields.add(sourceFor('patrimoine.investissements'));
    }
    if ((profile.prevoyance.avoirLppTotal ?? 0) > 0) {
      fields.add(sourceFor('prevoyance.avoirLppTotal'));
    }
    if (profile.prevoyance.totalEpargne3a > 0) {
      fields.add(sourceFor('prevoyance.totalEpargne3a'));
    }
    if (profile.dettes.totalDettes > 0) {
      fields.add(sourceForAny(const [
        'dettes.totalDettes',
        'dettes.hypotheque',
        'dettes.creditConsommation',
        'dettes.leasing',
        'dettes.autresDettes',
      ]));
    }

    final counts = <ProfileDataSource, int>{};
    for (final source in fields) {
      counts[source] = (counts[source] ?? 0) + 1;
    }
    return counts;
  }

  // ══════════════════════════════════════════════════════════════
  //  DISCLAIMER
  // ══════════════════════════════════════════════════════════════

  Widget _buildDisclaimer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Text(
        S.of(context)!.financialSummaryDisclaimer,
        style: MintTextStyles.labelSmall(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  SYNC STATUS ROW (Phase 52 T-52-03)
  // ══════════════════════════════════════════════════════════════
  //
  // Compact navigation affordance. Shows the current cloud-sync state
  // and routes to /settings/confidentialite for management. Always
  // visible (local-mode users see « Désactivée », which is correct).
  //
  // Design panel decisions (2026-05-03):
  //  - reuse settingsPrivacyCloudSyncTitle/On/Off ARB keys
  //  - new key: profileSyncRowHint (« Gérer dans Réglages › Confidentialité »)
  //  - context.push (not go) — preserves back stack to Profile
  //  - cloud_done_outlined when ON, cloud_outlined when OFF
  //  - state color matches Settings screen (success / textMuted)
  //  - ExcludeSemantics on chevron + state Text; Semantics(button:)
  //    wraps the whole InkWell
  Widget _buildSyncStatusRow(BuildContext context) {
    final s = S.of(context)!;
    final accountState = context.watch<AuthProvider>().accountDataState;
    final cloudSyncOn = accountState == MintAccountDataState.cloudSyncOn;
    final stateLabel = cloudSyncOn
        ? s.settingsPrivacyCloudSyncOn
        : s.settingsPrivacyCloudSyncOff;
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: EdgeInsets.zero,
      child: Semantics(
        button: true,
        container: true,
        label: '${s.settingsPrivacyCloudSyncTitle}, $stateLabel',
        hint: s.profileSyncRowHint,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/settings/confidentialite');
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MintSpacing.md,
                vertical: MintSpacing.md,
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      cloudSyncOn
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_outlined,
                      size: 24,
                      color: MintColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: MintSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.settingsPrivacyCloudSyncTitle,
                          style: MintTextStyles.titleMedium(
                            color: MintColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        ExcludeSemantics(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: MintTextStyles.labelMedium(
                              color: cloudSyncOn
                                  ? MintColors.success
                                  : MintColors.textMuted,
                            ),
                            child: Text(stateLabel),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.profileSyncRowHint,
                          style: MintTextStyles.bodySmall(
                            color: MintColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right,
                      color: MintColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  INLINE EDIT SHEET
  // ══════════════════════════════════════════════════════════════

  void _showEditSheet(
    BuildContext context, {
    required String title,
    required List<_EditField> fields,
  }) {
    final controllers = <String, TextEditingController>{};
    for (final f in fields) {
      controllers[f.key] = TextEditingController(
        text: f.initialValue != null ? formatChf(f.initialValue!) : '',
      );
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: MintTextStyles.headlineMedium(),
                ),
                const SizedBox(height: 20),
                for (final f in fields) ...[
                  Text(
                    f.label,
                    style: MintTextStyles.bodySmall(),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: controllers[f.key],
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    decoration: InputDecoration(
                      hintText: '0',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 8),
                FilledButton(
                  // lint-ignore: prefer_mint_cta
                  // Fix 2026-05-22 (data-race): the previous code fired
                  // _applyEdits() unawaited, then immediately popped the
                  // sheet. updateInline()'s ReportPersistenceService.saveAnswers
                  // write would be cancelled if the user backgrounded the app
                  // before SharedPreferences flushed — silent data loss.
                  // Now await the write before popping; UX gets a 50ms-200ms
                  // pause but persistence is guaranteed.
                  onPressed: () async {
                    await _applyEdits(context, controllers);
                    if (context.mounted) ctx.pop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    foregroundColor: MintColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    S.of(context)!.financialSummaryEnregistrer,
                    style: MintTextStyles.titleMedium(color: MintColors.white),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      for (final c in controllers.values) {
        c.dispose();
      }
    });
  }

  // Returns Future<void> so the caller (the bottom-sheet Save button) can
  // await the SharedPreferences write before popping. See call site comment
  // on the FilledButton onPressed — fix for unawaited write race.
  Future<void> _applyEdits(
    BuildContext context,
    Map<String, TextEditingController> controllers,
  ) async {
    double? parseVal(String key) {
      final raw = controllers[key]?.text.replaceAll(RegExp(r'[^0-9.,]'), '');
      if (raw == null || raw.isEmpty) return null;
      return double.tryParse(raw.replaceAll("'", '').replaceAll(',', '.'));
    }

    await context.read<CoachProfileProvider>().updateInline(
          salaireBrutMensuel: parseVal('salaireBrutMensuel'),
          // Tiroir 1 — Patrimoine
          epargneLiquide: parseVal('epargneLiquide'),
          investissements: parseVal('investissements'),
          avoirLppTotal: parseVal('avoirLppTotal'),
          nombre3a: parseVal('nombre3a')?.toInt(),
          totalEpargne3a: parseVal('totalEpargne3a'),
          // Tiroir 2 — Budget et dettes
          loyer: parseVal('loyer'),
          assuranceMaladie: parseVal('assuranceMaladie'),
          hypotheque: parseVal('hypotheque'),
          creditConsommation: parseVal('creditConsommation'),
          leasing: parseVal('leasing'),
          autresDettes: parseVal('autresDettes'),
          // Tiroir 3 — Projection
          rachatLppMensuel: parseVal('rachatLppMensuel'),
        );
  }
}

class _EditField {
  final String label;
  final double? initialValue;
  final String key;

  const _EditField({
    required this.label,
    this.initialValue,
    required this.key,
  });
}
