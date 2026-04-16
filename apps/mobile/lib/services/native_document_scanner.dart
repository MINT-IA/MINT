// Phase 28-03 — Native document scanner wrapper.
//
// iOS: Apple VisionKit `VNDocumentCameraViewController` (iOS 13+, WWDC 2019).
//      Auto-crop + deskew + shadow removal applied live in the camera preview.
// Android: Google ML Kit Document Scanner (GA 2024). Same client-side
//      crop + deskew + shadow removal, multi-page native, gratis, offline.
//
// Web/desktop: not supported. Callers must check `isAvailable` and fall back
// to a file picker (existing `_onGalleryPressed` flow in document_scan_screen).
//
// Wraps `flutter_doc_scanner` (2025 package that exposes both native SDKs
// behind a single Dart API). If a future blocker forces a custom MethodChannel
// implementation, this service is the only consumer to update.

import 'dart:io' show File, Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';

/// Result of a single scan invocation. Each entry is one processed page
/// (already cropped/deskewed/shadow-removed by the OS), encoded as JPEG bytes.
typedef ScannedPages = List<Uint8List>;

class DocumentScannerException implements Exception {
  final String code;
  final String? message;

  const DocumentScannerException(this.code, [this.message]);

  @override
  String toString() =>
      'DocumentScannerException($code${message != null ? ', $message' : ''})';
}

class NativeDocumentScanner {
  // Sentinel string returned by the platform channel when the user cancels
  // the scanner UI without producing any page.
  static const _cancelledMarker = 'CANCELLED';

  /// Returns `true` when the host platform exposes a native document scanner.
  /// Web, macOS, Windows and Linux callers must use the file-picker fallback.
  static bool get isAvailable {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS || Platform.isAndroid;
    } on UnsupportedError {
      // Defensive: `Platform` access can throw on unsupported targets.
      return false;
    }
  }

  /// Launches the OS document scanner and returns the captured pages as
  /// JPEG bytes. Returns `null` when the user cancels or no page was captured.
  ///
  /// Throws [DocumentScannerException] when the platform reports an error
  /// (permissions denied, ML Kit module unavailable, etc.).
  static Future<ScannedPages?> scan({int maxPages = 5}) async {
    if (!isAvailable) {
      // Caller responsibility to fall back to file picker.
      return null;
    }

    try {
      final dynamic raw =
          await FlutterDocScanner().getScannedDocumentAsImages(page: maxPages);

      final paths = _normalizeToPaths(raw);
      if (paths.isEmpty) return null;

      final pages = <Uint8List>[];
      for (final path in paths) {
        final bytes = await _readBytes(path);
        if (bytes != null && bytes.isNotEmpty) {
          pages.add(bytes);
        }
      }
      return pages.isEmpty ? null : pages;
    } on PlatformException catch (e) {
      // Cancellation is not an error condition.
      if (e.code == _cancelledMarker || e.message?.contains('cancelled') == true) {
        return null;
      }
      throw DocumentScannerException(e.code, e.message);
    } catch (e) {
      throw DocumentScannerException('scan_failed', e.toString());
    }
  }

  // Plugin returns one of:
  //   - String path
  //   - List<String> paths
  //   - Map with key 'pageImages' or 'Uri' (iOS variants)
  // Normalize all shapes to a list of file paths.
  static List<String> _normalizeToPaths(dynamic raw) {
    if (raw == null) return const [];
    if (raw is String) {
      return raw.isEmpty ? const [] : [raw];
    }
    if (raw is List) {
      return raw
          .map((e) => e?.toString() ?? '')
          .where((p) => p.isNotEmpty)
          .toList(growable: false);
    }
    if (raw is Map) {
      // Common shapes from the plugin across platforms.
      final candidates = [
        raw['pageImages'],
        raw['Uri'],
        raw['pdfUri'],
        raw['scannedImages'],
      ];
      for (final c in candidates) {
        if (c is List) {
          return c
              .map((e) => e?.toString() ?? '')
              .where((p) => p.isNotEmpty)
              .toList(growable: false);
        }
        if (c is String && c.isNotEmpty) {
          return [c];
        }
      }
    }
    return const [];
  }

  static Future<Uint8List?> _readBytes(String path) async {
    try {
      final cleaned = path.startsWith('file://')
          ? Uri.parse(path).toFilePath()
          : path;
      final file = File(cleaned);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }
}
