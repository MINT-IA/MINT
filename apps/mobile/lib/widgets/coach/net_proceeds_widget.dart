import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  P15-B  Le Calculateur de net réel — vente immobilière
//  Charte : L1 (CHF/mois) + L2 (Avant/Après)
//  Source : LIFD art. 12, LPP art. 30c
// ────────────────────────────────────────────────────────────

class NetProceedsWidget extends StatefulWidget {
  const NetProceedsWidget({
    super.key,
    required this.salePrice,
    required this.mortgageBalance,
    required this.capitalGainTax,
    required this.eplReimbursement,
    this.notaryFeeRate = 0.015,
    this.agencyFeeRate = 0.025,
  });

  final double salePrice;
  final double mortgageBalance;
  final double capitalGainTax;
  final double eplReimbursement;
  final double notaryFeeRate;
  final double agencyFeeRate;

  @override
  State<NetProceedsWidget> createState() => _NetProceedsWidgetState();
}

class _NetProceedsWidgetState extends State<NetProceedsWidget> {
  bool _showDetails = false;

  double get _notaryFees => widget.salePrice * widget.notaryFeeRate;
  double get _agencyFees => widget.salePrice * widget.agencyFeeRate;
  double get _totalDeductions =>
      widget.mortgageBalance +
      widget.capitalGainTax +
      widget.eplReimbursement +
      _notaryFees +
      _agencyFees;
  double get _netProceeds => (widget.salePrice - _totalDeductions).clamp(0, double.infinity);
  double get _perceivedNet => widget.salePrice - widget.mortgageBalance;
  double get _surprise => _perceivedNet - _netProceeds;

  List<({String label, double amount, String ref, Color color})> _deductions(S s) => [
    (
      label: s.netProceedsMortgageLabel,
      amount: widget.mortgageBalance,
      ref: s.netProceedsMortgageRef,
      color: MintColors.textSecondary,
    ),
    (
      label: s.netProceedsCapitalGainLabel,
      amount: widget.capitalGainTax,
      ref: s.netProceedsCapitalGainRef,
      color: MintColors.scoreAttention,
    ),
    (
      label: s.netProceedsEplLabel,
      amount: widget.eplReimbursement,
      ref: s.netProceedsEplRef,
      color: MintColors.scoreCritique,
    ),
    (
      label: s.netProceedsNotaryLabel,
      amount: _notaryFees,
      ref: s.netProceedsFeePercent((widget.notaryFeeRate * 100).toStringAsFixed(1)),
      color: MintColors.scoreAttention,
    ),
    (
      label: s.netProceedsAgencyLabel,
      amount: _agencyFees,
      ref: s.netProceedsFeePercent((widget.agencyFeeRate * 100).toStringAsFixed(1)),
      color: MintColors.scoreAttention,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Semantics(
      label: s.netProceedsSemantics,
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(s),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWaterfallChart(s),
                  const SizedBox(height: 16),
                  _buildSurprise(s),
                  const SizedBox(height: 12),
                  _buildToggleDetails(s),
                  if (_showDetails) ...[
                    const SizedBox(height: 12),
                    _buildDetailList(s),
                  ],
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

  Widget _buildHeader(S s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Text('💰', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.netProceedsTitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
                Text(
                  s.netProceedsSubtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterfallChart(S s) {
    final ratio = widget.salePrice > 0 ? _netProceeds / widget.salePrice : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              s.netProceedsSalePrice(formatChfWithPrefix(widget.salePrice)),
              style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary),
            ),
            Text(
              s.netProceedsNet(formatChfWithPrefix(_netProceeds)),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: MintColors.scoreExcellent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Container(
                height: 24,
                decoration: BoxDecoration(
                  color: MintColors.scoreCritique.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio.clamp(0.0, 1.0),
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: MintColors.scoreExcellent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${(ratio * 100).round()}\u00a0%',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: MintColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CHF 0',
              style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
            ),
            Text(
              s.netProceedsDeductions(formatChfWithPrefix(_totalDeductions)),
              style: GoogleFonts.inter(
                fontSize: 10,
                color: MintColors.scoreCritique,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSurprise(S s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreCritique.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreCritique.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Text('😱', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.netProceedsSurprise(formatChfWithPrefix(_surprise)),
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MintColors.scoreCritique,
                  ),
                ),
                Text(
                  s.netProceedsSurpriseDetail(formatChfWithPrefix(_perceivedNet), formatChfWithPrefix(_netProceeds)),
                  style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleDetails(S s) {
    return GestureDetector(
      onTap: () => setState(() => _showDetails = !_showDetails),
      child: Row(
        children: [
          Text(
            _showDetails ? s.netProceedsHideDetail : s.netProceedsShowDetail,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MintColors.primary,
            ),
          ),
          Icon(
            _showDetails ? Icons.expand_less : Icons.expand_more,
            color: MintColors.primary,
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailList(S s) {
    final deductions = _deductions(s);
    return Container(
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: deductions.asMap().entries.map((e) {
          final d = e.value;
          return Column(
            children: [
              if (e.key > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.label,
                            style: GoogleFonts.inter(fontSize: 12, color: MintColors.textPrimary),
                          ),
                          Text(
                            d.ref,
                            style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '\u2212\u00a0${formatChfWithPrefix(d.amount)}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: d.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDisclaimer(S s) {
    return Text(
      s.netProceedsDisclaimer,
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
