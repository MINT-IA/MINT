import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/coach/disability_scorecard_widget.dart';
import 'package:mint_mobile/widgets/coach/franchise_cost_widget.dart';
import 'package:mint_mobile/widgets/coach/edu_shared_widgets.dart';

// ────────────────────────────────────────────────────────────
//  P4 — COUVERTURE INVALIDITÉ
//  Bulletin scolaire (E) + Franchise LAMal (D)
//  Source : LAMal art. 64-64a, LAVS, LPP art. 23-26
// ────────────────────────────────────────────────────────────

class DisabilityInsuranceScreen extends StatefulWidget {
  const DisabilityInsuranceScreen({super.key});

  @override
  State<DisabilityInsuranceScreen> createState() =>
      _DisabilityInsuranceScreenState();
}

class _DisabilityInsuranceScreenState extends State<DisabilityInsuranceScreen> {
  double _grossMonthly = 8333;
  double _savings = 30000;
  bool _hasIjm = true;
  bool _hasPrivateInsurance = false;
  bool _seededFromProfile = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seededFromProfile) return;
    _seededFromProfile = true;
    final profile = context.read<CoachProfileProvider>().profile;
    if (profile == null) return;
    setState(() {
      final salary = profile.salaireBrutMensuel;
      if (salary > 0) _grossMonthly = salary.clamp(2000.0, 25000.0);
      final savings = profile.patrimoine.epargneLiquide;
      if (savings > 0) _savings = savings.clamp(0.0, 500000.0);
    });
  }

  // ── Scorecard items ───────────────────────────────────────

  List<CoverageItem> get _scorecardItems {
    final annualGross = _grossMonthly * 12;
    final hasLpp = annualGross >= lppSeuilEntree;

    // IJM
    final ijmGrade = _hasIjm ? 'B+' : (_hasPrivateInsurance ? 'B' : 'F');
    final ijmDetail = _hasIjm
        ? '80% salaire — 720 jours (assurance collective)'
        : _hasPrivateInsurance
            ? 'Assurance privée personnelle (vérifie les conditions)'
            : '⚠️ Aucune couverture — hors période employeur, c\'est 0 CHF';

    // AI
    const aiGrade = 'C';

    // LPP
    final lppGrade = hasLpp ? 'A-' : 'D';
    final lppDetail = hasLpp
        ? 'Rente ≈ 40% salaire coordonné (LPP art. 23)'
        : 'Sous le seuil LPP ${_fmtChf(lppSeuilEntree)} CHF/an — pas de couverture 2e pilier';

    // Épargne
    final monthsReserve = _savings / (_grossMonthly * 0.7);
    final String savingsGrade;
    if (monthsReserve >= 6) {
      savingsGrade = 'A';
    } else if (monthsReserve >= 3) {
      savingsGrade = 'C+';
    } else if (monthsReserve >= 1) {
      savingsGrade = 'D';
    } else {
      savingsGrade = 'F';
    }
    final savingsDetail =
        '${monthsReserve.toStringAsFixed(1)} mois de charges (objectif : 6 mois)';

    return [
      CoverageItem(
        label: 'IJM / Perte de gain',
        grade: ijmGrade,
        detail: ijmDetail,
        legalRef: 'LAMal art. 67-77',
        emoji: '🛡️',
      ),
      CoverageItem(
        label: 'AI fédérale',
        grade: aiGrade,
        detail: 'Max ${_fmtChf(aiRenteEntiere)} CHF/mois — délai décision ~14 mois',
        legalRef: 'LAI art. 28',
        emoji: '🏛️',
      ),
      CoverageItem(
        label: 'LPP invalidité',
        grade: lppGrade,
        detail: lppDetail,
        legalRef: 'LPP art. 23-26',
        emoji: '🏦',
      ),
      CoverageItem(
        label: 'Réserve d\'urgence',
        grade: savingsGrade,
        detail: savingsDetail,
        emoji: '💰',
      ),
    ];
  }

  String get _overallGrade {
    int score = 0;
    if (_hasIjm || _hasPrivateInsurance) score += 3;
    final annualGross = _grossMonthly * 12;
    if (annualGross >= lppSeuilEntree) score += 2;
    final monthsReserve = _savings / (_grossMonthly * 0.7);
    if (monthsReserve >= 3) score += 2;
    if (monthsReserve >= 6) score += 1;
    if (score >= 7) return 'B+';
    if (score >= 5) return 'C+';
    if (score >= 3) return 'C-';
    return 'D';
  }

  double get _lifeDropPercent {
    // Act 3 income estimate: AI + LPP
    final annualGross = _grossMonthly * 12;
    double lppInvalidity = 0.0;
    if (annualGross >= lppSeuilEntree) {
      final coordinated = (annualGross - lppDeductionCoordination)
          .clamp(lppSalaireCoordMin, lppSalaireCoordMax);
      lppInvalidity = coordinated * 0.40 / 12;
    }
    final act3Income = aiRenteEntiere + lppInvalidity;
    return ((1 - act3Income / _grossMonthly) * 100).clamp(0, 100);
  }

  // ── Franchise options ─────────────────────────────────────

  static const List<FranchiseOption> _franchiseOptions = [
    FranchiseOption(franchiseAmount: 300, monthlyPremiumSavings: 0),
    FranchiseOption(franchiseAmount: 500, monthlyPremiumSavings: 10),
    FranchiseOption(franchiseAmount: 1000, monthlyPremiumSavings: 25),
    FranchiseOption(franchiseAmount: 1500, monthlyPremiumSavings: 40),
    FranchiseOption(franchiseAmount: 2000, monthlyPremiumSavings: 60),
    FranchiseOption(franchiseAmount: 2500, monthlyPremiumSavings: 80),
  ];

  static String _fmtChf(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                _buildInputsCard(),
                const SizedBox(height: 20),
                DisabilityScorecardWidget(
                  items: _scorecardItems,
                  overallGrade: _overallGrade,
                  lifeDropPercent: _lifeDropPercent,
                ),
                const SizedBox(height: 20),
                FranchiseCostWidget(
                  options: _franchiseOptions,
                  initialConsultationsPerYear: 3,
                ),
                const SizedBox(height: 20),
                const EduDisclaimer(
                  text:
                      'Outil éducatif — ne constitue pas un conseil en assurance. '
                      'Les montants de franchise et primes sont indicatifs. '
                      'Compare les offres sur comparaison.ch ou via un·e courtier·ère indépendant·e.',
                ),
                const SizedBox(height: 8),
                const EduLegalSources(
                  sources:
                      '• LAMal art. 64-64a (franchise)\n'
                      '• OAMal art. 93 (primes)\n'
                      '• LAI art. 28 (rente AI)\n'
                      '• LPP art. 23-26 (invalidité 2e pilier)',
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: MintColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MintColors.blueDark, MintColors.blueMaterial900],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Ma couverture invalidité',
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: MintColors.white,
                    ),
                  ),
                  Text(
                    'Bulletin scolaire · Franchise LAMal · AI/APG',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      title: Text(
        'Ma couverture',
        style: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: MintColors.white,
        ),
      ),
    );
  }

  Widget _buildInputsCard() {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Affine ta situation',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildSliderRow(
            label: 'Salaire brut mensuel',
            value: _grossMonthly,
            min: 2000,
            max: 25000,
            divisions: 46,
            format: (v) => "CHF ${_fmtChf(v)}",
            onChanged: (v) => setState(() => _grossMonthly = v),
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            label: 'Épargne disponible',
            value: _savings,
            min: 0,
            max: 200000,
            divisions: 40,
            format: (v) => "CHF ${_fmtChf(v)}",
            onChanged: (v) => setState(() => _savings = v),
          ),
          const SizedBox(height: 16),
          _buildToggleRow(
            label: 'IJM via mon employeur',
            value: _hasIjm,
            onChanged: (v) => setState(() => _hasIjm = v),
          ),
          const SizedBox(height: 8),
          _buildToggleRow(
            label: 'Assurance perte de gain privée',
            value: _hasPrivateInsurance,
            onChanged: (v) => setState(() => _hasPrivateInsurance = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) format,
    required void Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: MintColors.textSecondary)),
            ),
            Text(
              format(value),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MintColors.primary,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            activeTrackColor: MintColors.primary,
            inactiveTrackColor: MintColors.border,
            thumbColor: MintColors.primary,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13, color: MintColors.textPrimary)),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: MintColors.primary,
        ),
      ],
    );
  }
}
