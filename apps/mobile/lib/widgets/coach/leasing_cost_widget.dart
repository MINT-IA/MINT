import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'dart:math' as math;

// ────────────────────────────────────────────────────────────
//  P10-D  Le coût caché du leasing vs investissement
//  Charte : L6 (Chiffre-choc) + L2 (Avant/Après)
//  Source : CO art. 255 (leasing), LPP calcul opportunité
// ────────────────────────────────────────────────────────────

class LeasingCostWidget extends StatefulWidget {
  const LeasingCostWidget({
    super.key,
    required this.vehiclePrice,
    required this.monthlyLeasing,
    this.leasingDurationMonths = 48,
    this.annualReturnRate = 0.05,
  });

  final double vehiclePrice;
  final double monthlyLeasing;
  final int leasingDurationMonths;
  final double annualReturnRate;

  @override
  State<LeasingCostWidget> createState() => _LeasingCostWidgetState();
}

class _LeasingCostWidgetState extends State<LeasingCostWidget> {
  late double _monthly;

  @override
  void initState() {
    super.initState();
    _monthly = widget.monthlyLeasing;
  }

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  double get _totalLeasing => _monthly * widget.leasingDurationMonths;

  /// Future value of investing _monthly each month at annualReturnRate.
  double _futureValue(int months) {
    final monthlyRate = widget.annualReturnRate / 12;
    if (monthlyRate == 0) return _monthly * months;
    // FV of annuity: PMT × [(1+r)^n - 1] / r
    return _monthly *
        (math.pow(1 + monthlyRate, months) - 1) /
        monthlyRate;
  }

  double get _opportunityCost {
    final fv = _futureValue(widget.leasingDurationMonths);
    return fv - _totalLeasing;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Leasing coût caché opportunité investissement comparaison',
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
                  _buildMonthlySlider(),
                  const SizedBox(height: 16),
                  _buildComparison(),
                  const SizedBox(height: 16),
                  _buildOpportunityCost(),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.scoreAttention.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🚗', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Le vrai coût du leasing',
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatChip(
                label: 'Véhicule : CHF ${_fmt(widget.vehiclePrice)}',
                color: MintColors.textSecondary,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                label: '${widget.leasingDurationMonths ~/ 12} ans',
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMonthlySlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Mensualité leasing',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: MintColors.scoreAttention.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'CHF ${_fmt(_monthly)}/mois',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.scoreAttention,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: _monthly,
          min: 200,
          max: 1500,
          divisions: 26,
          activeColor: MintColors.scoreAttention,
          onChanged: (v) => setState(() => _monthly = (v / 50).round() * 50.0),
        ),
      ],
    );
  }

  Widget _buildComparison() {
    return Row(
      children: [
        Expanded(child: _buildScenarioCard(
          emoji: '🔑',
          label: 'Leasing',
          subtitle: '${widget.leasingDurationMonths ~/ 12} ans de mensualités',
          value: 'CHF ${_fmt(_totalLeasing)}',
          subValue: 'total payé',
          color: MintColors.scoreCritique,
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildScenarioCard(
          emoji: '💸',
          label: 'Achat cash',
          subtitle: 'Valeur résiduelle ~45%',
          value: 'CHF ${_fmt(widget.vehiclePrice * 0.55)}',
          subValue: 'dépréciation réelle',
          color: MintColors.scoreAttention,
        )),
      ],
    );
  }

  Widget _buildScenarioCard({
    required String emoji,
    required String label,
    required String subtitle,
    required String value,
    required String subValue,
    required Color color,
  }) {
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
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            subValue,
            style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildOpportunityCost() {
    final fv = _futureValue(widget.leasingDurationMonths);

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
          Row(
            children: [
              const Text('📈', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Text(
                'Le vrai coût caché',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.scoreCritique,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Si tu avais investi CHF ${_fmt(_monthly)}/mois sur ${widget.leasingDurationMonths ~/ 12} ans '
            'à ${(widget.annualReturnRate * 100).toStringAsFixed(0)}%/an :',
            style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Capital accumulé',
                style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary),
              ),
              Text(
                'CHF ${_fmt(fv)}',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MintColors.scoreExcellent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Au lieu du leasing',
                style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary),
              ),
              Text(
                '− CHF ${_fmt(_totalLeasing)}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.scoreCritique,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Coût d\'opportunité',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                'CHF ${_fmt(_opportunityCost + _totalLeasing)}',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: MintColors.scoreCritique,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'C\'est ce que ton leasing te coûte vraiment sur ${widget.leasingDurationMonths ~/ 12} ans.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textSecondary,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Source : CO art. 255 (leasing). '
      'Rendement simulé à ${(widget.annualReturnRate * 100).toStringAsFixed(0)}% — ne garantit pas de rendement futur.',
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
