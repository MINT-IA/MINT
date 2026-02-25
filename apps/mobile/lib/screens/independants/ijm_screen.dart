import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/independants_service.dart';

// ────────────────────────────────────────────────────────────
//  IJM SCREEN — Sprint S18 / Independants complet
// ────────────────────────────────────────────────────────────
//
// Income loss insurance (indemnite journaliere maladie) simulator.
// Sliders for revenu, age. Toggle for delai de carence.
// Timeline showing coverage gap. Color-coded warning if age > 50.
// ────────────────────────────────────────────────────────────

class IjmScreen extends StatefulWidget {
  const IjmScreen({super.key});

  @override
  State<IjmScreen> createState() => _IjmScreenState();
}

class _IjmScreenState extends State<IjmScreen> {
  double _revenuMensuel = 6000;
  int _age = 40;
  int _delaiCarence = 30;
  IjmResult? _result;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  void _calculate() {
    setState(() {
      _result = IndependantsService.calculateIjm(
        _revenuMensuel,
        _age,
        _delaiCarence,
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
                _buildRevenueSlider(),
                const SizedBox(height: 20),
                _buildAgeSlider(),
                const SizedBox(height: 20),
                _buildCarenceToggle(),
                const SizedBox(height: 24),
                if (_result != null) ...[
                  _buildChiffreChoc(),
                  const SizedBox(height: 24),
                  if (_result!.isHighRisk) ...[
                    _buildHighRiskWarning(),
                    const SizedBox(height: 20),
                  ],
                  _buildResultCards(),
                  const SizedBox(height: 24),
                  _buildCoverageTimeline(),
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
          'Assurance IJM',
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
        borderRadius: const BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'L\'assurance IJM (indemnité journalière maladie) compense '
              'ta perte de revenu en cas de maladie. En tant '
              'qu\'indépendant\u00B7e, aucune protection n\'est prévue '
              'par défaut : c\'est à toi de t\'assurer.',
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

  // ── Revenue Slider ─────────────────────────────────────────

  Widget _buildRevenueSlider() {
    return _buildSliderCard(
      title: 'Revenu mensuel',
      valueLabel: IndependantsService.formatChf(_revenuMensuel),
      minLabel: 'CHF 0',
      maxLabel: "CHF 20'000",
      value: _revenuMensuel,
      min: 0,
      max: 20000,
      divisions: 200,
      onChanged: (v) {
        _revenuMensuel = v;
        _calculate();
      },
    );
  }

  // ── Age Slider ─────────────────────────────────────────────

  Widget _buildAgeSlider() {
    return _buildSliderCard(
      title: 'Ton âge',
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
        borderRadius: const BorderRadius.circular(20),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
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
              Text(minLabel, style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
              Text(maxLabel, style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Délai de Carence Toggle ────────────────────────────────

  Widget _buildCarenceToggle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.circular(20),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Délai de carence',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Période pendant laquelle tu ne reçois aucune indemnité',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildCarenceChip(30),
              const SizedBox(width: 8),
              _buildCarenceChip(60),
              const SizedBox(width: 8),
              _buildCarenceChip(90),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCarenceChip(int jours) {
    final isSelected = _delaiCarence == jours;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _delaiCarence = jours;
          _calculate();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? MintColors.primary : MintColors.appleSurface,
            borderRadius: const BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? MintColors.primary : MintColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$jours j',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'jours',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.8)
                      : MintColors.textMuted,
                ),
              ),
            ],
          ),
        ),
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
        borderRadius: const BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            IndependantsService.formatChf(r.perteCarence),
            style: GoogleFonts.montserrat(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sans assurance IJM, tu perds '
            '${IndependantsService.formatChf(r.perteCarence)} '
            'pendant le délai de carence de ${r.delaiCarence} jours',
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

  // ── High Risk Warning ──────────────────────────────────────

  Widget _buildHighRiskWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.circular(16),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: MintColors.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Primes élevées après 50 ans',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Les primes IJM augmentent fortement avec l\'âge. '
                  'Après 50 ans, le coût peut être 3 à 4 fois supérieur '
                  'à celui d\'un\u00B7e assuré\u00B7e de 30 ans. '
                  'Considère un délai de carence plus long pour réduire la prime.',
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

  // ── Result Cards ───────────────────────────────────────────

  Widget _buildResultCards() {
    final r = _result!;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildResultCard(
                'Prime /mois',
                IndependantsService.formatChf(r.primeMensuelle),
                Icons.payment_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildResultCard(
                'Prime /an',
                IndependantsService.formatChf(r.primeAnnuelle),
                Icons.calendar_month_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildResultCard(
                'Indemnité /jour',
                IndependantsService.formatChf(r.indemniteJournaliere),
                Icons.today_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildResultCard(
                'Tranche d\'âge',
                r.ageBandLabel,
                Icons.person_outline,
                small: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultCard(String label, String value, IconData icon,
      {bool small = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.circular(16),
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

  // ── Coverage Timeline ──────────────────────────────────────

  Widget _buildCoverageTimeline() {
    final r = _result!;
    const totalDays = 180; // show 6 months
    final carenceRatio = r.delaiCarence / totalDays;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'CHRONOLOGIE DE COUVERTURE',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Timeline bar
          ClipRRect(
            borderRadius: const BorderRadius.circular(6),
            child: Row(
              children: [
                Expanded(
                  flex: (carenceRatio * 100).toInt().clamp(1, 99),
                  child: Container(
                    height: 32,
                    color: MintColors.error.withValues(alpha: 0.2),
                    alignment: Alignment.center,
                    child: Text(
                      '${r.delaiCarence}j',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: MintColors.error,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: (100 - carenceRatio * 100).toInt().clamp(1, 99),
                  child: Container(
                    height: 32,
                    color: MintColors.success.withValues(alpha: 0.2),
                    alignment: Alignment.center,
                    child: Text(
                      'Couvert',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: MintColors.success,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Legend
          Row(
            children: [
              _buildLegendDot(MintColors.error, 'Pas de couverture'),
              const SizedBox(width: 16),
              _buildLegendDot(MintColors.success, 'Couverture IJM (80%)'),
            ],
          ),
          const SizedBox(height: 16),

          // Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.appleSurface,
              borderRadius: const BorderRadius.circular(12),
            ),
            child: Text(
              'Pendant les ${r.delaiCarence} premiers jours de maladie, '
              'tu n\'as aucun revenu. Ensuite, tu reçois '
              '${IndependantsService.formatChf(r.indemniteJournaliere)}/jour '
              '(80% de ton revenu mensuel).',
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

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: MintColors.textSecondary),
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
            const Icon(Icons.lightbulb_outline, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              'STRATÉGIES',
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
          Icons.savings_outlined,
          'Constitution d\'un fonds de carence',
          'Mets de côté l\'équivalent de 3 mois de revenus pour '
          'couvrir le délai de carence. Cela te permet de choisir '
          'un délai de 90 jours et de réduire ta prime.',
        ),
        _buildEduCard(
          Icons.compare_arrows,
          'Comparer les offres',
          'Les primes varient fortement entre assureurs. Demande '
          'plusieurs devis et compare les conditions (exclusions, '
          'durée des prestations, montant couvert).',
        ),
        _buildEduCard(
          Icons.shield_outlined,
          'Couverture LAMal insuffisante',
          'La LAMal ne couvre que les frais médicaux, pas la perte '
          'de gain. L\'IJM est indispensable pour protéger ton revenu.',
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
          borderRadius: const BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.circular(10),
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
        borderRadius: const BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Les primes présentées sont des estimations basées sur des '
              'moyennes du marché. Les primes réelles dépendent de '
              'l\'assureur, de ta profession et de ton état de santé. '
              'Demande un devis personnalisé à un\u00B7e spécialiste.',
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
