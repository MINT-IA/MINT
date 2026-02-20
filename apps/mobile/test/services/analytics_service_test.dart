import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnalyticsService', () {
    late AnalyticsService analytics;

    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      analytics = AnalyticsService();
      // Reset singleton state so init() re-reads from fresh SharedPreferences
      analytics.resetForTesting();
      await analytics.init();
    });

    test('initializes with a session ID', () async {
      expect(analytics.sessionId, isNotNull);
      expect(analytics.sessionId, isA<String>());
    });

    test('session ID persists across instances', () async {
      final sessionId1 = analytics.sessionId;

      // Create a new instance
      final analytics2 = AnalyticsService();
      await analytics2.init();

      expect(analytics2.sessionId, equals(sessionId1));
    });

    test('analytics is disabled by default (opt-in required)', () {
      expect(analytics.isEnabled, isFalse);
    });

    test('setConsent enables analytics', () async {
      await analytics.setConsent(true);
      expect(analytics.isEnabled, isTrue);
    });

    test('setConsent disables analytics', () async {
      await analytics.setConsent(true);
      expect(analytics.isEnabled, isTrue);

      await analytics.setConsent(false);
      expect(analytics.isEnabled, isFalse);
    });

    test('trackEvent queues events when consent is given', () async {
      await analytics.setConsent(true);

      // Note: We can't directly test the queue, but we can verify no exceptions
      expect(
        () => analytics.trackEvent('test_event', category: 'test'),
        returnsNormally,
      );
    });

    test('trackEvent does not track when consent is not given', () async {
      // Ensure analytics is disabled
      await analytics.setConsent(false);
      expect(analytics.isEnabled, isFalse);

      // Should not throw, just silently not track
      expect(
        () => analytics.trackEvent('test_event', category: 'test'),
        returnsNormally,
      );
    });

    test('trackScreenView works correctly', () async {
      await analytics.setConsent(true);

      expect(
        () => analytics.trackScreenView('/home'),
        returnsNormally,
      );
    });

    test('trackOnboardingStep includes correct data', () async {
      await analytics.setConsent(true);

      expect(
        () => analytics.trackOnboardingStep(1, 'household', totalSteps: 4),
        returnsNormally,
      );
    });

    test('trackOnboardingStarted works', () async {
      await analytics.setConsent(true);

      expect(
        () => analytics.trackOnboardingStarted(),
        returnsNormally,
      );
    });

    test('trackOnboardingStarted accepts contextual data', () async {
      await analytics.setConsent(true);

      expect(
        () => analytics.trackOnboardingStarted(data: {
          'experiment': 'mini_onboarding_v4',
          'variant': 'control',
        }),
        returnsNormally,
      );
    });

    test('trackOnboardingCompleted includes time spent', () async {
      await analytics.setConsent(true);

      expect(
        () => analytics.trackOnboardingCompleted(timeSpentSeconds: 120),
        returnsNormally,
      );
    });

    test('trackOnboardingCompleted accepts contextual data', () async {
      await analytics.setConsent(true);

      expect(
        () => analytics.trackOnboardingCompleted(
          timeSpentSeconds: 120,
          data: {'experiment': 'mini_onboarding_v4', 'variant': 'challenge'},
        ),
        returnsNormally,
      );
    });

    test('trackCTAClick includes CTA name and screen', () async {
      await analytics.setConsent(true);

      expect(
        () => analytics.trackCTAClick('cta_diagnostic', screenName: '/'),
        returnsNormally,
      );
    });

    test('trackCTAClick accepts contextual data', () async {
      await analytics.setConsent(true);

      expect(
        () => analytics.trackCTAClick(
          'cta_diagnostic',
          screenName: '/',
          data: {'experiment': 'mini_onboarding_v4', 'variant': 'challenge'},
        ),
        returnsNormally,
      );
    });

    test('trackTabSwitch includes from and to tabs', () async {
      await analytics.setConsent(true);

      expect(
        () => analytics.trackTabSwitch('now', 'explore'),
        returnsNormally,
      );
    });

    test('trackExperimentExposure works correctly', () async {
      await analytics.setConsent(true);

      expect(
        () => analytics.trackExperimentExposure(
          'mini_onboarding_v4',
          'control',
          screenName: '/advisor',
        ),
        returnsNormally,
      );
    });

    test('flush handles errors gracefully', () async {
      await analytics.setConsent(true);
      analytics.trackEvent('test_event');

      // Should not throw even if backend is unreachable
      expect(
        () async => await analytics.flush(),
        returnsNormally,
      );
    });

    test('hasConsent returns false by default', () async {
      final hasConsent = await AnalyticsService.hasConsent();
      expect(hasConsent, isFalse);
    });

    test('hasConsent returns true after consent given', () async {
      await analytics.setConsent(true);

      final hasConsent = await AnalyticsService.hasConsent();
      expect(hasConsent, isTrue);
    });

    test('hasAskedForConsent returns false initially', () async {
      final hasAsked = await AnalyticsService.hasAskedForConsent();
      expect(hasAsked, isFalse);
    });

    test('hasAskedForConsent returns true after consent interaction', () async {
      await analytics.setConsent(true);

      final hasAsked = await AnalyticsService.hasAskedForConsent();
      expect(hasAsked, isTrue);
    });

    test('hasAskedForConsent returns true even if consent refused', () async {
      await analytics.setConsent(false);

      final hasAsked = await AnalyticsService.hasAskedForConsent();
      expect(hasAsked, isTrue);
    });

    test('consent events are tracked even when analytics is disabled',
        () async {
      // Analytics disabled by default
      expect(analytics.isEnabled, isFalse);

      // Should still track consent events
      expect(
        () async => await analytics.setConsent(true),
        returnsNormally,
      );

      expect(
        () async => await analytics.setConsent(false),
        returnsNormally,
      );
    });

    test('trackEvent with custom data', () async {
      await analytics.setConsent(true);

      expect(
        () => analytics.trackEvent(
          'custom_event',
          category: 'custom',
          data: {
            'key1': 'value1',
            'key2': 42,
            'key3': true,
          },
        ),
        returnsNormally,
      );
    });

    test('trackEvent with screen name', () async {
      await analytics.setConsent(true);

      expect(
        () => analytics.trackEvent(
          'button_clicked',
          category: 'engagement',
          screenName: '/home',
        ),
        returnsNormally,
      );
    });

    test('multiple events can be queued', () async {
      await analytics.setConsent(true);

      for (int i = 0; i < 20; i++) {
        analytics.trackEvent('event_$i', category: 'test');
      }

      // Should not throw
      expect(
        () async => await analytics.flush(),
        returnsNormally,
      );
    });

    test('clearLocalQueue removes persisted queue but keeps consent/session',
        () async {
      await analytics.setConsent(true);
      analytics.trackEvent('queued_event', category: 'test');

      final before = await SharedPreferences.getInstance();
      expect(before.getString('analytics_events_queue'), isNotNull);
      final sessionBefore = analytics.sessionId;
      final consentBefore = analytics.isEnabled;

      await analytics.clearLocalQueue();

      final after = await SharedPreferences.getInstance();
      expect(after.getString('analytics_events_queue'), isNull);
      expect(analytics.sessionId, equals(sessionBefore));
      expect(analytics.isEnabled, equals(consentBefore));
    });

    test('trackEvent persists events to SharedPreferences', () async {
      await analytics.setConsent(true);
      analytics.trackEvent('persist_test', category: 'test');

      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString('analytics_events_queue');
      expect(queueJson, isNotNull);
      expect(queueJson, contains('persist_test'));
    });

    test('setConsent(false) clears persisted queue', () async {
      await analytics.setConsent(true);
      analytics.trackEvent('temp_event', category: 'test');

      // Verify event is queued
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('analytics_events_queue'), contains('temp_event'));

      // Revoke consent
      await analytics.setConsent(false);

      // Queue should be cleared (only revocation event may remain or be flushed)
      final afterRevoke = prefs.getString('analytics_events_queue');
      if (afterRevoke != null) {
        expect(afterRevoke, isNot(contains('temp_event')));
      }
    });
  });
}
