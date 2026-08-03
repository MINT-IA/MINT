import 'dart:collection';

import 'multi_provider_label.dart';
import 'ordinary_chf_amount.dart';

enum MultiProviderAddResult { added, existingEmpty, capacityReached }

enum MultiProviderRowLifecycle { active, tombstone }

enum MultiProviderAmountClassification {
  unreviewed,
  confirmedOrdinary,
  unresolved,
}

enum MultiProviderRemoveResult {
  tombstoned,
  removedEmpty,
  stale,
  minimumActive,
}

enum MultiProviderUndoResult { restored, stale }

enum MultiProviderFinalizeResult { finalized, stale }

enum MultiProviderUnresolvedActionResult { resolvedToUnreviewed, stale }

enum MultiProviderUnresolvedRefundResult { tombstoned, ineligible, stale }

enum MultiProviderAllZeroCorrectionResult { ready, stale }

sealed class _RowToken {
  const _RowToken(this.rowId, this.epoch, this.generation, this.nonce);
  final String rowId;
  final int epoch;
  final int generation;
  final int nonce;
}

final class MultiProviderEditToken extends _RowToken {
  const MultiProviderEditToken._(
    super.rowId,
    super.epoch,
    super.generation,
    super.nonce,
  );
}

final class MultiProviderRemoveToken extends _RowToken {
  const MultiProviderRemoveToken._(
    super.rowId,
    super.epoch,
    super.generation,
    super.nonce,
  );
}

final class MultiProviderUndoToken extends _RowToken {
  const MultiProviderUndoToken._(
    super.rowId,
    super.epoch,
    super.generation,
    super.nonce,
  );
}

final class MultiProviderFinalizeToken extends _RowToken {
  const MultiProviderFinalizeToken._(
    super.rowId,
    super.epoch,
    super.generation,
    super.nonce,
  );
}

final class MultiProviderUnresolvedResolveToken extends _RowToken {
  const MultiProviderUnresolvedResolveToken._(
    super.rowId,
    super.epoch,
    super.generation,
    super.nonce,
  );
}

final class MultiProviderUnresolvedRefundToken extends _RowToken {
  const MultiProviderUnresolvedRefundToken._(
    super.rowId,
    super.epoch,
    super.generation,
    super.nonce,
  );
}

final class MultiProviderUnresolvedAllZeroToken extends _RowToken {
  const MultiProviderUnresolvedAllZeroToken._(
    super.rowId,
    super.epoch,
    super.generation,
    super.nonce,
  );
}

final class MultiProviderUnresolvedOrigin {
  const MultiProviderUnresolvedOrigin._(
    this.rowId,
    this.resolveToken,
    this.refundToken,
    this.allZeroToken,
    this._capturedRemoveToken,
  );

  final String rowId;
  final MultiProviderUnresolvedResolveToken resolveToken;
  final MultiProviderUnresolvedRefundToken refundToken;
  final MultiProviderUnresolvedAllZeroToken allZeroToken;
  final MultiProviderRemoveToken _capturedRemoveToken;
}

class MultiProviderAmountRow {
  MultiProviderAmountRow._(this.id, this._generation);

  final String id;
  int _generation;
  MultiProviderRowLifecycle _lifecycle = MultiProviderRowLifecycle.active;
  String _providerName = '';
  String _rawAmount = '';
  int? _amountMinorUnits;
  bool _amountInvalid = false;
  MultiProviderAmountClassification _classification =
      MultiProviderAmountClassification.unreviewed;
  MultiProviderEditToken? _editToken;
  MultiProviderRemoveToken? _removeToken;
  MultiProviderUndoToken? _undoToken;
  MultiProviderFinalizeToken? _finalizeToken;
  MultiProviderUnresolvedOrigin? _unresolvedOrigin;

  MultiProviderRowLifecycle get lifecycle => _lifecycle;
  String get providerName => isActive ? _providerName : '';
  String get rawAmount => isActive ? _rawAmount : '';
  int? get amountMinorUnits => isActive ? _amountMinorUnits : null;
  bool get amountInvalid => _amountInvalid;
  MultiProviderAmountClassification get classification => _classification;
  MultiProviderEditToken get editToken => _editToken!;
  MultiProviderRemoveToken? get removeToken => _removeToken;
  MultiProviderUndoToken? get undoToken => _undoToken;
  MultiProviderFinalizeToken? get finalizeToken => _finalizeToken;

