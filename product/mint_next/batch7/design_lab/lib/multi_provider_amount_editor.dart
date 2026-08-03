import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'l10n/generated/mint_next_localizations.dart';
import 'multi_provider_amount_draft.dart';

enum MultiProviderAmountEditorFocusTarget {
  amount,
  doubt,
  undo,
  continueAction,
}

class MultiProviderAmountEditor extends StatefulWidget {
  const MultiProviderAmountEditor({
    super.key,
    required this.taxYear,
    required this.draft,
    required this.onCommitted,
    required this.onCorrectPrevious,
    required this.onUnknown,
    required this.restoreAmountFocus,
    required this.restoreUnknownActionFocus,
    required this.onRestoreFocusConsumed,
    this.enableBatch16 = false,
    this.onAmountDoubt,
    this.restoreRowId,
    this.restoreFocusTarget,
    this.onDraftChanged,
  });

  final int taxYear;
  final MultiProviderAmountDraft draft;
  final ValueChanged<int> onCommitted;
  final VoidCallback onCorrectPrevious;
  final VoidCallback onUnknown;
  final bool restoreAmountFocus;
  final bool restoreUnknownActionFocus;
  final VoidCallback onRestoreFocusConsumed;
  final bool enableBatch16;
  final ValueChanged<MultiProviderUnresolvedOrigin>? onAmountDoubt;
  final String? restoreRowId;
  final MultiProviderAmountEditorFocusTarget? restoreFocusTarget;
  final VoidCallback? onDraftChanged;

  @override
  State<MultiProviderAmountEditor> createState() =>
      _MultiProviderAmountEditorState();
}

class _MultiProviderAmountEditorState extends State<MultiProviderAmountEditor> {
  final Map<String, TextEditingController> _providerControllers = {};
  final Map<String, TextEditingController> _amountControllers = {};
  final Map<String, FocusNode> _providerFocus = {};
  final Map<String, FocusNode> _amountFocus = {};
  final Map<String, FocusNode> _undoFocus = {};
  final Map<String, FocusNode> _finalizeFocus = {};
  final Map<String, FocusNode> _doubtFocus = {};
  final Map<String, FocusNode> _restoredHeadingFocus = {};
  final FocusNode _reviewedFocus = FocusNode(
    debugLabel: 'all providers reviewed',
  );
  final FocusNode _addProviderFocus = FocusNode(debugLabel: 'add provider');
  final FocusNode _aggregateOverflowFocus = FocusNode(
    debugLabel: 'aggregate overflow',
  );
  final FocusNode _unknownActionFocus = FocusNode(
    debugLabel: 'unknown amount trigger',
  );
  final FocusNode _continueFocus = FocusNode(
    debugLabel: 'all confirmed editor continue',
  );
  final Map<String, String?> _providerErrors = {};
  final Map<String, String?> _amountErrors = {};
  bool _reviewedError = false;
  bool _emptyBeforeAddError = false;
  bool _capacityError = false;
  String? _tombstoneErrorId;
  String? _unresolvedErrorId;
  String? _removalAnnouncement;

  @override
  void initState() {
    super.initState();
    _ensureResources();
    _scheduleRequestedFocusRestore();
  }

  @override
  void didUpdateWidget(covariant MultiProviderAmountEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureResources();
    if (oldWidget.restoreAmountFocus != widget.restoreAmountFocus ||
        oldWidget.restoreUnknownActionFocus !=
            widget.restoreUnknownActionFocus ||
        oldWidget.restoreRowId != widget.restoreRowId ||
        oldWidget.restoreFocusTarget != widget.restoreFocusTarget) {
      _scheduleRequestedFocusRestore();
    }
  }

