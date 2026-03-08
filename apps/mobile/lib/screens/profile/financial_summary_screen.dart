import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/services/smart_onboarding_draft_service.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/widgets/profile/financial_summary_card.dart';
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

  static final _chf = NumberFormat('#,##0', 'fr_CH');
  static final _pct = NumberFormat('0.0', 'fr_CH');

  String _formatChf(double? value) {
    if (value == null) return '\u2014';
    if (value == 0) return '0 CHF';
    return "${_chf.format(value)} CHF";
  }

  String _formatChfMonth(double? value) {
    if (value == null) return '\u2014';
    if (value == 0) return '0 CHF/mois';
    return "${_chf.format(value)} CHF/mois";
  }

  String _formatPct(double? value) {
    if (value == null) return '\u2014';
    return '${_pct.format(value * 100)}%';
  }

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
                      'Aucun profil renseigné',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: MintColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.push('/onboarding/smart'),
                      child: const Text('Commencer le diagnostic'),
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
                    _buildChiffreChocBanner(profile),
                    ChiffreChocSection(
                      profile: profile,
                      narratives: const {
                        'fiscalite':
                            'Chaque année sans maximiser ton 3a, c\'est de l\'argent que tu offres à l\'État. '
                            'Il n\'est pas trop tard pour rattraper.',
                        'prevoyance':
                            'Racheter ta lacune LPP, c\'est investir dans ta retraite tout en réduisant tes impôts. '
                            'Double bénéfice, zéro risque de marché.',
                        'avs':
                            'Chaque année manquante dans ton AVS réduit ta rente à vie. '
                            'Vérifier et combler ces lacunes est l\'une des meilleures décisions que tu puisses prendre.',
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildSourceLegend(),
                    const SizedBox(height: 16),

                    // ── FRI Radar Chart — santé financière en 4 axes ──
                    _buildFriRadar(profile),
                    const SizedBox(height: 16),

                    if (profile.isCouple) _buildCoupleToggle(context, profile),
                    _buildRevenusCard(context, profile),
                    _buildFiscaliteCard(context, profile),
                    _buildPrevoyanceCard(context, profile),
                    _buildPatrimoineCard(context, profile),
                    _buildDepensesCard(context, profile),
                    _buildDettesCard(context, profile),
                    if (profile.isCouple)
                      _buildCoupleCard(context, profile),
                    const SizedBox(height: 16),

                    // ── Data Quality Card — completude du profil ──
                    _buildDataQualityCard(context, profile),
                    const SizedBox(height: 16),

                    _buildDisclaimer(),
                    const SizedBox(height: 24),

                    // ── What-If Stories — scenarios exploratoires ──
                    _buildWhatIfStories(profile),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          context.read<CoachProfileProvider>().clear();
                          await ReportPersistenceService.clear();
                          await SmartOnboardingDraftService.clearDraft();
                          if (context.mounted) {
                            context.push('/onboarding/smart');
                          }
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(
                          'Recommencer le diagnostic',
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
          'APERÇU FINANCIER',
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

  Widget _buildSourceLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _legendItem('\u2713', 'saisi', MintColors.success),
          _legendItem('~', 'estimé', MintColors.warning),
          _legendItem('\u2B06', 'certifié', MintColors.info),
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

  Widget _buildCoupleToggle(BuildContext context, CoachProfile profile) {
    final conjoint = profile.conjoint;
    if (conjoint == null) return const SizedBox.shrink();
    final name1 = profile.firstName ?? 'Toi';
    final name2 = conjoint.firstName ?? 'Conjoint\u00b7e';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MintColors.coachBubble,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.people_outline, size: 18, color: MintColors.info),
            const SizedBox(width: 10),
            Text(
              'Couple : $name1 + $name2',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  REVENUS
  // ══════════════════════════════════════════════════════════════

  FinancialSummaryCard _buildRevenusCard(BuildContext context, CoachProfile p) {
    final lines = <FinancialLine>[
      FinancialLine(
        label: 'Salaire brut mensuel',
        formattedValue: _formatChfMonth(p.salaireBrutMensuel),
        source: _source(p, 'salaireBrutMensuel'),
      ),
      FinancialLine(
        label: '\u00d7 ${p.nombreDeMois} mois${p.bonusPourcentage != null && p.bonusPourcentage! > 0 ? " + ${_pct.format(p.bonusPourcentage)}% bonus" : ""}',
        formattedValue: '',
      ),
    ];

    // Conjoint
    if (p.isCouple && p.conjoint?.salaireBrutMensuel != null) {
      lines.add(FinancialLine(
        label: '${p.conjoint?.firstName ?? "Conjoint\u00b7e"} brut mensuel',
        formattedValue: _formatChfMonth(p.conjoint!.salaireBrutMensuel),
        source: _source(p, 'conjoint.salaireBrutMensuel'),
      ));
    }

    return FinancialSummaryCard(
      title: 'Revenus',
      icon: Icons.account_balance_wallet_outlined,
      iconColor: MintColors.primary,
      lines: lines,
      totalLine: FinancialLine(
        label: p.isCouple ? 'Total couple / an' : 'Total / an',
        formattedValue: _formatChf(
            p.isCouple ? p.revenuBrutAnnuelCouple : p.revenuBrutAnnuel),
      ),
      onEdit: () => _showEditSheet(
        context,
        title: 'Modifier le revenu',
        fields: [
          _EditField(
            label: 'Salaire brut mensuel (CHF)',
            initialValue: p.salaireBrutMensuel,
            key: 'salaireBrutMensuel',
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  FISCALITÉ (décomposition brut → net)
  // ══════════════════════════════════════════════════════════════

  Widget _buildFiscaliteCard(BuildContext context, CoachProfile p) {
    final gross = p.revenuBrutAnnuel;
    if (gross <= 0) {
      return const SizedBox.shrink();
    }

    final breakdown = NetIncomeBreakdown.compute(
      grossSalary: gross,
      canton: p.canton,
      age: p.age,
    );

    final lines = <FinancialLine>[
      FinancialLine(
        label: 'Charges sociales (AVS/AC)',
        formattedValue: _formatChfMonth(breakdown.socialCharges / 12),
      ),
      FinancialLine(
        label: 'Cotisation LPP employé·e',
        formattedValue: _formatChfMonth(breakdown.lppEmployee / 12),
      ),
      FinancialLine(
        label: 'Impôt sur le revenu',
        formattedValue: _formatChfMonth(breakdown.incomeTaxEstimate / 12),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinancialSummaryCard(
          title: 'Fiscalité',
          icon: Icons.receipt_long_outlined,
          iconColor: MintColors.warning,
          lines: lines,
          totalLine: FinancialLine(
            label: 'Net fiche de paie (avant impôt)',
            formattedValue: _formatChfMonth(breakdown.monthlyNetPayslip),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Estimation simplifiée. L\'AANP et l\'IJM varient selon l\'employeur '
            'et ne sont pas inclus. La LPP employé·e reflète le minimum légal '
            '(50/50) \u2014 ta caisse peut appliquer un autre split.',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Disponible après impôt : ${_formatChfMonth(breakdown.disposableIncome / 12)}',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: MintColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PRÉVOYANCE (AVS + LPP + 3a + Libre passage)
  // ══════════════════════════════════════════════════════════════

  FinancialSummaryCard _buildPrevoyanceCard(BuildContext context, CoachProfile p) {
    final prev = p.prevoyance;
    final lines = <FinancialLine>[];

    // --- AVS ---
    lines.add(const FinancialLine(
      label: 'AVS (1er pilier)',
      formattedValue: '',
    ));
    lines.add(FinancialLine(
      label: 'Années cotisées',
      formattedValue: prev.anneesContribuees != null
          ? '${prev.anneesContribuees} ans'
          : '\u2014',
      source: _source(p, 'prevoyance.anneesContribuees'),
      indent: true,
    ));
    if (prev.lacunesAVS != null && prev.lacunesAVS! > 0) {
      lines.add(FinancialLine(
        label: 'Lacunes',
        formattedValue: '${prev.lacunesAVS} ans',
        source: _source(p, 'prevoyance.lacunesAVS'),
        indent: true,
      ));
    }
    lines.add(FinancialLine(
      label: 'Rente estimée',
      formattedValue: prev.renteAVSEstimeeMensuelle != null
          ? _formatChfMonth(prev.renteAVSEstimeeMensuelle)
          : '\u2014',
      source: _source(p, 'prevoyance.renteAVSEstimeeMensuelle'),
      indent: true,
      isLast: true,
    ));

    // --- LPP ---
    lines.add(const FinancialLine(
      label: 'LPP (2e pilier)',
      formattedValue: '',
    ));
    lines.add(FinancialLine(
      label: 'Avoir total',
      formattedValue: _formatChf(prev.avoirLppTotal),
      source: _source(p, 'prevoyance.avoirLppTotal'),
      indent: true,
    ));
    if (prev.avoirLppObligatoire != null) {
      lines.add(FinancialLine(
        label: 'Obligatoire',
        formattedValue: _formatChf(prev.avoirLppObligatoire),
        indent: true,
      ));
    }
    if (prev.avoirLppSurobligatoire != null) {
      lines.add(FinancialLine(
        label: 'Surobligatoire',
        formattedValue: _formatChf(prev.avoirLppSurobligatoire),
        indent: true,
      ));
    }
    lines.add(FinancialLine(
      label: 'Taux de conversion',
      formattedValue: _formatPct(prev.tauxConversion),
      source: _source(p, 'prevoyance.tauxConversion'),
      indent: true,
    ));
    if (prev.lacuneRachatRestante > 0) {
      lines.add(FinancialLine(
        label: 'Rachat possible',
        formattedValue: _formatChf(prev.lacuneRachatRestante),
        indent: true,
      ));
    }
    if (p.totalLppBuybackMensuel > 0) {
      lines.add(FinancialLine(
        label: 'Rachat planifié',
        formattedValue: _formatChfMonth(p.totalLppBuybackMensuel),
        source: ProfileDataSource.userInput,
        indent: true,
      ));
    }
    if (prev.nomCaisse != null) {
      lines.add(FinancialLine(
        label: 'Caisse',
        formattedValue: prev.nomCaisse!,
        indent: true,
        isLast: true,
      ));
    }

    // --- 3a ---
    lines.add(const FinancialLine(
      label: '3a (3e pilier)',
      formattedValue: '',
    ));
    if (prev.comptes3a.isNotEmpty) {
      for (int i = 0; i < prev.comptes3a.length; i++) {
        final c = prev.comptes3a[i];
        lines.add(FinancialLine(
          label: c.provider,
          formattedValue: _formatChf(c.solde),
          indent: true,
          isLast: i == prev.comptes3a.length - 1 && prev.librePassage.isEmpty,
        ));
      }
    } else {
      lines.add(FinancialLine(
        label: '${prev.nombre3a} compte(s)',
        formattedValue: _formatChf(prev.totalEpargne3a),
        source: _source(p, 'prevoyance.totalEpargne3a'),
        indent: true,
        isLast: prev.librePassage.isEmpty,
      ));
    }

    // --- Libre passage ---
    if (prev.librePassage.isNotEmpty) {
      lines.add(const FinancialLine(
        label: 'Libre passage',
        formattedValue: '',
      ));
      for (int i = 0; i < prev.librePassage.length; i++) {
        final lp = prev.librePassage[i];
        lines.add(FinancialLine(
          label: lp.institution ?? 'Compte ${i + 1}',
          formattedValue: _formatChf(lp.solde),
          indent: true,
          isLast: i == prev.librePassage.length - 1,
        ));
      }
    }

    // Conjoint prévoyance summary
    if (p.isCouple && p.conjoint?.prevoyance != null) {
      final cp = p.conjoint!.prevoyance!;
      lines.add(FinancialLine(
        label: '${p.conjoint?.firstName ?? "Conjoint\u00b7e"} \u2014 LPP',
        formattedValue: _formatChf(cp.avoirLppTotal),
      ));
      if (cp.totalEpargne3a > 0) {
        lines.add(FinancialLine(
          label: '${p.conjoint?.firstName ?? "Conjoint\u00b7e"} \u2014 3a',
          formattedValue: _formatChf(cp.totalEpargne3a),
        ));
      }
      // FATCA warning: US citizens can use Raiffeisen but not VIAC/Finpension
      if (p.conjoint!.isFatcaResident) {
        lines.add(FinancialLine(
          label: '\u26a0\ufe0f FATCA \u2014 Seule une minorit\u00e9 de prestataires accepte (ex. Raiffeisen)',
          formattedValue: '',
          source: ProfileDataSource.estimated,
          indent: true,
        ));
      }
    }

    return FinancialSummaryCard(
      title: 'Prévoyance',
      icon: Icons.security_outlined,
      iconColor: MintColors.info,
      lines: lines,
      onScanCertificate: () => context.push('/document-scan'),
      scanLabel: 'Scanner certificat LPP / AVS',
      onEdit: () => _showEditSheet(
        context,
        title: 'Modifier la prévoyance',
        fields: [
          _EditField(
            label: 'Avoir LPP total (CHF)',
            initialValue: prev.avoirLppTotal,
            key: 'avoirLppTotal',
          ),
          _EditField(
            label: 'Total épargne 3a (CHF)',
            initialValue: prev.totalEpargne3a > 0 ? prev.totalEpargne3a : null,
            key: 'totalEpargne3a',
          ),
          _EditField(
            label: 'Rachat LPP mensuel prévu (CHF/mois)',
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
    return FinancialSummaryCard(
      title: 'Patrimoine',
      icon: Icons.savings_outlined,
      iconColor: MintColors.success,
      lines: [
        FinancialLine(
          label: 'Épargne liquide',
          formattedValue: _formatChf(pat.epargneLiquide),
          source: _source(p, 'patrimoine.epargneLiquide'),
        ),
        FinancialLine(
          label: 'Investissements',
          formattedValue: _formatChf(pat.investissements),
          source: _source(p, 'patrimoine.investissements'),
        ),
        if (pat.immobilier != null && pat.immobilier! > 0)
          FinancialLine(
            label: 'Immobilier (valeur)',
            formattedValue: _formatChf(pat.immobilier),
            source: _source(p, 'patrimoine.immobilier'),
          ),
      ],
      totalLine: FinancialLine(
        label: 'Total patrimoine',
        formattedValue: _formatChf(pat.totalPatrimoine),
      ),
      onEdit: () => _showEditSheet(
        context,
        title: 'Modifier le patrimoine',
        fields: [
          _EditField(
            label: 'Épargne liquide (CHF)',
            initialValue: pat.epargneLiquide > 0 ? pat.epargneLiquide : null,
            key: 'epargneLiquide',
          ),
          _EditField(
            label: 'Investissements (CHF)',
            initialValue:
                pat.investissements > 0 ? pat.investissements : null,
            key: 'investissements',
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

    if (dep.loyer > 0) {
      lines.add(FinancialLine(
        label: 'Loyer / charges',
        formattedValue: _formatChfMonth(dep.loyer),
        source: _source(p, 'depenses.loyer'),
      ));
    }
    if (dep.assuranceMaladie > 0) {
      lines.add(FinancialLine(
        label: 'Assurance maladie',
        formattedValue: _formatChfMonth(dep.assuranceMaladie),
        source: _source(p, 'depenses.assuranceMaladie'),
      ));
    }
    if (dep.electricite != null && dep.electricite! > 0) {
      lines.add(FinancialLine(
        label: 'Électricité / énergie',
        formattedValue: _formatChfMonth(dep.electricite),
        source: _source(p, 'depenses.electricite'),
      ));
    }
    if (dep.transport != null && dep.transport! > 0) {
      lines.add(FinancialLine(
        label: 'Transport',
        formattedValue: _formatChfMonth(dep.transport),
        source: _source(p, 'depenses.transport'),
      ));
    }
    if (dep.telecom != null && dep.telecom! > 0) {
      lines.add(FinancialLine(
        label: 'Télécom',
        formattedValue: _formatChfMonth(dep.telecom),
        source: _source(p, 'depenses.telecom'),
      ));
    }
    if (dep.fraisMedicaux != null && dep.fraisMedicaux! > 0) {
      lines.add(FinancialLine(
        label: 'Frais médicaux',
        formattedValue: _formatChfMonth(dep.fraisMedicaux),
        source: _source(p, 'depenses.fraisMedicaux'),
      ));
    }
    if (dep.autresDepensesFixes != null && dep.autresDepensesFixes! > 0) {
      lines.add(FinancialLine(
        label: 'Autres frais fixes',
        formattedValue: _formatChfMonth(dep.autresDepensesFixes),
        source: _source(p, 'depenses.autresDepensesFixes'),
      ));
    }

    if (lines.isEmpty) {
      lines.add(const FinancialLine(
        label: 'Aucune dépense renseignée',
        formattedValue: '\u2014',
      ));
    }

    return FinancialSummaryCard(
      title: 'Dépenses fixes',
      icon: Icons.receipt_long_outlined,
      iconColor: MintColors.warning,
      lines: lines,
      totalLine: dep.totalMensuel > 0
          ? FinancialLine(
              label: 'Total mensuel',
              formattedValue: _formatChfMonth(dep.totalMensuel),
            )
          : null,
      onEdit: () => _showEditSheet(
        context,
        title: 'Modifier les dépenses',
        fields: [
          _EditField(
            label: 'Loyer / charges (CHF/mois)',
            initialValue: dep.loyer > 0 ? dep.loyer : null,
            key: 'loyer',
          ),
          _EditField(
            label: 'Assurance maladie (CHF/mois)',
            initialValue: dep.assuranceMaladie > 0 ? dep.assuranceMaladie : null,
            key: 'assuranceMaladie',
          ),
          _EditField(
            label: 'Électricité / énergie (CHF/mois)',
            initialValue: dep.electricite,
            key: 'electricite',
          ),
          _EditField(
            label: 'Transport (CHF/mois)',
            initialValue: dep.transport,
            key: 'transport',
          ),
          _EditField(
            label: 'Télécom (CHF/mois)',
            initialValue: dep.telecom,
            key: 'telecom',
          ),
          _EditField(
            label: 'Frais médicaux (CHF/mois)',
            initialValue: dep.fraisMedicaux,
            key: 'fraisMedicaux',
          ),
          _EditField(
            label: 'Autres frais fixes (CHF/mois)',
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
    if (!det.hasDette) {
      return FinancialSummaryCard(
        title: 'Dettes',
        icon: Icons.credit_card_outlined,
        iconColor: MintColors.textMuted,
        lines: const [
          FinancialLine(
            label: 'Aucune dette déclarée',
            formattedValue: '\u2014',
          ),
        ],
        onEdit: () => _showEditSheet(
          context,
          title: 'Modifier les dettes',
          fields: [
            const _EditField(label: 'Hypothèque (CHF)', key: 'hypotheque'),
            const _EditField(
                label: 'Crédit consommation (CHF)', key: 'creditConsommation'),
            const _EditField(label: 'Leasing (CHF)', key: 'leasing'),
            const _EditField(label: 'Autres dettes (CHF)', key: 'autresDettes'),
          ],
        ),
      );
    }

    final lines = <FinancialLine>[];
    if (det.hypotheque != null && det.hypotheque! > 0) {
      lines.add(FinancialLine(
        label: 'Hypothèque',
        formattedValue: _formatChf(det.hypotheque),
        source: _source(p, 'dettes.hypotheque'),
      ));
    }
    if (det.leasing != null && det.leasing! > 0) {
      lines.add(FinancialLine(
        label: 'Leasing',
        formattedValue: _formatChf(det.leasing),
        source: _source(p, 'dettes.leasing'),
      ));
    }
    if (det.creditConsommation != null && det.creditConsommation! > 0) {
      lines.add(FinancialLine(
        label: 'Crédit consommation',
        formattedValue: _formatChf(det.creditConsommation),
        source: _source(p, 'dettes.creditConsommation'),
      ));
    }
    if (det.autresDettes != null && det.autresDettes! > 0) {
      lines.add(FinancialLine(
        label: 'Autres dettes',
        formattedValue: _formatChf(det.autresDettes),
        source: _source(p, 'dettes.autresDettes'),
      ));
    }

    return FinancialSummaryCard(
      title: 'Dettes',
      icon: Icons.credit_card_outlined,
      iconColor: MintColors.error,
      lines: lines,
      totalLine: FinancialLine(
        label: 'Total dettes',
        formattedValue: _formatChf(det.totalDettes),
      ),
      onEdit: () => _showEditSheet(
        context,
        title: 'Modifier les dettes',
        fields: [
          _EditField(
            label: 'Hypothèque (CHF)',
            initialValue: det.hypotheque,
            key: 'hypotheque',
          ),
          _EditField(
            label: 'Crédit consommation (CHF)',
            initialValue: det.creditConsommation,
            key: 'creditConsommation',
          ),
          _EditField(
            label: 'Leasing (CHF)',
            initialValue: det.leasing,
            key: 'leasing',
          ),
          _EditField(
            label: 'Autres dettes (CHF)',
            initialValue: det.autresDettes,
            key: 'autresDettes',
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  COUPLE (edit shortcut)
  // ══════════════════════════════════════════════════════════════

  FinancialSummaryCard _buildCoupleCard(BuildContext context, CoachProfile p) {
    final conjoint = p.conjoint;
    final lines = <FinancialLine>[];
    if (conjoint != null) {
      lines.add(FinancialLine(
        label: conjoint.firstName ?? 'Conjoint\u00b7e',
        formattedValue: conjoint.age != null ? '${conjoint.age} ans' : '\u2014',
      ));
      if (conjoint.salaireBrutMensuel != null) {
        lines.add(FinancialLine(
          label: 'Salaire brut mensuel',
          formattedValue: _formatChfMonth(conjoint.salaireBrutMensuel),
          indent: true,
        ));
      }
    }
    if (lines.isEmpty) {
      lines.add(const FinancialLine(
        label: 'Aucune donnée conjoint\u00b7e',
        formattedValue: '\u2014',
      ));
    }
    return FinancialSummaryCard(
      title: 'Couple',
      icon: Icons.people_outline,
      iconColor: MintColors.info,
      lines: lines,
      onEdit: () => context.push('/data-block/couple'),  // Couple edit: separate flow
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Text(
        'Outil éducatif \u2014 ne constitue pas un conseil financier (LSFin, LAVS, LPP, LIFD). '
        'Les valeurs estimées (~) sont calculées à partir de moyennes suisses. '
        'Scanne tes certificats pour affiner la précision de tes projections.',
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
        text: f.initialValue != null ? _chf.format(f.initialValue!) : '',
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
                  'Enregistrer',
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

    check('Salaire brut', profile.salaireBrutMensuel > 0);
    check('Canton', profile.canton.isNotEmpty);
    check('Avoir LPP', profile.prevoyance.avoirLppTotal != null &&
        profile.prevoyance.avoirLppTotal! > 0);
    check('Epargne 3a', profile.prevoyance.totalEpargne3a > 0);
    check('Epargne liquide', profile.patrimoine.epargneLiquide > 0);
    check('Loyer / hypotheque', profile.depenses.loyer > 0 ||
        (profile.dettes.hypotheque != null && profile.dettes.hypotheque! > 0));
    check('Assurance maladie', profile.depenses.assuranceMaladie > 0);

    final impactPercent = missing.isEmpty
        ? null
        : '+${(missing.length * 10).clamp(5, 30)} % precision';

    return DataQualityCard(
      knownFields: known,
      missingFields: missing,
      enrichImpact: impactPercent,
      onEnrich: missing.isEmpty
          ? null
          : () => context.push('/onboarding/smart'),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  WHAT-IF STORIES — 3 micro-scenarios exploratoires
  // ═══════════════════════════════════════════════════════════════

  Widget _buildWhatIfStories(CoachProfile profile) {
    final avoirLpp = profile.prevoyance.avoirLppTotal ?? 0;
    final salary = profile.salaireBrutMensuel * profile.nombreDeMois;

    return WhatIfStoriesWidget(
      stories: [
        WhatIfStory(
          emoji: '\u{1F3E6}',
          question: 'Et si tu maximisais ton 3a chaque annee ?',
          monthlyImpactChf: 7258 / 12 * 0.30,
          explanation: 'A ton taux marginal, chaque franc verse en 3a te fait '
              'economiser ~30 % d\'impots.',
          actionLabel: 'Simuler',
        ),
        if (avoirLpp > 0)
          WhatIfStory(
            emoji: '\u{1F4C8}',
            question: 'Et si ta caisse LPP passait de 1 % a 3 % ?',
            monthlyImpactChf: avoirLpp * 0.02 / 12,
            explanation: 'Un meilleur rendement LPP augmente ton capital '
                'a la retraite sans effort de ta part.',
            actionLabel: 'Comparer',
          ),
        WhatIfStory(
          emoji: '\u{1F3E0}',
          question: 'Et si tu achetais au lieu de louer ?',
          monthlyImpactChf: salary > 0 ? salary * 0.005 / 12 : 50,
          explanation: 'L\'amortissement indirect via le 2e pilier peut '
              'reduire tes impots tout en constituant un patrimoine.',
          actionLabel: 'Explorer',
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
