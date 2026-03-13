import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  COUPLE PHASE TIMELINE — P5 / Couple Interactif
// ────────────────────────────────────────────────────────────
//
//  Affiche la timeline des phases de retraite en couple :
//    Phase 1 : Un·e partenaire à la retraite, l'autre travaille
//    Phase 2 : Les deux à la retraite
//
//  P5 : slider interactif "Et si [conjoint] à X ans ?"
//  Recalcul temps réel via RetirementProjectionService.project().
//
//  Aucun terme banni (garanti, certain, optimal, meilleur…).
// ────────────────────────────────────────────────────────────

class CouplePhaseTimeline extends StatefulWidget {
  final String userName;
  final String conjointName;
  final int userRetirementYear;
  final int conjointRetirementYear;
  final List<RetirementPhase> phases;

  /// Profile for "Et si" recalculation (optional).
  /// If null, slider is hidden.
  final CoachProfile? profile;

  const CouplePhaseTimeline({
    super.key,
    required this.userName,
    required this.conjointName,
    required this.userRetirementYear,
    required this.conjointRetirementYear,
    required this.phases,
    this.profile,
  });

  @override
  State<CouplePhaseTimeline> createState() => _CouplePhaseTimelineState();
}

class _CouplePhaseTimelineState extends State<CouplePhaseTimeline> {
  /// Current conjoint retirement age for the slider.
  late double _sliderAge;

  /// Default conjoint retirement age (from profile).
  late int _defaultAge;

  /// Recalculated phases when slider moves (null = use original).
  List<RetirementPhase>? _recalcPhases;

  /// Debounce timer for slider recalculation.
  Timer? _recalcTimer;

  /// Whether the slider has been moved from default.
  bool get _isModified => _sliderAge.round() != _defaultAge;

  @override
  void initState() {
    super.initState();
    _defaultAge = widget.profile?.conjoint?.effectiveRetirementAge ?? 65;
    _sliderAge = _defaultAge.toDouble();
  }

  @override
  void didUpdateWidget(covariant CouplePhaseTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conjointRetirementYear != widget.conjointRetirementYear) {
      _defaultAge = widget.profile?.conjoint?.effectiveRetirementAge ?? 65;
      _sliderAge = _defaultAge.toDouble();
      _recalcPhases = null;
    }
  }

  List<RetirementPhase> get _activePhases => _recalcPhases ?? widget.phases;

  int get _activeConjointYear {
    if (_recalcPhases != null && widget.profile?.conjoint?.birthYear != null) {
      return widget.profile!.conjoint!.birthYear! + _sliderAge.round();
    }
    return widget.conjointRetirementYear;
  }

  void _onSliderChanged(double value) {
    setState(() {
      _sliderAge = value;
    });
    _recalcTimer?.cancel();
    _recalcTimer = Timer(const Duration(milliseconds: 200), _recalculate);
  }

  @override
  void dispose() {
    _recalcTimer?.cancel();
    super.dispose();
  }

  void _recalculate() {
    final profile = widget.profile;
    if (profile == null || profile.conjoint == null) return;

    final newAge = _sliderAge.round();
    if (newAge == _defaultAge) {
      setState(() => _recalcPhases = null);
      return;
    }

    try {
      final result = RetirementProjectionService.project(
        profile: profile,
        retirementAgeConjoint: newAge,
      );
      if (mounted) {
        setState(() {
          _recalcPhases = result.phases.length >= 2 ? result.phases : null;
        });
      }
    } catch (_) {
      // Projection error — keep original phases
    }
  }

  void _resetSlider() {
    setState(() {
      _sliderAge = _defaultAge.toDouble();
      _recalcPhases = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.phases.length < 2) return const SizedBox.shrink();

    final phases = _activePhases;
    final conjYear = _activeConjointYear;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MintColors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: MintColors.indigo.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.people_outline_rounded,
                  color: MintColors.indigo,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Timeline couple',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Retirement dates summary
          _buildRetirementDate(
            name: widget.userName,
            year: widget.userRetirementYear,
            color: MintColors.info,
          ),
          const SizedBox(height: 6),
          _buildRetirementDate(
            name: widget.conjointName,
            year: conjYear,
            color: MintColors.purple,
            isModified: _isModified,
          ),
          const SizedBox(height: 16),

          // ── P5: "Et si" slider ──────────────────────────
          if (widget.profile != null) ...[
            _buildEtSiSlider(),
            const SizedBox(height: 16),
          ],

          // Phase timeline
          ...phases.asMap().entries.map((entry) {
            final index = entry.key;
            final phase = entry.value;
            final isLast = index == phases.length - 1;
            return _buildPhaseRow(phase, isLast);
          }),

          const SizedBox(height: 10),
          Text(
            'Projection \u00e9ducative. Les dates et montants sont '
            'des estimations qui peuvent varier (LSFin).',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEtSiSlider() {
    final conjName = widget.conjointName;
    final currentAge = _sliderAge.round();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.purple.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isModified
              ? MintColors.purple.withValues(alpha: 0.20)
              : MintColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 16,
                color: MintColors.purple,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Et si $conjName \u00e0 $currentAge\u00a0ans\u00a0?',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _isModified
                        ? MintColors.purple
                        : MintColors.textPrimary,
                  ),
                ),
              ),
              if (_isModified)
                GestureDetector(
                  onTap: _resetSlider,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MintColors.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'R\u00e9initialiser',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: MintColors.purple,
              inactiveTrackColor: MintColors.purple.withValues(alpha: 0.15),
              thumbColor: MintColors.purple,
              overlayColor: MintColors.purple.withValues(alpha: 0.08),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _sliderAge,
              min: 58,
              max: 70,
              divisions: 12,
              label: '$currentAge ans',
              onChanged: _onSliderChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '58 ans',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: MintColors.textMuted,
                ),
              ),
              Text(
                '70 ans',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: MintColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRetirementDate({
    required String name,
    required int year,
    required Color color,
    bool isModified = false,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$name\u00a0: retraite en $year',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isModified ? MintColors.purple : MintColors.textPrimary,
            ),
          ),
        ),
        if (isModified)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: MintColors.purple.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'modifi\u00e9',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: MintColors.purple,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhaseRow(RetirementPhase phase, bool isLast) {
    final yearRange = phase.endYear != null
        ? '${phase.startYear}\u2013${phase.endYear}'
        : '${phase.startYear}+';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot + line
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isLast ? MintColors.success : MintColors.info,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: MintColors.card,
                    width: 2,
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 50,
                  color: MintColors.lightBorder,
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MintColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        yearRange,
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: MintColors.info,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          phase.label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: MintColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Revenu m\u00e9nage\u00a0: ${_formatChf(phase.totalMonthly)}/mois',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Income sources breakdown (compact)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: phase.sources
                        .where((s) => s.monthlyAmount > 0)
                        .map((s) => Text(
                              '${s.label}\u00a0: ${_formatChf(s.monthlyAmount)}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: MintColors.textMuted,
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatChf(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write("'");
      buffer.write(str[i]);
    }
    return 'CHF\u00a0${buffer.toString()}';
  }
}
