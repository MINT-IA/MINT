import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/assurances_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';

// ────────────────────────────────────────────────────────────
//  LAMAL FRANCHISE OPTIMISER SCREEN — Sprint S13 / Chantier 7
// ────────────────────────────────────────────────────────────
//
// Interactive screen for comparing LAMal franchise levels.
// Includes sliders for monthly premium and annual health
// expenses, comparison cards, break-even info, and
// recommendations.
// ────────────────────────────────────────────────────────────

class LamalFranchiseScreen extends StatefulWidget {
  const LamalFranchiseScreen({super.key});

  @override
  State<LamalFranchiseScreen> createState() => _LamalFranchiseScreenState();
}

class _LamalFranchiseScreenState extends State<LamalFranchiseScreen> {
  // ── State ──────────────────────────────────────────────────
  double _primeMensuelle = 350;
  double _depensesSante = 2000;
  bool _isChild = false;

  LamalFranchiseResult? _result;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    ReportPersistenceService.markSimulatorExplored('lamal');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _compute();
    }
  }

  void _compute() {
    setState(() {
      _result = LamalFranchiseService.analyzeAllFranchises(
        _primeMensuelle,
        _depensesSante,
        isChild: _isChild,
        s: S.of(context)!,
      );
    });
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildDemoModeBadge(),
                const SizedBox(height: 12),
                _buildHeader(),
                const SizedBox(height: 20),
                _buildIntro(),
                const SizedBox(height: 24),

                // Toggle Adult / Child
                _buildToggle(),
                const SizedBox(height: 24),

                // Input sliders
                _buildPrimeSlider(),
                const SizedBox(height: 16),
                _buildDepensesSlider(),
                const SizedBox(height: 24),

                // Results
                if (_result != null) ...[
                  _buildComparisonCards(),
                  const SizedBox(height: 20),
                  _buildBreakEvenInfo(),
                  const SizedBox(height: 20),
                  _buildRecommendations(),
                  const SizedBox(height: 20),
                ],

                // Alert card
                _buildAlertCard(),
                const SizedBox(height: 20),

                // Disclaimer
                _buildDisclaimer(),
                const SizedBox(height: 16),

                // Sources
                _buildSourcesFooter(),
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
      backgroundColor: MintColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: Text(
        S.of(context)!.lamalFranchiseAppBarTitle,
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: 1.5,
          color: MintColors.textMuted,
        ),
      ),
    );
  }

  // ── Demo mode badge ──────────────────────────────────────

  Widget _buildDemoModeBadge() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: MintColors.neutralBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: MintColors.neutralBg),
        ),
        child: Text(
          S.of(context)!.lamalFranchiseDemoMode,
          style: GoogleFonts.montserrat(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: MintColors.blueDark,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.accentPastel,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.health_and_safety,
            color: MintColors.tealLight,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of(context)!.lamalFranchiseTitle,
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                S.of(context)!.lamalFranchiseSubtitle,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Intro ──────────────────────────────────────────────────

  Widget _buildIntro() {
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
              S.of(context)!.lamalFranchiseIntro,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Toggle ─────────────────────────────────────────────────

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isChild) {
                  _isChild = false;
                  _compute();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isChild ? MintColors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !_isChild
                      ? [
                          BoxShadow(
                            color: MintColors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    S.of(context)!.lamalFranchiseAdult,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: !_isChild ? FontWeight.w600 : FontWeight.w400,
                      color: !_isChild ? MintColors.textPrimary : MintColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isChild) {
                  _isChild = true;
                  _compute();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isChild ? MintColors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _isChild
                      ? [
                          BoxShadow(
                            color: MintColors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    S.of(context)!.lamalFranchiseChild,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: _isChild ? FontWeight.w600 : FontWeight.w400,
                      color: _isChild ? MintColors.textPrimary : MintColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Prime slider ───────────────────────────────────────────

  Widget _buildPrimeSlider() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
        border: Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.lamalFranchisePrimeLabel,
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  LamalFranchiseService.formatChf(_primeMensuelle),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: MintColors.primary,
              inactiveTrackColor: MintColors.border,
              thumbColor: MintColors.primary,
              overlayColor: MintColors.primary.withValues(alpha: 0.1),
              trackHeight: 6,
            ),
            child: Slider(
              value: _primeMensuelle,
              min: 200,
              max: 600,
              divisions: 40,
              onChanged: (value) {
                _primeMensuelle = value;
                _compute();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CHF\u00A0200', style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
              Text('CHF\u00A0600', style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Depenses slider ────────────────────────────────────────

  Widget _buildDepensesSlider() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
        border: Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.lamalFranchiseExpensesLabel,
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _depensesSante > 3000
                      ? MintColors.error.withValues(alpha: 0.1)
                      : _depensesSante > 1000
                          ? MintColors.warning.withValues(alpha: 0.1)
                          : MintColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  LamalFranchiseService.formatChf(_depensesSante),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _depensesSante > 3000
                        ? MintColors.error
                        : _depensesSante > 1000
                            ? MintColors.warning
                            : MintColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: MintColors.primary,
              inactiveTrackColor: MintColors.border,
              thumbColor: MintColors.primary,
              overlayColor: MintColors.primary.withValues(alpha: 0.1),
              trackHeight: 6,
            ),
            child: Slider(
              value: _depensesSante,
              min: 0,
              max: 10000,
              divisions: 100,
              onChanged: (value) {
                _depensesSante = value;
                _compute();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CHF\u00A00', style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
              Text('CHF\u00A010\'000', style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Comparison cards ───────────────────────────────────────

  Widget _buildComparisonCards() {
    final result = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.compare_arrows, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              S.of(context)!.lamalFranchiseComparisonTitle,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...result.comparaison.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildFranchiseCard(c),
        )),
      ],
    );
  }

  Widget _buildFranchiseCard(FranchiseComparison c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: c.isOptimal ? MintColors.success : MintColors.border.withValues(alpha: 0.6),
          width: c.isOptimal ? 2 : 0.8,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'CHF\u00A0${c.franchiseLevel}',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  if (c.isOptimal) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: MintColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        S.of(context)!.lamalFranchiseRecommended,
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: MintColors.success,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '${S.of(context)!.lamalFranchiseTotal}\u00a0: ${LamalFranchiseService.formatChf(c.coutTotal)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.isOptimal ? MintColors.success : MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(S.of(context)!.lamalFranchisePrimePerYear, LamalFranchiseService.formatChf(c.primeAnnuelle)),
              ),
              Expanded(
                child: _buildMiniStat(S.of(context)!.lamalFranchiseQuotePart, LamalFranchiseService.formatChf(c.quotePart)),
              ),
              Expanded(
                child: _buildMiniStat(
                  S.of(context)!.lamalFranchiseSavings,
                  c.economieVs300 > 0
                      ? '+${LamalFranchiseService.formatChf(c.economieVs300)}'
                      : LamalFranchiseService.formatChf(c.economieVs300),
                  color: c.economieVs300 > 0 ? MintColors.success : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: MintColors.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color ?? MintColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── Break-even info ────────────────────────────────────────

  Widget _buildBreakEvenInfo() {
    final result = _result!;
    if (result.breakEvenPoints.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_vert, color: MintColors.teal, size: 18),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.lamalFranchiseBreakEvenTitle,
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...result.breakEvenPoints.take(3).map((bp) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: MintColors.teal,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    S.of(context)!.lamalFranchiseBreakEvenItem(
                      LamalFranchiseService.formatChf(bp.seuilDepenses),
                      bp.franchiseBasse.toString(),
                      bp.franchiseHaute.toString(),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ── Recommendations ────────────────────────────────────────

  Widget _buildRecommendations() {
    final result = _result!;
    if (result.recommandations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              S.of(context)!.lamalFranchiseRecommendationsTitle,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...result.recommandations.map((rec) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
            ),
            child: Text(
              rec,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        )),
      ],
    );
  }

  // ── Alert card ─────────────────────────────────────────────

  Widget _buildAlertCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.accentPastel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.accentPastel),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.event, color: MintColors.tealLight, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.lamalFranchiseAlertReminder,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.tealDark,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Disclaimer ─────────────────────────────────────────────

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
              S.of(context)!.lamalFranchiseDisclaimer,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.deepOrange,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sources footer ─────────────────────────────────────────

  Widget _buildSourcesFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.lamalFranchiseSourcesTitle,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MintColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          S.of(context)!.lamalFranchiseSourcesBody,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: MintColors.textMuted,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
