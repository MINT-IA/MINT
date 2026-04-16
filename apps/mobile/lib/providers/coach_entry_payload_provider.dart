import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/coach_entry_payload.dart';

/// Transient provider for passing [CoachEntryPayload] from MintHomeScreen
/// to CoachChatScreen via the tab-based navigation path.
///
/// Wire Spec V2 fix: resolves the facade where payload was created on
/// MintHomeScreen but never delivered to CoachChatScreen in tab mode.
///
/// Usage:
///   1. MintHomeScreen sets payload via [setPayload]
///   2. MintCoachTab reads and clears via [consumePayload] (one-shot)
///   3. CoachChatScreen receives it as [entryPayload] parameter
class CoachEntryPayloadProvider extends ChangeNotifier {
  CoachEntryPayload? _pending;

  /// The pending payload, if any. Use [consumePayload] to read and clear.
  CoachEntryPayload? get pending => _pending;

  /// Store a payload for the next coach session.
  void setPayload(CoachEntryPayload? payload) {
    _pending = payload;
    notifyListeners();
  }

  /// Read and clear the pending payload (one-shot consumption).
  /// Returns null if no payload is pending.
  CoachEntryPayload? consumePayload() {
    final payload = _pending;
    if (payload != null) {
      _pending = null;
      // Don't notify here — the consumer already has the value.
    }
    return payload;
  }
}
