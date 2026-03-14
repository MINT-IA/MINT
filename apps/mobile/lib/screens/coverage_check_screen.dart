import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/assurances_service.dart';

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
  final String _canton = 'VD';

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
    _compute();
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
        S.of(context)!.coverageCheckAppBarTitle,
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
          S.of(context)!.coverageCheckDemoMode,
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
            color: MintColors.indigoBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
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
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                S.of(context)!.coverageCheckSubtitle,
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

  // ── Profile section ────────────────────────────────────────

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
        border: Border.all(color: MintColors.border.withOpacity(0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.coverageCheckProfile,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Statut professionnel
          Text(
            S.of(context)!.coverageCheckStatutLabel,
            style: GoogleFonts.inter(fontSize: 13, color: MintColors.textSecondary),
          ),
          const SizedBox(height: 8),
          _buildStatutChips(),
          const SizedBox(height: 16),

          // Toggles
          _buildProfileSwitch(S.of(context)!.coverageCheckHypotheque, _aHypotheque, (v) {
            _aHypotheque = v;
            _compute();
          }),
          _buildProfileSwitch(S.of(context)!.coverageCheckDependants, _aFamille, (v) {
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
        _buildStatutChip('salarie', S.of(context)!.coverageCheckStatutSalarie),
        _buildStatutChip('independant', S.of(context)!.coverageCheckStatutIndependant),
        _buildStatutChip('sans_emploi', S.of(context)!.coverageCheckStatutSansEmploi),
      ],
    );
  }

  Widget _buildStatutChip(String value, String label) {
    final isSelected = _statut == value;
    return GestureDetector(
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
          color: isSelected ? MintColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? MintColors.primary : MintColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? MintColors.white : MintColors.textSecondary,
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
            style: GoogleFonts.inter(fontSize: 14, color: MintColors.textPrimary),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: MintColors.primary,
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
            color: MintColors.primary.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
        border: Border.all(color: MintColors.border.withOpacity(0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.coverageCheckCurrentCoverage,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildCoverageSwitch(S.of(context)!.coverageCheckIjm, _aIjmCollective, (v) {
            _aIjmCollective = v;
            _compute();
          }),
          _buildCoverageSwitch(S.of(context)!.coverageCheckLaa, _aLaa, (v) {
            _aLaa = v;
            _compute();
          }),
          _buildCoverageSwitch(S.of(context)!.coverageCheckRc, _aRcPrivee, (v) {
            _aRcPrivee = v;
            _compute();
          }),
          _buildCoverageSwitch(S.of(context)!.coverageCheckMenage, _aMenage, (v) {
            _aMenage = v;
            _compute();
          }),
          _buildCoverageSwitch(S.of(context)!.coverageCheckProtectionJuridique, _aProtectionJuridique, (v) {
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
              style: GoogleFonts.inter(fontSize: 13, color: MintColors.textPrimary),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: MintColors.success,
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
            color: MintColors.primary.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
        border: Border.all(color: MintColors.border.withOpacity(0.6), width: 0.8),
      ),
      child: Column(
        children: [
          Text(
            S.of(context)!.coverageCheckScoreTitle,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
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
                      style: GoogleFonts.montserrat(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Text(
                      S.of(context)!.coverageCheckScoreMax,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textMuted,
                      ),
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
                color: MintColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: MintColors.error.withOpacity(0.2)),
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
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: MintColors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    result.lacunesCritiques > 1 ? S.of(context)!.coverageCheckLacunePlural : S.of(context)!.coverageCheckLacuneSingular,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MintColors.error,
                    ),
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
        border: Border.all(color: MintColors.border.withOpacity(0.6), width: 0.8),
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
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
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
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.estimatedCostRange,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textMuted,
                ),
              ),
              Text(
                item.source,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: MintColors.textMuted,
                ),
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
      'critique' => (S.of(context)!.coverageCheckUrgencyCritique, MintColors.error),
      'haute' => (S.of(context)!.coverageCheckUrgencyHaute, MintColors.warning),
      'moyenne' => (S.of(context)!.coverageCheckUrgencyMoyenne, MintColors.info),
      _ => (S.of(context)!.coverageCheckUrgencyBasse, MintColors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.montserrat(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    final (icon, label, color) = switch (status) {
      'couvert' => (Icons.check_circle, S.of(context)!.coverageCheckStatusCouvert, MintColors.success),
      'non_couvert' => (Icons.cancel, S.of(context)!.coverageCheckStatusNonCouvert, MintColors.error),
      _ => (Icons.help_outline, S.of(context)!.coverageCheckStatusAVerifier, MintColors.warning),
    };

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
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
              border: Border.all(color: MintColors.border.withOpacity(0.6), width: 0.8),
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
          Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.coverageCheckDisclaimer,
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
          S.of(context)!.coverageCheckSourcesTitle,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MintColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          S.of(context)!.coverageCheckSourcesBody,
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
