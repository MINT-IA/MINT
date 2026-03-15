import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';

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
    final s = S.of(context)!;
    final maxDays = _maxDays(age);
    final remaining = (maxDays - daysConsumed).clamp(0, maxDays);
    final progressFraction = daysConsumed / maxDays;
    final monthsRemaining = remaining / 21.7;

    return Semantics(
      label: s.unemploymentCounterSemantics,
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(s, maxDays),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProgressBar(s, progressFraction, remaining, maxDays),
                  const SizedBox(height: 20),
                  _buildStatsRow(s, remaining, monthsRemaining),
                  const SizedBox(height: 20),
                  _buildAgeTable(s, age),
                  const SizedBox(height: 16),
                  _buildChiffreChoc(s),
                  const SizedBox(height: 16),
                  _buildDisclaimer(s),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(S s, int maxDays) {
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
                  s.unemploymentCounterTitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.unemploymentCounterAgeSubtitle(_ageLabel(age), maxDays),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStatChip(
                label: s.unemploymentCounterChipMonthly(_fmt(monthlyBenefit)),
                color: MintColors.primary,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                label: s.unemploymentCounterChipMonths((maxDays / 21.7).toStringAsFixed(0)),
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
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildProgressBar(S s, double fraction, int remaining, int maxDays) {
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
              s.unemploymentCounterDaysUsed(daysConsumed),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textSecondary,
              ),
            ),
            Text(
              s.unemploymentCounterDaysRemaining(remaining),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
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
              s.unemploymentCounterDayZero,
              style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
            ),
            Text(
              s.unemploymentCounterDayEnd(maxDays),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: MintColors.scoreCritique,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow(S s, int remaining, double monthsRemaining) {
    return Row(
      children: [
        Expanded(child: _buildStatCard(
          label: s.unemploymentCounterDaysRemainingLabel,
          value: '$remaining',
          color: MintColors.info,
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(
          label: s.unemploymentCounterApproxLabel,
          value: s.unemploymentCounterMonthsValue(monthsRemaining.toStringAsFixed(1)),
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
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeTable(S s, int currentAge) {
    final rows = [
      (age: 24, label: '< 25 ans', days: acJoursMinCotisation),
      (age: 40, label: '25-54 ans', days: acJoursStandard),
      (age: 57, label: '\u2265 55 ans',  days: acJoursSenior),
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
                    s.unemploymentCounterAgeRange,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: MintColors.textSecondary),
                  ),
                ),
                Text(
                  s.unemploymentCounterMaxBenefits,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: MintColors.textSecondary),
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
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                        color: isActive ? MintColors.primary : MintColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    s.unemploymentCounterDaysCount(r.days),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                      color: isActive ? MintColors.primary : MintColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChiffreChoc(S s) {
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
          const Text('\u26a0\ufe0f', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.unemploymentCounterChiffreChocTitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MintColors.scoreCritique,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.unemploymentCounterChiffreChocBody,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(S s) {
    return Text(
      s.unemploymentCounterDisclaimer,
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
