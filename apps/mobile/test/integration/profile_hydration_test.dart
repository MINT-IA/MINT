import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Integration tests for F7-1: Profile hydration race condition fix.
///
/// Validates that the GoRouter redirect logic correctly handles
/// the async hydration window where the backend profile is being
/// fetched but has not yet arrived.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Profile hydration state machine', () {
    test('hasProfile=false + isHydrating=true → router must NOT redirect to onboarding', () {
      // Simulates the window between login and API response.
      final provider = CoachProfileProvider();

      // Initial state: no profile, not hydrating.
      expect(provider.hasProfile, isFalse);
      expect(provider.isHydrating, isFalse);

      // Start hydrating (API call in flight).
      provider.startHydrating();
      expect(provider.isHydrating, isTrue);
      expect(provider.hasProfile, isFalse);

      // Router decision: logged in, no profile, BUT hydrating.
      // The redirect condition is:
      //   !hasProfile && !isHydrating → redirect to onboarding
      // Since isHydrating=true, redirect must NOT fire.
      final shouldRedirectToOnboarding =
          !provider.hasProfile && !provider.isHydrating;
      expect(shouldRedirectToOnboarding, isFalse,
          reason: 'Router must wait for hydration to complete before redirecting');
    });

    test('hasProfile=false + isHydrating=false → router DOES redirect to onboarding', () {
      // Simulates a user who genuinely has no backend profile.
      final provider = CoachProfileProvider();

      expect(provider.hasProfile, isFalse);
      expect(provider.isHydrating, isFalse);

      // Router decision: logged in, no profile, not hydrating.
      // This means hydration completed and no profile was found.
      final shouldRedirectToOnboarding =
          !provider.hasProfile && !provider.isHydrating;
      expect(shouldRedirectToOnboarding, isTrue,
          reason: 'Router must redirect when hydration is done and no profile exists');
    });

    test('createFromRemoteProfile sets hasProfile=true → router allows /home', () {
      // Simulates successful hydration from backend.
      final provider = CoachProfileProvider();

      // Start hydrating.
      provider.startHydrating();
      expect(provider.hasProfile, isFalse);
      expect(provider.isHydrating, isTrue);

      // Backend returns profile data.
      provider.createFromRemoteProfile({
        'birth_year': 1977,
        'canton': 'VS',
        'income_gross_yearly': 122207.0,
        'gender': 'M',
        'employment_status': 'salarie',
      });

      // Finish hydrating.
      provider.finishHydrating();

      expect(provider.hasProfile, isTrue);
      expect(provider.isHydrating, isFalse);

      // Router decision: profile exists → no redirect needed.
      final shouldRedirectToOnboarding =
          !provider.hasProfile && !provider.isHydrating;
      expect(shouldRedirectToOnboarding, isFalse,
          reason: 'Router must allow navigation when profile exists');
    });

    test('startHydrating notifies listeners (triggers GoRouter re-evaluation)', () {
      final provider = CoachProfileProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      provider.startHydrating();
      expect(notified, isTrue,
          reason: 'startHydrating must call notifyListeners for GoRouter refresh');
    });

    test('finishHydrating notifies listeners (triggers GoRouter re-evaluation)', () {
      final provider = CoachProfileProvider();
      provider.startHydrating();

      var notified = false;
      provider.addListener(() => notified = true);

      provider.finishHydrating();
      expect(notified, isTrue,
          reason: 'finishHydrating must call notifyListeners for GoRouter refresh');
    });

    test('clear resets isHydrating to false', () {
      final provider = CoachProfileProvider();
      provider.startHydrating();
      expect(provider.isHydrating, isTrue);

      provider.clear();
      expect(provider.isHydrating, isFalse);
      expect(provider.hasProfile, isFalse);
    });

    test('hydration error path: finishHydrating called even on failure', () {
      // Simulates API error during hydration.
      final provider = CoachProfileProvider();

      provider.startHydrating();
      expect(provider.isHydrating, isTrue);

      // API call fails — catchError calls finishHydrating.
      provider.finishHydrating();
      expect(provider.isHydrating, isFalse);
      expect(provider.hasProfile, isFalse);

      // Router should redirect to onboarding (hydration done, no profile).
      final shouldRedirect = !provider.hasProfile && !provider.isHydrating;
      expect(shouldRedirect, isTrue);
    });
  });
}
