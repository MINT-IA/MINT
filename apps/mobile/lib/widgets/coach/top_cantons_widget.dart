import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  P12-C  Top 5 cantons pour ton profil
//  Charte : L5 (1 action) + L6 (Chiffre-choc)
//  Source : AFC (Administration fédérale des contributions)
// ────────────────────────────────────────────────────────────

class CantonRanking {
  const CantonRanking({
    required this.rank,
    required this.canton,
    required this.shortCode,
    required this.annualTaxSaving,
    this.monthlyLamal,
    this.monthlyRent,
    this.highlight,
  });

  final int rank;
  final String canton;
  final String shortCode;
  final double annualTaxSaving; // vs current canton
  // Nullables depuis MINT_nosync-9f8 : les anciennes valeurs LaMal/loyer
  // etaient inventees (aucune source) — masquees quand absentes.
  final double? monthlyLamal;
  final double? monthlyRent;
  final String? highlight;
}

class TopCantonWidget extends StatefulWidget {
  const TopCantonWidget({
    super.key,
    required this.currentCanton,
    required this.rankings,
    this.hasChildren = false,
    this.onChildrenChanged,
  });

  final String currentCanton;
  final List<CantonRanking> rankings;
  final bool hasChildren;
  final ValueChanged<bool>? onChildrenChanged;

  @override
  State<TopCantonWidget> createState() => _TopCantonWidgetState();
}

class _TopCantonWidgetState extends State<TopCantonWidget> {
  bool _hasChildren = false;

  @override
  void initState() {
    super.initState();
    _hasChildren = widget.hasChildren;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Comparaison indicative de cantons pour déménagement',
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
                  _buildFilter(),
                  const SizedBox(height: 16),
                  _buildRankingList(),
                  const SizedBox(height: 16),
                  _buildAction(),
                  const SizedBox(height: 16),
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
    final top = widget.rankings.isNotEmpty ? widget.rankings.first : null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.scoreExcellent.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cantons à simuler',
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (top != null)
            Text(
              'Premier scénario : ${top.canton}. Écart fiscal estimé ${formatChfWithPrefix(top.annualTaxSaving)}/an vs ${widget.currentCanton}.',
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.4),
            ),
        ],
      ),
    );
  }

  Widget _buildFilter() {
    return Row(
      children: [
        Text(
          'Avec enfants',
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
        ),
        const SizedBox(width: 8),
        Switch(
          value: _hasChildren,
          activeTrackColor: MintColors.primary,
          onChanged: (v) {
            setState(() => _hasChildren = v);
            widget.onChildrenChanged?.call(v);
          },
        ),
      ],
    );
  }

  Widget _buildRankingList() {
    if (widget.rankings.isEmpty) {
      // Etat vide honnete (MINT_nosync-9f8) : le canton actuel est deja
      // parmi les moins imposes — aucun ecart favorable a fabriquer.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          S.of(context)!.expatTopCantonsEmpty(widget.currentCanton),
          style: MintTextStyles.bodySmall(color: MintColors.textSecondary)
              .copyWith(height: 1.4),
        ),
      );
    }
    return Column(
      children: widget.rankings.asMap().entries.map((e) {
        final r = e.value;
        final isTop = e.key == 0;
        final color = isTop ? MintColors.scoreExcellent : MintColors.textSecondary;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isTop ? MintColors.scoreExcellent.withValues(alpha: 0.1) : MintColors.appleSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isTop ? MintColors.scoreExcellent : MintColors.lightBorder,
                width: isTop ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isTop ? 1.0 : 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${r.rank}',
                    style: MintTextStyles.bodyMedium(color: isTop ? MintColors.white : MintColors.textSecondary).copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.canton,
                        style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (r.highlight != null)
                        Text(
                          r.highlight!,
                          style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(fontStyle: FontStyle.normal),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Écart estimé ${formatChfWithPrefix(r.annualTaxSaving)}/an',
                      style: MintTextStyles.bodySmall(color: MintColors.scoreExcellent).copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (r.monthlyLamal != null && r.monthlyRent != null)
                      Text(
                        'LAMal ${formatChf(r.monthlyLamal!)}/m · loyer ~${formatChf(r.monthlyRent!)}/m',
                        style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(fontStyle: FontStyle.normal),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAction() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cet écart fiscal reste un scénario. '
              'Compare aussi la qualité des écoles, transports et prix de l\'immobilier.',
              style: MintTextStyles.labelMedium(color: MintColors.textPrimary).copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    // MINT_nosync-9f8 : l'ancienne attribution « Source : AFC » etait fausse
    // (les taux vivent dans FiscalService, modele simplifie MINT).
    return Text(
      S.of(context)!.expatTopCantonsDisclaimer,
      style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(fontStyle: FontStyle.normal),
    );
  }
}
