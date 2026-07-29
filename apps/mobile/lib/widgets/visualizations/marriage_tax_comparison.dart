import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/family_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────
//  IMPÔT DU MÉNAGE — DEUX CÉLIBATAIRES vs MARIÉ·E·S
// ────────────────────────────────────────────────────────────
//
//  Trois blocs, dans l'ordre de lecture :
//    1. les deux totaux, en barres de même remplissage — seule la LONGUEUR
//       diffère, donc la comparaison se lit aussi en niveaux de gris ;
//    2. l'écart : son SENS écrit en toutes lettres, puis son montant ;
//    3. la répartition des deux revenus, qui est ce qui fait basculer le sens,
//       avec la position de ce couple entre « revenus proches » et « un revenu
//       domine ».
//
//  AUCUNE couleur de valence. Ce widget remplace un thermomètre dont la moitié
//  haute était rouge (« pénalité ») et la moitié basse verte (« bonus »). Deux
//  raisons, convergentes :
//
//    - doctrine : le moteur est une estimation forfaitaire (barème marié
//      forfaitaire, ni déductions réelles, ni commune, ni barème cantonal
//      détaillé). Il donne le SENS d'un écart, pas de quoi qualifier un régime
//      de pénalité ou de bonus. Le rouge/vert était ce verdict en couleur ;
//    - accessibilité : faire porter une information par le seul couple
//      rouge/vert est l'échec WCAG le plus courant. Ici le sens est porté par
//      le libellé, par la longueur des barres et par le label `Semantics` ;
//      la couleur ne fait que meubler.
//
//  Le thermomètre montrait par ailleurs l'écart sans jamais montrer ce qui le
//  décide. Le bloc 3 est là pour ça : la répartition des revenus est la
//  variable dont dépend le sens, et l'ancienne visualisation ne l'exposait pas.
//
//  Ne pas ré-introduire de `MintColors.error` / `MintColors.success` ici : un
//  test de l'onglet Impôts (`mariage_gate_test.dart`) le repasse en rouge.
// ────────────────────────────────────────────────────────────

/// Household tax under both regimes, compared side by side.
///
/// [revenu1] / [revenu2] are the two gross incomes the comparison was computed
/// on. They feed no calculation here — they only place this couple on the
/// income-split scale, which is what the direction of the gap turns on.
class MarriageTaxComparison extends StatefulWidget {
  /// Total tax paid by two single individuals.
  final double taxSingles;

  /// Total tax paid as a married couple.
  final double taxMarried;

  /// First income the comparison was computed on.
  final double revenu1;

  /// Second income the comparison was computed on.
  final double revenu2;

  const MarriageTaxComparison({
    super.key,
    required this.taxSingles,
    required this.taxMarried,
    required this.revenu1,
    required this.revenu2,
  });

  @override
  State<MarriageTaxComparison> createState() => _MarriageTaxComparisonState();
}

