import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/document_service.dart';

/// Manages document upload state and document list.
///
/// Uses [DocumentService] for backend calls and notifies listeners
/// on every state change (upload progress, results, errors).
class DocumentProvider extends ChangeNotifier {
  final DocumentService _service;

  List<DocumentSummary> _documents = [];
  bool _isUploading = false;
  bool _isLoading = false;
  DocumentUploadResult? _lastUploadResult;
  String? _error;

  DocumentProvider({DocumentService? service})
      : _service = service ?? DocumentService();

  // ──────────────────────────────────────────────────────────
  // Getters
  // ──────────────────────────────────────────────────────────

  List<DocumentSummary> get documents => _documents;
  bool get isUploading => _isUploading;
  bool get isLoading => _isLoading;
  DocumentUploadResult? get lastUploadResult => _lastUploadResult;
  String? get error => _error;
  int get documentCount => _documents.length;

  // ──────────────────────────────────────────────────────────
  // Upload
  // ──────────────────────────────────────────────────────────

  /// Upload a document from the given file path.
  ///
  /// Sets [isUploading] to true during the upload.
  /// On success, sets [lastUploadResult] and refreshes the document list.
  /// On failure, sets [error].
  Future<void> uploadDocument(String filePath) async {
    _isUploading = true;
    _error = null;
    _lastUploadResult = null;
    notifyListeners();

    try {
      final file = File(filePath);
      final result = await _service.uploadDocument(file);
      _lastUploadResult = result;
      // Refresh documents list after upload
      await _loadDocumentsSilently();
    } on DocumentServiceException catch (e) {
      _error = e.message;
      debugPrint('DocumentProvider: Upload error: ${e.message}');
    } catch (e) {
      _error = 'Une erreur est survenue lors de l\'upload.';
      debugPrint('DocumentProvider: Unexpected upload error: $e');
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  // ──────────────────────────────────────────────────────────
  // List
  // ──────────────────────────────────────────────────────────

  /// Load the list of uploaded documents from the backend.
  Future<void> loadDocuments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _documents = await _service.listDocuments();
    } on DocumentServiceException catch (e) {
      _error = e.message;
      debugPrint('DocumentProvider: Load error: ${e.message}');
    } catch (e) {
      _error = 'Impossible de charger les documents.';
      debugPrint('DocumentProvider: Unexpected load error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Internal silent load (no loading indicator) after upload.
  Future<void> _loadDocumentsSilently() async {
    try {
      _documents = await _service.listDocuments();
    } catch (e) {
      debugPrint('DocumentProvider: Silent load error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────
  // Delete
  // ──────────────────────────────────────────────────────────

  /// Delete a document by ID and refresh the list.
  Future<bool> deleteDocument(String id) async {
    _error = null;
    notifyListeners();

    try {
      final success = await _service.deleteDocument(id);
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
      _error = e.message;
      debugPrint('DocumentProvider: Delete error: ${e.message}');
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Impossible de supprimer le document.';
      debugPrint('DocumentProvider: Unexpected delete error: $e');
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
}
