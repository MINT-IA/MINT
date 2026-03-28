import 'package:flutter/material.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  P4-F  Le Compte à rebours du délai de carence AI
//  Charte : L6 (Chiffre-choc) + L7 (Métaphore compte à rebours)
//  Source : LAI art. 28, LPGA art. 19
// ────────────────────────────────────────────────────────────

class DisabilityCountdownWidget extends StatefulWidget {
  const DisabilityCountdownWidget({
    super.key,
    required this.monthlyExpenses,
    required this.initialSavings,
  });

  final double monthlyExpenses;
  final double initialSavings;

  @override
  State<DisabilityCountdownWidget> createState() => _DisabilityCountdownWidgetState();
}

class _DisabilityCountdownWidgetState extends State<DisabilityCountdownWidget> {
  late double _savings;

  // Wire to social_insurance.dart single source of truth (LAI art. 28 + LPGA art. 19)
  static const int _aiDelayMonths = aiDecisionDelayMonths;

  @override
  void initState() {
    super.initState();
    _savings = widget.initialSavings;
  }

  double get _monthsCanHold => _savings / widget.monthlyExpenses;
  double get _gapMonths => (_aiDelayMonths - _monthsCanHold).clamp(0, _aiDelayMonths.toDouble());
  double get _gapAmount => _gapMonths * widget.monthlyExpenses;
  double get _holdFraction => (_monthsCanHold / _aiDelayMonths).clamp(0.0, 1.0);

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final hold = _monthsCanHold;
    final gap = _gapMonths;
    final isOk = hold >= _aiDelayMonths;
    final color = isOk
        ? MintColors.scoreExcellent
        : hold >= 6
            ? MintColors.scoreAttention
            : MintColors.scoreCritique;

    return Semantics(
      label: 'Compte à rebours délai carence AI invalidité',
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
                  _buildSavingsSlider(),
                  const SizedBox(height: 20),
                  _buildTimeline(hold, gap, color),
                  const SizedBox(height: 16),
                  _buildChiffreChoc(hold, gap, color, isOk),
                  const SizedBox(height: 16),
                  if (!isOk) _buildActions(),
                  if (!isOk) const SizedBox(height: 16),
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
        color: MintColors.amberWarm,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⏱', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Combien de temps tu tiens ?',
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Délai moyen de décision AI : $_aiDelayMonths mois (LAI art. 28)',
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsSlider() {
    final maxSavings = _aiDelayMonths * widget.monthlyExpenses * 1.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ton épargne disponible',
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              'CHF ${_fmt(_savings)}',
              style: MintTextStyles.bodyMedium(color: MintColors.primary).copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        Slider(
          value: _savings,
          min: 0,
          max: maxSavings,
          divisions: 60,
          activeColor: MintColors.primary,
          onChanged: (v) => setState(() => _savings = v),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('CHF 0', style: MintTextStyles.micro(color: MintColors.textSecondary)),
            Text(
              'CHF ${_fmt(maxSavings)}',
              style: MintTextStyles.micro(color: MintColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeline(double hold, double gap, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Durée de tenir vs délai AI',
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            // Background bar (total AI delay)
            Container(
              height: 28,
              decoration: BoxDecoration(
                color: MintColors.scoreCritique.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            // Hold bar
            if (_holdFraction > 0)
              FractionallySizedBox(
                widthFactor: _holdFraction.clamp(0.0, 1.0),
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '◄── ${hold.toStringAsFixed(1)} mois ──►',
                  style: MintTextStyles.labelSmall(color: color).copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Tu tiens',
                  style: MintTextStyles.micro(color: MintColors.textSecondary),
                ),
              ],
            ),
            if (gap > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '◄── ${gap.toStringAsFixed(1)} mois ──►',
                    style: MintTextStyles.labelSmall(color: MintColors.scoreCritique).copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Le vide',
                    style: MintTextStyles.micro(color: MintColors.textSecondary),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Jour J → Décision AI : $_aiDelayMonths mois',
            style: MintTextStyles.micro(color: MintColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildChiffreChoc(double hold, double gap, Color color, bool isOk) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isOk) ...[
            Text(
              '✅ Tes réserves couvrent tout le délai AI.',
              style: MintTextStyles.bodySmall(color: MintColors.scoreExcellent).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Tu tiens ${hold.toStringAsFixed(1)} mois, soit plus que le délai moyen de $_aiDelayMonths mois.',
              style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
            ),
          ] else ...[
            Text(
              '💰 Chiffre-choc : après ${hold.toStringAsFixed(1)} mois, il te faudrait emprunter ou vendre pour tenir.',
              style: MintTextStyles.bodySmall(color: MintColors.scoreCritique).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Il te manque CHF ${_fmt(_gapAmount)} pour tenir jusqu\'à la décision AI.',
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        _buildAction(
          '→ Constitue un fonds d\'urgence de 6 mois de charges',
          MintColors.primary,
        ),
        const SizedBox(height: 8),
        _buildAction(
          '→ Souscris une APG privée (dès CHF 45/mois)',
          MintColors.info,
        ),
      ],
    );
  }

  Widget _buildAction(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: MintTextStyles.bodySmall(color: color).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Source : LAI art. 28, LPGA art. 19.',
      style: MintTextStyles.micro(color: MintColors.textSecondary),
    );
  }
}
