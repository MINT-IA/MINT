import 'dart:math';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/independent_ledger_facts.dart';
import 'package:mint_mobile/services/independants_service.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_hero_number.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:provider/provider.dart';

// ────────────────────────────────────────────────────────────
//  DIVIDENDE VS SALAIRE SCREEN — Sprint S18
// ────────────────────────────────────────────────────────────
//
// Salary vs dividend split optimizer for SA/Sarl.
// Custom painted curve chart showing total charge vs split ratio.
// Requalification risk alert if salary < 60%.
// ────────────────────────────────────────────────────────────

class DividendeVsSalaireScreen extends StatefulWidget {
  const DividendeVsSalaireScreen({super.key});

  @override
  State<DividendeVsSalaireScreen> createState() =>
      _DividendeVsSalaireScreenState();
}

class _DividendeVsSalaireScreenState extends State<DividendeVsSalaireScreen> {
  double _partSalairePct = 70;
  double _tauxMarginal = 0.30;

  CoachProfileProvider? _profileProvider(BuildContext context) {
    try {
      return context.watch<CoachProfileProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  double? _annualEnvelope(CoachProfileProvider? provider) {
    return IndependentLedgerFacts.companyProfitAnnual(provider?.profile);
  }

  DividendeVsSalaireResult? _computeResult(double? annualEnvelope) {
    if (annualEnvelope == null) return null;
    return IndependantsService.calculateDividendeVsSalaire(
      annualEnvelope,
      _partSalairePct,
      _tauxMarginal,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final provider = _profileProvider(context);
    final annualEnvelope = _annualEnvelope(provider);
    final result = _computeResult(annualEnvelope);

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                MintEntrance(child: _buildHeader()),
                const SizedBox(height: 20),
                MintEntrance(
                    delay: const Duration(milliseconds: 100),
                    child: _buildLedgerFactsCard(context, s, annualEnvelope)),
                if (result != null) ...[
                  const SizedBox(height: 20),
                  _buildPartSalaireSlider(),
                  const SizedBox(height: 20),
                  _buildTauxSlider(),
                  const SizedBox(height: 24),
                  MintEntrance(child: _buildPremierEclairage(result)),
                  const SizedBox(height: 24),
                  if (result.requalificationRisk) ...[
                    MintEntrance(
                        delay: const Duration(milliseconds: 100),
                        child: _buildRequalificationAlert()),
                    const SizedBox(height: 20),
                  ],
                  MintEntrance(
                      delay: const Duration(milliseconds: 150),
                      child: _buildResultSection(result)),
                  const SizedBox(height: 24),
                  MintEntrance(
                      delay: const Duration(milliseconds: 200),
                      child: _buildCurveChart(result)),
                  const SizedBox(height: 24),
                  _buildEducation(),
                  const SizedBox(height: 24),
                ],
                _buildDisclaimer(),
                const SizedBox(height: 16),
                _buildCantonalDisclaimer(),
                const SizedBox(height: 16),
                _buildComplianceFooter(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.white,
      foregroundColor: MintColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => safePop(context),
      ),
      title: Text(S.of(context)!.dividendeVsSalaireTitle,
          style: MintTextStyles.headlineMedium()),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.dividendeHeaderBody,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Ledger Facts + Scenario Levers ───────────────────────

  Widget _buildLedgerFactsCard(
      BuildContext context, S s, double? annualEnvelope) {
    final hasMissing = annualEnvelope == null;

    return Semantics(
      key: const Key('dividende_vs_salaire_ledger_facts'),
      identifier: 'dividende_vs_salaire_ledger_facts',
      container: true,
      explicitChildNodes: true,
      child: MintSurface(
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasMissing
                      ? Icons.manage_search_outlined
                      : Icons.check_circle_outline,
                  color: hasMissing ? MintColors.warning : MintColors.success,
                  size: 20,
                ),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    hasMissing
                        ? s.dataQualityMissingSection
                        : s.dataQualityKnownSection,
                    style:
                        MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                            .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push(
                      '/data-block/revenu?inputKey=q_company_profit_annual_chf'),
                  icon: Icon(
                      hasMissing
                          ? Icons.add_circle_outline
                          : Icons.edit_outlined,
                      size: 18),
                  label: Text(hasMissing ? s.dataQualityEnrich : s.commonEdit),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm + 4),
            _buildFactRow(
              identifier: 'dividende_benefice_fact',
              label: s.dividendeBeneficeTotal,
              value: annualEnvelope == null
                  ? s.dataBlockStatusMissing
                  : IndependantsService.formatChf(annualEnvelope),
              isMissing: annualEnvelope == null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFactRow({
    required String identifier,
    required String label,
    required String value,
    required bool isMissing,
  }) {
    return Semantics(
      key: Key(identifier),
      identifier: identifier,
      label: '$label, $value',
      container: true,
      child: Row(
        children: [
          Icon(
            isMissing ? Icons.help_outline : Icons.check_circle_outline,
            color: isMissing ? MintColors.warning : MintColors.success,
            size: 16,
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: MintTextStyles.bodySmall(
                    color:
                        isMissing ? MintColors.warning : MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildPartSalaireSlider() {
    return _buildInputCard(
      child: MintPremiumSlider(
        label: S.of(context)!.dividendePartSalaire,
        value: _partSalairePct,
        min: 0,
        max: 100,
        divisions: 100,
        formatValue: (v) => '${v.toInt()}\u00a0%',
        onChanged: (v) {
          setState(() {
            _partSalairePct = v;
          });
        },
      ),
    );
  }

  Widget _buildTauxSlider() {
    return _buildInputCard(
      child: MintPremiumSlider(
        label: S.of(context)!.dividendeTauxMarginal,
        value: _tauxMarginal * 100,
        min: 10,
        max: 45,
        divisions: 35,
        formatValue: (v) => '${v.toStringAsFixed(0)}\u00a0%',
        onChanged: (v) {
          setState(() {
            _tauxMarginal = v / 100;
          });
        },
      ),
    );
  }

  Widget _buildInputCard({required Widget child}) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  // ── Premier Éclairage ───────────────────────────────────────────

  Widget _buildPremierEclairage(DividendeVsSalaireResult r) {
    final saving = r.economie;

    return Semantics(
      label: saving > 0
          ? S
              .of(context)!
              .semanticsDividendeSaving(IndependantsService.formatChf(saving))
          : S.of(context)!.semanticsDividendeAdjust,
      child: MintSurface(
        tone: saving > 0 ? MintSurfaceTone.sauge : MintSurfaceTone.porcelaine,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            MintHeroNumber(
              value: IndependantsService.formatChf(saving),
              caption: saving > 0
                  ? S.of(context)!.dividendeSavingCaption(
                        IndependantsService.formatChf(saving),
                      )
                  : S.of(context)!.semanticsDividendeAdjust,
              color: saving > 0 ? MintColors.success : MintColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  // ── Requalification Alert ──────────────────────────────────

  Widget _buildRequalificationAlert() {
    return Semantics(
        label: S.of(context)!.semanticsDividendeRequalification,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MintColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MintColors.error.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: MintColors.error, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context)!.dividendeRequalificationTitle,
                      style: MintTextStyles.bodyMedium(color: MintColors.error)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: MintSpacing.xs),
                    Text(
                      S.of(context)!.dividendeRequalificationBody,
                      style: MintTextStyles.bodySmall(
                          color: MintColors.error.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  // ── Result Section ─────────────────────────────────────────

  Widget _buildResultSection(DividendeVsSalaireResult r) {
    return Semantics(
      identifier: 'dividende_vs_salaire_result_section',
      container: true,
      child: Container(
          key: const Key('dividende_vs_salaire_result_section'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: MintColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MintColors.lightBorder),
          ),
          child: Column(
            children: [
              _buildResultRow(
                S.of(context)!.dividendePartSalaire,
                IndependantsService.formatChf(r.partSalaire),
                subtitle: S
                    .of(context)!
                    .dividendePctBenefice(_partSalairePct.toInt()),
              ),
              const SizedBox(height: 12),
              _buildResultRow(
                S.of(context)!.dividendePartDividende,
                IndependantsService.formatChf(r.partDividende),
                subtitle: S
                    .of(context)!
                    .dividendePctBenefice((100 - _partSalairePct).toInt()),
              ),
              const Divider(height: 24),
              _buildResultRow(
                S.of(context)!.dividendeVsSalaireChargeSalaire,
                IndependantsService.formatChf(r.chargeSalaire),
                color: MintColors.error,
              ),
              const SizedBox(height: 8),
              _buildResultRow(
                S.of(context)!.dividendeChargeDividende,
                IndependantsService.formatChf(r.chargeDividende),
                color: MintColors.info,
              ),
              const Divider(height: 24),
              _buildResultRow(
                S.of(context)!.dividendeChargeTotalSplit,
                IndependantsService.formatChf(r.chargeTotal),
                bold: true,
              ),
          const SizedBox(height: 8),
          _buildResultRow(
            S.of(context)!.dividendeVsSalaireCharge100Salaire,
            IndependantsService.formatChf(r.chargeToutSalaire),
            color: MintColors.textMuted,
          ),
            ],
          )),
    );
  }

  Widget _buildResultRow(
    String label,
    String value, {
    Color? color,
    String? subtitle,
    bool bold = false,
  }) {
    return Semantics(
        label: S.of(context)!.semanticsMetricLabelValue(label, value),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: MintTextStyles.bodyMedium(
                          color: color ?? MintColors.textSecondary)
                      .copyWith(
                          fontWeight: bold ? FontWeight.w600 : FontWeight.w400),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: MintTextStyles.micro(color: MintColors.textMuted),
                  ),
              ],
            )),
            const SizedBox(width: MintSpacing.md),
            Text(
              value,
              textAlign: TextAlign.right,
              style: MintTextStyles.bodyMedium(
                      color: bold
                          ? MintColors.primary
                          : (color ?? MintColors.textPrimary))
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ));
  }

  // ── Curve Chart ────────────────────────────────────────────

  Widget _buildCurveChart(DividendeVsSalaireResult r) {
    if (r.sensitivity.isEmpty) return const SizedBox.shrink();

    return Semantics(
      identifier: 'dividende_vs_salaire_curve_chart',
      container: true,
      child: Container(
          key: const Key('dividende_vs_salaire_curve_chart'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: MintColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MintColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.show_chart,
                      size: 16, color: MintColors.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    S.of(context)!.dividendeChartTitle,
                    style:
                        MintTextStyles.labelSmall(color: MintColors.textMuted)
                            .copyWith(
                                letterSpacing: 1, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                height: 200,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _ChargeCurvePainter(
                    points: r.sensitivity,
                    currentPct: _partSalairePct,
                    optimalPct: r.optimalSplitPct,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Axis labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(S.of(context)!.dividendeSplitMin,
                      style: MintTextStyles.micro(color: MintColors.textMuted)),
                  Text(S.of(context)!.dividendeSplitMax,
                      style: MintTextStyles.micro(color: MintColors.textMuted)),
                ],
              ),
              const SizedBox(height: 12),

              // Legend
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildChartLegend(MintColors.primary,
                      S.of(context)!.dividendeChartLegendChargeTotal),
                  _buildChartLegend(MintColors.success,
                      S.of(context)!.dividendeChartLegendSplitAdapte),
                  _buildChartLegend(MintColors.info,
                      S.of(context)!.dividendeChartLegendPosition),
                ],
              ),
            ],
          )),
    );
  }

  Widget _buildChartLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: MintTextStyles.micro(color: MintColors.textSecondary),
        ),
      ],
    );
  }

  // ── Education ──────────────────────────────────────────────

  Widget _buildEducation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline,
                size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              S.of(context)!.dividendeEducationTitle,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted)
                  .copyWith(letterSpacing: 1, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildEduCard(
          Icons.account_balance_outlined,
          S.of(context)!.dividendeEduProfitTaxTitle,
          S.of(context)!.dividendeEduProfitTaxBody,
        ),
        _buildEduCard(
          Icons.people_outline,
          S.of(context)!.dividendeEduAvsSalaryTitle,
          S.of(context)!.dividendeEduAvsSalaryBody,
        ),
        _buildEduCard(
          Icons.gavel_outlined,
          S.of(context)!.dividendeEduCantonalPracticeTitle,
          S.of(context)!.dividendeEduCantonalPracticeBody,
        ),
      ],
    );
  }

  Widget _buildEduCard(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.appleSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MintColors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: MintColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                            .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    body,
                    style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Disclaimers ────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.orangeRetroWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.dividendeDisclaimerBody,
              style: MintTextStyles.bodySmall(color: MintColors.deepOrange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCantonalDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        S.of(context)!.dividendeCantonalDisclaimer,
        style: MintTextStyles.micro(color: MintColors.textMuted),
        textAlign: TextAlign.center,
      ),
    );
  }
  // ── Compliance Footer ─────────────────────────────────────

  Widget _buildComplianceFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.dividendeComplianceFooter,
            style: MintTextStyles.micro(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            S.of(context)!.dividendeSourcesFooter,
            style: MintTextStyles.micro(color: MintColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  CUSTOM PAINTER — Charge curve
// ════════════════════════════════════════════════════════════

class _ChargeCurvePainter extends CustomPainter {
  static const double _chartCurveVerticalScale = 0.9;

  final List<DividendeSplitPoint> points;
  final double currentPct;
  final double optimalPct;

  _ChargeCurvePainter({
    required this.points,
    required this.currentPct,
    required this.optimalPct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final maxCharge = points.map((p) => p.chargeTotal).reduce(max);
    if (maxCharge <= 0) return;

    final paint = Paint()
      ..color = MintColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          MintColors.primary.withValues(alpha: 0.15),
          MintColors.primary.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final x = (points[i].partSalairePct / 100) * size.width;
      final y = size.height -
          (points[i].chargeTotal / maxCharge) *
              size.height *
              _chartCurveVerticalScale;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw optimal point
    final optimalX = (optimalPct / 100) * size.width;
    final optimalPoint = points.firstWhere(
      (p) => p.partSalairePct == optimalPct,
      orElse: () => points.first,
    );
    final optimalY = size.height -
        (optimalPoint.chargeTotal / maxCharge) *
            size.height *
            _chartCurveVerticalScale;

    final optimalDotPaint = Paint()
      ..color = MintColors.success
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(optimalX, optimalY), 6, optimalDotPaint);
    canvas.drawCircle(
      Offset(optimalX, optimalY),
      6,
      Paint()
        ..color = MintColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Draw current position
    final currentX = (currentPct / 100) * size.width;
    // Interpolate y for current position
    double currentY = size.height / 2;
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if (currentPct >= p1.partSalairePct && currentPct <= p2.partSalairePct) {
        final t = (currentPct - p1.partSalairePct) /
            (p2.partSalairePct - p1.partSalairePct);
        final charge = p1.chargeTotal + (p2.chargeTotal - p1.chargeTotal) * t;
        currentY = size.height -
            (charge / maxCharge) * size.height * _chartCurveVerticalScale;
        break;
      }
    }

    final currentDotPaint = Paint()
      ..color = MintColors.info
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(currentX, currentY), 6, currentDotPaint);
    canvas.drawCircle(
      Offset(currentX, currentY),
      6,
      Paint()
        ..color = MintColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Draw requalification zone (< 60%)
    final zonePaint = Paint()
      ..color = MintColors.error.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * 0.6, size.height),
      zonePaint,
    );

    // 60% vertical dashed line
    final dashedPaint = Paint()
      ..color = MintColors.error.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final dashX = size.width * 0.6;
    for (double dy = 0; dy < size.height; dy += 8) {
      canvas.drawLine(
        Offset(dashX, dy),
        Offset(dashX, (dy + 4).clamp(0, size.height)),
        dashedPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChargeCurvePainter oldDelegate) {
    return oldDelegate.currentPct != currentPct ||
        oldDelegate.optimalPct != optimalPct ||
        oldDelegate.points != points;
  }
}
