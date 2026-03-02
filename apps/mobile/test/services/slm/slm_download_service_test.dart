import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/slm/slm_download_service.dart';

// ────────────────────────────────────────────────────────────
//  SLM DOWNLOAD SERVICE TESTS
// ────────────────────────────────────────────────────────────
//
// Tests cover (unit-level, no native runtime):
//   1. DownloadState enum values
//   2. ModelInfo construction and fields
//   3. modelId derived from URL (not hardcoded)
//   4. modelId ends with .task extension
//   5. modelSizeFormatted returns human-readable Go
//   6. estimatedDownloadMinutes returns positive value
//   7. Initial state is notStarted
//   8. Initial progress is 0.0
//   9. cancelDownload is no-op when not downloading
//  10. DownloadProgressCallback typedef accepts correct signature
//  11. ModelInfo.isReady defaults correctly
//  12. modelSizeFormatted is consistent across calls
// ────────────────────────────────────────────────────────────

void main() {
  group('SlmDownloadService — unit tests (no native runtime)', () {
    test('1. DownloadState enum has all expected values', () {
      expect(
          DownloadState.values,
          containsAll([
            DownloadState.notStarted,
            DownloadState.downloading,
            DownloadState.paused,
            DownloadState.completed,
            DownloadState.failed,
          ]));
      expect(DownloadState.values.length, 5);
    });

    test('2. ModelInfo construction and fields', () {
      const info = ModelInfo(
        modelId: 'test-model.task',
        displayName: 'Test Model',
        sizeBytes: 1000000,
        version: '1.0.0',
        isReady: true,
        localPath: '/path/to/model',
      );
      expect(info.modelId, 'test-model.task');
      expect(info.displayName, 'Test Model');
      expect(info.sizeBytes, 1000000);
      expect(info.version, '1.0.0');
      expect(info.isReady, isTrue);
      expect(info.localPath, '/path/to/model');
    });

    test('3. modelId is derived from URL (contains gemma)', () {
      // modelId is derived via Uri.parse(url).pathSegments.last
      // so it must contain the model filename pattern.
      expect(SlmDownloadService.modelId, contains('gemma'));
    });

    test('4. modelId ends with .task extension', () {
      expect(SlmDownloadService.modelId, endsWith('.task'));
    });

    test('5. modelSizeFormatted returns human-readable Go', () {
      final formatted = SlmDownloadService.modelSizeFormatted;
      expect(formatted, contains('Go'));
      // ~2.3 GB → "2.2 Go" (binary)
      expect(formatted, matches(RegExp(r'\d+\.\d+ Go')));
    });

    test('6. estimatedDownloadMinutes returns positive value', () {
      final minutes = SlmDownloadService.estimatedDownloadMinutes();
      expect(minutes, greaterThan(0));
      // 2.4 GB at 50 Mbps → ~6.4 min → ceil = 7
      expect(minutes, lessThan(15));
    });

    test('7. singleton initial state is notStarted', () {
      final service = SlmDownloadService.instance;
      expect(service.state, equals(DownloadState.notStarted));
    });

    test('8. singleton initial progress is 0.0', () {
      final service = SlmDownloadService.instance;
      expect(service.progress, equals(0.0));
    });

    test('9. cancelDownload is no-op when not downloading', () {
      final service = SlmDownloadService.instance;
      // Should not throw — silent no-op when state != downloading.
      expect(() => service.cancelDownload(), returnsNormally);
      expect(service.state, equals(DownloadState.notStarted));
    });

    test('10. DownloadProgressCallback signature', () {
      // Verify the typedef accepts correct signature.
      DownloadProgressCallback callback = (progress, downloaded, total) {};
      callback(0.5, 1200000000, 2400000000);
      // No assertion needed — if it compiles and runs, the typedef is correct.
      expect(callback, isNotNull);
    });

    test('11. ModelInfo without localPath defaults to null', () {
      const info = ModelInfo(
        modelId: 'test.task',
        displayName: 'Test',
        sizeBytes: 100,
        version: '0.1',
        isReady: false,
      );
      expect(info.localPath, isNull);
      expect(info.isReady, isFalse);
    });

    test('12. modelSizeFormatted is consistent across calls', () {
      final a = SlmDownloadService.modelSizeFormatted;
      final b = SlmDownloadService.modelSizeFormatted;
      expect(a, equals(b));
    });

    test('13. expectedSizeBytes matches modelSizeFormatted', () {
      final bytes = SlmDownloadService.expectedSizeBytes;
      expect(bytes, greaterThan(2000000000)); // > 2 GB
      expect(bytes, lessThan(3000000000)); // < 3 GB
      final gb = bytes / (1024 * 1024 * 1024);
      expect(SlmDownloadService.modelSizeFormatted,
          '${gb.toStringAsFixed(1)} Go');
    });

    test('14. lastError is null initially', () {
      final service = SlmDownloadService.instance;
      expect(service.lastError, isNull);
    });
  });
}
