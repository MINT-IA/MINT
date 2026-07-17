import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/document_service.dart';
import 'package:mint_mobile/services/session_epoch.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

typedef SharedPreferencesLoader = Future<SharedPreferences> Function();

/// Opaque, raw-free link from a confirmed document to its strict ledger
/// snapshot.
final class ConfirmedDocumentReference {
  const ConfirmedDocumentReference({
    required this.referenceId,
    required this.kind,
    required this.snapshotId,
    required this.ownerKind,
    required this.confirmedAt,
  });

  static const lppKind = 'lpp';

  final String referenceId;
  final String kind;
  final String snapshotId;
  final LppEvidenceOwnerKind ownerKind;
  final DateTime confirmedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'referenceId': referenceId,
      'kind': kind,
      'snapshotId': snapshotId,
      'ownerKind': ownerKind.wireName,
      'confirmedAt': confirmedAt.toUtc().toIso8601String(),
    };
  }

  static ConfirmedDocumentReference? fromJson(Map<String, dynamic> json) {
    const allowedKeys = <String>{
      'referenceId',
      'kind',
      'snapshotId',
      'ownerKind',
      'confirmedAt',
    };
    if (json.length != allowedKeys.length ||
        json.keys.toSet().difference(allowedKeys).isNotEmpty ||
        json['referenceId'] is! String ||
        json['snapshotId'] is! String ||
        json['kind'] != lppKind) {
      return null;
    }
    final ownerKind = LppEvidenceOwnerKind.fromWireName(json['ownerKind']);
    final confirmedAt = _parseCanonicalUtcInstant(json['confirmedAt']);
    if (ownerKind == null ||
        confirmedAt == null ||
        !_isCanonicalUuidV4(json['referenceId'] as String) ||
        !_isCanonicalUuidV4(json['snapshotId'] as String)) {
      return null;
    }
    return ConfirmedDocumentReference(
      referenceId: json['referenceId'] as String,
      kind: lppKind,
      snapshotId: json['snapshotId'] as String,
      ownerKind: ownerKind,
      confirmedAt: confirmedAt,
    );
  }
}

/// Strict local persistence for opaque confirmed-document references.
///
/// This store intentionally does not read or migrate `_uploaded_documents`.
/// A malformed root or item is rejected as a whole so no partial set can be
/// mistaken for current ledger truth.
class DocumentReferenceStore {
  DocumentReferenceStore({SharedPreferencesLoader? preferencesLoader})
      : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const storageKey = '_confirmed_document_references_v1';
  static const schemaVersion = 1;

  final SharedPreferencesLoader _preferencesLoader;

  Future<List<ConfirmedDocumentReference>> load() async {
    final preferences = await _preferencesLoader();
    final encoded = preferences.getString(storageKey);
    if (encoded == null) return const [];

    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on Object catch (error) {
      throw FormatException('Malformed document reference root', error);
    }
    if (decoded is! Map) {
      throw const FormatException('Document reference root must be an object');
    }
    final root = Map<String, dynamic>.from(decoded);
    const allowedRootKeys = <String>{'schemaVersion', 'references'};
    if (root.length != allowedRootKeys.length ||
        root.keys.toSet().difference(allowedRootKeys).isNotEmpty ||
        root['schemaVersion'] != schemaVersion ||
        root['references'] is! List) {
      throw const FormatException('Invalid document reference root');
    }

    final references = <ConfirmedDocumentReference>[];
    final referenceIds = <String>{};
    final snapshotBindings = <String>{};
    for (final rawReference in root['references'] as List) {
      if (rawReference is! Map) {
        throw const FormatException('Invalid document reference item');
      }
      final reference = ConfirmedDocumentReference.fromJson(
        Map<String, dynamic>.from(rawReference),
      );
      if (reference == null || !referenceIds.add(reference.referenceId)) {
        throw const FormatException('Invalid document reference item');
      }
      final binding = '${reference.kind}|${reference.ownerKind.wireName}|'
          '${reference.snapshotId}';
      if (!snapshotBindings.add(binding)) {
        throw const FormatException('Duplicate document reference binding');
      }
      references.add(reference);
    }
    return List.unmodifiable(references);
  }

