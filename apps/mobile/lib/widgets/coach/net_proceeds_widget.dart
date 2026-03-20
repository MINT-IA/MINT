import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
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
                  'Ton net réel',
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                Text(
                  '"30% en dessous de ce que tu imagines."',
                  style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
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
              style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
            ),
            Text(
              'Net : ${formatChfWithPrefix(_netProceeds)}',
              style: MintTextStyles.bodySmall(color: MintColors.scoreExcellent).copyWith(fontWeight: FontWeight.w800),
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
                    style: MintTextStyles.labelSmall(color: MintColors.white).copyWith(fontWeight: FontWeight.w800),
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
              style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(fontStyle: FontStyle.normal),
            ),
            Text(
              'Déductions : ${formatChfWithPrefix(_totalDeductions)}',
              style: MintTextStyles.micro(color: MintColors.scoreCritique).copyWith(fontWeight: FontWeight.w600, fontStyle: FontStyle.normal),
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
                  style: MintTextStyles.titleMedium(color: MintColors.scoreCritique).copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Tu croyais toucher ${formatChfWithPrefix(_perceivedNet)} — tu touches ${formatChfWithPrefix(_netProceeds)}.',
                  style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12, height: 1.4),
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
            style: MintTextStyles.bodySmall(color: MintColors.primary).copyWith(fontWeight: FontWeight.w600),
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
                            style: MintTextStyles.labelSmall(color: MintColors.textPrimary).copyWith(fontSize: 12),
                          ),
                          Text(
                            d.ref,
                            style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(fontStyle: FontStyle.normal),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '− ${formatChfWithPrefix(d.amount)}',
                      style: MintTextStyles.bodySmall(color: d.color).copyWith(fontWeight: FontWeight.w700),
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
      style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(fontStyle: FontStyle.normal),
    );
  }
}
