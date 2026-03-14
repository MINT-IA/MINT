import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  P5-A  Le Film du premier salaire — 5 actes
//  Charte : L1 (CHF/mois) + L2 (Avant/Après) + L4 (Raconte) + L7 (Film)
//  Source : LAVS art. 3 (AVS 5.30%), LPP art. 7, LACI art. 3 (AC 1.10%),
//           OPP3 art. 7 (3a plafond 7'258 CHF)
// ────────────────────────────────────────────────────────────

class FirstSalaryFilmWidget extends StatefulWidget {
  const FirstSalaryFilmWidget({
    super.key,
    required this.grossMonthly,
  });

  final double grossMonthly;

  @override
  State<FirstSalaryFilmWidget> createState() => _FirstSalaryFilmWidgetState();
}

class _FirstSalaryFilmWidgetState extends State<FirstSalaryFilmWidget> {
  int _currentAct = 0;

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  // Act 1 — Douche froide: brut → net
  double get _avsEmployee => widget.grossMonthly * avsCotisationSalarie;  // LAVS art. 3
  double get _lppEmployee => widget.grossMonthly * 0.035;       // LPP (avg age 25)
  double get _ac => widget.grossMonthly * acCotisationSalarie;  // LACI art. 3
  double get _aanp => widget.grossMonthly * 0.013;              // LAA
  double get _totalDeductions => _avsEmployee + _lppEmployee + _ac + _aanp;
  double get _netMonthly => widget.grossMonthly - _totalDeductions;

  // Act 2 — Argent invisible: employeur
  double get _avsEmployer => widget.grossMonthly * 0.053;
  double get _lppEmployer => widget.grossMonthly * 0.035;
  double get _ijmEmployer => widget.grossMonthly * 0.006;
  double get _totalEmployerCost => widget.grossMonthly + _avsEmployer + _lppEmployer + _ijmEmployer;