  bool get isActive => _lifecycle == MultiProviderRowLifecycle.active;
  bool get isCompletelyEmpty =>
      isActive && _providerName.trim().isEmpty && _rawAmount.trim().isEmpty;
  bool get hasSafeProviderName =>
      isActive && multiProviderLabelIsSafe(_providerName);
  bool get hasPositiveExactAmount =>
      isActive && !_amountInvalid && (_amountMinorUnits ?? 0) > 0;
}

/// Ephemeral exact-money draft for the isolated hidden runtime harness.
class MultiProviderAmountDraft {
  final List<MultiProviderAmountRow> _rows = [];
  int _nextRowNumber = 1;
  int _nextNonce = 1;
  int _sessionEpoch = 1;
  bool _allProvidersReviewed = false;
  int? _committedTotalMinorUnits;

  MultiProviderAmountDraft() {
    _rows.add(_newRow());
  }

  UnmodifiableListView<MultiProviderAmountRow> get rows =>
      UnmodifiableListView(_rows);
  bool get allProvidersReviewed => _allProvidersReviewed;
  int? get committedTotalMinorUnits => _committedTotalMinorUnits;
  int get activeRowCount => _rows.where((row) => row.isActive).length;
  bool get hasTombstones => _rows.any((row) => !row.isActive);

  MultiProviderAmountRow _newRow() {
    final row = MultiProviderAmountRow._('provider-row-${_nextRowNumber++}', 1);
    _issueActiveTokens(row);
    return row;
  }

  void _issueActiveTokens(MultiProviderAmountRow row) {
    row._editToken = MultiProviderEditToken._(
      row.id,
      _sessionEpoch,
      row._generation,
      _nextNonce++,
    );
    row._removeToken = MultiProviderRemoveToken._(
      row.id,
      _sessionEpoch,
      row._generation,
      _nextNonce++,
    );
    row._undoToken = null;
    row._finalizeToken = null;
  }

  void _issueTombstoneTokens(MultiProviderAmountRow row) {
    row._editToken = null;
    row._removeToken = null;
    row._undoToken = MultiProviderUndoToken._(
      row.id,
      _sessionEpoch,
      row._generation,
      _nextNonce++,
    );
    row._finalizeToken = MultiProviderFinalizeToken._(
      row.id,
      _sessionEpoch,
      row._generation,
      _nextNonce++,
    );
  }

  MultiProviderAmountRow? _rowFor(_RowToken token) {
    if (token.epoch != _sessionEpoch) return null;
    for (final row in _rows) {
      if (row.id == token.rowId && row._generation == token.generation) {
        return row;
      }
    }
    return null;
  }

  void _invalidateCommit() {
    _allProvidersReviewed = false;
    _committedTotalMinorUnits = null;
  }

  void _invalidateUnresolvedOrigin(MultiProviderAmountRow row) {
    row._unresolvedOrigin = null;
  }

  void invalidateConfirmation() => _invalidateCommit();

  bool updateProviderName(MultiProviderEditToken token, String value) {
    final row = _rowFor(token);
    if (row == null || !identical(row._editToken, token) || !row.isActive) {
      return false;
    }
    _invalidateUnresolvedOrigin(row);
    if (row._classification ==
        MultiProviderAmountClassification.confirmedOrdinary) {
      row._classification = MultiProviderAmountClassification.unreviewed;
    }
    row._providerName = value;
    _invalidateCommit();
    return true;
  }

  bool updateAmount(
    MultiProviderEditToken token,
    String value, {
    required String locale,
  }) {
    final row = _rowFor(token);
    if (row == null || !identical(row._editToken, token) || !row.isActive) {
      return false;
    }
    _invalidateUnresolvedOrigin(row);
    row._classification = MultiProviderAmountClassification.unreviewed;
    row._rawAmount = value;
    try {
      row._amountMinorUnits = parseOrdinaryChfAmount(value, locale: locale);
      row._amountInvalid = false;
    } on FormatException {
      row._amountMinorUnits = null;
      row._amountInvalid = true;
    }
    _invalidateCommit();
    return true;
  }

