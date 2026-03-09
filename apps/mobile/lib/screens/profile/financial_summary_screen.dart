import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/smart_onboarding_draft_service.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/widgets/profile/financial_summary_card.dart';
import 'package:mint_mobile/widgets/profile/budget_waterfall_painter.dart';
import 'package:mint_mobile/widgets/profile/narrative_header.dart';
import 'package:mint_mobile/widgets/profile/couple_patrimoine_card.dart';
import 'package:mint_mobile/widgets/profile/conjoint_invitation_card.dart';
import 'package:mint_mobile/widgets/profile/futur_projection_card.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/services/chiffre_choc_selector.dart';
import 'package:mint_mobile/widgets/coach/chiffre_choc_section.dart';
import 'package:mint_mobile/widgets/coach/fri_radar_chart.dart';
import 'package:mint_mobile/widgets/coach/data_quality_card.dart';
import 'package:mint_mobile/widgets/coach/what_if_stories_widget.dart';

/// Écran "Mon aperçu financier" — vue consolidée de toutes les données
/// du CoachProfile, organisées par section.
///
/// Accessible depuis /profile/bilan et depuis le ProfileScreen.
/// Each section has an edit icon that opens an inline edit dialog.
class FinancialSummaryScreen extends StatelessWidget {
  const FinancialSummaryScreen({super.key});

  ProfileDataSource _source(CoachProfile p, String field) {
    return p.dataSources[field] ?? ProfileDataSource.estimated;
  }

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
            SliverFillRemaining(
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
                      child: Text(S.of(context)!.financialSummaryStartDiagnostic),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Narrative Header — contextual phrase + confidence ──
                    _buildNarrativeHeader(context, profile),
                    const SizedBox(height: 16),

                    _buildChiffreChocBanner(profile),
                    ChiffreChocSection(
                      profile: profile,
                      narratives: {
                        'fiscalite': S.of(context)!.financialSummaryNarrativeFiscalite,
                        'prevoyance': S.of(context)!.financialSummaryNarrativePrevoyance,
                        'avs': S.of(context)!.financialSummaryNarrativeAvs,
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildSourceLegend(context),
                    const SizedBox(height: 16),

                    // ── FRI Radar Chart — santé financière en 4 axes ──
                    _buildFriRadar(profile),
                    const SizedBox(height: 16),

                    // ══════════════════════════════════════════════════
                    //  TRIPTYQUE: FLUX / STOCK / FUTUR
                    // ══════════════════════════════════════════════════

                    // ── FLUX: Waterfall + Revenus cascade ──
                    _buildWaterfallSection(context, profile),
                    _buildRevenusCascadeCard(context, profile),
                    _buildDepensesCard(context, profile),
                    _buildDettesCard(context, profile),

                    // ── STOCK: Patrimoine + Prévoyance ──
                    _buildPrevoyanceCard(context, profile),
                    if (profile.isCouple)
                      _buildCouplePatrimoine(context, profile)
                    else
                      _buildPatrimoineCard(context, profile),

                    // ── Couple invitation ──
                    if (profile.isCouple)
                      _buildConjointInvitation(context, profile),

                    // ── FUTUR: Projection retraite ──
                    _buildFuturProjection(context, profile),
                    const SizedBox(height: 16),

                    // ── Data Quality Card — completude du profil ──
                    _buildDataQualityCard(context, profile),
                    const SizedBox(height: 16),

                    _buildDisclaimer(context),
                    const SizedBox(height: 24),

                    // ── What-If Stories — scenarios exploratoires ──
                    _buildWhatIfStories(context, profile),
                    const SizedBox(height: 32),
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
                          side: BorderSide(color: MintColors.error.withValues(alpha: 0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 80,
      backgroundColor: MintColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
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
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ── CHIFFRE CHOC BANNER ──────────────────────────────────────────────────
  //  Recompute from profile data and show as a compact motivational card.
  //  Keeps the emotional hook from onboarding alive on the bilan screen.

  Widget _buildChiffreChocBanner(CoachProfile p) {
    if (p.revenuBrutAnnuel <= 0 || p.age <= 0) return const SizedBox.shrink();

    final canton = p.canton.isNotEmpty ? p.canton : 'ZH';
    ChiffreChoc choc;
    try {
      final minimal = MinimalProfileService.compute(
        age: p.age,
        grossSalary: p.revenuBrutAnnuel,
        canton: canton,
      );
      choc = ChiffreChocSelector.select(minimal);
    } catch (_) {
      return const SizedBox.shrink();
    }

    final color = _chocColor(choc.colorKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withAlpha(14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withAlpha(24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_chocIcon(choc.iconName), color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  choc.title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  choc.value,
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  choc.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textSecondary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _chocColor(String key) => switch (key) {
        'error' => MintColors.error,
        'warning' => MintColors.warning,
        'success' => MintColors.success,
        'info' => MintColors.info,
        _ => MintColors.primary,
      };

  IconData _chocIcon(String name) => switch (name) {
        'warning_amber' => Icons.warning_amber_rounded,
        'trending_down' => Icons.trending_down_rounded,
        'savings' => Icons.savings_rounded,
        'account_balance' => Icons.account_balance_rounded,
        _ => Icons.insights_rounded,
      };

  Widget _buildSourceLegend(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _legendItem('\u2713', S.of(context)!.financialSummaryLegendSaisi, MintColors.success),
          _legendItem('~', S.of(context)!.financialSummaryLegendEstime, MintColors.warning),
          _legendItem('\u2B06', S.of(context)!.financialSummaryLegendCertifie, MintColors.info),
        ],
      ),
    );
  }

  Widget _legendItem(String symbol, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            symbol,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
              fontSize: 11, color: MintColors.textSecondary),
        ),
      ],
    );
  }

  // _buildCoupleToggle removed — replaced by NarrativeHeader + ConjointInvitationCard

  // ══════════════════════════════════════════════════════════════
  //  REVENUS
  // ══════════════════════════════════════════════════════════════

  // ══════════════════════════════════════════════════════════════
  //  REVENUS & FISCALITÉ — Cascade unifiée brut → net → disponible
  //
  //  Fix S45: L'ancienne carte Fiscalité listait l'impôt dans les
  //  déductions mais affichait "Net fiche de paie (avant impôt)" comme
  //  total — incohérence sémantique. Maintenant c'est une cascade claire.
  // ══════════════════════════════════════════════════════════════

  Widget _buildRevenusCascadeCard(BuildContext context, CoachProfile p) {
    final gross = p.revenuBrutAnnuel;
    if (gross <= 0) return const SizedBox.shrink();

    final breakdown = NetIncomeBreakdown.compute(
      grossSalary: gross,
      canton: p.canton,
      age: p.age,
    );

    final lines = <FinancialLine>[];

    final l10n = S.of(context)!;

    // ── Revenus bruts ──
    lines.add(FinancialLine(
      label: l10n.financialSummarySalaireBrutMensuel,
      formattedValue: formatChfMonthly(p.salaireBrutMensuel),
      source: _source(p, 'salaireBrutMensuel'),
    ));

    // 13ème salaire (si > 12 mois)
    if (p.nombreDeMois > 12) {
      final treizieme = (p.salaireBrutMensuel ?? 0) * (p.nombreDeMois - 12);
      lines.add(FinancialLine(
        label: p.nombreDeMois == 13
            ? l10n.financialSummary13emeSalaire
            : l10n.financialSummaryNemeMois('${p.nombreDeMois}'),
        formattedValue: '+ ${formatChfOrDash(treizieme)}',
      ));
    }

    // Bonus (si déclaré)
    if (p.bonusPourcentage != null && p.bonusPourcentage! > 0) {
      final base = (p.salaireBrutMensuel ?? 0) * p.nombreDeMois;
      final bonus = base * p.bonusPourcentage! / 100;
      lines.add(FinancialLine(
        label: l10n.financialSummaryBonusEstime(formatPct(p.bonusPourcentage!)),
        formattedValue: '+ ${formatChfOrDash(bonus)}',
      ));
    }

    // Conjoint (si couple)
    if (p.isCouple && p.conjoint?.salaireBrutMensuel != null) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryConjointBrutMensuel(
            p.conjoint?.firstName ?? l10n.financialSummaryDefaultConjoint),
        formattedValue: formatChfMonthly(p.conjoint!.salaireBrutMensuel),
        source: _source(p, 'conjoint.salaireBrutMensuel'),
      ));
    }

