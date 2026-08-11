import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/mint_next_3a_tax_boundary.dart';
import 'package:mint_mobile/models/mint_next_civil_status_fact.dart';
import 'package:mint_mobile/models/mint_next_domicile_fact.dart';
import 'package:mint_mobile/models/mint_next_lpp_affiliation_fact.dart';
import 'package:mint_mobile/models/mint_next_revenu_fact.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/mint_next_3a_task_store.dart';
import 'package:mint_mobile/services/mint_next_3a_tax_delta_engine.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class MintNext3aHandoffScreen extends StatefulWidget {
  const MintNext3aHandoffScreen({
    super.key,
    this.store = const MintNext3aTaskStore(),
    this.taxEngine = const NoAttestedEngine(),
    this.now,
    this.domicileReader = readCanonicalDomicileFact,
    this.civilStatusReader = readCanonicalCivilStatusFact,
    this.revenuReader = readCanonicalRevenuFact,
    this.lppAffiliationReader = readCanonicalLppAffiliationFact,
  });

  final MintNext3aTaskStore store;
  final Pillar3aTaxDeltaEngine taxEngine;
  final DateTime Function()? now;

  /// Reads the confirmed fiscal-domicile fact from the canonical answers.
  /// Injected in tests; the default goes through the single canonical path.
  final Future<MintNextDomicileFact?> Function() domicileReader;

  static Future<MintNextDomicileFact?> readCanonicalDomicileFact() async =>
      MintNextDomicileFact.fromWizardAnswers(
          await ReportPersistenceService.loadAnswers());

  /// Reads the confirmed civil-status fact from the canonical answers.
  final Future<MintNextCivilStatusFact?> Function() civilStatusReader;

  static Future<MintNextCivilStatusFact?> readCanonicalCivilStatusFact() async =>
      MintNextCivilStatusFact.fromWizardAnswers(
          await ReportPersistenceService.loadAnswers());

  /// Reads the confirmed revenu fact from the canonical answers.
  final Future<MintNextRevenuFact?> Function() revenuReader;

  static Future<MintNextRevenuFact?> readCanonicalRevenuFact() async =>
      MintNextRevenuFact.fromWizardAnswers(
          await ReportPersistenceService.loadAnswers());

  /// Reads the confirmed LPP affiliation fact from the canonical answers.
  final Future<MintNextLppAffiliationFact?> Function() lppAffiliationReader;

  static Future<MintNextLppAffiliationFact?>
      readCanonicalLppAffiliationFact() async =>
          MintNextLppAffiliationFact.fromWizardAnswers(
              await ReportPersistenceService.loadAnswers());

  @override
  State<MintNext3aHandoffScreen> createState() =>
      _MintNext3aHandoffScreenState();
}

enum _Step {
  loading,
  teachBack,
  taskPreview,
  saved,
  taskDetail,
  storageFailure
}

enum _Choice { annualTotal, latestPayment, payMax }

enum _StorageFailureKind { read, delete, verifyRead, cleanupDelete }

class _MintNext3aHandoffScreenState extends State<MintNext3aHandoffScreen> {
  _Step _step = _Step.loading;
  _Choice? _choice;
  bool _checked = false;
  bool _correct = false;
  bool _saving = false;
  bool _storageFailed = false;
  bool _deleteOnly = false;
  bool _leaveWithoutSavingRequested = false;
  bool _cleanupPending = false;
  MintNext3aTask? _task;
  MintNext3aFiscalContext? _fiscalContext;
  _StorageFailureKind _storageFailureKind = _StorageFailureKind.read;
  int _resolveGeneration = 0;
  final FocusNode _safeExitFocusNode = FocusNode();
  final FocusNode _deleteFocusNode = FocusNode();

  DateTime _now() => (widget.now?.call() ?? DateTime.now()).toUtc();

  @override
  void initState() {
    super.initState();
    FeatureFlags.mintNext3aProductHandoffListenable.addListener(_reload);
    unawaited(_resolve());
  }

