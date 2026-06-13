import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/waitlist_service.dart';

/// State machine for the /waitlist screen submission flow.
///
/// initial → submitting → success | error
/// error → (resetError) → initial
enum WaitlistStatus { initial, submitting, success, error }

/// ARB keys consumed by the screen layer via AppLocalizations.
const _errorKeyBadEmail = 'waitlistErrorBadEmail';
const _errorKeyNetwork = 'waitlistErrorNetwork';

class WaitlistProvider extends ChangeNotifier {
  WaitlistProvider({WaitlistService? service, this.onGateSuccess})
      : _service = service ?? WaitlistService();

  final WaitlistService _service;

  /// Sub-phase 01.5 W02-T03 Task 6 — invoked once when the user
  /// successfully submits the waitlist form (transition to
  /// [WaitlistStatus.success]). Used to fire
  /// `CoachProfileProvider.clearAll()` (nLPD art. 6 minimization per
  /// Security §6 Q5) without making this provider depend directly on
  /// [CoachProfileProvider] (avoids a cyclic import). Null callback =
  /// no-op (existing tests and isolated screens unaffected).
  final FutureOr<void> Function()? onGateSuccess;

  WaitlistStatus _status = WaitlistStatus.initial;
  String? _errorKey;

  WaitlistStatus get status => _status;
  String? get errorKey => _errorKey;

  /// Submit the email to the waitlist endpoint and transition through
  /// the state machine. Throws [ArgumentError] when [consentGiven] is
  /// false (defense-in-depth — the screen also disables the CTA).
  Future<void> submit({
    required String email,
    required String archetype,
    required String locale,
    required String source,
    required bool consentGiven,
  }) async {
    if (!consentGiven) {
      throw ArgumentError(
        'consentGiven must be true (UCA opt-in required).',
      );
    }
    _status = WaitlistStatus.submitting;
    _errorKey = null;
    notifyListeners();

    final result = await _service.submit(
      email: email,
      archetype: archetype,
      locale: locale,
      source: source,
      consentGiven: consentGiven,
    );

    if (result.success) {
      _status = WaitlistStatus.success;
      _errorKey = null;
    } else {
      _status = WaitlistStatus.error;
      _errorKey = result.error == WaitlistApiError.badEmail
          ? _errorKeyBadEmail
          : _errorKeyNetwork;
    }
    notifyListeners();

    // Sub-phase 01.5 W02-T03 Task 6 — fire AFTER notifyListeners so the
    // UI has already transitioned to success state when the clearAll
    // side effect runs (Security §6 Q5 nLPD art. 6 minimization).
    if (_status == WaitlistStatus.success) {
      await onGateSuccess?.call();
    }
  }

  /// Returns the screen from error → initial so the user can edit the
  /// email and retry. No-op if currently in any state other than error.
  void resetError() {
    if (_status != WaitlistStatus.error) return;
    _status = WaitlistStatus.initial;
    _errorKey = null;
    notifyListeners();
  }
}
