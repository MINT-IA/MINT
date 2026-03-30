import 'package:flutter/material.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  P7-C  Compteur de jours — Capital temps (sablier)
//  Charte : L6 (Chiffre-choc) + L7 (Métaphore sablier)
//  Source : LACI art. 27-30
// ────────────────────────────────────────────────────────────

class UnemploymentCounterWidget extends StatelessWidget {
  const UnemploymentCounterWidget({
    super.key,
    required this.age,
    required this.monthlyBenefit,
    this.daysConsumed = 0,
  });

  final int age;
  final double monthlyBenefit;
  final int daysConsumed;

  /// Durée max indemnités AC par tranche d'âge — cas standard (≥ 22 mois cotisation).
  /// Source : LACI art. 27 al. 2 lit. a-d.
  static int _maxDays(int age) {
    if (age < 25) return acJoursMinCotisation;       // 200 j — cotisation typiquement courte
    if (age < acAgeSeuillSenior) return acJoursStandard;  // 400 j — LACI art. 27 al. 2 lit. c
    return acJoursSenior;                            // 520 j — LACI art. 27 al. 2 lit. d
  }

  static String _ageLabel(int age) {
    if (age < 25) return '< 25 ans';
    if (age < acAgeSeuillSenior) return '25–54 ans';
    return '≥ 55 ans';
  }

  static String _fmt(double v) {
    final n = v.round();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final maxDays = _maxDays(age);
    final remaining = (maxDays - daysConsumed).clamp(0, maxDays);
    final progressFraction = daysConsumed / maxDays;
    final monthsRemaining = remaining / 21.7;

    return Semantics(
      label: 'Compteur jours chômage capital temps',
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(maxDays),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProgressBar(progressFraction, remaining, maxDays),
                  const SizedBox(height: 20),
                  _buildStatsRow(remaining, monthsRemaining),
                  const SizedBox(height: 20),
                  _buildAgeTable(age),
                  const SizedBox(height: 16),
                  _buildChiffreChoc(),
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

  Widget _buildHeader(int maxDays) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: MintColors.neutralBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⏳', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ton capital temps',
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_ageLabel(age)} → $maxDays indemnités journalières',
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStatChip(
                label: 'CHF ${_fmt(monthlyBenefit)}/mois',
                color: MintColors.primary,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                label: '≈ ${(maxDays / 21.7).toStringAsFixed(0)} mois',
                color: MintColors.info,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: MintTextStyles.labelMedium(color: color).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildProgressBar(double fraction, int remaining, int maxDays) {
    final color = fraction < 0.5
        ? MintColors.scoreExcellent
        : fraction < 0.75
            ? MintColors.scoreAttention
            : MintColors.scoreCritique;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Jours utilisés : $daysConsumed',
              style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
            ),
            Text(
              'Restants : $remaining',
              style: MintTextStyles.labelMedium(color: color).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 14,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Jour 0',
              style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(fontStyle: FontStyle.normal),
            ),
            Text(
              'Jour $maxDays → 0 CHF',
              style: MintTextStyles.micro(color: MintColors.scoreCritique).copyWith(fontWeight: FontWeight.w700, fontStyle: FontStyle.normal),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow(int remaining, double monthsRemaining) {
    return Row(
      children: [
        Expanded(child: _buildStatCard(
          label: 'Jours restants',
          value: '$remaining',
          color: MintColors.info,
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(
          label: 'Soit environ',
          value: '${monthsRemaining.toStringAsFixed(1)} mois',
          color: MintColors.primary,
        )),
      ],
    );
  }

  Widget _buildStatCard({required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: MintTextStyles.headlineSmall(color: color).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeTable(int currentAge) {
    final rows = [
      (age: 24, label: '< 25 ans', days: acJoursMinCotisation),
      (age: 40, label: '25–54 ans', days: acJoursStandard),
      (age: 57, label: '≥ 55 ans',  days: acJoursSenior),
    ];

    return Container(
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tranche d\'âge',
                    style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  'Indemnités max',
                  style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...rows.map((r) {
            final isActive = _maxDays(currentAge) == r.days;
            return Container(
              color: isActive ? MintColors.primary.withValues(alpha: 0.07) : null,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  if (isActive)
                    const Icon(Icons.arrow_right, color: MintColors.primary, size: 16),
                  if (!isActive) const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      r.label,
                      style: MintTextStyles.bodySmall(color: isActive ? MintColors.primary : MintColors.textPrimary).copyWith(fontWeight: isActive ? FontWeight.w700 : FontWeight.w400),
                    ),
                  ),
                  Text(
                    '${r.days} jours',
                    style: MintTextStyles.bodySmall(color: isActive ? MintColors.primary : MintColors.textPrimary).copyWith(fontWeight: isActive ? FontWeight.w700 : FontWeight.w400),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChiffreChoc() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreCritique.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreCritique.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Après le dernier jour : 0 CHF',
                  style: MintTextStyles.bodySmall(color: MintColors.scoreCritique).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pas de prolongation. Tu passes à l\'aide sociale — sans délai de grâce.',
                  style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Source : LACI art. 27-30.',
      style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(fontStyle: FontStyle.normal),
    );
  }
}
