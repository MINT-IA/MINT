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

    test('LandingScreen keeps no routing policy of its own', () {
      // Bascule 4 : la destination de la première ouverture n'est plus écrite
      // dans l'écran. Elle passe par l'entrée canonique unique, qui décide
      // selon la préversion — un littéral dispersé échappait au vérificateur
      // de fermeture et laissait huit alias mener au wizard historique.
      expect(landingSource, contains('LegacyOnboardingEntry.open(context)'));
      for (final literal in const [
        "context.go('/start')",
        "context.go('/onb')",
        "context.go('/anonymous/chat')",
      ]) {
        expect(landingSource, isNot(contains(literal)),
            reason: 'aucune destination d\'entrée en dur dans la landing');
      }
    });
  });
}