  MultiProviderUnresolvedOrigin? markAmountUnresolved(
    MultiProviderEditToken token,
  ) {
    final row = _rowFor(token);
    if (row == null ||
        !identical(row._editToken, token) ||
        !row.isActive ||
        !row.hasPositiveExactAmount) {
      return null;
    }
    _invalidateUnresolvedOrigin(row);
    final origin = MultiProviderUnresolvedOrigin._(
      row.id,
      MultiProviderUnresolvedResolveToken._(
        row.id,
        _sessionEpoch,
        row._generation,
        _nextNonce++,
      ),
      MultiProviderUnresolvedRefundToken._(
        row.id,
        _sessionEpoch,
        row._generation,
        _nextNonce++,
      ),
      MultiProviderUnresolvedAllZeroToken._(
        row.id,
        _sessionEpoch,
        row._generation,
        _nextNonce++,
      ),
      row._removeToken!,
    );
    row
      .._classification = MultiProviderAmountClassification.unresolved
      .._unresolvedOrigin = origin;
    _invalidateCommit();
    return origin;
  }

  MultiProviderUnresolvedActionResult resolveProviderReportedTotal(
    MultiProviderUnresolvedResolveToken token,
  ) {
    final row = _rowFor(token);
    if (row == null ||
        !row.isActive ||
        row._classification != MultiProviderAmountClassification.unresolved ||
        !identical(row._unresolvedOrigin?.resolveToken, token)) {
      return MultiProviderUnresolvedActionResult.stale;
    }
    _invalidateUnresolvedOrigin(row);
    row._classification = MultiProviderAmountClassification.unreviewed;
    _invalidateCommit();
    return MultiProviderUnresolvedActionResult.resolvedToUnreviewed;
  }

  MultiProviderUnresolvedRefundResult refundFullyProvider(
    MultiProviderUnresolvedRefundToken token,
  ) {
    final row = _rowFor(token);
    final origin = row?._unresolvedOrigin;
    if (row == null ||
        !row.isActive ||
        row._classification != MultiProviderAmountClassification.unresolved ||
        origin == null ||
        !identical(origin.refundToken, token)) {
      return MultiProviderUnresolvedRefundResult.stale;
    }
    final anotherPositiveProvider = _activeRows.any(
      (candidate) =>
          !identical(candidate, row) && candidate.hasPositiveExactAmount,
    );
    if (!row.hasPositiveExactAmount ||
        !anotherPositiveProvider ||
        !identical(row._removeToken, origin._capturedRemoveToken)) {
      return MultiProviderUnresolvedRefundResult.ineligible;
    }

    _invalidateUnresolvedOrigin(row);
    final result = removeProvider(origin._capturedRemoveToken);
    if (result != MultiProviderRemoveResult.tombstoned) {
      throw StateError('validated unresolved refund must tombstone exact row');
    }
    return MultiProviderUnresolvedRefundResult.tombstoned;
  }