  Future<void> save(List<ConfirmedDocumentReference> references) async {
    final referenceIds = <String>{};
    final snapshotBindings = <String>{};
    for (final reference in references) {
      if (ConfirmedDocumentReference.fromJson(reference.toJson()) == null ||
          !referenceIds.add(reference.referenceId) ||
          !snapshotBindings.add(
            '${reference.kind}|${reference.ownerKind.wireName}|'
            '${reference.snapshotId}',
          )) {
        throw const FormatException('Invalid document reference set');
      }
    }
    final preferences = await _preferencesLoader();
    final persisted = await preferences.setString(
      storageKey,
      jsonEncode(<String, dynamic>{
        'schemaVersion': schemaVersion,
        'references': references
            .map((reference) => reference.toJson())
            .toList(growable: false),
      }),
    );
    if (!persisted) {
      throw StateError('Document reference persistence failed');
    }
  }
}

DateTime? _parseCanonicalUtcInstant(Object? raw) {
  if (raw is! String) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null ||
      !parsed.isUtc ||
      parsed.toUtc().toIso8601String() != raw) {
    return null;
  }
  return parsed.toUtc();
}

bool _isCanonicalUuidV4(String value) => RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    ).hasMatch(value);

enum DocumentReferenceHydrationState { idle, loading, ready, failed }

/// Manages document upload state and document list.
///
/// Uses [DocumentService] for backend calls and notifies listeners
/// on every state change (upload progress, results, errors).
class DocumentProvider extends ChangeNotifier {
  final DocumentService _service;
  final DocumentReferenceStore _referenceStore;
  final DateTime Function() _now;
  final Uuid _uuid;
  final SessionEpoch _sessionEpoch;

  List<DocumentSummary> _documents = [];
  List<ConfirmedDocumentReference> _references = const [];
  bool _isUploading = false;
  bool _isLoading = false;
  DocumentReferenceHydrationState _referenceHydrationState =
      DocumentReferenceHydrationState.idle;
  DocumentUploadResult? _lastUploadResult;
  String? _error;
  CoachProfileProvider? _ledger;
  Future<void>? _referenceHydration;
  int? _referenceHydrationGeneration;
  Future<void>? _referenceMutationTail;

  DocumentProvider({
    DocumentService? service,
    DocumentReferenceStore? referenceStore,
    DateTime Function()? now,
    Uuid? uuid,
    SessionEpoch? sessionEpoch,
  })  : _service = service ?? DocumentService(),
        _referenceStore = referenceStore ?? DocumentReferenceStore(),
        _now = now ?? DateTime.now,
        _uuid = uuid ?? const Uuid(),
        _sessionEpoch = sessionEpoch ?? SessionEpoch();

  // ──────────────────────────────────────────────────────────
  // Getters
  // ──────────────────────────────────────────────────────────

  List<DocumentSummary> get documents => _documents;
  bool get isUploading => _isUploading;
  bool get isLoading => _isLoading;
  DocumentUploadResult? get lastUploadResult => _lastUploadResult;
  String? get error => _error;
  int get documentCount => _documents.length;
  bool get referencesHydrated =>
      _referenceHydrationState == DocumentReferenceHydrationState.ready;
  DocumentReferenceHydrationState get referenceHydrationState =>
      _referenceHydrationState;
  DocumentReferenceStore get referenceStore => _referenceStore;

  List<ConfirmedDocumentReference> get currentReferences {
    final ledger = _ledger;
    if (!referencesHydrated || ledger == null || !ledger.isLoaded) {
      return const <ConfirmedDocumentReference>[];
    }
    return List<ConfirmedDocumentReference>.unmodifiable(
      _references.where(
        (reference) =>
            ledger.currentLppSnapshotId(reference.ownerKind) ==
            reference.snapshotId,
      ),
    );
  }

  /// Binds reference resolution to the canonical ledger. The provider listens
  /// for snapshot replacement so stale references disappear immediately.
  void bindLedger(CoachProfileProvider ledger) {
    if (identical(_ledger, ledger)) return;
    _ledger?.removeListener(_onLedgerChanged);
    _ledger = ledger;
    ledger.addListener(_onLedgerChanged);
  }

  void _onLedgerChanged() {
    if (_sessionEpoch.isTerminationBlocked) return;
    notifyListeners();
  }

  Future<void> hydrateReferences() {
    if (referencesHydrated) return Future.value();
    final generation = _sessionEpoch.generation;
    final pending = _referenceHydration;
    if (pending != null && _referenceHydrationGeneration == generation) {
      return pending;
    }
    late final SessionEpochGuard guard;
    try {
      guard = _sessionEpoch.capture();
    } on SessionEpochInvalidated {
      return Future.value();
    }
    final hydration = _hydrateReferences(guard);
    _referenceHydration = hydration;
    _referenceHydrationGeneration = generation;
    return hydration.whenComplete(() {
      if (identical(_referenceHydration, hydration)) {
        _referenceHydration = null;
        _referenceHydrationGeneration = null;
      }
    });
  }

