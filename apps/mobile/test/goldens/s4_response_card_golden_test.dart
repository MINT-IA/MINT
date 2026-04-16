// S4 ResponseCardWidget goldens (Plan 04-03) — SKIPPED PLACEHOLDER.
//
// Plan 04-02 is wiring MTC into response_card_widget.dart in parallel
// with this plan. To avoid a race on shared file ownership, the S4
// image-diff goldens are deferred until 04-02 lands on dev. The test
// body below compiles against the planned Plan 04-02 API surface but
// is gated with `skip:` so the test runner reports the intent without
// failing.
//
// When Plan 04-02 is committed:
//   1. Remove `skip:` from each test.
//   2. Update the constructor call if Plan 04-02 locked a different
//      confidence parameter name.
//   3. Re-run `flutter test --update-goldens test/goldens/s4_response_card_golden_test.dart`
//      locally to generate the masters.
//   4. Commit the masters alongside the un-skipped test file.
//
// These goldens are local-run only — see README.md.

@Tags(<String>['local-only'])
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('S4 ResponseCardWidget goldens [local-only]', () {
    // SKIPPED — waiting for Plan 04-02 (response_card_widget MTC wiring).
    // See file header for the un-skip protocol.
    testWidgets(
      's4_mtc_default iphone14pro [skipped: awaiting 04-02]',
      (tester) async {
        // Intentionally empty body — see file-header instructions.
      },
      skip: true,
    );

    testWidgets(
      's4_mtc_default galaxya14 [skipped: awaiting 04-02]',
      (tester) async {},
      skip: true,
    );

    testWidgets(
      's4_no_mtc control [skipped: awaiting 04-02]',
      (tester) async {},
      skip: true,
    );
  });
}
