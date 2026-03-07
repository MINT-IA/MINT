import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  P4-A  La Falaise — Timeline invalidité en 3 actes
//  Charte : L6 (Chiffre-choc) + L2 (Avant/Après) + L7 (Film)
//  Source : LAVS art. 28-29, LPP art. 23-26, LPGA art. 19
// ────────────────────────────────────────────────────────────

class DisabilityAct {
  const DisabilityAct({
    required this.label,
    required this.subtitle,
    required this.durationLabel,
    required this.monthlyIncome,
    required this.emoji,
    required this.color,
    this.detail,
  });

  final String label;
  final String subtitle;
  final String durationLabel;
  final double monthlyIncome;
  final String emoji;
  final Color color;
  final String? detail;
}

class DisabilityCliffWidget extends StatelessWidget {
  const DisabilityCliffWidget({
    super.key,
    required this.grossMonthly,
    required this.acts,
  });

  final double grossMonthly;
  final List<DisabilityAct> acts;

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
    final lastIncome = acts.isNotEmpty ? acts.last.monthlyIncome : grossMonthly;
    final lostMonthly = grossMonthly - lastIncome;
    final lostYearly15 = lostMonthly * 12 * 15;

    return Semantics(
      label: 'La Falaise timeline invalidité 3 actes',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(lostMonthly),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentIncome(),
                  const SizedBox(height: 20),
                  ...acts.asMap().entries.map(
                    (e) => _buildAct(e.key, e.value),
                  ),
                  const SizedBox(height: 8),
                  _buildChiffreChoc(lostMonthly, lostYearly15),
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

  Widget _buildHeader(double lostMonthly) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFFFFEBEE),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎬', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Si tu ne pouvais plus travailler demain',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'La falaise d\'invalidité en 3 actes',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentIncome() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: MintColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.work_outline, color: MintColors.primary, size: 18),
          const SizedBox(width: 10),
          Text(
            'Ton salaire actuel : CHF ${_fmt(grossMonthly)}/mois',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: MintColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAct(int index, DisabilityAct act) {
    final isLast = index == acts.length - 1;
    return Column(
      children: [
        if (index > 0) _buildArrow(),
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: act.color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: act.color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(act.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ACTE ${index + 1} · ${act.label}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: act.color,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          act.durationLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: MintColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'CHF ${_fmt(act.monthlyIncome)}',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: act.color,
                        ),
                      ),
                      Text(
                        '/mois',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (act.subtitle.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  act.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
              if (act.detail != null) ...[
                const SizedBox(height: 6),
                Text(
                  act.detail!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: act.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (isLast && acts.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: MintColors.scoreCritique.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'vs CHF ${_fmt(grossMonthly)}/mois avant',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MintColors.scoreCritique,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Icon(Icons.keyboard_arrow_down, color: MintColors.textSecondary, size: 24),
      ),
    );
  }

  Widget _buildChiffreChoc(double lostMonthly, double lostYearly15) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreCritique.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreCritique.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💰 Chiffre-choc',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.scoreCritique,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tu perdrais CHF ${_fmt(lostMonthly)}/mois.',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: MintColors.scoreCritique,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sur 15 ans = CHF ${_fmt(lostYearly15)} de revenus en moins.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '→ Action : Vérifie ta couverture LPP invalidité',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Source : LAVS art. 28-29, LPP art. 23-26.',
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
