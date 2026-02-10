import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/unemployment_service.dart';
import 'package:mint_mobile/widgets/educational/unemployment_timeline_widget.dart';

// ────────────────────────────────────────────────────────────
//  UNEMPLOYMENT SCREEN — Sprint S19 / Chomage (LACI)
// ────────────────────────────────────────────────────────────
//
// Interactive LACI benefits calculator.
// Inputs: gain assure mensuel, age, months of contribution,
//         children toggle, disability toggle.
// Outputs: taux, indemnite, duration, timeline, checklist.
// ────────────────────────────────────────────────────────────

class UnemploymentScreen extends StatefulWidget {
  const UnemploymentScreen({super.key});

  @override
  State<UnemploymentScreen> createState() => _UnemploymentScreenState();
}

class _UnemploymentScreenState extends State<UnemploymentScreen> {
  double _gainAssure = 6000;
  int _age = 35;
  int _moisCotisation = 18;
  bool _hasChildren = false;
  bool _hasDisability = false;
  UnemploymentResult? _result;

  // Checklist tracking
  final Set<int> _checkedItems = {};

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  void _calculate() {
    setState(() {
      _result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: _gainAssure,
        age: _age,
        moisCotisation: _moisCotisation,
        hasChildren: _hasChildren,
        hasDisability: _hasDisability,
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
                _buildGainSlider(),
                const SizedBox(height: 20),
                _buildAgeSlider(),
                const SizedBox(height: 20),
                _buildMoisCotisationSlider(),
                const SizedBox(height: 20),
                _buildToggles(),
                const SizedBox(height: 24),
                if (_result != null) ...[
                  if (!_result!.eligible) ...[
                    _buildNotEligible(),
                    const SizedBox(height: 24),
                  ] else ...[
                    _buildChiffreChoc(),
                    const SizedBox(height: 24),
                    _buildTauxCard(),
                    const SizedBox(height: 24),
                    _buildResultCards(),
                    const SizedBox(height: 24),
                    _buildDurationCard(),
                    const SizedBox(height: 24),
                  ],
                  UnemploymentTimelineWidget(items: _result!.timeline),
                  const SizedBox(height: 24),
                  _buildChecklist(),
                  const SizedBox(height: 24),
                  _buildEducation(),
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
          'Perte d\'emploi',
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
          const Icon(Icons.shield_outlined, color: MintColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Estime tes droits au chomage (LACI). Le calcul depend de ton '
              'gain assure, de ton age et de la duree de cotisation au cours '
              'des 2 dernieres annees.',
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

  Widget _buildGainSlider() {
    return _buildSliderCard(
      title: 'Gain assure mensuel',
      valueLabel: UnemploymentService.formatChf(_gainAssure),
      minLabel: 'CHF 0',
      maxLabel: "CHF 12'350",
      value: _gainAssure,
      min: 0,
      max: 12350,
      divisions: 247,
      onChanged: (v) {
        _gainAssure = v;
        _calculate();
      },
    );
  }

  Widget _buildAgeSlider() {
    return _buildSliderCard(
      title: 'Ton age',
      valueLabel: '$_age ans',
      minLabel: '18 ans',
      maxLabel: '65 ans',
      value: _age.toDouble(),
      min: 18,
      max: 65,
      divisions: 47,
      onChanged: (v) {
        _age = v.toInt();
        _calculate();
      },
    );
  }

  Widget _buildMoisCotisationSlider() {
    return _buildSliderCard(
      title: 'Mois de cotisation (2 dernieres annees)',
      valueLabel: '$_moisCotisation mois',
      minLabel: '0',
      maxLabel: '24 mois',
      value: _moisCotisation.toDouble(),
      min: 0,
      max: 24,
      divisions: 24,
      onChanged: (v) {
        _moisCotisation = v.toInt();
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

  // ── Toggles ────────────────────────────────────────────────

  Widget _buildToggles() {
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
          Text(
            'Situation personnelle',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Influence le taux d\'indemnisation (70% ou 80%)',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          _buildToggleRow(
            icon: Icons.child_care,
            label: 'Obligation d\'entretien (enfants)',
            value: _hasChildren,
            onChanged: (v) {
              _hasChildren = v;
              _calculate();
            },
          ),
          const SizedBox(height: 12),
          _buildToggleRow(
            icon: Icons.accessible,
            label: 'Handicap reconnu',
            value: _hasDisability,
            onChanged: (v) {
              _hasDisability = v;
              _calculate();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: MintColors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textPrimary,
            ),
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: MintColors.primary,
        ),
      ],
    );
  }

  // ── Not Eligible ───────────────────────────────────────────

  Widget _buildNotEligible() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: MintColors.warning, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Non eligible',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _result!.raisonNonEligible ?? '',
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
    );
  }

  // ── Chiffre Choc ───────────────────────────────────────────

  Widget _buildChiffreChoc() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.error,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            UnemploymentService.formatChf(r.perteMensuelle),
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

  // ── Taux Card ──────────────────────────────────────────────

  Widget _buildTauxCard() {
    final r = _result!;
    final tauxPct = (r.tauxIndemnite * 100).toStringAsFixed(0);
    final isEnhanced = r.tauxIndemnite == 0.80;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isEnhanced
                  ? MintColors.success.withValues(alpha: 0.1)
                  : MintColors.info.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$tauxPct%',
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isEnhanced ? MintColors.success : MintColors.info,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Taux d\'indemnisation',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEnhanced
                      ? 'Taux majore (80%) : obligation d\'entretien, '
                        'handicap, ou salaire < CHF 3\'797'
                      : 'Taux standard (70%) : applicable dans les '
                        'autres situations',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Result Cards ───────────────────────────────────────────

  Widget _buildResultCards() {
    final r = _result!;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Indemnite /jour',
                UnemploymentService.formatChf(r.indemniteJournaliere),
                Icons.today_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Indemnite /mois',
                UnemploymentService.formatChf(r.indemniteMensuelle),
                Icons.calendar_month_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Gain assure retenu',
                UnemploymentService.formatChf(r.gainAssureRetenu),
                Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Delai de carence',
                '${r.delaiCarenceJours} jours',
                Icons.hourglass_empty,
                small: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon,
      {bool small = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: MintColors.textMuted),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: small ? 14 : 18,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Duration Card ──────────────────────────────────────────

  Widget _buildDurationCard() {
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
              const Icon(Icons.access_time, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'DUREE DES PRESTATIONS',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.nombreIndemnites}',
                      style: GoogleFonts.montserrat(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: MintColors.primary,
                      ),
                    ),
                    Text(
                      'indemnites journalieres',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: MintColors.lightBorder,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '~${r.dureeMois.toStringAsFixed(0)}',
                      style: GoogleFonts.montserrat(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: MintColors.primary,
                      ),
                    ),
                    Text(
                      'mois de couverture',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDurationTable(),
        ],
      ),
    );
  }

  Widget _buildDurationTable() {
    final brackets = [
      ('< 25 ans, >= 12 mois cotis.', '200 indemnites', _age < 25 && _moisCotisation >= 12),
      ('>= 25 ans, >= 18 mois cotis.', '260 indemnites', _age >= 25 && _moisCotisation >= 18 && _age < 55),
      ('>= 55 ans, >= 22 mois cotis.', '400 indemnites', _age >= 55 && _age < 60 && _moisCotisation >= 22),
      ('>= 60 ans, >= 22 mois cotis.', '520 indemnites', _age >= 60 && _moisCotisation >= 22),
    ];

    return Column(
      children: brackets.map((b) {
        final isCurrent = b.$3;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isCurrent
                ? MintColors.primary.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isCurrent
                ? Border.all(
                    color: MintColors.primary.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (isCurrent)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: MintColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'TOI',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  Text(
                    b.$1,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight:
                          isCurrent ? FontWeight.w600 : FontWeight.w400,
                      color: isCurrent
                          ? MintColors.textPrimary
                          : MintColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Text(
                b.$2,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isCurrent
                      ? MintColors.primary
                      : MintColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Checklist ──────────────────────────────────────────────

  Widget _buildChecklist() {
    final items = [
      'S\'inscrire a l\'ORP des le 1er jour sans emploi',
      'Deposer le dossier a la caisse de chomage',
      'Adapter le budget au nouveau revenu',
      'Transferer l\'avoir LPP sur un compte de libre passage',
      'Verifier les droits a une reduction de prime LAMal',
      'Mettre a jour le budget MINT avec le nouveau revenu',
    ];

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
              const Icon(Icons.checklist, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'CHECKLIST',
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
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: checked
                            ? MintColors.success
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: checked
                              ? MintColors.success
                              : MintColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: checked
                          ? const Icon(Icons.check,
                              size: 14, color: Colors.white)
                          : null,
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
              'BON A SAVOIR',
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
          Icons.timer_outlined,
          'Inscription rapide',
          'Inscris-toi a l\'ORP le plus tot possible. Chaque jour de retard '
          'peut entrainer une suspension de tes indemnites.',
        ),
        _buildEduCard(
          Icons.savings_outlined,
          '3e pilier en pause',
          'Sans revenu lucratif, tu ne peux plus cotiser au 3a. Les indemnites '
          'de chomage ne sont pas considerees comme un revenu lucratif '
          'au sens du 3e pilier.',
        ),
        _buildEduCard(
          Icons.account_balance_outlined,
          'LPP et chomage',
          'Pendant le chomage, seuls les risques deces et invalidite sont '
          'couverts par le LPP. L\'epargne vieillesse s\'arrete. '
          'Transfere ton avoir sur un compte de libre passage.',
        ),
        _buildEduCard(
          Icons.health_and_safety_outlined,
          'Reduction de prime LAMal',
          'Avec un revenu plus bas, tu pourrais avoir droit a des subsides '
          'LAMal. Fais la demande aupres de ton canton.',
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
              'Estimations educatives — ne constitue pas un conseil — '
              'LACI/LPP/OPP3. Les montants presentes sont approximatifs '
              'et dependent de ta situation personnelle. Consulte '
              'un\u00B7e specialiste ou l\'ORP de ton canton.',
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
