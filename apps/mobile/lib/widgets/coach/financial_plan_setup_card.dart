import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/financial_plan_ledger_inputs.dart';
import 'package:mint_mobile/services/plan_generation_service.dart';
import 'package:mint_mobile/services/session_epoch.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:provider/provider.dart';

enum _PlanSetupStep {
  category,
  retirementContext,
  details,
  confirmation,
}

/// App-owned setup for an intent-only `generate_financial_plan` tool call.
///
/// The coach goal is display-only until final confirmation. Category, amount,
/// date and retirement scope all cross this boundary through explicit Flutter
/// interactions; none are read from legacy tool arguments or written to the
/// profile/wizard ledgers.
class FinancialPlanSetupCard extends StatefulWidget {
  const FinancialPlanSetupCard({
    super.key,
    required this.goalHint,
    required this.planProvider,
    this.initialPlan,
    this.onConfirmed,
    this.initialError = false,
    this.clock = DateTime.now,
  });

  final String goalHint;
  final FinancialPlanProvider planProvider;
  final FinancialPlan? initialPlan;
  final VoidCallback? onConfirmed;
  final bool initialError;
  final DateTime Function() clock;

  @override
  State<FinancialPlanSetupCard> createState() => _FinancialPlanSetupCardState();
}

class _FinancialPlanSetupCardState extends State<FinancialPlanSetupCard> {
  late final TextEditingController _goalController;
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();

  _PlanSetupStep _step = _PlanSetupStep.category;
  String? _category;
  bool _horizonAcknowledged = false;
  bool _scopeAcknowledged = false;
  double? _prospectiveLppReturn;
  bool _earlyRetirementRuleAcknowledged = false;
  bool _postReferenceActivityAcknowledged = false;
  bool _isPreparing = false;
  bool _isSaving = false;
  bool _didSubmit = false;
  bool _hasError = false;
  String? _validationMessage;
  double? _confirmedAmount;
  DateTime? _confirmedTargetDate;
  FinancialPlan? _draftPlan;
  FinancialPlanDependencySnapshot? _draftInputs;
  bool _requiresPostReferenceActivity = false;
  bool _hasPreparationError = false;
  bool _draftChanged = false;
  FinancialPlanDependencyBlocker? _preparationBlocker;

  static bool _isRetirementCategory(String? category) =>
      category == 'goal_retirement_plan' || category == 'goal_pension_opt';

  static String _safeGoal(String raw) {
    final withoutControls = raw.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ');
    final scrubbed = ConversationStore.scrubPii(withoutControls)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return String.fromCharCodes(scrubbed.runes.take(100));
  }

  @override
  void initState() {
    super.initState();
    _goalController = TextEditingController(
      text: _safeGoal(widget.goalHint),
    )..addListener(_handleGoalChanged);
    _hasError = widget.initialError;
    final initialPlan = widget.initialPlan;
    final initialAmount = initialPlan?.goalAmount;
    if (initialPlan != null &&
        initialAmount != null &&
        initialAmount.isFinite &&
        initialAmount > 0 &&
        initialPlan.targetDate.isAfter(widget.clock())) {
      _category = initialPlan.goalCategory;
      _prospectiveLppReturn =
          initialPlan.projectionAssumptions?.caisseReturnBase;
      _amountController.text = initialAmount.toString();
      _dateController.text = DateFormat('yyyy-MM-dd').format(
        initialPlan.targetDate,
      );
      _step = _isRetirementCategory(_category)
          ? _PlanSetupStep.retirementContext
          : _PlanSetupStep.details;
    }
  }

