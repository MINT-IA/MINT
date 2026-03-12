import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  TRUE HOURLY RATE WIDGET — P6-D / S42 UX Redesign
// ────────────────────────────────────────────────────────────
//
//  Décomposition : net souhaité + charges + impôts + frais
//  + vacances/maladie = CA nécessaire ÷ heures facturables
//  = tarif horaire minimum.
//
//  Widget pur — aucune dépendance Provider.
//  Lois : L1 (CHF/mois) + L7 (métaphore bat graphique)
// ────────────────────────────────────────────────────────────

/// Breakdown layer of the hourly rate composition.
class RateLayer {
  final String label;
  final double amount;
  final String emoji;

  const RateLayer({
    required this.label,
    required this.amount,
    required this.emoji,
  });
}

class TrueHourlyRateWidget extends StatelessWidget {
  /// Desired net annual income.
  final double desiredNetAnnual;

  /// Breakdown layers: taxes, social charges, business expenses, unpaid days.
  final List<RateLayer> layers;

  /// Total required annual revenue.
  final double requiredRevenue;

  /// Billable hours per year (typically 1600).
  final int billableHours;

  const TrueHourlyRateWidget({
    super.key,
    required this.desiredNetAnnual,
    required this.layers,
    required this.requiredRevenue,
    this.billableHours = 1600,
  });

  double get _hourlyRate =>
      billableHours > 0 ? requiredRevenue / billableHours : 0;
  double get _chargesPerHour =>
      billableHours > 0 ? (requiredRevenue - desiredNetAnnual) / billableHours : 0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tarif horaire v\u00e9rit\u00e9. '
          'Minimum\u00a0: ${_hourlyRate.toStringAsFixed(0)} CHF/h.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ton tarif horaire de v\u00e9rit\u00e9',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pour un net de ${formatChfWithPrefix(desiredNetAnnual)}/an',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),

            // ── Hero hourly rate ──
            Center(
              child: Column(
                children: [
                  Text(
                    '${_hourlyRate.toStringAsFixed(0)} CHF/h',
                    style: GoogleFonts.montserrat(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: MintColors.primary,
                    ),
                  ),
                  Text(
                    'minimum',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: MintColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Breakdown ──
            _buildDecomposition(),
            const SizedBox(height: 12),

            // ── Chiffre-choc ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MintColors.scoreCritique.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_hourlyRate.toStringAsFixed(0)} CHF/h '
                '\u2260 ${_hourlyRate.toStringAsFixed(0)} CHF dans ta poche.\n'
                '${_chargesPerHour.toStringAsFixed(0)} CHF partent en charges. '
                'En dessous de ${_hourlyRate.toStringAsFixed(0)} CHF/h, '
                'tu t\u2019appauvris.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: MintColors.scoreCritique,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 12),
            Text(
              'Bas\u00e9 sur $billableHours h facturables/an. '
              'Cotisations\u00a0: LAVS art. 4-14. '
              'Outil \u00e9ducatif \u2014 ne constitue pas un conseil financier (LSFin).',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: MintColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecomposition() {
    return Column(
      children: [
        // Net desired
        _buildRow('\ud83d\udcb0', 'Net souhait\u00e9', desiredNetAnnual,
            MintColors.scoreExcellent),
        ...layers.map((l) => _buildRow(l.emoji, l.label, l.amount,
            MintColors.scoreCritique)),
        const Divider(height: 12),
        // Required revenue
        _buildRow('\ud83d\udcbc', 'CA n\u00e9cessaire', requiredRevenue,
            MintColors.primary, isBold: true),
        Padding(
          padding: const EdgeInsets.only(left: 30, top: 2),
          child: Text(
            '\u00f7 $billableHours h = ${_hourlyRate.toStringAsFixed(0)} CHF/h',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(String emoji, String label, double amount, Color color,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
                color: MintColors.textPrimary,
              ),
            ),
          ),
          Text(
            formatChfWithPrefix(amount),
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
