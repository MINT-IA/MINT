import 'dart:async';

import 'package:mint_mobile/debug/ring_buffer.dart';

/// Bounded buffer of recent `debugPrint` / `print` lines.
///
/// Populated only when [runWithLogCapture] wraps the app's `main()`.
/// `DebugServer` exposes the snapshot at `/debug/state/logs`. Capacity
/// is tuned for short-burst LLM debug loops — bump it carefully, every
/// entry is a strong-referenced [String].
class DebugLogBuffer {
  DebugLogBuffer._();

  static final RingBuffer<String> _buffer = RingBuffer<String>(200);

  static void _add(String line) {
    // Drop the inline noisy Flutter framework chatter that drowns out the
    // signal lines an LLM agent actually greps for. Keep `[ch.mint.*]`
    // tagged lines (Tier 1 obs spine emits these) + anything explicitly
    // routed through `developer.log(name: 'mint.*')` if it bridges to
    // stdout via `print`.
    if (line.isEmpty) return;
    _buffer.add(line);
  }

  /// Read-only snapshot, oldest first.
  static List<String> snapshot() => _buffer.toList();

  static int get length => _buffer.length;
}

/// Wrap the app's `main()` body in a Zone that tees every `print` into
/// the [DebugLogBuffer]. Debug builds only — release builds bypass this
/// entirely (see `lib/debug/debug_facade.dart`).
///
/// Usage:
///   await runWithLogCapture(() async {
///     WidgetsFlutterBinding.ensureInitialized();
///     runApp(const MintApp());
///   });
T runWithLogCapture<T>(T Function() body) {
  return runZoned<T>(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        DebugLogBuffer._add(line);
        parent.print(zone, line);
      },
    ),
  );
}
