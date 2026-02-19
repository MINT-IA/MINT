import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/data/cantonal_data.dart';
import 'package:go_router/go_router.dart';

// ────────────────────────────────────────────────────────────
//  MINI-ONBOARDING — "60 secondes to value"
// ────────────────────────────────────────────────────────────
//
// Remplace l'ancien ecran d'information statique par un
// questionnaire en 3 etapes rapides. Apres 3 questions
// essentielles, l'utilisateur obtient un chiffre choc
// personnalise sur le dashboard.
//
// Etape 1 : Stress check (ta priorite financiere)
// Etape 2 : Age + Canton (2 champs combines)
// Etape 3 : Revenu + Statut professionnel
//
// Le wizard complet reste accessible pour enrichir le profil.
// Les reponses sont sauvegardees via ReportPersistenceService
// pour que le wizard puisse reprendre sans redemander.
// ────────────────────────────────────────────────────────────

class AdvisorOnboardingScreen extends StatefulWidget {
  const AdvisorOnboardingScreen({super.key});

  @override
  State<AdvisorOnboardingScreen> createState() =>
      _AdvisorOnboardingScreenState();
}

class _AdvisorOnboardingScreenState extends State<AdvisorOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Answers
  String? _stressChoice;
  String? _canton;
  String? _employmentStatus;

  // Controllers
  final _birthYearController = TextEditingController();
  final _incomeController = TextEditingController();

  // Saved wizard progress
  bool _hasSavedWizardProgress = false;
  int _savedWizardProgress = 0;

  // Canton list (sorted by name)
  late final List<MapEntry<String, CantonProfile>> _sortedCantons;

  @override
  void initState() {
    super.initState();
    _sortedCantons = CantonalDataService.cantons.entries.toList()
      ..sort((a, b) => a.value.name.compareTo(b.value.name));
    _checkSavedProgress();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _birthYearController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  Future<void> _checkSavedProgress() async {
    final savedAnswers = await ReportPersistenceService.loadAnswers();
    if (savedAnswers.isNotEmpty && mounted) {
      setState(() {
        _hasSavedWizardProgress = true;
        _savedWizardProgress =
            ((savedAnswers.length / 24) * 100).round().clamp(0, 99);
      });
    }
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _goBack() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _completeMiniOnboarding() async {
    // Parse inputs
    final birthYear = int.tryParse(_birthYearController.text);
    final income = double.tryParse(
      _incomeController.text.replaceAll("'", '').replaceAll(' ', ''),
    );

    if (birthYear == null || _canton == null || income == null) return;

    // Resolve employment status (default: employee)
    final empStatus = _employmentStatus ?? 'employee';

    // Build answers map (compatible with wizard question IDs)
    final answers = <String, dynamic>{
      'q_financial_stress_check': _stressChoice,
      'q_birth_year': birthYear,
      'q_canton': _canton,
      'q_net_income_period_chf': income,
      'q_employment_status': empStatus,
    };

    // Auto-infer LPP for employees above threshold (LPP art. 7)
    if (empStatus == 'employee' && income * 12 > 22680) {
      answers['q_has_pension_fund'] = 'yes';
    }

    // Merge with existing wizard answers (don't overwrite prior progress)
    final existing = await ReportPersistenceService.loadAnswers();
    final merged = {...existing, ...answers};
    await ReportPersistenceService.saveAnswers(merged);
    await ReportPersistenceService.setMiniOnboardingCompleted(true);

    // Create partial profile
    if (mounted) {
      context.read<CoachProfileProvider>().updateFromMiniOnboarding(merged);
      // Navigate to dashboard
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with back/close + step indicator
            _buildTopBar(),

            // Step indicator dots
            _buildStepIndicator(),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _buildStep1StressCheck(),
                  _buildStep2Essentials(),
                  _buildStep3Income(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  TOP BAR
  // ════════════════════════════════════════════════════════════════

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          if (_currentStep > 0)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              color: MintColors.textPrimary,
              onPressed: _goBack,
            )
          else
            const SizedBox(width: 48),
          const Spacer(),
          // Step label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: MintColors.appleSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_currentStep + 1}/3',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 22),
            color: MintColors.textMuted,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  STEP INDICATOR DOTS
  // ════════════════════════════════════════════════════════════════

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final isActive = i == _currentStep;
          final isDone = i < _currentStep;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isDone
                  ? MintColors.primary
                  : isActive
                      ? MintColors.primary
                      : MintColors.lightBorder,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  STEP 1 : STRESS CHECK
  // ════════════════════════════════════════════════════════════════

  Widget _buildStep1StressCheck() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Quelle est ta priorite ?',
            style: GoogleFonts.montserrat(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: MintColors.textPrimary,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'MINT s\'adapte a ce qui compte pour toi maintenant',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          _buildStressCard(
            icon: Icons.savings_outlined,
            label: 'Maitriser mon budget',
            value: 'budget',
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 12),
          _buildStressCard(
            icon: Icons.money_off_outlined,
            label: 'Reduire mes dettes',
            value: 'debt',
            color: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 12),
          _buildStressCard(
            icon: Icons.account_balance_outlined,
            label: 'Optimiser mes impots',
            value: 'tax',
            color: const Color(0xFF6366F1),
          ),
          const SizedBox(height: 12),
          _buildStressCard(
            icon: Icons.beach_access_outlined,
            label: 'Securiser ma retraite',
            value: 'pension',
            color: const Color(0xFF0EA5E9),
          ),
          const SizedBox(height: 32),
          // Secondary options
          if (_hasSavedWizardProgress) ...[
            Center(
              child: TextButton.icon(
                onPressed: () => context.push('/advisor/wizard'),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(
                  'Reprendre mon diagnostic ($_savedWizardProgress%)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: MintColors.primary,
                ),
              ),
            ),
          ],
          Center(
            child: TextButton(
              onPressed: () => context.push('/advisor/wizard'),
              child: Text(
                'Diagnostic complet (10 min)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStressCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final isSelected = _stressChoice == value;

    return GestureDetector(
      onTap: () {
        setState(() => _stressChoice = value);
        // Small delay for visual feedback, then advance
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) _goToStep(1);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : MintColors.lightBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isSelected ? color : MintColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  STEP 2 : AGE + CANTON
  // ════════════════════════════════════════════════════════════════

  Widget _buildStep2Essentials() {
    final canGoNext =
        _birthYearController.text.length == 4 && _canton != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'L\'essentiel',
            style: GoogleFonts.montserrat(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: MintColors.textPrimary,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Age et canton changent tout en Suisse',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Birth year
          Text(
            'Annee de naissance',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _birthYearController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '1990',
              hintStyle: TextStyle(
                color: MintColors.textMuted.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: MintColors.lightBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: MintColors.lightBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: MintColors.primary, width: 2),
              ),
            ),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),

          const SizedBox(height: 24),

          // Canton
          Text(
            'Canton de residence',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MintColors.lightBorder),
            ),
            child: DropdownButtonFormField<String>(
              value: _canton,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: InputBorder.none,
                hintText: 'Selectionner',
                hintStyle: TextStyle(
                  color: MintColors.textMuted.withValues(alpha: 0.5),
                  fontSize: 16,
                ),
              ),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: MintColors.textPrimary,
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(16),
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: MintColors.textMuted),
              items: _sortedCantons.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text('${entry.value.name} (${entry.key})'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _canton = value);
              },
            ),
          ),

          const SizedBox(height: 40),

          // CTA
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canGoNext ? () => _goToStep(2) : null,
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.textPrimary,
                disabledBackgroundColor:
                    MintColors.textMuted.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Suivant',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  STEP 3 : INCOME + STATUS
  // ════════════════════════════════════════════════════════════════

  Widget _buildStep3Income() {
    final hasIncome = _incomeController.text.isNotEmpty &&
        (double.tryParse(
                _incomeController.text.replaceAll("'", '').replaceAll(' ', '')) ??
            0) >
            0;
    final canComplete = hasIncome && _employmentStatus != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Ton revenu',
            style: GoogleFonts.montserrat(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: MintColors.textPrimary,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pour calculer ton potentiel d\'economie',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Monthly net income
          Text(
            'Revenu net mensuel (CHF)',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _incomeController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '5000',
              prefixText: 'CHF  ',
              prefixStyle: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: MintColors.textMuted,
              ),
              hintStyle: TextStyle(
                color: MintColors.textMuted.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: MintColors.lightBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: MintColors.lightBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: MintColors.primary, width: 2),
              ),
            ),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),

          const SizedBox(height: 28),

          // Employment status
          Text(
            'Statut professionnel',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatusChip(
            label: 'Salarie\u00B7e',
            value: 'employee',
            icon: Icons.business_center_outlined,
          ),
          const SizedBox(height: 8),
          _buildStatusChip(
            label: 'Independant\u00B7e',
            value: 'self_employed',
            icon: Icons.storefront_outlined,
          ),
          const SizedBox(height: 8),
          _buildStatusChip(
            label: 'Etudiant\u00B7e / Apprenti\u00B7e',
            value: 'student',
            icon: Icons.school_outlined,
          ),
          const SizedBox(height: 8),
          _buildStatusChip(
            label: 'Sans emploi',
            value: 'unemployed',
            icon: Icons.pause_circle_outline,
          ),

          const SizedBox(height: 36),

          // CTA
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canComplete ? _completeMiniOnboarding : null,
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                disabledBackgroundColor:
                    MintColors.textMuted.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Voir mon chiffre',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Secondary: full diagnostic
          Center(
            child: TextButton(
              onPressed: () => context.push('/advisor/wizard'),
              child: Text(
                'Je prefere le diagnostic complet (10 min)',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _employmentStatus == value;

    return GestureDetector(
      onTap: () => setState(() => _employmentStatus = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? MintColors.primary.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? MintColors.primary : MintColors.lightBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color:
                  isSelected ? MintColors.primary : MintColors.textSecondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? MintColors.primary
                      : MintColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: MintColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
