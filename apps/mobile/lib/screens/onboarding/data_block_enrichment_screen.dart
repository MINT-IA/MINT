import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Data block enrichment screen — deep-edit a specific confidence bloc.
///
/// P8 Phase 3: Routes /data-block/<type> land here.
/// Shows the current block score, prompts, and relevant input fields.
///
/// Supported block types: revenu, lpp, avs, 3a, patrimoine,
/// objectifRetraite, compositionMenage.
class DataBlockEnrichmentScreen extends StatelessWidget {
  final String blockType;

  const DataBlockEnrichmentScreen({
    super.key,
    required this.blockType,
  });

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<CoachProfileProvider>().profile;
    final blocs = profile != null
        ? ConfidenceScorer.scoreAsBlocs(profile)
        : <String, BlockScore>{};
    final bloc = blocs[blockType];

    final meta = _blockMeta(blockType);

    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          meta.title,
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // ── Block score indicator ────────────────────────────
              if (bloc != null) _BlockScoreBar(bloc: bloc),
              const SizedBox(height: 24),

              // ── Description ──────────────────────────────────────
              Text(
                meta.description,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // ── Enrichment prompts for this block ────────────────
              if (profile != null) ...[
                _buildPrompts(profile, blockType),
              ],

              const Spacer(),

              // ── CTA ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // Navigate to the appropriate enrichment flow
                    final route = _enrichmentRoute(blockType);
                    if (route != null) {
                      context.push(route);
                    } else {
                      context.pop();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    meta.ctaLabel,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Disclaimer ───────────────────────────────────────
              Text(
                'Outil educatif simplifie. Ne constitue pas un conseil '
                'financier (LSFin).',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: MintColors.textMuted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrompts(CoachProfile profile, String type) {
    final confidence = ConfidenceScorer.score(profile);
    final relevant = confidence.prompts
        .where((p) => _categoryMatchesBlock(p.category, type))
        .toList();

    if (relevant.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.success.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: MintColors.success, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Ce bloc est complet.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.success,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: relevant.map((prompt) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MintColors.lightBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: MintColors.primary.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '+${prompt.impact}',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: MintColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prompt.label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: MintColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        prompt.action,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  bool _categoryMatchesBlock(String category, String blockType) {
    const mapping = {
      'revenu': ['income'],
      'lpp': ['lpp'],
      'avs': ['avs'],
      '3a': ['3a'],
      'patrimoine': ['patrimoine'],
      'objectifRetraite': ['objectif_retraite', 'retirement_urgency'],
      'compositionMenage': ['menage'],
      'foreign_pension': ['foreign_pension'],
    };
    final categories = mapping[blockType] ?? [];
    return categories.contains(category);
  }

  String? _enrichmentRoute(String type) {
    const routes = {
      'revenu': '/onboarding/enrichment',
      'lpp': '/document-scan',
      'avs': '/document-scan/avs-guide',
      '3a': '/3a-deep/comparator',
      'patrimoine': '/onboarding/enrichment',
      'objectifRetraite': '/onboarding/enrichment',
      'compositionMenage': '/onboarding/enrichment',
    };
    return routes[type];
  }

  _BlockMeta _blockMeta(String type) {
    return switch (type) {
      'revenu' => const _BlockMeta(
          title: 'Revenu',
          description:
              'Ton salaire brut est la base de toutes les projections : '
              'prevoyance, impots, budget. Plus il est precis, plus tes '
              'resultats seront fiables.',
          ctaLabel: 'Mettre a jour mon revenu',
        ),
      'lpp' => const _BlockMeta(
          title: 'Prevoyance LPP',
          description:
              'Ton avoir LPP (2e pilier) represente souvent le plus gros '
              'capital de ta prevoyance. Un certificat de prevoyance donne '
              'une valeur exacte vs une estimation.',
          ctaLabel: 'Ajouter mon certificat LPP',
        ),
      'avs' => const _BlockMeta(
          title: 'Extrait AVS',
          description:
              'L\'extrait AVS confirme tes annees de cotisation effectives. '
              'Des lacunes (sejour a l\'etranger, annees manquantes) reduisent '
              'ta rente AVS.',
          ctaLabel: 'Commander mon extrait AVS',
        ),
      '3a' => const _BlockMeta(
          title: '3e pilier (3a)',
          description:
              'Tes comptes 3a s\'ajoutent a ta prevoyance et offrent un '
              'avantage fiscal. Renseigne les soldes actuels pour une vue '
              'complete.',
          ctaLabel: 'Saisir mes soldes 3a',
        ),
      'patrimoine' => const _BlockMeta(
          title: 'Patrimoine',
          description:
              'Epargne libre, investissements, immobilier : ces donnees '
              'completent ta projection et permettent de calculer ton '
              'Financial Resilience Index.',
          ctaLabel: 'Renseigner mon patrimoine',
        ),
      'objectifRetraite' => const _BlockMeta(
          title: 'Objectif retraite',
          description:
              'A quel age souhaites-tu arreter de travailler ? '
              'Un objectif clair permet de calculer l\'effort d\'epargne '
              'necessaire et les options (anticipation, retraite partielle).',
          ctaLabel: 'Definir mon objectif',
        ),
      'compositionMenage' => const _BlockMeta(
          title: 'Composition du menage',
          description:
              'En couple, les projections changent : AVS plafonnee pour '
              'les maries (LAVS art. 35), rente de survivant (LPP art. 19), '
              'optimisation fiscale a deux.',
          ctaLabel: 'Completer le profil couple',
        ),
      _ => const _BlockMeta(
          title: 'Donnees',
          description: 'Complete ce bloc pour ameliorer la precision de '
              'tes projections.',
          ctaLabel: 'Completer',
        ),
    };
  }
}

class _BlockMeta {
  final String title;
  final String description;
  final String ctaLabel;

  const _BlockMeta({
    required this.title,
    required this.description,
    required this.ctaLabel,
  });
}

class _BlockScoreBar extends StatelessWidget {
  final BlockScore bloc;

  const _BlockScoreBar({required this.bloc});

  @override
  Widget build(BuildContext context) {
    final ratio = bloc.maxScore > 0 ? bloc.score / bloc.maxScore : 0.0;
    final color = switch (bloc.status) {
      'complete' => MintColors.success,
      'partial' => MintColors.warning,
      _ => MintColors.error,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${bloc.score.round()} / ${bloc.maxScore.round()} pts',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                switch (bloc.status) {
                  'complete' => 'Complet',
                  'partial' => 'Partiel',
                  _ => 'Manquant',
                },
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: MintColors.lightBorder,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
