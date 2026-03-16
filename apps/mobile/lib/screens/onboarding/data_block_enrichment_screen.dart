import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/services/cross_validation_service.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Data block enrichment screen — deep-edit a specific confidence bloc.
///
/// P8 Phase 3: Routes /data-block/<type> land here.
/// Shows the current block score, prompts, and relevant input fields.
///
/// Supported block types: revenu, lpp, avs, 3a, patrimoine,
/// objectifRetraite, compositionMenage.
class DataBlockEnrichmentScreen extends StatefulWidget {
  final String blockType;
  static const Set<String> _supportedBlockTypes = {
    'revenu',
    'lpp',
    'avs',
    '3a',
    'patrimoine',
    'fiscalite',
    'objectifRetraite',
    'compositionMenage',
  };

  const DataBlockEnrichmentScreen({
    super.key,
    required this.blockType,
  });

  @override
  State<DataBlockEnrichmentScreen> createState() =>
      _DataBlockEnrichmentScreenState();
}

class _DataBlockEnrichmentScreenState
    extends State<DataBlockEnrichmentScreen> {
  bool _showCoachMode = false;

  /// Cached cross-validation alerts to avoid recomputing on every build.
  List<ValidationAlert>? _cachedAlerts;
  CoachProfile? _cachedAlertsProfile;

  List<ValidationAlert> _getAlertsForBlock(
      CoachProfile profile, String blockType) {
    // Recompute only when the profile object changes (Provider identity).
    if (!identical(profile, _cachedAlertsProfile)) {
      _cachedAlerts = CrossValidationService.validate(profile);
      _cachedAlertsProfile = profile;
    }
    return _cachedAlerts!.where((a) => a.block == blockType).toList();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<CoachProfileProvider>().profile;
    final canonicalBlockType = _canonicalBlockType(widget.blockType);
    final isKnownBlock =
        DataBlockEnrichmentScreen._supportedBlockTypes.contains(canonicalBlockType);
    final blocs = profile != null
        ? ConfidenceScorer.scoreAsBlocs(profile)
        : <String, BlockScore>{};
    final bloc = isKnownBlock ? blocs[canonicalBlockType] : null;

    final meta = _blockMeta(isKnownBlock ? canonicalBlockType : 'unknown');

    // Check if SLM or BYOK is available for coach mode
    final slmProvider = context.watch<SlmProvider>();
    final coachAvailable = slmProvider.isEngineAvailable;

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // ── Block score indicator ────────────────────────────
              if (bloc != null) _BlockScoreBar(bloc: bloc),
              const SizedBox(height: 24),

              // ── Coach mode toggle ───────────────────────────────
              _CoachModeToggle(
                isCoachMode: _showCoachMode,
                coachAvailable: coachAvailable,
                onToggle: (value) {
                  if (value) {
                    // Navigate to coach chat with contextual prompt
                    final prompt = _coachPromptForBlock(canonicalBlockType);
                    context.push('/coach/chat?prompt=${Uri.encodeComponent(prompt)}');
                  } else {
                    setState(() => _showCoachMode = false);
                  }
                },
              ),
              const SizedBox(height: 16),

              // ── Description ─────────────────────────────────────
              ...[
                Text(
                  meta.description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: MintColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Enrichment prompts for this block ────────────────
              if (profile != null) ...[
                _buildPrompts(profile, canonicalBlockType, bloc),
              ],

              // ── Cross-validation alerts ────────────────────────────
              if (profile != null) ...[
                _buildValidationAlerts(profile, canonicalBlockType),
              ],

              const SizedBox(height: 32),

              // ── CTA ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // Navigate to the appropriate enrichment flow
                    final route = _enrichmentRoute(canonicalBlockType);
                    if (route != null) {
                      context.push(route);
                    } else {
                      context.pop();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    foregroundColor: MintColors.white,
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
                'Outil éducatif simplifié. Ne constitue pas un conseil '
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

  Widget _buildPrompts(CoachProfile profile, String type, BlockScore? bloc) {
    final confidence = ConfidenceScorer.score(profile);
    final relevant = confidence.prompts
        .where((p) => _categoryMatchesBlock(p.category, type))
        .toList();

    if (relevant.isEmpty) {
      final isComplete = bloc?.status == 'complete';
      if (!isComplete) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MintColors.warning.withAlpha(12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MintColors.warning.withAlpha(48)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: MintColors.warning, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ce bloc est encore incomplet. Ouvre la section dédiée pour '
                  'ajouter les données manquantes.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: MintColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }
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

  Widget _buildValidationAlerts(CoachProfile profile, String blockType) {
    final relevant = _getAlertsForBlock(profile, blockType);

    if (relevant.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 16),
        ...relevant.map((alert) {
          final color = switch (alert.severity) {
            AlertSeverity.error => MintColors.error,
            AlertSeverity.warning => MintColors.warning,
            AlertSeverity.info => MintColors.primary,
          };
          final icon = switch (alert.severity) {
            AlertSeverity.error => Icons.error_outline,
            AlertSeverity.warning => Icons.warning_amber_rounded,
            AlertSeverity.info => Icons.lightbulb_outline,
          };

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withAlpha(12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withAlpha(48)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: color, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          alert.message,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: MintColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (alert.suggestion != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Text(
                        alert.suggestion!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: MintColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  bool _categoryMatchesBlock(String category, String blockType) {
    const mapping = {
      'revenu': ['income'],
      'lpp': ['lpp'],
      'avs': ['avs'],
      '3a': ['3a'],
      'patrimoine': ['patrimoine'],
      'fiscalite': ['fiscalite', 'tax', 'commune'],
      'objectifRetraite': ['objectif_retraite', 'retirement_urgency'],
      'compositionMenage': ['menage'],
      'foreign_pension': ['foreign_pension'],
    };
    final categories = mapping[blockType] ?? [];
    return categories.contains(category);
  }

  String _coachPromptForBlock(String type) {
    return switch (type) {
      '3a' => 'Je veux comprendre mon 3e pilier : combien de comptes ouvrir, chez quel provider, et comment maximiser mon avantage fiscal.',
      'lpp' => 'Explique-moi mon 2e pilier LPP : mon avoir actuel, la lacune de rachat, et ce que je peux faire pour ameliorer ma situation.',
      'avs' => 'Parle-moi de ma rente AVS : est-ce que j\'ai des lacunes de cotisation et comment les combler ?',
      'patrimoine' => 'Je veux faire le point sur mon patrimoine global et comprendre comment le structurer.',
      'fiscalite' => 'Aide-moi a comprendre ma situation fiscale et les leviers d\'optimisation possibles.',
      'revenu' => 'Je veux comprendre l\'impact de mon revenu sur ma prevoyance et mes impots.',
      'objectifRetraite' => 'Quel serait l\'impact si je partais a la retraite plus tot ou plus tard ?',
      'compositionMenage' => 'Comment la situation de couple influence mes projections de retraite ?',
      _ => 'Aide-moi a completer mon profil financier.',
    };
  }

  String? _enrichmentRoute(String type) {
    const routes = {
      'revenu': '/onboarding/quick',
      'lpp': '/scan',
      'avs': '/document-scan/avs-guide',
      '3a': '/pilier-3a',
      'patrimoine': '/profile/bilan',
      'fiscalite': '/fiscal',
      'objectifRetraite': '/coach/cockpit',
      'compositionMenage': '/couple',
    };
    return routes[type] ?? '/profile/bilan';
  }

  String _canonicalBlockType(String rawType) {
    final normalized = _normalizeTypeToken(rawType);
    return switch (normalized) {
      'situation' ||
      'income' ||
      'salary' ||
      'revenu' ||
      'salaire' ||
      'base' ||
      'age_canton' =>
        'revenu',
      'couple' ||
      'menage' ||
      'household' ||
      'composition_menage' ||
      'compositionmenage' =>
        'compositionMenage',
      'pension' ||
      'lpp' ||
      'prevoyance' ||
      'prevoyance_lpp' ||
      'pension_lpp' ||
      'lpp_balance' ||
      'lpp_details' ||
      'taux_conversion' =>
        'lpp',
      'avs' || 'avs_extract' || 'ci' => 'avs',
      'goal' ||
      'objectif' ||
      'objectif_retraite' ||
      'retirement_goal' ||
      'retirement_urgency' =>
        'objectifRetraite',
      'housing' ||
      'property' ||
      'patrimoine' ||
      'wealth' ||
      'asset' ||
      'assets' =>
        'patrimoine',
      '3a' || 'pilier_3a' || 'epargne_3a' => '3a',
      'fiscalite' ||
      'fiscal' ||
      'tax' ||
      'impot' ||
      'impots' ||
      'tax_declaration' =>
        'fiscalite',
      _ => rawType.trim(),
    };
  }

  String _normalizeTypeToken(String value) {
    var normalized = value.trim().toLowerCase();
    const accents = {
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    accents.forEach((source, target) {
      normalized = normalized.replaceAll(source, target);
    });
    normalized = normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized;
  }

  _BlockMeta _blockMeta(String type) {
    return switch (type) {
      'revenu' => const _BlockMeta(
          title: 'Revenu',
          description:
              'Ton salaire brut est la base de toutes les projections : '
              'prévoyance, impôts, budget. Plus il est précis, plus tes '
              'résultats seront fiables.',
          ctaLabel: 'Préciser mon revenu',
        ),
      'lpp' => const _BlockMeta(
          title: 'Prévoyance LPP',
          description:
              'Ton avoir LPP (2e pilier) représente souvent le plus gros '
              'capital de ta prévoyance. Un certificat de prévoyance donne '
              'une valeur exacte plutôt qu\'une estimation.',
          ctaLabel: 'Ajouter mon certificat LPP',
        ),
      'avs' => const _BlockMeta(
          title: 'Extrait AVS',
          description:
              "L'extrait AVS confirme tes années de cotisation effectives. "
              "Des lacunes (séjour à l'étranger, années manquantes) réduisent "
              'ta rente AVS.',
          ctaLabel: 'Commander mon extrait AVS',
        ),
      '3a' => const _BlockMeta(
          title: '3e pilier (3a)',
          description:
              "Tes comptes 3a s'ajoutent à ta prévoyance et offrent un "
              'avantage fiscal. Renseigne les soldes actuels pour une vue '
              'complète.',
          ctaLabel: 'Simuler mon 3a',
        ),
      'patrimoine' => const _BlockMeta(
          title: 'Patrimoine',
          description:
              'Épargne libre, investissements, immobilier : ces données '
              'complètent ta projection et permettent de calculer ton '
              'Financial Resilience Index.',
          ctaLabel: 'Renseigner mon patrimoine',
        ),
      'fiscalite' => const _BlockMeta(
          title: 'Fiscalité',
          description:
              'Ta commune, ton revenu imposable et ta fortune déterminent '
              'ton taux marginal d\'imposition. Une déclaration fiscale '
              'ou un avis de taxation donne un taux réel plutôt qu\'estimé '
              '(coefficient communal 60%-130%).',
          ctaLabel: 'Comparer ma fiscalité',
        ),
      'objectifRetraite' => const _BlockMeta(
          title: 'Objectif retraite',
          description: 'À quel âge souhaites-tu arrêter de travailler ? '
              "Un objectif clair permet de calculer l'effort d'épargne "
              'nécessaire et les options (anticipation, retraite partielle).',
          ctaLabel: 'Voir ma projection',
        ),
      'compositionMenage' => const _BlockMeta(
          title: 'Composition du ménage',
          description:
              'En couple, les projections changent : AVS plafonnée pour '
              'les mariés (LAVS art. 35), rente de survivant (LPP art. 19), '
              'optimisation fiscale à deux.',
          ctaLabel: 'Gérer mon ménage',
        ),
      'unknown' => const _BlockMeta(
          title: 'Données',
          description:
              'Ce lien de données n’est plus à jour. Utilise la section '
              'recommandée pour compléter ton profil.',
          ctaLabel: 'Ouvrir le diagnostic',
        ),
      _ => const _BlockMeta(
          title: 'Données',
          description: 'Complète ce bloc pour améliorer la précision de '
              'tes projections.',
          ctaLabel: 'Compléter',
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

// ═══════════════════════════════════════════════════════════════
// Coach Mode Toggle
// ═══════════════════════════════════════════════════════════════

class _CoachModeToggle extends StatelessWidget {
  final bool isCoachMode;
  final bool coachAvailable;
  final ValueChanged<bool> onToggle;

  const _CoachModeToggle({
    required this.isCoachMode,
    required this.coachAvailable,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeChip(
            label: 'Formulaire',
            icon: Icons.edit_note,
            isSelected: !isCoachMode,
            onTap: () => onToggle(false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeChip(
            label: 'Parle au coach',
            icon: Icons.smart_toy_outlined,
            isSelected: isCoachMode,
            isDisabled: !coachAvailable,
            onTap: coachAvailable ? () => onToggle(true) : null,
          ),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback? onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.isDisabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDisabled
        ? MintColors.textMuted
        : isSelected
            ? MintColors.primary
            : MintColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? MintColors.primary.withAlpha(15)
              : MintColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? MintColors.primary.withAlpha(60)
                : MintColors.lightBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Coach Bubble — conversational enrichment guide
// ═══════════════════════════════════════════════════════════════

// _CoachBubble removed — "Parle au coach" now navigates to /coach/chat
// with a contextual prompt for the block type.
