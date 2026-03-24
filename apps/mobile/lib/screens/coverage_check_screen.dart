import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/assurances_service.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

// ────────────────────────────────────────────────────────────
//  COVERAGE CHECK SCREEN — Sprint S13 / Chantier 7
// ────────────────────────────────────────────────────────────
//
// Interactive screen for evaluating insurance coverage.
// Includes profile toggles, coverage switches, score gauge,
// checklist cards with urgency badges, and recommendations.
// ────────────────────────────────────────────────────────────

class CoverageCheckScreen extends StatefulWidget {
  const CoverageCheckScreen({super.key});

  @override
  State<CoverageCheckScreen> createState() => _CoverageCheckScreenState();
}

class _CoverageCheckScreenState extends State<CoverageCheckScreen> {
  // ── State — Profile ────────────────────────────────────────
  String _statut = 'salarie'; // "salarie", "independant", "sans_emploi"
  bool _aHypotheque = false;
  bool _aFamille = false;
  bool _estLocataire = true;
  bool _voyagesFrequents = false;
  String _canton = 'VD';

  // ── State — Current coverage ───────────────────────────────
  bool _aIjmCollective = true;
  bool _aLaa = true;
  bool _aRcPrivee = false;
  bool _aMenage = false;
  bool _aProtectionJuridique = false;
  bool _aAssuranceVoyage = false;
  bool _aAssuranceDeces = false;

  CoverageCheckResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFromProfile();
    });
    _compute();
  }

  void _initializeFromProfile() {
    try {
      final provider = context.read<CoachProfileProvider>();
      if (!provider.hasProfile) return;
      final profile = provider.profile!;
      setState(() {
        if (profile.employmentStatus == 'independant') {
          _statut = 'independant';
        } else if (profile.employmentStatus == 'chomage') {
          _statut = 'sans_emploi';
        }
        if (profile.canton.isNotEmpty) {
          _canton = profile.canton;
        }
        if (profile.dettes.hypotheque != null &&
            profile.dettes.hypotheque! > 0) {
          _aHypotheque = true;
        }
        if (profile.nombreEnfants > 0 ||
            profile.conjoint != null) {
          _aFamille = true;
        }
        if (profile.housingStatus == 'proprietaire') {
          _estLocataire = false;
        }
      });
      _compute();
    } catch (_) {}
  }

  void _compute() {
    setState(() {
      _result = CoverageCheckService.evaluateCoverage(
        statutProfessionnel: _statut,
        aHypotheque: _aHypotheque,
        aFamille: _aFamille,
        estLocataire: _estLocataire,
        voyagesFrequents: _voyagesFrequents,
        aIjmCollective: _aIjmCollective,
        aLaa: _aLaa,
        aRcPrivee: _aRcPrivee,
        aMenage: _aMenage,
        aProtectionJuridique: _aProtectionJuridique,
        aAssuranceVoyage: _aAssuranceVoyage,
        aAssuranceDeces: _aAssuranceDeces,
        canton: _canton,
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

                // Profile section
                _buildProfileSection(),
                const SizedBox(height: 24),

                // Current coverage section
                _buildCoverageSection(),
                const SizedBox(height: 24),

                // Results
                if (_result != null) ...[
                  _buildScoreGauge(),
                  const SizedBox(height: 20),
                  _buildChecklist(),
                  const SizedBox(height: 20),
                  _buildRecommendations(),
                  const SizedBox(height: 20),
                ],

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
    final s = S.of(context)!;
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: Text(
        s.coverageCheckAppBarTitle,
        style: MintTextStyles.headlineMedium(),
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
          S.of(context)!.coverageCheckDemoMode,
          style: MintTextStyles.micro(color: MintColors.blueDark)
              .copyWith(fontWeight: FontWeight.w700, fontStyle: FontStyle.normal),
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
            color: MintColors.indigoBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.verified_user,
            color: MintColors.indigoDeep,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of(context)!.coverageCheckTitle,
                style: MintTextStyles.headlineMedium(),
              ),
              const SizedBox(height: 4),
              Text(
                S.of(context)!.coverageCheckSubtitle,
                style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Profile section ────────────────────────────────────────

  Widget _buildProfileSection() {
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
          Text(
            S.of(context)!.coverageCheckTonProfil,
            style: MintTextStyles.titleMedium(),
          ),
          const SizedBox(height: 16),

          // Statut professionnel
          Text(
            S.of(context)!.coverageCheckStatut,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: 8),
          _buildStatutChips(),
          const SizedBox(height: 16),

          // Toggles
          _buildProfileSwitch(S.of(context)!.coverageCheckHypotheque, _aHypotheque, (v) {
            _aHypotheque = v;
            _compute();
          }),
          _buildProfileSwitch(S.of(context)!.coverageCheckPersonnesCharge, _aFamille, (v) {
            _aFamille = v;
            _compute();
          }),
          _buildProfileSwitch(S.of(context)!.coverageCheckLocataire, _estLocataire, (v) {
            _estLocataire = v;
            _compute();
          }),
          _buildProfileSwitch(S.of(context)!.coverageCheckVoyages, _voyagesFrequents, (v) {
            _voyagesFrequents = v;
            _compute();
          }),
        ],
      ),
    );
  }

  Widget _buildStatutChips() {
    return Wrap(
      spacing: 8,
      children: [
        _buildStatutChip('salarie', S.of(context)!.coverageCheckSalarie),
        _buildStatutChip('independant', S.of(context)!.coverageCheckIndependant),
        _buildStatutChip('sans_emploi', S.of(context)!.coverageCheckSansEmploi),
      ],
    );
  }

  Widget _buildStatutChip(String value, String label) {
    final isSelected = _statut == value;
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
      onTap: () {
        _statut = value;
        // Reset related switches when changing status
        if (value == 'independant') {
          _aIjmCollective = false;
          _aLaa = false;
        } else if (value == 'salarie') {
          _aLaa = true;
        }
        _compute();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? MintColors.primary : MintColors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? MintColors.primary : MintColors.border,
          ),
        ),
        child: Text(
          label,
          style: MintTextStyles.bodySmall(
            color: isSelected ? MintColors.white : MintColors.textSecondary,
          ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
        ),
      ),
      ),
    );
  }

  Widget _buildProfileSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: MintColors.primary,
          ),
        ],
      ),
    );
  }

  // ── Coverage section ───────────────────────────────────────

  Widget _buildCoverageSection() {
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
          MintEntrance(child: Text(
            S.of(context)!.coverageCheckCouvertureActuelle,
            style: MintTextStyles.titleMedium(),
          )),
          const SizedBox(height: 12),
          MintEntrance(delay: const Duration(milliseconds: 100), child: _buildCoverageSwitch(S.of(context)!.coverageCheckIjm, _aIjmCollective, (v) {
            _aIjmCollective = v;
            _compute();
          })),
          MintEntrance(delay: const Duration(milliseconds: 200), child: _buildCoverageSwitch(S.of(context)!.coverageCheckLaa, _aLaa, (v) {
            _aLaa = v;
            _compute();
          })),
          MintEntrance(delay: const Duration(milliseconds: 300), child: _buildCoverageSwitch(S.of(context)!.coverageCheckRcPrivee, _aRcPrivee, (v) {
            _aRcPrivee = v;
            _compute();
          })),
          MintEntrance(delay: const Duration(milliseconds: 400), child: _buildCoverageSwitch(S.of(context)!.coverageCheckMenage, _aMenage, (v) {
            _aMenage = v;
            _compute();
          })),
          _buildCoverageSwitch(S.of(context)!.coverageCheckProtJuridique, _aProtectionJuridique, (v) {
            _aProtectionJuridique = v;
            _compute();
          }),
          _buildCoverageSwitch(S.of(context)!.coverageCheckVoyage, _aAssuranceVoyage, (v) {
            _aAssuranceVoyage = v;
            _compute();
          }),
          _buildCoverageSwitch(S.of(context)!.coverageCheckDeces, _aAssuranceDeces, (v) {
            _aAssuranceDeces = v;
            _compute();
          }),
        ],
      ),
    );
  }

  Widget _buildCoverageSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: MintColors.success,
          ),
        ],
      ),
    );
  }

  // ── Score gauge ────────────────────────────────────────────

  Widget _buildScoreGauge() {
    final result = _result!;
    final score = result.scoreCouverture;
    final color = score < 40
        ? MintColors.error
        : score < 70
            ? MintColors.warning
            : MintColors.success;

    return Container(
      padding: const EdgeInsets.all(24),
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
        children: [
          Text(
            S.of(context)!.coverageCheckScore,
            style: MintTextStyles.titleMedium(),
          ),
          const SizedBox(height: 20),

          // Score circle
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 10,
                    backgroundColor: MintColors.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$score',
                      style: MintTextStyles.displayMedium(color: color),
                    ),
                    Text(
                      '/ 100',
                      style: MintTextStyles.labelSmall(color: MintColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Critical gaps badge
          if (result.lacunesCritiques > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: MintColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: MintColors.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: MintColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${result.lacunesCritiques}',
                      style: MintTextStyles.labelSmall(color: MintColors.white)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: MintSpacing.sm),
                  Text(
                    result.lacunesCritiques > 1
                        ? S.of(context)!.coverageCriticalGapPlural
                        : S.of(context)!.coverageCriticalGapSingular,
                    style: MintTextStyles.bodySmall(color: MintColors.error)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Checklist ──────────────────────────────────────────────

  Widget _buildChecklist() {
    final result = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.checklist, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              S.of(context)!.coverageCheckAnalyseTitle,
              style: MintTextStyles.bodySmall(color: MintColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...result.checklist.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildChecklistCard(item),
        )),
      ],
    );
  }

  Widget _buildChecklistCard(CoverageCheckItem item) {
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
              _buildIconForType(item.iconType),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: MintTextStyles.titleMedium(),
                ),
              ),
              _buildUrgencyBadge(item.urgency),
            ],
          ),
          const SizedBox(height: 8),

          // Status indicator
          _buildStatusIndicator(item.status),
          const SizedBox(height: 8),

          Text(
            item.description,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.sm),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.estimatedCostRange,
                style: MintTextStyles.labelSmall(color: MintColors.textMuted),
              ),
              Text(
                item.source,
                style: MintTextStyles.micro(color: MintColors.textMuted)
                    .copyWith(fontStyle: FontStyle.normal),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconForType(IconType type) {
    final iconData = switch (type) {
      IconType.shield => Icons.shield_outlined,
      IconType.home => Icons.home_outlined,
      IconType.gavel => Icons.gavel,
      IconType.flight => Icons.flight_outlined,
      IconType.favorite => Icons.favorite_outline,
      IconType.localHospital => Icons.local_hospital_outlined,
      IconType.warning => Icons.warning_outlined,
      IconType.work => Icons.work_outline,
    };

    return Icon(iconData, size: 20, color: MintColors.textSecondary);
  }

  Widget _buildUrgencyBadge(String urgency) {
    final (label, color) = switch (urgency) {
      'critique' => (S.of(context)!.coverageCheckCritique, MintColors.error),
      'haute' => (S.of(context)!.coverageCheckHaute, MintColors.warning),
      'moyenne' => (S.of(context)!.coverageCheckMoyenne, MintColors.info),
      _ => (S.of(context)!.coverageCheckBasse, MintColors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: MintTextStyles.micro(color: color)
            .copyWith(fontWeight: FontWeight.w700, fontStyle: FontStyle.normal),
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    final (icon, label, color) = switch (status) {
      'couvert' => (Icons.check_circle, S.of(context)!.coverageCheckCouvert, MintColors.success),
      'non_couvert' => (Icons.cancel, S.of(context)!.coverageCheckNonCouvert, MintColors.error),
      _ => (Icons.help_outline, S.of(context)!.coverageCheckAVerifier, MintColors.warning),
    };

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: MintTextStyles.labelSmall(color: color)
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ],
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
              S.of(context)!.coverageCheckRecommandationsTitle,
              style: MintTextStyles.bodySmall(color: MintColors.textMuted),
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
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
        )),
      ],
    );
  }

  // ── Disclaimer ─────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Text(
              S.of(context)!.coverageCheckDisclaimer,
              style: MintTextStyles.micro(color: MintColors.textMuted),
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
          S.of(context)!.coverageCheckSources,
          style: MintTextStyles.labelSmall(color: MintColors.textMuted)
              .copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: MintSpacing.xs + 2),
        Text(
          S.of(context)!.coverageCheckSourcesBody,
          style: MintTextStyles.micro(color: MintColors.textMuted)
              .copyWith(fontStyle: FontStyle.normal),
        ),
      ],
    );
  }
}