  void _scheduleRequestedFocusRestore() {
    final hasLegacyRequest =
        widget.restoreAmountFocus || widget.restoreUnknownActionFocus;
    final hasExactRequest =
        widget.restoreFocusTarget != null &&
        (widget.restoreFocusTarget ==
                MultiProviderAmountEditorFocusTarget.continueAction ||
            widget.restoreRowId != null);
    if (!hasLegacyRequest && !hasExactRequest) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusNode? target;
      if (hasExactRequest) {
        target = switch (widget.restoreFocusTarget!) {
          MultiProviderAmountEditorFocusTarget.amount =>
            _amountFocus[widget.restoreRowId],
          MultiProviderAmountEditorFocusTarget.doubt =>
            _doubtFocus[widget.restoreRowId],
          MultiProviderAmountEditorFocusTarget.undo =>
            _undoFocus[widget.restoreRowId],
          MultiProviderAmountEditorFocusTarget.continueAction => _continueFocus,
        };
      } else if (widget.restoreAmountFocus) {
        target = _amountFocus[widget.draft.rows.first.id];
      } else {
        target = _unknownActionFocus;
      }
      target?.requestFocus();
      final focusContext = target?.context;
      if (focusContext != null) {
        Scrollable.ensureVisible(focusContext, alignment: 0.35);
      }
      widget.onRestoreFocusConsumed();
    });
  }

  void _ensureResources() {
    for (final row in widget.draft.rows) {
      _providerControllers.putIfAbsent(
        row.id,
        () => TextEditingController(text: row.providerName),
      );
      _amountControllers.putIfAbsent(
        row.id,
        () => TextEditingController(text: row.rawAmount),
      );
      _providerFocus.putIfAbsent(
        row.id,
        () => FocusNode(debugLabel: 'provider name ${row.id}'),
      );
      _amountFocus.putIfAbsent(
        row.id,
        () => FocusNode(debugLabel: 'amount ${row.id}'),
      );
      _undoFocus.putIfAbsent(
        row.id,
        () => FocusNode(debugLabel: 'undo removal ${row.id}'),
      );
      _finalizeFocus.putIfAbsent(
        row.id,
        () => FocusNode(debugLabel: 'finalize removal ${row.id}'),
      );
      _doubtFocus.putIfAbsent(
        row.id,
        () => FocusNode(debugLabel: 'amount doubt ${row.id}'),
      );
      _restoredHeadingFocus.putIfAbsent(
        row.id,
        () => FocusNode(
          debugLabel: 'restored provider heading ${row.id}',
          skipTraversal: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _providerControllers.values) {
      controller.dispose();
    }
    for (final controller in _amountControllers.values) {
      controller.dispose();
    }
    for (final focus in _providerFocus.values) {
      focus.dispose();
    }
    for (final focus in _amountFocus.values) {
      focus.dispose();
    }
    for (final focus in _undoFocus.values) {
      focus.dispose();
    }
    for (final focus in _finalizeFocus.values) {
      focus.dispose();
    }
    for (final focus in _doubtFocus.values) {
      focus.dispose();
    }
    for (final focus in _restoredHeadingFocus.values) {
      focus.dispose();
    }
    _reviewedFocus.dispose();
    _addProviderFocus.dispose();
    _aggregateOverflowFocus.dispose();
    _unknownActionFocus.dispose();
    _continueFocus.dispose();
    super.dispose();
  }

  String _formatMinorUnits(int value, Locale locale) {
    final whole = value ~/ 100;
    final cents = (value % 100).toString().padLeft(2, '0');
    final localeName = locale.toLanguageTag();
    final grouped = NumberFormat.decimalPattern(localeName).format(whole);
    final decimal = NumberFormat.currency(
      locale: localeName,
      name: 'CHF',
      decimalDigits: 2,
    ).symbols.DECIMAL_SEP;
    return '$grouped$decimal$cents CHF';
  }

  void _addProvider() {
    final result = widget.draft.addProvider();
    if (result != MultiProviderAddResult.added) {
      setState(() {
        _emptyBeforeAddError = result == MultiProviderAddResult.existingEmpty;
        _capacityError = result == MultiProviderAddResult.capacityReached;
      });
      if (_capacityError) {
        _addProviderFocus.requestFocus();
        return;
      }
      MultiProviderAmountRow? empty;
      for (final row in widget.draft.rows) {
        if (row.isCompletelyEmpty) {
          empty = row;
          break;
        }
      }
      if (empty != null) _providerFocus[empty.id]?.requestFocus();
      return;
    }
    setState(() {
      _emptyBeforeAddError = false;
      _capacityError = false;
      _reviewedError = false;
      _removalAnnouncement = null;
      _ensureResources();
    });
    widget.onDraftChanged?.call();
    final added = widget.draft.rows.last.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _providerFocus[added]?.requestFocus();
      final context = _providerFocus[added]?.context;
      if (context != null) Scrollable.ensureVisible(context, alignment: 0.35);
    });
  }

  void _remove(
    MultiProviderAmountRow row,
    MultiProviderRemoveToken removeToken,
  ) {
    final id = row.id;
    final removedIndex = widget.draft.rows.indexWhere((item) => item.id == id);
    final result = widget.draft.removeProvider(removeToken);
    if (result == MultiProviderRemoveResult.stale ||
        result == MultiProviderRemoveResult.minimumActive) {
      return;
    }
    if (result == MultiProviderRemoveResult.tombstoned) {
      setState(() {
        _reviewedError = false;
        _emptyBeforeAddError = false;
        _capacityError = false;
        _tombstoneErrorId = null;
        final l10n = MintNextLocalizations.of(context);
        _removalAnnouncement = l10n.batch15TombstonedAnnouncement(
          _subtotalForAnnouncement(l10n),
        );
      });
      widget.onDraftChanged?.call();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final rows = widget.draft.rows;
        MultiProviderAmountRow? target;
        for (var offset = 1; offset < rows.length; offset++) {
          final candidateIndex = removedIndex + offset;
          if (candidateIndex < rows.length && rows[candidateIndex].isActive) {
            target = rows[candidateIndex];
            break;
          }
        }
        if (target == null) {
          for (
            var candidateIndex = removedIndex - 1;
            candidateIndex >= 0;
            candidateIndex--
          ) {
            if (rows[candidateIndex].isActive) {
              target = rows[candidateIndex];
              break;
            }
          }
        }
        if (target == null) {
          _addProviderFocus.requestFocus();
        } else {
          _providerFocus[target.id]?.requestFocus();
        }
      });
      return;
    }
    _providerControllers.remove(id)?.dispose();
    _amountControllers.remove(id)?.dispose();
    _providerFocus.remove(id)?.dispose();
    _amountFocus.remove(id)?.dispose();
    _undoFocus.remove(id)?.dispose();
    _finalizeFocus.remove(id)?.dispose();
    _doubtFocus.remove(id)?.dispose();
    _restoredHeadingFocus.remove(id)?.dispose();
    setState(() {
      _providerErrors.remove(id);
      _amountErrors.remove(id);
      _reviewedError = false;
      _emptyBeforeAddError = false;
      _capacityError = false;
      _removalAnnouncement = MintNextLocalizations.of(
        context,
      ).batch14RemovedAnnouncement;
    });
    widget.onDraftChanged?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rows = widget.draft.rows;
      MultiProviderAmountRow? target;
      for (
        var candidateIndex = removedIndex;
        candidateIndex < rows.length;
        candidateIndex++
      ) {
        if (rows[candidateIndex].isActive) {
          target = rows[candidateIndex];
          break;
        }
      }
      if (target == null) {
        for (
          var candidateIndex = removedIndex - 1;
          candidateIndex >= 0;
          candidateIndex--
        ) {
          if (rows[candidateIndex].isActive) {
            target = rows[candidateIndex];
            break;
          }
        }
      }
      if (target == null) {
        _addProviderFocus.requestFocus();
      } else {
        _providerFocus[target.id]?.requestFocus();
      }
    });
  }

  void _undo(MultiProviderAmountRow row, MultiProviderUndoToken undoToken) {
    if (widget.draft.undoRemoval(undoToken) !=
        MultiProviderUndoResult.restored) {
      return;
    }
    setState(() {
      _reviewedError = false;
      _tombstoneErrorId = null;
      final l10n = MintNextLocalizations.of(context);
      _removalAnnouncement = l10n.batch15RestoredAnnouncement(
        _subtotalForAnnouncement(l10n),
      );
    });
    widget.onDraftChanged?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _restoredHeadingFocus[row.id]?.requestFocus();
    });
  }

  void _finalize(
    MultiProviderAmountRow row,
    MultiProviderFinalizeToken finalizeToken,
  ) {
    final id = row.id;
    final index = widget.draft.rows.indexOf(row);
    String? targetId;
    final before = widget.draft.rows;
    for (
      var candidateIndex = index + 1;
      candidateIndex < before.length;
      candidateIndex++
    ) {
      if (before[candidateIndex].isActive) {
        targetId = before[candidateIndex].id;
        break;
      }
    }
    if (targetId == null) {
      for (
        var candidateIndex = index - 1;
        candidateIndex >= 0;
        candidateIndex--
      ) {
        if (before[candidateIndex].isActive) {
          targetId = before[candidateIndex].id;
          break;
        }
      }
    }
    if (widget.draft.finalizeRemoval(finalizeToken) !=
        MultiProviderFinalizeResult.finalized) {
      return;
    }
    _providerControllers.remove(id)?.dispose();
    _amountControllers.remove(id)?.dispose();
    _providerFocus.remove(id)?.dispose();
    _amountFocus.remove(id)?.dispose();
    _undoFocus.remove(id)?.dispose();
    _finalizeFocus.remove(id)?.dispose();
    _doubtFocus.remove(id)?.dispose();
    _restoredHeadingFocus.remove(id)?.dispose();
    setState(() {
      _providerErrors.remove(id);
      _amountErrors.remove(id);
      _reviewedError = false;
      _tombstoneErrorId = null;
      _removalAnnouncement = MintNextLocalizations.of(
        context,
      ).batch15FinalizedAnnouncement;
    });
    widget.onDraftChanged?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (targetId == null) {
        _addProviderFocus.requestFocus();
        return;
      }
      _providerFocus[targetId]?.requestFocus();
    });
  }

  String _subtotalForAnnouncement(MintNextLocalizations l10n) {
    final subtotal = widget.draft.provisionalSubtotalMinorUnits;
    return subtotal == null
        ? l10n.batch15NoProvisionalSubtotal
        : _formatMinorUnits(subtotal, Localizations.localeOf(context));
  }

  String _classificationLabel(
    MintNextLocalizations l10n,
    MultiProviderAmountRow row,
    int rowNumber,
  ) {
    final prefix = l10n.batch16RowContext(rowNumber, widget.taxYear);
    return switch (row.classification) {
      MultiProviderAmountClassification.unreviewed =>
        '$prefix. ${l10n.batch16MintNotVerifiedMeaning}',
      MultiProviderAmountClassification.confirmedOrdinary =>
        '$prefix. ${l10n.batch16AnnualOrdinaryTotalMeaning}',
      MultiProviderAmountClassification.unresolved =>
        '$prefix. ${l10n.batch16RefundVsAllZeroMeaning}',
    };
  }

  String _classificationKey(MultiProviderAmountRow row) =>
      switch (row.classification) {
        MultiProviderAmountClassification.unreviewed => 'amount_unreviewed',
        MultiProviderAmountClassification.confirmedOrdinary =>
          'amount_confirmed_ordinary',
        MultiProviderAmountClassification.unresolved => 'amount_unresolved',
      };

  void _markAmountDoubt(MultiProviderAmountRow row) {
    final origin = widget.draft.markAmountUnresolved(row.editToken);
    if (origin == null) {
      _amountFocus[row.id]?.requestFocus();
      return;
    }
    setState(() {
      _reviewedError = false;
      _unresolvedErrorId = null;
      _tombstoneErrorId = null;
      _removalAnnouncement = null;
    });
    widget.onAmountDoubt?.call(origin);
  }

  void _continue() {
    final l10n = MintNextLocalizations.of(context);
    final duplicates = widget.draft.laterDuplicateRowIds;
    String? firstProviderError;
    String? firstAmountError;
    String? firstUnresolved;
    for (final row in widget.draft.rows) {
      if (!row.isActive) continue;
      final providerError = row.providerName.trim().isEmpty
          ? l10n.batch11ProviderNameEmpty
          : !row.hasSafeProviderName
          ? l10n.batch11ProviderNameSensitive
          : duplicates.contains(row.id)
          ? l10n.batch14Duplicate
          : null;
      final amountError = row.rawAmount.trim().isEmpty || row.amountInvalid
          ? l10n.batch11AmountInvalid
          : !row.hasPositiveExactAmount
          ? l10n.batch11AmountZero
          : null;
      _providerErrors[row.id] = providerError;
      _amountErrors[row.id] = amountError;
      firstProviderError ??= providerError == null ? null : row.id;
      firstAmountError ??= amountError == null ? null : row.id;
      if (firstUnresolved == null &&
          row.classification == MultiProviderAmountClassification.unresolved) {
        firstUnresolved = row.id;
      }
    }
    final committed = widget.draft.commit();
    setState(() => _reviewedError = !widget.draft.allProvidersReviewed);
    if (firstProviderError != null) {
      _providerFocus[firstProviderError]?.requestFocus();
      return;
    }
    if (firstAmountError != null) {
      _amountFocus[firstAmountError]?.requestFocus();
      return;
    }
    if (firstUnresolved != null) {
      setState(() {
        _reviewedError = false;
        _unresolvedErrorId = firstUnresolved;
      });
      _doubtFocus[firstUnresolved]?.requestFocus();
      return;
    }
    MultiProviderAmountRow? firstTombstone;
    for (final row in widget.draft.rows) {
      if (!row.isActive) {
        firstTombstone = row;
        break;
      }
    }
    if (firstTombstone != null) {
      setState(() {
        _reviewedError = false;
        _tombstoneErrorId = firstTombstone!.id;
      });
      _undoFocus[firstTombstone.id]?.requestFocus();
      return;
    }
    if (widget.draft.aggregateOverflow) {
      _aggregateOverflowFocus.requestFocus();
      return;
    }
    if (committed == null) {
      _reviewedFocus.requestFocus();
      return;
    }
    widget.onCommitted(committed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    final subtotal = widget.draft.provisionalSubtotalMinorUnits;
    final duplicates = widget.draft.laterDuplicateRowIds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.batch14ClassificationGuide(widget.taxYear),
          key: const ValueKey('content:batch14.classification_guide'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.batch14Privacy,
          key: const ValueKey('content:batch14.privacy'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        for (var index = 0; index < widget.draft.rows.length; index++) ...[
          Builder(
            builder: (context) {
              final row = widget.draft.rows[index];
              if (!row.isActive) {
                final undoToken = row.undoToken!;
                final finalizeToken = row.finalizeToken!;
                return Semantics(
                  key: ValueKey('group:provider_tombstone:${row.id}'),
                  container: true,
                  explicitChildNodes: true,
                  label: l10n.batch15TombstoneLabel(index + 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ExcludeSemantics(
                        child: Text(l10n.batch15TombstoneLabel(index + 1)),
                      ),
                      if (_tombstoneErrorId == row.id)
                        Semantics(
                          key: ValueKey('error:tombstone:${row.id}'),
                          liveRegion: true,
                          child: Text(l10n.batch15ResolveTombstoneError),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          key: ValueKey('action:undo_removal:${row.id}'),
                          focusNode: _undoFocus[row.id],
                          onPressed: () => _undo(row, undoToken),
                          child: Text(l10n.batch15UndoRemoval(index + 1)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 48,
                        child: TextButton(
                          key: ValueKey('action:finalize_removal:${row.id}'),
                          focusNode: _finalizeFocus[row.id],
                          onPressed: () => _finalize(row, finalizeToken),
                          child: Text(l10n.batch15FinalizeRemoval(index + 1)),
                        ),
                      ),
                    ],
                  ),
                );
              }
              final editToken = row.editToken;
              final removeToken = row.removeToken!;
              final providerError =
                  _providerErrors[row.id] ??
                  (duplicates.contains(row.id) ? l10n.batch14Duplicate : null);
              return Semantics(
                key: ValueKey('group:provider_row:${row.id}'),
                container: true,
                explicitChildNodes: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Focus(
                        focusNode: _restoredHeadingFocus[row.id],
                        child: Text(
                          l10n.batch14ProviderRowLabel(index + 1),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      key: ValueKey('field:provider_name:${row.id}'),
                      controller: _providerControllers[row.id],
                      focusNode: _providerFocus[row.id],
                      textInputAction: TextInputAction.next,
                      enableIMEPersonalizedLearning: false,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: l10n.batch11ProviderNameLabel,
                        errorText: providerError,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        if (!widget.draft.updateProviderName(
                          editToken,
                          value,
                        )) {
                          return;
                        }
                        setState(() {
                          for (final id in _providerErrors.keys.toList()) {
                            _providerErrors[id] = null;
                          }
                          _reviewedError = false;
                          _unresolvedErrorId = null;
                          _tombstoneErrorId = null;
                          _removalAnnouncement = null;
                        });
                        widget.onDraftChanged?.call();
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      key: ValueKey('field:amount:${row.id}'),
                      controller: _amountControllers[row.id],
                      focusNode: _amountFocus[row.id],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      enableIMEPersonalizedLearning: false,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: l10n.batch11OrdinaryAmountLabel(
                          widget.taxYear,
                        ),
                        suffixText: 'CHF',
                        errorText: _amountErrors[row.id],
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        if (!widget.draft.updateAmount(
                          editToken,
                          value,
                          locale: Localizations.localeOf(context).languageCode,
                        )) {
                          return;
                        }
                        setState(() {
                          _amountErrors[row.id] = null;
                          _reviewedError = false;
                          _unresolvedErrorId = null;
                          _tombstoneErrorId = null;
                          _removalAnnouncement = null;
                        });
                        widget.onDraftChanged?.call();
                      },
                    ),
                    if (widget.enableBatch16) ...[
                      const SizedBox(height: 8),
                      Semantics(
                        key: ValueKey(
                          'status:${_classificationKey(row)}:${row.id}',
                        ),
                        label: _classificationLabel(l10n, row, index + 1),
                        child: ExcludeSemantics(
                          child: Text(
                            _classificationLabel(l10n, row, index + 1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        key: ValueKey('action:amount_doubt:${row.id}'),
                        label:
                            '${l10n.batch11UnknownAmount}. '
                            '${l10n.batch16RowContext(index + 1, widget.taxYear)}. '
                            '${l10n.batch11OrdinaryAmountLabel(widget.taxYear)}',
                        hint: _unresolvedErrorId == row.id
                            ? l10n.batch16MintNotVerifiedMeaning
                            : null,
                        button: true,
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            focusNode: _doubtFocus[row.id],
                            onPressed: row.hasPositiveExactAmount
                                ? () => _markAmountDoubt(row)
                                : null,
                            child: Text(l10n.batch11UnknownAmount),
                          ),
                        ),
                      ),
                      if (_unresolvedErrorId == row.id)
                        Semantics(
                          key: ValueKey('error:amount_unresolved:${row.id}'),
                          liveRegion: true,
                          child: Text(l10n.batch16MintNotVerifiedMeaning),
                        ),
                    ],
                    if (widget.draft.activeRowCount > 1)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: ValueKey(
                            row.isCompletelyEmpty
                                ? 'action:remove_empty:${row.id}'
                                : 'action:remove_provider:${row.id}',
                          ),
                          onPressed: () => _remove(row, removeToken),
                          child: Text(
                            row.isCompletelyEmpty
                                ? l10n.batch14RemoveEmpty
                                : l10n.batch15RemoveProvider,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
        OutlinedButton.icon(
          key: const ValueKey('action:fact_contributed_amount.add_provider'),
          onPressed: _addProvider,
          focusNode: _addProviderFocus,
          icon: const Icon(Icons.add),
          label: Text(l10n.batch14AddProvider),
        ),
        if (_emptyBeforeAddError)
          Semantics(
            key: const ValueKey('error:batch14.empty_before_add'),
            liveRegion: true,
            child: Text(l10n.batch14EmptyBeforeAdd),
          ),
        if (_capacityError)
          Semantics(
            key: const ValueKey('error:batch14.provider_capacity'),
            liveRegion: true,
            child: Text(l10n.batch14ProviderCapacity),
          ),
        if (_removalAnnouncement != null)
          Semantics(
            key: const ValueKey('status:batch14.row_removed'),
            liveRegion: true,
            label: _removalAnnouncement,
            child: const SizedBox.shrink(),
          ),
        if (widget.draft.aggregateOverflow)
          Focus(
            focusNode: _aggregateOverflowFocus,
            child: Semantics(
              key: const ValueKey('error:batch14.aggregate_overflow'),
              liveRegion: true,
              child: Text(l10n.batch14AggregateOverflow),
            ),
          )
        else if (subtotal != null) ...[
          const SizedBox(height: 16),
          Semantics(
            key: const ValueKey(
              'value:fact_contributed_amount.running_subtotal',
            ),
            liveRegion: true,
            child: Text(
              l10n.batch14ProvisionalSubtotal(
                _formatMinorUnits(subtotal, Localizations.localeOf(context)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        CheckboxListTile(
          key: const ValueKey(
            'action:fact_contributed_amount.toggle_all_reviewed',
          ),
          contentPadding: EdgeInsets.zero,
          focusNode: _reviewedFocus,
          value: widget.draft.allProvidersReviewed,
          title: Text(l10n.batch14AllReviewed(widget.taxYear)),
          subtitle: _reviewedError ? Text(l10n.batch11ReviewAllRequired) : null,
          onChanged: (value) {
            final requested = value ?? false;
            final accepted = widget.draft.setAllProvidersReviewed(requested);
            if (requested && !accepted) {
              _continue();
              return;
            }
            setState(() {
              _reviewedError = false;
              _removalAnnouncement = null;
              _tombstoneErrorId = null;
            });
            widget.onDraftChanged?.call();
          },
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('action:fact_contributed_amount.continue'),
          focusNode: _continueFocus,
          onPressed: _continue,
          child: Text(l10n.batch11Continue),
        ),
        if (subtotal == null)
          OutlinedButton(
            key: const ValueKey(
              'action:fact_contributed_amount.unknown_amount',
            ),
            focusNode: _unknownActionFocus,
            onPressed: widget.onUnknown,
            child: Text(l10n.batch11UnknownAmount),
          ),
        TextButton(
          key: const ValueKey(
            'action:fact_contributed_amount.correct_previous',
          ),
          onPressed: () {
            widget.draft.invalidateConfirmation();
            widget.onCorrectPrevious();
          },
          child: Text(l10n.batch11CorrectPrevious),
        ),
      ],
    );
  }
}
