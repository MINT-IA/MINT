import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AuthProviderStub extends AuthProvider {
  bool loggedIn = false;
  bool loading = false;

  @override
  bool get isLoggedIn => loggedIn;

  @override
  bool get isLoading => loading;

  void setAuthState({required bool isLoggedIn, required bool isLoading}) {
    loggedIn = isLoggedIn;
    loading = isLoading;
    notifyListeners();
  }
}

class _ReloadTrackingCoachProfileProvider extends CoachProfileProvider {
  int reloadCalls = 0;

  @override
  Future<void> reloadAfterAuthBackendHydration() async {
    reloadCalls += 1;
  }
}

/// Integration tests for F7-1: Profile hydration race condition fix.
///
/// Validates that the GoRouter redirect logic correctly handles
/// the async hydration window where the backend profile is being
/// fetched but has not yet arrived.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Profile hydration state machine', () {
    test(
        'hasProfile=false + isHydrating=true → router must NOT redirect to onboarding',
        () {
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
          reason:
              'Router must wait for hydration to complete before redirecting');
    });

    test(
        'hasProfile=false + isHydrating=false → router DOES redirect to onboarding',
        () {
      // Simulates a user who genuinely has no backend profile.
      final provider = CoachProfileProvider();

      expect(provider.hasProfile, isFalse);
      expect(provider.isHydrating, isFalse);

      // Router decision: logged in, no profile, not hydrating.
      // This means hydration completed and no profile was found.
      final shouldRedirectToOnboarding =
          !provider.hasProfile && !provider.isHydrating;
      expect(shouldRedirectToOnboarding, isTrue,
          reason:
              'Router must redirect when hydration is done and no profile exists');
    });

    test('createFromRemoteProfile sets hasProfile=true → router allows /home',
        () {
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

    test('createFromRemoteProfile without birth data keeps age unknown', () {
      final provider = CoachProfileProvider();

      provider.createFromRemoteProfile({
        'canton': 'VS',
        'income_gross_yearly': 122207.0,
      });

      expect(provider.hasProfile, isTrue);
      expect(provider.profile!.birthYear, 0,
          reason: 'backend-only hydration must not invent a 40-year-old user');
      expect(provider.profile!.ageOrNull, isNull);
      expect(provider.profile!.anneesAvantRetraite, isNull);
      expect(provider.profile!.goalA.targetDate.year,
          isNot(DateTime.now().year + 20));
      expect(provider.isPartialProfile, isTrue);
    });

    test('startHydrating notifies listeners (triggers GoRouter re-evaluation)',
        () {
      final provider = CoachProfileProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      provider.startHydrating();
      expect(notified, isTrue,
          reason:
              'startHydrating must call notifyListeners for GoRouter refresh');
    });

    test('finishHydrating notifies listeners (triggers GoRouter re-evaluation)',
        () {
      final provider = CoachProfileProvider();
      provider.startHydrating();

      var notified = false;
      provider.addListener(() => notified = true);

      provider.finishHydrating();
      expect(notified, isTrue,
          reason:
              'finishHydrating must call notifyListeners for GoRouter refresh');
    });

    test('clear resets isHydrating to false even when the secure purge '
        'defers to a startup retry', () async {
      final provider = CoachProfileProvider();
      provider.startHydrating();
      expect(provider.isHydrating, isTrue);

      // Depuis la bascule 2, une purge sécurisée qui n'aboutit pas SIGNALE
      // son report au lieu de prétendre avoir réussi — c'est le cas en test,
      // où le coffre est simulé. L'invariant à protéger reste que l'état
      // d'hydratation retombe, réussite ou report.
      try {
        await provider.clear();
      } on StateError catch (error) {
        expect(error.message, contains('startup retry'));
      }
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

    testWidgets(
        'auth completion triggers active coach profile reload through provider tree',
        (tester) async {
      final auth = _AuthProviderStub();
      final coach = _ReloadTrackingCoachProfileProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProxyProvider<AuthProvider, CoachProfileProvider>(
              lazy: false,
              create: (_) => coach,
              update: (_, auth, provider) {
                final coachProvider = provider ?? CoachProfileProvider();
                if (auth.isLoggedIn && !auth.isLoading) {
                  coachProvider.reloadAfterAuthBackendHydration();
                }
                return coachProvider;
              },
            ),
          ],
          child: const MaterialApp(home: SizedBox.shrink()),
        ),
      );

      expect(coach.reloadCalls, 0);

      auth.setAuthState(isLoggedIn: true, isLoading: false);
      await tester.pump();

      expect(coach.reloadCalls, 1);
    });
  });
}
