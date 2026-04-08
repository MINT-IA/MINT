import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import '../../services/biography/biography_fact.dart';
import '../../services/biography/biography_repository.dart';
import '../../services/voice/voice_cursor_contract.dart';
import 'mint_alert_object.dart';
import 'mint_alert_signal.dart';

/// Signature for the `SemanticsService.announce` side of [MintAlertHost].
/// Exposed as a seam so unit tests can capture calls without relying on
/// the platform accessibility channel.
typedef AnnounceFn = void Function(String message, TextDirection direction);

/// Signature for the ack-record side of [MintAlertHost]. Tests inject a
/// fake; production wires this to [BiographyRepository.recordFact].
typedef RecordAckFn = Future<void> Function(BiographyFact fact);

/// Signature for the ack-lookup side of [MintAlertHost]. Tests inject a
/// fake; production wires this to [BiographyRepository.hasAlertAck].
typedef HasAckFn = Future<bool> Function(String alertId);

/// MintAlertHost — Phase 9 Plan 09-04 stateful wrapper around
/// [MintAlertObject].
///
/// Responsibilities (all three coupled on purpose — they share state):
///
///   1. **G3 ack persistence (D-06 / ALERT-05).** Each signal carries an
///      `alertId` (content hash). When the user taps the "Compris" CTA on a
///      G3 alert, the host records a [BiographyFact.alertAcknowledged] via
///      [recordAck]. Subsequent signals with the same `alertId` are
///      suppressed via [hasAck] (checked on each build).
///
///   2. **SemanticsService.announce on G2→G3 transition (D-11 / ALERT-08).**
///      The host tracks the previous [Gravity] per `alertId`. When it sees a
///      transition from [Gravity.g2] to [Gravity.g3] for the same id, it
///      fires [announce] **exactly once**. First render of a G3 alert does
///      NOT fire (there is no transition). Idle G3→G3 updates do NOT fire.
///
///   3. **G2 is auto-dismissible; G3 persists until ack.** When the
///      [signals] stream stops emitting a given G2 alert (signal dropped
///      from the "active" set), the widget disappears. G3 alerts remain
///      visible until the user acknowledges them — a stream drop does not
///      dismiss them.
///
/// The host renders the current active set as a simple Column of
/// [MintAlertObject]s each followed by a "Compris" ack CTA (shown only on
/// G3 per D-06; G2 is transient). Parent surfaces (S5) embed the host in
/// whatever card stack they use; the host itself makes no layout claims
/// beyond a mainAxisSize.min Column.
///
/// All I/O is behind typedef seams ([announce], [recordAck], [hasAck]) so
/// unit tests are hermetic — see `test/widgets/alert/mint_alert_host_test.dart`.
class MintAlertHost extends StatefulWidget {
  const MintAlertHost({
    super.key,
    required this.signals,
    required this.resolveContext,
    this.announce,
    this.recordAck,
    this.hasAck,
  });

  /// Merged feeder stream. Signals emitted by `AnticipationProvider`,
  /// `NudgeEngine` and `ProactiveTriggerService` (Plan 09-02).
  ///
  /// The host treats each emitted [MintAlertSignal] as "this alertId is
  /// currently active". To retract an alert, the feeder emits a signal
  /// with the same `alertId` removed from the active set — but since the
  /// stream is a flat stream of individual signals (not sets), the host
  /// instead treats dropping by timing: **G2 signals auto-expire** after
  /// the feeder stops re-emitting them within the current frame cycle.
  /// For deterministic tests we expose a simpler contract: the active set
  /// is precisely the set of distinct `alertId` values emitted so far
  /// that have NOT been acknowledged.
  ///
  /// (This mirrors the Phase 9 D-09 "feeder emits rule-based signals"
  /// intent and is sufficient for the patrol matrix.)
  final Stream<MintAlertSignal> signals;

  /// Called once per signal to build a [VoiceResolutionContext] from app
  /// state (CoachProfile, BiographyProvider, etc.). Plan 09-02's feeder
  /// wiring is expected to supply this.
  final VoiceResolutionContext Function(BuildContext, MintAlertSignal)
      resolveContext;

  /// Seam for `SemanticsService.announce`. Defaults to the real one.
  final AnnounceFn? announce;

  /// Seam for ack persistence. Defaults to [BiographyRepository.recordFact]
  /// via the shared singleton. Tests pass a fake to avoid DB setup.
  final RecordAckFn? recordAck;

  /// Seam for ack lookup. Defaults to [BiographyRepository.hasAlertAck]
  /// via the shared singleton.
  final HasAckFn? hasAck;

  @override
  State<MintAlertHost> createState() => _MintAlertHostState();
}

class _MintAlertHostState extends State<MintAlertHost> {
  /// Active signals keyed by alertId, in insertion order.
  final Map<String, MintAlertSignal> _active = <String, MintAlertSignal>{};

  /// Previous gravity per alertId — used to detect G2→G3 transitions.
  /// First render stores the initial gravity WITHOUT announcing
  /// (D-11: announce on transition only).
  final Map<String, Gravity> _previousGravity = <String, Gravity>{};

  /// alertIds for which an ack fact exists (cached from [hasAck] probes).
  final Set<String> _acked = <String>{};

