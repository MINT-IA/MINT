import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  PILLAR DECOMPOSITION — LOT 4 / Retirement Dashboard
// ────────────────────────────────────────────────────────────
//
//  Decomposition du revenu de retraite par pilier.
//  Barres horizontales proportionnelles + labels + montants.
//
//  Piliers :
//    AVS  (1er pilier)   → MintColors.retirementAvs   (bleu)
//    LPP  (2eme pilier)  → MintColors.retirementLpp   (vert)
//    3a   (3eme pilier)  → MintColors.retirement3a    (violet)
//    Libre (epargne)     → MintColors.retirementLibre (teal)
//
//  Widget pur — aucune dependance Provider.
// ────────────────────────────────────────────────────────────

class PillarDecomposition extends StatefulWidget {
  /// Rente AVS mensuelle (1er pilier). CHF/mois.
  final double avsMonthly;

  /// Rente LPP mensuelle (2eme pilier, user). CHF/mois.
  final double lppMonthly;

  /// Revenu mensuel 3a annualise. CHF/mois.
  final double threeAMonthly;

  /// Revenu mensuel libre (epargne / investissements). CHF/mois.
  final double freeMonthly;

  /// Rente AVS conjoint (couple only). CHF/mois.
  final double avsConjointMonthly;

  /// Rente LPP conjoint (couple only). CHF/mois.
  final double lppConjointMonthly;

  const PillarDecomposition({
    super.key,
    required this.avsMonthly,
    required this.lppMonthly,
    required this.threeAMonthly,
    required this.freeMonthly,
    this.avsConjointMonthly = 0,
    this.lppConjointMonthly = 0,
  });

  @override
  State<PillarDecomposition> createState() => _PillarDecompositionState();
}

class _PillarDecompositionState extends State<PillarDecomposition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(PillarDecomposition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avsMonthly != widget.avsMonthly ||
        oldWidget.lppMonthly != widget.lppMonthly ||
        oldWidget.threeAMonthly != widget.threeAMonthly ||
        oldWidget.freeMonthly != widget.freeMonthly ||
        oldWidget.avsConjointMonthly != widget.avsConjointMonthly ||
        oldWidget.lppConjointMonthly != widget.lppConjointMonthly) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasConjoint =>
      widget.avsConjointMonthly > 0 || widget.lppConjointMonthly > 0;

  double get _total =>
      widget.avsMonthly +
      widget.lppMonthly +
      widget.threeAMonthly +
      widget.freeMonthly +
      widget.avsConjointMonthly +
      widget.lppConjointMonthly;

  @override
  Widget build(BuildContext context) {
    final total = _total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          if (total <= 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Compl\u00e8te ton profil pour voir la d\u00e9composition par pilier.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MintColors.textSecondary,
                ),
              ),
            )
          else
          AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              return Column(
                children: [
                  _buildPillarRow(
                    label: _hasConjoint ? '1er pilier (AVS toi)' : '1er pilier (AVS)',
                    amount: widget.avsMonthly,
                    total: total,
                    color: MintColors.retirementAvs,
                    icon: Icons.shield_outlined,
                    progress: _animation.value,
                  ),
                  const SizedBox(height: 10),
                  _buildPillarRow(
                    label: _hasConjoint ? '2\u00e8me pilier (LPP toi)' : '2\u00e8me pilier (LPP)',
                    amount: widget.lppMonthly,
                    total: total,
                    color: MintColors.retirementLpp,
                    icon: Icons.account_balance_outlined,
                    progress: _animation.value,
                  ),
                  if (_hasConjoint && widget.avsConjointMonthly > 0) ...[
                    const SizedBox(height: 10),
                    _buildPillarRow(
                      label: '1er pilier (AVS conjoint\u00b7e)',
                      amount: widget.avsConjointMonthly,
                      total: total,
                      color: MintColors.retirementAvs.withValues(alpha: 0.65),
                      icon: Icons.shield_outlined,
                      progress: _animation.value,
                    ),
                  ],
                  if (_hasConjoint && widget.lppConjointMonthly > 0) ...[
                    const SizedBox(height: 10),
                    _buildPillarRow(
                      label: '2\u00e8me pilier (LPP conjoint\u00b7e)',
                      amount: widget.lppConjointMonthly,
                      total: total,
                      color: const Color(0xFF5C6BC0),
                      icon: Icons.account_balance_outlined,
                      progress: _animation.value,
                    ),
                  ],
                  const SizedBox(height: 10),
                  _buildPillarRow(
                    label: '3\u00e8me pilier (3a)',
                    amount: widget.threeAMonthly,
                    total: total,
                    color: MintColors.retirement3a,
                    icon: Icons.savings_outlined,
                    progress: _animation.value,
                  ),
                  const SizedBox(height: 10),
                  _buildPillarRow(
                    label: 'Libre / \u00e9pargne',
                    amount: widget.freeMonthly,
                    total: total,
                    color: MintColors.retirementLibre,
                    icon: Icons.trending_up,
                    progress: _animation.value,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: MintColors.lightBorder),
          const SizedBox(height: 12),
          _buildTotalRow(total),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      'D\u00e9composition par pilier',
      style: GoogleFonts.montserrat(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: MintColors.textPrimary,
      ),
    );
  }

  Widget _buildPillarRow({
    required String label,
    required double amount,
    required double total,
    required Color color,
    required IconData icon,
    required double progress,
  }) {
    final fraction = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;
    final animatedFraction = fraction * progress;

    return Row(
      children: [
        // Icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        // Label + bar
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    height: 7,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: MintColors.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 7,
                        width: constraints.maxWidth * animatedFraction,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Amount
        SizedBox(
          width: 80,
          child: Text(
            amount > 0 ? formatChfWithPrefix(amount) : '—',
            textAlign: TextAlign.right,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: amount > 0 ? MintColors.textPrimary : MintColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalRow(double total) {
    return Row(
      children: [
        const SizedBox(width: 42),
        Expanded(
          child: Text(
            'Total mensuel estim\u00e9',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
        ),
        Text(
          formatChfWithPrefix(total),
          style: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: MintColors.primary,
          ),
        ),
      ],
    );
  }

}
