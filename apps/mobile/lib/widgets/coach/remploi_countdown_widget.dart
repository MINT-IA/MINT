import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  P15-C  Le Chrono du remploi — 2 ans pour racheter
//  Charte : L5 (1 action) + L7 (Métaphore chrono)
//  Source : LIFD art. 12 al. 3 (remploi résidence principale)
// ────────────────────────────────────────────────────────────

class RemploiCountdownWidget extends StatefulWidget {
  const RemploiCountdownWidget({
    super.key,
    required this.saleDate,
    required this.deferredTax,
  });

  final DateTime saleDate;
  final double deferredTax;

  @override
  State<RemploiCountdownWidget> createState() => _RemploiCountdownWidgetState();
}

class _RemploiCountdownWidgetState extends State<RemploiCountdownWidget> {
  static const _remploidDeadlineYears = 2;

  DateTime get _deadline {
    return DateTime(
      widget.saleDate.year + _remploidDeadlineYears,
      widget.saleDate.month,
      widget.saleDate.day,
    );
  }

  int get _totalDays => _deadline.difference(widget.saleDate).inDays;
  int get _daysElapsed => DateTime.now().difference(widget.saleDate).inDays.clamp(0, _totalDays);
  int get _daysRemaining => (_totalDays - _daysElapsed).clamp(0, _totalDays);
  int get _monthsRemaining => (_daysRemaining / 30.44).floor();
  double get _fraction => _totalDays > 0 ? _daysElapsed / _totalDays : 0;

  Color get _urgencyColor {
    if (_fraction < 0.5) return MintColors.scoreExcellent;
    if (_fraction < 0.75) return MintColors.scoreAttention;
    return MintColors.scoreCritique;
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _daysRemaining == 0;

    return Semantics(
      label: 'Compte à rebours remploi vente immobilière 2 ans LIFD',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isExpired),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTimer(isExpired),
                  const SizedBox(height: 16),
                  _buildProgressBar(),
                  const SizedBox(height: 16),
                  _buildExplanation(isExpired),
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

  Widget _buildHeader(bool isExpired) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isExpired
            ? MintColors.scoreCritique.withValues(alpha: 0.1)
            : MintColors.warningBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Text(isExpired ? '⛔' : '⏱️', style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chrono du remploi',
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
                Text(
                  isExpired
                      ? 'Délai écoulé — l\'impôt est dû.'
                      : 'Tu as ${_remploidDeadlineYears} ans pour racheter une résidence principale.',
                  style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimer(bool isExpired) {
    if (isExpired) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.scoreCritique.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.scoreCritique.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              '0',
              style: GoogleFonts.montserrat(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: MintColors.scoreCritique,
              ),
            ),
            Text(
              'jours restants',
              style: GoogleFonts.inter(fontSize: 14, color: MintColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Impôt dû : ${formatChfWithPrefix(widget.deferredTax)}',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: MintColors.scoreCritique,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(child: _buildTimerCard('$_daysRemaining', 'jours restants', _urgencyColor)),
        const SizedBox(width: 12),
        Expanded(child: _buildTimerCard('$_monthsRemaining', 'mois environ', MintColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: _buildTimerCard(
          formatChfWithPrefix(widget.deferredTax),
          'impôt à éviter',
          MintColors.scoreAttention,
        )),
      ],
    );
  }

  Widget _buildTimerCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: value.length > 6 ? 14 : 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Vente : ${_formatDate(widget.saleDate)}',
              style: GoogleFonts.inter(fontSize: 11, color: MintColors.textSecondary),
            ),
            Text(
              'Délai : ${_formatDate(_deadline)}',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _urgencyColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _fraction,
            minHeight: 12,
            backgroundColor: _urgencyColor.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(_urgencyColor),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$_daysElapsed jours écoulés sur $_totalDays',
          style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildExplanation(bool isExpired) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (isExpired ? MintColors.scoreCritique : MintColors.info).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isExpired ? MintColors.scoreCritique : MintColors.info).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isExpired ? '⚠️' : '💡', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isExpired
                  ? 'Le délai de remploi est dépassé. L\'impôt sur le gain de '
                    '${formatChfWithPrefix(widget.deferredTax)} est dû. Contacte l\'administration fiscale cantonale.'
                  : 'Si tu achètes une nouvelle résidence principale avant le ${_formatDate(_deadline)}, '
                    'l\'impôt de ${formatChfWithPrefix(widget.deferredTax)} est différé. '
                    'LIFD art. 12 al. 3.',
              style: GoogleFonts.inter(fontSize: 12, color: MintColors.textPrimary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil fiscal au sens de la LSFin. '
      'Source : LIFD art. 12 al. 3 (remploi résidence principale). '
      'Délai de 2 ans — vérifier les règles cantonales spécifiques.',
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
