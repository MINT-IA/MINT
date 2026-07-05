import 'package:flutter/material.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/cross_validation_service.dart';
import 'package:mint_mobile/services/data_quest/data_quest_service.dart';
import 'package:mint_mobile/services/dossier/dossier_payload_service.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Data block enrichment screen — deep-edit a specific confidence bloc.
///
/// P8 Phase 3: Routes /data-block/<type> land here.
/// Shows the current block score, prompts, and relevant input fields.
///
/// Supported block types: revenu, lpp, avs, 3a, patrimoine,
/// objectifRetraite, compositionMenage.
class DataBlockEnrichmentScreen extends StatefulWidget {
  final String blockType;
  static const Set<String> _supportedBlockTypes = {
    'revenu',
    'lpp',
    'avs',
    '3a',
    'patrimoine',
    'fiscalite',
    'objectifRetraite',
    'compositionMenage',
  };

  const DataBlockEnrichmentScreen({
    super.key,
    required this.blockType,
  });

  @override
  State<DataBlockEnrichmentScreen> createState() =>
      _DataBlockEnrichmentScreenState();
}

class _DataBlockEnrichmentScreenState
    extends State<DataBlockEnrichmentScreen> {
  bool _showCoachMode = false;
  final _cantonController = TextEditingController();
  final _salaryController = TextEditingController();
  final _birthYearController = TextEditingController();
  final _targetRetirementAgeController = TextEditingController();
  final _lppBalanceController = TextEditingController();
  final _pillar3aBalanceController = TextEditingController();
  final _savingsController = TextEditingController();
  final _targetPropertyController = TextEditingController();
  final _mortgageRateController = TextEditingController();
  final _collectorKey = GlobalKey();
  bool _seededRevenueInputs = false;
  bool _seededRetirementGoalInput = false;
  bool _seededLppInput = false;
  bool _seededPillar3aInput = false;
  bool _seededPatrimoineInputs = false;
  bool _seededHouseholdInput = false;
  bool _hasPensionFund = false;
  bool _hasPensionFundTouched = false;
  String _householdType = 'single';
  bool _isSavingRevenue = false;
  bool _isSavingRetirementGoal = false;
  bool _isSavingLpp = false;
  bool _isSavingPillar3a = false;
  bool _isSavingPatrimoine = false;
  bool _isSavingHousehold = false;
  bool _isReconfirming = false;
  String? _activeUpdateInputKey;
  String? _revenueError;
  String? _retirementGoalError;
  String? _lppError;
  String? _pillar3aError;
  String? _patrimoineError;

  /// Cached cross-validation alerts to avoid recomputing on every build.
  List<ValidationAlert>? _cachedAlerts;
  CoachProfile? _cachedAlertsProfile;

  List<ValidationAlert> _getAlertsForBlock(
      CoachProfile profile, String blockType) {
    // Recompute only when the profile object changes (Provider identity).
    if (!identical(profile, _cachedAlertsProfile)) {
      _cachedAlerts = CrossValidationService.validate(profile);
      _cachedAlertsProfile = profile;
    }
    return _cachedAlerts!.where((a) => a.block == blockType).toList();
  }

  void _seedRevenueInputs(CoachProfile? profile, Map<String, dynamic> answers) {
    if (_seededRevenueInputs) return;
    final hasDraft = _cantonController.text.isNotEmpty ||
        _salaryController.text.isNotEmpty ||
        _birthYearController.text.isNotEmpty ||
        _hasPensionFundTouched;
    if (hasDraft) {
      _seededRevenueInputs = true;
      return;
    }
    if (profile != null) {
      if (profile.canton.isNotEmpty) {
        _cantonController.text = profile.canton;
      }
      final salary = profile.revenuBrutAnnuel;
      if (salary > 0) {
        _salaryController.text = salary.round().toString();
      }
      if (profile.birthYear >= 1900) {
        _birthYearController.text = profile.birthYear.toString();
      }
    }
    final pensionFund = answers['q_has_pension_fund'];
    if (pensionFund is bool) {
      _hasPensionFund = pensionFund;
    }
    _seededRevenueInputs = true;
  }

  void _seedRetirementGoalInput(
    CoachProfile? profile,
    Map<String, dynamic> answers,
  ) {
    if (_seededRetirementGoalInput) return;
    if (_targetRetirementAgeController.text.isNotEmpty) {
      _seededRetirementGoalInput = true;
      return;
    }
    final targetAge = _parseAnswerAmount(answers['q_target_retirement_age']) ??
        profile?.targetRetirementAge;
    if (targetAge != null) {
      _targetRetirementAgeController.text = targetAge.toString();
    }
    _seededRetirementGoalInput = true;
  }

  void _seedLppInput(CoachProfile? profile, Map<String, dynamic> answers) {
    if (_seededLppInput) return;
    if (_lppBalanceController.text.isNotEmpty) {
      _seededLppInput = true;
      return;
    }
    final explicitAvoir = _parseAnswerAmount(
      answers['_coach_avoir_lpp'],
      allowZero: true,
    );
    if (explicitAvoir != null) {
      _lppBalanceController.text = explicitAvoir.toString();
      _seededLppInput = true;
      return;
    }

    final source = profile?.dataSources['prevoyance.avoirLppTotal'];
    final hasConfirmedProfileValue = source != null &&
        source != ProfileDataSource.estimated &&
        profile?.prevoyance.avoirLppTotal != null;
    if (hasConfirmedProfileValue) {
      _lppBalanceController.text =
          profile!.prevoyance.avoirLppTotal!.round().toString();
    }
    _seededLppInput = true;
  }

  void _seedPillar3aInput(
    CoachProfile? profile,
    Map<String, dynamic> answers,
  ) {
    if (_seededPillar3aInput) return;
    if (_pillar3aBalanceController.text.isNotEmpty) {
      _seededPillar3aInput = true;
      return;
    }
    final reported3a = _parseAnswerAmount(
      answers['q_3a_total'],
      allowZero: true,
    );
    final legacy3a = _parseAnswerAmount(
      answers['_coach_total_3a'],
      allowZero: true,
    );
    final explicit3a = reported3a ?? legacy3a;
    if (explicit3a != null) {
      _pillar3aBalanceController.text = explicit3a.toString();
      _seededPillar3aInput = true;
      return;
    }

    final source = profile?.dataSources['prevoyance.totalEpargne3a'];
    final hasConfirmedProfileValue = source != null &&
        source != ProfileDataSource.estimated &&
        profile?.prevoyance.totalEpargne3a != null;
    if (hasConfirmedProfileValue) {
      _pillar3aBalanceController.text =
          profile!.prevoyance.totalEpargne3a.round().toString();
    }
    _seededPillar3aInput = true;
  }

  void _seedPatrimoineInputs(Map<String, dynamic> answers) {
    if (_seededPatrimoineInputs) return;
    final hasDraft = _savingsController.text.isNotEmpty ||
        _targetPropertyController.text.isNotEmpty ||
        _mortgageRateController.text.isNotEmpty;
    if (hasDraft) {
      _seededPatrimoineInputs = true;
      return;
    }

    final liquidSavings = _parseAnswerAmount(
      answers['q_cash_total'],
      allowZero: true,
    );
    if (liquidSavings != null) {
      _savingsController.text = liquidSavings.toString();
    }
    final targetProperty = _parseAnswerAmount(
      answers['q_target_property_value'],
    );
    if (targetProperty != null) {
      _targetPropertyController.text = targetProperty.toString();
    }
    final mortgageRate = _parseAnswerAmount(
      answers['q_mortgage_rate'],
      allowZero: true,
    );
    final rawMortgageRate = answers['q_mortgage_rate'];
    if (rawMortgageRate is num) {
      _mortgageRateController.text =
          _formatMortgageRateInput(rawMortgageRate.toDouble());
    } else if (mortgageRate != null) {
      _mortgageRateController.text = mortgageRate.toString();
    }
    _seededPatrimoineInputs = true;
  }

  void _seedHouseholdInput(Map<String, dynamic> answers) {
    if (_seededHouseholdInput) return;
    _householdType = _normalizeHouseholdType(answers['q_civil_status']);
    _seededHouseholdInput = true;
  }

  int? _parseAnswerAmount(dynamic raw, {bool allowZero = false}) {
    final value = raw is num ? raw.round() : int.tryParse('$raw');
    if (value == null || value < 0) return null;
    if (!allowZero && value == 0) return null;
    return value;
  }

  @override
  void dispose() {
    _cantonController.dispose();
    _salaryController.dispose();
    _birthYearController.dispose();
    _targetRetirementAgeController.dispose();
    _lppBalanceController.dispose();
    _pillar3aBalanceController.dispose();
    _savingsController.dispose();
    _targetPropertyController.dispose();
    _mortgageRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CoachProfileProvider>();
    final profile = provider.profile;
    final answers = provider.answersSnapshot;
    final canonicalBlockType = _canonicalBlockType(widget.blockType);
    if (canonicalBlockType == 'revenu') {
      _seedRevenueInputs(profile, answers);
    }
    if (canonicalBlockType == 'objectifRetraite') {
      _seedRetirementGoalInput(profile, answers);
    }
    if (canonicalBlockType == 'lpp') {
      _seedLppInput(profile, answers);
    }
    if (canonicalBlockType == '3a') {
      _seedPillar3aInput(profile, answers);
    }
    if (canonicalBlockType == 'patrimoine') {
      _seedPatrimoineInputs(answers);
    }
    if (canonicalBlockType == 'compositionMenage') {
      _seedHouseholdInput(answers);
    }
    final hasInlineCollector =
        canonicalBlockType == 'revenu' ||
        canonicalBlockType == 'objectifRetraite' ||
        canonicalBlockType == 'lpp' ||
        canonicalBlockType == '3a' ||
        canonicalBlockType == 'patrimoine' ||
        canonicalBlockType == 'compositionMenage';
    final isKnownBlock =
        DataBlockEnrichmentScreen._supportedBlockTypes.contains(canonicalBlockType);
    final blocs = profile != null
        ? ConfidenceScorer.scoreAsBlocs(profile)
        : <String, BlockScore>{};
    final bloc = isKnownBlock ? blocs[canonicalBlockType] : null;
    final dataQuestFacts = profile == null
        ? const <String, BiographyFact>{}
        : DossierPayloadService.dataQuestFactsFromProfile(
            profile: profile,
            answers: answers,
          );
    final dataQuestPlan = profile == null
        ? null
        : _dataQuestPlanForBlock(canonicalBlockType, answers, dataQuestFacts);
    final reconfirmAsk =
        dataQuestPlan == null ? null : _firstReconfirmAsk(dataQuestPlan);
    final activeUpdateInputKey = _activeUpdateInputKey;
    final showInlineCollector =
        reconfirmAsk == null || activeUpdateInputKey != null;

    final l = S.of(context)!;
    final meta = _blockMeta(isKnownBlock ? canonicalBlockType : 'unknown', l);

    // Check if SLM or BYOK is available for coach mode
    final slmProvider = context.watch<SlmProvider>();
    final coachAvailable = slmProvider.isEngineAvailable;

    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
          onPressed: () => safePop(context),
        ),
        title: Text(
          meta.title,
          style: MintTextStyles.titleLarge(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // ── Block score indicator ────────────────────────────
              if (bloc != null) MintEntrance(child: _BlockScoreBar(bloc: bloc)),
              const SizedBox(height: 24),

              // ── Coach mode toggle ───────────────────────────────
              MintEntrance(delay: const Duration(milliseconds: 100), child: _CoachModeToggle(
                isCoachMode: _showCoachMode,
                coachAvailable: coachAvailable,
                onToggle: (value) {
                  if (value) {
                    // Navigate to coach chat with structured topic
                    context.go('/coach/chat?topic=${Uri.encodeComponent(canonicalBlockType)}');
                  } else {
                    setState(() => _showCoachMode = false);
                  }
                },
              )),
              const SizedBox(height: 16),

              // ── Description ─────────────────────────────────────
              ...[
                MintEntrance(delay: const Duration(milliseconds: 150), child: Text(
                  meta.description,
                  style: MintTextStyles.bodyMedium(color: MintColors.textSecondary).copyWith(height: 1.5),
                )),
                const SizedBox(height: 24),
              ],

              if (profile != null && reconfirmAsk != null) ...[
                MintEntrance(
                  delay: const Duration(milliseconds: 180),
                  child: _buildReconfirmCard(
                    ask: reconfirmAsk,
                    factsByLedgerKey: dataQuestFacts,
                    profile: profile,
                    blockType: canonicalBlockType,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Enrichment prompts for this block ────────────────
              if (profile != null && !hasInlineCollector) ...[
                MintEntrance(delay: const Duration(milliseconds: 200), child: _buildPrompts(profile, canonicalBlockType, bloc)),
              ],

              if (canonicalBlockType == 'revenu' && showInlineCollector) ...[
                MintEntrance(
                  delay: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: _collectorKey,
                    child: _buildRevenueCollector(onlyInputKey: activeUpdateInputKey),
                  ),
                ),
              ],
              if (canonicalBlockType == 'objectifRetraite' &&
                  showInlineCollector) ...[
                MintEntrance(
                  delay: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: _collectorKey,
                    child: _buildRetirementGoalCollector(),
                  ),
                ),
              ],
              if (canonicalBlockType == 'lpp' && showInlineCollector) ...[
                MintEntrance(
                  delay: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: _collectorKey,
                    child: _buildLppCollector(),
                  ),
                ),
              ],
              if (canonicalBlockType == '3a' && showInlineCollector) ...[
                MintEntrance(
                  delay: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: _collectorKey,
                    child: _buildPillar3aCollector(),
                  ),
                ),
              ],
              if (canonicalBlockType == 'patrimoine' && showInlineCollector) ...[
                MintEntrance(
                  delay: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: _collectorKey,
                    child: _buildPatrimoineCollector(onlyInputKey: activeUpdateInputKey),
                  ),
                ),
              ],
              if (canonicalBlockType == 'compositionMenage' && showInlineCollector) ...[
                MintEntrance(
                  delay: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: _collectorKey,
                    child: _buildHouseholdCollector(),
                  ),
                ),
              ],

              // ── Cross-validation alerts ────────────────────────────
              if (profile != null) ...[
                _buildValidationAlerts(profile, canonicalBlockType),
              ],

              const SizedBox(height: 32),

              // ── CTA ──────────────────────────────────────────────
              if (!hasInlineCollector) Semantics(
                button: true,
                label: meta.ctaLabel,
                child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    // Navigate to the appropriate enrichment flow
                    final route = _enrichmentRoute(canonicalBlockType);
                    if (route != null) {
                      context.push(route);
                    } else {
                      safePop(context);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    foregroundColor: MintColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    meta.ctaLabel,
                    style: MintTextStyles.titleMedium().copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              )),
              const SizedBox(height: 16),

              // ── Disclaimer ───────────────────────────────────────
              MintEntrance(child: Text(
                S.of(context)!.dataBlockDisclaimer,
                style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(height: 1.4),
                textAlign: TextAlign.center,
              )),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ))),
    );
  }

  Widget _buildRevenueCollector({String? onlyInputKey}) {
    final l = S.of(context)!;
    final capturesCanton = _capturesRevenue('canton', onlyInputKey);
    final capturesSalary = _capturesRevenue('incomeGrossYearly', onlyInputKey);
    final capturesBirthYear = _capturesRevenue('birthYear', onlyInputKey);
    final capturesPensionFund = _capturesRevenue('has2ndPillar', onlyInputKey);
    return MintSurface(
      padding: const EdgeInsets.all(16),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (capturesCanton) ...[
            TextField(
              key: const Key('canton_input'),
              controller: _cantonController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
                LengthLimitingTextInputFormatter(2),
              ],
              decoration: InputDecoration(
                labelText: l.affordabilityCanton,
                hintText: 'GE',
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (capturesSalary) ...[
            TextField(
              key: const Key('salary_input'),
              controller: _salaryController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l.dataBlockRevenueGrossAnnualLabel,
                prefixText: 'CHF ',
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (capturesBirthYear) ...[
            TextField(
              key: const Key('birth_year_input'),
              controller: _birthYearController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: InputDecoration(
                labelText: l.authDateOfBirth,
                hintText: '2001',
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (capturesPensionFund)
            SwitchListTile.adaptive(
              key: const Key('has_pension_fund_switch'),
              value: _hasPensionFund,
              contentPadding: EdgeInsets.zero,
              title: Text(l.eduThemeLppQuestion),
              onChanged: (value) {
                setState(() {
                  _hasPensionFund = value;
                  _hasPensionFundTouched = true;
                });
              },
            ),
          if (_revenueError != null) ...[
            const SizedBox(height: 8),
            Text(
              _revenueError!,
              style: MintTextStyles.labelSmall(color: MintColors.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('salary_save_cta'),
            onPressed: _isSavingRevenue ? null : _saveRevenueFacts,
            style: FilledButton.styleFrom(
              backgroundColor: MintColors.primary,
              foregroundColor: MintColors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _isSavingRevenue
                  ? l.dataBlockRevenueSaveSaving
                  : l.dataBlockRevenueSaveIdle,
              style: MintTextStyles.titleMedium().copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRevenueFacts() async {
    final onlyInputKey = _activeUpdateInputKey;
    final capturesCanton = _capturesRevenue('canton', onlyInputKey);
    final capturesSalary = _capturesRevenue('incomeGrossYearly', onlyInputKey);
    final capturesBirthYear = _capturesRevenue('birthYear', onlyInputKey);
    final capturesPensionFund = _capturesRevenue('has2ndPillar', onlyInputKey);
    final canton =
        capturesCanton ? _cantonController.text.trim().toUpperCase() : null;
    final salary = capturesSalary
        ? int.tryParse(_salaryController.text.trim())
        : null;
    final birthYearText =
        capturesBirthYear ? _birthYearController.text.trim() : '';
    int? birthYear;
    if (birthYearText.isNotEmpty) {
      birthYear = int.tryParse(birthYearText);
    }
    final currentYear = DateTime.now().year;

    String? error;
    if (capturesCanton && (canton == null || canton.length != 2)) {
      error = S.of(context)!.dataBlockRevenueInvalidAmount;
    } else if (capturesSalary && (salary == null || salary <= 0)) {
      error = S.of(context)!.dataBlockRevenueInvalidAmount;
    } else if (capturesBirthYear &&
        onlyInputKey == 'birthYear' &&
        birthYearText.isEmpty) {
      error = S.of(context)!.dataBlockRevenueInvalidAmount;
    } else if (capturesBirthYear &&
        birthYearText.isNotEmpty &&
        (birthYear == null || birthYear < 1900 || birthYear > currentYear)) {
      error = S.of(context)!.dataBlockRevenueInvalidAmount;
    }

    if (error != null) {
      setState(() => _revenueError = error);
      return;
    }

    setState(() {
      _isSavingRevenue = true;
      _revenueError = null;
    });

    final answers = <String, dynamic>{
      if (capturesSalary) 'q_gross_salary_annual': salary,
      if (capturesCanton) 'q_canton': canton,
      if (capturesBirthYear && birthYear != null) 'q_birth_year': birthYear,
      if (capturesPensionFund &&
          (onlyInputKey == 'has2ndPillar' || _hasPensionFundTouched))
        'q_has_pension_fund': _hasPensionFund,
    };

    await context.read<CoachProfileProvider>().mergeAnswers(answers);

    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isSavingRevenue = false;
      _activeUpdateInputKey = null;
    });
  }

  Widget _buildRetirementGoalCollector() {
    final l = S.of(context)!;
    return MintSurface(
      padding: const EdgeInsets.all(16),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('target_retirement_age_input'),
            controller: _targetRetirementAgeController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            decoration: InputDecoration(
              labelText: l.dataQuestFieldTargetRetirementAge,
              hintText: '64',
            ),
          ),
          if (_retirementGoalError != null) ...[
            const SizedBox(height: 8),
            Text(
              _retirementGoalError!,
              style: MintTextStyles.labelSmall(color: MintColors.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('retirement_goal_save_cta'),
            onPressed:
                _isSavingRetirementGoal ? null : _saveRetirementGoalFacts,
            style: FilledButton.styleFrom(
              backgroundColor: MintColors.primary,
              foregroundColor: MintColors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              l.dataBlockSaveIdle,
              style: MintTextStyles.titleMedium()
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRetirementGoalFacts() async {
    final targetAge =
        int.tryParse(_targetRetirementAgeController.text.trim());

    if (targetAge == null || targetAge < 58 || targetAge > 70) {
      setState(() {
        _retirementGoalError = S.of(context)!.dataBlockRevenueInvalidAmount;
      });
      return;
    }

    setState(() {
      _isSavingRetirementGoal = true;
      _retirementGoalError = null;
    });

    await context.read<CoachProfileProvider>().mergeAnswers({
      'q_target_retirement_age': targetAge,
    });

    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isSavingRetirementGoal = false;
      _activeUpdateInputKey = null;
    });
  }

  Widget _buildLppCollector() {
    final l = S.of(context)!;
    return MintSurface(
      padding: const EdgeInsets.all(16),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('lpp_balance_input'),
            controller: _lppBalanceController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l.affordabilityPillarLpp,
              prefixText: 'CHF ',
            ),
          ),
          if (_lppError != null) ...[
            const SizedBox(height: 8),
            Text(
              _lppError!,
              style: MintTextStyles.labelSmall(color: MintColors.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('lpp_save_cta'),
            onPressed: _isSavingLpp ? null : _saveLppFacts,
            style: FilledButton.styleFrom(
              backgroundColor: MintColors.primary,
              foregroundColor: MintColors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              l.dataBlockSaveIdle,
              style: MintTextStyles.titleMedium()
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('lpp_scan_cta'),
            onPressed: () => context.push('/scan?type=lpp'),
            icon: const Icon(Icons.document_scanner_outlined, size: 18),
            label: Text(l.dataBlockLppCta),
          ),
        ],
      ),
    );
  }

  Future<void> _saveLppFacts() async {
    final lppBalance = int.tryParse(_lppBalanceController.text.trim());

    if (lppBalance == null || lppBalance < 0) {
      setState(() => _lppError = S.of(context)!.dataBlockRevenueInvalidAmount);
      return;
    }

    setState(() {
      _isSavingLpp = true;
      _lppError = null;
    });

    await context.read<CoachProfileProvider>().mergeAnswers(
      {'_coach_avoir_lpp': lppBalance},
      source: ProfileDataSource.userInput,
    );

    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isSavingLpp = false;
      _activeUpdateInputKey = null;
    });
  }

  Widget _buildPillar3aCollector() {
    final l = S.of(context)!;
    return MintSurface(
      padding: const EdgeInsets.all(16),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('pillar3a_balance_input'),
            controller: _pillar3aBalanceController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l.affordabilityPillar3a,
              prefixText: 'CHF ',
            ),
          ),
          if (_pillar3aError != null) ...[
            const SizedBox(height: 8),
            Text(
              _pillar3aError!,
              style: MintTextStyles.labelSmall(color: MintColors.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('pillar3a_save_cta'),
            onPressed: _isSavingPillar3a ? null : _savePillar3aFacts,
            style: FilledButton.styleFrom(
              backgroundColor: MintColors.primary,
              foregroundColor: MintColors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              l.dataBlockSaveIdle,
              style: MintTextStyles.titleMedium()
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('pillar3a_simulator_cta'),
            onPressed: () => context.push('/pilier-3a'),
            icon: const Icon(Icons.savings_outlined, size: 18),
            label: Text(l.dataBlock3aCta),
          ),
        ],
      ),
    );
  }

  Future<void> _savePillar3aFacts() async {
    final balance = int.tryParse(_pillar3aBalanceController.text.trim());

    if (balance == null || balance < 0) {
      setState(() {
        _pillar3aError = S.of(context)!.dataBlockRevenueInvalidAmount;
      });
      return;
    }

    setState(() {
      _isSavingPillar3a = true;
      _pillar3aError = null;
    });

    await context.read<CoachProfileProvider>().mergeAnswers(
      {'q_3a_total': balance},
      source: ProfileDataSource.userInput,
    );

    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isSavingPillar3a = false;
      _activeUpdateInputKey = null;
    });
  }

  Widget _buildPatrimoineCollector({String? onlyInputKey}) {
    final l = S.of(context)!;
    final capturesSavings =
        _capturesPatrimoine('patrimoine.epargneLiquide', onlyInputKey);
    final capturesTargetProperty =
        _capturesPatrimoine('targetPropertyValue', onlyInputKey);
    final capturesMortgageRate =
        _capturesPatrimoine('patrimoine.mortgageRate', onlyInputKey);
    return MintSurface(
      padding: const EdgeInsets.all(16),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (capturesSavings) ...[
            TextField(
              key: const Key('savings_input'),
              controller: _savingsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l.financialSummaryEpargneLiquide,
                prefixText: 'CHF ',
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (capturesTargetProperty)
            TextField(
              key: const Key('target_property_input'),
              controller: _targetPropertyController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l.affordabilityTargetPrice,
                prefixText: 'CHF ',
              ),
            ),
          if (capturesMortgageRate) ...[
            if (capturesTargetProperty) const SizedBox(height: 12),
            TextField(
              key: const Key('mortgage_rate_input'),
              controller: _mortgageRateController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
              ],
              decoration: InputDecoration(
                labelText: l.locationTauxHypo,
                suffixText: '%',
              ),
            ),
          ],
          if (_patrimoineError != null) ...[
            const SizedBox(height: 8),
            Text(
              _patrimoineError!,
              style: MintTextStyles.labelSmall(color: MintColors.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('patrimoine_save_cta'),
            onPressed: _isSavingPatrimoine ? null : _savePatrimoineFacts,
            style: FilledButton.styleFrom(
              backgroundColor: MintColors.primary,
              foregroundColor: MintColors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              l.dataBlockSaveIdle,
              style: MintTextStyles.titleMedium().copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _savePatrimoineFacts() async {
    final onlyInputKey = _activeUpdateInputKey;
    final capturesSavings =
        _capturesPatrimoine('patrimoine.epargneLiquide', onlyInputKey);
    final capturesTargetProperty =
        _capturesPatrimoine('targetPropertyValue', onlyInputKey);
    final capturesMortgageRate =
        _capturesPatrimoine('patrimoine.mortgageRate', onlyInputKey);
    final savingsText = _savingsController.text.trim();
    final targetPropertyText = _targetPropertyController.text.trim();
    final mortgageRateText = _mortgageRateController.text.trim();
    final hasSavingsInput = capturesSavings && savingsText.isNotEmpty;
    final hasTargetPropertyInput =
        capturesTargetProperty && targetPropertyText.isNotEmpty;
    final hasMortgageRateInput =
        capturesMortgageRate && mortgageRateText.isNotEmpty;
    final savings = hasSavingsInput ? int.tryParse(savingsText) : null;
    final targetProperty =
        hasTargetPropertyInput ? int.tryParse(targetPropertyText) : null;
    final mortgageRate =
        hasMortgageRateInput ? _parseMortgageRatePercent(mortgageRateText) : null;

    String? error;
    if (onlyInputKey == null &&
        !hasSavingsInput &&
        !hasTargetPropertyInput &&
        !hasMortgageRateInput) {
      error = S.of(context)!.dataBlockRevenueInvalidAmount;
    } else if (onlyInputKey != null &&
        capturesSavings &&
        !hasSavingsInput) {
      error = S.of(context)!.dataBlockRevenueInvalidAmount;
    } else if (onlyInputKey != null &&
        capturesTargetProperty &&
        !hasTargetPropertyInput) {
      error = S.of(context)!.dataBlockRevenueInvalidAmount;
    } else if (onlyInputKey != null &&
        capturesMortgageRate &&
        !hasMortgageRateInput) {
      error = S.of(context)!.dataBlockRevenueInvalidAmount;
    } else if (hasSavingsInput && (savings == null || savings < 0)) {
      error = S.of(context)!.dataBlockRevenueInvalidAmount;
    } else if (hasTargetPropertyInput &&
        (targetProperty == null || targetProperty <= 0)) {
      error = S.of(context)!.dataBlockRevenueInvalidAmount;
    } else if (hasMortgageRateInput &&
        (mortgageRate == null || mortgageRate < 0 || mortgageRate > 0.2)) {
      error = S.of(context)!.dataBlockRevenueInvalidAmount;
    }

    if (error != null) {
      setState(() => _patrimoineError = error);
      return;
    }

    setState(() {
      _isSavingPatrimoine = true;
      _patrimoineError = null;
    });

    await context.read<CoachProfileProvider>().mergeAnswers({
      if (hasSavingsInput) 'q_cash_total': savings,
      if (hasTargetPropertyInput) 'q_target_property_value': targetProperty,
      if (hasMortgageRateInput) 'q_mortgage_rate': mortgageRate,
    });

    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isSavingPatrimoine = false;
      _activeUpdateInputKey = null;
    });
  }

  Widget _buildHouseholdCollector() {
    final l = S.of(context)!;
    final options = [
      (value: 'single', label: l.frontalierCelibataire),
      (value: 'cohabiting', label: l.concubinageConcubinage),
      (value: 'married', label: l.concubinageMariage),
    ];

    return MintSurface(
      padding: const EdgeInsets.all(16),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.frontalierEtatCivil,
            style: MintTextStyles.bodyMedium(
              color: MintColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                ChoiceChip(
                  key: Key('household_type_${option.value}'),
                  label: Text(option.label),
                  selected: _householdType == option.value,
                  selectedColor: MintColors.primary.withAlpha(36),
                  checkmarkColor: MintColors.primary,
                  labelStyle: MintTextStyles.labelMedium(
                    color: _householdType == option.value
                        ? MintColors.primary
                        : MintColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w600),
                  side: BorderSide(
                    color: _householdType == option.value
                        ? MintColors.primary
                        : MintColors.border,
                  ),
                  onSelected: (_) {
                    setState(() => _householdType = option.value);
                    HapticFeedback.selectionClick();
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('household_save_cta'),
            onPressed: _isSavingHousehold ? null : _saveHouseholdFacts,
            style: FilledButton.styleFrom(
              backgroundColor: MintColors.primary,
              foregroundColor: MintColors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              l.dataBlockSaveIdle,
              style: MintTextStyles.titleMedium()
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveHouseholdFacts() async {
    setState(() => _isSavingHousehold = true);

    await context.read<CoachProfileProvider>().mergeAnswers({
      'q_civil_status': _householdType,
    });

    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isSavingHousehold = false;
      _activeUpdateInputKey = null;
    });
  }

  DataQuestPlan? _dataQuestPlanForBlock(
    String blockType,
    Map<String, dynamic> answers,
    Map<String, BiographyFact> factsByLedgerKey,
  ) {
    final caseId = switch (blockType) {
      'revenu' => 'first_salary_tax',
      'lpp' => 'transmit_property',
      '3a' => 'transmit_property',
      'patrimoine' => 'buy_property',
      'objectifRetraite' => 'transmit_property',
      _ => null,
    };
    if (caseId == null) return null;
    return DataQuestService.planCase(
      caseId: caseId,
      answers: answers,
      now: DateTime.now().toUtc(),
      factsByLedgerKey: factsByLedgerKey,
    );
  }

  DataQuestAsk? _firstReconfirmAsk(DataQuestPlan plan) {
    for (final ask in plan.asks) {
      if (ask.mode == DataQuestAskMode.reconfirm) return ask;
    }
    return null;
  }

  Widget _buildReconfirmCard({
    required DataQuestAsk ask,
    required Map<String, BiographyFact> factsByLedgerKey,
    required CoachProfile profile,
    required String blockType,
  }) {
    final l = S.of(context)!;
    final fact = _factForAsk(ask, factsByLedgerKey);
    final prompt = l.freshnessReconfirmPrompt(
      _dataQuestFieldLabel(l, ask.inputKey),
      _formatPriorValue(l, ask.inputKey, ask.priorValue),
      _formatDate(l, fact?.sourceDate ?? fact?.updatedAt),
    );
    return MintSurface(
      key: const Key('data_block_reconfirm_card'),
      tone: MintSurfaceTone.bleu,
      padding: const EdgeInsets.all(16),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.update_rounded, color: MintColors.info, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  prompt,
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w600, height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('data_block_reconfirm_yes_cta'),
                onPressed: _isReconfirming
                    ? null
                    : () => _confirmStaleAsk(
                          ask: ask,
                          profile: profile,
                          fact: fact,
                        ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(l.freshnessReconfirmYes),
                style: FilledButton.styleFrom(
                  backgroundColor: MintColors.primary,
                  foregroundColor: MintColors.white,
                ),
              ),
              OutlinedButton.icon(
                key: const Key('data_block_reconfirm_update_cta'),
                onPressed: () => _startUpdateAsk(ask, blockType),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l.freshnessReconfirmUpdate),
              ),
              TextButton.icon(
                key: const Key('data_block_reconfirm_rescan_cta'),
                onPressed: () {
                  context.push('/scan?type=${Uri.encodeComponent(blockType)}');
                },
                icon: const Icon(Icons.document_scanner_outlined, size: 18),
                label: Text(l.freshnessReconfirmRescan),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmStaleAsk({
    required DataQuestAsk ask,
    required CoachProfile profile,
    required BiographyFact? fact,
  }) async {
    final field = _fieldSpecForAsk(ask);
    final answerKey = field?.answerKeys.first;
    final value = ask.priorValue;
    if (answerKey == null || value == null) return;
    setState(() => _isReconfirming = true);
    await context.read<CoachProfileProvider>().mergeAnswers(
      {answerKey: value},
      source: fact == null
          ? ProfileDataSource.userInput
          : profile.dataSources[fact.fieldPath] ?? ProfileDataSource.userInput,
      sourceDate: fact?.sourceDate,
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isReconfirming = false;
      _activeUpdateInputKey = null;
    });
  }

  void _startUpdateAsk(DataQuestAsk ask, String currentBlockType) {
    HapticFeedback.selectionClick();
    final targetBlockType = _editorBlockForInput(ask.inputKey, currentBlockType);
    if (targetBlockType != currentBlockType) {
      context.push('/data-block/$targetBlockType');
      return;
    }
    if (!_canInlineEdit(currentBlockType, ask.inputKey)) {
      context.push('/coach/chat?topic=${Uri.encodeComponent(currentBlockType)}');
      return;
    }
    setState(() {
      _activeUpdateInputKey = ask.inputKey;
      _revenueError = null;
      _retirementGoalError = null;
      _lppError = null;
      _pillar3aError = null;
      _patrimoineError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToCollector();
    });
  }

  void _scrollToCollector() {
    final context = _collectorKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  BiographyFact? _factForAsk(
    DataQuestAsk ask,
    Map<String, BiographyFact> factsByLedgerKey,
  ) {
    final ledgerKey = ask.ledgerKey;
    if (ledgerKey != null && factsByLedgerKey.containsKey(ledgerKey)) {
      return factsByLedgerKey[ledgerKey];
    }
    return factsByLedgerKey[ask.inputKey];
  }

  DataQuestFieldSpec? _fieldSpecForAsk(DataQuestAsk ask) {
    final spec = DataQuestCaseRegistry.p0Cases[ask.caseId];
    if (spec == null) return null;
    for (final field in [
      ...spec.guardFields,
      ...spec.requiredFields,
      ...spec.usefulFields,
    ]) {
      if (field.inputKey == ask.inputKey) return field;
    }
    return null;
  }

  String _editorBlockForInput(String inputKey, String fallbackBlockType) {
    return switch (inputKey) {
      'incomeGrossYearly' ||
      'canton' ||
      'birthYear' ||
      'has2ndPillar' =>
        'revenu',
      'targetRetirementAge' => 'objectifRetraite',
      'avoirLpp' => 'lpp',
      'pillar3aBalance' => '3a',
      'patrimoine.epargneLiquide' ||
      'parentLiquidAssets' ||
      'targetPropertyValue' ||
      'patrimoine.mortgageRate' =>
        'patrimoine',
      'householdType' => 'compositionMenage',
      _ => fallbackBlockType,
    };
  }

  bool _canInlineEdit(String blockType, String inputKey) {
    return switch (blockType) {
      'revenu' => inputKey == 'incomeGrossYearly' ||
          inputKey == 'canton' ||
          inputKey == 'birthYear' ||
          inputKey == 'has2ndPillar',
      'objectifRetraite' => inputKey == 'targetRetirementAge',
      'lpp' => inputKey == 'avoirLpp',
      '3a' => inputKey == 'pillar3aBalance',
      'patrimoine' => inputKey == 'patrimoine.epargneLiquide' ||
          inputKey == 'parentLiquidAssets' ||
          inputKey == 'targetPropertyValue' ||
          inputKey == 'patrimoine.mortgageRate',
      'compositionMenage' => inputKey == 'householdType',
      _ => false,
    };
  }

  bool _capturesRevenue(String inputKey, String? onlyInputKey) {
    return onlyInputKey == null || onlyInputKey == inputKey;
  }

  bool _capturesPatrimoine(String inputKey, String? onlyInputKey) {
    if (onlyInputKey == null) return true;
    if (inputKey == 'patrimoine.epargneLiquide') {
      return onlyInputKey == inputKey || onlyInputKey == 'parentLiquidAssets';
    }
    return onlyInputKey == inputKey;
  }

  double? _parseMortgageRatePercent(String raw) {
    final percent = double.tryParse(raw.replaceAll(',', '.'));
    if (percent == null) return null;
    return double.parse((percent / 100).toStringAsFixed(6));
  }

  String _formatMortgageRateInput(double raw) {
    final percent = raw > 0.3 ? raw : raw * 100;
    final fixed = percent.toStringAsFixed(2);
    return fixed
        .replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _normalizeHouseholdType(dynamic raw) {
    final value = raw?.toString().trim().toLowerCase();
    return switch (value) {
      'marie' || 'marié' || 'married' => 'married',
      'concubinage' ||
      'concubin' ||
      'concubine' ||
      'cohabiting' ||
      'couple' ||
      'family' =>
        'cohabiting',
      _ => 'single',
    };
  }

  String _dataQuestFieldLabel(S l, String inputKey) {
    return switch (inputKey) {
      'incomeGrossYearly' => l.affordabilityGrossIncome,
      'canton' => l.affordabilityCanton,
      'birthYear' => l.authDateOfBirth,
      'has2ndPillar' => l.eduThemeLppQuestion,
      'targetRetirementAge' => l.dataQuestFieldTargetRetirementAge,
      'avoirLpp' => l.affordabilityPillarLpp,
      'pillar3aBalance' => l.affordabilityPillar3a,
      'patrimoine.epargneLiquide' ||
      'parentLiquidAssets' =>
        l.financialSummaryEpargneLiquide,
      'targetPropertyValue' => l.affordabilityTargetPrice,
      'householdType' => l.dossierCoupleSection,
      'patrimoine.mortgageRate' => l.dataQuestFieldMortgageBalance,
      _ => l.dataQuestFieldFallback,
    };
  }

  String _formatPriorValue(S l, String inputKey, dynamic value) {
    if (value == null) return l.dossierDataUnknown;
    if (value is bool) {
      return value ? l.documentThirdPartyYes : l.documentThirdPartyNo;
    }
    if (value is num) {
      final formatted = _formatNumber(value);
      return switch (inputKey) {
        'incomeGrossYearly' ||
        'avoirLpp' ||
        'pillar3aBalance' ||
        'patrimoine.epargneLiquide' ||
        'parentLiquidAssets' ||
        'targetPropertyValue' =>
          'CHF $formatted',
        _ => formatted,
      };
    }
    return '$value';
  }

  String _formatNumber(num value) {
    final raw = value.round().toString();
    return raw.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => "'",
    );
  }

  String _formatDate(S l, DateTime? value) {
    if (value == null) return l.dossierDataUnknown;
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  Widget _buildPrompts(CoachProfile profile, String type, BlockScore? bloc) {
    final confidence = ConfidenceScorer.score(profile);
    final relevant = confidence.prompts
        .where((p) => _categoryMatchesBlock(p.category, type))
        .toList();

    if (relevant.isEmpty) {
      final isComplete = bloc?.status == 'complete';
      if (!isComplete) {
        return MintSurface(
          tone: MintSurfaceTone.peche,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: MintColors.warning, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  S.of(context)!.dataBlockIncomplete,
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(height: 1.4),
                ),
              ),
            ],
          ),
        );
      }
      return MintSurface(
        tone: MintSurfaceTone.sauge,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: MintColors.success, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                S.of(context)!.dataBlockComplete,
                style: MintTextStyles.bodyMedium(color: MintColors.success),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: relevant.map((prompt) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: MintSurface(
            padding: const EdgeInsets.all(16),
            radius: 12,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: MintColors.primary.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '+${prompt.impact}',
                      style: MintTextStyles.labelSmall(color: MintColors.primary).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prompt.label,
                        style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: MintSpacing.xs),
                      Text(
                        prompt.action,
                        style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildValidationAlerts(CoachProfile profile, String blockType) {
    final relevant = _getAlertsForBlock(profile, blockType);

    if (relevant.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 16),
        ...relevant.map((alert) {
          final color = switch (alert.severity) {
            AlertSeverity.error => MintColors.error,
            AlertSeverity.warning => MintColors.warning,
            AlertSeverity.info => MintColors.primary,
          };
          final icon = switch (alert.severity) {
            AlertSeverity.error => Icons.error_outline,
            AlertSeverity.warning => Icons.warning_amber_rounded,
            AlertSeverity.info => Icons.lightbulb_outline,
          };

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withAlpha(12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withAlpha(48)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: color, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          alert.message,
                          style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  if (alert.suggestion != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Text(
                        alert.suggestion!,
                        style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  bool _categoryMatchesBlock(String category, String blockType) {
    const mapping = {
      'revenu': ['income'],
      'lpp': ['lpp'],
      'avs': ['avs'],
      '3a': ['3a'],
      'patrimoine': ['patrimoine'],
      'fiscalite': ['fiscalite', 'tax', 'commune'],
      'objectifRetraite': ['objectif_retraite', 'retirement_urgency'],
      'compositionMenage': ['menage'],
      'foreign_pension': ['foreign_pension'],
    };
    final categories = mapping[blockType] ?? [];
    return categories.contains(category);
  }

  String? _enrichmentRoute(String type) {
    const routes = {
      'revenu': '/coach/chat', // P10-02b: was /onboarding/quick (deleted)
      'lpp': '/scan',
      'avs': '/document-scan/avs-guide',
      '3a': '/pilier-3a',
      'patrimoine': '/profile/bilan',
      'fiscalite': '/fiscal',
      'objectifRetraite': '/coach/cockpit',
      'compositionMenage': '/couple',
    };
    return routes[type] ?? '/profile/bilan';
  }

  String _canonicalBlockType(String rawType) {
    final normalized = _normalizeTypeToken(rawType);
    return switch (normalized) {
      'situation' ||
      'income' ||
      'salary' ||
      'revenu' ||
      'salaire' ||
      'base' ||
      'age_canton' =>
        'revenu',
      'couple' ||
      'menage' ||
      'household' ||
      'composition_menage' ||
      'compositionmenage' =>
        'compositionMenage',
      'pension' ||
      'lpp' ||
      'prevoyance' ||
      'prevoyance_lpp' ||
      'pension_lpp' ||
      'lpp_balance' ||
      'lpp_details' ||
      'taux_conversion' =>
        'lpp',
      'avs' || 'avs_extract' || 'ci' => 'avs',
      'goal' ||
      'objectif' ||
      'objectif_retraite' ||
      'retirement_goal' ||
      'retirement_urgency' =>
        'objectifRetraite',
      'housing' ||
      'property' ||
      'patrimoine' ||
      'wealth' ||
      'asset' ||
      'assets' =>
        'patrimoine',
      '3a' || 'pilier_3a' || 'epargne_3a' => '3a',
      'fiscalite' ||
      'fiscal' ||
      'tax' ||
      'impot' ||
      'impots' ||
      'tax_declaration' =>
        'fiscalite',
      _ => rawType.trim(),
    };
  }

  String _normalizeTypeToken(String value) {
    var normalized = value.trim().toLowerCase();
    const accents = {
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    accents.forEach((source, target) {
      normalized = normalized.replaceAll(source, target);
    });
    normalized = normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized;
  }

  _BlockMeta _blockMeta(String type, S l) {
    return switch (type) {
      'revenu' => _BlockMeta(
          title: l.dataBlockRevenuTitle,
          description: l.dataBlockRevenuDesc,
          ctaLabel: l.dataBlockRevenuCta,
        ),
      'lpp' => _BlockMeta(
          title: l.dataBlockLppTitle,
          description: l.dataBlockLppDesc,
          ctaLabel: l.dataBlockLppCta,
        ),
      'avs' => _BlockMeta(
          title: l.dataBlockAvsTitle,
          description: l.dataBlockAvsDesc,
          ctaLabel: l.dataBlockAvsCta,
        ),
      '3a' => _BlockMeta(
          title: l.dataBlock3aTitle,
          description: l.dataBlock3aDesc,
          ctaLabel: l.dataBlock3aCta,
        ),
      'patrimoine' => _BlockMeta(
          title: l.dataBlockPatrimoineTitle,
          description: l.dataBlockPatrimoineDesc,
          ctaLabel: l.dataBlockPatrimoineCta,
        ),
      'fiscalite' => _BlockMeta(
          title: l.dataBlockFiscaliteTitle,
          description: l.dataBlockFiscaliteDesc,
          ctaLabel: l.dataBlockFiscaliteCta,
        ),
      'objectifRetraite' => _BlockMeta(
          title: l.dataBlockObjectifTitle,
          description: l.dataBlockObjectifDesc,
          ctaLabel: l.dataBlockObjectifCta,
        ),
      'compositionMenage' => _BlockMeta(
          title: l.dataBlockMenageTitle,
          description: l.dataBlockMenageDesc,
          ctaLabel: l.dataBlockMenageCta,
        ),
      'unknown' => _BlockMeta(
          title: l.dataBlockUnknownTitle,
          description: l.dataBlockUnknownDesc,
          ctaLabel: l.dataBlockUnknownCta,
        ),
      _ => _BlockMeta(
          title: l.dataBlockDefaultTitle,
          description: l.dataBlockDefaultDesc,
          ctaLabel: l.dataBlockDefaultCta,
        ),
    };
  }
}

class _BlockMeta {
  final String title;
  final String description;
  final String ctaLabel;

  const _BlockMeta({
    required this.title,
    required this.description,
    required this.ctaLabel,
  });
}

class _BlockScoreBar extends StatelessWidget {
  final BlockScore bloc;

  const _BlockScoreBar({required this.bloc});

  @override
  Widget build(BuildContext context) {
    final ratio = bloc.maxScore > 0 ? bloc.score / bloc.maxScore : 0.0;
    final color = switch (bloc.status) {
      'complete' => MintColors.success,
      'partial' => MintColors.warning,
      _ => MintColors.error,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${bloc.score.round()} / ${bloc.maxScore.round()} pts',
              style: MintTextStyles.titleMedium(color: color).copyWith(fontWeight: FontWeight.w700),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                switch (bloc.status) {
                  'complete' => S.of(context)!.dataBlockStatusComplete,
                  'partial' => S.of(context)!.dataBlockStatusPartial,
                  _ => S.of(context)!.dataBlockStatusMissing,
                },
                style: MintTextStyles.labelSmall(color: color).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: MintColors.lightBorder,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Coach Mode Toggle
// ═══════════════════════════════════════════════════════════════

class _CoachModeToggle extends StatelessWidget {
  final bool isCoachMode;
  final bool coachAvailable;
  final ValueChanged<bool> onToggle;

  const _CoachModeToggle({
    required this.isCoachMode,
    required this.coachAvailable,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeChip(
            label: S.of(context)!.dataBlockModeForm,
            icon: Icons.edit_note,
            isSelected: !isCoachMode,
            onTap: () => onToggle(false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeChip(
            label: S.of(context)!.dataBlockModeCoach,
            icon: Icons.smart_toy_outlined,
            isSelected: isCoachMode,
            isDisabled: !coachAvailable,
            onTap: coachAvailable ? () => onToggle(true) : null,
          ),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback? onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.isDisabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDisabled
        ? MintColors.textMuted
        : isSelected
            ? MintColors.primary
            : MintColors.textSecondary;

    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? MintColors.primary.withAlpha(15)
                : MintColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? MintColors.primary.withAlpha(60)
                  : MintColors.lightBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: MintTextStyles.bodySmall(color: color).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Coach Bubble — conversational enrichment guide
// ═══════════════════════════════════════════════════════════════

// _CoachBubble removed — "Parle au coach" now navigates to /coach/chat
// with a contextual prompt for the block type.
