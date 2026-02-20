import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('initial state is empty', () {
    final provider = UserActivityProvider();
    expect(provider.exploredSimulators, isEmpty);
    expect(provider.exploredLifeEvents, isEmpty);
    expect(provider.dismissedTips, isEmpty);
    expect(provider.snoozedTips, isEmpty);
    expect(provider.isLoaded, isFalse);
  });

  test('loadAll hydrates from SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({
      'explored_simulators_v1': ['budget', '3a'],
      'explored_life_events_v1': ['marriage'],
      'dismissed_tips_v1': ['tip_1'],
    });

    final provider = UserActivityProvider();
    await provider.loadAll();

    expect(provider.isLoaded, isTrue);
    expect(provider.exploredSimulators, {'budget', '3a'});
    expect(provider.exploredLifeEvents, {'marriage'});
    expect(provider.dismissedTips, {'tip_1'});
    expect(provider.isSimulatorExplored('budget'), isTrue);
    expect(provider.isSimulatorExplored('mortgage'), isFalse);
    expect(provider.isLifeEventExplored('marriage'), isTrue);
  });

  test('loadAll is idempotent', () async {
    final provider = UserActivityProvider();
    await provider.loadAll();
    await provider.markSimulatorExplored('budget');
    // Second loadAll should not reset state
    await provider.loadAll();
    expect(provider.isSimulatorExplored('budget'), isTrue);
  });

  test('markSimulatorExplored persists and notifies', () async {
    final provider = UserActivityProvider();
    await provider.loadAll();

    int notifyCount = 0;
    provider.addListener(() => notifyCount++);

    await provider.markSimulatorExplored('budget');
    expect(provider.isSimulatorExplored('budget'), isTrue);
    expect(notifyCount, 1);

    // Duplicate should not notify
    await provider.markSimulatorExplored('budget');
    expect(notifyCount, 1);

    // Verify persistence
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('explored_simulators_v1'), contains('budget'));
  });

  test('markLifeEventExplored persists and notifies', () async {
    final provider = UserActivityProvider();
    await provider.loadAll();

    await provider.markLifeEventExplored('divorce');
    expect(provider.isLifeEventExplored('divorce'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs.getStringList('explored_life_events_v1'), contains('divorce'));
  });

  test('dismissTip removes from snoozed and persists', () async {
    final provider = UserActivityProvider();
    await provider.loadAll();

    // Snooze first, then dismiss
    await provider.snoozeTip('tip_1', const Duration(days: 30));
    expect(provider.isTipActive('tip_1'), isFalse);

    await provider.dismissTip('tip_1');
    expect(provider.isTipActive('tip_1'), isFalse);
    expect(provider.dismissedTips, contains('tip_1'));
    expect(provider.snoozedTips, isNot(contains('tip_1')));
  });

  test('snoozeTip makes tip inactive until expiry', () async {
    final provider = UserActivityProvider();
    await provider.loadAll();

    expect(provider.isTipActive('tip_1'), isTrue);

    await provider.snoozeTip('tip_1', const Duration(days: 30));
    expect(provider.isTipActive('tip_1'), isFalse);
  });

  test('expired snooze tip is active again', () async {
    final provider = UserActivityProvider();
    await provider.loadAll();

    // Snooze with negative duration (already expired)
    await provider.snoozeTip('tip_1', const Duration(seconds: -1));
    expect(provider.isTipActive('tip_1'), isTrue);
  });

  test('clearAll resets everything', () async {
    final provider = UserActivityProvider();
    await provider.loadAll();

    await provider.markSimulatorExplored('budget');
    await provider.markLifeEventExplored('marriage');
    await provider.dismissTip('tip_1');

    await provider.clearAll();

    expect(provider.exploredSimulators, isEmpty);
    expect(provider.exploredLifeEvents, isEmpty);
    expect(provider.dismissedTips, isEmpty);
    expect(provider.snoozedTips, isEmpty);
    expect(provider.isLoaded, isFalse);
  });

  test('snoozed tips hydration filters expired entries', () async {
    // Snoozed tip with past date should not be loaded
    final pastDate =
        DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
    final futureDate =
        DateTime.now().add(const Duration(days: 30)).toIso8601String();

    SharedPreferences.setMockInitialValues({
      'snoozed_tips_v1': '{"tip_expired":"$pastDate","tip_active":"$futureDate"}',
    });

    final provider = UserActivityProvider();
    await provider.loadAll();

    expect(provider.snoozedTips, isNot(contains('tip_expired')));
    expect(provider.snoozedTips.containsKey('tip_active'), isTrue);
    expect(provider.isTipActive('tip_expired'), isTrue);
    expect(provider.isTipActive('tip_active'), isFalse);
  });
}
