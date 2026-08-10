import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/mint_next_housing_fact.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

enum _HousingStep {
  savedSummary,
  tenureQuestion,
  tenureBoundary,
  mortgageQuestion,
  mortgageBoundary,
  statementQuestion,
  statementBoundary,
  interestQuestion,
  interestBoundary,
  debtQuestion,
  statementReview,
}

class MintNextHousingScreen extends StatefulWidget {
  const MintNextHousingScreen({super.key, this.onExit});

  final VoidCallback? onExit;

  @override
  State<MintNextHousingScreen> createState() => _MintNextHousingScreenState();
}

class _MintNextHousingScreenState extends State<MintNextHousingScreen> {
  final _interestController = TextEditingController();
  final _debtController = TextEditingController();
  final _statementYearController = TextEditingController();
  PrimaryHomeTenure? _selected;
  HousingMortgageStatus? _mortgageStatus;
  MortgageStatementAvailability? _statementAvailability;
  _HousingStep _step = _HousingStep.tenureQuestion;
  int? _annualInterestCents;
  int? _debtBalanceCents;
  int? _statementTaxYear;
  bool _isPersisting = false;
  String? _persistenceError;
  CoachProfileProvider? _profileProvider;
  bool _didRestoreSavedFact = false;

  @override
  void initState() {
    super.initState();
    FeatureFlags.mintNextHousingListenable.addListener(_handleFlagChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<CoachProfileProvider>();
    if (identical(provider, _profileProvider)) return;
    _profileProvider?.removeListener(_handleProfileHydration);
    _profileProvider = provider..addListener(_handleProfileHydration);
    _didRestoreSavedFact = false;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _restoreSavedFactIfPristine());
  }

  @override
  void dispose() {
    FeatureFlags.mintNextHousingListenable.removeListener(_handleFlagChange);
    _profileProvider?.removeListener(_handleProfileHydration);
    _interestController.dispose();
    _debtController.dispose();
    _statementYearController.dispose();
    super.dispose();
  }

  void _handleFlagChange() {
    if (!FeatureFlags.enableMintNextHousing && mounted) _exit();
  }

  void _handleProfileHydration() => _restoreSavedFactIfPristine();

  bool get _isPristineFlow =>
      _step == _HousingStep.tenureQuestion &&
      _selected == null &&
      _mortgageStatus == null &&
      _statementAvailability == null &&
      _statementTaxYear == null &&
      _annualInterestCents == null &&
      _debtBalanceCents == null;

  void _restoreSavedFactIfPristine() {
    if (!mounted || _didRestoreSavedFact || !_isPristineFlow) return;
    final fact = _profileProvider?.housingFact;
    if (fact == null) return;
    _didRestoreSavedFact = true;
    setState(() {
      _selected = fact.tenure;
      _mortgageStatus = fact.mortgageStatus;
      _statementAvailability = fact.statementAvailability;
      _statementTaxYear = fact.statementYear;
      _annualInterestCents = fact.annualInterestCents;
      _debtBalanceCents = fact.debtBalanceCents;
      if (_statementTaxYear != null) {
        _statementYearController.text = _statementTaxYear.toString();
      }
      if (_annualInterestCents != null) {
        _interestController.text = _formatEditableChf(_annualInterestCents!);
      }
      if (_debtBalanceCents != null) {
        _debtController.text = _formatEditableChf(_debtBalanceCents!);
      }
      _step = _HousingStep.savedSummary;
    });
  }

  void _exit() {
    _step = _HousingStep.tenureQuestion;
    _selected = null;
    _mortgageStatus = null;
    _statementAvailability = null;
    _annualInterestCents = null;
    _interestController.clear();
    _debtBalanceCents = null;
    _debtController.clear();
    _statementTaxYear = null;
    _statementYearController.clear();
    _persistenceError = null;
    widget.onExit?.call();
    if (widget.onExit == null) context.go('/home');
  }