  // Act 3 — Cadeau fiscal 3a
  static const double _monthly3a = pilier3aPlafondAvecLpp / 12;  // OPP3 art. 7
  static const double _return3a = 0.04;            // 4% annuel
  double _project3a(int years) {
    double acc = 0;
    for (int y = 0; y < years; y++) {
      acc = (acc + _monthly3a * 12) * (1 + _return3a);
    }
    return acc;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final acts = [
      _buildAct1(s),
      _buildAct2(s),
      _buildAct3(s),
      _buildAct4(s),
      _buildAct5(s),
    ];

    return Semantics(
      label: 'Film premier salaire 5 actes AVS LPP 3a LAMal douche froide',
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
            _buildActSelector(s),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  acts[_currentAct],
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
      decoration: BoxDecoration(
        color: MintColors.scoreExcellent.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('\u{1F3AC}', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.firstSalaryFilmTitle,
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
          Text(
            s.firstSalaryFilmSubtitle(_fmt(widget.grossMonthly)),
            style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildActSelector(S s) {
    final actLabels = [
      s.firstSalaryFilmTab1,
      s.firstSalaryFilmTab2,
      s.firstSalaryFilmTab3,
      s.firstSalaryFilmTab4,
      s.firstSalaryFilmTab5,
    ];

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        border: Border(bottom: BorderSide(color: MintColors.lightBorder)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final selected = _currentAct == i;
          return GestureDetector(
            onTap: () => setState(() => _currentAct = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? MintColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? MintColors.primary : MintColors.lightBorder,
                ),
              ),
              child: Text(
                actLabels[i],
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? MintColors.white : MintColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAct1(S s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.firstSalaryFilmAct1Title,
          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800, color: MintColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          s.firstSalaryFilmAct1Quote(_fmt(_totalDeductions)),
          style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary, height: 1.4, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
        _buildSalaryBar(s),
        const SizedBox(height: 16),
        _buildDeductionRows(s),
      ],
    );
  }

  Widget _buildSalaryBar(S s) {
    final netRatio = _netMonthly / widget.grossMonthly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(s.firstSalaryBrutLabel(_fmt(widget.grossMonthly)), style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary)),
            Text(s.firstSalaryNetLabel(_fmt(_netMonthly)), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: MintColors.scoreExcellent)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Container(height: 28, color: MintColors.scoreCritique.withValues(alpha: 0.2)),
              FractionallySizedBox(
                widthFactor: netRatio,
                child: Container(
                  height: 28,
                  color: MintColors.scoreExcellent,
                  alignment: Alignment.center,
                  child: Text(
                    s.firstSalaryFilmNetPercent((netRatio * 100).round().toString()),
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: MintColors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeductionRows(S s) {
    final rows = [
      (s.firstSalaryFilmDeductionAvs, _avsEmployee, 'LAVS art. 3'),
      (s.firstSalaryFilmDeductionLpp, _lppEmployee, 'LPP art. 7'),
      (s.firstSalaryFilmDeductionAc, _ac, 'LACI art. 3'),
      (s.firstSalaryFilmDeductionAanp, _aanp, 'LAA art. 6'),
    ];
    return Column(
      children: rows.map((r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(r.$1, style: GoogleFonts.inter(fontSize: 12, color: MintColors.textPrimary))),
            Text(s.firstSalaryFilmDeductionAmount(_fmt(r.$2)), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: MintColors.scoreCritique)),
            const SizedBox(width: 8),
            Text(r.$3, style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildAct2(S s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.firstSalaryFilmAct2Title,
          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800, color: MintColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          s.firstSalaryFilmAct2Quote(_fmt(_totalEmployerCost)),
          style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary, height: 1.4, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
        _buildIcebergCards(s),
      ],
    );
  }

  Widget _buildIcebergCards(S s) {
    return Column(
      children: [
        _buildCostCard(s.firstSalaryFilmVisibleNet, _netMonthly, MintColors.scoreExcellent, s.firstSalaryFilmVisibleNetSub),
        const SizedBox(height: 6),
        _buildCostCard(s.firstSalaryFilmYourContributions, _totalDeductions, MintColors.scoreAttention, s.firstSalaryFilmYourContributionsSub),
        const SizedBox(height: 6),
        _buildCostCard(s.firstSalaryFilmEmployerContributions, _avsEmployer + _lppEmployer + _ijmEmployer, MintColors.info, s.firstSalaryFilmEmployerContributionsSub),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: MintColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.firstSalaryEmployerCost, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: MintColors.textPrimary)),
              Text(
                s.firstSalaryFilmChfPerMonth(_fmt(_totalEmployerCost)),
                style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w800, color: MintColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCostCard(String label, double amount, Color color, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: MintColors.textPrimary)),
                Text(sub, style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary)),
              ],
            ),
          ),
          Text(
            S.of(context)!.firstSalaryChfValue(_fmt(amount)),
            style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildAct3(S s) {
    final at30 = _project3a(5);   // 25+5 = 30 ans
    final at40 = _project3a(15);  // 25+15 = 40 ans
    final at65 = _project3a(40);  // 25+40 = 65 ans

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.firstSalaryFilmAct3Title,
          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800, color: MintColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          s.firstSalaryFilmAct3Quote(_fmt(_monthly3a)),
          style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary, height: 1.4, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
        _buildProjectionBar(s.firstSalaryFilmAt30, at30, at65, s),
        const SizedBox(height: 8),
        _buildProjectionBar(s.firstSalaryFilmAt40, at40, at65, s),
        const SizedBox(height: 8),
        _buildProjectionBar(s.firstSalaryFilmAt65, at65, at65, s),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MintColors.scoreExcellent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            s.firstSalaryFilm3aInfo,
            style: GoogleFonts.inter(fontSize: 11, color: MintColors.scoreExcellent, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectionBar(String label, double value, double max, S s) {
    final ratio = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary)),
            Text(s.firstSalaryChfValue(_fmt(value)), style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w800, color: MintColors.primary)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: MintColors.primary.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(MintColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildAct4(S s) {
    final franchises = [
      (label: 'CHF 300/an', monthly: 25.0, advice: s.firstSalaryFilmFranchise300Advice, isRecommended: false),
      (label: 'CHF 1\'500/an', monthly: 125.0, advice: s.firstSalaryFilmFranchise1500Advice, isRecommended: true),
      (label: 'CHF 2\'500/an', monthly: 208.0, advice: s.firstSalaryFilmFranchise2500Advice, isRecommended: false),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.firstSalaryFilmAct4Title,
          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800, color: MintColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          s.firstSalaryFilmAct4Quote,
          style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary, height: 1.4, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
        ...franchises.map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: f.isRecommended
                  ? MintColors.scoreExcellent.withValues(alpha: 0.07)
                  : MintColors.appleSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: f.isRecommended
                    ? MintColors.scoreExcellent.withValues(alpha: 0.3)
                    : MintColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.firstSalaryFranchiseLabel(f.label), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: MintColors.textPrimary)),
                      Text(f.advice, style: GoogleFonts.inter(fontSize: 11, color: MintColors.textSecondary)),
                    ],
                  ),
                ),
                Text(
                  s.firstSalaryFilmPrimeMonthly(_fmt(f.monthly)),
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: MintColors.primary),
                ),
              ],
            ),
          ),
        )),
        const SizedBox(height: 4),
        Text(
          s.firstSalaryFilmLamalInfo,
          style: GoogleFonts.inter(fontSize: 11, color: MintColors.info, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildAct5(S s) {
    final checklist = [
      (week: s.firstSalaryFilmWeek1, emoji: '\u{1F3E6}', task: s.firstSalaryFilmTask1),
      (week: s.firstSalaryFilmWeek1, emoji: '\u2699\uFE0F', task: s.firstSalaryFilmTask2),
      (week: s.firstSalaryFilmWeek2, emoji: '\u{1F3E5}', task: s.firstSalaryFilmTask3),
      (week: s.firstSalaryFilmWeek2, emoji: '\u{1F6E1}\uFE0F', task: s.firstSalaryFilmTask4),
      (week: s.firstSalaryFilmBefore31Dec, emoji: '\u{1F4B0}', task: s.firstSalaryFilmTask5),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.firstSalaryFilmAct5Title,
          style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w800, color: MintColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          s.firstSalaryFilmAct5Quote,
          style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary, height: 1.4, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
        ...checklist.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.week,
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: MintColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              Text(item.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.task,
                  style: GoogleFonts.inter(fontSize: 12, color: MintColors.textPrimary, height: 1.4),
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.scoreExcellent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text('\u{1F3C6}', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.firstSalaryFirstStep, style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w800, color: MintColors.scoreExcellent)),
                    Text(s.firstSalaryFirstStepSub, style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimer(S s) {
    return Text(
      s.firstSalaryFilmDisclaimer,
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