class _MarriageTaxComparisonState extends State<MarriageTaxComparison>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _growth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _growth = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void didUpdateWidget(MarriageTaxComparison oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taxSingles != widget.taxSingles ||
        oldWidget.taxMarried != widget.taxMarried ||
        oldWidget.revenu1 != widget.revenu1 ||
        oldWidget.revenu2 != widget.revenu2) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Signed gap. Positive = the household pays more once married. A direction,
  /// never a verdict : which side that favours depends on the life it is read
  /// from, and this model is too coarse to arbitrate it.
  double get _gap => widget.taxMarried - widget.taxSingles;

  double get _maxTax => max(widget.taxSingles, widget.taxMarried);

  /// 0 = one income carries everything, 1 = the two incomes are equal.
  /// `null` when there is no income at all to split.
  double? get _incomeBalance {
    final higher = max(widget.revenu1, widget.revenu2);
    if (higher <= 0) return null;
    return (min(widget.revenu1, widget.revenu2) / higher).clamp(0.0, 1.0);
  }

  String _direction(BuildContext context) {
    if (_gap == 0) return S.of(context)!.mariageEcartAnnuelImpotIdentique;
    return _gap > 0
        ? S.of(context)!.mariageEcartAnnuelImpotPlusEleveMarie
        : S.of(context)!.mariageEcartAnnuelImpotPlusEleveCelibataires;
  }

  @override
  Widget build(BuildContext context) {
    final singlesLabel = S.of(context)!.mariageDeuxCelibataires;
    final marriedLabel = S.of(context)!.mariageMaries;
    final direction = _direction(context);

    return Semantics(
      // Le sens ET l'ampleur, pas seulement le nom de l'objet : sans les barres
      // sous les yeux, cette phrase doit suffire.
      label: '${S.of(context)!.mariageTaxComparisonTitle}. '
          '$direction : ${FamilyService.formatChf(_gap.abs())}. '
          '$singlesLabel ${FamilyService.formatChf(widget.taxSingles)}, '
          '$marriedLabel ${FamilyService.formatChf(widget.taxMarried)}.',
      child: MintSurface(
        tone: MintSurfaceTone.blanc,
        elevated: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.of(context)!.mariageTaxComparisonTitle,
              style: MintTextStyles.titleMedium(),
            ),
            const SizedBox(height: MintSpacing.lg),

            // ── 1. les deux totaux ──
            AnimatedBuilder(
              animation: _growth,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAmountBar(context, singlesLabel, widget.taxSingles),
                  const SizedBox(height: MintSpacing.md),
                  _buildAmountBar(context, marriedLabel, widget.taxMarried),
                ],
              ),
            ),
            const SizedBox(height: MintSpacing.lg),
            Divider(color: MintColors.border.withValues(alpha: 0.5)),
            const SizedBox(height: MintSpacing.md),

            // ── 2. l'écart : le sens d'abord, le montant ensuite ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    direction,
                    style:
                        MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                            .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: MintSpacing.sm),
                // Montant sans signe : le libellé porte déjà le sens, et un
                // « + » / « − » re-poserait le verdict qu'on retire.
                Text(
                  FamilyService.formatChf(_gap.abs()),
                  style:
                      MintTextStyles.titleLarge(color: MintColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),

            // ── 3. ce qui fait basculer le sens ──
            ..._buildIncomeSplit(context),
          ],
        ),
      ),
    );
  }

  /// One total: label + amount on a line, bar underneath. Both bars share the
  /// same fill token — only their length differs, which is what makes the
  /// comparison survive a greyscale print or a red/green colour deficiency.
  Widget _buildAmountBar(BuildContext context, String label, double amount) {
    final fraction = _maxTax <= 0 ? 0.0 : (amount / _maxTax) * _growth.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: MintTextStyles.labelMedium(color: MintColors.textSecondary)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            Text.rich(
              TextSpan(
                text: FamilyService.formatChf(amount),
                style: MintTextStyles.labelLarge(color: MintColors.textPrimary)
                    .copyWith(fontWeight: FontWeight.w700),
                children: [
                  TextSpan(
                    text: ' ${S.of(context)!.mariageParAn}',
                    style:
                        MintTextStyles.labelSmall(color: MintColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 10,
            color: MintColors.surface,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: Container(color: MintColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  /// The income split is the variable the direction of the gap turns on. It is
  /// shown as a POSITION, never as a prediction: the ends are named for what
  /// they are, and the caption states the two forces at work. Marking a tipping
  /// point would claim a precision this simplified model does not have — and
  /// would let the scale contradict the figure printed just above it.
  List<Widget> _buildIncomeSplit(BuildContext context) {
    final balance = _incomeBalance;
    if (balance == null) return const [];

    return [
      const SizedBox(height: MintSpacing.lg),
      Text(
        S.of(context)!.mariageRepartitionCaption,
        style: MintTextStyles.bodySmall(color: MintColors.textSecondary)
            .copyWith(height: 1.4),
      ),
      const SizedBox(height: MintSpacing.md),
      AnimatedBuilder(
        animation: _growth,
        builder: (context, _) {
          // Left = incomes close together, right = one income dominates.
          final position = ((1 - balance) * _growth.value).clamp(0.0, 1.0);
          return SizedBox(
            height: 14,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(height: 6, color: MintColors.surface),
                ),
                Align(
                  alignment: Alignment(position * 2 - 1, 0),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: MintColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: MintColors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: MintSpacing.xs),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            S.of(context)!.mariageRepartitionRevenusProches,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
          Text(
            S.of(context)!.mariageRepartitionRevenuDomine,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
        ],
      ),
    ];
  }
}
