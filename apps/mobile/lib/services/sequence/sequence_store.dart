/// SequenceStore — persistence for the active guided sequence run.
///
/// SharedPreferences-backed. One active run at a time.
/// This is the SOLE source of truth for whether a sequence is active.
///
/// See: docs/RFC_AGENT_LOOP_STATEFUL.md §5.6, §6.3
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/sequence_run.dart';

/// Persists and retrieves the active [SequenceRun].
class SequenceStore {
  SequenceStore._();

  static const String _key = 'mint_sequence_run';

  /// Load the active run, or null if none.
  static Future<SequenceRun?> load({SharedPreferences? prefs}) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    return SequenceRun.deserialize(sp.getString(_key));
  }

  /// Save (create or update) the active run.
  static Future<void> save(SequenceRun run, {SharedPreferences? prefs}) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    await sp.setString(_key, run.serialize());
  }

  /// Clear the active run (sequence completed or abandoned).
  static Future<void> clear({SharedPreferences? prefs}) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    await sp.remove(_key);
  }
}