  @override
  void dispose() {
    _goalController.removeListener(_handleGoalChanged);
    _goalController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _handleGoalChanged() {
    if (_step != _PlanSetupStep.confirmation || _draftPlan == null) return;
    setState(() {
      _draftPlan = null;
      _draftInputs = null;
      _confirmedAmount = null;
      _confirmedTargetDate = null;
      _hasPreparationError = true;
      _draftChanged = true;
      _step = _PlanSetupStep.details;
    });
  }

  void _selectCategory(String category) {
    setState(() {
      _category = category;
      _hasError = false;
      _hasPreparationError = false;
      _draftChanged = false;
      _validationMessage = null;
      _preparationBlocker = null;
      _draftPlan = null;
      _draftInputs = null;
      _earlyRetirementRuleAcknowledged = false;
      _postReferenceActivityAcknowledged = false;
      if (category != 'goal_retirement_plan') {
        _prospectiveLppReturn = null;
      }
      _step = _isRetirementCategory(category)
          ? _PlanSetupStep.retirementContext
          : _PlanSetupStep.details;
    });
  }

  void _continueFromRetirementContext() {
    final affiliation =
        context.read<CoachProfileProvider>().profile?.prevoyance.hasPensionFund;
    final explicitLpp = affiliation == true;
    if (affiliation == null ||
        !_horizonAcknowledged ||
        (explicitLpp &&
            (!_scopeAcknowledged || _prospectiveLppReturn == null))) {
      return;
    }
    setState(() => _step = _PlanSetupStep.details);
  }

  Future<void> _review(CoachProfile? profile) async {
    final reviewTime = widget.clock();
    final localeName = Localizations.localeOf(context).toString();
    final normalizedAmount = _amountController.text
        .trim()
        .replaceAll('\u2019', '')
        .replaceAll("'", '')
        .replaceAll('\u00a0', '')
        .replaceAll('\u202f', '')
        .replaceAll(' ', '');
    final amount = NumberFormat.decimalPattern(localeName)
        .tryParse(normalizedAmount)
        ?.toDouble();
    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(
          () => _validationMessage = S.of(context)!.planSetupInvalidAmount);
      return;
    }

    final targetDate = DateTime.tryParse(_dateController.text.trim());
    if (targetDate == null || !targetDate.isAfter(reviewTime)) {
      setState(() => _validationMessage = S.of(context)!.planSetupInvalidDate);
      return;
    }
    final retirementAge = _isRetirementCategory(_category) && profile != null
        ? _retirementAgeAt(profile, targetDate)
        : null;
    if (_isRetirementCategory(_category) &&
        (retirementAge == null || retirementAge < 58 || retirementAge > 70)) {
      setState(() => _validationMessage = S.of(context)!.planSetupInvalidDate);
      return;
    }
    final explicitLpp = profile?.prevoyance.hasPensionFund == true;
    if (_isRetirementCategory(_category) &&
        explicitLpp &&
        _prospectiveLppReturn == null) {
      setState(() =>
          _validationMessage = S.of(context)!.planSetupReturnAssumptionBody);
      return;
    }
    if (profile == null || _category == null) {
      setState(() {
        _preparationBlocker = FinancialPlanDependencyBlocker.unexpected;
        _hasPreparationError = true;
      });
      return;
    }

    late final SessionEpochGuard sessionGuard;
    try {
      sessionGuard = widget.planProvider.captureAccountSession();
    } on SessionEpochInvalidated {
      return;
    }

    setState(() {
      _confirmedAmount = amount;
      _confirmedTargetDate = targetDate;
      _validationMessage = null;
      _hasError = false;
      _hasPreparationError = false;
      _preparationBlocker = null;
      _draftChanged = false;
      _isPreparing = true;
      _draftPlan = null;
      _draftInputs = null;
      _earlyRetirementRuleAcknowledged = false;
      _postReferenceActivityAcknowledged = false;
    });

    try {
      final generatedAt = reviewTime;
      final safeGoal = _safeGoal(_goalController.text);
      final l = S.of(context)!;
      final resolvedGoal = safeGoal.isNotEmpty
          ? safeGoal
          : _isRetirementCategory(_category)
              ? l.planSetupCategoryRetirement
              : l.planSetupCategoryGeneral;
      _goalController.value = TextEditingValue(
        text: resolvedGoal,
        selection: TextSelection.collapsed(offset: resolvedGoal.length),
      );
      final ledger = context.read<CoachProfileProvider>();
      late final String owner;
      try {
        owner = await ledger.previewCanonicalProfileOwner();
        sessionGuard.assertCurrent();
      } on FinancialPlanDependencyBlocked {
        rethrow;
      } on StateError catch (error) {
        throw FinancialPlanDependencyBlocked(
          FinancialPlanDependencyBlocker.ownerAuthority,
          error.message,
        );
      }
      final selfLppSnapshot = ledger.currentLppSnapshot(
        LppEvidenceOwnerKind.self,
      );
      final inputs = FinancialPlanDependencySnapshot.fromProfile(
        profile,
        profileOwnerId: owner,
        goalCategory: _category!,
        goalAmount: amount,
        targetDate: targetDate,
        prospectiveLppReturn: _prospectiveLppReturn,
        selfLppSnapshot: selfLppSnapshot,
        now: generatedAt,
      );
      final draft = await PlanGenerationService.generate(
        goalDescription: resolvedGoal,
        goalCategory: _category!,
        targetDate: targetDate,
        profile: profile,
        profileOwnerId: owner,
        selfLppSnapshot: selfLppSnapshot,
        goalAmount: amount,
        prospectiveLppReturn: _prospectiveLppReturn,
        now: generatedAt,
      );
      sessionGuard.assertCurrent();
      if (!mounted) return;
      setState(() {
        _draftPlan = draft;
        _draftInputs = inputs;
        _requiresPostReferenceActivity = inputs.requiresPostReferenceActivity;
        _step = _PlanSetupStep.confirmation;
      });
    } on SessionEpochInvalidated {
      return;
    } on FinancialPlanDependencyBlocked catch (error) {
      debugPrint('[financial_plan_setup] dependency_blocked');
      if (mounted) {
        setState(() {
          _preparationBlocker = error.blocker;
          _hasPreparationError = true;
          _draftChanged = false;
          _step = _PlanSetupStep.details;
        });
      }
    } catch (_) {
      debugPrint('[financial_plan_setup] draft_calculation_failed');
      if (mounted) {
        setState(() {
          _hasPreparationError = true;
          _preparationBlocker = FinancialPlanDependencyBlocker.unexpected;
          _draftChanged = false;
          _step = _PlanSetupStep.details;
        });
      }
    } finally {
      try {
        sessionGuard.assertCurrent();
        if (mounted) setState(() => _isPreparing = false);
      } on SessionEpochInvalidated {
        // The account-session transition owns the visible recovery state.
      }
    }
  }

