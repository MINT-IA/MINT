import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/segments_service.dart';

// ────────────────────────────────────────────────────────────
//  INDEPENDANT SCREEN — Sprint S12 / Chantier 6
// ────────────────────────────────────────────────────────────
//
// Coverage gap analysis for self-employed workers.
// Visual indicators for LPP/IJM/LAA/3a coverage.
// Protection cost calculator with monthly breakdown.
// Critical alerts for missing IJM.
// ────────────────────────────────────────────────────────────

class IndependantScreen extends StatefulWidget {
  const IndependantScreen({super.key});

  @override
  State<IndependantScreen> createState() => _IndependantScreenState();
}

class _IndependantScreenState extends State<IndependantScreen> {
  // ── State ──────────────────────────────────────────────────
  double _revenuNet = 80000;
  int _age = 42;
  bool _hasLpp = false;
  bool _hasIjm = false;
  bool _hasLaa = false;
  bool _has3a = false;
  String _canton = 'VD';

  IndependantResult? _result;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  void _compute() {
    final input = IndependantInput(
      revenuNet: _revenuNet,
      age: _age,
      hasLpp: _hasLpp,
      hasIjm: _hasIjm,
      hasLaa: _hasLaa,
      has3a: _has3a,
      canton: _canton,
    );
    setState(() {
      _result = IndependantService.analyse(input: input);
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
                _buildHeader(),
                const SizedBox(height: 20),
                _buildIntro(),
                const SizedBox(height: 24),

                // Revenue input
                _buildRevenueSection(),
                const SizedBox(height: 24),

                // Coverage toggles
                _buildCoverageToggles(),
                const SizedBox(height: 24),

                if (_result != null) ...[
                  // Jour J — protection before/after (P6-A / S42)
                  _buildJourJSection(),
                  const SizedBox(height: 20),

                  // Critical alerts
                  if (_result!.alerts.isNotEmpty) ...[
                    _buildAlerts(),
                    const SizedBox(height: 20),
                  ],

                  // Coverage gap analysis
                  _buildCoverageGapSection(),
                  const SizedBox(height: 20),

                  // Protection cost calculator
                  _buildProtectionCost(),
                  const SizedBox(height: 20),

                  // AVS info
                  _buildAvsInfo(),
                  const SizedBox(height: 20),

                  // 3a info
                  _build3aInfo(),
                  const SizedBox(height: 20),

                  // Recommendations
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
        'PARCOURS INDÉPENDANT',
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 1.5,
          color: MintColors.textMuted,
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
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.business_center,
            color: Colors.amber.shade700,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Indépendant',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Analyse de couverture et protection',
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
              'En tant qu\'indépendant, tu n\'as pas de LPP '
              'obligatoire, pas d\'IJM, et pas de LAA. Ta '
              'protection sociale dépend entièrement de tes '
              'démarches personnelles. Identifie tes lacunes.',
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

  // ── Jour J section (P6-A / S42) ───────────────────────────
  //  Dramatic before/after: every protection ON vs OFF.
  //  Computed from result or estimated from revenuNet.

  static const _protections = [
    ('AVS', '\ud83e\uddf1', 'Double ta cotisation'),
    ('LPP', '\ud83c\udfe6', 'Dispara\u00eet \u2014 choix volontaire'),
    ('LAA', '\ud83c\udfe5', 'Dispara\u00eet \u2014 accident hors travail'),
    ('IJM', '\ud83e\ude7a', 'Dispara\u00eet \u2014 maladie 0 CHF'),
    ('APG', '\ud83d\udc76', 'Dispara\u00eet \u2014 cong\u00e9 parental'),
  ];

  Widget _buildJourJSection() {
    // Estimate protection monthly loss when switching to self-employment.
    // AVS: employee share doubles (indep. pays both sides — LAVS art. 8).
    final avsMonth = _revenuNet * avsCotisationSalarie / 12;
    // LPP: voluntary caisse bonification (age-dependent — LPP art. 16).
    // Falls back to result's avsMensuel when a full calculation is available.
    final lppMonth = _result?.protectionCost.avsMensuel ??
        _revenuNet * getLppBonificationRate(_age) / 12;
    // LAA non-professionnelle: indicative market premium (~150 CHF/mois).
    // IJM maladie: indicative market premium (~100 CHF/mois).
    // These are educational estimates — real premiums depend on caisse & coverage.
    const double kLaaIndepMensuel = 150.0;
    const double kIjmIndepMensuel = 100.0;
    final totalLoss = (avsMonth + lppMonth + kLaaIndepMensuel + kIjmIndepMensuel)
        .roundToDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MintColors.error.withValues(alpha: 0.04),
            MintColors.warning.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text('\ud83d\udd04', style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Le Jour J \u2014 La grande bascule',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ce qui change en 1 jour quand tu deviens ind\u00e9pendant\u00b7e',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),

          // Column headers
          Row(
            children: [
              const Expanded(flex: 2, child: SizedBox()),
              Expanded(
                child: Text(
                  'Salari\u00e9\u00b7e',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MintColors.success,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Ind\u00e9pendant\u00b7e',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MintColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Protection rows
          ..._protections.map((p) => _buildProtectionRow(p.$1, p.$2, p.$3)),

          const SizedBox(height: 10),

          // Chiffre-choc
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MintColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Tu perds ~${IndependantService.formatChf(totalLoss)}/mois '
              'de protection invisible.\n'
              'Tu n\u2019as pas quitt\u00e9 un emploi. Tu as quitt\u00e9 un syst\u00e8me de protection.',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: MintColors.error,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionRow(String label, String emoji, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: MintColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Icon(Icons.check_circle, color: MintColors.success, size: 18),
          ),
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.cancel, color: MintColors.error, size: 18),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: MintColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Revenue section ────────────────────────────────────────

  Widget _buildRevenueSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D1D1F).withOpacity(0.06),
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
            'Revenu net annuel',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                IndependantService.formatChf(_revenuNet),
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                'Age : $_age ans',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MintColors.textSecondary,
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
              overlayColor: MintColors.primary.withOpacity(0.1),
              trackHeight: 6,
            ),
            child: Slider(
              value: _revenuNet,
              min: 20000,
              max: 200000,
              divisions: 36,
              onChanged: (value) {
                _revenuNet = value;
                _compute();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CHF\u00A020k', style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
              Text('CHF\u00A0200k', style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Coverage toggles ───────────────────────────────────────

  Widget _buildCoverageToggles() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border.withOpacity(0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ma couverture actuelle',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildToggleRow('LPP (affiliation volontaire)', _hasLpp, (v) {
            _hasLpp = v;
            _compute();
          }),
          _buildToggleRow('IJM (indemnité journalière maladie)', _hasIjm, (v) {
            _hasIjm = v;
            _compute();
          }),
          _buildToggleRow('LAA (assurance accident)', _hasLaa, (v) {
            _hasLaa = v;
            _compute();
          }),
          _buildToggleRow('3e pilier (3a)', _has3a, (v) {
            _has3a = v;
            _compute();
          }),
        ],
      ),
    );
  }

  Widget _buildToggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: MintColors.success,
          ),
        ],
      ),
    );
  }

  // ── Alerts ─────────────────────────────────────────────────

  Widget _buildAlerts() {
    final result = _result!;
    return Column(
      children: result.alerts.map((alert) {
        final isCritique = alert.startsWith('CRITIQUE');
        final isImportant = alert.startsWith('IMPORTANT');
        final color = isCritique
            ? MintColors.error
            : isImportant
                ? MintColors.warning
                : MintColors.info;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isCritique ? Icons.error : Icons.warning_amber_rounded,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    alert,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: color,
                      height: 1.5,
                      fontWeight: isCritique ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Coverage gap section ───────────────────────────────────

  Widget _buildCoverageGapSection() {
    final result = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shield_outlined, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'ANALYSE DE COUVERTURE',
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
        ...result.coverageGaps.map((gap) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildCoverageCard(gap),
        )),
      ],
    );
  }

  Widget _buildCoverageCard(CoverageGapItem gap) {
    final statusColor = gap.isCovered
        ? MintColors.success
        : gap.urgency == 'critique'
            ? MintColors.error
            : gap.urgency == 'haute'
                ? MintColors.warning
                : MintColors.info;

    final statusLabel = gap.isCovered
        ? 'Couvert'
        : gap.urgency == 'critique'
            ? 'NON COUVERT — Critique'
            : gap.urgency == 'haute'
                ? 'NON COUVERT'
                : 'Non couvert';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: gap.isCovered ? 0.8 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  gap.isCovered ? Icons.check_circle : Icons.cancel,
                  color: statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gap.label,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            gap.recommendation,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            gap.source,
            style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ── Protection cost calculator ─────────────────────────────

  Widget _buildProtectionCost() {
    final result = _result!;
    final cost = result.protectionCost;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D1D1F).withOpacity(0.06),
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
            'Coût de ma protection complète',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Estimation mensuelle',
            style: GoogleFonts.inter(fontSize: 13, color: MintColors.textSecondary),
          ),
          const SizedBox(height: 20),

          _buildCostRow('AVS / AI / APG', cost.avsMensuel, Colors.teal.shade700),
          const SizedBox(height: 10),
          if (!_hasIjm)
            _buildCostRow('IJM (estimation)', cost.ijmMensuel, MintColors.error),
          if (!_hasIjm) const SizedBox(height: 10),
          if (!_hasLaa)
            _buildCostRow('LAA (estimation)', cost.laaMensuel, MintColors.warning),
          if (!_hasLaa) const SizedBox(height: 10),
          _buildCostRow('3e pilier (max)', cost.pillar3aMensuel, const Color(0xFF4F46E5)),
          const SizedBox(height: 16),

          Divider(color: MintColors.border.withOpacity(0.5)),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total mensuel',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                IndependantService.formatChf(cost.totalMensuel),
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: MintColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${IndependantService.formatChf(cost.totalAnnuel)} / an',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, double amount, Color color) {
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
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textSecondary,
            ),
          ),
        ),
        Text(
          IndependantService.formatChf(amount),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
          ),
        ),
        Text(
          '/mois',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: MintColors.textMuted,
          ),
        ),
      ],
    );
  }

  // ── AVS info ───────────────────────────────────────────────

  Widget _buildAvsInfo() {
    final result = _result!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_outline, color: Colors.teal.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Cotisation AVS indépendant',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Ta cotisation AVS estimée : '
            '${IndependantService.formatChf(result.cotisationAvsAnnuelle)}/an '
            '(taux dégressif pour les revenus inférieurs à CHF\u00A058\'800, '
            'puis ~10.6% au-dessus).',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.teal.shade800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Source : LAVS art. 8 / Tables des cotisations AVS',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.teal.shade600),
          ),
        ],
      ),
    );
  }

  // ── 3a info ────────────────────────────────────────────────

  Widget _build3aInfo() {
    final result = _result!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_outlined, color: Color(0xFF4F46E5), size: 20),
              const SizedBox(width: 8),
              Text(
                '3e pilier — plafond indépendant',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF312E81),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _hasLpp
                ? 'Avec LPP volontaire : plafond 3a standard de '
                  'CHF\u00A07\'258/an.'
                : 'Sans LPP : plafond 3a "grand" de 20% du revenu net, '
                  'max ${IndependantService.formatChf(result.plafond3a)}/an '
                  '(plafond legal CHF\u00A036\'288).',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF4338CA),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Source : OPP3 art. 7',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6366F1)),
          ),
        ],
      ),
    );
  }

  // ── Recommendations ────────────────────────────────────────

  Widget _buildRecommendations() {
    final result = _result!;
    if (result.recommendations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'RECOMMANDATIONS',
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
        ...result.recommendations.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MintColors.border.withOpacity(0.6), width: 0.8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: MintColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MintColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: MintColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
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
              'Les montants présentés sont des estimations indicatives. '
              'Les cotisations réelles dépendent de ta situation '
              'personnelle et des offres d\'assurance disponibles. '
              'Consulte un fiduciaire ou un assureur avant toute '
              'décision.',
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

  // ── Sources footer ─────────────────────────────────────────

  Widget _buildSourcesFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sources',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MintColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'LPP art. 4 (pas d\'obligation pour indépendants) / '
          'LPP art. 44 (affiliation volontaire) / '
          'OPP3 art. 7 (3a grand : 20% du revenu net, max 36\'288) / '
          'LAVS art. 8 (cotisations indépendants) / '
          'LAA art. 4 / LAMal',
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