  MultiProviderAllZeroCorrectionResult beginAllProvidersZeroCorrection(
    MultiProviderUnresolvedAllZeroToken token,
  ) {
    final row = _rowFor(token);
    if (row == null ||
        !row.isActive ||
        row._classification != MultiProviderAmountClassification.unresolved ||
        !identical(row._unresolvedOrigin?.allZeroToken, token)) {
      return MultiProviderAllZeroCorrectionResult.stale;
    }
    _invalidateCommit();
    return MultiProviderAllZeroCorrectionResult.ready;
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

  MultiProviderRemoveResult removeProvider(MultiProviderRemoveToken token) {
    final row = _rowFor(token);
    if (row == null || !identical(row._removeToken, token) || !row.isActive) {
      return MultiProviderRemoveResult.stale;
    }
    if (activeRowCount <= 1) return MultiProviderRemoveResult.minimumActive;
    _invalidateUnresolvedOrigin(row);
    _invalidateCommit();
    if (row.isCompletelyEmpty) {
      _wipe(row);
      _rows.remove(row);
      return MultiProviderRemoveResult.removedEmpty;
    }
    row._lifecycle = MultiProviderRowLifecycle.tombstone;
    row._generation++;
    _issueTombstoneTokens(row);
    return MultiProviderRemoveResult.tombstoned;
  }

  MultiProviderUndoResult undoRemoval(MultiProviderUndoToken token) {
    final row = _rowFor(token);
    if (row == null || !identical(row._undoToken, token) || row.isActive) {
      return MultiProviderUndoResult.stale;
    }
    row._lifecycle = MultiProviderRowLifecycle.active;
    row._generation++;
    _issueActiveTokens(row);
    _invalidateCommit();
    return MultiProviderUndoResult.restored;
  }

  MultiProviderFinalizeResult finalizeRemoval(
    MultiProviderFinalizeToken token,
  ) {
    final row = _rowFor(token);
    if (row == null || !identical(row._finalizeToken, token) || row.isActive) {
      return MultiProviderFinalizeResult.stale;
    }
    _wipe(row);
    _rows.remove(row);
    _invalidateCommit();
    return MultiProviderFinalizeResult.finalized;
  }

  void _wipe(MultiProviderAmountRow row) {
    row._providerName = '';
    row._rawAmount = '';
    row._amountMinorUnits = null;
    row._amountInvalid = false;
    row._classification = MultiProviderAmountClassification.unreviewed;
    row._unresolvedOrigin = null;
    row._editToken = null;
    row._removeToken = null;
    row._undoToken = null;
    row._finalizeToken = null;
    row._generation++;
  }

  Iterable<MultiProviderAmountRow> get _activeRows =>
      _rows.where((row) => row.isActive);

  Set<String> get duplicateRowIds {
    final rowsByKey = <String, List<String>>{};
    for (final row in _activeRows) {
      if (!row.hasSafeProviderName) continue;
      rowsByKey
          .putIfAbsent(normalizeMultiProviderLabel(row.providerName), () => [])
          .add(row.id);
    }
    return {
      for (final ids in rowsByKey.values)
        if (ids.length > 1) ...ids,
    };
  }

  Set<String> get laterDuplicateRowIds {
    final firstRowByKey = <String, String>{};
    final later = <String>{};
    for (final row in _activeRows) {
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
    for (final row in _activeRows) {
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
    for (final row in _activeRows) {
      final amount = row.amountMinorUnits;
      if (amount != null && amount > 0) subtotal += amount;
    }
    return subtotal == 0 ? null : subtotal;
  }

  bool get canConfirmAllProvidersReviewed =>
      !hasTombstones &&
      _activeRows.isNotEmpty &&
      _activeRows.every(
        (row) =>
            row.hasSafeProviderName &&
            row.hasPositiveExactAmount &&
            row.classification != MultiProviderAmountClassification.unresolved,
      ) &&
      duplicateRowIds.isEmpty &&
      !aggregateOverflow;

  bool setAllProvidersReviewed(bool value) {
    if (!value) {
      for (final row in _activeRows) {
        _invalidateUnresolvedOrigin(row);
        row._classification = MultiProviderAmountClassification.unreviewed;
      }
      _invalidateCommit();
      return true;
    }
    if (!canConfirmAllProvidersReviewed) return false;
    for (final row in _activeRows) {
      _invalidateUnresolvedOrigin(row);
      row._classification = MultiProviderAmountClassification.confirmedOrdinary;
    }
    _allProvidersReviewed = true;
    _committedTotalMinorUnits = null;
    return true;
  }

  int? commit() {
    if (!_allProvidersReviewed || !canConfirmAllProvidersReviewed) return null;
    if (_activeRows.any(
      (row) =>
          row.classification !=
          MultiProviderAmountClassification.confirmedOrdinary,
    )) {
      return null;
    }
    final subtotal = provisionalSubtotalMinorUnits;
    if (subtotal == null) return null;
    return _committedTotalMinorUnits = subtotal;
  }

  void purge() {
    _sessionEpoch++;
    for (final row in _rows) {
      _wipe(row);
    }
    _rows
      ..clear()
      ..add(_newRow());
    _invalidateCommit();
  }
}