  int? _retirementAgeAt(CoachProfile profile, DateTime targetDate) {
    final birthDate = profile.dateOfBirth;
    final birthYear = birthDate?.year ?? profile.birthYear;
    if (birthYear <= 0) return null;
    var age = targetDate.year - birthYear;
    if (birthDate != null &&
        (targetDate.month < birthDate.month ||
            (targetDate.month == birthDate.month &&
                targetDate.day < birthDate.day))) {
      age--;
    }
    return age;
  }

  Future<void> _confirm(CoachProfileProvider ledger) async {
    if (_isSaving || _didSubmit) return;
    final draft = _draftPlan;
    final profile = ledger.profile;
    if (!ledger.isLoaded ||
        profile == null ||
        draft == null ||
        !_ageConditionsAcknowledged) {
      setState(() => _hasError = true);
      return;
    }

    late final SessionEpochGuard sessionGuard;
    try {
      sessionGuard = widget.planProvider.captureAccountSession();
    } on SessionEpochInvalidated {
      return;
    }

    setState(() {
      _isSaving = true;
      _didSubmit = true;
      _hasError = false;
    });

    final confirmationTime = widget.clock();
    try {
      late final FinancialPlanDependencySnapshot currentInputs;
      try {
        final owner = await _previewOwnerForConfirmation(ledger);
        sessionGuard.assertCurrent();
        if (owner != draft.profileOwnerId ||
            _safeGoal(_goalController.text) != draft.goalDescription) {
          throw StateError('financial plan draft owner or goal changed');
        }
        currentInputs = FinancialPlanDependencySnapshot.fromProfile(
          profile,
          profileOwnerId: owner,
          goalCategory: draft.goalCategory,
          goalAmount: draft.goalAmount!,
          targetDate: draft.targetDate,
          prospectiveLppReturn: draft.projectionAssumptions?.caisseReturnBase,
          selfLppSnapshot: ledger.currentLppSnapshot(
            LppEvidenceOwnerKind.self,
          ),
          now: confirmationTime,
        );
      } on SessionEpochInvalidated {
        rethrow;
      } on FinancialPlanDependencyBlocked catch (error) {
        debugPrint('[financial_plan_setup] confirmation_dependency_blocked');
        if (mounted) {
          setState(() {
            _didSubmit = false;
            _draftPlan = null;
            _draftInputs = null;
            _preparationBlocker = error.blocker;
            _hasPreparationError = true;
            _draftChanged = false;
            _step = _PlanSetupStep.details;
          });
        }
        return;
      } on ArgumentError {
        _invalidateDraftAfterConfirmationDrift();
        return;
      } on StateError {
        _invalidateDraftAfterConfirmationDrift();
        return;
      }

      if (currentInputs.profileOwnerId != draft.profileOwnerId ||
          currentInputs.schemaVersion != draft.dependencySchemaVersion ||
          currentInputs.branch.wireName != draft.dependencyBranch ||
          currentInputs.basis.wireName != draft.dependencyBasis ||
          currentInputs.fingerprint != draft.dependencyHash ||
          currentInputs.validUntil.toUtc() != draft.validUntil?.toUtc() ||
          currentInputs.requiresPostReferenceActivity !=
              _requiresPostReferenceActivity) {
        _invalidateDraftAfterConfirmationDrift();
        return;
      }

      try {
        sessionGuard.assertCurrent();
        await ledger.commitStagedCanonicalProfileOwner(draft.profileOwnerId!);
        sessionGuard.assertCurrent();
        widget.planProvider.attachProfileProvider(ledger);
        await widget.planProvider.setPlan(
          draft.copyWith(confirmedAt: confirmationTime),
        );
        sessionGuard.assertCurrent();
        if (mounted) widget.onConfirmed?.call();
      } on SessionEpochInvalidated {
        rethrow;
      } catch (_) {
        debugPrint('[financial_plan_setup] confirmation_failed');
        if (mounted) {
          setState(() {
            _didSubmit = false;
            _hasError = true;
          });
        }
      }
    } on SessionEpochInvalidated {
      return;
    } finally {
      try {
        sessionGuard.assertCurrent();
        if (mounted) setState(() => _isSaving = false);
      } on SessionEpochInvalidated {
        // The account-session transition owns the visible recovery state.
      }
    }
  }

