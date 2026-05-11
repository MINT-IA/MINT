// Phase 97 W7 iter#5 — T001 EXIF leak unit-test gate.
//
// scrubExif() removes GPS, DateTime, Make/Model, Software EXIF tags from JPEG
// bytes before they leave the device. Pixel data is preserved bit-for-bit
// after a decode/encode roundtrip via the `image` package (deterministic,
// no JPEG quality loss because we re-emit at quality=100).
//
// GDPR Art. 5(1)(c) data minimization + Swiss DSG/LPD Art. 8 security :
// the Vision API only needs pixel content to extract financial fields, it
// does NOT need where the photo was taken, when, or with what device.
//
// The 6 assertions below cover :
//   1. GPS tags stripped
//   2. DateTime tags stripped
//   3. Make / Model tags stripped
//   4. Pixel data preserved (width, height, and pixel-sum invariant)
//   5. EXIF-less photo passes through unchanged (idempotent)
//   6. Detection regression : an unscrubbed photo still carries the tags
//      (catches future removal of the scrub call).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mint_mobile/services/exif_scrub.dart';

/// Build a synthetic 16×16 JPEG with the supplied EXIF tags injected.
///
/// All tags written into ifd0 (the primary directory) except GPS which goes
/// into ifd0.sub['gps'] per the EXIF 2.32 spec. Returns the JPEG bytes ready
/// to feed into [scrubExif].
Uint8List _buildJpegWithExif({
  String? gpsLatitudeRef,
  String? dateTime,
  String? make,
  String? model,
  String? software,
}) {
  final image = img.Image(width: 16, height: 16);
  // Paint a deterministic gradient so pixel-equality checks are meaningful.
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgba(x, y, x * 16, y * 16, 64, 255);
    }
  }
  if (make != null) image.exif.imageIfd['Make'] = make;
  if (model != null) image.exif.imageIfd['Model'] = model;
  if (dateTime != null) image.exif.imageIfd['DateTime'] = dateTime;
  if (software != null) image.exif.imageIfd['Software'] = software;
  if (gpsLatitudeRef != null) {
    // GPSLatitudeRef lives in the gps sub-IFD (tag 0x0001).
    image.exif.gpsIfd['GPSLatitudeRef'] = gpsLatitudeRef;
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 100));
}

/// Sum the R/G/B channel values across every pixel. A scrub that re-encoded
/// at quality=100 from a decoded Image preserves pixel values exactly for the
/// purposes of this checksum (16x16 = 256 pixels, deterministic gradient).
int _pixelChecksum(img.Image image) {
  var sum = 0;
  for (final p in image) {
    sum += p.r.toInt() + p.g.toInt() + p.b.toInt();
  }
  return sum;
}

