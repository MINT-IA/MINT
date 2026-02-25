import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
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

  static final List<_ToolCategory> _categories = [
    _ToolCategory(
      icon: Icons.elderly,
      title: 'Prevoyance',
      color: const Color(0xFF4F46E5),
      tools: [
        _ToolItem(
          icon: Icons.elderly,
          title: 'Planificateur retraite',
          subtitle: 'Simule ta retraite AVS + LPP + 3a',
          route: '/retirement',
          color: const Color(0xFF4F46E5),
        ),
        _ToolItem(
          icon: Icons.savings,
          title: 'Simulateur 3a',
          subtitle: 'Calcule ton economie fiscale annuelle',
          route: '/simulator/3a',
          color: const Color(0xFF059669),
        ),
        _ToolItem(
          icon: Icons.compare_arrows,
          title: 'Comparateur 3a',
          subtitle: 'Compare les providers (banque vs assurance)',
          route: '/3a-deep/comparator',
          color: const Color(0xFF0891B2),
        ),
        _ToolItem(
          icon: Icons.percent,
          title: 'Rendement reel 3a',
          subtitle: 'Rendement net apres frais et inflation',
          route: '/3a-deep/real-return',
          color: const Color(0xFF7C3AED),
        ),
        _ToolItem(
          icon: Icons.stacked_line_chart,
          title: 'Retrait echelonne 3a',
          subtitle: 'Optimise le retrait sur plusieurs annees',
          route: '/3a-deep/staggered-withdrawal',
          color: const Color(0xFFDB2777),
        ),
        _ToolItem(
          icon: Icons.account_balance,
          title: 'Rente vs Capital',
          subtitle: 'Compare rente LPP et retrait du capital',
          route: '/simulator/rente-capital',
          color: const Color(0xFF4F46E5),
        ),
        _ToolItem(
          icon: Icons.trending_up,
          title: 'Rachat echelonne LPP',
          subtitle: 'Optimise tes rachats LPP sur plusieurs annees',
          route: '/lpp-deep/rachat',
          color: const Color(0xFF059669),
        ),
        _ToolItem(
          icon: Icons.swap_horiz,
          title: 'Libre passage',
          subtitle: 'Checklist changement d\'emploi ou depart',
          route: '/lpp-deep/libre-passage',
          color: const Color(0xFF2563EB),
        ),
        _ToolItem(
          icon: Icons.shield_outlined,
          title: 'Filet de securite',
          subtitle: 'Simule ton gap invalidite/deces',
          route: '/simulator/disability-gap',
          color: const Color(0xFFEA580C),
        ),
        _ToolItem(
          icon: Icons.balance,
          title: 'Gender gap prevoyance',
          subtitle: 'Impact du temps partiel sur ta retraite',
          route: '/segments/gender-gap',
          color: const Color(0xFF9333EA),
        ),
      ],
    ),
    _ToolCategory(
      icon: Icons.family_restroom,
      title: 'Famille',
      color: const Color(0xFFDB2777),
      tools: [
        _ToolItem(
          icon: Icons.favorite_outline,
          title: 'Mariage & fiscalite',
          subtitle: 'Penalite/bonus du mariage + regimes + survivant',
          route: '/mariage',
          color: const Color(0xFFDB2777),
        ),
        _ToolItem(
          icon: Icons.child_care,
          title: 'Naissance & famille',
          subtitle: 'Conge parental, allocations, impact fiscal',
          route: '/naissance',
          color: const Color(0xFFEA580C),
        ),
        _ToolItem(
          icon: Icons.balance,
          title: 'Mariage vs Concubinage',
          subtitle: 'Comparateur + checklist de protection',
          route: '/concubinage',
          color: const Color(0xFF7C3AED),
        ),
        _ToolItem(
          icon: Icons.family_restroom,
          title: 'Simulateur divorce',
          subtitle: 'Impact financier du divorce sur la LPP',
          route: '/life-event/divorce',
          color: const Color(0xFF9333EA),
        ),
        _ToolItem(
          icon: Icons.volunteer_activism,
          title: 'Simulateur succession',
          subtitle: 'Calcule les parts legales et impots',
          route: '/life-event/succession',
          color: const Color(0xFF0D9488),
        ),
      ],
    ),
    _ToolCategory(
      icon: Icons.work_outline,
      title: 'Emploi',
      color: const Color(0xFFD97706),
      tools: [
        _ToolItem(
          icon: Icons.school,
          title: 'Premier emploi',
          subtitle: 'Comprends ta fiche de salaire et tes droits',
          route: '/first-job',
          color: const Color(0xFF2563EB),
        ),
        _ToolItem(
          icon: Icons.work_off,
          title: 'Simulateur chomage',
          subtitle: 'Calcule tes indemnites et duree',
          route: '/unemployment',
          color: const Color(0xFFDC2626),
        ),
        _ToolItem(
          icon: Icons.swap_horiz,
          title: 'Comparateur d\'emploi',
          subtitle: 'Compare deux offres (net + LPP + avantages)',
          route: '/simulator/job-comparison',
          color: const Color(0xFFD97706),
        ),
        _ToolItem(
          icon: Icons.business_center,
          title: 'Independant',
          subtitle: 'Couverture sociale et protection',
          route: '/segments/independant',
          color: const Color(0xFFD97706),
        ),
        _ToolItem(
          icon: Icons.receipt_long,
          title: 'Cotisations AVS indep.',
          subtitle: 'Calcule tes cotisations AVS/AI/APG',
          route: '/independants/avs',
          color: const Color(0xFF059669),
        ),
        _ToolItem(
          icon: Icons.medical_services_outlined,
          title: 'Assurance IJM',
          subtitle: 'Indemnite journaliere maladie',
          route: '/independants/ijm',
          color: const Color(0xFF0891B2),
        ),
        _ToolItem(
          icon: Icons.savings,
          title: '3a independant',
          subtitle: 'Plafond majore pour independants',
          route: '/independants/3a',
          color: const Color(0xFF059669),
        ),
        _ToolItem(
          icon: Icons.compare,
          title: 'Dividende vs Salaire',
          subtitle: 'Optimise ta remuneration en SA/Sarl',
          route: '/independants/dividende-salaire',
          color: const Color(0xFF7C3AED),
        ),
        _ToolItem(
          icon: Icons.account_balance,
          title: 'LPP volontaire',
          subtitle: 'Prevoyance facultative pour independants',
          route: '/independants/lpp-volontaire',
          color: const Color(0xFF4F46E5),
        ),
        _ToolItem(
          icon: Icons.language,
          title: 'Frontalier',
          subtitle: 'Impot source, 90 jours, charges sociales',
          route: '/segments/frontalier',
          color: const Color(0xFF2563EB),
        ),
        _ToolItem(
          icon: Icons.flight_takeoff,
          title: 'Expatriation',
          subtitle: 'Forfait fiscal, depart, lacunes AVS',
          route: '/expatriation',
          color: const Color(0xFF7C3AED),
        ),
      ],
    ),
    _ToolCategory(
      icon: Icons.house,
      title: 'Immobilier',
      color: const Color(0xFF0D9488),
      tools: [
        _ToolItem(
          icon: Icons.house,
          title: 'Capacite d\'achat',
          subtitle: 'Calcule le prix max que tu peux acheter',
          route: '/mortgage/affordability',
          color: const Color(0xFF0D9488),
        ),
        _ToolItem(
          icon: Icons.schedule,
          title: 'Plan d\'amortissement',
          subtitle: 'Echeancier de remboursement hypothecaire',
          route: '/mortgage/amortization',
          color: const Color(0xFF2563EB),
        ),
        _ToolItem(
          icon: Icons.compare_arrows,
          title: 'SARON vs Fixe',
          subtitle: 'Compare les types d\'hypotheque',
          route: '/mortgage/saron-vs-fixed',
          color: const Color(0xFF7C3AED),
        ),
        _ToolItem(
          icon: Icons.home_work,
          title: 'Valeur locative',
          subtitle: 'Estime la valeur locative imputee',
          route: '/mortgage/imputed-rental',
          color: const Color(0xFFD97706),
        ),
        _ToolItem(
          icon: Icons.real_estate_agent,
          title: 'EPL combine',
          subtitle: 'Retrait anticipe LPP + 3a pour logement',
          route: '/mortgage/epl-combined',
          color: const Color(0xFF059669),
        ),
        _ToolItem(
          icon: Icons.home_outlined,
          title: 'Retrait EPL (LPP)',
          subtitle: 'Financer un logement avec ton 2e pilier',
          route: '/lpp-deep/epl',
          color: const Color(0xFF0D9488),
        ),
      ],
    ),
    _ToolCategory(
      icon: Icons.receipt_long,
      title: 'Fiscalite',
      color: const Color(0xFF059669),
      tools: [
        _ToolItem(
          icon: Icons.balance,
          title: 'Comparateur fiscal',
          subtitle: 'Compare ta charge fiscale entre cantons',
          route: '/fiscal',
          color: const Color(0xFF059669),
        ),
        _ToolItem(
          icon: Icons.trending_up,
          title: 'Interets composes',
          subtitle: 'Visualise la croissance de ton epargne',
          route: '/simulator/compound',
          color: const Color(0xFF4F46E5),
        ),
      ],
    ),
    _ToolCategory(
      icon: Icons.health_and_safety,
      title: 'Sante',
      color: const Color(0xFF0891B2),
      tools: [
        _ToolItem(
          icon: Icons.health_and_safety,
          title: 'Franchise LAMal',
          subtitle: 'Trouve la franchise ideale pour toi',
          route: '/assurances/lamal',
          color: const Color(0xFF0891B2),
        ),
        _ToolItem(
          icon: Icons.verified_user,
          title: 'Check-up couverture',
          subtitle: 'Evalue ta protection assurantielle',
          route: '/assurances/coverage',
          color: const Color(0xFF4F46E5),
        ),
      ],
    ),
    _ToolCategory(
      icon: Icons.account_balance_wallet,
      title: 'Budget & Dettes',
      color: const Color(0xFFDC2626),
      tools: [
        _ToolItem(
          icon: Icons.account_balance_wallet,
          title: 'Budget',
          subtitle: 'Planifie et suis tes depenses mensuelles',
          route: '/budget',
          color: const Color(0xFFD97706),
        ),
        _ToolItem(
          icon: Icons.warning_amber,
          title: 'Check dette',
          subtitle: 'Evalue ton risque de surendettement',
          route: '/check/debt',
          color: const Color(0xFFDC2626),
        ),
        _ToolItem(
          icon: Icons.pie_chart,
          title: 'Ratio d\'endettement',
          subtitle: 'Diagnostic visuel de ta situation',
          route: '/debt/ratio',
          color: const Color(0xFFEA580C),
        ),
        _ToolItem(
          icon: Icons.payments,
          title: 'Plan de remboursement',
          subtitle: 'Strategie optimale pour rembourser',
          route: '/debt/repayment',
          color: const Color(0xFF059669),
        ),
        _ToolItem(
          icon: Icons.support_agent,
          title: 'Aide et ressources',
          subtitle: 'Contacts et organismes de soutien',
          route: '/debt/help',
          color: const Color(0xFF2563EB),
        ),
        _ToolItem(
          icon: Icons.credit_card,
          title: 'Credit conso',
          subtitle: 'Simule le cout reel d\'un credit',
          route: '/simulator/credit',
          color: const Color(0xFFD97706),
        ),
        _ToolItem(
          icon: Icons.directions_car,
          title: 'Calculateur leasing',
          subtitle: 'Cout reel et alternatives au leasing',
          route: '/simulator/leasing',
          color: const Color(0xFFEA580C),
        ),
      ],
    ),
    _ToolCategory(
      icon: Icons.account_balance,
      title: 'Banque & Documents',
      color: const Color(0xFF2563EB),
      tools: [
        _ToolItem(
          icon: Icons.account_balance,
          title: 'Open Banking',
          subtitle: 'Connecte tes comptes bancaires',
          route: '/open-banking',
          color: const Color(0xFF0D9488),
        ),
        _ToolItem(
          icon: Icons.upload_file,
          title: 'Import bancaire',
          subtitle: 'Importe tes releves CSV/PDF',
          route: '/bank-import',
          color: const Color(0xFF2563EB),
        ),
        _ToolItem(
          icon: Icons.description,
          title: 'Mes documents',
          subtitle: 'Certificats LPP et documents importants',
          route: '/documents',
          color: const Color(0xFF4F46E5),
        ),
        _ToolItem(
          icon: Icons.pie_chart,
          title: 'Portfolio',
          subtitle: 'Vue d\'ensemble de ta situation',
          route: '/portfolio',
          color: const Color(0xFF059669),
        ),
        _ToolItem(
          icon: Icons.timeline,
          title: 'Timeline',
          subtitle: 'Tes echeances et rappels importants',
          route: '/timeline',
          color: const Color(0xFF7C3AED),
        ),
        _ToolItem(
          icon: Icons.privacy_tip,
          title: 'Consentements',
          subtitle: 'Gere tes autorisations de donnees',
          route: '/profile/consent',
          color: const Color(0xFF6B7280),
        ),
      ],
    ),
  ];

  List<_ToolCategory> get _filteredCategories {
    if (_searchQuery.isEmpty) return _categories;

    final query = _searchQuery.toLowerCase();
    final result = <_ToolCategory>[];

    for (final category in _categories) {
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
      _categories.fold(0, (sum, cat) => sum + cat.tools.length);

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
              'Tous les outils',
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: MintColors.primary.withValues(alpha: 0.08),
                      borderRadius: const Borderconst Radius.circular(8),
                    ),
                    child: Text(
                      '$_totalToolCount outils',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MintColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: MintColors.surface,
                      borderRadius: const Borderconst Radius.circular(8),
                    ),
                    child: Text(
                      '${_categories.length} categories',
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
                        'Effacer',
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
                  final globalIndex = _categories.indexOf(
                    _categories.firstWhere((c) => c.title == category.title),
                  );
                  return _buildCategorySection(
                      category, globalIndex, index == filtered.length - 1);
                },
                childCount: filtered.length,
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: const SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: const Borderconst Radius.circular(16),
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
          hintText: 'Chercher un outil...',
          hintStyle: GoogleFonts.inter(
            fontSize: 15,
            color: MintColors.textMuted,
          ),
          prefixIcon: const Icon(Icons.search,
              color: MintColors.textMuted, size: 20),
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
            'Aucun outil trouve',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essaie avec d\'autres mots-cles',
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
            borderRadius: const Borderconst Radius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.1),
                      borderRadius: const Borderconst Radius.circular(10),
                    ),
                    child: Icon(category.icon,
                        color: category.color, size: 18),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: MintColors.surface,
                      borderRadius: const Borderconst Radius.circular(8),
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
        borderRadius: const Borderconst Radius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.card,
            borderRadius: const Borderconst Radius.circular(16),
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
                  borderRadius: const Borderconst Radius.circular(12),
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