    // Subtotal: Revenu brut annuel
    lines.add(FinancialLine(
      label: p.isCouple ? l10n.financialSummaryRevenuBrutAnnuelCouple : l10n.financialSummaryRevenuBrutAnnuel,
      formattedValue: formatChfOrDash(
          p.isCouple ? p.revenuBrutAnnuelCouple : gross),
      isSubtotal: true,
    ));

    // Mensuel lissé (si 13ème ou bonus)
    if (p.nombreDeMois > 12 || (p.bonusPourcentage ?? 0) > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummarySoitLisseSur12Mois,
        formattedValue: formatChfMonthly(gross / 12),
      ));
    }

    // ── Déductions salariales ──
    lines.add(FinancialLine(
      label: l10n.financialSummaryDeductionsSalariales,
      isSectionHeader: true,
    ));

    lines.add(FinancialLine(
      label: l10n.financialSummaryChargesSociales,
      formattedValue: '\u2212 ${formatChfMonthly(breakdown.socialCharges / 12)}',
      isDeduction: true,
    ));

    lines.add(FinancialLine(
      label: l10n.financialSummaryCotisationLpp,
      formattedValue: '\u2212 ${formatChfMonthly(breakdown.lppEmployee / 12)}',
      isDeduction: true,
    ));

    // Subtotal: Net fiche de paie
    lines.add(FinancialLine(
      label: l10n.financialSummaryNetFicheDePaie,
      formattedValue: formatChfMonthly(breakdown.monthlyNetPayslip),
      isSubtotal: true,
    ));

    // Hint about what "net fiche de paie" means
    lines.add(FinancialLine(
      label: l10n.financialSummaryNetFicheDePaieHint,
      isHint: true,
    ));

    // ── Fiscalité ──
    lines.add(FinancialLine(
      label: l10n.financialSummaryFiscalite,
      isSectionHeader: true,
    ));

    lines.add(FinancialLine(
      label: l10n.financialSummaryImpotEstime,
      formattedValue: '\u2212 ${formatChfMonthly(breakdown.incomeTaxEstimate / 12)}',
      isDeduction: true,
    ));

    // Taux marginal
    final marginalRate = RetirementTaxCalculator.estimateMarginalRate(
      gross,
      p.canton.isNotEmpty ? p.canton : 'ZH',
    );
    lines.add(FinancialLine(
      label: l10n.financialSummaryTauxMarginalEstime,
      formattedValue: '${formatPct(marginalRate * 100)}\u00a0%',
    ));

    // 13ème / bonus info
    if (p.nombreDeMois > 12 || (p.bonusPourcentage ?? 0) > 0) {
      final treizieme = p.nombreDeMois > 12
          ? (p.salaireBrutMensuel ?? 0) * (p.nombreDeMois - 12)
          : 0.0;
      final base = (p.salaireBrutMensuel ?? 0) * p.nombreDeMois;
      final bonus = (p.bonusPourcentage ?? 0) > 0
          ? base * p.bonusPourcentage! / 100
          : 0.0;
      final extraAnnuel = treizieme + bonus;
      final extraNet = extraAnnuel * breakdown.disposableRatio;
      final hintLabel = '${p.nombreDeMois > 12 ? "13\u00e8me" : ""}${p.nombreDeMois > 12 && bonus > 0 ? " + " : ""}${bonus > 0 ? "bonus" : ""}';
      lines.add(FinancialLine(
        label: l10n.financialSummary13emeEtBonusHint(hintLabel, formatChfOrDash(extraNet)),
        isHint: true,
      ));
    }

    return FinancialSummaryCard(
      title: l10n.financialSummaryRevenusEtFiscalite,
      icon: Icons.account_balance_wallet_outlined,
      iconColor: MintColors.primary,
      lines: lines,
      // Hero total: Disponible après impôt
      totalLine: FinancialLine(
        label: l10n.financialSummaryDisponibleApresImpot,
        formattedValue: formatChfMonthly(breakdown.disposableIncome / 12),
        isHero: true,
      ),
      footnote: l10n.financialSummaryFootnoteRevenus,
      onScanCertificate: () => context.push('/document-scan'),
      scanLabel: l10n.financialSummaryScanFicheSalaire,
      onEdit: () => _showEditSheet(
        context,
        title: l10n.financialSummaryModifierRevenu,
        fields: [
          _EditField(
            label: l10n.financialSummaryEditSalaireBrut,
            initialValue: p.salaireBrutMensuel,
            key: 'salaireBrutMensuel',
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PRÉVOYANCE (AVS + LPP + 3a + Libre passage)
  // ══════════════════════════════════════════════════════════════

  FinancialSummaryCard _buildPrevoyanceCard(BuildContext context, CoachProfile p) {
    final prev = p.prevoyance;
    final lines = <FinancialLine>[];
    final l10n = S.of(context)!;

    // --- AVS ---
    lines.add(FinancialLine(
      label: l10n.financialSummaryAvs1erPilier,
      formattedValue: '',
    ));
    lines.add(FinancialLine(
      label: l10n.financialSummaryAnneesCotisees,
      formattedValue: prev.anneesContribuees != null
          ? l10n.financialSummaryAnneesUnit('${prev.anneesContribuees}')
          : '\u2014',
      source: _source(p, 'prevoyance.anneesContribuees'),
      indent: true,
    ));
    if (prev.lacunesAVS != null && prev.lacunesAVS! > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryLacunes,
        formattedValue: l10n.financialSummaryAnneesUnit('${prev.lacunesAVS}'),
        source: _source(p, 'prevoyance.lacunesAVS'),
        indent: true,
      ));
    }
    lines.add(FinancialLine(
      label: l10n.financialSummaryRenteEstimee,
      formattedValue: prev.renteAVSEstimeeMensuelle != null
          ? formatChfMonthly(prev.renteAVSEstimeeMensuelle)
          : '\u2014',
      source: _source(p, 'prevoyance.renteAVSEstimeeMensuelle'),
      indent: true,
      isLast: true,
    ));

    // --- LPP ---
    lines.add(FinancialLine(
      label: l10n.financialSummaryLpp2ePilier,
      formattedValue: '',
    ));
    lines.add(FinancialLine(
      label: l10n.financialSummaryAvoirTotal,
      formattedValue: formatChfOrDash(prev.avoirLppTotal),
      source: _source(p, 'prevoyance.avoirLppTotal'),
      indent: true,
    ));
    if (prev.avoirLppObligatoire != null) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryObligatoire,
        formattedValue: formatChfOrDash(prev.avoirLppObligatoire),
        indent: true,
      ));
    }
    if (prev.avoirLppSurobligatoire != null) {
      lines.add(FinancialLine(
        label: l10n.financialSummarySurobligatoire,
        formattedValue: formatChfOrDash(prev.avoirLppSurobligatoire),
        indent: true,
      ));
    }
    lines.add(FinancialLine(
      label: l10n.financialSummaryTauxConversion,
      formattedValue: formatPctOrDash(prev.tauxConversion),
      source: _source(p, 'prevoyance.tauxConversion'),
      indent: true,
    ));
    if (prev.lacuneRachatRestante > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryRachatPossible,
        formattedValue: formatChfOrDash(prev.lacuneRachatRestante),
        indent: true,
      ));
    }
    if (p.totalLppBuybackMensuel > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryRachatPlanifie,
        formattedValue: formatChfMonthly(p.totalLppBuybackMensuel),
        source: ProfileDataSource.userInput,
        indent: true,
      ));
    }
    if (prev.nomCaisse != null) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryCaisse,
        formattedValue: prev.nomCaisse!,
        indent: true,
        isLast: true,
      ));
    }

    // --- 3a ---
    lines.add(FinancialLine(
      label: l10n.financialSummary3a3ePilier,
      formattedValue: '',
    ));
    if (prev.comptes3a.isNotEmpty) {
      for (int i = 0; i < prev.comptes3a.length; i++) {
        final c = prev.comptes3a[i];
        lines.add(FinancialLine(
          label: c.provider,
          formattedValue: formatChfOrDash(c.solde),
          indent: true,
          isLast: i == prev.comptes3a.length - 1 && prev.librePassage.isEmpty,
        ));
      }
    } else {
      lines.add(FinancialLine(
        label: l10n.financialSummaryNComptes('${prev.nombre3a}'),
        formattedValue: formatChfOrDash(prev.totalEpargne3a),
        source: _source(p, 'prevoyance.totalEpargne3a'),
        indent: true,
        isLast: prev.librePassage.isEmpty,
      ));
    }

    // --- Libre passage ---
    if (prev.librePassage.isNotEmpty) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryLibrePassage,
        formattedValue: '',
      ));
      for (int i = 0; i < prev.librePassage.length; i++) {
        final lp = prev.librePassage[i];
        lines.add(FinancialLine(
          label: lp.institution ?? l10n.financialSummaryCompteN('${i + 1}'),
          formattedValue: formatChfOrDash(lp.solde),
          indent: true,
          isLast: i == prev.librePassage.length - 1,
        ));
      }
    }

    // Conjoint prévoyance summary
    if (p.isCouple && p.conjoint?.prevoyance != null) {
      final cp = p.conjoint!.prevoyance!;
      lines.add(FinancialLine(
        label: l10n.financialSummaryConjointLpp(
            p.conjoint?.firstName ?? l10n.financialSummaryDefaultConjoint),
        formattedValue: formatChfOrDash(cp.avoirLppTotal),
      ));
      if (cp.totalEpargne3a > 0) {
        lines.add(FinancialLine(
          label: l10n.financialSummaryConjoint3a(
              p.conjoint?.firstName ?? l10n.financialSummaryDefaultConjoint),
          formattedValue: formatChfOrDash(cp.totalEpargne3a),
        ));
      }
      // FATCA warning: US citizens can use Raiffeisen but not VIAC/Finpension
      if (p.conjoint!.isFatcaResident) {
        lines.add(FinancialLine(
          label: l10n.financialSummaryFatcaWarning,
          formattedValue: '',
          source: ProfileDataSource.estimated,
          indent: true,
        ));
      }
    }

    return FinancialSummaryCard(
      title: l10n.financialSummaryPrevoyanceTitle,
      icon: Icons.security_outlined,
      iconColor: MintColors.info,
      lines: lines,
      onScanCertificate: () => context.push('/document-scan'),
      scanLabel: l10n.financialSummaryScanCertificatLpp,
      onEdit: () => _showEditSheet(
        context,
        title: l10n.financialSummaryModifierPrevoyance,
        fields: [
          _EditField(
            label: l10n.financialSummaryEditAvoirLpp,
            initialValue: prev.avoirLppTotal,
            key: 'avoirLppTotal',
          ),
          _EditField(
            label: l10n.financialSummaryEditNombre3a,
            initialValue: prev.nombre3a > 0 ? prev.nombre3a.toDouble() : null,
            key: 'nombre3a',
          ),
          _EditField(
            label: l10n.financialSummaryEditTotal3a,
            initialValue: prev.totalEpargne3a > 0 ? prev.totalEpargne3a : null,
            key: 'totalEpargne3a',
          ),
          _EditField(
            label: l10n.financialSummaryEditRachatLpp,
            initialValue: p.totalLppBuybackMensuel > 0
                ? p.totalLppBuybackMensuel
                : null,
            key: 'rachatLppMensuel',
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PATRIMOINE
  // ══════════════════════════════════════════════════════════════

  FinancialSummaryCard _buildPatrimoineCard(BuildContext context, CoachProfile p) {
    final pat = p.patrimoine;
    final det = p.dettes;
    final lines = <FinancialLine>[];
    final l10n = S.of(context)!;

    // ── Liquidités ──
    lines.add(FinancialLine(
      label: l10n.financialSummaryLiquidites,
      isSectionHeader: true,
    ));
    lines.add(FinancialLine(
      label: l10n.financialSummaryEpargneLiquide,
      formattedValue: formatChfOrDash(pat.epargneLiquide),
      source: _source(p, 'patrimoine.epargneLiquide'),
    ));
    lines.add(FinancialLine(
      label: l10n.financialSummaryInvestissements,
      formattedValue: formatChfOrDash(pat.investissements),
      source: _source(p, 'patrimoine.investissements'),
    ));

    // ── Immobilier (si renseigné) ──
    final hasProperty = pat.immobilierEffectif > 0;
    if (hasProperty) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryImmobilier,
        isSectionHeader: true,
      ));
      if (pat.propertyDescription != null) {
        lines.add(FinancialLine(
          label: pat.propertyDescription!,
          formattedValue: '',
        ));
      }
      lines.add(FinancialLine(
        label: l10n.financialSummaryValeurEstimee,
        formattedValue: formatChfOrDash(pat.immobilierEffectif),
        source: _source(p, 'patrimoine.propertyMarketValue'),
      ));
      if ((pat.mortgageBalance ?? 0) > 0) {
        lines.add(FinancialLine(
          label: l10n.financialSummaryHypothequeRestante,
          formattedValue: '\u2212 ${formatChfOrDash(pat.mortgageBalance)}',
          isDeduction: true,
        ));
        lines.add(FinancialLine(
          label: l10n.financialSummaryValeurNetteImmobiliere,
          formattedValue: formatChfOrDash(pat.immobilierNet),
          isSubtotal: true,
        ));
        // LTV ratio avec conseil FINMA
        final ltv = pat.loanToValue;
        final ltvPct = formatPct(ltv * 100);
        lines.add(FinancialLine(
          label: ltv > 0.67
              ? l10n.financialSummaryLtvAmortissement(ltvPct)
              : ltv > 0.50
                  ? l10n.financialSummaryLtvBonneVoie(ltvPct)
                  : l10n.financialSummaryLtvExcellent(ltvPct),
          isHint: true,
        ));
      }
    }

    // ── Prévoyance (stock, cross-link) ──
    final prev = p.prevoyance;
    lines.add(FinancialLine(
      label: l10n.financialSummaryPrevoyanceCapital,
      isSectionHeader: true,
    ));
    if ((prev.avoirLppTotal ?? 0) > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryAvoirLppTotal,
        formattedValue: formatChfOrDash(prev.avoirLppTotal),
        source: _source(p, 'prevoyance.avoirLppTotal'),
      ));
    }
    if (prev.totalEpargne3a > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryCapital3a('${prev.nombre3a}', prev.nombre3a > 1 ? 's' : ''),
        formattedValue: formatChfOrDash(prev.totalEpargne3a),
        source: _source(p, 'prevoyance.totalEpargne3a'),
      ));
    }
    if (prev.totalLibrePassage > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryLibrePassage,
        formattedValue: formatChfOrDash(prev.totalLibrePassage),
        source: _source(p, 'prevoyance.librePassage'),
      ));
    }

    // ── Totaux ──
    final prevCapital = (prev.avoirLppTotal ?? 0) +
        prev.totalEpargne3a +
        prev.totalLibrePassage;
    final patrimoineBrut = pat.epargneLiquide +
        pat.investissements +
        pat.immobilierEffectif +
        prevCapital;
    final patrimoineNet = patrimoineBrut - det.totalDettes;

    lines.add(FinancialLine(
      label: l10n.financialSummaryPatrimoineBrut,
      formattedValue: formatChfOrDash(patrimoineBrut),
      isSubtotal: true,
    ));
    if (det.totalDettes > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryDettesTotales,
        formattedValue: '\u2212 ${formatChfOrDash(det.totalDettes)}',
        isDeduction: true,
      ));
    }

    return FinancialSummaryCard(
      title: l10n.financialSummaryPatrimoine,
      icon: Icons.savings_outlined,
      iconColor: MintColors.success,
      lines: lines,
      totalLine: FinancialLine(
        label: l10n.financialSummaryPatrimoineTotalBloque,
        formattedValue: formatChfOrDash(patrimoineNet),
        isHero: true,
      ),
      onEdit: () => _showEditSheet(
        context,
        title: l10n.financialSummaryModifierPatrimoine,
        fields: [
          _EditField(
            label: l10n.financialSummaryEditEpargneLiquide,
            initialValue: pat.epargneLiquide > 0 ? pat.epargneLiquide : null,
            key: 'epargneLiquide',
          ),
          _EditField(
            label: l10n.financialSummaryEditInvestissements,
            initialValue:
                pat.investissements > 0 ? pat.investissements : null,
            key: 'investissements',
          ),
          _EditField(
            label: l10n.financialSummaryEditValeurImmobiliere,
            initialValue: pat.immobilierEffectif > 0
                ? pat.immobilierEffectif
                : null,
            key: 'propertyMarketValue',
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  DÉPENSES FIXES
  // ══════════════════════════════════════════════════════════════

  FinancialSummaryCard _buildDepensesCard(BuildContext context, CoachProfile p) {
    final dep = p.depenses;
    final lines = <FinancialLine>[];
    final l10n = S.of(context)!;

    if (dep.loyer > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryLoyerCharges,
        formattedValue: formatChfMonthly(dep.loyer),
        source: _source(p, 'depenses.loyer'),
      ));
    }
    if (dep.assuranceMaladie > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryAssuranceMaladie,
        formattedValue: formatChfMonthly(dep.assuranceMaladie),
        source: _source(p, 'depenses.assuranceMaladie'),
      ));
    }
    if (dep.electricite != null && dep.electricite! > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryElectriciteEnergie,
        formattedValue: formatChfMonthly(dep.electricite),
        source: _source(p, 'depenses.electricite'),
      ));
    }
    if (dep.transport != null && dep.transport! > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryTransport,
        formattedValue: formatChfMonthly(dep.transport),
        source: _source(p, 'depenses.transport'),
      ));
    }
    if (dep.telecom != null && dep.telecom! > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryTelecom,
        formattedValue: formatChfMonthly(dep.telecom),
        source: _source(p, 'depenses.telecom'),
      ));
    }
    if (dep.fraisMedicaux != null && dep.fraisMedicaux! > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryFraisMedicaux,
        formattedValue: formatChfMonthly(dep.fraisMedicaux),
        source: _source(p, 'depenses.fraisMedicaux'),
      ));
    }
    if (dep.autresDepensesFixes != null && dep.autresDepensesFixes! > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryAutresFraisFixes,
        formattedValue: formatChfMonthly(dep.autresDepensesFixes),
        source: _source(p, 'depenses.autresDepensesFixes'),
      ));
    }

    if (lines.isEmpty) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryAucuneDepense,
        formattedValue: '\u2014',
      ));
    }

    return FinancialSummaryCard(
      title: l10n.financialSummaryDepensesFixes,
      icon: Icons.receipt_long_outlined,
      iconColor: MintColors.warning,
      lines: lines,
      totalLine: dep.totalMensuel > 0
          ? FinancialLine(
              label: l10n.financialSummaryTotalMensuel,
              formattedValue: formatChfMonthly(dep.totalMensuel),
            )
          : null,
      onEdit: () => _showEditSheet(
        context,
        title: l10n.financialSummaryModifierDepenses,
        fields: [
          _EditField(
            label: l10n.financialSummaryEditLoyerCharges,
            initialValue: dep.loyer > 0 ? dep.loyer : null,
            key: 'loyer',
          ),
          _EditField(
            label: l10n.financialSummaryEditAssuranceMaladie,
            initialValue: dep.assuranceMaladie > 0 ? dep.assuranceMaladie : null,
            key: 'assuranceMaladie',
          ),
          _EditField(
            label: l10n.financialSummaryEditElectricite,
            initialValue: dep.electricite,
            key: 'electricite',
          ),
          _EditField(
            label: l10n.financialSummaryEditTransport,
            initialValue: dep.transport,
            key: 'transport',
          ),
          _EditField(
            label: l10n.financialSummaryEditTelecom,
            initialValue: dep.telecom,
            key: 'telecom',
          ),
          _EditField(
            label: l10n.financialSummaryEditFraisMedicaux,
            initialValue: dep.fraisMedicaux,
            key: 'fraisMedicaux',
          ),
          _EditField(
            label: l10n.financialSummaryEditAutresFraisFixes,
            initialValue: dep.autresDepensesFixes,
            key: 'autresDepensesFixes',
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  DETTES
  // ══════════════════════════════════════════════════════════════

  FinancialSummaryCard _buildDettesCard(BuildContext context, CoachProfile p) {
    final det = p.dettes;
    final l10n = S.of(context)!;

    VoidCallback onEditDettes() => () => _showEditSheet(
          context,
          title: l10n.financialSummaryModifierDettes,
          fields: [
            _EditField(
              label: l10n.financialSummaryEditHypotheque,
              initialValue: det.hypotheque,
              key: 'hypotheque',
            ),
            _EditField(
              label: l10n.financialSummaryEditCreditConsommation,
              initialValue: det.creditConsommation,
              key: 'creditConsommation',
            ),
            _EditField(
              label: l10n.financialSummaryEditLeasing,
              initialValue: det.leasing,
              key: 'leasing',
            ),
            _EditField(
              label: l10n.financialSummaryEditAutresDettes,
              initialValue: det.autresDettes,
              key: 'autresDettes',
            ),
          ],
        );

    if (!det.hasDette) {
      return FinancialSummaryCard(
        title: l10n.financialSummaryDettes,
        icon: Icons.credit_card_outlined,
        iconColor: MintColors.textMuted,
        lines: [
          FinancialLine(
            label: l10n.financialSummaryAucuneDetteDeclaree,
            formattedValue: '\u2014',
          ),
        ],
        onEdit: onEditDettes(),
      );
    }

    final lines = <FinancialLine>[];

    // ── Dette structurelle (hypothèque) ──
    if (det.detteStructurelle > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryDetteStructurelle,
        isSectionHeader: true,
      ));
      final hypoLabel = det.rangHypotheque != null
          ? (det.rangHypotheque == 1
              ? l10n.financialSummaryHypotheque1erRang
              : l10n.financialSummaryHypotheque2emeRang)
          : l10n.financialSummaryHypotheque;
      final hypoDetail = det.tauxHypotheque != null
          ? ' (${formatPct(det.tauxHypotheque!)}\u00a0%)'
          : '';
      lines.add(FinancialLine(
        label: '$hypoLabel$hypoDetail',
        formattedValue: formatChfOrDash(det.hypotheque),
        source: _source(p, 'dettes.hypotheque'),
      ));
      if (det.mensualiteHypotheque != null) {
        lines.add(FinancialLine(
          label: l10n.financialSummaryChargeMensuelle,
          formattedValue: formatChfMonthly(det.mensualiteHypotheque),
          indent: true,
        ));
      }
      if (det.echeanceHypotheque != null) {
        final remaining = det.echeanceHypotheque!
            .difference(DateTime.now())
            .inDays;
        final years = (remaining / 365).ceil();
        lines.add(FinancialLine(
          label: l10n.financialSummaryEcheance(
              DateFormat('MM/yyyy').format(det.echeanceHypotheque!), '$years'),
          formattedValue: '',
          indent: true,
          isLast: true,
        ));
      }
      // Intérêts déductibles
      if (det.tauxHypotheque != null) {
        final interets = det.interetsHypothecairesAnnuels;
        lines.add(FinancialLine(
          label: l10n.financialSummaryInteretsDeductibles(formatChfOrDash(interets)),
          isHint: true,
        ));
      }
    }

    // ── Dette à la consommation ──
    if (det.detteConsommation > 0 || (det.autresDettes ?? 0) > 0) {
      lines.add(FinancialLine(
        label: l10n.financialSummaryDetteConsommation,
        isSectionHeader: true,
      ));

      if (det.creditConsommation != null && det.creditConsommation! > 0) {
        final tauxLabel = det.tauxCreditConso != null
            ? ' (${formatPct(det.tauxCreditConso!)}\u00a0%)'
            : '';
        lines.add(FinancialLine(
          label: '${l10n.financialSummaryCreditConsommation}$tauxLabel',
          formattedValue: formatChfOrDash(det.creditConsommation),
          source: _source(p, 'dettes.creditConsommation'),
        ));
        if (det.mensualiteCreditConso != null) {
          lines.add(FinancialLine(
            label: l10n.financialSummaryMensualite,
            formattedValue: formatChfMonthly(det.mensualiteCreditConso),
            indent: true,
            isLast: det.echeanceCreditConso == null,
          ));
        }
      }
      if (det.leasing != null && det.leasing! > 0) {
        final tauxLabel = det.tauxLeasing != null
            ? ' (${formatPct(det.tauxLeasing!)}\u00a0%)'
            : '';
        lines.add(FinancialLine(
          label: '${l10n.financialSummaryLeasing}$tauxLabel',
          formattedValue: formatChfOrDash(det.leasing),
          source: _source(p, 'dettes.leasing'),
        ));
        if (det.mensualiteLeasing != null) {
          lines.add(FinancialLine(
            label: l10n.financialSummaryMensualite,
            formattedValue: formatChfMonthly(det.mensualiteLeasing),
            indent: true,
            isLast: true,
          ));
        }
      }
      if (det.autresDettes != null && det.autresDettes! > 0) {
        lines.add(FinancialLine(
          label: l10n.financialSummaryAutresDettes,
          formattedValue: formatChfOrDash(det.autresDettes),
          source: _source(p, 'dettes.autresDettes'),
        ));
      }

      // Conseil priorité remboursement
      final tauxMax = det.tauxMaxConsommation;
      if (tauxMax != null && tauxMax > 3) {
        lines.add(FinancialLine(
          label: l10n.financialSummaryConseilRemboursement(formatPct(tauxMax)),
          isHint: true,
        ));
      }
    }

    // Charge mensuelle totale
    final totalMensualite = det.totalMensualite;

    return FinancialSummaryCard(
      title: l10n.financialSummaryDettes,
      icon: Icons.credit_card_outlined,
      iconColor: MintColors.error,
      lines: lines,
      totalLine: FinancialLine(
        label: l10n.financialSummaryTotalDettes,
        formattedValue: '${formatChfOrDash(det.totalDettes)}${totalMensualite > 0 ? " (${formatChfMonthly(totalMensualite)})" : ""}',
      ),
      onEdit: onEditDettes(),
    );
  }

  // _buildCoupleCard removed — replaced by ConjointInvitationCard + CouplePatrimoineCard

  // ══════════════════════════════════════════════════════════════
  //  NARRATIVE HEADER — contextual phrase + confidence bar
  // ══════════════════════════════════════════════════════════════

  Widget _buildNarrativeHeader(BuildContext context, CoachProfile p) {
    final gross = p.revenuBrutAnnuel;
    if (gross <= 0) return const SizedBox.shrink();

    final breakdown = NetIncomeBreakdown.compute(
      grossSalary: gross,
      canton: p.canton.isNotEmpty ? p.canton : 'ZH',
      age: p.age,
    );
    final dep = p.depenses;
    final freeMargin = breakdown.disposableIncome / 12 - dep.totalMensuel;

    final det = p.dettes;
    final prev = p.prevoyance;
    final prevCapital = (prev.avoirLppTotal ?? 0) +
        prev.totalEpargne3a +
        prev.totalLibrePassage;
    final pat = p.patrimoine;
    final patrimoineBrut = pat.epargneLiquide +
        pat.investissements +
        pat.immobilierEffectif +
        prevCapital;
    final patrimoineNet = patrimoineBrut - det.totalDettes;

    // Replacement rate estimate
    final renteAvs = prev.renteAVSEstimeeMensuelle ?? 0;
    final renteLpp = (prev.avoirLppTotal ?? 0) * 0.068 / 12; // taux conversion min
    final projectedMonthly = renteAvs + renteLpp;
    final currentDisposable = breakdown.disposableIncome / 12;
    final replacementRate = currentDisposable > 0
        ? projectedMonthly / currentDisposable
        : 0.0;

    // Confidence score from data completeness
    final knownCount = [
      p.salaireBrutMensuel > 0,
      p.canton.isNotEmpty,
      prev.avoirLppTotal != null && prev.avoirLppTotal! > 0,
      prev.totalEpargne3a > 0,
      pat.epargneLiquide > 0,
      dep.loyer > 0 || (det.hypotheque != null && det.hypotheque! > 0),
      dep.assuranceMaladie > 0,
    ].where((b) => b).length;
    final confidence = (knownCount / 7 * 100).clamp(0.0, 100.0);

    return NarrativeHeader(
      firstName: p.firstName,
      conjointFirstName: p.isCouple ? p.conjoint?.firstName : null,
      freeMargin: freeMargin,
      patrimoineNet: patrimoineNet,
      replacementRate: replacementRate,
      confidenceScore: confidence,
      confidenceBoostAvailable: confidence < 100 ? ((7 - knownCount) * 10).clamp(5, 30).toInt() : null,
      boostAction: confidence < 100 ? S.of(context)!.financialSummaryScannerDocument : null,
      onBoostTap: confidence < 100 ? () {} : null,
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  WATERFALL — budget cascade visualization
  // ══════════════════════════════════════════════════════════════

  Widget _buildWaterfallSection(BuildContext context, CoachProfile p) {
    final gross = p.revenuBrutAnnuel;
    if (gross <= 0) return const SizedBox.shrink();

    final breakdown = NetIncomeBreakdown.compute(
      grossSalary: gross,
      canton: p.canton.isNotEmpty ? p.canton : 'ZH',
      age: p.age,
    );
    final dep = p.depenses;
    final det = p.dettes;

    final steps = WaterfallStep.fromBreakdown(
      grossMonthly: gross / 12,
      socialCharges: breakdown.socialCharges / 12,
      lppEmployee: breakdown.lppEmployee / 12,
      incomeTax: breakdown.incomeTaxEstimate / 12,
      rent: dep.loyer,
      healthInsurance: dep.assuranceMaladie,
      leasing: det.mensualiteLeasing ?? 0,
      otherFixed: (dep.electricite ?? 0) +
          (dep.transport ?? 0) +
          (dep.telecom ?? 0) +
          (dep.fraisMedicaux ?? 0) +
          (dep.autresDepensesFixes ?? 0),
      pillar3a: p.prevoyance.totalEpargne3a > 0 ? 7258 / 12 : 0,
      investment: p.patrimoine.investissements > 0 ? 500 : 0,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.waterfall_chart, size: 18, color: MintColors.primary),
              const SizedBox(width: 10),
              Text(
                S.of(context)!.financialSummaryCascadeBudgetaire,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BudgetWaterfallChart(steps: steps),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  COUPLE PATRIMOINE — 3-column layout with owner badges
  // ══════════════════════════════════════════════════════════════

  Widget _buildCouplePatrimoine(BuildContext context, CoachProfile p) {
    final pat = p.patrimoine;
    final prev = p.prevoyance;
    final det = p.dettes;
    final conjoint = p.conjoint;
    final cp = conjoint?.prevoyance;

    final prevCapital = (prev.avoirLppTotal ?? 0) +
        prev.totalEpargne3a +
        prev.totalLibrePassage;
    final conjointPrevCapital = (cp?.avoirLppTotal ?? 0) +
        (cp?.totalEpargne3a ?? 0) +
        (cp?.totalLibrePassage ?? 0);
    final patrimoineBrut = pat.epargneLiquide +
        pat.investissements +
        pat.immobilierEffectif +
        prevCapital +
        conjointPrevCapital;
    final patrimoineNet = patrimoineBrut - det.totalDettes;

    return CouplePatrimoineCard(
      firstName: p.firstName ?? S.of(context)!.financialSummaryToi,
      conjointFirstName: conjoint?.firstName,
      epargneLiquide: pat.epargneLiquide,
      investissements: pat.investissements,
      immobilierValeur: pat.immobilierEffectif,
      mortgageBalance: pat.mortgageBalance ?? 0,
      loanToValue: pat.loanToValue,
      propertyDescription: pat.propertyDescription,
      avoirLpp: prev.avoirLppTotal ?? 0,
      conjointAvoirLpp: cp?.avoirLppTotal ?? 0,
      capital3a: prev.totalEpargne3a,
      conjointCapital3a: cp?.totalEpargne3a ?? 0,
      librePassage: prev.totalLibrePassage,
      totalDettes: det.totalDettes,
      patrimoineBrut: patrimoineBrut,
      patrimoineNet: patrimoineNet,
      // Note: conjoint patrimoine (épargne/invest) not yet in ConjointProfile model.
      // partUser includes all user assets; partConjoint only prévoyance for now.
      partUser: prevCapital + pat.epargneLiquide + pat.investissements + pat.immobilierEffectif,
      partConjoint: conjointPrevCapital,
      conjointIsEstimated: conjoint?.invitationLevel != 'linked',
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  CONJOINT INVITATION — CTA for couple data sharing
  // ══════════════════════════════════════════════════════════════

  Widget _buildConjointInvitation(BuildContext context, CoachProfile p) {
    final conjoint = p.conjoint;
    if (conjoint == null) return const SizedBox.shrink();

    return ConjointInvitationCard(
      conjointFirstName: conjoint.firstName ?? S.of(context)!.financialSummaryConjointeDefault,
      invitationLevel: conjoint.invitationLevel,
      onInvite: () {
        // TODO: implement invite flow
      },
      onLink: () {
        // TODO: implement link flow
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  FUTUR PROJECTION — retirement income overview
  // ══════════════════════════════════════════════════════════════

  Widget _buildFuturProjection(BuildContext context, CoachProfile p) {
    final gross = p.revenuBrutAnnuel;
    if (gross <= 0) return const SizedBox.shrink();

    final breakdown = NetIncomeBreakdown.compute(
      grossSalary: gross,
      canton: p.canton.isNotEmpty ? p.canton : 'ZH',
      age: p.age,
    );

    final prev = p.prevoyance;
    final conjoint = p.conjoint;
    final cp = conjoint?.prevoyance;

    // Confidence score
    final knownCount = [
      p.salaireBrutMensuel > 0,
      p.canton.isNotEmpty,
      prev.avoirLppTotal != null && prev.avoirLppTotal! > 0,
      prev.totalEpargne3a > 0,
      p.patrimoine.epargneLiquide > 0,
      p.depenses.loyer > 0,
      p.depenses.assuranceMaladie > 0,
    ].where((b) => b).length;
    final confidence = (knownCount / 7 * 100).clamp(0.0, 100.0);

    return FuturProjectionCard(
      firstName: p.firstName ?? S.of(context)!.financialSummaryToi,
      conjointFirstName: p.isCouple ? conjoint?.firstName : null,
      ageRetraite: p.effectiveRetirementAge,
      conjointAgeRetraite: conjoint?.effectiveRetirementAge,
      renteAvsUser: prev.renteAVSEstimeeMensuelle ?? 0,
      renteAvsConjoint: p.isCouple ? (cp?.renteAVSEstimeeMensuelle ?? 0) : null,
      renteLppUser: (prev.avoirLppTotal ?? 0) * prev.tauxConversion / 12,
      renteLppConjoint: p.isCouple
          ? (cp?.avoirLppTotal ?? 0) * (cp?.tauxConversion ?? 0.068) / 12
          : null,
      capital3aUser: prev.totalEpargne3a,
      capital3aConjoint: p.isCouple ? (cp?.totalEpargne3a ?? 0) : null,
      capitalLibrePassage: prev.totalLibrePassage > 0 ? prev.totalLibrePassage : null,
      investissementsMarche: p.patrimoine.investissements > 0
          ? p.patrimoine.investissements
          : null,
      disposableActuel: breakdown.disposableIncome / 12,
      disposableCouple: p.isCouple && conjoint != null
          ? breakdown.disposableIncome / 12 +
              (conjoint.revenuBrutAnnuel > 0
                  ? NetIncomeBreakdown.compute(
                      grossSalary: conjoint.revenuBrutAnnuel,
                      canton: p.canton,
                      age: conjoint.age ?? 45,
                    ).disposableIncome / 12
                  : 0)
          : null,
      confidenceScore: confidence,
    );
  }

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
                  foregroundColor: Colors.white,
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
          salaireBrutMensuel: parseVal('salaireBrutMensuel'),
          avoirLppTotal: parseVal('avoirLppTotal'),
          nombre3a: parseVal('nombre3a')?.toInt(),
          totalEpargne3a: parseVal('totalEpargne3a'),
          rachatLppMensuel: parseVal('rachatLppMensuel'),
          epargneLiquide: parseVal('epargneLiquide'),
          investissements: parseVal('investissements'),
          loyer: parseVal('loyer'),
          assuranceMaladie: parseVal('assuranceMaladie'),
          electricite: parseVal('electricite'),
          transport: parseVal('transport'),
          telecom: parseVal('telecom'),
          fraisMedicaux: parseVal('fraisMedicaux'),
          autresDepensesFixes: parseVal('autresDepensesFixes'),
          hypotheque: parseVal('hypotheque'),
          creditConsommation: parseVal('creditConsommation'),
          leasing: parseVal('leasing'),
          autresDettes: parseVal('autresDettes'),
        );
  }

  // ═══════════════════════════════════════════════════════════════
  //  FRI RADAR CHART — proxy scores from profile completeness
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFriRadar(CoachProfile profile) {
    // Compute proxy FRI scores (0-25 each) from available profile data
    double liquidity = 5; // base
    if (profile.patrimoine.epargneLiquide > 0) {
      final months = profile.patrimoine.epargneLiquide /
          (profile.salaireBrutMensuel > 0 ? profile.salaireBrutMensuel : 5000);
      liquidity = (months / 6 * 25).clamp(0, 25); // 6 mois = 25/25
    }

    double fiscal = 5;
    final has3a = profile.prevoyance.totalEpargne3a > 0;
    final hasRachat = profile.totalLppBuybackMensuel > 0;
    if (has3a) fiscal += 12;
    if (hasRachat) fiscal += 8;
    fiscal = fiscal.clamp(0, 25);

    double retirement = 5;
    final hasLpp = profile.prevoyance.avoirLppTotal != null &&
        profile.prevoyance.avoirLppTotal! > 0;
    if (hasLpp) retirement += 15;
    if (has3a) retirement += 5;
    retirement = retirement.clamp(0, 25);

    double structural = 5;
    if (profile.dettes.hypotheque == null || profile.dettes.hypotheque == 0) {
      structural += 10;
    }
    if (profile.dettes.creditConsommation == null ||
        profile.dettes.creditConsommation == 0) {
      structural += 5;
    }
    if (profile.etatCivil == CoachCivilStatus.marie) structural += 5;
    structural = structural.clamp(0, 25);

    return FriRadarChart(
      liquidity: liquidity,
      fiscal: fiscal,
      retirement: retirement,
      structural: structural,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DATA QUALITY CARD — known vs missing fields
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDataQualityCard(BuildContext context, CoachProfile profile) {
    final known = <String>[];
    final missing = <String>[];

    void check(String label, bool isKnown) {
      if (isKnown) {
        known.add(label);
      } else {
        missing.add(label);
      }
    }

    final l10n = S.of(context)!;
    check(l10n.financialSummaryCheckSalaireBrut, profile.salaireBrutMensuel > 0);
    check(l10n.financialSummaryCheckCanton, profile.canton.isNotEmpty);
    check(l10n.financialSummaryCheckAvoirLpp, profile.prevoyance.avoirLppTotal != null &&
        profile.prevoyance.avoirLppTotal! > 0);
    check(l10n.financialSummaryCheckEpargne3a, profile.prevoyance.totalEpargne3a > 0);
    check(l10n.financialSummaryCheckEpargneLiquide, profile.patrimoine.epargneLiquide > 0);
    check(l10n.financialSummaryCheckLoyerHypotheque, profile.depenses.loyer > 0 ||
        (profile.dettes.hypotheque != null && profile.dettes.hypotheque! > 0));
    check(l10n.financialSummaryCheckAssuranceMaladie, profile.depenses.assuranceMaladie > 0);

    // S46: Enhanced 3-axis scoring with i18n labels
    final enhanced = ConfidenceScorer.scoreEnhanced(
      profile,
      labels: {
        'salaireBrutMensuel': l10n.confidenceLabelSalaire,
        'age': l10n.confidenceLabelAge,
        'canton': l10n.confidenceLabelCanton,
        'etatCivil': l10n.confidenceLabelMenage,
        'prevoyance.avoirLppTotal': l10n.confidenceLabelAvoirLpp,
        'prevoyance.tauxConversion': l10n.confidenceLabelTauxConversion,
        'prevoyance.anneesContribuees': l10n.confidenceLabelAnneesAvs,
        'prevoyance.totalEpargne3a': l10n.confidenceLabelEpargne3a,
        'patrimoine.epargneLiquide': l10n.confidenceLabelPatrimoine,
      },
      promptLabels: {
        'freshnessPrefix': l10n.confidencePromptFreshnessPrefix,
        'freshnessStale': l10n.confidencePromptFreshnessStale('{months}'),
        'freshnessConfirm': l10n.confidencePromptFreshnessConfirm,
        'accuracyPrefix': l10n.confidencePromptAccuracyPrefix,
        'accuracyEstimated': l10n.confidencePromptAccuracyEstimated,
        'accuracyCertificate': l10n.confidencePromptAccuracyCertificate,
      },
    );

    final impactPercent = missing.isEmpty
        ? null
        : '+${(missing.length * 10).clamp(5, 30)} % pr\u00e9cision';

    return DataQualityCard(
      knownFields: known,
      missingFields: missing,
      enrichImpact: impactPercent,
      completenessScore: enhanced.completeness,
      accuracyScore: enhanced.accuracy,
      freshnessScore: enhanced.freshness,
      combinedScore: enhanced.combined,
      onEnrich: missing.isEmpty
          ? null
          : () => context.push('/document-scan'),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  WHAT-IF STORIES — 3 micro-scenarios exploratoires
  // ═══════════════════════════════════════════════════════════════

  Widget _buildWhatIfStories(BuildContext context, CoachProfile profile) {
    final l10n = S.of(context)!;
    final avoirLpp = profile.prevoyance.avoirLppTotal ?? 0;
    final salary = profile.salaireBrutMensuel * profile.nombreDeMois;

    return WhatIfStoriesWidget(
      stories: [
        WhatIfStory(
          emoji: '\u{1F3E6}',
          question: l10n.financialSummaryWhatIf3aQuestion,
          monthlyImpactChf: 7258 / 12 * 0.30,
          explanation: l10n.financialSummaryWhatIf3aExplanation,
          actionLabel: l10n.financialSummaryWhatIf3aAction,
          route: '/simulator/3a',
        ),
        if (avoirLpp > 0)
          WhatIfStory(
            emoji: '\u{1F4C8}',
            question: l10n.financialSummaryWhatIfLppQuestion,
            monthlyImpactChf: avoirLpp * 0.02 / 12,
            explanation: l10n.financialSummaryWhatIfLppExplanation,
            actionLabel: l10n.financialSummaryWhatIfLppAction,
            route: '/arbitrage/rachat-vs-marche',
          ),
        WhatIfStory(
          emoji: '\u{1F3E0}',
          question: l10n.financialSummaryWhatIfAchatQuestion,
          monthlyImpactChf: salary > 0 ? salary * 0.005 / 12 : 50,
          explanation: l10n.financialSummaryWhatIfAchatExplanation,
          actionLabel: l10n.financialSummaryWhatIfAchatAction,
          route: '/arbitrage/location-vs-propriete',
        ),
      ],
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