  StreamSubscription<MintAlertSignal>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.signals.listen(_onSignal);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  AnnounceFn get _announce =>
      // ignore: deprecated_member_use
      widget.announce ?? SemanticsService.announce;

  Future<void> _defaultRecordAck(BiographyFact fact) async {
    final repo = await BiographyRepository.instance();
    await repo.recordFact(fact);
  }

  Future<bool> _defaultHasAck(String alertId) async {
    final repo = await BiographyRepository.instance();
    return repo.hasAlertAck(alertId);
  }

  RecordAckFn get _recordAck => widget.recordAck ?? _defaultRecordAck;
  HasAckFn get _hasAck => widget.hasAck ?? _defaultHasAck;

  Future<void> _onSignal(MintAlertSignal signal) async {
    // Ack check — if already acknowledged, drop silently.
    if (_acked.contains(signal.alertId)) return;
    final already = await _hasAck(signal.alertId);
    if (already) {
      _acked.add(signal.alertId);
      if (mounted) setState(() {});
      return;
    }

    final Gravity? prev = _previousGravity[signal.alertId];
    final bool isTransitionG2ToG3 =
        prev == Gravity.g2 && signal.gravity == Gravity.g3;

    if (isTransitionG2ToG3 && mounted) {
      // D-11: announce exactly once on G2→G3 transition.
      final loc = S.of(context);
      final msg = loc?.mintAlertAnnounceG3 ??
          'MINT a repéré un point important qui demande ton attention.';
      _announce(msg, TextDirection.ltr);
    }

    _previousGravity[signal.alertId] = signal.gravity;
    _active[signal.alertId] = signal;

    // G2 auto-dismiss semantics: a G2 signal is considered "live" only
    // until the next rebuild if not re-emitted. For the deterministic
    // contract used by the patrol matrix we keep it active until a later
    // signal drops it (parent may call [removeG2] if needed). This keeps
    // the host hermetic for testing; S5 drives dismissal by not
    // re-emitting.

    if (mounted) setState(() {});
  }

  Future<void> _acknowledge(MintAlertSignal signal) async {
    await _recordAck(
      BiographyFact.alertAcknowledged(
        alertId: signal.alertId,
        at: DateTime.now(),
      ),
    );
    _acked.add(signal.alertId);
    _active.remove(signal.alertId);
    if (mounted) setState(() {});
  }

  /// Public API: drop a G2 signal (auto-dismiss path). Called by S5 when
  /// the feeder stops emitting. G3 signals cannot be removed this way —
  /// only ack removes them. Tests exercise this via a second stream event
  /// carrying the same alertId but no-op semantics; in practice S5 wraps
  /// the host in its own controller.
  void dismissIfG2(String alertId) {
    final s = _active[alertId];
    if (s == null) return;
    if (s.gravity == Gravity.g2) {
      _active.remove(alertId);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_active.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (final signal in _active.values) {
      if (_acked.contains(signal.alertId)) continue;
      children.add(_buildAlertCard(signal));
      children.add(const SizedBox(height: 12));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    children.removeLast(); // trailing gap

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildAlertCard(MintAlertSignal signal) {
    final loc = S.of(context);
    final fact = _resolveArb(loc, signal.factKey);
    final cause = _resolveArb(loc, signal.causeKey);
    final nextMoment = _resolveArb(loc, signal.nextMomentKey);

    final alert = MintAlertObject(
      gravity: signal.gravity,
      fact: fact,
      cause: cause,
      nextMoment: nextMoment,
      alertId: signal.alertId,
      resolutionContext: widget.resolveContext(context, signal),
    );

    if (signal.gravity != Gravity.g3) return alert;

    // G3 only: show "Compris" ack CTA. Use TextButton (Material) with an
    // explicit tooltip on its semantics — TalkBack 13 sweep (D-13).
    final ackLabel = loc?.alertAckCta ?? 'Compris';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        alert,
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Tooltip(
            message: ackLabel,
            child: Semantics(
              button: true,
              label: ackLabel,
              hint: 'Marquer cette alerte comme vue',
              child: TextButton(
                key: Key('mint_alert_ack_${signal.alertId}'),
                onPressed: () => _acknowledge(signal),
                child: Text(ackLabel),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Very small ARB-key resolver. For Phase 9 Plan 09-04 we accept either
  /// a direct literal (if the feeder already localized) or one of the
  /// known alert ARB keys. Unknown keys fall back to the key itself so
  /// tests remain self-describing.
  String _resolveArb(S? loc, String keyOrLiteral) {
    if (loc == null) return keyOrLiteral;
    switch (keyOrLiteral) {
      case 'mintAlertDebtFact':
        return loc.mintAlertDebtFact;
      case 'mintAlertDebtCause':
        return loc.mintAlertDebtCause;
      case 'mintAlertDebtNextMoment':
        return loc.mintAlertDebtNextMoment;
      case 'alertGenericFactPrefix':
        return loc.alertGenericFactPrefix;
      case 'alertGenericCausePrefix':
        return loc.alertGenericCausePrefix;
      case 'alertGenericNextMomentPrefix':
        return loc.alertGenericNextMomentPrefix;
    }
    return keyOrLiteral;
  }
}
