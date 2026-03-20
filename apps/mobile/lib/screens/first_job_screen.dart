import 'dart:math' show pow;
import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/first_job_service.dart';
import 'package:mint_mobile/widgets/educational/salary_breakdown_widget.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/coach/first_salary_film_widget.dart';
import 'package:mint_mobile/widgets/coach/budget_503020_widget.dart';
import 'package:mint_mobile/widgets/coach/career_timelapse_widget.dart';
import 'package:mint_mobile/widgets/coach/payslip_xray_widget.dart';
import 'package:mint_mobile/widgets/coach/job_change_checklist_widget.dart';
import 'package:mint_mobile/constants/social_insurance.dart';

// ────────────────────────────────────────────────────────────
//  FIRST JOB SCREEN — Sprint S19 / Premier emploi
// ────────────────────────────────────────────────────────────
//
// Interactive first job salary analyzer.
// Category C — Life Event (DESIGN_SYSTEM §2C).
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
    final age = DateTime.now().year - profile.birthYear;
    if (age > 30) return;
    _seededFromProfile = true;
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
            padding: const EdgeInsets.fromLTRB(
                MintSpacing.lg, 0, MintSpacing.lg, MintSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHeader(),
                const SizedBox(height: MintSpacing.md + 4),
                _buildSalaireSlider(),
                const SizedBox(height: MintSpacing.md + 4),
                _buildAgeSlider(),
                const SizedBox(height: MintSpacing.md + 4),
                _buildCantonAndActivity(),
                const SizedBox(height: MintSpacing.lg),
                if (_result != null) ...[
                  _buildChiffreChoc(),
                  const SizedBox(height: MintSpacing.lg),
                  SalaryBreakdownWidget(
                    brut: _result!.brut,
                    netEstime: _result!.netEstime,
                    cotisationsEmployeur: _result!.cotisationsEmployeur,
                    deductions: _result!.deductionItems,
                  ),
                  const SizedBox(height: MintSpacing.lg),
                  PayslipXRayWidget(
                    grossSalary: _salaire,
                    netSalary: _salaire * 0.76,
                    employerHiddenCost: _salaire * 1.13,
                    deductions: [
                      PayslipLine(
                        label: 'AVS/AI/APG',
                        emoji: '\u{1F6E1}\u{FE0F}',
                        amount: _salaire * 0.053,
                        percentage: 5.3,
                        explanation:
                            'Cotisation salari\u00e9\u00b7e\u00a0: 5.3% du brut. '
                            'Ton employeur paie aussi 5.3% en plus.',
                        legalRef: 'LAVS art. 5',
                      ),
                      PayslipLine(
                        label: 'LPP (2e pilier)',
                        emoji: '\u{1F3E6}',
                        amount: _salaire * 0.08,
                        percentage: 8.0,
                        explanation:
                            '\u00c9pargne vieillesse obligatoire d\u00e8s 25 ans. '
                            'Le taux exact d\u00e9pend de ta caisse et ton \u00e2ge.',
                        legalRef: 'LPP art. 16',
                      ),
                      PayslipLine(
                        label: 'Imp\u00f4t \u00e0 la source (estimation)',
                        emoji: '\u{1F3DB}\u{FE0F}',
                        amount: _salaire * 0.09,
                        percentage: 9.0,
                        explanation:
                            'Retenu directement sur le salaire si tu es impos\u00e9\u00b7e '
                            '\u00e0 la source. Le taux varie selon canton, statut et revenu.',
                        legalRef: 'LIFD art. 83',
                      ),
                    ],
                  ),
                  const SizedBox(height: MintSpacing.lg),
                  _build3aRecommendation(),
                  const SizedBox(height: MintSpacing.lg),
                  _build3aWarning(),
                  const SizedBox(height: MintSpacing.lg),
                  _buildLamalComparison(),
                  const SizedBox(height: MintSpacing.lg),
                  _buildChecklist(),
                  const SizedBox(height: MintSpacing.lg),
                  const JobChangeChecklistWidget(
                    items: [
                      ChecklistItem(
                        deadline: 'Avant de quitter',
                        emoji: '\u{1F4C4}',
                        action:
                            'Demande ton certificat LPP \u00e0 ton employeur actuel.',
                        legalRef: 'LPP art. 3 — libre passage',
                        consequence:
                            'Sans certificat, tu ne peux pas v\u00e9rifier que le '
                            'montant transf\u00e9r\u00e9 est correct.',
                      ),
                      ChecklistItem(
                        deadline: '30 jours',
                        emoji: '\u{1F3E6}',
                        action:
                            'V\u00e9rifie que ton avoir LPP a \u00e9t\u00e9 transf\u00e9r\u00e9 \u00e0 la '
                            'caisse de ton nouvel employeur.',
                        legalRef: 'OLP art. 3 — d\u00e9lai de transfert',
                        consequence:
                            'Sans transfert, ton capital va \u00e0 la Fondation '
                            'suppl\u00e9tive \u00e0 un taux de 0.05%.',
                      ),
                      ChecklistItem(
                        deadline: '1 mois',
                        emoji: '\u{1F6E1}\u{FE0F}',
                        action:
                            'Informe ton assurance-maladie LAMal du changement '
                            'd\'employeur si tu b\u00e9n\u00e9ficiais d\'une couverture collective.',
                        legalRef: 'LAMal art. 3',
                      ),
                      ChecklistItem(
                        deadline: 'D\u00e8s le premier salaire',
                        emoji: '\u{1F3E6}',
                        action:
                            'Continue tes versements au pilier 3a — '
                            'l\'interruption te co\u00fbte des d\u00e9ductions fiscales.',
                        legalRef: 'OPP3 art. 1',
                      ),
                    ],
                  ),
                  const SizedBox(height: MintSpacing.lg),
                  _buildEducation(),
                  const SizedBox(height: MintSpacing.lg),
                  _buildMintAnalysisSection(),
                  const SizedBox(height: MintSpacing.lg),
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

  // ── App Bar (white standard per DESIGN_SYSTEM §4.5) ──────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: Semantics(
        label: 'Retour',
        button: true,
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      title: Text(
        S.of(context)!.firstJobTitle,
        style: MintTextStyles.headlineMedium(),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.celebration_outlined,
              color: MintColors.info, size: 20),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              S.of(context)!.firstJobHeaderDesc,
              style:
                  MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sliders ────────────────────────────────────────────────

  Widget _buildSalaireSlider() {
    return _buildSliderCard(
      title: S.of(context)!.firstJobSalaryTitle,
      valueLabel: FirstJobService.formatChf(_salaire),
      minLabel: S.of(context)!.firstJobSalaryMin,
      maxLabel: S.of(context)!.firstJobSalaryMax,
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
      title: S.of(context)!.unemploymentAgeSliderTitle,
      valueLabel: S.of(context)!.unemploymentAgeValue(_age),
      minLabel: S.of(context)!.unemploymentAgeMin,
      maxLabel: S.of(context)!.unemploymentAgeValue(30),
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
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.white,
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
                  style: MintTextStyles.titleMedium(
                      color: MintColors.textPrimary),
                ),
              ),
              Text(
                valueLabel,
                style: MintTextStyles.headlineMedium(
                        color: MintColors.primary)
                    .copyWith(fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: MintColors.primary,
              inactiveTrackColor: MintColors.border,
              thumbColor: MintColors.primary,
              overlayColor: MintColors.primary.withValues(alpha: 0.1),
              trackHeight: 4,
            ),
            child: Semantics(
              label: title,
              slider: true,
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(minLabel, style: MintTextStyles.labelSmall()),
              Text(maxLabel, style: MintTextStyles.labelSmall()),
            ],
          ),
        ],
      ),
    );
  }

  // ── Canton + Activity Rate ─────────────────────────────────

  Widget _buildCantonAndActivity() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.white,
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
                S.of(context)!.firstJobCantonLabel,
                style:
                    MintTextStyles.titleMedium(color: MintColors.textPrimary),
              ),
              Semantics(
                label: S.of(context)!.firstJobCantonLabel,
                button: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: MintSpacing.sm + 4),
                  decoration: BoxDecoration(
                    color: MintColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: MintColors.border),
                  ),
                  child: DropdownButton<String>(
                    value: _canton,
                    underline: const SizedBox.shrink(),
                    style: MintTextStyles.titleMedium(
                        color: MintColors.primary),
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
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md + 4),

          // Activity rate slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context)!.firstJobActivityRate,
                style:
                    MintTextStyles.titleMedium(color: MintColors.textPrimary),
              ),
              Text(
                '${_tauxActivite.toStringAsFixed(0)}\u00a0%',
                style: MintTextStyles.headlineMedium(
                        color: MintColors.primary)
                    .copyWith(fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: MintColors.primary,
              inactiveTrackColor: MintColors.border,
              thumbColor: MintColors.primary,
              overlayColor: MintColors.primary.withValues(alpha: 0.1),
              trackHeight: 4,
            ),
            child: Semantics(
              label: S.of(context)!.firstJobActivityRate,
              slider: true,
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
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(S.of(context)!.firstJobActivityMin,
                  style: MintTextStyles.labelSmall()),
              Text(S.of(context)!.firstJobActivityMax,
                  style: MintTextStyles.labelSmall()),
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
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            FirstJobService.formatChf(r.cotisationsEmployeur),
            style: MintTextStyles.displayMedium(color: MintColors.white)
                .copyWith(fontSize: 36),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            r.chiffreChoc,
            style: MintTextStyles.bodyMedium(
                color: MintColors.white.withValues(alpha: 0.9)),
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
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_outlined,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                S.of(context)!.firstJob3aHeader,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildMiniMetric(
                  S.of(context)!.firstJob3aAnnualCap,
                  FirstJobService.formatChf(r.plafondAnnuel3a),
                ),
              ),
              const SizedBox(width: MintSpacing.sm + 4),
              Expanded(
                child: _buildMiniMetric(
                  S.of(context)!.firstJob3aMonthlySuggestion,
                  FirstJobService.formatChf(r.montantMensuelSuggere3a),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Container(
            padding: const EdgeInsets.all(MintSpacing.sm + 4),
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up,
                    size: 16, color: MintColors.success),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    S.of(context)!.firstJobFiscalSavings(
                        FirstJobService.formatChf(r.economieFiscaleEstimee3a)),
                    style: MintTextStyles.bodySmall(color: MintColors.success)
                        .copyWith(fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.all(MintSpacing.sm + 6),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style:
                MintTextStyles.titleMedium(color: MintColors.primary)
                    .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── 3a WARNING ─────────────────────────────────────────────

  Widget _build3aWarning() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: MintColors.error.withValues(alpha: 0.15), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: MintColors.error, size: 24),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.firstJob3aWarningTitle,
                  style: MintTextStyles.bodyMedium(color: MintColors.error)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: MintSpacing.xs + 2),
                Text(
                  _result!.alerte3a,
                  style: MintTextStyles.bodySmall(
                      color: MintColors.textPrimary),
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
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.health_and_safety_outlined,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                S.of(context)!.firstJobLamalHeader,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),

          // Franchise cards
          ...r.franchiseOptions.map((option) {
            final isRecommended =
                option.franchise == r.franchiseRecommandee;
            return Container(
              margin: const EdgeInsets.only(bottom: MintSpacing.sm),
              padding: const EdgeInsets.symmetric(
                  horizontal: MintSpacing.sm + 6,
                  vertical: MintSpacing.sm + 4),
              decoration: BoxDecoration(
                color: isRecommended
                    ? MintColors.success.withValues(alpha: 0.06)
                    : MintColors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isRecommended
                    ? Border.all(
                        color: MintColors.success.withValues(alpha: 0.15))
                    : Border.all(
                        color:
                            MintColors.border.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  if (isRecommended)
                    Container(
                      margin: const EdgeInsets.only(right: MintSpacing.sm),
                      padding: const EdgeInsets.symmetric(
                          horizontal: MintSpacing.xs + 2, vertical: 2),
                      decoration: BoxDecoration(
                        color: MintColors.success,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        S.of(context)!.firstJobTopBadge,
                        style: MintTextStyles.labelSmall(
                                color: MintColors.white)
                            .copyWith(
                                fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'CHF\u00a0${option.franchise}',
                      style: MintTextStyles.bodyMedium(
                        color: isRecommended
                            ? MintColors.success
                            : MintColors.textPrimary,
                      ).copyWith(
                          fontWeight: isRecommended
                              ? FontWeight.w700
                              : FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${FirstJobService.formatChf(option.primeMensuelle)}/mois',
                      style: MintTextStyles.labelSmall(
                          color: MintColors.textSecondary),
                    ),
                  ),
                  Text(
                    'Max ${FirstJobService.formatChf(option.coutAnnuelMax)}/an',
                    style: MintTextStyles.labelSmall(),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: MintSpacing.sm + 4),

          // Savings highlight
          Container(
            padding: const EdgeInsets.all(MintSpacing.sm + 4),
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.savings_outlined,
                    size: 16, color: MintColors.success),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    S.of(context)!.firstJobFranchiseSavings(
                        FirstJobService.formatChf(r.economieAnnuelleVs300)),
                    style: MintTextStyles.bodySmall(color: MintColors.success)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MintSpacing.sm + 4),

          // Note
          Text(
            r.noteLamal,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Checklist ──────────────────────────────────────────────

  Widget _buildChecklist() {
    final items = _result?.checklist ?? [];
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(
                S.of(context)!.firstJobChecklistHeader,
                style: MintTextStyles.labelSmall(),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          ...List.generate(items.length, (index) {
            final checked = _checkedItems.contains(index);
            return Semantics(
              label: '${S.of(context)!.firstJobChecklistHeader} ${index + 1}',
              button: true,
              child: GestureDetector(
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
                  padding:
                      const EdgeInsets.symmetric(vertical: MintSpacing.sm + 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: checked
                              ? MintColors.success
                              : MintColors.surface,
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
                                size: 16, color: MintColors.white)
                            : Text(
                                '${index + 1}',
                                style: MintTextStyles.labelSmall(
                                    color: MintColors.textSecondary),
                              ),
                      ),
                      const SizedBox(width: MintSpacing.sm + 4),
                      Expanded(
                        child: Text(
                          items[index],
                          style: MintTextStyles.bodyMedium(
                            color: checked
                                ? MintColors.textMuted
                                : MintColors.textPrimary,
                          ).copyWith(
                            decoration: checked
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
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
            const SizedBox(width: MintSpacing.sm),
            Text(
              S.of(context)!.unemploymentGoodToKnow,
              style: MintTextStyles.labelSmall(),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        _buildEduCard(
          Icons.account_balance_outlined,
          S.of(context)!.firstJobEduLppTitle,
          S.of(context)!.firstJobEduLppBody,
        ),
        _buildEduCard(
          Icons.receipt_long_outlined,
          S.of(context)!.firstJobEdu13Title,
          S.of(context)!.firstJobEdu13Body,
        ),
        _buildEduCard(
          Icons.savings_outlined,
          S.of(context)!.firstJobEduBudgetTitle,
          S.of(context)!.firstJobEduBudgetBody,
        ),
        _buildEduCard(
          Icons.description_outlined,
          S.of(context)!.firstJobEduTaxTitle,
          S.of(context)!.firstJobEduTaxBody,
        ),
      ],
    );
  }

  Widget _buildEduCard(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm + 4),
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.md),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(MintSpacing.sm),
              decoration: BoxDecoration(
                color: MintColors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: MintColors.primary),
            ),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: MintTextStyles.bodyMedium(
                            color: MintColors.textPrimary)
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

  // ── Analyse MINT ───────────────────────────────────────────

  Widget _buildMintAnalysisSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(),
        const SizedBox(height: MintSpacing.sm + 4),
        _buildScenarioChips(),
        const SizedBox(height: MintSpacing.md),
        FirstSalaryFilmWidget(grossMonthly: _salaire),
        const SizedBox(height: MintSpacing.md + 4),
        _buildBudget503020(),
        const SizedBox(height: MintSpacing.md + 4),
        _buildCareerTimeLapse(),
      ],
    );
  }

  /// Future Value of annuity: annual * ((1+r)^n - 1) / r
  static double _fvAnnuity(double annual, int years, {double r = 0.04}) {
    if (years <= 0) return 0;
    return annual * ((pow(1 + r, years) - 1) / r);
  }

  Widget _buildBudget503020() {
    final net = _result?.netEstime ?? _salaire * 0.85;
    final annualSavings = net * 0.20 * 12;
    final years = (65 - _age).clamp(0, 45);
    final fv = _fvAnnuity(annualSavings, years);
    return Budget503020Widget(
      netSalary: net,
      categories: [
        BudgetCategory(
          label: 'Besoins',
          emoji: '\u{1F3E0}',
          percent: 50,
          amount: net * 0.50,
          examples: const ['Loyer', 'LAMal', 'Transport', 'Alimentation'],
        ),
        BudgetCategory(
          label: 'Envies',
          emoji: '\u2728',
          percent: 30,
          amount: net * 0.30,
          examples: const ['Loisirs', 'Restaurants', 'Voyages', 'Shopping'],
        ),
        BudgetCategory(
          label: '\u00c9pargne & 3a',
          emoji: '\u{1F3E6}',
          percent: 20,
          amount: net * 0.20,
          examples: const ['Pilier 3a', '\u00c9pargne', 'Fonds d\'urgence'],
        ),
      ],
      chiffreChoc:
          'Si tu \u00e9pargnes ${(annualSavings.round() ~/ 1000)}\'000 CHF/an '
          'd\u00e8s maintenant, tu auras ~${(fv.round() ~/ 1000)}\'000 CHF \u00e0 65 ans.',
    );
  }

  Widget _buildCareerTimeLapse() {
    const monthly3a = pilier3aPlafondAvecLpp / 12;
    const annual3a = monthly3a * 12;

    final candidateAges =
        [22, 25, 30, 35].where((a) => a <= _age + 5).toList();
    final scenarioAges = candidateAges.isEmpty ? [_age] : candidateAges;
    final scenarios = scenarioAges
        .map((a) => TimeLapseScenario(
              startAge: a,
              capitalAt65: _fvAnnuity(annual3a, (65 - a).clamp(0, 45)),
            ))
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
            S.of(context)!.firstJobAnalysisHeader,
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.sm + 2, vertical: MintSpacing.xs),
          decoration: BoxDecoration(
            color: _seededFromProfile
                ? MintColors.success.withValues(alpha: 0.1)
                : MintColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _seededFromProfile
                  ? MintColors.success.withValues(alpha: 0.15)
                  : MintColors.warning.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            _seededFromProfile
                ? '\u{1F4CD} ${S.of(context)!.firstJobProfileBadge}'
                : '\u{1F4A1} ${S.of(context)!.firstJobIllustrativeBadge}',
            style: MintTextStyles.labelSmall(
              color: _seededFromProfile
                  ? MintColors.success
                  : MintColors.warning,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildScenarioChips() {
    const median = 6500.0;
    final profileVal = _seededFromProfile
        ? context
                .read<CoachProfileProvider>()
                .profile
                ?.salaireBrutMensuel ??
            5000.0
        : 5000.0;
    final boosted = (profileVal * 1.20).clamp(2000.0, 15000.0);

    final scenarios = [
      (
        label: _seededFromProfile
            ? '\u{1F4CD} Mon salaire'
            : '\u{1F4CD} D\u00e9faut',
        value: profileVal.clamp(2000.0, 15000.0),
        active:
            (_salaire - profileVal.clamp(2000.0, 15000.0)).abs() < 50,
      ),
      (
        label: '\u{1F1E8}\u{1F1ED} M\u00e9dian CH',
        value: median,
        active: (_salaire - median).abs() < 50,
      ),
      (
        label: '\u2728 +20%',
        value: boosted,
        active: (_salaire - boosted).abs() < 50,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: scenarios.map((s) {
          return Padding(
            padding: const EdgeInsets.only(right: MintSpacing.sm),
            child: Semantics(
              label: 'Sc\u00e9nario salaire\u00a0: ${s.label}',
              button: true,
              child: GestureDetector(
                onTap: () {
                  setState(() => _salaire = s.value);
                  _calculate();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: MintSpacing.sm + 6,
                      vertical: MintSpacing.sm),
                  decoration: BoxDecoration(
                    color: s.active ? MintColors.primary : MintColors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: s.active
                          ? MintColors.primary
                          : MintColors.border,
                      width: s.active ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    '${s.label}  CHF ${FirstJobService.formatChf(s.value)}',
                    style: MintTextStyles.labelSmall(
                      color: s.active
                          ? MintColors.white
                          : MintColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              S.of(context)!.firstJobDisclaimer,
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
