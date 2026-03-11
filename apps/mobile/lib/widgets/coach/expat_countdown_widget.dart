import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  P13-B  Compte à rebours 90 jours expatriation
//  Charte : L5 (1 action) + L7 (Métaphore décompte)
//  Source : LAVS art. 2 (cotisation volontaire), LPP art. 5 (libre passage)
//           OPP3 art. 1 (3a clôture)
// ────────────────────────────────────────────────────────────

class ExpatDeadline {
  const ExpatDeadline({
    required this.label,
    required this.emoji,
    required this.daysFromDeparture,
    required this.action,
    required this.legalRef,
    this.consequence,
    this.isEuOnly = false,
  });

  final String label;
  final String emoji;
  final int daysFromDeparture;
  final String action;
  final String legalRef;
  final String? consequence;
  final bool isEuOnly;
}

class ExpatCountdownWidget extends StatefulWidget {
  const ExpatCountdownWidget({
    super.key,
    required this.departureDate,
    required this.deadlines,
    this.isEuDestination = false,
  });

  final DateTime departureDate;
  final List<ExpatDeadline> deadlines;
  final bool isEuDestination;

  @override
  State<ExpatCountdownWidget> createState() => _ExpatCountdownWidgetState();
}

class _ExpatCountdownWidgetState extends State<ExpatCountdownWidget> {
  late List<bool> _completed;

  @override
  void initState() {
    super.initState();
    _completed = List.filled(widget.deadlines.length, false);
  }

  int get _completedCount => _completed.where((c) => c).length;

  int _daysFrom(int fromDeparture) {
    final deadline = widget.departureDate.add(Duration(days: fromDeparture));
    final remaining = deadline.difference(DateTime.now()).inDays;
    return remaining;
  }

  @override
  Widget build(BuildContext context) {
    final visibleDeadlines = widget.deadlines
        .where((d) => !d.isEuOnly || widget.isEuDestination)
        .toList();

    return Semantics(
      label: 'Compte à rebours expatriation deadlines LPP 3a AVS départ',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(visibleDeadlines.length),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...visibleDeadlines.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildDeadlineCard(e.key, e.value),
                  )),
                  const SizedBox(height: 12),
                  _buildCriticalNote(),
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

  Widget _buildHeader(int count) {
    final progress = count > 0 ? _completedCount / count : 0.0;
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
              const Text('✈️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Checklist départ — deadlines légales',
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: MintColors.primary.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(MintColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$_completedCount / $count actions complétées',
            style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlineCard(int index, ExpatDeadline d) {
    final daysRemaining = _daysFrom(d.daysFromDeparture);
    final isUrgent = daysRemaining < 30 && daysRemaining >= 0;
    final isOverdue = daysRemaining < 0;
    final isDone = _completed[index];

    Color borderColor = MintColors.lightBorder;
    if (isDone) borderColor = MintColors.scoreExcellent.withValues(alpha: 0.4);
    else if (isOverdue) borderColor = MintColors.scoreCritique.withValues(alpha: 0.4);
    else if (isUrgent) borderColor = MintColors.scoreAttention.withValues(alpha: 0.4);

    return GestureDetector(
      onTap: () => setState(() => _completed[index] = !_completed[index]),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDone
              ? MintColors.scoreExcellent.withValues(alpha: 0.05)
              : isOverdue
                  ? MintColors.scoreCritique.withValues(alpha: 0.05)
                  : MintColors.appleSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => setState(() => _completed[index] = !_completed[index]),
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: isDone ? MintColors.scoreExcellent : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDone ? MintColors.scoreExcellent : MintColors.lightBorder,
                    width: 2,
                  ),
                ),
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(d.emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          d.label,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDone ? MintColors.textSecondary : MintColors.textPrimary,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      _buildDaysBadge(daysRemaining, isDone),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    d.action,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    d.legalRef,
                    style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
                  ),
                  if (d.consequence != null && !isDone) ...[
                    const SizedBox(height: 4),
                    Text(
                      '⚠️ ${d.consequence}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: MintColors.scoreAttention,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysBadge(int days, bool isDone) {
    if (isDone) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: MintColors.scoreExcellent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '✓ Fait',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: MintColors.scoreExcellent),
        ),
      );
    }
    if (days < 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: MintColors.scoreCritique,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'En retard',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      );
    }
    final color = days < 30 ? MintColors.scoreAttention : MintColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'J${days >= 0 ? '+' : ''}$days',
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildCriticalNote() {
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
          const Text('🔑', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Chaque jour de retard peut te coûter un formulaire de plus '
              'ou des droits irréversibles. Le libre passage LPP doit être transféré avant ton départ.',
              style: GoogleFonts.inter(fontSize: 12, color: MintColors.textPrimary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil juridique au sens de la LSFin. '
      'Source : LAVS art. 2, LPP art. 5 (libre passage), OPP3 art. 1.',
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
