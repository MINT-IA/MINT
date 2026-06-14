// Diagnostic onboarding route contract.
//
// The landing CTA stays dumb (`context.go('/start')`). The routing decision
// belongs to app.dart, and the first-run entry must fail closed to the
// structured diagnostic onboarding. It must never fall back to the legacy
// anonymous chat when backend feature flags are false or unavailable.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/routes/route_metadata.dart';

void main() {
  group('/start route contract', () {
    late String appSource;
    late String landingSource;

    setUpAll(() {
      final appFile = File('lib/app.dart');
      expect(appFile.existsSync(), isTrue, reason: 'lib/app.dart must exist');
      appSource = appFile.readAsStringSync();

      final landingFile = File('lib/screens/landing_screen.dart');
      expect(
        landingFile.existsSync(),
        isTrue,
        reason: 'LandingScreen source must exist',
      );
      landingSource = landingFile.readAsStringSync();
    });

    String startRouteBlock() {
      final startIndex = appSource.indexOf("path: '/start'");
      expect(startIndex, isNonNegative, reason: 'app.dart must declare /start');

      final onbIndex = appSource.indexOf("path: '/onb'", startIndex);
      expect(
        onbIndex,
        isNonNegative,
        reason: '/start should be declared before /onb in app.dart',
      );

      return appSource.substring(startIndex, onbIndex);
    }

    test('app.dart routes /start to diagnostic onboarding only', () {
      final block = startRouteBlock();

      expect(
        block,
        isNot(contains('FeatureFlags.enableMvpWedgeOnboarding')),
        reason:
            '/start must not depend on a remote rollout flag for first-run UX',
      );
      expect(block, contains("'/onb'"));
      expect(
        block,
        isNot(contains("'/anonymous/chat'")),
        reason: 'the legacy chat-first surface must not be a /start fallback',
      );
    });

    test('route metadata describes the same /start contract', () {
      final meta = kRouteRegistry['/start'];

      expect(meta, isNotNull);
      expect(meta!.description, contains('/onb'));
      expect(meta.description, isNot(contains('/anonymous/chat')));
    });

    test('LandingScreen delegates first-run routing to /start', () {
      expect(landingSource, contains("context.go('/start')"));
      expect(
        landingSource,
        isNot(contains("context.go('/onb')")),
        reason: 'LandingScreen must keep routing policy in /start',
      );
    });
  });
}
