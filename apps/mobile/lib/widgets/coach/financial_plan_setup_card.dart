import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/financial_plan.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/financial_core/avs_reference_age.dart';
import 'package:mint_mobile/services/financial_plan_ledger_inputs.dart';
import 'package:mint_mobile/services/plan_generation_service.dart';
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
    this.initialError = false,
    this.clock = DateTime.now,
  });

  final String goalHint;
  final FinancialPlanProvider planProvider;
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
  FinancialPlanLedgerInputs? _draftInputs;
  int? _retirementAge;
  bool _requiresPostReferenceActivity = false;
  bool _hasPreparationError = false;
  bool _draftChanged = false;

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
    );
    _hasError = widget.initialError;
  }

  @override
  void dispose() {
    _goalController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _selectCategory(String category) {
    setState(() {
      _category = category;
      _hasError = false;
      _hasPreparationError = false;
      _draftChanged = false;
      _validationMessage = null;
      _draftPlan = null;
      _draftInputs = null;
      _earlyRetirementRuleAcknowledged = false;
      _postReferenceActivityAcknowledged = false;
      if (category != 'goal_retirement_plan') {
        _prospectiveLppReturn = null;
      }
      _step = category == 'goal_retirement_plan'
          ? _PlanSetupStep.retirementContext
          : _PlanSetupStep.details;
    });
  }

  void _continueFromRetirementContext() {
    final explicitNoLpp = context
            .read<CoachProfileProvider>()
            .profile
            ?.prevoyance
            .hasPensionFund ==
        false;
    if (!_horizonAcknowledged ||
        !_scopeAcknowledged ||
        (!explicitNoLpp && _prospectiveLppReturn == null)) {
      return;
    }
    setState(() => _step = _PlanSetupStep.details);
  }

  Future<void> _review(CoachProfile? profile) async {
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
    final today = DateTime.now();
    if (targetDate == null || !targetDate.isAfter(today)) {
      setState(() => _validationMessage = S.of(context)!.planSetupInvalidDate);
      return;
    }
    final retirementAge = _category == 'goal_retirement_plan' && profile != null
        ? _retirementAgeAt(profile, targetDate)
        : null;
    if (_category == 'goal_retirement_plan' &&
        (retirementAge == null || retirementAge < 58 || retirementAge > 70)) {
      setState(() => _validationMessage = S.of(context)!.planSetupInvalidDate);
      return;
    }
    final explicitNoLpp = profile?.prevoyance.hasPensionFund == false;
    if (_category == 'goal_retirement_plan' &&
        !explicitNoLpp &&
        _prospectiveLppReturn == null) {
      setState(() =>
          _validationMessage = S.of(context)!.planSetupReturnAssumptionBody);
      return;
    }
    if (profile == null || _category == null) {
      setState(() => _hasPreparationError = true);
      return;
    }

    setState(() {
      _confirmedAmount = amount;
      _confirmedTargetDate = targetDate;
      _retirementAge = retirementAge;
      _validationMessage = null;
      _hasError = false;
      _hasPreparationError = false;
      _draftChanged = false;
      _isPreparing = true;
      _draftPlan = null;
      _draftInputs = null;
      _earlyRetirementRuleAcknowledged = false;
      _postReferenceActivityAcknowledged = false;
    });

    try {
      final generatedAt = widget.clock();
      final safeGoal = _safeGoal(_goalController.text);
      _goalController.value = TextEditingValue(
        text: safeGoal,
        selection: TextSelection.collapsed(offset: safeGoal.length),
      );
      final inputs = FinancialPlanLedgerInputs.fromProfile(
        profile,
        now: generatedAt,
      );
      final l = S.of(context)!;
      final draft = await PlanGenerationService.generate(
        goalDescription: safeGoal.isNotEmpty
            ? safeGoal
            : _category == 'goal_retirement_plan'
                ? l.planSetupCategoryRetirement
                : l.planSetupCategoryGeneral,
        goalCategory: _category!,
        targetDate: targetDate,
        profile: profile,
        goalAmount: amount,
        prospectiveLppReturn: _prospectiveLppReturn,
        now: generatedAt,
      );
      final referenceDate = AvsReferenceAge.referenceDate(
        dateOfBirth: profile.dateOfBirth,
        birthYear: profile.birthYear,
        gender: profile.gender,
      );
      if (!mounted) return;
      setState(() {
        _draftPlan = draft;
        _draftInputs = inputs;
        _requiresPostReferenceActivity = _category == 'goal_retirement_plan' &&
            referenceDate != null &&
            targetDate.isAfter(referenceDate);
        _step = _PlanSetupStep.confirmation;
      });
    } catch (error, stackTrace) {
      debugPrint(
        '[financial_plan_setup] draft calculation failed: $error\n$stackTrace',
      );
      if (mounted) {
        setState(() {
          _hasPreparationError = true;
          _draftChanged = false;
          _step = _PlanSetupStep.details;
        });
      }
    } finally {
      if (mounted) setState(() => _isPreparing = false);
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

    final confirmationTime = widget.clock();
    final currentInputs = FinancialPlanLedgerInputs.fromProfile(
      profile,
      now: confirmationTime,
    );
    if (currentInputs.fingerprint != draft.profileHashAtGeneration) {
      setState(() {
        _draftPlan = null;
        _draftInputs = null;
        _hasPreparationError = true;
        _draftChanged = true;
        _step = _PlanSetupStep.details;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _didSubmit = true;
      _hasError = false;
    });

    try {
      widget.planProvider.attachProfileProvider(ledger);
      await widget.planProvider.setPlan(
        draft.copyWith(confirmedAt: confirmationTime),
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[financial_plan_setup] confirmation failed: $error\n$stackTrace',
      );
      if (mounted) {
        setState(() {
          _didSubmit = false;
          _hasError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool get _ageConditionsAcknowledged {
    if (_category != 'goal_retirement_plan') return true;
    if ((_retirementAge ?? 0) < 63 && !_earlyRetirementRuleAcknowledged) {
      return false;
    }
    if (_requiresPostReferenceActivity && !_postReferenceActivityAcknowledged) {
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
                        : l.planSetupMissingRetirementData,
                    style: MintTextStyles.bodyMedium(color: MintColors.error),
                  ),
                ),
                if (!_draftChanged && _category == 'goal_retirement_plan') ...[
                  const SizedBox(height: MintSpacing.xs),
                  Semantics(
                    identifier: 'financial_plan_setup_enrich_lpp',
                    button: true,
                    child: TextButton(
                      onPressed: () => context.push('/data-block/lpp'),
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
    final explicitNoLpp = context
            .read<CoachProfileProvider>()
            .profile
            ?.prevoyance
            .hasPensionFund ==
        false;
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
        if (!explicitNoLpp) ...[
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
        FilledButton(
          onPressed: _horizonAcknowledged &&
                  _scopeAcknowledged &&
                  (explicitNoLpp || _prospectiveLppReturn != null)
              ? _continueFromRetirementContext
              : null,
          child: Text(l.planSetupContinue),
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
    final sourceDate = sourcePath == null
        ? null
        : profile.dataSourceDates[sourcePath] ??
            profile.dataTimestamps[sourcePath];
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
          if (_category == 'goal_retirement_plan') ...[
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
            if (sourceDate != null)
              Text(
                l.planSetupLppFactDate(
                  DateFormat.yMd(localeName).format(sourceDate),
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
          if (_category == 'goal_retirement_plan' &&
              (_retirementAge ?? 0) < 63) ...[
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
          if (_category == 'goal_retirement_plan' &&
              _requiresPostReferenceActivity) ...[
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
