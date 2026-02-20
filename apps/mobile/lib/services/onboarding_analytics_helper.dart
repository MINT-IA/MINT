import 'package:mint_mobile/services/analytics_service.dart';

class OnboardingAnalyticsHelper {
  final AnalyticsService _analytics;

  OnboardingAnalyticsHelper([AnalyticsService? analytics])
      : _analytics = analytics ?? AnalyticsService();

  void trackStarted(Map<String, dynamic> context) {
    _analytics.trackOnboardingStarted(data: context);
  }

  void trackStepTransition({
    required int step,
    required String stepName,
    required int totalSteps,
    required Map<String, dynamic> context,
    int? durationSeconds,
  }) {
    _analytics.trackOnboardingStep(step, stepName,
        totalSteps: totalSteps, data: context);
    _analytics.trackEvent(
      'onboarding_step_duration',
      category: 'engagement',
      data: {
        ...context,
        'step': step,
        'step_name': stepName,
        if (durationSeconds != null) 'duration_seconds': durationSeconds,
      },
    );
  }

  void trackCompleted({
    required int timeSpentSeconds,
    required Map<String, dynamic> context,
  }) {
    _analytics.trackOnboardingCompleted(
      timeSpentSeconds: timeSpentSeconds,
      data: context,
    );
  }

  void trackAbandoned({
    required int step,
    required String stepName,
    required int elapsedSeconds,
    required Map<String, dynamic> context,
  }) {
    _analytics.trackEvent(
      'onboarding_abandoned',
      category: 'engagement',
      data: {
        ...context,
        'step': step,
        'step_name': stepName,
        'elapsed_seconds': elapsedSeconds,
      },
    );
  }
}
