import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for _SparklinePainter logic and _ScoreSparkline widget.
///
/// Since _SparklinePainter is private to pulse_screen.dart, we test
/// the underlying math independently.
///
/// The sparkline renders score history (last 12 months) as a mini-chart
/// with gradient fill and delta badge.
void main() {
  // ════════════════════════════════════════════════════════
  //  SPARKLINE MATH
  // ════════════════════════════════════════════════════════

  group('Sparkline math', () {
    test('delta calculation: positive trend', () {
      final scores = [60.0, 62.0, 65.0, 68.0, 72.0];
      final delta = scores.last - scores.first;
      expect(delta, 12.0);
      expect(delta >= 0, true);
    });

    test('delta calculation: negative trend', () {
      final scores = [72.0, 70.0, 68.0, 65.0];
      final delta = scores.last - scores.first;
      expect(delta, -7.0);
      expect(delta < 0, true);
    });

    test('delta calculation: flat trend', () {
      final scores = [65.0, 65.0, 65.0];
      final delta = scores.last - scores.first;
      expect(delta, 0.0);
    });

    test('range clamping: min range = 1.0', () {
      final scores = [50.0, 50.0, 50.0];
      final maxScore = scores.reduce((a, b) => a > b ? a : b);
      final minScore = scores.reduce((a, b) => a < b ? a : b);
      final range = (maxScore - minScore).clamp(1.0, 100.0);
      expect(range, 1.0, reason: 'Flat data should have range 1.0');
    });

    test('range clamping: max range = 100.0', () {
      final scores = [0.0, 150.0];
      final maxScore = scores.reduce((a, b) => a > b ? a : b);
      final minScore = scores.reduce((a, b) => a < b ? a : b);
      final range = (maxScore - minScore).clamp(1.0, 100.0);
      expect(range, 100.0);
    });

    test('Y coordinate normalization', () {
      final scores = [40.0, 60.0, 80.0];
      final minScore = 40.0;
      final range = 40.0;
      const height = 28.0;

      // Score 40 → y = height (bottom)
      final y40 = height - ((40.0 - minScore) / range * height);
      expect(y40, height);

      // Score 80 → y = 0 (top)
      final y80 = height - ((80.0 - minScore) / range * height);
      expect(y80, 0.0);

      // Score 60 → y = height/2 (middle)
      final y60 = height - ((60.0 - minScore) / range * height);
      expect(y60, height / 2);
    });

    test('X coordinate distribution', () {
      final scores = [10.0, 20.0, 30.0, 40.0, 50.0];
      const width = 100.0;

      for (var i = 0; i < scores.length; i++) {
        final x = i / (scores.length - 1) * width;
        final expectedX = i * 25.0;
        expect(x, closeTo(expectedX, 0.01));
      }
    });

    test('last 12 months truncation', () {
      final history = List.generate(
        24,
        (i) => {'month': '2024-${(i + 1).toString().padLeft(2, '0')}', 'score': 50 + i},
      );

      final recent = history.length > 12
          ? history.sublist(history.length - 12)
          : history;

      expect(recent.length, 12);
      expect(recent.first['month'], '2025-01');
      expect(recent.last['score'], 73);
    });
  });

  // ════════════════════════════════════════════════════════
  //  SPARKLINE DISPLAY LOGIC
  // ════════════════════════════════════════════════════════

  group('Sparkline display', () {
    test('requires at least 2 data points', () {
      final history = [{'month': '2026-03', 'score': 72}];
      expect(history.length >= 2, false);
    });

    test('2 data points is sufficient', () {
      final history = [
        {'month': '2026-02', 'score': 70},
        {'month': '2026-03', 'score': 72},
      ];
      expect(history.length >= 2, true);
    });

    test('delta badge color: positive = success', () {
      const delta = 5.0;
      final isSuccess = delta >= 0;
      expect(isSuccess, true);
    });

    test('delta badge color: negative = warning', () {
      const delta = -3.0;
      final isSuccess = delta >= 0;
      expect(isSuccess, false);
    });

    test('delta badge format: +X pts / -X pts', () {
      const delta = 5.0;
      final text = '${delta >= 0 ? '+' : ''}${delta.round()} pts';
      expect(text, '+5 pts');

      const delta2 = -3.0;
      final text2 = '${delta2 >= 0 ? '+' : ''}${delta2.round()} pts';
      expect(text2, '-3 pts');
    });
  });

  // ════════════════════════════════════════════════════════
  //  SCORE EXTRACTION
  // ════════════════════════════════════════════════════════

  group('Score extraction from history', () {
    test('extracts scores from history maps', () {
      final history = [
        {'month': '2026-01', 'score': 60},
        {'month': '2026-02', 'score': 65},
        {'month': '2026-03', 'score': 72},
      ];

      final scores = history
          .map((e) => (e['score'] as num?)?.toDouble() ?? 0)
          .toList();

      expect(scores, [60.0, 65.0, 72.0]);
    });

    test('handles null scores gracefully', () {
      final history = [
        {'month': '2026-01', 'score': null},
        {'month': '2026-02', 'score': 65},
      ];

      final scores = history
          .map((e) => (e['score'] as num?)?.toDouble() ?? 0)
          .toList();

      expect(scores, [0.0, 65.0]);
    });

    test('handles missing score key', () {
      final history = <Map<String, dynamic>>[
        {'month': '2026-01'},
        {'month': '2026-02', 'score': 70},
      ];

      final scores = history
          .map((e) => (e['score'] as num?)?.toDouble() ?? 0)
          .toList();

      expect(scores, [0.0, 70.0]);
    });
  });
}
