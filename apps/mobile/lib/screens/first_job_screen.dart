import 'dart:math' show pow;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/first_job_service.dart';
import 'package:mint_mobile/widgets/educational/salary_breakdown_widget.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/coach/first_salary_film_widget.dart';
import 'package:mint_mobile/widgets/coach/budget_503020_widget.dart';
import 'package:mint_mobile/widgets/coach/career_timelapse_widget.dart';
import 'package:mint_mobile/constants/social_insurance.dart';

// ────────────────────────────────────────────────────────────
//  FIRST JOB SCREEN — Sprint S19 / Premier emploi
// ────────────────────────────────────────────────────────────
//
// Interactive first job salary analyzer.
// Inputs: salary, age, canton, activity rate.
// Outputs: salary breakdown, 3a recommendation, LAMal franchise
//          comparison, checklist.
// ────────────────────────────────────────────────────────────

class FirstJobScreen extends StatefulWidget {
  const FirstJobScreen({super.key});

  @override
  State<FirstJobScreen> createState() => _FirstJobScreenState();
}

class _FirstJobScreenState extends State<FirstJobScreen> {
  double _salaire = 5000;
  int _age = 25;
  String _canton = 'ZH';
  double _tauxActivite = 100;
  FirstJobResult? _result;
  bool _seededFromProfile = false;

  // Checklist tracking
  final Set<int> _checkedItems = {};

