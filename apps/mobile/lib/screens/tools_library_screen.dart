import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Data model for a single tool entry.
class _ToolItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final Color color;

  const _ToolItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.color,
  });
}

/// Data model for a tool category.
class _ToolCategory {
  final IconData icon;
  final String title;
  final Color color;
  final List<_ToolItem> tools;

  const _ToolCategory({
    required this.icon,
    required this.title,
    required this.color,
    required this.tools,
  });
}

/// Complete tool discovery screen with categorized navigation to every feature.
///
/// Organized by 8 life-domain categories so users can discover all tools
/// within 2 taps from the home screen.
class ToolsLibraryScreen extends StatefulWidget {
  const ToolsLibraryScreen({super.key});

  @override
  State<ToolsLibraryScreen> createState() => _ToolsLibraryScreenState();
}

class _ToolsLibraryScreenState extends State<ToolsLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<int> _collapsedCategories = {};

  static List<_ToolCategory> _buildCategories(S? s) => [
    _ToolCategory(
      icon: Icons.elderly,
      title: s?.toolsCatPrevoyance ?? 'Prévoyance',
      color: MintColors.indigo,
      tools: [
        _ToolItem(
          icon: Icons.elderly,
          title: s?.toolsRetirementPlanner ?? 'Planificateur retraite',
          subtitle: s?.toolsRetirementPlannerDesc ?? 'Simule ta retraite AVS + LPP + 3a',
          route: '/retirement',
          color: MintColors.indigo,
        ),
        _ToolItem(
          icon: Icons.savings,
          title: s?.toolsSimulator3a ?? 'Simulateur 3a',
          subtitle: s?.toolsSimulator3aDesc ?? 'Calcule ton économie fiscale annuelle',
          route: '/simulator/3a',
          color: MintColors.categoryGreen,
        ),
        _ToolItem(
          icon: Icons.compare_arrows,
          title: s?.toolsComparator3a ?? 'Comparateur 3a',
          subtitle: s?.toolsComparator3aDesc ?? 'Compare les providers (banque vs assurance)',
          route: '/3a-deep/comparator',
          color: MintColors.cyan,
        ),
        _ToolItem(
          icon: Icons.percent,
          title: s?.toolsRealReturn3a ?? 'Rendement réel 3a',
          subtitle: s?.toolsRealReturn3aDesc ?? 'Rendement net après frais et inflation',
          route: '/3a-deep/real-return',
          color: MintColors.categoryPurple,
        ),
        _ToolItem(
          icon: Icons.stacked_line_chart,
          title: s?.toolsStaggeredWithdrawal3a ?? 'Retrait échelonné 3a',
          subtitle: s?.toolsStaggeredWithdrawal3aDesc ?? 'Optimise le retrait sur plusieurs années',
          route: '/3a-deep/staggered-withdrawal',
          color: MintColors.categoryMagenta,
        ),
        _ToolItem(
          icon: Icons.account_balance,
          title: s?.toolsRenteVsCapital ?? 'Rente vs Capital',
          subtitle: s?.toolsRenteVsCapitalDesc ?? 'Compare rente LPP et retrait du capital',
          route: '/arbitrage/rente-vs-capital',
          color: MintColors.indigo,
        ),
        _ToolItem(
          icon: Icons.trending_up,
          title: s?.toolsRachatLpp ?? 'Rachat échelonné LPP',
          subtitle: s?.toolsRachatLppDesc ?? 'Optimise tes rachats LPP sur plusieurs années',
          route: '/lpp-deep/rachat',
          color: MintColors.categoryGreen,
        ),
        _ToolItem(
          icon: Icons.swap_horiz,
          title: s?.toolsLibrePassage ?? 'Libre passage',
          subtitle: s?.toolsLibrePassageDesc ?? 'Checklist changement d\'emploi ou départ',
          route: '/lpp-deep/libre-passage',
          color: MintColors.categoryBlue,
        ),
        _ToolItem(
          icon: Icons.shield_outlined,
          title: s?.toolsDisabilityGap ?? 'Filet de sécurité',
          subtitle: s?.toolsDisabilityGapDesc ?? 'Simule ton gap invalidité/décès',
          route: '/simulator/disability-gap',
          color: MintColors.deepOrange,
        ),
        _ToolItem(
          icon: Icons.balance,
          title: s?.toolsGenderGap ?? 'Gender gap prévoyance',
          subtitle: s?.toolsGenderGapDesc ?? 'Impact du temps partiel sur ta retraite',
          route: '/segments/gender-gap',
          color: MintColors.violetDeep,
        ),
      ],
    ),
    _ToolCategory(
      icon: Icons.family_restroom,
      title: s?.toolsCatFamily ?? 'Famille',
      color: MintColors.categoryMagenta,
      tools: [
        _ToolItem(
          icon: Icons.favorite_outline,
          title: s?.toolsMarriage ?? 'Mariage & fiscalité',
          subtitle: s?.toolsMarriageDesc ?? 'Pénalité/bonus du mariage + régimes + survivant',
          route: '/mariage',
          color: MintColors.categoryMagenta,
        ),
        _ToolItem(
          icon: Icons.child_care,
          title: s?.toolsBirth ?? 'Naissance & famille',
          subtitle: s?.toolsBirthDesc ?? 'Congé parental, allocations, impact fiscal',
          route: '/naissance',
          color: MintColors.deepOrange,
        ),
        _ToolItem(
          icon: Icons.balance,
          title: s?.toolsConcubinage ?? 'Mariage vs Concubinage',
          subtitle: s?.toolsConcubinageDesc ?? 'Comparateur + checklist de protection',
          route: '/concubinage',
          color: MintColors.categoryPurple,
        ),
        _ToolItem(
          icon: Icons.family_restroom,
          title: s?.toolsDivorce ?? 'Simulateur divorce',
          subtitle: s?.toolsDivorceDesc ?? 'Impact financier du divorce sur la LPP',
          route: '/life-event/divorce',
          color: MintColors.violetDeep,
        ),
        _ToolItem(
          icon: Icons.volunteer_activism,
          title: s?.toolsSuccession ?? 'Simulateur succession',
          subtitle: s?.toolsSuccessionDesc ?? 'Calcule les parts légales et impôts',
          route: '/life-event/succession',
          color: MintColors.teal,
        ),
      ],
    ),
    _ToolCategory(
      icon: Icons.work_outline,
      title: s?.toolsCatEmployment ?? 'Emploi',
      color: MintColors.categoryAmber,
      tools: [
        _ToolItem(
          icon: Icons.school,
          title: s?.toolsFirstJob ?? 'Premier emploi',
          subtitle: s?.toolsFirstJobDesc ?? 'Comprends ta fiche de salaire et tes droits',
          route: '/first-job',
          color: MintColors.categoryBlue,
        ),
        _ToolItem(
          icon: Icons.work_off,
          title: s?.toolsUnemployment ?? 'Simulateur chômage',
          subtitle: s?.toolsUnemploymentDesc ?? 'Calcule tes indemnités et durée',
          route: '/unemployment',
          color: MintColors.crisisRed,
        ),
        _ToolItem(
          icon: Icons.swap_horiz,
          title: s?.toolsJobComparison ?? 'Comparateur d\'emploi',
          subtitle: s?.toolsJobComparisonDesc ?? 'Compare deux offres (net + LPP + avantages)',
          route: '/simulator/job-comparison',
          color: MintColors.categoryAmber,
        ),
        _ToolItem(
          icon: Icons.business_center,
          title: s?.toolsSelfEmployed ?? 'Indépendant',
          subtitle: s?.toolsSelfEmployedDesc ?? 'Couverture sociale et protection',
          route: '/segments/independant',
          color: MintColors.categoryAmber,
        ),
        _ToolItem(
          icon: Icons.receipt_long,
          title: s?.toolsAvsContributions ?? 'Cotisations AVS indép.',
          subtitle: s?.toolsAvsContributionsDesc ?? 'Calcule tes cotisations AVS/AI/APG',
          route: '/independants/avs',
          color: MintColors.categoryGreen,
        ),
        _ToolItem(
          icon: Icons.medical_services_outlined,
          title: s?.toolsIjm ?? 'Assurance IJM',
          subtitle: s?.toolsIjmDesc ?? 'Indemnité journalière maladie',
          route: '/independants/ijm',
          color: MintColors.cyan,
        ),
        _ToolItem(
          icon: Icons.savings,
          title: s?.tools3aSelfEmployed ?? '3a indépendant',
          subtitle: s?.tools3aSelfEmployedDesc ?? 'Plafond majoré pour indépendants',
          route: '/independants/3a',
          color: MintColors.categoryGreen,
        ),
        _ToolItem(
          icon: Icons.compare,
          title: s?.toolsDividendVsSalary ?? 'Dividende vs Salaire',
          subtitle: s?.toolsDividendVsSalaryDesc ?? 'Optimise ta rémunération en SA/Sàrl',
          route: '/independants/dividende-salaire',
          color: MintColors.categoryPurple,
        ),
        _ToolItem(
          icon: Icons.account_balance,
          title: s?.toolsLppVoluntary ?? 'LPP volontaire',
          subtitle: s?.toolsLppVoluntaryDesc ?? 'Prévoyance facultative pour indépendants',
          route: '/independants/lpp-volontaire',
          color: MintColors.indigo,
        ),
        _ToolItem(
          icon: Icons.language,
          title: s?.toolsCrossBorder ?? 'Frontalier',
          subtitle: s?.toolsCrossBorderDesc ?? 'Impôt source, 90 jours, charges sociales',
          route: '/segments/frontalier',
          color: MintColors.categoryBlue,
        ),
        _ToolItem(
          icon: Icons.flight_takeoff,
          title: s?.toolsExpatriation ?? 'Expatriation',
          subtitle: s?.toolsExpatriationDesc ?? 'Forfait fiscal, départ, lacunes AVS',
          route: '/expatriation',
          color: MintColors.categoryPurple,
        ),
      ],
    ),
    _ToolCategory(
      icon: Icons.house,
      title: s?.toolsCatRealEstate ?? 'Immobilier',
      color: MintColors.teal,
      tools: [
        _ToolItem(
          icon: Icons.house,
          title: s?.toolsAffordability ?? 'Capacité d\'achat',
          subtitle: s?.toolsAffordabilityDesc ?? 'Calcule le prix max que tu peux acheter',
          route: '/mortgage/affordability',
          color: MintColors.teal,
        ),
        _ToolItem(
          icon: Icons.schedule,
          title: s?.toolsAmortization ?? 'Plan d\'amortissement',
          subtitle: s?.toolsAmortizationDesc ?? 'Échéancier de remboursement hypothécaire',
          route: '/mortgage/amortization',
          color: MintColors.categoryBlue,
        ),
        _ToolItem(
          icon: Icons.compare_arrows,
          title: s?.toolsSaronVsFixed ?? 'SARON vs Fixe',
          subtitle: s?.toolsSaronVsFixedDesc ?? 'Compare les types d\'hypothèque',
          route: '/mortgage/saron-vs-fixed',
          color: MintColors.categoryPurple,
        ),
        _ToolItem(
          icon: Icons.home_work,
          title: s?.toolsImputedRental ?? 'Valeur locative',
          subtitle: s?.toolsImputedRentalDesc ?? 'Estime la valeur locative imputée',
          route: '/mortgage/imputed-rental',
          color: MintColors.categoryAmber,
        ),
        _ToolItem(
          icon: Icons.real_estate_agent,
          title: s?.toolsEplCombined ?? 'EPL combiné',
          subtitle: s?.toolsEplCombinedDesc ?? 'Retrait anticipé LPP + 3a pour logement',
          route: '/mortgage/epl-combined',
          color: MintColors.categoryGreen,
        ),
        _ToolItem(
          icon: Icons.home_outlined,
          title: s?.toolsEplLpp ?? 'Retrait EPL (LPP)',
          subtitle: s?.toolsEplLppDesc ?? 'Financer un logement avec ton 2e pilier',
          route: '/lpp-deep/epl',
          color: MintColors.teal,
        ),
      ],
    ),
    _ToolCategory(
      icon: Icons.receipt_long,
      title: s?.toolsCatTax ?? 'Fiscalité',
      color: MintColors.categoryGreen,
      tools: [
        _ToolItem(
          icon: Icons.balance,
          title: s?.toolsFiscalComparator ?? 'Comparateur fiscal',
          subtitle: s?.toolsFiscalComparatorDesc ?? 'Compare ta charge fiscale entre cantons',
          route: '/fiscal',
          color: MintColors.categoryGreen,
        ),
        _ToolItem(
          icon: Icons.trending_up,
          title: s?.toolsCompoundInterest ?? 'Intérêts composés',
          subtitle: s?.toolsCompoundInterestDesc ?? 'Visualise la croissance de ton épargne',
          route: '/simulator/compound',
          color: MintColors.indigo,
        ),
      ],
    ),
    _ToolCategory(
      icon: Icons.health_and_safety,
      title: s?.toolsCatHealth ?? 'Santé',
      color: MintColors.cyan,
      tools: [
        _ToolItem(
          icon: Icons.health_and_safety,
          title: s?.toolsLamalDeductible ?? 'Franchise LAMal',
          subtitle: s?.toolsLamalDeductibleDesc ?? 'Trouve la franchise idéale pour toi',
          route: '/assurances/lamal',
          color: MintColors.cyan,
        ),
        _ToolItem(
          icon: Icons.verified_user,
          title: s?.toolsCoverageCheckup ?? 'Check-up couverture',
          subtitle: s?.toolsCoverageCheckupDesc ?? 'Évalue ta protection assurantielle',
          route: '/assurances/coverage',
          color: MintColors.indigo,
        ),
      ],
    ),
    _ToolCategory(
      icon: Icons.account_balance_wallet,
      title: s?.toolsCatBudgetDebt ?? 'Budget & Dettes',
      color: MintColors.crisisRed,
      tools: [
        _ToolItem(
          icon: Icons.account_balance_wallet,
          title: s?.toolsBudget ?? 'Budget',
          subtitle: s?.toolsBudgetDesc ?? 'Planifie et suis tes dépenses mensuelles',
          route: '/budget',
          color: MintColors.categoryAmber,
        ),
        _ToolItem(
          icon: Icons.warning_amber,
          title: s?.toolsDebtCheck ?? 'Check dette',
          subtitle: s?.toolsDebtCheckDesc ?? 'Évalue ton risque de surendettement',
          route: '/check/debt',
          color: MintColors.crisisRed,
        ),
        _ToolItem(
          icon: Icons.pie_chart,
          title: s?.toolsDebtRatio ?? 'Ratio d\'endettement',
          subtitle: s?.toolsDebtRatioDesc ?? 'Diagnostic visuel de ta situation',
          route: '/debt/ratio',
          color: MintColors.deepOrange,
        ),
        _ToolItem(
          icon: Icons.payments,
          title: s?.toolsRepaymentPlan ?? 'Plan de remboursement',
          subtitle: s?.toolsRepaymentPlanDesc ?? 'Stratégie adaptée pour rembourser',
          route: '/debt/repayment',
          color: MintColors.categoryGreen,
        ),
        _ToolItem(
          icon: Icons.support_agent,
          title: s?.toolsDebtHelp ?? 'Aide et ressources',
          subtitle: s?.toolsDebtHelpDesc ?? 'Contacts et organismes de soutien',
          route: '/debt/help',
          color: MintColors.categoryBlue,
        ),
        _ToolItem(
          icon: Icons.credit_card,
          title: s?.toolsConsumerCredit ?? 'Crédit conso',
          subtitle: s?.toolsConsumerCreditDesc ?? 'Simule le coût réel d\'un crédit',
          route: '/simulator/credit',
          color: MintColors.categoryAmber,
        ),
        _ToolItem(
          icon: Icons.directions_car,
          title: s?.toolsLeasing ?? 'Calculateur leasing',
          subtitle: s?.toolsLeasingDesc ?? 'Coût réel et alternatives au leasing',
          route: '/simulator/leasing',
          color: MintColors.deepOrange,
        ),
      ],
    ),
    _ToolCategory(
      icon: Icons.account_balance,
      title: s?.toolsCatBankDocs ?? 'Banque & Documents',
      color: MintColors.categoryBlue,
      tools: [
        _ToolItem(
          icon: Icons.account_balance,
          title: s?.toolsOpenBanking ?? 'Open Banking',
          subtitle: s?.toolsOpenBankingDesc ?? 'Connecte tes comptes bancaires',
          route: '/open-banking',
          color: MintColors.teal,
        ),
        _ToolItem(
          icon: Icons.upload_file,
          title: s?.toolsBankImport ?? 'Import bancaire',
          subtitle: s?.toolsBankImportDesc ?? 'Importe tes relevés CSV/PDF',
          route: '/bank-import',
          color: MintColors.categoryBlue,
        ),
        _ToolItem(
          icon: Icons.description,
          title: s?.toolsDocuments ?? 'Mes documents',
          subtitle: s?.toolsDocumentsDesc ?? 'Certificats LPP et documents importants',
          route: '/documents',
          color: MintColors.indigo,
        ),
        _ToolItem(
          icon: Icons.pie_chart,
          title: s?.toolsPortfolio ?? 'Portfolio',
          subtitle: s?.toolsPortfolioDesc ?? 'Vue d\'ensemble de ta situation',
          route: '/portfolio',
          color: MintColors.categoryGreen,
        ),
        _ToolItem(
          icon: Icons.timeline,
          title: s?.toolsTimeline ?? 'Timeline',
          subtitle: s?.toolsTimelineDesc ?? 'Tes échéances et rappels importants',
          route: '/timeline',
          color: MintColors.categoryPurple,
        ),
        _ToolItem(
          icon: Icons.privacy_tip,
          title: s?.toolsConsent ?? 'Consentements',
          subtitle: s?.toolsConsentDesc ?? 'Gère tes autorisations de données',
          route: '/profile/consent',
          color: const Color(0xFF6B7280),
        ),
      ],
    ),
  ];

  List<_ToolCategory> get _effectiveCategories {
    final categories = _buildCategories(S.of(context));
    if (FeatureFlags.enableDecisionScaffold) return categories;

    return categories
        .map((category) {
          final tools = category.tools
              .where(
                (tool) =>
                    !tool.route.startsWith('/arbitrage/') &&
                    tool.route != '/simulator/rente-capital',
              )
              .toList();
          return _ToolCategory(
            icon: category.icon,
            title: category.title,
            color: category.color,
            tools: tools,
          );
        })
        .where((category) => category.tools.isNotEmpty)
        .toList();
  }

  List<_ToolCategory> get _filteredCategories {
    final baseCategories = _effectiveCategories;
    if (_searchQuery.isEmpty) return baseCategories;

    final query = _searchQuery.toLowerCase();
    final result = <_ToolCategory>[];

    for (final category in baseCategories) {
      final matchingTools = category.tools
          .where((tool) =>
              tool.title.toLowerCase().contains(query) ||
              tool.subtitle.toLowerCase().contains(query) ||
              category.title.toLowerCase().contains(query))
          .toList();

      if (matchingTools.isNotEmpty) {
        result.add(_ToolCategory(
          icon: category.icon,
          title: category.title,
          color: category.color,
          tools: matchingTools,
        ));
      }
    }
    return result;
  }

  int get _totalToolCount =>
      _effectiveCategories.fold(0, (sum, cat) => sum + cat.tools.length);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCategories;

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: MintColors.background,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              S.of(context)?.toolsAllTools ?? 'Tous les outils',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: MintColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _buildSearchBar(),
              ),
            ),
          ),

          // Stats header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: MintColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      S.of(context)?.toolsToolCount(_totalToolCount.toString()) ?? '$_totalToolCount outils',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MintColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: MintColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      S.of(context)?.toolsCategoryCount(_effectiveCategories.length.toString()) ?? '${_effectiveCategories.length} catégories',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: Text(
                        S.of(context)?.toolsClear ?? 'Effacer',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MintColors.info,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Category sections
          if (filtered.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyState())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final category = filtered[index];
                  final globalIndex = _effectiveCategories.indexOf(
                    _effectiveCategories.firstWhere(
                      (c) => c.title == category.title,
                    ),
                  );
                  return _buildCategorySection(
                      category, globalIndex, index == filtered.length - 1);
                },
                childCount: filtered.length,
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: GoogleFonts.inter(
          fontSize: 15,
          color: MintColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: S.of(context)?.toolsSearchHint ?? 'Chercher un outil...',
          hintStyle: GoogleFonts.inter(
            fontSize: 15,
            color: MintColors.textMuted,
          ),
          prefixIcon:
              const Icon(Icons.search, color: MintColors.textMuted, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close,
                      color: MintColors.textMuted, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          filled: false,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 48, color: MintColors.textMuted),
          const SizedBox(height: 16),
          Text(
            S.of(context)?.toolsNoResults ?? 'Aucun outil trouvé',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context)?.toolsNoResultsHint ?? 'Essaie avec d\'autres mots-clés',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
      _ToolCategory category, int globalIndex, bool isLast) {
    final isCollapsed = _collapsedCategories.contains(globalIndex);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, isLast ? 0 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          InkWell(
            onTap: () {
              setState(() {
                if (isCollapsed) {
                  _collapsedCategories.remove(globalIndex);
                } else {
                  _collapsedCategories.add(globalIndex);
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(category.icon, color: category.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category.title.toUpperCase(),
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: MintColors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: MintColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${category.tools.length}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isCollapsed ? -0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more,
                        color: MintColors.textMuted, size: 20),
                  ),
                ],
              ),
            ),
          ),

          // Tool cards
          AnimatedCrossFade(
            firstChild: Column(
              children: [
                for (int i = 0; i < category.tools.length; i++) ...[
                  _buildToolCard(category.tools[i]),
                  if (i < category.tools.length - 1) const SizedBox(height: 8),
                ],
                const SizedBox(height: 16),
              ],
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: isCollapsed
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(_ToolItem tool) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(tool.route),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.lightBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tool.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tool.icon, color: tool.color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tool.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textSecondary,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right,
                  color: MintColors.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
