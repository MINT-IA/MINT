import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

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

  static List<_ToolCategory> _buildCategories(S s) => [
    _ToolCategory(
      icon: Icons.elderly,
      title: s.toolsCatPrevoyance,
      color: MintColors.indigo,
      tools: [
        _ToolItem(
          icon: Icons.elderly,
          title: s.toolsRetirementPlanner,
          subtitle: s.toolsRetirementPlannerDesc,
          route: '/retraite',
          color: MintColors.indigo,
        ),
        _ToolItem(
          icon: Icons.savings,
          title: s.toolsSimulator3a,
          subtitle: s.toolsSimulator3aDesc,
          route: '/pilier-3a',
          color: MintColors.categoryGreen,
        ),
        _ToolItem(
          icon: Icons.compare_arrows,
          title: s.toolsComparator3a,
          subtitle: s.toolsComparator3aDesc,
          route: '/3a-deep/comparator',
          color: MintColors.cyan,
        ),
        _ToolItem(
          icon: Icons.percent,
          title: s.toolsRealReturn3a,
          subtitle: s.toolsRealReturn3aDesc,
          route: '/3a-deep/real-return',
          color: MintColors.categoryPurple,
        ),
        _ToolItem(
          icon: Icons.stacked_line_chart,
          title: s.toolsStaggeredWithdrawal3a,
          subtitle: s.toolsStaggeredWithdrawal3aDesc,
          route: '/3a-deep/staggered-withdrawal',
          color: MintColors.categoryMagenta,
        ),
        _ToolItem(
          icon: Icons.account_balance,
          title: s.toolsRenteVsCapital,
          subtitle: s.toolsRenteVsCapitalDesc,
          route: '/rente-vs-capital',
          color: MintColors.indigo,
        ),
        _ToolItem(
          icon: Icons.trending_up,
          title: s.toolsRachatLpp,
          subtitle: s.toolsRachatLppDesc,
          route: '/rachat-lpp',
          color: MintColors.categoryGreen,
        ),
        _ToolItem(
          icon: Icons.swap_horiz,
          title: s.toolsLibrePassage,
          subtitle: s.toolsLibrePassageDesc,
          route: '/libre-passage',
          color: MintColors.categoryBlue,
        ),
        _ToolItem(
          icon: Icons.shield_outlined,
          title: s.toolsDisabilityGap,
          subtitle: s.toolsDisabilityGapDesc,
          route: '/invalidite',
          color: MintColors.deepOrange,
        ),
        _ToolItem(
          icon: Icons.balance,
          title: s.toolsGenderGap,
          subtitle: s.toolsGenderGapDesc,
          route: '/segments/gender-gap',
          color: MintColors.violetDeep,
        ),
      ],
    ),
    _ToolCategory(
      icon: Icons.family_restroom,
      title: s.toolsCatFamily,
      color: MintColors.categoryMagenta,
      tools: [
        _ToolItem(
          icon: Icons.favorite_outline,
          title: s.toolsMarriage,
          subtitle: s.toolsMarriageDesc,
          route: '/mariage',
          color: MintColors.categoryMagenta,
        ),
        _ToolItem(
          icon: Icons.child_care,
          title: s.toolsBirth,
          subtitle: s.toolsBirthDesc,
          route: '/naissance',
          color: MintColors.deepOrange,
        ),
        _ToolItem(
          icon: Icons.balance,
          title: s.toolsConcubinage,
          subtitle: s.toolsConcubinageDesc,
          route: '/concubinage',
          color: MintColors.categoryPurple,
        ),
        _ToolItem(
          icon: Icons.family_restroom,
          title: s.toolsDivorce,
          subtitle: s.toolsDivorceDesc,
          route: '/divorce',
          color: MintColors.violetDeep,
        ),
        _ToolItem(
          icon: Icons.volunteer_activism,
          title: s.toolsSuccession,
          subtitle: s.toolsSuccessionDesc,
          route: '/succession',
          color: MintColors.teal,
        ),
      ],
    ),
    _ToolCategory(
      icon: Icons.work_outline,
      title: s.toolsCatEmployment,
      color: MintColors.categoryAmber,
      tools: [
        _ToolItem(
          icon: Icons.school,
          title: s.toolsFirstJob,
          subtitle: s.toolsFirstJobDesc,
          route: '/first-job',
          color: MintColors.categoryBlue,
        ),
        _ToolItem(
          icon: Icons.work_off,
          title: s.toolsUnemployment,
          subtitle: s.toolsUnemploymentDesc,
          route: '/unemployment',
          color: MintColors.crisisRed,
        ),
        _ToolItem(
          icon: Icons.swap_horiz,
          title: s.toolsJobComparison,
          subtitle: s.toolsJobComparisonDesc,
          route: '/simulator/job-comparison',
          color: MintColors.categoryAmber,
        ),
        _ToolItem(
          icon: Icons.business_center,
          title: s.toolsSelfEmployed,
          subtitle: s.toolsSelfEmployedDesc,
          route: '/segments/independant',
          color: MintColors.categoryAmber,
        ),
        _ToolItem(
          icon: Icons.receipt_long,
          title: s.toolsAvsContributions,
          subtitle: s.toolsAvsContributionsDesc,
          route: '/independants/avs',
          color: MintColors.categoryGreen,
        ),
        _ToolItem(
          icon: Icons.medical_services_outlined,
          title: s.toolsIjm,
          subtitle: s.toolsIjmDesc,
          route: '/independants/ijm',
          color: MintColors.cyan,
        ),
        _ToolItem(
          icon: Icons.savings,
          title: s.tools3aSelfEmployed,
          subtitle: s.tools3aSelfEmployedDesc,
          route: '/independants/3a',
          color: MintColors.categoryGreen,
        ),
        _ToolItem(
          icon: Icons.compare,
          title: s.toolsDividendVsSalary,
          subtitle: s.toolsDividendVsSalaryDesc,
          route: '/independants/dividende-salaire',
          color: MintColors.categoryPurple,
        ),
        _ToolItem(
          icon: Icons.account_balance,
          title: s.toolsLppVoluntary,
          subtitle: s.toolsLppVoluntaryDesc,
          route: '/independants/lpp-volontaire',
          color: MintColors.indigo,
        ),
        _ToolItem(
          icon: Icons.language,
          title: s.toolsCrossBorder,
          subtitle: s.toolsCrossBorderDesc,
          route: '/segments/frontalier',
          color: MintColors.categoryBlue,
        ),
        _ToolItem(
          icon: Icons.flight_takeoff,
          title: s.toolsExpatriation,
          subtitle: s.toolsExpatriationDesc,
          route: '/expatriation',
          color: MintColors.categoryPurple,
        ),
      ],
    ),
    _ToolCategory(
      icon: Icons.house,
      title: s.toolsCatRealEstate,
      color: MintColors.teal,
      tools: [
        _ToolItem(
          icon: Icons.house,
          title: s.toolsAffordability,
          subtitle: s.toolsAffordabilityDesc,
          route: '/hypotheque',
          color: MintColors.teal,
        ),
        _ToolItem(
          icon: Icons.schedule,
          title: s.toolsAmortization,
          subtitle: s.toolsAmortizationDesc,
          route: '/mortgage/amortization',
          color: MintColors.categoryBlue,
        ),
        _ToolItem(
          icon: Icons.compare_arrows,
          title: s.toolsSaronVsFixed,
          subtitle: s.toolsSaronVsFixedDesc,
          route: '/mortgage/saron-vs-fixed',
          color: MintColors.categoryPurple,
        ),
        _ToolItem(
          icon: Icons.home_work,
          title: s.toolsImputedRental,
          subtitle: s.toolsImputedRentalDesc,
          route: '/mortgage/imputed-rental',
          color: MintColors.categoryAmber,
        ),
        _ToolItem(
          icon: Icons.real_estate_agent,
          title: s.toolsEplCombined,
          subtitle: s.toolsEplCombinedDesc,
          route: '/mortgage/epl-combined',
          color: MintColors.categoryGreen,
        ),
        _ToolItem(
          icon: Icons.home_outlined,
          title: s.toolsEplLpp,
          subtitle: s.toolsEplLppDesc,
          route: '/epl',
          color: MintColors.teal,
        ),
      ],
    ),
    _ToolCategory(
      icon: Icons.receipt_long,
      title: s.toolsCatTax,
      color: MintColors.categoryGreen,
      tools: [
        _ToolItem(
          icon: Icons.balance,
          title: s.toolsFiscalComparator,
          subtitle: s.toolsFiscalComparatorDesc,
          route: '/fiscal',
          color: MintColors.categoryGreen,
        ),
        _ToolItem(
          icon: Icons.trending_up,
          title: s.toolsCompoundInterest,
          subtitle: s.toolsCompoundInterestDesc,
          route: '/simulator/compound',
          color: MintColors.indigo,
        ),
      ],
    ),
    _ToolCategory(
      icon: Icons.health_and_safety,
      title: s.toolsCatHealth,
      color: MintColors.cyan,
      tools: [
        _ToolItem(
          icon: Icons.health_and_safety,
          title: s.toolsLamalDeductible,
          subtitle: s.toolsLamalDeductibleDesc,
          route: '/assurances/lamal',
          color: MintColors.cyan,
        ),
        _ToolItem(
          icon: Icons.verified_user,
          title: s.toolsCoverageCheckup,
          subtitle: s.toolsCoverageCheckupDesc,
          route: '/assurances/coverage',
          color: MintColors.indigo,
        ),
      ],
    ),
    _ToolCategory(
      icon: Icons.account_balance_wallet,
      title: s.toolsCatBudgetDebt,
      color: MintColors.crisisRed,
      tools: [
        _ToolItem(
          icon: Icons.account_balance_wallet,
          title: s.toolsBudget,
          subtitle: s.toolsBudgetDesc,
          route: '/budget',
          color: MintColors.categoryAmber,
        ),
        _ToolItem(
          icon: Icons.warning_amber,
          title: s.toolsDebtCheck,
          subtitle: s.toolsDebtCheckDesc,
          route: '/check/debt',
          color: MintColors.crisisRed,
        ),
        _ToolItem(
          icon: Icons.pie_chart,
          title: s.toolsDebtRatio,
          subtitle: s.toolsDebtRatioDesc,
          route: '/debt/ratio',
          color: MintColors.deepOrange,
        ),
        _ToolItem(
          icon: Icons.payments,
          title: s.toolsRepaymentPlan,
          subtitle: s.toolsRepaymentPlanDesc,
          route: '/debt/repayment',
          color: MintColors.categoryGreen,
        ),
        _ToolItem(
          icon: Icons.support_agent,
          title: s.toolsDebtHelp,
          subtitle: s.toolsDebtHelpDesc,
          route: '/debt/help',
          color: MintColors.categoryBlue,
        ),
        _ToolItem(
          icon: Icons.credit_card,
          title: s.toolsConsumerCredit,
          subtitle: s.toolsConsumerCreditDesc,
          route: '/simulator/credit',
          color: MintColors.categoryAmber,
        ),
        _ToolItem(
          icon: Icons.directions_car,
          title: s.toolsLeasing,
          subtitle: s.toolsLeasingDesc,
          route: '/simulator/leasing',
          color: MintColors.deepOrange,
        ),
      ],
    ),
    _ToolCategory(
      icon: Icons.account_balance,
      title: s.toolsCatBankDocs,
      color: MintColors.categoryBlue,
      tools: [
        _ToolItem(
          icon: Icons.account_balance,
          title: s.toolsOpenBanking,
          subtitle: s.toolsOpenBankingDesc,
          route: '/open-banking',
          color: MintColors.teal,
        ),
        _ToolItem(
          icon: Icons.upload_file,
          title: s.toolsBankImport,
          subtitle: s.toolsBankImportDesc,
          route: '/bank-import',
          color: MintColors.categoryBlue,
        ),
        _ToolItem(
          icon: Icons.description,
          title: s.toolsDocuments,
          subtitle: s.toolsDocumentsDesc,
          route: '/documents',
          color: MintColors.indigo,
        ),
        _ToolItem(
          icon: Icons.pie_chart,
          title: s.toolsPortfolio,
          subtitle: s.toolsPortfolioDesc,
          route: '/portfolio',
          color: MintColors.categoryGreen,
        ),
        _ToolItem(
          icon: Icons.timeline,
          title: s.toolsTimeline,
          subtitle: s.toolsTimelineDesc,
          route: '/timeline',
          color: MintColors.categoryPurple,
        ),
        _ToolItem(
          icon: Icons.privacy_tip,
          title: s.toolsConsent,
          subtitle: s.toolsConsentDesc,
          route: '/profile/consent',
          color: MintColors.greyWarm,
        ),
      ],
    ),
  ];

  List<_ToolCategory> get _effectiveCategories {
    final categories = _buildCategories(S.of(context)!);
    if (FeatureFlags.enableDecisionScaffold) return categories;

    return categories
        .map((category) {
          final tools = category.tools
              .where(
                (tool) =>
                    !tool.route.startsWith('/arbitrage/') &&
                    tool.route != '/rente-vs-capital',
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
              onPressed: () => context.pop(),
            ),
            title: Text(
              S.of(context)!.toolsAllTools,
              style: MintTextStyles.headlineMedium().copyWith(
                fontSize: 18,
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
                  MintEntrance(child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: MintColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      S.of(context)!.toolsToolCount(_totalToolCount.toString()),
                      style: MintTextStyles.bodySmall(color: MintColors.primary).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )),
                  const SizedBox(width: 8),
                  MintEntrance(delay: Duration(milliseconds: 100), child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: MintColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      S.of(context)!.toolsCategoryCount(_effectiveCategories.length.toString()),
                      style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )),
                  if (_searchQuery.isNotEmpty) ...[
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: Text(
                        S.of(context)!.toolsClear,
                        style: MintTextStyles.bodySmall(color: MintColors.info).copyWith(
                          fontWeight: FontWeight.w600,
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
        style: MintTextStyles.bodyLarge(color: MintColors.textPrimary),
        decoration: InputDecoration(
          hintText: S.of(context)!.toolsSearchHint,
          hintStyle: MintTextStyles.bodyLarge(color: MintColors.textMuted),
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
            S.of(context)!.toolsNoResults,
            style: MintTextStyles.titleMedium(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            S.of(context)!.toolsNoResultsHint,
            style: MintTextStyles.bodyMedium(color: MintColors.textMuted),
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
          Semantics(
            label: '${category.title} - ${isCollapsed ? "déplier" : "replier"}',
            button: true,
            child: InkWell(
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
                      style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                      color: MintColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${category.tools.length}',
                      style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(
                        fontWeight: FontWeight.w600,
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
    return Semantics(
      label: tool.title,
      button: true,
      child: Material(
        color: MintColors.transparent,
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
                color: MintColors.black.withValues(alpha: 0.03),
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
                      style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tool.subtitle,
                      style: MintTextStyles.bodySmall().copyWith(height: 1.3),
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
    ),
    );
  }
}