  @override
  void dispose() {
    FeatureFlags.mintNext3aProductHandoffListenable.removeListener(_reload);
    _safeExitFocusNode.dispose();
    _deleteFocusNode.dispose();
    super.dispose();
  }

  void _reload() {
    if (_saving) return;
    unawaited(_resolve());
  }

  Future<void> _resolve() async {
    final generation = ++_resolveGeneration;
    if (mounted) setState(() => _step = _Step.loading);
    final now = _now();
    final MintNext3aTask? task;
    try {
      task = await widget.store.read(at: now);
    } on MintNext3aTaskStorageException {
      if (!mounted || generation != _resolveGeneration) return;
      setState(() {
        _storageFailureKind = _StorageFailureKind.read;
        _step = _Step.storageFailure;
      });
      return;
    }
    final Pillar3aTaxDeltaResult taxResult;
    final MintNextDomicileFact? domicile;
    final MintNextCivilStatusFact? civilStatus;
    final MintNextRevenuFact? revenu;
    final MintNextLppAffiliationFact? lppAffiliation;
    try {
      domicile = await widget.domicileReader();
      civilStatus = await widget.civilStatusReader();
      revenu = await widget.revenuReader();
      lppAffiliation = await widget.lppAffiliationReader();
    } on Object {
      if (mounted && generation == _resolveGeneration) context.go('/home');
      return;
    }
    if (!mounted || generation != _resolveGeneration) return;
    final fiscalContext = MintNext3aFiscalContext(
      taxYear: now.year,
      effectiveAt: now,
      domicile: MintNext3aDomicileContext.fromConfirmedFact(domicile),
      civilStatus: MintNext3aCivilStatusContext.fromConfirmedFact(civilStatus),
      revenu: MintNext3aRevenuContext.fromConfirmedFact(revenu),
      lppAffiliation:
          MintNext3aLppAffiliationContext.fromConfirmedFact(lppAffiliation),
    );
    try {
      taxResult = await widget.taxEngine.calculate(
        Pillar3aTaxDeltaRequest(
          context: fiscalContext,
        ),
      );
    } on Object {
      if (mounted && generation == _resolveGeneration) context.go('/home');
      return;
    }
    if (!mounted || generation != _resolveGeneration) return;
    if (taxResult is! Pillar3aTaxDeltaUnavailable) {
      context.go('/home');
      return;
    }
    _fiscalContext = fiscalContext;
    if (task != null) {
      setState(() {
        _task = task;
        _deleteOnly = !FeatureFlags.enableMintNext3aProductHandoff;
        _step = _Step.taskDetail;
      });
      return;
    }
    if (!FeatureFlags.enableMintNext3aProductHandoff) {
      context.go('/home');
      return;
    }
    setState(() {
      _deleteOnly = false;
      _step = _Step.teachBack;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!FeatureFlags.enableMintNext3aProductHandoff) {
      context.go('/home');
      return;
    }
    setState(() {
      _saving = true;
      _storageFailed = false;
    });
    final operationTime = _fiscalContext?.effectiveAt;
    if (operationTime == null) {
      if (mounted) context.go('/home');
      return;
    }
    final MintNext3aTask writtenTask;
    try {
      writtenTask = await widget.store.save(
        taxYear: operationTime.year,
        at: operationTime,
      );
    } on MintNext3aTaskStorageException catch (error) {
      if (_leaveWithoutSavingRequested ||
          !FeatureFlags.enableMintNext3aProductHandoff) {
        await _cleanupAfterInterruptedSave();
        return;
      }
      if (!mounted) return;
      if (error.operation == 'write') {
        setState(() {
          _saving = false;
          _storageFailed = true;
        });
      } else if (error.operation == 'write_cleanup') {
        _deleteOnly = true;
        _showStorageFailure(_StorageFailureKind.cleanupDelete);
      } else {
        _showStorageFailure(_StorageFailureKind.read);
      }
      return;
    }

    if (_leaveWithoutSavingRequested ||
        !FeatureFlags.enableMintNext3aProductHandoff) {
      await _cleanupAfterInterruptedSave(task: writtenTask);
      return;
    }

    final MintNext3aTask? task;
    try {
      task = await widget.store.read(at: operationTime);
    } on MintNext3aTaskStorageException {
      if (_leaveWithoutSavingRequested ||
          !FeatureFlags.enableMintNext3aProductHandoff) {
        await _cleanupAfterInterruptedSave(task: writtenTask);
        return;
      }
      if (mounted) _showStorageFailure(_StorageFailureKind.verifyRead);
      return;
    }
    if (_leaveWithoutSavingRequested ||
        !FeatureFlags.enableMintNext3aProductHandoff) {
      await _cleanupAfterInterruptedSave(task: task);
      return;
    }
    if (!mounted) return;
    if (task == null) {
      _showStorageFailure(_StorageFailureKind.verifyRead);
      return;
    }
    setState(() {
      _task = task;
      _saving = false;
      _step = _Step.saved;
    });
  }

  Future<void> _cleanupAfterInterruptedSave({MintNext3aTask? task}) async {
    try {
      await widget.store.delete();
    } on MintNext3aTaskStorageException {
      if (mounted) {
        _task = task;
        _deleteOnly = true;
        _showStorageFailure(_StorageFailureKind.cleanupDelete);
      }
      return;
    }
    if (mounted) context.go('/home');
  }

  void _requestLeaveWithoutSaving() {
    _leaveWithoutSavingRequested = true;
    if (_saving) {
      if (mounted) setState(() => _cleanupPending = true);
    } else {
      context.go('/home');
    }
  }

  Future<void> _handleSystemBack() async {
    if (_cleanupPending) return;
    if (_step == _Step.loading) {
      context.go('/home');
      return;
    }
    if (_deleteOnly || _step == _Step.saved) {
      context.go('/home');
      return;
    }
    await _openSafeExit();
  }

  void _showStorageFailure(_StorageFailureKind kind) => setState(() {
        _saving = false;
        _storageFailed = false;
        _storageFailureKind = kind;
        _step = _Step.storageFailure;
      });

  Future<void> _delete() async {
    try {
      await widget.store.delete();
    } on MintNext3aTaskStorageException {
      if (mounted) {
        setState(() {
          _storageFailureKind = _StorageFailureKind.delete;
          _step = _Step.storageFailure;
        });
      }
      return;
    }
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleSystemBack());
      },
      child: Scaffold(
        backgroundColor: MintColors.warmWhite,
        appBar: AppBar(
          backgroundColor: MintColors.warmWhite,
          surfaceTintColor: MintColors.transparent,
          title: Text(l10n.mintNext3aTaskTitle),
          leading: _step == _Step.loading
              ? null
              : IconButton(
                  onPressed: _cleanupPending
                      ? null
                      : (_deleteOnly || _step == _Step.saved)
                          ? () => context.go('/home')
                          : _openSafeExit,
                  icon: const Icon(Icons.close),
                  tooltip: l10n.mintNext3aSafeExitTitle,
                ),
        ),
        body: SafeArea(
          child: _step == _Step.loading
              ? Center(
                  child: Semantics(
                    identifier: 'status:3a.loading',
                    liveRegion: true,
                    label: l10n.loadingGeneric,
                    child: ExcludeSemantics(
                      child: disableAnimations
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.hourglass_empty),
                                const SizedBox(height: MintSpacing.sm),
                                Text(l10n.loadingGeneric),
                              ],
                            )
                          : const CircularProgressIndicator(),
                    ),
                  ),
                )
              : Semantics(
                  container: true,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      MintSpacing.md,
                      MintSpacing.sm,
                      MintSpacing.md,
                      MintSpacing.xl,
                    ),
                    children: [_buildStep(l10n, disableAnimations)],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildStep(S l10n, bool disableAnimations) => switch (_step) {
        _Step.teachBack => _teachBack(l10n, disableAnimations),
        _Step.taskPreview => _taskPreview(l10n),
        _Step.saved => _saved(l10n),
        _Step.taskDetail => _taskDetail(l10n),
        _Step.storageFailure => _storageFailure(l10n),
        _Step.loading => const SizedBox.shrink(),
      };

  Widget _storageFailure(S l10n) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            identifier: 'status:3a.task.storage_failed',
            liveRegion: true,
            child: Text(
              l10n.mintNext3aStorageFailure(_storageFailureKind.name),
              style: MintTextStyles.bodyMedium(color: MintColors.error),
            ),
          ),
          const SizedBox(height: MintSpacing.lg),
          _button(
            'action:3a.task.storage_retry',
            l10n.commonRetry,
            _storageFailureKind == _StorageFailureKind.delete ||
                    _storageFailureKind == _StorageFailureKind.cleanupDelete
                ? _delete
                : _resolve,
          ),
          if (!FeatureFlags.enableMintNext3aProductHandoff &&
              (_storageFailureKind == _StorageFailureKind.read ||
                  _storageFailureKind == _StorageFailureKind.verifyRead)) ...[
            const SizedBox(height: MintSpacing.sm),
            _button(
              'action:3a.task.delete_unverified',
              l10n.mintNext3aDelete,
              () => _confirmDelete(l10n),
              destructive: true,
              focusNode: _deleteFocusNode,
            ),
          ],
          _textButton('action:3a.task.return_today', l10n.mintNext3aReturnToday,
              () => context.go('/home')),
        ],
      );

  Widget _teachBack(S l10n, bool disableAnimations) => Semantics(
        identifier: 'node:3a.teach_back',
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.mintNext3aTeachBackQuestion,
                  style: MintTextStyles.headlineSmall(
                      color: MintColors.textPrimary)),
            ),
            const SizedBox(height: MintSpacing.md),
            Semantics(
              identifier: 'status:tax.personal_unavailable',
              child: Text(l10n.mintNext3aPersonalUnavailable,
                  style: MintTextStyles.bodyMedium(
                      color: MintColors.textSecondary)),
            ),
            const SizedBox(height: MintSpacing.lg),
            _choiceTile('choice:3a.teach_back.annual_total_all_accounts',
                l10n.mintNext3aTeachBackChoiceAnnualTotal, _Choice.annualTotal),
            _choiceTile(
                'choice:3a.teach_back.latest_payment_only',
                l10n.mintNext3aTeachBackChoiceLatestPayment,
                _Choice.latestPayment),
            _choiceTile('choice:3a.teach_back.pay_max_without_checking',
                l10n.mintNext3aTeachBackChoicePayMax, _Choice.payMax),
            const SizedBox(height: MintSpacing.sm),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              expansionAnimationStyle:
                  disableAnimations ? AnimationStyle.noAnimation : null,
              title: Text(l10n.mintNext3aCountingHelpTitle),
              children: [
                Text(l10n.mintNext3aCountingHelpBody),
                const SizedBox(height: MintSpacing.sm),
                Text(l10n.mintNext3aCountingHelpUncertain),
              ],
            ),
            if (_checked) ...[
              const SizedBox(height: MintSpacing.md),
              Semantics(
                identifier: _correct
                    ? 'feedback:3a.teach_back.correct'
                    : 'feedback:3a.teach_back.retry',
                liveRegion: true,
                child: Text(
                  _correct
                      ? l10n.mintNext3aTeachBackFeedbackCorrect
                      : l10n.mintNext3aTeachBackFeedbackRetry,
                  style: MintTextStyles.bodyMedium(
                    color: _correct ? MintColors.success : MintColors.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: MintSpacing.lg),
            if (!_checked)
              _button(
                'action:3a.teach_back.check',
                l10n.capCoverageCheckCtaLabel,
                _choice == null ? null : _check,
              )
            else if (!_correct)
              _button('action:3a.teach_back.retry', l10n.commonRetry, _retry)
            else
              _button(
                  'action:3a.teach_back.continue',
                  l10n.milestoneContinueBtn,
                  () => setState(() => _step = _Step.taskPreview)),
            const SizedBox(height: MintSpacing.sm),
            _textButton('action:3a.safe_exit.open',
                l10n.mintNext3aSafeExitTitle, _openSafeExit,
                focusNode: _safeExitFocusNode),
          ],
        ),
      );

  Widget _taskPreview(S l10n) => Semantics(
        identifier: 'node:3a.task_preview',
        container: true,
        child: _taskContent(
          l10n,
          taxYear: _fiscalContext!.taxYear,
          actions: [
            Semantics(
              identifier: 'disclosure:3a.task.local_only',
              child: Text(l10n.mintNext3aStorageDisclosure),
            ),
            const SizedBox(height: MintSpacing.sm),
            Semantics(
              identifier: _fiscalContext?.domicileKnown == true
                  ? 'fact:3a.domicile.known'
                  : 'fact:3a.domicile.missing',
              child: Text(
                _fiscalContext?.domicile != null
                    ? l10n.mintNext3aDomicileKnown(
                        _fiscalContext!.domicile!.communeName,
                        _fiscalContext!.domicile!.canton)
                    : l10n.mintNext3aDomicileMissing,
                style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
              ),
            ),
            const SizedBox(height: MintSpacing.md),
            if (_cleanupPending)
              Semantics(
                identifier: 'status:3a.task.cleanup_pending',
                liveRegion: true,
                child: Text(l10n.mintNext3aCleanupPending),
              )
            else if (_storageFailed) ...[
              Semantics(
                identifier: 'status:3a.task.storage_failed',
                liveRegion: true,
                child: Text(l10n.mintNext3aStorageFailure('write'),
                    style: const TextStyle(color: MintColors.error)),
              ),
              _button('action:3a.task.storage_retry', l10n.mintNext3aSave,
                  _saving ? null : _save),
            ] else
              _button('action:3a.task.save', l10n.mintNext3aSave,
                  _saving ? null : _save),
            if (!_cleanupPending)
              _textButton(
                  'action:3a.task.leave_without_saving',
                  l10n.mintNext3aLeaveWithoutSaving,
                  _requestLeaveWithoutSaving),
          ],
        ),
      );

  Widget _saved(S l10n) => Semantics(
        identifier: 'node:3a.task_saved',
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.mintNext3aSavedTitle,
                  style: MintTextStyles.headlineSmall(
                      color: MintColors.textPrimary)),
            ),
            const SizedBox(height: MintSpacing.md),
            Text(l10n.mintNext3aSavedLocation),
            const SizedBox(height: MintSpacing.sm),
            Text(l10n.mintNext3aExpiryDisclosure(_task!.expiresAt.year)),
            const SizedBox(height: MintSpacing.lg),
            _button('action:3a.task.return_today', l10n.mintNext3aReturnToday,
                () => context.go('/home')),
          ],
        ),
      );

  Widget _taskDetail(S l10n) => Semantics(
        identifier: 'node:3a.task_detail',
        container: true,
        child: _taskContent(
          l10n,
          taxYear: _task!.taxYear,
          actions: [
            Text(l10n.mintNext3aExpiryDisclosure(_task!.expiresAt.year)),
            const SizedBox(height: MintSpacing.lg),
            _button('action:3a.task.delete', l10n.mintNext3aDelete,
                () => _confirmDelete(l10n),
                focusNode: _deleteFocusNode, destructive: true),
            const SizedBox(height: MintSpacing.sm),
            _textButton('action:3a.task.return_today',
                l10n.mintNext3aReturnToday, () => context.go('/home')),
          ],
        ),
      );

  Widget _taskContent(
    S l10n, {
    required int taxYear,
    required List<Widget> actions,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.mintNext3aTaskTitle,
                style: MintTextStyles.headlineSmall(
                    color: MintColors.textPrimary)),
          ),
          const SizedBox(height: MintSpacing.md),
          Text(l10n.mintNext3aTaskBody(taxYear)),
          const SizedBox(height: MintSpacing.lg),
          ...actions,
        ],
      );

  Widget _choiceTile(String id, String label, _Choice value) {
    final checked = _choice == value;
    final bool? accessibilitySelected;
    final String? semanticsHint;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        accessibilitySelected = null;
        semanticsHint = null;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        accessibilitySelected = checked;
        semanticsHint = checked
            ? null
            : WidgetsLocalizations.of(context).radioButtonUnselectedLabel;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.sm),
      child: Semantics(
        identifier: id,
        label: label,
        selected: accessibilitySelected,
        checked: checked,
        hint: semanticsHint,
        inMutuallyExclusiveGroup: true,
        onTap: () => setState(() {
          _choice = value;
          _checked = false;
        }),
        excludeSemantics: true,
        child: InkWell(
          onTap: () => setState(() {
            _choice = value;
            _checked = false;
          }),
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: checked
                    ? MintColors.success.withValues(alpha: .1)
                    : MintColors.craie,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(MintSpacing.md),
                child: Row(
                  children: [
                    Expanded(child: Text(label)),
                    if (checked) ...[
                      const SizedBox(width: MintSpacing.sm),
                      Semantics(
                        identifier:
                            'indicator:3a.teach_back.${value.name}.selected',
                        excludeSemantics: true,
                        child: const Icon(
                          Icons.check_circle,
                          color: MintColors.success,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _button(
    String id,
    String label,
    VoidCallback? onPressed, {
    bool destructive = false,
    FocusNode? focusNode,
  }) =>
      Semantics(
        identifier: id,
        label: label,
        button: true,
        enabled: onPressed != null,
        onTap: onPressed,
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: FilledButton(
            // lint-ignore: prefer_mint_cta
            onPressed: onPressed,
            focusNode: focusNode,
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: MintColors.error)
                : null,
            child: Text(label),
          ),
        ),
      );

  Widget _textButton(
    String id,
    String label,
    VoidCallback onPressed, {
    FocusNode? focusNode,
  }) =>
      Semantics(
        identifier: id,
        label: label,
        button: true,
        onTap: onPressed,
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: TextButton(
            // lint-ignore: prefer_mint_cta
            onPressed: onPressed,
            focusNode: focusNode,
            child: Text(label),
          ),
        ),
      );

  void _check() => setState(() {
        _checked = true;
        _correct = _choice == _Choice.annualTotal;
      });

  void _retry() => setState(() {
        _choice = null;
        _checked = false;
        _correct = false;
      });

  Future<void> _openSafeExit() async {
    final l10n = S.of(context)!;
    await showDialog<void>(
      context: context,
      animationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      builder: (dialogContext) => Semantics(
        identifier: 'overlay:3a.safe_exit',
        container: true,
        child: AlertDialog(
          scrollable: true,
          title: Text(l10n.mintNext3aSafeExitTitle),
          content: Text(l10n.mintNext3aSafeExitBody),
          actions: [
            _textButton(
                'action:3a.safe_exit.resume', l10n.mintNext3aSafeExitResume,
                () {
              Navigator.pop(dialogContext);
              _restoreFocus(_safeExitFocusNode);
            }),
            _textButton('action:3a.safe_exit.leave_without_saving',
                l10n.mintNext3aSafeExitLeave, () {
              Navigator.pop(dialogContext);
              _requestLeaveWithoutSaving();
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(S l10n) async {
    await showDialog<void>(
      context: context,
      animationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      builder: (dialogContext) => Semantics(
        identifier: 'overlay:3a.task.delete_confirm',
        container: true,
        child: AlertDialog(
          scrollable: true,
          title: Text(l10n.mintNext3aDeleteQuestion),
          content: Text(l10n.mintNext3aDeleteBoundary),
          actions: [
            _textButton('action:3a.task.delete_cancel', l10n.mintNext3aCancel,
                () {
              Navigator.pop(dialogContext);
              _restoreFocus(_deleteFocusNode);
            }),
            _textButton(
                'action:3a.task.delete_confirm', l10n.mintNext3aDeleteConfirm,
                () {
              Navigator.pop(dialogContext);
              unawaited(_delete());
            }),
          ],
        ),
      ),
    );
  }

  void _restoreFocus(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && node.canRequestFocus) node.requestFocus();
    });
  }
}
