/// STAMP-03 (Phase 89 v2.12) — frame timing capture for jank measurement.
///
/// When the dart-define `MINT_FRAME_TIMING_CAPTURE=true` is present
/// (debug/profile builds only — `kReleaseMode` short-circuits), the
/// service registers `WidgetsBinding.instance.addTimingsCallback` and
/// emits a structured `[MINT_FRAME_TIMING]` log line every second with
/// the count of frames + percentage of those frames whose total span
/// exceeded 16ms (jank threshold for 60fps target).
///
/// Walker (`tools/simulator/walker_premier_eclairage.sh`) consumes
/// these lines via `xcrun simctl spawn booted log stream` to compute
/// the STAMP-03 jank metric : `< 1% > 16ms over a 5s window of
/// 4-card éclairage scroll-and-tap`.
///
/// Output line format :
/// `[MINT_FRAME_TIMING] window=Xs total=N over_16ms=M pct=P.PP`
///
/// Release builds : the service is a no-op (kReleaseMode short-circuit).

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class MintFrameTimingCapture {
  static const bool _enabled = bool.fromEnvironment(
    'MINT_FRAME_TIMING_CAPTURE',
    defaultValue: false,
  );

  static const int _jankThresholdMicros = 16667; // 60fps target = 16.67ms
  static int _windowFrames = 0;
  static int _windowJankFrames = 0;
  static DateTime _windowStart = DateTime.now();
  static bool _registered = false;

  /// Register the timings callback. Idempotent + release-mode safe.
  static void register() {
    if (kReleaseMode) return;
    if (!_enabled) return;
    if (_registered) return;
    _registered = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _windowFrames++;
      // Build + raster = the actual frame work. `totalSpan` includes
      // vsyncOverhead (wait time between vsyncs) which inflates idle
      // frames to the inter-frame interval. We measure rendering work,
      // not scheduler latency.
      final renderMicros =
          t.buildDuration.inMicroseconds + t.rasterDuration.inMicroseconds;
      if (renderMicros > _jankThresholdMicros) {
        _windowJankFrames++;
      }
    }

    final now = DateTime.now();
    if (now.difference(_windowStart).inSeconds >= 1) {
      final pct = _windowFrames == 0
          ? 0.0
          : (_windowJankFrames / _windowFrames) * 100.0;
      // Emit a parseable single-line log entry. Walker greps for
      // `[MINT_FRAME_TIMING]` to aggregate across the 5s window.
      // `print` is intentional — debug/profile only, kReleaseMode
      // short-circuit above.
      // ignore: avoid_print
      print(
        '[MINT_FRAME_TIMING] window=1s '
        'total=$_windowFrames '
        'over_16ms=$_windowJankFrames '
        'pct=${pct.toStringAsFixed(2)}',
      );
      _windowFrames = 0;
      _windowJankFrames = 0;
      _windowStart = now;
    }
  }
}