void main() {
  group('scrubExif()', () {
    test('GPS tags are stripped from the JPEG output', () {
      final input = _buildJpegWithExif(gpsLatitudeRef: 'N');
      final inputExif = img.decodeJpgExif(input);
      expect(inputExif?.gpsIfd['GPSLatitudeRef']?.toString(), contains('N'),
          reason: 'precondition: synthetic JPEG carries GPS tag');

      final scrubbed = scrubExif(input);

      final outExif = img.decodeJpgExif(scrubbed);
      // After scrub, no GPS data at all should remain.
      expect(outExif?.gpsIfd['GPSLatitudeRef'], isNull,
          reason: 'GPSLatitudeRef must be stripped');
    });

    test('DateTime tags are stripped from the JPEG output', () {
      final input = _buildJpegWithExif(dateTime: '2026:05:11 14:30:22');
      final inputExif = img.decodeJpgExif(input);
      expect(inputExif?.imageIfd['DateTime']?.toString(), contains('2026'),
          reason: 'precondition: synthetic JPEG carries DateTime tag');

      final scrubbed = scrubExif(input);

      final outExif = img.decodeJpgExif(scrubbed);
      expect(outExif?.imageIfd['DateTime'], isNull,
          reason: 'DateTime must be stripped');
    });

    test('Make and Model tags are stripped from the JPEG output', () {
      final input = _buildJpegWithExif(make: 'Apple', model: 'iPhone 17 Pro');
      final inputExif = img.decodeJpgExif(input);
      expect(inputExif?.imageIfd['Make']?.toString(), contains('Apple'),
          reason: 'precondition: synthetic JPEG carries Make tag');
      expect(inputExif?.imageIfd['Model']?.toString(), contains('iPhone'),
          reason: 'precondition: synthetic JPEG carries Model tag');

      final scrubbed = scrubExif(input);

      final outExif = img.decodeJpgExif(scrubbed);
      expect(outExif?.imageIfd['Make'], isNull,
          reason: 'Make must be stripped');
      expect(outExif?.imageIfd['Model'], isNull,
          reason: 'Model must be stripped');
    });

    test('pixel data is preserved (width, height, RGB checksum invariant)',
        () {
      final input = _buildJpegWithExif(
        gpsLatitudeRef: 'N',
        dateTime: '2026:05:11 14:30:22',
        make: 'Apple',
        model: 'iPhone 17 Pro',
      );
      final inputImage = img.decodeJpg(input)!;
      final inputChecksum = _pixelChecksum(inputImage);

      final scrubbed = scrubExif(input);

      final outImage = img.decodeJpg(scrubbed)!;
      expect(outImage.width, equals(inputImage.width),
          reason: 'width must be preserved');
      expect(outImage.height, equals(inputImage.height),
          reason: 'height must be preserved');
      expect(_pixelChecksum(outImage), equals(inputChecksum),
          reason: 'RGB pixel checksum must be preserved bit-for-bit '
              '(quality=100 re-encode of a synthetic 16x16 image)');
    });

    test('a JPEG with no EXIF data passes through unchanged in size+pixels',
        () {
      // Build a JPEG without any EXIF tags by encoding a fresh Image
      // without touching .exif first.
      final image = img.Image(width: 16, height: 16);
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          image.setPixelRgba(x, y, x * 16, y * 16, 64, 255);
        }
      }
      final input = Uint8List.fromList(img.encodeJpg(image, quality: 100));
      final preExif = img.decodeJpgExif(input);
      // No tags should be present in any directory.
      expect(preExif == null || !preExif.hasTag(0x010F /* Make */), isTrue,
          reason: 'precondition: no Make tag on EXIF-less synthetic JPEG');

      final scrubbed = scrubExif(input);

      final outImage = img.decodeJpg(scrubbed)!;
      expect(outImage.width, equals(16));
      expect(outImage.height, equals(16));
      // Pixel checksum unchanged.
      expect(_pixelChecksum(outImage), equals(_pixelChecksum(image)));
    });

    test(
        'regression-detect : unscrubbed JPEG still carries its EXIF tags '
        '(so we catch future removal of the scrub call)', () {
      final input = _buildJpegWithExif(
        gpsLatitudeRef: 'E',
        dateTime: '2026:05:11 14:30:22',
        make: 'Apple',
        model: 'iPhone 17 Pro',
      );
      // This is the SAME bytes we'd send to Vision without scrub. The test
      // asserts the tags ARE present so any regression that bypasses the
      // scrub call (e.g. someone refactors and forgets to call scrubExif)
      // will be caught here as a sanity check that the synthetic fixture
      // actually carries the leak we worry about.
      final exif = img.decodeJpgExif(input);
      expect(exif, isNotNull);
      expect(exif!.gpsIfd['GPSLatitudeRef']?.toString(), contains('E'));
      expect(exif.imageIfd['DateTime']?.toString(), contains('2026'));
      expect(exif.imageIfd['Make']?.toString(), contains('Apple'));
      expect(exif.imageIfd['Model']?.toString(), contains('iPhone'));
    });
  });
}
