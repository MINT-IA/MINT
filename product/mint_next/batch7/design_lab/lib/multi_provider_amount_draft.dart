import 'dart:collection';

import 'multi_provider_label.dart';
import 'ordinary_chf_amount.dart';

enum MultiProviderAddResult { added, existingEmpty, capacityReached }

class MultiProviderAmountRow {
  MultiProviderAmountRow._(this.id);

  final String id;
  String _providerName = '';
  String _rawAmount = '';
  int? _amountMinorUnits;
  bool _amountInvalid = false;

  String get providerName => _providerName;
  String get rawAmount => _rawAmount;
  int? get amountMinorUnits => _amountMinorUnits;
  bool get amountInvalid => _amountInvalid;

  bool get isCompletelyEmpty =>
      _providerName.trim().isEmpty && _rawAmount.trim().isEmpty;

  bool get hasSafeProviderName => multiProviderLabelIsSafe(_providerName);

  bool get hasPositiveExactAmount =>
      !_amountInvalid && (_amountMinorUnits ?? 0) > 0;
}

/// Ephemeral exact-money draft for the isolated Batch 14 runtime.
///
/// This first hidden slice deliberately exposes no persistence, network,
/// fiscal result, missing-provider request, or contentful deletion API.
class MultiProviderAmountDraft {
  final List<MultiProviderAmountRow> _rows = [];
  int _nextRowNumber = 1;

  MultiProviderAmountDraft() {
    _rows.add(_newRow());
  }

  UnmodifiableListView<MultiProviderAmountRow> get rows =>
      UnmodifiableListView(_rows);

  bool _allProvidersReviewed = false;
  int? _committedTotalMinorUnits;

  bool get allProvidersReviewed => _allProvidersReviewed;
  int? get committedTotalMinorUnits => _committedTotalMinorUnits;

  MultiProviderAmountRow _newRow() =>
      MultiProviderAmountRow._('provider-row-${_nextRowNumber++}');

  MultiProviderAmountRow? _row(String id) {
    for (final row in _rows) {
      if (row.id == id) return row;
    }
    return null;
  }

  void _invalidateCommit() {
    _allProvidersReviewed = false;
    _committedTotalMinorUnits = null;
  }

  void invalidateConfirmation() => _invalidateCommit();

  void updateProviderName(String id, String value) {
    final row = _row(id);
    if (row == null) return;
    row._providerName = value;
    _invalidateCommit();
  }

  void updateAmount(String id, String value, {required String locale}) {
    final row = _row(id);
    if (row == null) return;
    row._rawAmount = value;
    try {
      row._amountMinorUnits = parseOrdinaryChfAmount(value, locale: locale);
      row._amountInvalid = false;
    } on FormatException {
      row._amountMinorUnits = null;
      row._amountInvalid = true;
    }
    _invalidateCommit();
  }

  MultiProviderAddResult addProvider() {
    if (_rows.any((row) => row.isCompletelyEmpty)) {
      return MultiProviderAddResult.existingEmpty;
    }
    if (_rows.length >= 50) return MultiProviderAddResult.capacityReached;
    _rows.add(_newRow());
    _invalidateCommit();
    return MultiProviderAddResult.added;
  }

  bool removeEmptyProvider(String id) {
    if (_rows.length <= 1) return false;
    final index = _rows.indexWhere((row) => row.id == id);
    if (index < 0 || !_rows[index].isCompletelyEmpty) return false;
    _rows.removeAt(index);
    _invalidateCommit();
    return true;
  }

  Set<String> get duplicateRowIds {
    final rowsByKey = <String, List<String>>{};
    for (final row in _rows) {
      if (!row.hasSafeProviderName) continue;
      final key = normalizeMultiProviderLabel(row.providerName);
      rowsByKey.putIfAbsent(key, () => []).add(row.id);
    }
    return {
      for (final ids in rowsByKey.values)
        if (ids.length > 1) ...ids,
    };
  }

  Set<String> get laterDuplicateRowIds {
    final firstRowByKey = <String, String>{};
    final later = <String>{};
    for (final row in _rows) {
      if (!row.hasSafeProviderName) continue;
      final key = normalizeMultiProviderLabel(row.providerName);
      if (firstRowByKey.containsKey(key)) {
        later.add(row.id);
      } else {
        firstRowByKey[key] = row.id;
      }
    }
    return later;
  }

  bool get aggregateOverflow {
    var subtotal = BigInt.zero;
    for (final row in _rows) {
      final amount = row.amountMinorUnits;
      if (amount == null || amount <= 0) continue;
      subtotal += BigInt.from(amount);
      if (subtotal > BigInt.from(maxOrdinaryChfAmountMinorUnits)) return true;
    }
    return false;
  }

  int? get provisionalSubtotalMinorUnits {
    if (aggregateOverflow) return null;
    var subtotal = 0;
    for (final row in _rows) {
      final amount = row.amountMinorUnits;
      if (amount != null && amount > 0) subtotal += amount;
    }
    return subtotal == 0 ? null : subtotal;
  }

  bool get canConfirmAllProvidersReviewed =>
      _rows.isNotEmpty &&
      _rows.every(
        (row) => row.hasSafeProviderName && row.hasPositiveExactAmount,
      ) &&
      duplicateRowIds.isEmpty &&
      !aggregateOverflow;

  bool setAllProvidersReviewed(bool value) {
    if (!value) {
      _invalidateCommit();
      return true;
    }
    if (!canConfirmAllProvidersReviewed) return false;
    _allProvidersReviewed = true;
    _committedTotalMinorUnits = null;
    return true;
  }

  int? commit() {
    if (!_allProvidersReviewed || !canConfirmAllProvidersReviewed) return null;
    final subtotal = provisionalSubtotalMinorUnits;
    if (subtotal == null) return null;
    _committedTotalMinorUnits = subtotal;
    return subtotal;
  }

  void purge() {
    for (final row in _rows) {
      row._providerName = '';
      row._rawAmount = '';
      row._amountMinorUnits = null;
      row._amountInvalid = false;
    }
    _rows
      ..clear()
      ..add(_newRow());
    _invalidateCommit();
  }
}
