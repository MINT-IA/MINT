import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'l10n/generated/mint_next_localizations.dart';
import 'multi_provider_amount_draft.dart';

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
  });

  final int taxYear;
  final MultiProviderAmountDraft draft;
  final ValueChanged<int> onCommitted;
  final VoidCallback onCorrectPrevious;
  final VoidCallback onUnknown;
  final bool restoreAmountFocus;
  final bool restoreUnknownActionFocus;
  final VoidCallback onRestoreFocusConsumed;

  @override
  State<MultiProviderAmountEditor> createState() =>
      _MultiProviderAmountEditorState();
}

class _MultiProviderAmountEditorState extends State<MultiProviderAmountEditor> {
  final Map<String, TextEditingController> _providerControllers = {};
  final Map<String, TextEditingController> _amountControllers = {};
  final Map<String, FocusNode> _providerFocus = {};
  final Map<String, FocusNode> _amountFocus = {};
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
  final Map<String, String?> _providerErrors = {};
  final Map<String, String?> _amountErrors = {};
  bool _reviewedError = false;
  bool _emptyBeforeAddError = false;
  bool _capacityError = false;
  String? _removalAnnouncement;

  @override
  void initState() {
    super.initState();
    _ensureResources();
    if (widget.restoreAmountFocus || widget.restoreUnknownActionFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = widget.restoreAmountFocus
            ? _amountFocus[widget.draft.rows.first.id]
            : _unknownActionFocus;
        target?.requestFocus();
        final focusContext = target?.context;
        if (focusContext != null) {
          Scrollable.ensureVisible(focusContext, alignment: 0.35);
        }
        widget.onRestoreFocusConsumed();
      });
    }
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
    _reviewedFocus.dispose();
    _addProviderFocus.dispose();
    _aggregateOverflowFocus.dispose();
    _unknownActionFocus.dispose();
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
    final added = widget.draft.rows.last.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _providerFocus[added]?.requestFocus();
      final context = _providerFocus[added]?.context;
      if (context != null) Scrollable.ensureVisible(context, alignment: 0.35);
    });
  }

  void _removeEmpty(String id) {
    final removedIndex = widget.draft.rows.indexWhere((row) => row.id == id);
    if (!widget.draft.removeEmptyProvider(id)) return;
    _providerControllers.remove(id)?.dispose();
    _amountControllers.remove(id)?.dispose();
    _providerFocus.remove(id)?.dispose();
    _amountFocus.remove(id)?.dispose();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rows = widget.draft.rows;
      if (rows.isEmpty) {
        _addProviderFocus.requestFocus();
        return;
      }
      final targetIndex = removedIndex < rows.length
          ? removedIndex
          : rows.length - 1;
      _providerFocus[rows[targetIndex].id]?.requestFocus();
    });
  }

  void _continue() {
    final l10n = MintNextLocalizations.of(context);
    final duplicates = widget.draft.laterDuplicateRowIds;
    String? firstProviderError;
    String? firstAmountError;
    for (final row in widget.draft.rows) {
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
              final providerError =
                  _providerErrors[row.id] ??
                  (duplicates.contains(row.id) ? l10n.batch14Duplicate : null);
              return Semantics(
                key: ValueKey('group:provider_row:${row.id}'),
                container: true,
                explicitChildNodes: true,
                label: l10n.batch14ProviderRowLabel(index + 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ExcludeSemantics(
                      child: Text(
                        l10n.batch14ProviderRowLabel(index + 1),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      key: ValueKey('field:provider_name:${row.id}'),
                      controller: _providerControllers[row.id],
                      focusNode: _providerFocus[row.id],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.batch11ProviderNameLabel,
                        errorText: providerError,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) => setState(() {
                        widget.draft.updateProviderName(row.id, value);
                        for (final id in _providerErrors.keys.toList()) {
                          _providerErrors[id] = null;
                        }
                        _reviewedError = false;
                        _removalAnnouncement = null;
                      }),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      key: ValueKey('field:amount:${row.id}'),
                      controller: _amountControllers[row.id],
                      focusNode: _amountFocus[row.id],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.batch11OrdinaryAmountLabel(
                          widget.taxYear,
                        ),
                        suffixText: 'CHF',
                        errorText: _amountErrors[row.id],
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) => setState(() {
                        widget.draft.updateAmount(
                          row.id,
                          value,
                          locale: Localizations.localeOf(context).languageCode,
                        );
                        _amountErrors[row.id] = null;
                        _reviewedError = false;
                        _removalAnnouncement = null;
                      }),
                    ),
                    if (widget.draft.rows.length > 1 && row.isCompletelyEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: ValueKey('action:remove_empty:${row.id}'),
                          onPressed: () => _removeEmpty(row.id),
                          child: Text(l10n.batch14RemoveEmpty),
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
          Text(
            l10n.batch14ProvisionalSubtotal(
              _formatMinorUnits(subtotal, Localizations.localeOf(context)),
            ),
            key: const ValueKey(
              'value:fact_contributed_amount.running_subtotal',
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
            setState(() => _reviewedError = false);
          },
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('action:fact_contributed_amount.continue'),
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
