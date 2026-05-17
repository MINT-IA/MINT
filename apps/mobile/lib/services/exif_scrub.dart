// Phase 97 W7 iter#5 — T001 EXIF leak guard.
//
// Strip GPS, DateTime, Make / Model, Software EXIF tags from JPEG bytes
// BEFORE they leave the device on the Vision API path. The Vision pipeline
// only needs pixel content to extract Swiss financial fields ; it does NOT
// need where the photo was taken, when, or with what device.
//
// Compliance citation :
//   - GDPR Art. 5(1)(c) data minimization
//   - Swiss DSG / LPD Art. 8 security of processing
//
// Strategy (Karpathy #2 simplicity-first) : use the `image` package's
// decode/encode round-trip. We DO NOT carry the source Image's `_exif`
// container into the encoder ; the freshly constructed Image we build
// from the decoded pixels has no EXIF by default. Pixel data is preserved
// because we re-emit at quality=100 from the decoded image grid.

import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:sentry_flutter/sentry_flutter.dart';

/// Strip all EXIF metadata from JPEG bytes.
///
/// Returns the original bytes unchanged if :
///   - the bytes are not a decodable JPEG (PDF / corrupt / unknown format —
///     the caller already handles PDFs separately on the Vision path)
///   - decoding throws (defensive ; the data is still routed to the backend
///     which has its own server-side validation)
///
/// On success, emits a non-PII Sentry breadcrumb with `category:
/// mint.privacy.exif_scrubbed` and aggregate payload :
///   - bytes_before : int (input length)
///   - bytes_after  : int (output length)
///   - had_exif     : bool (whether the decode found a non-empty EXIF block)
///
/// The tag values themselves are NEVER emitted (those ARE the PII we are
/// stripping in the first place).
Uint8List scrubExif(Uint8List inputBytes) {
  try {
    final hadExif = _hasNonEmptyExif(inputBytes);
    final decoded = img.decodeJpg(inputBytes);
    if (decoded == null) {
      // Not a JPEG (or corrupt) — return unchanged. Caller handles PDFs
      // separately ; the Vision path tolerates the original bytes.
      return inputBytes;
    }
    // Build a fresh Image carrying pixels only — no EXIF, no thumbnail, no
    // XMP. We copy pixel-by-pixel to guarantee no metadata bridge from the
    // source `Image` object's internal exif container.
    final clean = img.Image(
      width: decoded.width,
      height: decoded.height,
      numChannels: decoded.numChannels,
    );
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final p = decoded.getPixel(x, y);
        clean.setPixelRgba(x, y, p.r, p.g, p.b, p.a);
      }
    }
    final scrubbed = Uint8List.fromList(img.encodeJpg(clean, quality: 100));

    _emitBreadcrumb(
      bytesBefore: inputBytes.length,
      bytesAfter: scrubbed.length,
      hadExif: hadExif,
    );
    return scrubbed;
  } catch (_) {
    // Defensive — never block the upload on a scrub failure. The backend
    // has its own validation. We emit a degraded breadcrumb so operators
    // can detect a regression in this guard.
    Sentry.addBreadcrumb(Breadcrumb(
      category: 'mint.privacy.exif_scrubbed',
      level: SentryLevel.warning,
      data: const <String, dynamic>{
        'success': false,
      },
    ));
    return inputBytes;
  }
}

/// Returns true iff the JPEG carries a non-empty EXIF block (any tag in
/// any directory). Used for the breadcrumb's `had_exif` field.
bool _hasNonEmptyExif(Uint8List bytes) {
  try {
    final exif = img.decodeJpgExif(bytes);
    if (exif == null) return false;
    for (final dir in exif.directories.values) {
      if (dir.keys.isNotEmpty) return true;
      for (final sub in dir.sub.keys) {
        if (dir.sub[sub].keys.isNotEmpty) return true;
      }
    }
    return false;
  } catch (_) {
    return false;
  }
}

void _emitBreadcrumb({
  required int bytesBefore,
  required int bytesAfter,
  required bool hadExif,
}) {
  Sentry.addBreadcrumb(Breadcrumb(
    category: 'mint.privacy.exif_scrubbed',
    level: SentryLevel.info,
    data: <String, dynamic>{
      'success': true,
      'bytes_before': bytesBefore,
      'bytes_after': bytesAfter,
      'had_exif': hadExif,
    },
  ));
}
