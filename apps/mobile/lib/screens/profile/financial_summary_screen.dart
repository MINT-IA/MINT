import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/smart_onboarding_draft_service.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/widgets/profile/hero_gap_card.dart';
import 'package:mint_mobile/widgets/profile/financial_drawer.dart';
import 'package:mint_mobile/widgets/profile/patrimoine_drawer_content.dart';
import 'package:mint_mobile/widgets/profile/dettes_drawer_content.dart';
import 'package:mint_mobile/widgets/profile/futur_drawer_content.dart';
import 'package:mint_mobile/widgets/profile/enrichment_cta.dart';

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
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          if (profile == null)
            _buildEmptyState(context)
          else
            _buildContent(context, profile),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  APP BAR
  // ══════════════════════════════════════════════════════════════

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 80,
      backgroundColor: MintColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.white),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                MintColors.primary,
                MintColors.primary.withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 56, bottom: 14),
        title: Text(
          S.of(context)!.financialSummaryTitle,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: MintColors.white,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  EMPTY STATE
  // ══════════════════════════════════════════════════════════════

  Widget _buildEmptyState(BuildContext context) {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_outlined,
                size: 48, color: MintColors.textMuted),
            const SizedBox(height: 16),
            Text(
              S.of(context)!.financialSummaryNoProfile,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: MintColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.push('/onboarding/quick'),
              child:
                  Text(S.of(context)!.financialSummaryStartDiagnostic),
            ),
          ],
        ),
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
          )
        : null;

    // ── Hero Gap data ──
    final currentMonthlyNet = breakdown != null
        ? breakdown.disposableIncome / 12
        : 0.0;
    final renteAvs = prev.renteAVSEstimeeMensuelle ?? 0;
    final renteLpp =
        (prev.avoirLppTotal ?? 0) * prev.tauxConversion / 12;
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HERO GAP CARD ──
            HeroGapCard(
              currentMonthlyNet: currentMonthlyNet,
              projectedMonthlyRetirement: projectedMonthly,
              confidencePercent: confidence,
              missingFieldsCount: missingCount > 0 ? missingCount : null,
              confidenceBoostPercent:
                  missingCount > 0 ? (missingCount * 10).clamp(5, 30) : null,
              onScanTap: missingCount > 0
                  ? () => context.push('/document-scan')
                  : null,
            ),
            const SizedBox(height: 20),

            // ── TIROIR 1: Ce que tu as ──
            FinancialDrawer(
              title: s.drawerCeQueTuAs,
              subtitle: s.drawerCeQueTuAsSubtitle,
              heroValue: formatChfCompact(patrimoineNet),
              icon: Icons.savings_outlined,
              accentColor: MintColors.success,
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
                    initialValue:
                        pat.investissements > 0 ? pat.investissements : null,
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
                    initialValue:
                        prev.totalEpargne3a > 0 ? prev.totalEpargne3a : null,
                    key: 'totalEpargne3a',
                  ),
                ],
              ),
              content: PatrimoineDrawerContent(profile: profile),
            ),
            const SizedBox(height: 12),

            // ── TIROIR 2: Ce que tu dois ──
            FinancialDrawer(
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
            ),
            const SizedBox(height: 12),

            // ── TIROIR 3: Ce que tu auras ──
            FinancialDrawer(
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
                    initialValue:
                        prev.totalEpargne3a > 0 ? prev.totalEpargne3a : null,
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
            ),
            const SizedBox(height: 20),

            // ── ENRICHMENT CTA ──
            if (missingCount > 0)
              EnrichmentCta(
                missingFieldsCount: missingCount,
                onTap: () => context.push('/document-scan'),
              ),
            if (missingCount > 0) const SizedBox(height: 16),

            // ── DISCLAIMER ──
            _buildDisclaimer(context),
            const SizedBox(height: 24),

            // ── RESTART DIAGNOSTIC ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: OutlinedButton.icon(
                onPressed: () async {
                  context.read<CoachProfileProvider>().clear();
                  await ReportPersistenceService.clear();
                  await SmartOnboardingDraftService.clearDraft();
                  if (context.mounted) {
                    context.push('/onboarding/quick');
                  }
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(
                  S.of(context)!.financialSummaryRestartDiagnostic,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
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
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
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
        style: GoogleFonts.inter(
          fontSize: 11,
          color: MintColors.textMuted,
          height: 1.4,
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
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
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              for (final f in fields) ...[
                Text(
                  f.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textSecondary,
                  ),
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
                onPressed: () {
                  _applyEdits(context, controllers);
                  Navigator.of(ctx).pop();
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
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ).whenComplete(() {
      for (final c in controllers.values) {
        c.dispose();
      }
    });
  }

  void _applyEdits(
    BuildContext context,
    Map<String, TextEditingController> controllers,
  ) {
    double? parseVal(String key) {
      final raw = controllers[key]?.text.replaceAll(RegExp(r'[^0-9.,]'), '');
      if (raw == null || raw.isEmpty) return null;
      return double.tryParse(raw.replaceAll("'", '').replaceAll(',', '.'));
    }

    context.read<CoachProfileProvider>().updateInline(
          // Tiroir 1 — Patrimoine
          epargneLiquide: parseVal('epargneLiquide'),
          investissements: parseVal('investissements'),
          avoirLppTotal: parseVal('avoirLppTotal'),
          nombre3a: parseVal('nombre3a')?.toInt(),
          totalEpargne3a: parseVal('totalEpargne3a'),
          // Tiroir 2 — Dettes
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
