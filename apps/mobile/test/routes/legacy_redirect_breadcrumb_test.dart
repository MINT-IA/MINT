// Phase 32 Wave 0 stub — MAP-05: 43 redirects emit mint.routing.legacy_redirect.hit.
// Implementation: Plan 32-03 Wave 3.
//
// Baseline (from RECONCILE-REPORT.md §Redirect Call-Site Inventory):
// - 43 arrow-form `(_, __) => '/target'` redirects at app.dart L531..L1171
// - Each site has redirect_branches=1, null_pass_through=0
// - Expected total MintBreadcrumbs.legacyRedirectHit source-call count >= 43
//
// Wave 3 wires `MintBreadcrumbs.legacyRedirectHit(from, to)` at every arrow-form
// site. D-09 §2 redaction requires data MUST NOT include query params or user
// context.
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('legacyRedirectHit breadcrumb (MAP-05)', () {
    test('redirect /report -> /rapport emits category mint.routing.legacy_redirect.hit', () {
      // Will drive GoRouter to /report, await redirect to /rapport, and assert
      // Sentry breadcrumb queue contains one breadcrumb with
      // category == 'mint.routing.legacy_redirect.hit' and
      // data == {'from': '/report', 'to': '/rapport'}.
    }, skip: 'Plan 32-03 Wave 3 wires legacyRedirectHit in app.dart');

    test('breadcrumb data contains from+to paths, NO query params, NO user context', () {
      // Will drive /advisor?utm_source=email and assert breadcrumb data has
      // exactly {'from': '/advisor', 'to': '/coach/chat'} — no utm_source,
      // no user.id, no email. D-09 §2 nLPD minimization contract.
    }, skip: 'Plan 32-03 Wave 3 (D-09 §2 redaction)');
  });
}
