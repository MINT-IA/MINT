import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Horizontal per-category data-completeness bar.
///
/// Per AUDIT-01 / Plan 08a-02 carve-out: this surface is an **extraction**
/// visualization (per-block enrichment state), NOT a calculation-confidence
/// renderer. It is intentionally a sibling of [MintTrameConfiance], and
/// MUST NOT import it.
///
/// Each block represents a scoring category from [ConfidenceScorer.scoreAsBlocs()].
/// Tapping a block navigates to the corresponding data enrichment screen.
///
/// Displays 5 main user-facing blocks (Base, Objectif, Menage, LPP, 3a).
/// Technical blocks (archetype, taux_conversion, foreign_pension) are merged
/// into their parent categories for UX clarity.
class DataBlockConfidenceBar extends StatelessWidget {
  final Map<String, BlockScore> blocs;

  const DataBlockConfidenceBar({super.key, required this.blocs});

  static const _displayBlocks = [
    _DisplayBlock(
      keys: ['revenu', 'age_canton', 'archetype'],
      label: 'Base',
      icon: Icons.person,
      dataBlockType: 'revenu',
    ),
    _DisplayBlock(
      keys: ['objectifRetraite'],
      label: 'Objectif',
      icon: Icons.flag,
      dataBlockType: 'objectifRetraite',
    ),
    _DisplayBlock(
      keys: ['compositionMenage'],
      label: 'Ménage',
      icon: Icons.people,
      dataBlockType: 'compositionMenage',
    ),
    _DisplayBlock(
      keys: ['lpp', 'taux_conversion'],
      label: 'LPP',
      icon: Icons.account_balance,
      dataBlockType: 'lpp',
    ),
    _DisplayBlock(
      keys: ['avs', '3a', 'patrimoine', 'foreign_pension'],
      label: 'Épargne',
      icon: Icons.savings,
      dataBlockType: '3a',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Row(
        children: _displayBlocks.map((db) {
          double score = 0;
          double maxScore = 0;
          for (final key in db.keys) {
            final bloc = blocs[key];
            if (bloc != null) {
              score += bloc.score;
              maxScore += bloc.maxScore;
            }
          }
          final ratio = maxScore > 0 ? (score / maxScore).clamp(0.0, 1.0) : 0.0;
          final isComplete = ratio >= 0.95;
          final isMissing = ratio < 0.1;

          return Expanded(
            child: Semantics(
              label: db.label,
              button: true,
              child: GestureDetector(
                onTap: () => context.push('/data-block/${db.dataBlockType}'),
                child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isComplete
                            ? MintColors.primary.withAlpha(20)
                            : isMissing
                                ? MintColors.lightBorder.withAlpha(60)
                                : MintColors.accent.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        db.icon,
                        size: 18,
                        color: isComplete
                            ? MintColors.primary
                            : isMissing
                                ? MintColors.textMuted
                                : MintColors.accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 4,
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: MintColors.lightBorder,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isComplete ? MintColors.primary : MintColors.accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      db.label,
                      style: MintTextStyles.micro(color: isComplete ? MintColors.textPrimary : MintColors.textMuted).copyWith(fontWeight: isComplete ? FontWeight.w600 : FontWeight.w400),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          );
        }).toList(),
      ),
    );
  }
}

/// Back-compat alias. New code MUST use [DataBlockConfidenceBar].
/// Slated for removal in Phase 11 (see Plan 08a-03 CI gate).
@Deprecated('Use DataBlockConfidenceBar — sibling of MintTrameConfiance (AUDIT-01 extraction carve-out).')
typedef ConfidenceBlocksBar = DataBlockConfidenceBar;

class _DisplayBlock {
  final List<String> keys;
  final String label;
  final IconData icon;
  final String dataBlockType;

  const _DisplayBlock({
    required this.keys,
    required this.label,
    required this.icon,
    required this.dataBlockType,
  });
}