  // Swiss cantons
  static const List<String> _cantons = [
    'AG', 'AI', 'AR', 'BE', 'BL', 'BS', 'FR', 'GE', 'GL', 'GR',
    'JU', 'LU', 'NE', 'NW', 'OW', 'SG', 'SH', 'SO', 'SZ', 'TG',
    'TI', 'UR', 'VD', 'VS', 'ZG', 'ZH',
  ];

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seededFromProfile) return;
    final profile = context.read<CoachProfileProvider>().profile;
    if (profile == null) return;
    _seededFromProfile = true;
    final age = DateTime.now().year - profile.birthYear;
    setState(() {
      _salaire = profile.salaireBrutMensuel.clamp(2000, 15000);
      _age = age.clamp(18, 30);
      if (profile.canton.isNotEmpty) _canton = profile.canton;
    });
    _calculate();
  }

  void _calculate() {
    setState(() {
      _result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: _salaire,
        age: _age,
        canton: _canton,
        tauxActivite: _tauxActivite,
      );
    });
  }

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
                _buildHeader(),
                const SizedBox(height: 20),
                _buildSalaireSlider(),
                const SizedBox(height: 20),
                _buildAgeSlider(),
                const SizedBox(height: 20),
                _buildCantonAndActivity(),
                const SizedBox(height: 24),
                if (_result != null) ...[
                  _buildChiffreChoc(),
                  const SizedBox(height: 24),
                  SalaryBreakdownWidget(
                    brut: _result!.brut,
                    netEstime: _result!.netEstime,
                    cotisationsEmployeur: _result!.cotisationsEmployeur,
                    deductions: _result!.deductionItems,
                  ),
                  const SizedBox(height: 24),
                  _build3aRecommendation(),
                  const SizedBox(height: 24),
                  _build3aWarning(),
                  const SizedBox(height: 24),
                  _buildLamalComparison(),
                  const SizedBox(height: 24),
                  _buildChecklist(),
                  const SizedBox(height: 24),
                  _buildEducation(),
                  const SizedBox(height: 24),
                  _buildMintAnalysisSection(),
                  const SizedBox(height: 24),
                ],
                _buildDisclaimer(),
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
      expandedHeight: 120,
      backgroundColor: MintColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 16),
        title: Text(
          'Premier emploi',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MintColors.primary,
                MintColors.primary.withValues(alpha: 0.85),
              ],
            ),
          ),
        ),
      ),
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
          const Icon(Icons.celebration_outlined, color: MintColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Comprends ta fiche de salaire ! On te montre où vont tes '
              'cotisations, ce que ton employeur paie en plus, et les '
              'premiers réflexes financiers à adopter.',
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

  // ── Sliders ────────────────────────────────────────────────

  Widget _buildSalaireSlider() {
    return _buildSliderCard(
      title: 'Salaire brut mensuel',
      valueLabel: FirstJobService.formatChf(_salaire),
      minLabel: "CHF 2'000",
      maxLabel: "CHF 15'000",
      value: _salaire,
      min: 2000,
      max: 15000,
      divisions: 260,
      onChanged: (v) {
        _salaire = v;
        _calculate();
      },
    );
  }

  Widget _buildAgeSlider() {
    return _buildSliderCard(
      title: 'Ton âge',
      valueLabel: '$_age ans',
      minLabel: '18 ans',
      maxLabel: '30 ans',
      value: _age.toDouble(),
      min: 18,
      max: 30,
      divisions: 12,
      onChanged: (v) {
        _age = v.toInt();
        _calculate();
      },
    );
  }

  Widget _buildSliderCard({
    required String title,
    required String valueLabel,
    required String minLabel,
    required String maxLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Text(
                valueLabel,
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: MintColors.primary,
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
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(minLabel,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: MintColors.textMuted)),
              Text(maxLabel,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: MintColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Canton + Activity Rate ─────────────────────────────────

  Widget _buildCantonAndActivity() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Canton dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Canton',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: MintColors.appleSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MintColors.border),
                ),
                child: DropdownButton<String>(
                  value: _canton,
                  underline: const SizedBox.shrink(),
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MintColors.primary,
                  ),
                  items: _cantons.map((c) {
                    return DropdownMenuItem(value: c, child: Text(c));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      _canton = v;
                      _calculate();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Activity rate slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Taux d\'activité',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                '${_tauxActivite.toStringAsFixed(0)}%',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: MintColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: MintColors.primary,
              inactiveTrackColor: MintColors.border,
              thumbColor: MintColors.primary,
              overlayColor: MintColors.primary.withValues(alpha: 0.1),
              trackHeight: 6,
            ),
            child: Slider(
              value: _tauxActivite,
              min: 10,
              max: 100,
              divisions: 18,
              onChanged: (v) {
                _tauxActivite = v;
                _calculate();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('10%',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: MintColors.textMuted)),
              Text('100%',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: MintColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Chiffre Choc ───────────────────────────────────────────

  Widget _buildChiffreChoc() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            FirstJobService.formatChf(r.cotisationsEmployeur),
            style: GoogleFonts.montserrat(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            r.chiffreChoc,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── 3a Recommendation ──────────────────────────────────────

  Widget _build3aRecommendation() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_outlined,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'PILIER 3A — À OUVRIR MAINTENANT',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMiniMetric(
                  'Plafond annuel',
                  FirstJobService.formatChf(r.plafondAnnuel3a),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniMetric(
                  'Suggestion /mois',
                  FirstJobService.formatChf(r.montantMensuelSuggere3a),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up,
                    size: 16, color: MintColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Économie fiscale estimée : ~${FirstJobService.formatChf(r.economieFiscaleEstimee3a)}/an',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MintColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MintColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── 3a WARNING ─────────────────────────────────────────────

  Widget _build3aWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.error.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: MintColors.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ATTENTION — ASSURANCE-VIE 3A',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.error,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _result!.alerte3a,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── LAMal Franchise Comparison ─────────────────────────────

  Widget _buildLamalComparison() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.health_and_safety_outlined,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'COMPARAISON FRANCHISES LAMAL',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Franchise cards
          ...r.franchiseOptions.map((option) {
            final isRecommended =
                option.franchise == r.franchiseRecommandee;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isRecommended
                    ? MintColors.success.withValues(alpha: 0.06)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isRecommended
                    ? Border.all(
                        color: MintColors.success.withValues(alpha: 0.4))
                    : Border.all(
                        color: MintColors.lightBorder.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  if (isRecommended)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: MintColors.success,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'TOP',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'CHF ${option.franchise}',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight:
                            isRecommended ? FontWeight.w700 : FontWeight.w500,
                        color: isRecommended
                            ? MintColors.success
                            : MintColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${FirstJobService.formatChf(option.primeMensuelle)}/mois',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    'Max ${FirstJobService.formatChf(option.coutAnnuelMax)}/an',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: MintColors.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),

          // Savings highlight
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.savings_outlined,
                    size: 16, color: MintColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Franchise 2500 vs 300 : économie estimée de ~'
                    '${FirstJobService.formatChf(r.economieAnnuelleVs300)}/an en primes',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MintColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Note
          Text(
            r.noteLamal,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Checklist ──────────────────────────────────────────────

  Widget _buildChecklist() {
    final items = _result?.checklist ?? [];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'PREMIERS RÉFLEXES',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(items.length, (index) {
            final checked = _checkedItems.contains(index);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (checked) {
                    _checkedItems.remove(index);
                  } else {
                    _checkedItems.add(index);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step number or check
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: checked
                            ? MintColors.success
                            : MintColors.appleSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: checked
                              ? MintColors.success
                              : MintColors.border,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: checked
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : Text(
                              '${index + 1}',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: MintColors.textSecondary,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        items[index],
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: checked
                              ? MintColors.textMuted
                              : MintColors.textPrimary,
                          decoration: checked
                              ? TextDecoration.lineThrough
                              : null,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
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
              'BON À SAVOIR',
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
        _buildEduCard(
          Icons.account_balance_outlined,
          'LPP dès 25 ans',
          'La cotisation LPP (2e pilier) commence à 25 ans pour '
          'l\'épargne vieillesse. Avant 25 ans, seuls les risques '
          'décès et invalidité sont couverts.',
        ),
        _buildEduCard(
          Icons.receipt_long_outlined,
          '13e salaire',
          'Si ton contrat prévoit un 13e salaire, celui-ci est aussi '
          'soumis aux déductions sociales. Ton salaire mensuel brut '
          'est alors le salaire annuel divisé par 13.',
        ),
        _buildEduCard(
          Icons.savings_outlined,
          'Règle du 50/30/20',
          'Un bon réflexe pour ton premier salaire : 50% pour les '
          'dépenses fixes, 30% pour les loisirs, 20% pour l\'épargne '
          'et la prévoyance (3a inclus).',
        ),
        _buildEduCard(
          Icons.description_outlined,
          'Déclaration fiscale',
          'Dès ton premier emploi, tu devras remplir une déclaration '
          'fiscale. Garde toutes tes attestations (salaire, 3a, '
          'frais professionnels).',
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
                color: Colors.white,
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
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Analyse MINT ───────────────────────────────────────────

  Widget _buildMintAnalysisSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(),
        const SizedBox(height: 12),
        _buildScenarioChips(),
        const SizedBox(height: 16),
        FirstSalaryFilmWidget(grossMonthly: _salaire),
        const SizedBox(height: 20),
        _buildBudget503020(),
        const SizedBox(height: 20),
        _buildCareerTimeLapse(),
      ],
    );
  }

  Widget _buildBudget503020() {
    final net = _result?.netEstime ?? _salaire * 0.85;
    return Budget503020Widget(
      netSalary: net,
      categories: [
        BudgetCategory(
          label: 'Besoins',
          emoji: '🏠',
          percent: 50,
          amount: net * 0.50,
          examples: const ['Loyer', 'LAMal', 'Transport', 'Alimentation'],
        ),
        BudgetCategory(
          label: 'Envies',
          emoji: '✨',
          percent: 30,
          amount: net * 0.30,
          examples: const ['Loisirs', 'Restaurants', 'Voyages', 'Shopping'],
        ),
        BudgetCategory(
          label: 'Épargne & 3a',
          emoji: '🏦',
          percent: 20,
          amount: net * 0.20,
          examples: const ['Pilier 3a', 'Épargne', 'Fonds d\'urgence'],
        ),
      ],
      chiffreChoc: 'Si tu épargnes ${((net * 0.20) * 12).round() ~/ 1000}\'000 CHF/an '
          'dès maintenant, tu auras ~${(((net * 0.20) * 12 * 40 * 1.04).round() ~/ 1000)}\'000 CHF à 65 ans.',
    );
  }

  Widget _buildCareerTimeLapse() {
    final monthly3a = pilier3aPlafondAvecLpp / 12;
    // FV annuity: annual contribution × ((1+r)^n - 1) / r — proper compound interest.
    double approxCapital(int startAge) {
      final years = (65 - startAge).clamp(0, 45);
      if (years == 0) return 0;
      const r = 0.04;
      return monthly3a * 12 * ((pow(1 + r, years) - 1) / r);
    }

    final candidateAges = [22, 25, 30, 35].where((a) => a <= _age + 5).toList();
    final scenarioAges = candidateAges.isEmpty ? [_age] : candidateAges;
    final scenarios = scenarioAges
        .map((a) => TimeLapseScenario(startAge: a, capitalAt65: approxCapital(a)))
        .toList();

    return CareerTimeLapseWidget(
      scenarios: scenarios,
      monthly3aContribution: monthly3a,
      initialAge: _age,
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Analyse MINT — Le film de ton salaire',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: MintColors.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _seededFromProfile
                ? MintColors.scoreExcellent.withValues(alpha: 0.1)
                : MintColors.scoreAttention.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _seededFromProfile
                  ? MintColors.scoreExcellent.withValues(alpha: 0.4)
                  : MintColors.scoreAttention.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            _seededFromProfile ? '📍 Ton profil' : '💡 Illustratif',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _seededFromProfile
                  ? MintColors.scoreExcellent
                  : MintColors.scoreAttention,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScenarioChips() {
    const median = 6500.0;
    final profileVal = _seededFromProfile
        ? context.read<CoachProfileProvider>().profile?.salaireBrutMensuel ?? 5000.0
        : 5000.0;
    final boosted = (profileVal * 1.20).clamp(2000.0, 15000.0);

    final scenarios = [
      (
        label: _seededFromProfile ? '📍 Mon salaire' : '📍 Défaut',
        value: profileVal.clamp(2000.0, 15000.0),
        active: (_salaire - profileVal.clamp(2000.0, 15000.0)).abs() < 50,
      ),
      (
        label: '🇨🇭 Médian CH',
        value: median,
        active: (_salaire - median).abs() < 50,
      ),
      (
        label: '✨ +20%',
        value: boosted,
        active: (_salaire - boosted).abs() < 50,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: scenarios.map((s) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _salaire = s.value);
                _calculate();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: s.active
                      ? MintColors.primary
                      : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: s.active ? MintColors.primary : MintColors.lightBorder,
                    width: s.active ? 2 : 1,
                  ),
                ),
                child: Text(
                  '${s.label}  CHF ${FirstJobService.formatChf(s.value)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: s.active ? Colors.white : MintColors.textPrimary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Disclaimer ─────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Estimations éducatives — ne constitue pas un conseil — '
              'LACI/LPP/OPP3. Les montants sont approximatifs et ne '
              'tiennent pas compte de toutes les spécificités cantonales. '
              'Consulte priminfo.admin.ch pour les primes LAMal exactes. '
              'Consulte un\u00B7e spécialiste en prévoyance.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.orange.shade800,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
