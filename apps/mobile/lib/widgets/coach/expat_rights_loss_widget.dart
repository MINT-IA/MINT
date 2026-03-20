import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  P13-A  Les 5 choses que tu perds en partant
//  Charte : L6 (Chiffre-choc) + L2 (Avant/Après)
//  Source : LAVS art. 1a, LPP art. 5, OPP3 art. 1, LAMal art. 3
// ────────────────────────────────────────────────────────────

class ExpatRight {
  const ExpatRight({
    required this.label,
    required this.emoji,
    required this.before,
    required this.after,
    required this.legalRef,
    required this.impact,
    this.isIrreversible = false,
  });

  final String label;
  final String emoji;
  final String before;
  final String after;
  final String legalRef;
  final String impact;
  final bool isIrreversible;
}

class ExpatRightsLossWidget extends StatelessWidget {
  const ExpatRightsLossWidget({
    super.key,
    required this.rights,
    required this.destination,
    this.isEuDestination = false,
  });

  final List<ExpatRight> rights;
  final String destination;
  final bool isEuDestination;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Expatriation droits perdus AVS LPP 3a LAMal avant après',
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEuBadge(),
                  if (isEuDestination) const SizedBox(height: 12),
                  ...rights.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildRightCard(r),
                  )),
                  const SizedBox(height: 4),
                  _buildDisclaimer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: MintColors.urgentBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✈️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '5 choses que tu perds en partant',
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Suisse → $destination · Avant de partir, vérifie chaque point.',
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEuBadge() {
    if (!isEuDestination) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Text('🇪🇺', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Destination UE — totalisation des périodes d\'assurance possible',
              style: MintTextStyles.labelSmall(color: MintColors.info),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightCard(ExpatRight r) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: r.isIrreversible
              ? MintColors.scoreCritique.withValues(alpha: 0.3)
              : MintColors.scoreAttention.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: r.isIrreversible
                  ? MintColors.scoreCritique.withValues(alpha: 0.06)
                  : MintColors.scoreAttention.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Text(r.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.label,
                              style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (r.isIrreversible)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: MintColors.scoreCritique,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'IRRÉVERSIBLE',
                                style: MintTextStyles.micro(color: MintColors.white).copyWith(fontSize: 9, fontWeight: FontWeight.w800),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        r.legalRef,
                        style: MintTextStyles.micro(color: MintColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildBeforeAfter('En Suisse', r.before, MintColors.scoreExcellent),
                    ),
                    const Icon(Icons.arrow_forward, size: 16, color: MintColors.textSecondary),
                    Expanded(
                      child: _buildBeforeAfter('À $destination', r.after, MintColors.scoreCritique),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: MintColors.scoreCritique.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '💥 ${r.impact}',
                    style: MintTextStyles.labelSmall(color: MintColors.scoreCritique).copyWith(fontSize: 12, fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeforeAfter(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: MintTextStyles.micro(color: MintColors.textSecondary)),
        const SizedBox(height: 4),
        Text(
          value,
          style: MintTextStyles.labelSmall(color: color).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil juridique ou financier au sens de la LSFin. '
      'Source : LAVS art. 1a, LPP art. 5, OPP3 art. 1, LAMal art. 3.',
      style: MintTextStyles.micro(color: MintColors.textSecondary),
    );
  }
}