  Future<String> _previewOwnerForConfirmation(
    CoachProfileProvider ledger,
  ) async {
    try {
      return await ledger.previewCanonicalProfileOwner();
    } on FinancialPlanDependencyBlocked {
      rethrow;
    } on StateError catch (error) {
      throw FinancialPlanDependencyBlocked(
        FinancialPlanDependencyBlocker.ownerAuthority,
        error.message,
      );
    }
  }

  void _invalidateDraftAfterConfirmationDrift() {
    if (!mounted) return;
    setState(() {
      _didSubmit = false;
      _draftPlan = null;
      _draftInputs = null;
      _hasPreparationError = true;
      _draftChanged = true;
      _step = _PlanSetupStep.details;
    });
  }

  bool get _ageConditionsAcknowledged {
    if (_draftInputs?.branch != FinancialPlanDependencyBranch.retirementLpp) {
      return true;
    }
    final assumptions = _draftPlan?.projectionAssumptions;
    if (assumptions?.requiresFundAuthorizationBefore63 == true &&
        !_earlyRetirementRuleAcknowledged) {
      return false;
    }
    if (assumptions?.assumesPostReferenceGainfulActivity == true &&
        !_postReferenceActivityAcknowledged) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final ledger = context.watch<CoachProfileProvider>();

    return Semantics(
      identifier: 'financial_plan_setup',
      container: true,
      liveRegion: _hasError,
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.appleSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MintColors.border),
        ),
        padding: const EdgeInsets.all(MintSpacing.md),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.planSetupTitle,
                style:
                    MintTextStyles.titleMedium(color: MintColors.textPrimary),
              ),
              const SizedBox(height: MintSpacing.xs),
              Semantics(
                identifier: 'financial_plan_setup_goal',
                textField: true,
                child: TextField(
                  controller: _goalController,
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: l.planSetupGoalLabel,
                    helperText: widget.goalHint.trim().isEmpty
                        ? null
                        : l.planSetupHint(_safeGoal(widget.goalHint)),
                  ),
                ),
              ),
              const SizedBox(height: MintSpacing.md),
              switch (_step) {
                _PlanSetupStep.category => _buildCategory(l),
                _PlanSetupStep.retirementContext => _buildRetirementContext(l),
                _PlanSetupStep.details => _buildDetails(l, ledger.profile),
                _PlanSetupStep.confirmation => _buildConfirmation(l, ledger),
              },
              if (_validationMessage != null) ...[
                const SizedBox(height: MintSpacing.sm),
                Text(
                  _validationMessage!,
                  style: MintTextStyles.bodyMedium(color: MintColors.error),
                ),
              ],
              if (_hasPreparationError) ...[
                const SizedBox(height: MintSpacing.sm),
                Semantics(
                  identifier: _draftChanged
                      ? 'financial_plan_setup_draft_changed'
                      : 'financial_plan_setup_missing_data',
                  liveRegion: true,
                  child: Text(
                    _draftChanged
                        ? l.planSetupDraftChanged
                        : _preparationMessage(l),
                    style: MintTextStyles.bodyMedium(color: MintColors.error),
                  ),
                ),
                if (!_draftChanged &&
                    (_preparationBlocker ==
                            FinancialPlanDependencyBlocker.affiliation ||
                        _preparationBlocker ==
                            FinancialPlanDependencyBlocker.salary)) ...[
                  const SizedBox(height: MintSpacing.xs),
                  Semantics(
                    identifier: 'financial_plan_setup_enrich_revenue',
                    button: true,
                    child: TextButton(
                      onPressed: () => context.push(
                        _preparationBlocker ==
                                FinancialPlanDependencyBlocker.affiliation
                            ? '/data-block/revenu?inputKey=q_has_pension_fund'
                            : '/data-block/revenu?inputKey=q_gross_salary_annual',
                      ),
                      child: Text(l.dataBlockRevenuCta),
                    ),
                  ),
                ],
                if (!_draftChanged &&
                    _preparationBlocker ==
                        FinancialPlanDependencyBlocker.gender) ...[
                  const SizedBox(height: MintSpacing.xs),
                  Semantics(
                    identifier: 'financial_plan_setup_enrich_gender',
                    button: true,
                    child: TextButton(
                      onPressed: () => context.push(
                        '/data-block/revenu?inputKey=q_gender',
                      ),
                      child: Text(l.dataBlockRevenuCta),
                    ),
                  ),
                ],
                if (!_draftChanged &&
                    _preparationBlocker ==
                        FinancialPlanDependencyBlocker.dateOfBirth) ...[
                  const SizedBox(height: MintSpacing.xs),
                  Semantics(
                    identifier: 'financial_plan_setup_enrich_date_of_birth',
                    button: true,
                    child: TextButton(
                      onPressed: () => context.push(
                        '/data-block/revenu?inputKey=q_date_of_birth',
                      ),
                      child: Text(l.dataBlockRevenuCta),
                    ),
                  ),
                ],
                if (!_draftChanged &&
                    _preparationBlocker == FinancialPlanDependencyBlocker.lpp &&
                    ledger.profile?.prevoyance.hasPensionFund == true &&
                    FeatureFlags.lppEvidenceIngestionEnabled) ...[
                  const SizedBox(height: MintSpacing.xs),
                  Semantics(
                    identifier: 'financial_plan_setup_enrich_lpp',
                    button: true,
                    child: TextButton(
                      onPressed: () =>
                          context.push('/scan?type=lppCertificate'),
                      child: Text(l.planSetupEnrichLpp),
                    ),
                  ),
                ],
              ],
              if (_hasError) ...[
                const SizedBox(height: MintSpacing.sm),
                Semantics(
                  identifier: 'financial_plan_setup_error',
                  container: true,
                  liveRegion: true,
                  child: Text(
                    l.planSetupError,
                    style: MintTextStyles.bodyMedium(color: MintColors.error),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategory(S l) {
    return Semantics(
      identifier: 'financial_plan_setup_category',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.planSetupCategoryTitle,
            style: MintTextStyles.bodyLarge(color: MintColors.textPrimary),
          ),
          const SizedBox(height: MintSpacing.sm),
          _semanticButton(
            identifier: 'financial_plan_setup_category_general',
            label: l.planSetupCategoryGeneral,
            onPressed: () => _selectCategory('goal_general'),
          ),
          const SizedBox(height: MintSpacing.xs),
          _semanticButton(
            identifier: 'financial_plan_setup_category_retirement',
            label: l.planSetupCategoryRetirement,
            onPressed: () => _selectCategory('goal_retirement_plan'),
          ),
        ],
      ),
    );
  }

  Widget _buildRetirementContext(S l) {
    final affiliation =
        context.read<CoachProfileProvider>().profile?.prevoyance.hasPensionFund;
    final explicitLpp = affiliation == true;
    final explicitNoLpp = affiliation == false;
    final canContinue = affiliation != null &&
        _horizonAcknowledged &&
        (!explicitLpp || (_scopeAcknowledged && _prospectiveLppReturn != null));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          identifier: 'financial_plan_setup_retirement_horizon',
          container: true,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _horizonAcknowledged,
            onChanged: (value) =>
                setState(() => _horizonAcknowledged = value ?? false),
            title: Text(l.planSetupRetirementHorizonTitle),
            subtitle: Text(l.planSetupRetirementHorizonBody),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
        if (explicitLpp) ...[
          Semantics(
            identifier: 'financial_plan_setup_retirement_scope',
            container: true,
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _scopeAcknowledged,
              onChanged: (value) =>
                  setState(() => _scopeAcknowledged = value ?? false),
              title: Text(l.planSetupRetirementScopeTitle),
              subtitle: Text(l.planSetupRetirementScopeBody),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
        ] else if (explicitNoLpp) ...[
          const SizedBox(height: MintSpacing.xs),
          Text(
            l.planCard_retirementScopeNoLpp,
            style: MintTextStyles.micro(color: MintColors.textMuted),
          ),
        ] else ...[
          const SizedBox(height: MintSpacing.xs),
          Text(
            l.planSetupBlockerAffiliation,
            style: MintTextStyles.bodyMedium(color: MintColors.error),
          ),
          Semantics(
            identifier: 'financial_plan_setup_enrich_revenue',
            button: true,
            child: TextButton(
              onPressed: () => context.push(
                '/data-block/revenu?inputKey=q_has_pension_fund',
              ),
              child: Text(l.dataBlockRevenuCta),
            ),
          ),
        ],
        if (explicitLpp) ...[
          const SizedBox(height: MintSpacing.sm),
          Semantics(
            identifier: 'financial_plan_setup_return_assumption',
            container: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.planSetupReturnAssumptionTitle,
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  l.planSetupReturnAssumptionBody,
                  style: MintTextStyles.micro(color: MintColors.textMuted),
                ),
                const SizedBox(height: MintSpacing.xs),
                Wrap(
                  spacing: MintSpacing.xs,
                  children:
                      const [0.01, 0.02, 0.03].map(_returnChoice).toList(),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: MintSpacing.sm),
        Semantics(
          identifier: 'financial_plan_setup_retirement_continue',
          container: true,
          button: true,
          enabled: canContinue,
          onTap: canContinue ? _continueFromRetirementContext : null,
          child: ExcludeSemantics(
            child: FilledButton(
              onPressed: canContinue ? _continueFromRetirementContext : null,
              child: Text(l.planSetupContinue),
            ),
          ),
        ),
      ],
    );
  }

  Widget _returnChoice(double rate) {
    final localeName = Localizations.localeOf(context).toString();
    final label = NumberFormat.decimalPercentPattern(
      locale: localeName,
      decimalDigits: 1,
    ).format(rate);
    final option = (rate * 100).round();
    return Semantics(
      identifier: 'financial_plan_setup_return_assumption_$option',
      button: true,
      selected: _prospectiveLppReturn == rate,
      child: ChoiceChip(
        label: Text(label),
        selected: _prospectiveLppReturn == rate,
        onSelected: (_) => setState(() => _prospectiveLppReturn = rate),
      ),
    );
  }

  Widget _buildDetails(S l, CoachProfile? profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.planSetupDetailsTitle,
          style: MintTextStyles.bodyLarge(color: MintColors.textPrimary),
        ),
        const SizedBox(height: MintSpacing.sm),
        Semantics(
          identifier: 'financial_plan_setup_amount',
          textField: true,
          child: TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l.planSetupAmountLabel),
          ),
        ),
        const SizedBox(height: MintSpacing.sm),
        Semantics(
          identifier: 'financial_plan_setup_target_date',
          textField: true,
          child: TextField(
            controller: _dateController,
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(labelText: l.planSetupDateLabel),
          ),
        ),
        const SizedBox(height: MintSpacing.md),
        _semanticButton(
          identifier: 'financial_plan_setup_review',
          label: _isPreparing ? l.planSetupPreparing : l.planSetupReview,
          onPressed: () {
            if (!_isPreparing) _review(profile);
          },
        ),
      ],
    );
  }

  Widget _buildConfirmation(S l, CoachProfileProvider ledger) {
    final amount = _confirmedAmount!;
    final targetDate = _confirmedTargetDate!;
    final draft = _draftPlan!;
    final inputs = _draftInputs!;
    final assumptions = draft.projectionAssumptions;
    final localeName = Localizations.localeOf(context).toString();
    final amountText = NumberFormat('#,##0.##', localeName).format(amount);
    final dateText = DateFormat.yMd(localeName).format(targetDate);
    final chf = NumberFormat.currency(
      locale: localeName,
      symbol: '',
      decimalDigits: 0,
    );
    final percent = NumberFormat.decimalPercentPattern(
      locale: localeName,
      decimalDigits: 1,
    );
    final profile = ledger.profile!;
    final sourcePath = _capitalSourcePath(profile);
    final source = sourcePath == null ? null : profile.dataSources[sourcePath];
    final sourceDate =
        sourcePath == null ? null : profile.dataSourceDates[sourcePath];
    final salaryAnnual = assumptions?.salaryBasis.annualChf;
    final salaryBasisMatchesProfile = salaryAnnual != null &&
        (salaryAnnual - inputs.grossAnnualSalary).abs() < 0.01;
    final salarySource = salaryBasisMatchesProfile
        ? profile.dataSources['salaireBrutMensuel']
        : null;
    final salaryUpdatedAt = salaryBasisMatchesProfile
        ? profile.dataTimestamps['salaireBrutMensuel']
        : null;
    final salaryFreshnessDays = salaryUpdatedAt == null
        ? null
        : draft.generatedAt
            .difference(salaryUpdatedAt)
            .inDays
            .clamp(0, 99999)
            .toInt();
    final canConfirm = !_isSaving && _ageConditionsAcknowledged;

    return Semantics(
      identifier: 'financial_plan_setup_confirmation',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.planSetupConfirmationTitle,
            style: MintTextStyles.bodyLarge(color: MintColors.textPrimary),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            l.planSetupConfirmationBody(
              draft.goalDescription,
              amountText,
              dateText,
            ),
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
          ),
          if (inputs.branch !=
              FinancialPlanDependencyBranch.retirementNoLpp) ...[
            const SizedBox(height: MintSpacing.xs),
            Semantics(
              identifier: 'financial_plan_setup_monthly_amount',
              container: true,
              child: Text(
                l.planCard_monthlyAmount(
                  chf.format(draft.monthlyTarget).trim(),
                ),
                style: MintTextStyles.bodyMedium(
                  color: MintColors.textPrimary,
                ),
              ),
            ),
          ],
          if (inputs.branch ==
              FinancialPlanDependencyBranch.retirementNoLpp) ...[
            const SizedBox(height: MintSpacing.sm),
            Text(
              l.planCard_retirementNoLppNarrative(
                chf.format(draft.monthlyTarget).trim(),
              ),
              style: MintTextStyles.bodyMedium(
                color: MintColors.textSecondary,
              ),
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              l.planCard_retirementScopeNoLpp,
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
            Semantics(
              identifier: 'financial_plan_setup_savings_return_zero',
              container: true,
              child: Text(
                l.planCard_supplementalSavingsReturnZero,
                style: MintTextStyles.micro(color: MintColors.textMuted),
              ),
            ),
            Text(
              l.planCard_dataConfidence(
                draft.confidenceLevel.round().toString(),
              ),
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ],
          if (inputs.branch == FinancialPlanDependencyBranch.retirementLpp) ...[
            const SizedBox(height: MintSpacing.sm),
            Text(
              l.planSetupLegalBaseline,
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
            ),
            if (inputs.currentLppCapital case final capital?) ...[
              const SizedBox(height: MintSpacing.xs),
              Text(
                l.planSetupCapitalUsed(chf.format(capital).trim()),
                style: MintTextStyles.micro(color: MintColors.textMuted),
              ),
            ],
            if (draft.projectedLow case final low?)
              if (draft.projectedHigh case final high?)
                Semantics(
                  identifier: 'financial_plan_setup_projection_band',
                  container: true,
                  child: Text(
                    l.planCard_confidenceBands(
                      chf.format(low).trim(),
                      chf.format(draft.projectedOutcome).trim(),
                      chf.format(high).trim(),
                    ),
                    style: MintTextStyles.micro(color: MintColors.textMuted),
                  ),
                ),
            if (assumptions?.caisseReturnBase case final value?)
              Text(
                l.planCard_returnBase(percent.format(value)),
                style: MintTextStyles.micro(color: MintColors.textMuted),
              ),
            if (assumptions?.caisseReturnLow case final value?)
              Text(
                l.planCard_returnLow(percent.format(value)),
                style: MintTextStyles.micro(color: MintColors.textMuted),
              ),
            if (assumptions?.caisseReturnHigh case final value?)
              Text(
                l.planCard_returnHigh(percent.format(value)),
                style: MintTextStyles.micro(color: MintColors.textMuted),
              ),
            if (assumptions?.supplementalMonthlySavingsReturn == 0)
              Text(
                l.planCard_supplementalSavingsReturnZero,
                style: MintTextStyles.micro(color: MintColors.textMuted),
              ),
            if (assumptions?.salaryBasis.annualChf case final salary?)
              Text(
                l.planCard_salaryFallback(chf.format(salary).trim()),
                style: MintTextStyles.micro(color: MintColors.textMuted),
              ),
            if (salarySource != null)
              Semantics(
                identifier: 'financial_plan_setup_salary_source',
                container: true,
                child: Text(
                  l.agentFieldSource(_sourceLabel(l, salarySource)),
                  style: MintTextStyles.micro(color: MintColors.textMuted),
                ),
              ),
            if (salaryFreshnessDays != null)
              Semantics(
                identifier: 'financial_plan_setup_salary_freshness',
                container: true,
                child: Text(
                  l.profileAnnualRefreshDays(salaryFreshnessDays),
                  style: MintTextStyles.micro(color: MintColors.textMuted),
                ),
              ),
            if (assumptions?.bonificationBasis.kind == 'legalAgeSchedule')
              Text(
                l.planCard_bonificationLegal,
                style: MintTextStyles.micro(color: MintColors.textMuted),
              ),
            if (source != null)
              Text(
                l.planSetupLppFactSource(_sourceLabel(l, source)),
                style: MintTextStyles.micro(color: MintColors.textMuted),
              ),
            if (sourcePath != null)
              Text(
                l.planSetupLppFactDate(
                  sourceDate == null
                      ? l.planSetupSourceUnknown
                      : DateFormat.yMd(localeName).format(sourceDate),
                ),
                style: MintTextStyles.micro(color: MintColors.textMuted),
              ),
            Text(
              l.planCard_dataConfidence(
                draft.confidenceLevel.round().toString(),
              ),
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
            Text(
              l.planSetupNominalScope,
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
            if (assumptions?.annualProjectionUsesWholeYears == true)
              Semantics(
                identifier: 'financial_plan_setup_annual_approximation',
                container: true,
                child: Text(
                  l.planSetupAnnualApproximation,
                  style: MintTextStyles.micro(color: MintColors.textMuted),
                ),
              ),
            if (draft.sources.isNotEmpty) ...[
              const SizedBox(height: MintSpacing.xs),
              Text(
                l.askMintSourcesTitle,
                style: MintTextStyles.micro(color: MintColors.textMuted),
              ),
              ...draft.sources.map(
                (source) => Text(
                  source,
                  style: MintTextStyles.micro(color: MintColors.textMuted),
                ),
              ),
            ],
          ],
          if (inputs.branch == FinancialPlanDependencyBranch.retirementLpp &&
              assumptions?.requiresFundAuthorizationBefore63 == true) ...[
            const SizedBox(height: MintSpacing.sm),
            Semantics(
              identifier: 'financial_plan_setup_early_retirement_rule',
              container: true,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _earlyRetirementRuleAcknowledged,
                onChanged: (value) => setState(
                  () => _earlyRetirementRuleAcknowledged = value ?? false,
                ),
                title: Text(l.planSetupEarlyRetirementRuleTitle),
                subtitle: Text(l.planSetupEarlyRetirementRuleBody),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
          ],
          if (inputs.branch == FinancialPlanDependencyBranch.retirementLpp &&
              assumptions?.assumesPostReferenceGainfulActivity == true) ...[
            const SizedBox(height: MintSpacing.sm),
            Semantics(
              identifier: 'financial_plan_setup_post65_gainful_activity',
              container: true,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _postReferenceActivityAcknowledged,
                onChanged: (value) => setState(
                  () => _postReferenceActivityAcknowledged = value ?? false,
                ),
                title: Text(l.planSetupPostReferenceActivityTitle),
                subtitle: Text(l.planSetupPostReferenceActivityBody),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
          ],
          const SizedBox(height: MintSpacing.sm),
          Text(
            l.planCard_disclaimer,
            style: MintTextStyles.micro(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),
          Semantics(
            identifier: 'financial_plan_setup_confirm',
            container: true,
            button: true,
            enabled: canConfirm,
            onTap: canConfirm ? () => _confirm(ledger) : null,
            child: ExcludeSemantics(
              child: FilledButton(
                onPressed: canConfirm ? () => _confirm(ledger) : null,
                child: Text(
                  _isSaving ? l.planSetupSaving : l.planSetupConfirm,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _capitalSourcePath(CoachProfile profile) {
    final pension = profile.prevoyance;
    if (pension.avoirLppTotal != null) return 'prevoyance.avoirLppTotal';
    if (pension.avoirLppObligatoire != null &&
        pension.avoirLppSurobligatoire != null) {
      return 'prevoyance.avoirLppObligatoire';
    }
    return null;
  }

  String _preparationMessage(S l) => switch (_preparationBlocker) {
        FinancialPlanDependencyBlocker.affiliation =>
          l.planSetupBlockerAffiliation,
        FinancialPlanDependencyBlocker.dateOfBirth =>
          l.planSetupBlockerDateOfBirth,
        FinancialPlanDependencyBlocker.gender => l.planSetupBlockerGender,
        FinancialPlanDependencyBlocker.salary => l.planSetupBlockerSalary,
        FinancialPlanDependencyBlocker.lpp => l.planSetupBlockerLpp,
        FinancialPlanDependencyBlocker.legalContract =>
          l.planSetupBlockerLegalContract,
        FinancialPlanDependencyBlocker.ownerAuthority =>
          l.planSetupBlockerOwnerAuthority,
        FinancialPlanDependencyBlocker.unexpected ||
        null =>
          l.planSetupBlockerUnexpected,
      };

  String _sourceLabel(S l, ProfileDataSource source) => switch (source) {
        ProfileDataSource.certificate => l.planSetupSourceCertificate,
        ProfileDataSource.userInput => l.planSetupSourceUserInput,
        ProfileDataSource.crossValidated => l.planSetupSourceCrossValidated,
        ProfileDataSource.openBanking => l.planSetupSourceOpenBanking,
        ProfileDataSource.estimated => l.planSetupSourceEstimated,
      };

  Widget _semanticButton({
    required String identifier,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      identifier: identifier,
      container: true,
      button: true,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onPressed,
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