  Future<void> _hydrateReferences(SessionEpochGuard guard) async {
    guard.assertCurrent();
    _referenceHydrationState = DocumentReferenceHydrationState.loading;
    notifyListeners();
    try {
      final loaded = await _referenceStore.load();
      guard.assertCurrent();
      _references = loaded;
      _referenceHydrationState = DocumentReferenceHydrationState.ready;
      notifyListeners();
    } on SessionEpochInvalidated {
      return;
    } on Object {
      guard.assertCurrent();
      _referenceHydrationState = DocumentReferenceHydrationState.failed;
      notifyListeners();
      rethrow;
    }
  }

  /// Resolves a reference only when both persistence and the strict ledger are
  /// hydrated and still point at the same person-owned snapshot.
  ConfirmedDocumentReference? byId(String referenceId) {
    final ledger = _ledger;
    if (!referencesHydrated || ledger == null || !ledger.isLoaded) return null;
    ConfirmedDocumentReference? reference;
    for (final candidate in _references) {
      if (candidate.referenceId == referenceId) {
        reference = candidate;
        break;
      }
    }
    if (reference == null ||
        ledger.currentLppSnapshotId(reference.ownerKind) !=
            reference.snapshotId) {
      return null;
    }
    return reference;
  }

  bool hasStoredReference(String referenceId) =>
      referencesHydrated &&
      _references.any((reference) => reference.referenceId == referenceId);

  Future<ConfirmedDocumentReference> recordConfirmedLppReview(
    LppReviewReceipt receipt,
  ) {
    final guard = _sessionEpoch.capture();
    return _serializeReferenceMutation(() async {
      guard.assertCurrent();
      final ledger = _ledger;
      if (ledger == null || !ledger.isLoaded) {
        throw StateError('Document reference ledger is unavailable');
      }
      if (!ledger.matchesAcceptedLppReceipt(receipt)) {
        throw StateError('LPP receipt does not match the current ledger');
      }
      await hydrateReferences();
      guard.assertCurrent();
      for (final reference in _references) {
        if (reference.kind == ConfirmedDocumentReference.lppKind &&
            reference.ownerKind == receipt.ownerKind &&
            reference.snapshotId == receipt.snapshotId) {
          return reference;
        }
      }
      final reference = ConfirmedDocumentReference(
        referenceId: _uuid.v4(),
        kind: ConfirmedDocumentReference.lppKind,
        snapshotId: receipt.snapshotId,
        ownerKind: receipt.ownerKind,
        confirmedAt: _now().toUtc(),
      );
      final nextReferences = List<ConfirmedDocumentReference>.unmodifiable(
        <ConfirmedDocumentReference>[..._references, reference],
      );
      await _sessionEpoch.runGuardedPersistence(
        guard,
        () => _referenceStore.save(nextReferences),
      );
      guard.assertCurrent();
      _references = nextReferences;
      notifyListeners();
      return reference;
    });
  }

  Future<void> deleteConfirmedReference(String referenceId) {
    final guard = _sessionEpoch.capture();
    return _serializeReferenceMutation(() async {
      await hydrateReferences();
      guard.assertCurrent();
      final nextReferences = _references
          .where((reference) => reference.referenceId != referenceId)
          .toList(growable: false);
      if (nextReferences.length == _references.length) return;
      await _sessionEpoch.runGuardedPersistence(
        guard,
        () => _referenceStore.save(nextReferences),
      );
      guard.assertCurrent();
      _references = List.unmodifiable(nextReferences);
      notifyListeners();
    });
  }

  Future<T> _serializeReferenceMutation<T>(
    Future<T> Function() operation,
  ) async {
    final previousMutation = _referenceMutationTail;
    final completion = Completer<void>();
    final currentMutation = completion.future;
    _referenceMutationTail = currentMutation;
    if (previousMutation != null) await previousMutation;
    try {
      return await operation();
    } finally {
      completion.complete();
      if (identical(_referenceMutationTail, currentMutation)) {
        _referenceMutationTail = null;
      }
    }
  }

  /// Returns documents filtered by [type].
  List<DocumentSummary> documentsOfType(VaultDocumentType type) =>
      _documents.where((d) => d.documentType == type).toList();

  /// Returns the count of documents matching [type].
  int countOfType(VaultDocumentType type) =>
      _documents.where((d) => d.documentType == type).length;

  // ──────────────────────────────────────────────────────────
  // Upload
  // ──────────────────────────────────────────────────────────