  Future<void> _openSafeExit() async {
    final l10n = S.of(context)!;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.housingSafeExit),
        actions: [
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Semantics(
              identifier: 'action:fact_logement.resume',
              button: true,
              child: Text(l10n.housingResume),
            ),
          ),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Semantics(
              identifier: 'action:fact_logement.leave_without_saving',
              button: true,
              child: Text(l10n.housingLeaveWithoutSaving),
            ),
          ),
        ],
      ),
    );
    if (leave == true && mounted) _exit();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final previous = switch (_step) {
          _HousingStep.savedSummary => null,
          _HousingStep.statementReview => _HousingStep.debtQuestion,
          _HousingStep.debtQuestion => _HousingStep.interestBoundary,
          _HousingStep.interestBoundary => _HousingStep.interestQuestion,
          _HousingStep.interestQuestion => _HousingStep.statementBoundary,
          _HousingStep.statementBoundary => _HousingStep.statementQuestion,
          _HousingStep.statementQuestion => _HousingStep.mortgageBoundary,
          _HousingStep.mortgageBoundary => _HousingStep.mortgageQuestion,
          _HousingStep.mortgageQuestion => _HousingStep.tenureBoundary,
          _HousingStep.tenureBoundary => _HousingStep.tenureQuestion,
          _HousingStep.tenureQuestion => null,
        };
        if (previous == null) {
          _openSafeExit();
        } else {
          setState(() => _step = previous);
        }
      },
      child: Scaffold(
        backgroundColor: MintColors.craie,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(MintSpacing.lg),
            child: switch (_step) {
              _HousingStep.savedSummary => _savedSummary(l10n),
              _HousingStep.tenureQuestion => _question(l10n),
              _HousingStep.tenureBoundary => _boundary(l10n),
              _HousingStep.mortgageQuestion => _mortgageQuestion(l10n),
              _HousingStep.mortgageBoundary => _mortgageBoundary(l10n),
              _HousingStep.statementQuestion => _statementQuestion(l10n),
              _HousingStep.statementBoundary => _statementBoundary(l10n),
              _HousingStep.interestQuestion => _interestQuestion(l10n),
              _HousingStep.interestBoundary => _interestBoundary(l10n),
              _HousingStep.debtQuestion => _debtQuestion(l10n),
              _HousingStep.statementReview => _statementReview(l10n),
            },
          ),
        ),
      ),
    );
  }

  Widget _question(S l10n) {
    final labels = <PrimaryHomeTenure, String>{
      PrimaryHomeTenure.tenant: l10n.housingTenant,
      PrimaryHomeTenure.ownerOccupier: l10n.housingOwnerOccupier,
      PrimaryHomeTenure.other: l10n.housingOther,
      PrimaryHomeTenure.unknown: l10n.housingUnknown,
    };
    return Semantics(
      identifier: 'node:fact_logement',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.housingQuestion,
              style:
                  MintTextStyles.headlineLarge(color: MintColors.textPrimary),
            ),
          ),
          const SizedBox(height: MintSpacing.lg),
          ...labels.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.sm),
              child: Semantics(
                identifier: 'choice:fact_logement.${entry.key.id}',
                button: true,
                selected: _selected == entry.key,
                child: InkWell(
                  onTap: () => setState(() {
                    if (_selected != entry.key) {
                      _mortgageStatus = null;
                      _statementAvailability = null;
                      _clearStatementAmounts();
                    }
                    _selected = entry.key;
                  }),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.all(MintSpacing.md),
                    decoration: BoxDecoration(
                      color: _selected == entry.key
                          ? MintColors.success.withValues(alpha: .1)
                          : MintColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: MintColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(entry.value)),
                        if (_selected == entry.key)
                          const Icon(Icons.check_circle,
                              color: MintColors.success),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.md),
          Semantics(
            identifier: 'action:fact_logement.continue',
            button: true,
            child: FilledButton(
              // lint-ignore: prefer_mint_cta
              onPressed: _selected == null
                  ? null
                  : () => setState(() => _step = _HousingStep.tenureBoundary),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(l10n.housingContinue),
            ),
          ),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: _openSafeExit,
            child: Semantics(
              identifier: 'action:fact_logement.safe_exit',
              button: true,
              child: Text(l10n.housingSafeExit),
            ),
          ),
        ],
      ),
    );
  }

  Widget _boundary(S l10n) {
    final selected = _selected!;
    final body = switch (selected) {
      PrimaryHomeTenure.tenant => l10n.housingTenantBoundary,
      PrimaryHomeTenure.ownerOccupier => l10n.housingOwnerBoundary,
      PrimaryHomeTenure.other => l10n.housingOtherHelp,
      PrimaryHomeTenure.unknown => l10n.housingUnknownHelp,
    };
    final node = switch (selected) {
      PrimaryHomeTenure.tenant => 'housing_tenant_boundary',
      PrimaryHomeTenure.ownerOccupier => 'housing_owner_boundary',
      PrimaryHomeTenure.other => 'housing_other_help',
      PrimaryHomeTenure.unknown => 'housing_unknown_help',
    };
    return Semantics(
      identifier: 'node:$node',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(body,
              style:
                  MintTextStyles.headlineSmall(color: MintColors.textPrimary)),
          const SizedBox(height: MintSpacing.xl),
          Semantics(
            identifier: selected == PrimaryHomeTenure.ownerOccupier
                ? 'action:housing_owner_boundary.continue'
                : 'action:$node.finish',
            button: true,
            child: FilledButton(
              // lint-ignore: prefer_mint_cta
              onPressed: selected == PrimaryHomeTenure.ownerOccupier
                  ? () => setState(() => _step = _HousingStep.mortgageQuestion)
                  : _saveAndExit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(selected == PrimaryHomeTenure.ownerOccupier
                  ? l10n.housingContinue
                  : l10n.housingSave),
            ),
          ),
          if (selected != PrimaryHomeTenure.ownerOccupier)
            _persistenceFailureMessage(),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () =>
                setState(() => _step = _HousingStep.tenureQuestion),
            child: Text(l10n.housingBack),
          ),
          TextButton(
              // lint-ignore: prefer_mint_cta
              onPressed: _openSafeExit,
              child: Text(l10n.housingSafeExit)),
        ],
      ),
    );
  }

  Widget _mortgageQuestion(S l10n) {
    final labels = <HousingMortgageStatus, String>{
      HousingMortgageStatus.yes: l10n.housingMortgageYes,
      HousingMortgageStatus.no: l10n.housingMortgageNo,
      HousingMortgageStatus.unknown: l10n.housingMortgageUnknown,
    };
    return Semantics(
      identifier: 'node:fact_housing_mortgage',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.housingMortgageQuestion,
              style:
                  MintTextStyles.headlineLarge(color: MintColors.textPrimary),
            ),
          ),
          const SizedBox(height: MintSpacing.lg),
          ...labels.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.sm),
              child: Semantics(
                identifier: 'choice:fact_housing_mortgage.${entry.key.id}',
                button: true,
                selected: _mortgageStatus == entry.key,
                child: InkWell(
                  onTap: () => setState(() {
                    if (_mortgageStatus != entry.key) {
                      _statementAvailability = null;
                      _clearStatementAmounts();
                    }
                    _mortgageStatus = entry.key;
                  }),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.all(MintSpacing.md),
                    decoration: BoxDecoration(
                      color: _mortgageStatus == entry.key
                          ? MintColors.success.withValues(alpha: .1)
                          : MintColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: MintColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(entry.value)),
                        if (_mortgageStatus == entry.key)
                          const Icon(Icons.check_circle,
                              color: MintColors.success),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.md),
          Semantics(
            identifier: 'action:fact_housing_mortgage.continue',
            button: true,
            child: FilledButton(
              // lint-ignore: prefer_mint_cta
              onPressed: _mortgageStatus == null
                  ? null
                  : () => setState(() => _step = _HousingStep.mortgageBoundary),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(l10n.housingContinue),
            ),
          ),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () =>
                setState(() => _step = _HousingStep.tenureBoundary),
            child: Text(l10n.housingBack),
          ),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: _openSafeExit,
            child: Text(l10n.housingSafeExit),
          ),
        ],
      ),
    );
  }

  Widget _mortgageBoundary(S l10n) {
    final status = _mortgageStatus!;
    final body = switch (status) {
      HousingMortgageStatus.yes => l10n.housingMortgageYesBoundary,
      HousingMortgageStatus.no => l10n.housingMortgageNoBoundary,
      HousingMortgageStatus.unknown => l10n.housingMortgageUnknownBoundary,
    };
    final node = 'housing_mortgage_${status.id}_boundary';
    return Semantics(
      identifier: 'node:$node',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            body,
            style: MintTextStyles.headlineSmall(color: MintColors.textPrimary),
          ),
          const SizedBox(height: MintSpacing.xl),
          Semantics(
            identifier: status == HousingMortgageStatus.yes
                ? 'action:housing_mortgage_yes_boundary.continue'
                : 'action:$node.finish',
            button: true,
            child: FilledButton(
              // lint-ignore: prefer_mint_cta
              onPressed: status == HousingMortgageStatus.yes
                  ? () => setState(() => _step = _HousingStep.statementQuestion)
                  : _saveAndExit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(status == HousingMortgageStatus.yes
                  ? l10n.housingContinue
                  : l10n.housingSave),
            ),
          ),
          if (status != HousingMortgageStatus.yes)
            _persistenceFailureMessage(),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () =>
                setState(() => _step = _HousingStep.mortgageQuestion),
            child: Text(l10n.housingBack),
          ),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: _openSafeExit,
            child: Text(l10n.housingSafeExit),
          ),
        ],
      ),
    );
  }

  Widget _statementQuestion(S l10n) {
    final labels = <MortgageStatementAvailability, String>{
      MortgageStatementAvailability.ready: l10n.mortgageStatementReady,
      MortgageStatementAvailability.findLater: l10n.mortgageStatementFindLater,
      MortgageStatementAvailability.unknown: l10n.mortgageStatementUnknown,
    };
    return Semantics(
      identifier: 'node:fact_mortgage_statement',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.mortgageStatementQuestion,
              style: MintTextStyles.headlineLarge(color: MintColors.textPrimary),
            ),
          ),
          const SizedBox(height: MintSpacing.lg),
          ...labels.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.sm),
              child: Semantics(
                identifier: 'choice:fact_mortgage_statement.${entry.key.id}',
                button: true,
                selected: _statementAvailability == entry.key,
                child: InkWell(
                  onTap: () => setState(() {
                    if (_statementAvailability != entry.key) {
                      _clearStatementAmounts();
                    }
                    _statementAvailability = entry.key;
                  }),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.all(MintSpacing.md),
                    decoration: BoxDecoration(
                      color: _statementAvailability == entry.key
                          ? MintColors.success.withValues(alpha: .1)
                          : MintColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: MintColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(entry.value)),
                        if (_statementAvailability == entry.key)
                          const Icon(Icons.check_circle,
                              color: MintColors.success),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.md),
          Semantics(
            identifier: 'action:fact_mortgage_statement.continue',
            button: true,
            child: FilledButton(
              // lint-ignore: prefer_mint_cta
              onPressed: _statementAvailability == null
                  ? null
                  : () =>
                      setState(() => _step = _HousingStep.statementBoundary),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(l10n.housingContinue),
            ),
          ),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () =>
                setState(() => _step = _HousingStep.mortgageBoundary),
            child: Text(l10n.housingBack),
          ),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: _openSafeExit,
            child: Text(l10n.housingSafeExit),
          ),
        ],
      ),
    );
  }

  Widget _statementBoundary(S l10n) {
    final availability = _statementAvailability!;
    final body = switch (availability) {
      MortgageStatementAvailability.ready =>
        l10n.mortgageStatementReadyBoundary,
      MortgageStatementAvailability.findLater =>
        l10n.mortgageStatementFindLaterBoundary,
      MortgageStatementAvailability.unknown =>
        l10n.mortgageStatementUnknownBoundary,
    };
    final node = 'mortgage_statement_${availability.id}_boundary';
    return Semantics(
      identifier: 'node:$node',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(body,
              style:
                  MintTextStyles.headlineSmall(color: MintColors.textPrimary)),
          const SizedBox(height: MintSpacing.xl),
          Semantics(
            identifier: availability == MortgageStatementAvailability.ready
                ? 'action:mortgage_statement_ready_boundary.continue'
                : 'action:$node.finish',
            button: true,
            child: FilledButton(
              // lint-ignore: prefer_mint_cta
              onPressed: availability == MortgageStatementAvailability.ready
                  ? () => setState(() => _step = _HousingStep.interestQuestion)
                  : _saveAndExit,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: Text(
                availability == MortgageStatementAvailability.ready
                    ? l10n.housingContinue
                    : l10n.housingSave,
              ),
            ),
          ),
          if (availability != MortgageStatementAvailability.ready)
            _persistenceFailureMessage(),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () =>
                setState(() => _step = _HousingStep.statementQuestion),
            child: Text(l10n.housingBack),
          ),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: _openSafeExit,
            child: Text(l10n.housingSafeExit),
          ),
        ],
      ),
    );
  }

  void _clearStatementAmounts() {
    _clearFinancialAmounts();
    _statementTaxYear = null;
    _statementYearController.clear();
  }

  void _clearFinancialAmounts() {
    _annualInterestCents = null;
    _interestController.clear();
    _debtBalanceCents = null;
    _debtController.clear();
  }

  void _updateInterest(String raw) {
    setState(() => _annualInterestCents = _parseChfCents(raw));
  }

  void _updateDebt(String raw) {
    setState(() => _debtBalanceCents = _parseChfCents(raw));
  }

  void _updateStatementYear(String raw) {
    final year = int.tryParse(raw);
    final currentYear = DateTime.now().year;
    final nextYear =
        year != null && year >= 2000 && year <= currentYear ? year : null;
    setState(() {
      if (_statementTaxYear != null && nextYear != _statementTaxYear) {
        _clearFinancialAmounts();
      }
      _statementTaxYear = nextYear;
    });
  }

  int? _parseChfCents(String raw) {
    final compact = raw.replaceAll(RegExp(r"['’ ]"), '');
    final match = RegExp(r'^(\d+)(?:[.,](\d{1,2}))?$').firstMatch(compact);
    if (match == null) return null;
    final francs = int.tryParse(match.group(1)!);
    final decimals = match.group(2);
    if (francs == null) return null;
    final cents = decimals == null
        ? 0
        : int.parse(decimals.length == 1 ? '${decimals}0' : decimals);
    return francs * 100 + cents;
  }

  String _formatChf(int cents) {
    final digits = (cents ~/ 100).toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('’');
      buffer.write(digits[index]);
    }
    final remainder = cents % 100;
    return remainder == 0
        ? buffer.toString()
        : '$buffer.${remainder.toString().padLeft(2, '0')}';
  }

  String _formatEditableChf(int cents) {
    final whole = cents ~/ 100;
    final decimals = cents % 100;
    return decimals == 0
        ? whole.toString()
        : '$whole.${decimals.toString().padLeft(2, '0')}';
  }

  Future<void> _saveAndExit() async {
    if (_selected == null || _isPersisting) return;
    setState(() {
      _isPersisting = true;
      _persistenceError = null;
    });
    try {
      await context.read<CoachProfileProvider>().saveHousingFact(
            MintNextHousingFact(
              tenure: _selected!,
              mortgageStatus: _mortgageStatus,
              statementAvailability: _statementAvailability,
              statementYear: _statementTaxYear,
              annualInterestCents: _annualInterestCents,
              debtBalanceCents: _debtBalanceCents,
              assertedAt: DateTime.now().toUtc(),
              source: MintNextHousingFact.userDeclarationSource,
              schemaVersion: 1,
              needsConfirmation: false,
            ),
          );
      if (mounted) _exit();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isPersisting = false;
          _persistenceError = S.of(context)!.housingSaveError;
        });
      }
    }
  }

  Widget _persistenceFailureMessage() {
    if (_persistenceError == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: MintSpacing.sm),
      child: Text(
        _persistenceError!,
        style: MintTextStyles.bodySmall(color: MintColors.error),
      ),
    );
  }

  Widget _interestQuestion(S l10n) {
    return Semantics(
      identifier: 'node:fact_mortgage_interest_paid',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.mortgageInterestQuestion,
              style:
                  MintTextStyles.headlineLarge(color: MintColors.textPrimary),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            l10n.mortgageInterestHint,
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.lg),
          Semantics(
            identifier: 'input:fact_mortgage_statement_year',
            textField: true,
            child: TextField(
              controller: _statementYearController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              onChanged: _updateStatementYear,
              decoration: InputDecoration(
                labelText: l10n.mortgageStatementYearLabel,
                hintText: l10n.mortgageStatementYearHint,
                filled: true,
                fillColor: MintColors.white,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.md),
          Semantics(
            identifier: 'input:fact_mortgage_interest_paid',
            textField: true,
            child: TextField(
              controller: _interestController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[0-9'’ .,]")),
              ],
              onChanged: _updateInterest,
              decoration: InputDecoration(
                prefixText: 'CHF ',
                labelText: l10n.mortgageInterestLabel,
                filled: true,
                fillColor: MintColors.white,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.lg),
          Semantics(
            identifier: 'action:fact_mortgage_interest_paid.continue',
            button: true,
            child: FilledButton(
              // lint-ignore: prefer_mint_cta
              onPressed: _statementTaxYear == null ||
                      _annualInterestCents == null
                  ? null
                  : () => setState(() => _step = _HousingStep.interestBoundary),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: Text(l10n.housingContinue),
            ),
          ),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () =>
                setState(() => _step = _HousingStep.statementBoundary),
            child: Text(l10n.housingBack),
          ),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: _openSafeExit,
            child: Text(l10n.housingSafeExit),
          ),
        ],
      ),
    );
  }

  Widget _interestBoundary(S l10n) {
    return Semantics(
      identifier: 'node:mortgage_interest_paid_boundary',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.mortgageInterestBoundary(
              _formatChf(_annualInterestCents!),
              _statementTaxYear!,
            ),
            style: MintTextStyles.headlineSmall(color: MintColors.textPrimary),
          ),
          const SizedBox(height: MintSpacing.xl),
          Semantics(
            identifier: 'action:mortgage_interest_paid_boundary.continue',
            button: true,
            child: FilledButton(
              // lint-ignore: prefer_mint_cta
              onPressed: () =>
                  setState(() => _step = _HousingStep.debtQuestion),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: Text(l10n.housingContinue),
            ),
          ),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () =>
                setState(() => _step = _HousingStep.interestQuestion),
            child: Text(l10n.housingBack),
          ),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: _openSafeExit,
            child: Text(l10n.housingSafeExit),
          ),
        ],
      ),
    );
  }

  Widget _debtQuestion(S l10n) {
    return Semantics(
      identifier: 'node:fact_mortgage_debt_balance',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.mortgageDebtQuestion(_statementTaxYear!),
              style:
                  MintTextStyles.headlineLarge(color: MintColors.textPrimary),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            l10n.mortgageDebtHint,
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.lg),
          Semantics(
            identifier: 'input:fact_mortgage_debt_balance',
            textField: true,
            child: TextField(
              controller: _debtController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[0-9'’ .,]")),
              ],
              onChanged: _updateDebt,
              decoration: InputDecoration(
                prefixText: 'CHF ',
                labelText: l10n.mortgageDebtLabel,
                filled: true,
                fillColor: MintColors.white,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.lg),
          Semantics(
            identifier: 'action:fact_mortgage_debt_balance.continue',
            button: true,
            child: FilledButton(
              // lint-ignore: prefer_mint_cta
              onPressed: _debtBalanceCents == null
                  ? null
                  : () => setState(() => _step = _HousingStep.statementReview),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: Text(l10n.housingContinue),
            ),
          ),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () =>
                setState(() => _step = _HousingStep.interestBoundary),
            child: Text(l10n.housingBack),
          ),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: _openSafeExit,
            child: Text(l10n.housingSafeExit),
          ),
        ],
      ),
    );
  }

  Widget _statementReview(S l10n) {
    return Semantics(
      identifier: 'node:mortgage_statement_review',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.mortgageReviewTitle(_statementTaxYear!),
              style:
                  MintTextStyles.headlineLarge(color: MintColors.textPrimary),
            ),
          ),
          const SizedBox(height: MintSpacing.lg),
          Text(
            l10n.mortgageReviewInterest(_formatChf(_annualInterestCents!)),
            style: MintTextStyles.bodyLarge(color: MintColors.textPrimary),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            l10n.mortgageReviewDebt(_formatChf(_debtBalanceCents!)),
            style: MintTextStyles.bodyLarge(color: MintColors.textPrimary),
          ),
          const SizedBox(height: MintSpacing.md),
          Text(
            l10n.mortgageReviewBoundary,
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.xl),
          Semantics(
            identifier: 'action:mortgage_statement_review.save',
            button: true,
            child: FilledButton(
              // lint-ignore: prefer_mint_cta -- Phase 4 migration is out of scope.
              key: const ValueKey('housing_save_button'),
              onPressed: _isPersisting ? null : _saveAndExit,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: Text(l10n.housingSave),
            ),
          ),
          if (_persistenceError != null) ...[
            const SizedBox(height: MintSpacing.sm),
            Text(
              _persistenceError!,
              style: MintTextStyles.bodySmall(color: MintColors.error),
            ),
          ],
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () => setState(() => _step = _HousingStep.debtQuestion),
            child: Text(l10n.housingBack),
          ),
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: _openSafeExit,
            child: Text(l10n.housingSafeExit),
          ),
        ],
      ),
    );
  }

  Widget _savedSummary(S l10n) {
    return Semantics(
      identifier: 'node:housing_saved_summary',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.housingSavedTitle,
              style:
                  MintTextStyles.headlineLarge(color: MintColors.textPrimary),
            ),
          ),
          const SizedBox(height: MintSpacing.md),
          Text(
            l10n.housingSavedBody,
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
          ),
          if (_statementTaxYear != null) ...[
            const SizedBox(height: MintSpacing.lg),
            Text(
              l10n.mortgageReviewTitle(_statementTaxYear!),
              style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
            ),
          ],
          if (_annualInterestCents != null)
            Text(l10n.mortgageReviewInterest(_formatChf(_annualInterestCents!))),
          if (_debtBalanceCents != null)
            Text(l10n.mortgageReviewDebt(_formatChf(_debtBalanceCents!))),
          const SizedBox(height: MintSpacing.xl),
          Semantics(
            identifier: 'action:housing_saved.edit',
            button: true,
            child: FilledButton(
              // lint-ignore: prefer_mint_cta
              onPressed: () => setState(() => _step = _HousingStep.tenureQuestion),
              child: Text(l10n.housingSavedEdit),
            ),
          ),
          Semantics(
            identifier: 'action:housing_saved.delete',
            button: true,
            child: TextButton(
              // lint-ignore: prefer_mint_cta
              onPressed: _confirmDelete,
              child: Text(l10n.housingSavedDelete),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final l10n = S.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.housingSavedDeleteTitle),
        content: Text(l10n.housingSavedDeleteBody),
        actions: [
          TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.housingSavedDeleteCancel),
          ),
          Semantics(
            identifier: 'action:housing_saved.delete_confirm',
            button: true,
            child: TextButton(
              // lint-ignore: prefer_mint_cta
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.housingSavedDeleteConfirm),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<CoachProfileProvider>().deleteHousingFact();
    if (!mounted) return;
    setState(() {
      _selected = null;
      _mortgageStatus = null;
      _statementAvailability = null;
      _clearStatementAmounts();
      _step = _HousingStep.tenureQuestion;
    });
  }
}
