// Phase 31 OBS-04 (a) — trace_id propagation in _authHeaders stub (Wave 0).
//
// Wave 1 Plan 31-01 patches:
//   apps/mobile/lib/services/api_service.dart:_authHeaders()
// to inject `sentry-trace` + `baggage` headers when a Sentry transaction /
// span is active at the call site. This is the mobile end of the
// round-trip verified by tools/simulator/trace_round_trip_test.sh.
//
// D-05 LOCKED (CONTEXT.md §Implementation Decisions): the primary
// propagation header is `sentry-trace` (Sentry OTLP-compatible) plus
// `baggage` (W3C standard). The legacy `X-MINT-Trace-Id` emitted by the
// backend LoggingMiddleware continues in parallel — dual-header zero-
// regression approach. No Dio migration (D-A4 rejected — http ^1.2.0
// stays, manual header injection only).
//
// Expected _authHeaders() behaviour (Wave 1):
//   - when Sentry.getSpan() is non-null -> headers include
//     'sentry-trace': '<32-hex-trace>-<16-hex-span>-<sampled>'
//     'baggage': 'sentry-trace_id=<hex>,sentry-environment=<env>,...'
//   - when no span is active (cold auth bootstrap) -> headers do NOT
//     include sentry-trace; existing auth headers unchanged.
//
// Covers the 20+ call sites of _authHeaders() with a single patch point.
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiService._authHeaders sentry-trace (Wave 1 Plan 31-01)', () {
    test(
      '_authHeaders returns sentry-trace + baggage when a Sentry span '
      'is active at the call site (D-05 locked dual-header propagation)',
      () {},
      skip: 'Wave 1 impl pending — Plan 31-01 patches api_service.dart',
    );
  });
}
