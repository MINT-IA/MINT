import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpFrames(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _FakeNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  @override
  Future<NotificationAppLaunchDetails?>
      getNotificationAppLaunchDetails() async {
    return null;
  }
}

void main() {
  testWidgets(
      'the production app proxy eagerly recomputes exactly once per profile mutation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    FlutterLocalNotificationsPlatform.instance = _FakeNotificationsPlatform();
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(const MintApp());
    await _pumpFrames(tester);

    final appContext = tester.element(find.byType(MaterialApp));
    final profileProvider = appContext.read<CoachProfileProvider>();
    profileProvider.updateFromAnswers(const {
      'q_birth_year': 1985,
      'q_canton': 'VD',
      'q_gross_salary_annual': 96000,
    });
    await _pumpFrames(tester);

    // This first read must observe already-computed state. If reading the
    // provider itself materialises a lazy proxy, production mutations that
    // happen without a MintState consumer are silently lost.
    final stateProvider = appContext.read<MintStateProvider>();
    expect(stateProvider.hasState, isTrue);
    expect(stateProvider.state!.profile.salaireBrutMensuel, 8000);

    var notifications = 0;
    stateProvider.addListener(() => notifications++);

    final salaryMutation = profileProvider.profile!.copyWith(
      salaireBrutMensuel: 9000,
      updatedAt: DateTime.utc(2026, 7, 12, 12, 1),
    );
    profileProvider.updateProfile(salaryMutation);
    await _pumpFrames(tester);

    expect(notifications, 1);
    expect(stateProvider.state!.profile, same(salaryMutation));

    final provenanceMutation = salaryMutation.copyWith(
      dataSources: const {
        'salaireBrutMensuel': ProfileDataSource.certificate,
      },
      updatedAt: DateTime.utc(2026, 7, 12, 12, 2),
    );
    profileProvider.updateProfile(provenanceMutation);
    await _pumpFrames(tester);

    expect(notifications, 2);
    expect(stateProvider.state!.profile, same(provenanceMutation));
    expect(
      stateProvider.state!.profile.dataSources['salaireBrutMensuel'],
      ProfileDataSource.certificate,
    );
    // updateProfile persists asynchronously; drain SecureWizardStore's
    // bounded timeout before Flutter verifies that no test timers leaked.
    await _pumpFrames(tester, frames: 60);
    debugDefaultTargetPlatformOverride = null;
  });
}
