import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/services/milestone_detection_service.dart';
import 'package:mint_mobile/services/streak_service.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/widgets/coach/coach_helpers.dart';
import 'package:mint_mobile/widgets/coach/milestone_celebration_sheet.dart';
import 'package:mint_mobile/services/notification_service.dart';

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
  String _scoreDeltaReason = '';
  int _scoreBefore = 0;
  int _scoreAfter = 0;

  bool _profileInitialized = false;

  @override
  void initState() {
    super.initState();
    // Will be initialized from provider in didChangeDependencies
    _amountControllers = [];

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
      } else {
        // Build empty profile if wizard not completed
        _profile = CoachProfile(
          birthYear: 1990,
          canton: 'ZH',
          salaireBrutMensuel: 0,
          goalA: GoalA(
            type: GoalAType.retraite,
            targetDate: DateTime(2055, 12, 31),
            label: 'Retraite',
          ),
        );
      }
      // Init controllers from profile data
      for (final c in _amountControllers) {
        c.dispose();
      }
      _amountControllers = _profile.plannedContributions
          .map((c) => TextEditingController(text: c.amount.toStringAsFixed(2)))
          .toList();
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

    final coachProvider = context.read<CoachProfileProvider>();

    // Build versements map + detect amount changes
    final versements = <String, double>{};
    final updatedContributions = <PlannedMonthlyContribution>[];
    bool contributionsChanged = false;

    for (int i = 0; i < _profile.plannedContributions.length; i++) {
      final contribution = _profile.plannedContributions[i];
      final amount = double.tryParse(_amountControllers[i].text) ?? 0;
      if (amount > 0) {
        versements[contribution.id] = amount;
      }
      // Track if user edited the amount (update planned for next month)
      if (amount != contribution.amount && amount > 0) {
        updatedContributions.add(contribution.copyWith(amount: amount));
        contributionsChanged = true;
      } else {
        updatedContributions.add(contribution);
      }
    }

    // Calculate totals
    _totalVersements = versements.values.fold(0.0, (s, v) => s + v);

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

    // ── Score before / after ────────────────────────────────
    final scoreBefore = FinancialFitnessService.calculate(
      profile: _profile,
      previousScore: coachProvider.previousScore,
    );
    _scoreBefore = scoreBefore.global;
    _coachTip = scoreBefore.coachMessage;

    // Build updated profile with new check-in + potentially updated contributions
    final updatedProfile =
        _profile.copyWithCheckIns(updatedCheckIns).copyWithContributions(
              contributionsChanged
                  ? updatedContributions
                  : _profile.plannedContributions,
            );
    final scoreAfter = FinancialFitnessService.calculate(
      profile: updatedProfile,
      previousScore: _scoreBefore,
    );
    _scoreAfter = scoreAfter.global;
    _scoreDeltaReason = _deriveScoreDeltaReason(
      scoreBefore: _scoreBefore,
      scoreAfter: _scoreAfter,
      totalVersements: _totalVersements,
      depensesExceptionnelles: double.tryParse(_depensesController.text) ?? 0.0,
      revenusExceptionnels: double.tryParse(_revenusController.text) ?? 0.0,
      contributionsChanged: contributionsChanged,
      initialContributions: _profile.plannedContributions,
      updatedContributions: updatedContributions,
    );
    _coachTip = scoreAfter.coachMessage;

    // Projection-based impact (more accurate than simple sum)
    final projectionBefore = ForecasterService.project(
      profile: _profile,
      targetDate: _profile.goalA.targetDate,
    );
    final projectionAfter = ForecasterService.project(
      profile: updatedProfile,
      targetDate: updatedProfile.goalA.targetDate,
    );
    _impactCapital =
        projectionAfter.base.capitalFinal - projectionBefore.base.capitalFinal;
    final oneMonthImpact = ForecasterService.calculateMonthlyDelta(
      profile: updatedProfile,
      versements: versements,
    );
    if (_impactCapital.abs() < 1 && oneMonthImpact > 0) {
      _impactCapital = oneMonthImpact;
    }

    // Persist check-in via provider
    coachProvider.addCheckIn(checkIn);

    // Persist updated contribution amounts if changed
    if (contributionsChanged) {
      coachProvider.updateContributions(updatedContributions);
    }

    // Persist score for trend tracking
    coachProvider.saveCurrentScore(_scoreAfter);
    unawaited(
      ReportPersistenceService.saveLastScoreAttribution(
        reason: _scoreDeltaReason,
        delta: _scoreAfter - _scoreBefore,
      ),
    );

    // Re-schedule notifications with updated profile (new check-in resets reminders)
    NotificationService().scheduleCoachingReminders(profile: updatedProfile);

    setState(() {
      _isSubmitted = true;
    });
    _checkAnimController.forward();

    // ── Milestone detection (async, after check-in persisted) ──
    _detectAndCelebrateMilestones(updatedProfile);
  }

  /// Detect newly achieved milestones and show celebration sheets.
  Future<void> _detectAndCelebrateMilestones(
      CoachProfile updatedProfile) async {
    final streakResult = StreakService.compute(updatedProfile);
    final milestones = await MilestoneDetectionService.detectNew(
      profile: updatedProfile,
      currentScore: _scoreAfter,
      streak: streakResult,
    );
    await _enrichMilestonesIfByok(milestones, updatedProfile);
    for (final milestone in milestones) {
      if (!mounted) break;
      try {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => MilestoneCelebrationSheet(milestone: milestone),
        );
      } catch (_) {
        break; // Widget disposed, arreter les celebrations
      }
    }
  }

  Future<void> _enrichMilestonesIfByok(
    List<MilestoneEvent> milestones,
    CoachProfile profile,
  ) async {
    if (milestones.isEmpty || !mounted) return;
    ByokProvider? byok;
    try {
      byok = context.read<ByokProvider>();
    } catch (_) {
      byok = null;
    }
    if (byok == null || !byok.isConfigured || byok.apiKey == null) return;

    final ragService = RagService();
    for (final milestone in milestones) {
      if (!mounted) return;
      try {
        final response = await ragService.query(
          question: '''
Tu es le coach financier MINT. Ecris une celebration courte (1-2 phrases) pour ce milestone.
Profil: ${profile.firstName ?? 'utilisateur'}, ${profile.age} ans, canton ${profile.canton}.
Milestone: ${milestone.title}
Description: ${milestone.description}
Contraintes: ton positif, tutoiement, concret, sans promesse.
Interdits: garanti, certain, assure, sans risque, optimal, meilleur, parfait.
Reponds uniquement avec le texte final.
''',
          apiKey: byok.apiKey!,
          provider: byok.provider ?? 'openai',
          profileContext: {
            'financial_summary':
                '${profile.firstName ?? 'utilisateur'}, ${profile.age} ans, score $_scoreAfter/100',
          },
        );
        final narrative = _sanitizeNarrative(response.answer);
        if (narrative.isNotEmpty) {
          milestone.narrativeMessage = narrative;
        }
      } catch (_) {
        // Fallback: keep static description
      }
    }
  }

  String _sanitizeNarrative(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*'), '').trim();
      text = text.replaceFirst(RegExp(r'```$'), '').trim();
    }
    const bannedTerms = [
      'garanti',
      'certain',
      'assuré',
      'assure',
      'sans risque',
      'optimal',
      'meilleur',
      'parfait',
    ];
    for (final term in bannedTerms) {
      text =
          text.replaceAll(RegExp(term, caseSensitive: false), '[terme retire]');
    }
    return text;
  }

  int _calculateStreak(List<MonthlyCheckIn> checkIns) {
    if (checkIns.isEmpty) return 0;
    final sorted = List<MonthlyCheckIn>.from(checkIns)
      ..sort((a, b) => b.month.compareTo(a.month));
    int count = 0;
    DateTime expected = DateTime(DateTime.now().year, DateTime.now().month);
    for (final ci in sorted) {
      final ciMonth = DateTime(ci.month.year, ci.month.month);
      if (ciMonth == expected) {
        count++;
        expected = DateTime(ciMonth.year, ciMonth.month - 1);
      } else {
        break;
      }
    }
    return count;
  }

  String _deriveScoreDeltaReason({
    required int scoreBefore,
    required int scoreAfter,
    required double totalVersements,
    required double depensesExceptionnelles,
    required double revenusExceptionnels,
    required bool contributionsChanged,
    required List<PlannedMonthlyContribution> initialContributions,
    required List<PlannedMonthlyContribution> updatedContributions,
  }) {
    final s = S.of(context);
    final delta = scoreAfter - scoreBefore;
    if (delta == 0) {
      return s?.checkinScoreReasonStable ??
          'Score stable ce mois: continue la regularite de tes actions.';
    }

    if (delta > 0) {
      if (totalVersements > 0) {
        return s?.checkinScoreReasonPositiveContrib(
              ForecasterService.formatChf(totalVersements),
            ) ??
            'Hausse principale: versements confirmes (${ForecasterService.formatChf(totalVersements)}) ce mois.';
      }
      if (revenusExceptionnels > 0) {
        return s?.checkinScoreReasonPositiveIncome ??
            'Hausse principale: revenu exceptionnel ajoute ce mois.';
      }
      return s?.checkinScoreReasonPositiveGeneral ??
          'Hausse principale: progression globale de ta discipline financiere.';
    }

    if (depensesExceptionnelles > 0) {
      return s?.checkinScoreReasonNegativeExpense(
            ForecasterService.formatChf(depensesExceptionnelles),
          ) ??
          'Baisse principale: depenses exceptionnelles ce mois (${ForecasterService.formatChf(depensesExceptionnelles)}).';
    }

    if (contributionsChanged &&
        initialContributions.length == updatedContributions.length) {
      var deltaPlanned = 0.0;
      for (var i = 0; i < initialContributions.length; i++) {
        deltaPlanned +=
            (updatedContributions[i].amount - initialContributions[i].amount);
      }
      if (deltaPlanned < 0) {
        return s?.checkinScoreReasonNegativeContrib(
              ForecasterService.formatChf(deltaPlanned.abs()),
            ) ??
            'Baisse principale: reduction de tes versements planifies (${ForecasterService.formatChf(deltaPlanned.abs())}/mois).';
      }
    }

    return s?.checkinScoreReasonNegativeGeneral ??
        'Baisse temporaire ce mois. On ajuste le plan au prochain check-in.';
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
    final s = S.of(context);
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
        (s?.checkinTitle(_currentMonthLabel) ?? 'CHECK-IN $_currentMonthLabel')
            .toUpperCase(),
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
    final s = S.of(context);
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
            _buildSectionTitle(
                s?.checkinPlannedSection ?? 'Versements planifiés'),
            const SizedBox(height: 12),
            ..._buildContributionRows(),
            const SizedBox(height: 28),

            // Section: Exceptional items
            _buildSectionTitle(s?.checkinEventsSection ?? 'Événements du mois'),
            const SizedBox(height: 12),
            _buildExceptionalField(
              label: s?.checkinExpenses ?? 'Dépenses exceptionnelles ?',
              hint: s?.checkinExpensesHint ?? 'Ex: 2000 (réparation voiture)',
              controller: _depensesController,
              icon: Icons.remove_circle_outline,
              color: MintColors.error,
            ),
            const SizedBox(height: 12),
            _buildExceptionalField(
              label: s?.checkinRevenues ?? 'Revenus exceptionnels ?',
              hint: s?.checkinRevenuesHint ?? 'Ex: 5000 (bonus annuel)',
              controller: _revenusController,
              icon: Icons.add_circle_outline,
              color: MintColors.success,
            ),
            const SizedBox(height: 28),

            // Section: Note
            _buildSectionTitle(
                s?.checkinNoteSection ?? 'Note du mois (optionnel)'),
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
    final s = S.of(context);
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
                s?.checkinHeader(_currentMonthLabel) ??
                    'Check-in $_currentMonthLabel',
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s?.checkinSubtitle ?? 'Confirme tes versements du mois',
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
            onDelete: () => _removeContribution(i),
          ),
        ),
      );
    }
    // Add button
    rows.add(_buildAddContributionButton());
    return rows;
  }

  Widget _buildAddContributionButton() {
    final s = S.of(context);
    return GestureDetector(
      onTap: _showAddContributionSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: MintColors.coachAccent.withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline,
                color: MintColors.coachAccent, size: 20),
            const SizedBox(width: 8),
            Text(
              s?.checkinAddContribution ?? 'Ajouter un versement',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: MintColors.coachAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeContribution(int index) {
    final coachProvider = context.read<CoachProfileProvider>();
    setState(() {
      final contributions =
          List<PlannedMonthlyContribution>.from(_profile.plannedContributions);
      contributions.removeAt(index);
      _amountControllers[index].dispose();
      _amountControllers.removeAt(index);
      _profile = _profile.copyWithContributions(contributions);
    });
    // Persist via provider
    coachProvider.removeContribution(index);
  }

  void _showAddContributionSheet() {
    final s = S.of(context);
    final categories = [
      (
        '3a',
        s?.checkinCat3a ?? 'Pilier 3a',
        Icons.savings,
        const Color(0xFF4F46E5)
      ),
      (
        'lpp_buyback',
        s?.checkinCatLpp ?? 'Rachat LPP',
        Icons.account_balance,
        const Color(0xFF0891B2)
      ),
      (
        'investissement',
        s?.checkinCatInvest ?? 'Investissement',
        Icons.trending_up,
        MintColors.success
      ),
      (
        'epargne_libre',
        s?.checkinCatEpargne ?? 'Epargne libre',
        Icons.wallet,
        MintColors.warning
      ),
    ];

    String selectedCategory = '3a';
    final labelController = TextEditingController();
    final amountController = TextEditingController();
    bool isAutomatic = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                  24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: MintColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    s?.checkinAddContribution ?? 'Ajouter un versement',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Category chips
                  Text(
                    s?.checkinCategoryLabel ?? 'Catégorie',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSelected = selectedCategory == cat.$1;
                      return GestureDetector(
                        onTap: () =>
                            setSheetState(() => selectedCategory = cat.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? cat.$4.withValues(alpha: 0.12)
                                : MintColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  isSelected ? cat.$4 : MintColors.lightBorder,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(cat.$3,
                                  size: 16,
                                  color: isSelected
                                      ? cat.$4
                                      : MintColors.textMuted),
                              const SizedBox(width: 6),
                              Text(
                                cat.$2,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? cat.$4
                                      : MintColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Label
                  Text(
                    s?.checkinLabelField ?? 'Nom',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: labelController,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: MintColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: s?.checkinLabelHint ??
                          'Ex: 3a VIAC, Epargne vacances...',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 13, color: MintColors.textMuted),
                      filled: true,
                      fillColor: MintColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: MintColors.lightBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: MintColors.lightBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: MintColors.coachAccent, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Amount
                  Text(
                    s?.checkinAmountField ?? 'Montant mensuel',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.inter(
                        fontSize: 14, color: MintColors.textPrimary),
                    decoration: InputDecoration(
                      prefixText: 'CHF ',
                      prefixStyle: GoogleFonts.inter(
                          fontSize: 13, color: MintColors.textMuted),
                      hintText: '0.00',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 13, color: MintColors.textMuted),
                      filled: true,
                      fillColor: MintColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: MintColors.lightBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: MintColors.lightBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: MintColors.coachAccent, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Auto/Manual toggle
                  Row(
                    children: [
                      Text(
                        s?.checkinAutoToggle ?? 'Ordre permanent (automatique)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: MintColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Switch.adaptive(
                        value: isAutomatic,
                        onChanged: (v) => setSheetState(() => isAutomatic = v),
                        activeThumbColor: MintColors.coachAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        final label = labelController.text.trim();
                        final amount =
                            double.tryParse(amountController.text) ?? 0;
                        if (label.isEmpty || amount <= 0) return;

                        final id =
                            '${selectedCategory}_${label.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
                        final contribution = PlannedMonthlyContribution(
                          id: id,
                          label: label,
                          amount: amount,
                          category: selectedCategory,
                          isAutomatic: isAutomatic,
                        );

                        Navigator.of(ctx).pop();
                        _addContribution(contribution);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MintColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        s?.checkinAddConfirm ?? 'Ajouter',
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _addContribution(PlannedMonthlyContribution contribution) {
    final coachProvider = context.read<CoachProfileProvider>();
    setState(() {
      final contributions =
          List<PlannedMonthlyContribution>.from(_profile.plannedContributions);
      contributions.add(contribution);
      _amountControllers.add(
        TextEditingController(text: contribution.amount.toStringAsFixed(2)),
      );
      _profile = _profile.copyWithContributions(contributions);
    });
    // Persist via provider
    coachProvider.addContribution(contribution);
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
                borderSide:
                    const BorderSide(color: MintColors.coachAccent, width: 1.5),
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
    final s = S.of(context);
    return TextFormField(
      controller: _noteController,
      maxLines: 3,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: MintColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: s?.checkinNoteHint ??
            'Ex: Mois compliqué, dépense imprévue pour la voiture...',
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
          borderSide:
              const BorderSide(color: MintColors.coachAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Submit button ──────────────────────────────────────────
  Widget _buildSubmitButton() {
    final s = S.of(context);
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
          s?.checkinSubmit ?? 'Valider le check-in',
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
    final s = S.of(context);
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
          s?.checkinSuccessTitle(_currentMonthLabel) ??
              'Bravo ! Check-in $_currentMonthLabel complété',
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
      ),
      const SizedBox(height: 32),

      // Score delta card
      if (_scoreAfter != _scoreBefore) _buildScoreDeltaCard(),
      if (_scoreAfter != _scoreBefore) const SizedBox(height: 16),

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
            s?.checkinSeeTrajectory ?? 'Voir ma trajectoire mise à jour',
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

  Widget _buildScoreDeltaCard() {
    final delta = _scoreAfter - _scoreBefore;
    final isPositive = delta > 0;
    final color = isPositive ? MintColors.success : MintColors.warning;
    final arrow = isPositive ? '↗' : '↘';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isPositive ? Icons.trending_up : Icons.trending_down,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ton score financier',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_scoreBefore $arrow $_scoreAfter / 100',
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPositive
                      ? '+$delta pts — tes actions portent leurs fruits !'
                      : '$delta pts — continue, chaque mois compte',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _scoreDeltaReason,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactCard() {
    final s = S.of(context);
    final impactFormatted = ForecasterService.formatChf(_impactCapital);
    final totalFormatted = ForecasterService.formatChf(_totalVersements);
    final impactLabel = _impactCapital.abs() < 1
        ? (s?.checkinImpactPending ?? 'Impact en cours de calcul')
        : (s?.checkinImpactCapital(impactFormatted) ??
            'Capital projeté +$impactFormatted ce mois');
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
                  s?.checkinImpactLabel ?? 'Impact sur ta trajectoire',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  impactLabel,
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: MintColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s?.checkinImpactTotal(totalFormatted) ??
                      'Total versements : $totalFormatted',
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
    final s = S.of(context);
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
                  s?.checkinStreakLabel ?? 'Série en cours',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s?.checkinStreakCount(_streak.toString()) ??
                      '$_streak mois consécutifs on-track !',
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
    final s = S.of(context);
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
                  s?.checkinCoachTip ?? 'Tip du coach',
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
    final s = S.of(context);
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
              s?.checkinDisclaimer ??
                  'Outil éducatif — ne constitue pas un conseil financier personnalisé. '
                      'Les projections sont basées sur des hypothèses et peuvent varier. '
                      'Consulte un·e spécialiste pour un accompagnement adapté. LSFin.',
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
  final VoidCallback? onDelete;

  const _ContributionRow({
    required this.contribution,
    required this.controller,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final icon = iconForCategory(contribution.category);
    final color = colorForCategory(contribution.category);

    return Stack(
      children: [
        Container(
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
                        contribution.isAutomatic
                            ? (s?.checkinAuto ?? 'Auto')
                            : (s?.checkinManuel ?? 'Manuel'),
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
                    if (double.tryParse(value) == null) {
                      return s?.checkinInvalidAmount ?? 'Montant invalide';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
        // Delete button
        if (onDelete != null)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: MintColors.error.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, size: 14, color: MintColors.error),
              ),
            ),
          ),
      ],
    );
  }
}
