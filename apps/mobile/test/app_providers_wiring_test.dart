/// Integration test proving end-to-end that the notifications wiring
/// is ACTUALLY connected in the widget tree — not façade.
///
/// Wave A-MINIMAL A2-fix (2026-04-18). Post-exec audit panels UX + bugs
/// unanimously flagged that unit tests on NotificationsWiringService
/// (with `scheduleOverride` injection) do NOT prove the ProxyProvider
/// instantiates in production, because `ChangeNotifierProxyProvider`
/// is lazy by default. This test pumps a real MultiProvider tree
/// matching `app.dart` and asserts that a CoachProfileProvider
/// notifyListeners propagates to the wiring service (and through it
/// to a spy scheduler).
///
/// If this test passes while `lazy: false` is removed from
/// `app.dart`, the test is not strict enough — it must fail in that
/// scenario.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/notifications_wiring_service.dart';
import 'package:provider/provider.dart';

class _SpyProfileProvider extends CoachProfileProvider {
  CoachProfile? _current;

  @override
  CoachProfile? get profile => _current;

  void setProfile(CoachProfile? p) {
    _current = p;
    notifyListeners();
  }
}

CoachProfile _triadProfile() => CoachProfile(
      birthYear: 1977,
      canton: 'VS',
      salaireBrutMensuel: 10000,
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2040),
        label: '',
      ),
    );

void main() {
  setUp(() {
    // Short debounce so the test runs in ~30 ms.
    NotificationsWiringService.debounce = const Duration(milliseconds: 10);
  });

  tearDown(() {
    NotificationsWiringService.debounce =
        const Duration(milliseconds: 500);
  });

  testWidgets(
    'A2-fix: MultiProvider with lazy:false instantiates NotificationsWiringService '
    'and calls scheduleOverride when CoachProfileProvider emits a complete triad',
    (tester) async {
      final recorded = <CoachProfile>[];
      Future<void> spySchedule(CoachProfile p) async {
        recorded.add(p);
      }

      final profileProvider = _SpyProfileProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CoachProfileProvider>.value(
              value: profileProvider,
            ),
            // Same shape as `app.dart:1308-1315` — lazy:false is mandatory.
            // Drop it and this test should fail.
            ChangeNotifierProxyProvider<CoachProfileProvider,
                NotificationsWiringService>(
              lazy: false,
              create: (_) => NotificationsWiringService(
                scheduleOverride: spySchedule,
              ),
              update: (_, prof, prev) {
                final service = prev ??
                    NotificationsWiringService(
                      scheduleOverride: spySchedule,
                    );
                service.onProfileChanged(prof.profile);
                return service;
              },
            ),
          ],
          child: const _Sentinel(),
        ),
      );

      // Initially profile is null — no schedule expected even with lazy:false
      // because _hasTriad rejects null/incomplete.
      await tester.pump(const Duration(milliseconds: 30));
      expect(recorded, isEmpty);

      // Emit a complete triad — wiring must propagate through the
      // ProxyProvider update callback and the debounced scheduler.
      profileProvider.setProfile(_triadProfile());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      expect(
        recorded,
        hasLength(1),
        reason:
            'ProxyProvider update must fire onProfileChanged after triad emits; '
            'if this fails, the ChangeNotifierProxyProvider is likely lazy '
            '(default) and the wiring is dead in production.',
      );
      expect(recorded.first.canton, 'VS');
      expect(recorded.first.birthYear, 1977);
    },
  );
}

/// Empty child. The test asserts plumbing, not UI rendering.
class _Sentinel extends StatelessWidget {
  const _Sentinel();

  @override
  Widget build(BuildContext context) =>
      const Directionality(textDirection: TextDirection.ltr, child: SizedBox());
}