  /// Upload a document from the given file path.
  ///
  /// [type] specifies the kind of document being uploaded. Defaults to
  /// [VaultDocumentType.lppCertificate] for backward compatibility.
  /// Sets [isUploading] to true during the upload.
  /// On success, sets [lastUploadResult] and refreshes the document list.
  /// On failure, sets [error].
  Future<void> uploadDocument(
    String filePath, {
    VaultDocumentType type = VaultDocumentType.lppCertificate,
  }) async {
    final guard = _sessionEpoch.capture();
    _isUploading = true;
    _error = null;
    _lastUploadResult = null;
    notifyListeners();

    try {
      final file = File(filePath);
      final result = await _service.uploadDocument(file, type: type);
      guard.assertCurrent();
      _lastUploadResult = result;
      // Refresh documents list after upload
      await _loadDocumentsSilently(guard);
    } on SessionEpochInvalidated {
      return;
    } on DocumentServiceException catch (e) {
      guard.assertCurrent();
      _error = e.message;
      if (kDebugMode) {
        debugPrint('DocumentProvider: Upload error: ${e.message}');
      }
    } catch (e) {
      guard.assertCurrent();
      _error = 'Une erreur est survenue lors de l\'upload.';
      if (kDebugMode) {
        debugPrint('DocumentProvider: Unexpected upload error: $e');
      }
    } finally {
      try {
        guard.assertCurrent();
        _isUploading = false;
        notifyListeners();
      } on SessionEpochInvalidated {
        // Session termination owns the cleared state.
      }
    }
  }

  // ──────────────────────────────────────────────────────────
  // List
  // ──────────────────────────────────────────────────────────

  /// Load the list of uploaded documents from the backend.
  Future<void> loadDocuments() async {
    final guard = _sessionEpoch.capture();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final documents = await _service.listDocuments();
      guard.assertCurrent();
      _documents = documents;
    } on SessionEpochInvalidated {
      return;
    } on DocumentServiceException catch (e) {
      guard.assertCurrent();
      _error = e.message;
      if (kDebugMode) {
        debugPrint('DocumentProvider: Load error: ${e.message}');
      }
    } catch (e) {
      guard.assertCurrent();
      _error = 'Impossible de charger les documents.';
      if (kDebugMode) {
        debugPrint('DocumentProvider: Unexpected load error: $e');
      }
    } finally {
      try {
        guard.assertCurrent();
        _isLoading = false;
        notifyListeners();
      } on SessionEpochInvalidated {
        // Session termination owns the cleared state.
      }
    }
  }

  /// Internal silent load (no loading indicator) after upload.
  Future<void> _loadDocumentsSilently(SessionEpochGuard guard) async {
    try {
      final documents = await _service.listDocuments();
      guard.assertCurrent();
      _documents = documents;
    } on SessionEpochInvalidated {
      return;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DocumentProvider: Silent load error: $e');
      }
    }
  }

  // ──────────────────────────────────────────────────────────
  // Delete
  // ──────────────────────────────────────────────────────────

  /// Delete a document by ID and refresh the list.
  Future<bool> deleteDocument(String id) async {
    final guard = _sessionEpoch.capture();
    _error = null;
    notifyListeners();

    try {
      final success = await _service.deleteDocument(id);
      guard.assertCurrent();
      if (success) {
        _documents.removeWhere((d) => d.id == id);
        // If we just deleted the document from the last upload result, clear it
        if (_lastUploadResult?.id == id) {
          _lastUploadResult = null;
        }
        notifyListeners();
        return true;
      }
      return false;
    } on DocumentServiceException catch (e) {
      guard.assertCurrent();
      _error = e.message;
      if (kDebugMode) {
        debugPrint('DocumentProvider: Delete error: ${e.message}');
      }
      notifyListeners();
      return false;
    } catch (e) {
      guard.assertCurrent();
      _error = 'Impossible de supprimer le document.';
      if (kDebugMode) {
        debugPrint('DocumentProvider: Unexpected delete error: $e');
      }
      notifyListeners();
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────
  // Error
  // ──────────────────────────────────────────────────────────

  /// Clear the current error.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clear the last upload result (e.g. after confirming profile update).
  void clearLastResult() {
    _lastUploadResult = null;
    notifyListeners();
  }

  /// Clears local in-memory state only (does not delete backend documents).
  void clearLocalState() {
    _documents = [];
    _isUploading = false;
    _isLoading = false;
    _lastUploadResult = null;
    _error = null;
    _references = const [];
    _referenceHydrationState = DocumentReferenceHydrationState.idle;
    _referenceHydration = null;
    _referenceHydrationGeneration = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ledger?.removeListener(_onLedgerChanged);
    super.dispose();
  }
}
