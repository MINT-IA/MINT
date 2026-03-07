import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  List<({String label, double amount, String ref, Color color})> get _deductions => [
    (
      label: 'Hypothèque remboursée',
      amount: widget.mortgageBalance,
      ref: 'Banque',
      color: MintColors.textSecondary,
    ),
    (
      label: 'Impôt sur le gain',
      amount: widget.capitalGainTax,
      ref: 'LIFD art. 12',
      color: MintColors.scoreAttention,
    ),
    (
      label: 'Remboursement EPL',
      amount: widget.eplReimbursement,
      ref: 'LPP art. 30c',
      color: MintColors.scoreCritique,
    ),
    (
      label: 'Frais de notaire',
      amount: _notaryFees,
      ref: '${(widget.notaryFeeRate * 100).toStringAsFixed(1)}% prix',
      color: MintColors.scoreAttention,
    ),
    (
      label: 'Commission agence',
      amount: _agencyFees,
      ref: '${(widget.agencyFeeRate * 100).toStringAsFixed(1)}% prix',
      color: MintColors.scoreAttention,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Net réel vente immobilière calculateur cascade déductions',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
                  _buildWaterfallChart(),
                  const SizedBox(height: 16),
                  _buildSurprise(),
                  const SizedBox(height: 12),
                  _buildToggleDetails(),
                  if (_showDetails) ...[
                    const SizedBox(height: 12),
                    _buildDetailList(),
                  ],
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
      decoration: const BoxDecoration(
        color: Color(0xFFFFF3E0),
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
                  'Ton net réel',
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
                Text(
                  '"30% en dessous de ce que tu imagines."',
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

  Widget _buildWaterfallChart() {
    final ratio = widget.salePrice > 0 ? _netProceeds / widget.salePrice : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Prix de vente : ${formatChfWithPrefix(widget.salePrice)}',
              style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary),
            ),
            Text(
              'Net : ${formatChfWithPrefix(_netProceeds)}',
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
                    '${(ratio * 100).round()}%',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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
              'Déductions : ${formatChfWithPrefix(_totalDeductions)}',
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

  Widget _buildSurprise() {
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
                  'Surprise : − ${formatChfWithPrefix(_surprise)}',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MintColors.scoreCritique,
                  ),
                ),
                Text(
                  'Tu croyais toucher ${formatChfWithPrefix(_perceivedNet)} — tu touches ${formatChfWithPrefix(_netProceeds)}.',
                  style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleDetails() {
    return GestureDetector(
      onTap: () => setState(() => _showDetails = !_showDetails),
      child: Row(
        children: [
          Text(
            _showDetails ? 'Masquer le détail' : 'Voir le détail des déductions',
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

  Widget _buildDetailList() {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: _deductions.asMap().entries.map((e) {
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
                      '− ${formatChfWithPrefix(d.amount)}',
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

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil fiscal au sens de la LSFin. '
      'Source : LIFD art. 12 (gain), LPP art. 30c (EPL). Chiffres indicatifs.',
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
