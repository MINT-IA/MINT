import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/widgets/coach/coach_helpers.dart';

// ────────────────────────────────────────────────────────────
//  COACH CHECK-IN SCREEN — Sprint C6 / MINT Coach
// ────────────────────────────────────────────────────────────
//
// Ecran de check-in mensuel — comme enregistrer une activite
// Strava pour tes finances. L'utilisateur confirme ses
// versements du mois, note des depenses/revenus exceptionnels,
// et voit l'impact sur sa trajectoire.
//
// Aucun terme banni. Ton pedagogique, tutoiement.
// ────────────────────────────────────────────────────────────

class CoachCheckinScreen extends StatefulWidget {
  const CoachCheckinScreen({super.key});

  @override
  State<CoachCheckinScreen> createState() => _CoachCheckinScreenState();
}

class _CoachCheckinScreenState extends State<CoachCheckinScreen>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────
  late CoachProfile _profile;
  late List<TextEditingController> _amountControllers;
  final _depensesController = TextEditingController();
  final _revenusController = TextEditingController();
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSubmitted = false;
  late AnimationController _checkAnimController;
  late Animation<double> _checkAnimation;

  // Computed after submit
  double _totalVersements = 0;
  double _impactCapital = 0;
  int _streak = 0;
  String _coachTip = '';

  bool _profileInitialized = false;

  @override
  void initState() {
    super.initState();
    _profile = CoachProfile.buildDemo(); // Fallback until provider loads

    // Init controllers with pre-filled amounts
    _amountControllers = _profile.plannedContributions
        .map((c) => TextEditingController(text: c.amount.toStringAsFixed(2)))
        .toList();

    _checkAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkAnimController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_profileInitialized) {
      _profileInitialized = true;
      final coachProvider = context.read<CoachProfileProvider>();
      if (coachProvider.hasProfile) {
        _profile = coachProvider.profile!;
        // Recreate controllers with real profile data
        for (final c in _amountControllers) {
          c.dispose();
        }
        _amountControllers = _profile.plannedContributions
            .map((c) => TextEditingController(text: c.amount.toStringAsFixed(2)))
            .toList();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _amountControllers) {
      c.dispose();
    }
    _depensesController.dispose();
    _revenusController.dispose();
    _noteController.dispose();
    _checkAnimController.dispose();
    super.dispose();
  }

  // ── Current month info ─────────────────────────────────────
  String get _currentMonthLabel {
    final now = DateTime.now();
    return '${kFrenchMonths[now.month - 1]} ${now.year}';
  }

  // ── Submit handler ─────────────────────────────────────────
  void _onSubmit() {
    if (!_formKey.currentState!.validate()) return;

    // Build versements map
    final versements = <String, double>{};
    for (int i = 0; i < _profile.plannedContributions.length; i++) {
      final contribution = _profile.plannedContributions[i];
      final amount = double.tryParse(_amountControllers[i].text) ?? 0;
      if (amount > 0) {
        versements[contribution.id] = amount;
      }
    }

    // Calculate totals
    _totalVersements = versements.values.fold(0.0, (s, v) => s + v);
    _impactCapital = ForecasterService.calculateMonthlyDelta(
      profile: _profile,
      versements: versements,
    );

    // Create the check-in
    final checkIn = MonthlyCheckIn(
      month: DateTime(DateTime.now().year, DateTime.now().month),
      versements: versements,
      depensesExceptionnelles: double.tryParse(_depensesController.text),
      revenusExceptionnels: double.tryParse(_revenusController.text),
      note: _noteController.text.isNotEmpty ? _noteController.text : null,
      completedAt: DateTime.now(),
    );

    // Simulate updated profile with the new check-in for streak calc
    final updatedCheckIns = [..._profile.checkIns, checkIn];
    _streak = _calculateStreak(updatedCheckIns);

    // Get coach message from fitness score
    final fitnessScore = FinancialFitnessService.calculate(profile: _profile);
    _coachTip = fitnessScore.coachMessage;

    setState(() {
      _isSubmitted = true;
    });
    _checkAnimController.forward();
  }

  int _calculateStreak(List<MonthlyCheckIn> checkIns) {
    if (checkIns.isEmpty) return 0;
    final sorted = List<MonthlyCheckIn>.from(checkIns)
      ..sort((a, b) => b.month.compareTo(a.month));
    int count = 0;
    DateTime expected = DateTime(DateTime.now().year, DateTime.now().month);
    for (final ci in sorted) {
      final ciMonth = DateTime(ci.month.year, ci.month.month);
      if (ciMonth == expected ||
          ciMonth == DateTime(expected.year, expected.month - 1)) {
        count++;
        expected = DateTime(ciMonth.year, ciMonth.month - 1);
      } else {
        break;
      }
    }
    return count;
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                _isSubmitted ? _buildSuccessContent() : _buildFormContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'CHECK-IN $_currentMonthLabel'.toUpperCase(),
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 1.5,
          color: MintColors.textMuted,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  FORM CONTENT
  // ════════════════════════════════════════════════════════════

  List<Widget> _buildFormContent() {
    return [
      const SizedBox(height: 8),
      // Header
      _buildFormHeader(),
      const SizedBox(height: 24),

      // Form
      Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section: Planned contributions
            _buildSectionTitle('Versements planifies'),
            const SizedBox(height: 12),
            ..._buildContributionRows(),
            const SizedBox(height: 28),

            // Section: Exceptional items
            _buildSectionTitle('Evenements du mois'),
            const SizedBox(height: 12),
            _buildExceptionalField(
              label: 'Depenses exceptionnelles ?',
              hint: 'Ex: 2000 (reparation voiture)',
              controller: _depensesController,
              icon: Icons.remove_circle_outline,
              color: MintColors.error,
            ),
            const SizedBox(height: 12),
            _buildExceptionalField(
              label: 'Revenus exceptionnels ?',
              hint: 'Ex: 5000 (bonus annuel)',
              controller: _revenusController,
              icon: Icons.add_circle_outline,
              color: MintColors.success,
            ),
            const SizedBox(height: 28),

            // Section: Note
            _buildSectionTitle('Note du mois (optionnel)'),
            const SizedBox(height: 12),
            _buildNoteField(),
            const SizedBox(height: 32),

            // CTA
            _buildSubmitButton(),
            const SizedBox(height: 24),

            // Disclaimer
            _buildDisclaimer(),
          ],
        ),
      ),
    ];
  }

  Widget _buildFormHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.coachBubble,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.edit_calendar,
            color: MintColors.coachAccent,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Check-in $_currentMonthLabel',
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Confirme tes versements du mois',
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.montserrat(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: MintColors.textPrimary,
      ),
    );
  }

  // ── Contribution rows ──────────────────────────────────────
  List<Widget> _buildContributionRows() {
    final rows = <Widget>[];
    for (int i = 0; i < _profile.plannedContributions.length; i++) {
      final contribution = _profile.plannedContributions[i];
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ContributionRow(
            contribution: contribution,
            controller: _amountControllers[i],
          ),
        ),
      );
    }
    return rows;
  }

  // ── Exceptional field ──────────────────────────────────────
  Widget _buildExceptionalField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.inter(
              fontSize: 16,
              color: MintColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textMuted,
              ),
              prefixText: 'CHF ',
              prefixStyle: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textSecondary,
              ),
              filled: true,
              fillColor: MintColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: MintColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: MintColors.lightBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: MintColors.coachAccent, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Note field ─────────────────────────────────────────────
  Widget _buildNoteField() {
    return TextFormField(
      controller: _noteController,
      maxLines: 3,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: MintColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'Ex: Mois complique, depense imprevue pour la voiture...',
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: MintColors.textMuted,
        ),
        filled: true,
        fillColor: MintColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: MintColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: MintColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: MintColors.coachAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Submit button ──────────────────────────────────────────
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _onSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: MintColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(
          'Valider le check-in',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SUCCESS CONTENT (replaces form after validation)
  // ════════════════════════════════════════════════════════════

  List<Widget> _buildSuccessContent() {
    return [
      const SizedBox(height: 40),
      // Animated checkmark
      Center(
        child: AnimatedBuilder(
          animation: _checkAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _checkAnimation.value,
              child: child,
            );
          },
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: MintColors.success,
              size: 64,
            ),
          ),
        ),
      ),
      const SizedBox(height: 24),

      // Success title
      Center(
        child: Text(
          'Bravo ! Check-in $_currentMonthLabel complete',
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
      ),
      const SizedBox(height: 32),

      // Impact card
      _buildImpactCard(),
      const SizedBox(height: 16),

      // Streak card
      _buildStreakCard(),
      const SizedBox(height: 16),

      // Coach tip card
      _buildCoachTipCard(),
      const SizedBox(height: 32),

      // CTA: see trajectory
      SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: MintColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Text(
            'Voir ma trajectoire mise a jour',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      const SizedBox(height: 24),

      // Disclaimer
      _buildDisclaimer(),
    ];
  }

  Widget _buildImpactCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MintColors.success.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.trending_up,
              color: MintColors.success,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Impact sur ta trajectoire',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Capital projete +${ForecasterService.formatChf(_impactCapital)} ce mois',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: MintColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total versements : ${ForecasterService.formatChf(_totalVersements)}',
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
    );
  }

  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MintColors.warning.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.emoji_events,
              color: MintColors.warning,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Serie en cours',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_streak mois consecutifs on-track !',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: MintColors.warning,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachTipCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MintColors.coachAccent.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MintColors.coachAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.tips_and_updates,
              color: MintColors.coachAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tip du coach',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.coachAccent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _coachTip,
                  style: GoogleFonts.inter(
                    fontSize: 14,
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

  // ── Disclaimer ─────────────────────────────────────────────
  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: MintColors.textMuted,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Outil educatif — ne constitue pas un conseil financier personnalise. '
              'Les projections sont basees sur des hypotheses et peuvent varier. '
              'Consulte un·e specialiste pour un accompagnement adapte. LSFin.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MintColors.textMuted,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  CONTRIBUTION ROW WIDGET
// ════════════════════════════════════════════════════════════════

class _ContributionRow extends StatelessWidget {
  final PlannedMonthlyContribution contribution;
  final TextEditingController controller;

  const _ContributionRow({
    required this.contribution,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final icon = iconForCategory(contribution.category);
    final color = colorForCategory(contribution.category);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D1D1F).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Category icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),

          // Label + auto/manual badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contribution.label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: contribution.isAutomatic
                        ? MintColors.success.withValues(alpha: 0.1)
                        : MintColors.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    contribution.isAutomatic ? 'Auto' : 'Manuel',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: contribution.isAutomatic
                          ? MintColors.success
                          : MintColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Amount input
          SizedBox(
            width: 120,
            child: TextFormField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
              ),
              decoration: InputDecoration(
                prefixText: 'CHF ',
                prefixStyle: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textMuted,
                ),
                filled: true,
                fillColor: MintColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: MintColors.lightBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: MintColors.coachAccent,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                isDense: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return null; // optional
                if (double.tryParse(value) == null) return 'Montant invalide';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}
