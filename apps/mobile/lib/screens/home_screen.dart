import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mint_mobile/models/recommendation.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/info_tooltip.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/profile_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showSafeModeBanner = true;
  // Mock recommendations for MVP
  final List<Recommendation> _recommendations = [
    Recommendation(
      id: '1',
      kind: 'compound_interest',
      title: 'Le pouvoir du temps',
      summary: 'CHF 500/mois à 5% = CHF 205\'000 en 20 ans.',
      why: [
        'Les intérêts composés travaillent pour toi',
        'Commencer tôt maximise l\'effet'
      ],
      assumptions: ['Rendement 5%/an', 'Versements réguliers'],
      impact: const Impact(amountCHF: 85000, period: Period.oneoff),
      risks: ['Volatilité du marché'],
      alternatives: ['Compte épargne', 'Pilier 3a'],
      evidenceLinks: [],
      nextActions: [
        const NextAction(
            type: NextActionType.simulate, label: 'Simuler mes intérêts'),
      ],
    ),
    Recommendation(
      id: '2',
      kind: 'pillar3a',
      title: 'Optimisation Fiscale',
      summary: 'Économisez jusqu\'à CHF 1\'764/an d\'impôts.',
      why: ['Déduction fiscale immédiate', 'Rendement supérieur au compte'],
      assumptions: ['Taux marginal 25%', 'Contribution max'],
      impact: const Impact(amountCHF: 1764, period: Period.yearly),
      risks: ['Capital bloqué jusqu\'à la retraite'],
      alternatives: ['3a bancaire', '3a assurance'],
      evidenceLinks: [],
      nextActions: [
        const NextAction(
            type: NextActionType.simulate, label: 'Calculer mon économie'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSafeModeBanner(context),
                const SizedBox(height: 12),
                _buildCoachBanner(context),
                const SizedBox(height: 32),
                _buildSectionHeader(context, S.of(context)?.recommendations ?? 'Tes Recommandations'),
                const SizedBox(height: 16),
                for (var rec in _recommendations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildRecommendationCard(context, rec),
                  ),
                const SizedBox(height: 32),
                _buildSectionHeader(context, S.of(context)?.simulatorsTitle ?? 'Simulateurs de Voyage'),
                const SizedBox(height: 16),
                _buildSimulatorGrid(context),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      backgroundColor: MintColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        'MINT',
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
          fontSize: 16,
          color: MintColors.primary,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_outlined, size: 22),
          onPressed: () => context.go('/'),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSafeModeBanner(BuildContext context) {
    if (!_showSafeModeBanner) return const SizedBox.shrink();

    final hasDebt = context.watch<ProfileProvider>().profile?.hasDebt ?? false;
    if (!hasDebt) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      color: MintColors.warning, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    S.of(context)?.homeSafeModeActive ?? 'MODE PROTECTION ACTIVÉ',
                    style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: MintColors.warning,
                        letterSpacing: 1),
                  ),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _showSafeModeBanner = false),
                icon: const Icon(Icons.close,
                    size: 18, color: MintColors.textMuted),
                tooltip: S.of(context)?.homeHide ?? 'Masquer',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context)?.homeSafeModeMessage ?? 'Nous avons détecté des signaux de tension. MINT te conseille de stabiliser ton budget avant tout investissement.',
            style: const TextStyle(
                fontSize: 13, height: 1.4, color: MintColors.textPrimary),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.help_outline, size: 16),
            label: Text(S.of(context)?.homeSafeModeResources ?? 'Ressources & Aides gratuites'),
            style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: MintColors.warning),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: MintColors.appleSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_outlined,
                    color: MintColors.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Text(
                S.of(context)?.homeMentorAdvisor ?? 'Mentor Advisor',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            S.of(context)?.homeMentorDescription ?? 'Lance ta session personnalisée pour obtenir un diagnostic complet de ta situation financière.',
            style: const TextStyle(
              fontSize: 15,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.push('/advisor'),
              child: Text(S.of(context)?.homeStartSession ?? 'Démarrer ma session'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: GoogleFonts.montserrat(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: MintColors.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildRecommendationCard(BuildContext context, Recommendation rec) {
    return Container(
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: MintColors.border, width: 0.5)),
      ),
      child: InkWell(
        onTap: () => _handleAction(rec.nextActions.first),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            children: [
              _buildKindIcon(rec.kind),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    _buildSummaryWithTooltips(rec.summary),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildImpactBadge(rec.impact),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right,
                  color: MintColors.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKindIcon(String kind) {
    final (IconData icon, Color color) = switch (kind) {
      'compound_interest' => (Icons.trending_up, MintColors.primary),
      'pillar3a' => (Icons.savings_outlined, MintColors.success),
      'consumer_credit' => (Icons.warning_amber_rounded, MintColors.warning),
      _ => (Icons.info_outline, MintColors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildSummaryWithTooltips(String summary) {
    // Basic implementation: find keywords and wrap them
    final keywords = [
      'volatilité',
      'taux marginal',
      'intérêt composé',
      'amortissement indirect'
    ];
    List<InlineSpan> spans = [];

    String temp = summary;
    for (var keyword in keywords) {
      if (temp.toLowerCase().contains(keyword)) {
        // Simple split for demo
        int index = temp.toLowerCase().indexOf(keyword);
        spans.add(TextSpan(text: temp.substring(0, index)));
        spans.add(WidgetSpan(child: InfoTooltip(term: keyword)));
        temp = temp.substring(index + keyword.length);
      }
    }
    spans.add(TextSpan(text: temp));

    return RichText(
      text: TextSpan(
        style: const TextStyle(
            color: MintColors.textSecondary, fontSize: 14, height: 1.5),
        children: spans,
      ),
    );
  }


  Widget _buildImpactBadge(Impact impact) {
    final periodLabel = switch (impact.period) {
      Period.monthly => '/mois',
      Period.yearly => '/an',
      _ => ' potentiel',
    };

    return Text(
      '+ CHF ${impact.amountCHF.toStringAsFixed(0)}$periodLabel',
      style: const TextStyle(
        color: MintColors.success,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }

  Widget _buildSimulatorGrid(BuildContext context) {
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildSimulatorTile(
                S.of(context)?.homeSimulator3a ?? 'Retraite 3a', Icons.savings_outlined, '/simulator/3a'),
            _buildSimulatorTile(
                S.of(context)?.homeSimulatorGrowth ?? 'Croissance', Icons.trending_up, '/simulator/compound'),
            _buildSimulatorTile(
                S.of(context)?.homeSimulatorLeasing ?? 'Leasing', Icons.directions_car_outlined, '/simulator/leasing'),
            _buildSimulatorTile(S.of(context)?.homeSimulatorCredit ?? 'Crédit Conso', Icons.credit_card_outlined,
                '/simulator/credit'),
          ],
        ),
        const SizedBox(height: 12),
        // Demo Rapport V2
        InkWell(
          onTap: () {
            context.push('/report/demo');
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade400, Colors.purple.shade600],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Icon(Icons.science, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.of(context)?.homeReportV2Title ?? '🧪 NOUVEAU : Rapport V2 (Démo)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        S.of(context)?.homeReportV2Subtitle ?? 'Score par cercle, comparateur 3a, stratégie LPP',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimulatorTile(String title, IconData icon, String route) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: MintColors.primary, size: 22),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(NextAction action) {
    if (action.type == NextActionType.simulate) {
      if (action.label.contains('intérêts')) {
        context.push('/simulator/compound');
      } else if (action.label.contains('économie') ||
          action.label.contains('calculer')) {
        context.push('/simulator/3a');
      } else if (action.label.contains('crédit')) {
        context.push('/simulator/credit');
      }
    }
  }
}
