import 'dart:convert';
import 'dart:async';
import 'dart:ui' show CheckedState, SemanticsAction, Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/tension_card.dart';
import 'package:mint_mobile/models/timeline_node.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/providers/timeline_provider.dart';
import 'package:mint_mobile/routes/mint_next_3a_route_gate.dart';
import 'package:mint_mobile/screens/aujourdhui/aujourdhui_screen.dart';
import 'package:mint_mobile/screens/mint_next_3a/mint_next_3a_handoff_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/mint_next_3a_task_store.dart';
import 'package:mint_mobile/widgets/aujourdhui/mint_next_3a_handoff_card.dart';

const _taskStorageKey = 'mint_next_3a_task_v1';
const _secureChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

class _SecureStoreProbe {
  _SecureStoreProbe([Map<String, String>? seed])
      : values = Map<String, String>.from(seed ?? const {});

  final Map<String, String> values;
  final List<String> readKeys = [];
  bool failNextWrite = false;
  int failReadsAfterWrite = 0;
  int _readsAfterWriteRemaining = 0;
  bool failRead = false;
  bool failDelete = false;
  Completer<void>? writeGate;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, (call) async {
      final arguments = call.arguments is Map
          ? Map<String, dynamic>.from(call.arguments as Map)
          : <String, dynamic>{};
      final key = arguments['key'] as String?;
      switch (call.method) {
        case 'write':
          if (failNextWrite) {
            failNextWrite = false;
            throw PlatformException(code: 'write_failed');
          }
          await writeGate?.future;
          final value = arguments['value'] as String?;
          if (key != null && value != null) values[key] = value;
          _readsAfterWriteRemaining = failReadsAfterWrite;
          return null;
        case 'read':
          if (_readsAfterWriteRemaining > 0) {
            _readsAfterWriteRemaining--;
            throw PlatformException(code: 'verify_read_failed');
          }
          if (failRead) throw PlatformException(code: 'read_failed');
          if (key != null) readKeys.add(key);
          return key == null ? null : values[key];
        case 'delete':
          if (failDelete) throw PlatformException(code: 'delete_failed');
          if (key != null) values.remove(key);
          return null;
        case 'deleteAll':
          values.clear();
          return null;
        case 'readAll':
          return Map<String, String>.from(values);
        case 'containsKey':
          return key != null && values.containsKey(key);
      }
      return null;
    });
  }
}

class _MemoryTaskAdapter implements MintNext3aTaskStorageAdapter {
  String? value;
  Completer<void>? readGate;
  bool failWrite = false;

  @override
  Future<void> delete(String key) async => value = null;

  @override
  Future<String?> read(String key) async {
    await readGate?.future;
    return value;
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('write failed');
    this.value = value;
  }
}

late _SecureStoreProbe _secureProbe;

class _SeededProfileProvider extends CoachProfileProvider {
  _SeededProfileProvider(this._profile);
  final CoachProfile _profile;
  @override
  CoachProfile? get profile => _profile;
}

class _EmptyTimeline extends TimelineProvider {
  @override
  bool get isLoading => false;
  @override
  bool get isEmpty => true;
  @override
  bool get hasNodes => false;
  @override
  bool get hasMore => false;
  @override
  List<TimelineMonth> get months => const [];
  @override
  CleoLoopPosition get loopPosition => CleoLoopPosition.insight;
  @override
  List<TensionCard> get cards => const [];
  @override
  Future<void> refresh() async {}
}

CoachProfile _profile() => CoachProfile(
      birthYear: 1996,
      canton: 'ZH',
      salaireBrutMensuel: 6500,
      employmentStatus: 'salarie',
      userProvidedFields: const {'age'},
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2066),
        label: 'red-contract',
      ),
    );

Finder _semantic(String id) => find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.identifier == id,
    );

Future<void> _withSemantics(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final handle = tester.ensureSemantics();
  try {
    await body();
  } finally {
    handle.dispose();
  }
}

Widget _realTodayHarness({
  Locale locale = const Locale('fr'),
  TextScaler textScaler = TextScaler.noScaling,
  String initialLocation = '/home',
  MintNext3aTaskStore? taskStore,
  DateTime Function()? now,
  void Function(GoRouter router)? onRouter,
  void Function()? onHandoffBuild,
  bool disableAnimations = false,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, __) => const AujourdhuiScreen(),
      ),
      GoRoute(
        path: '/mint-next/3a',
        redirect: (_, state) => mintNext3aRouteRedirect(
          flagEnabled: FeatureFlags.enableMintNext3aProductHandoff,
          extra: state.extra,
        ),
        builder: (_, __) {
          onHandoffBuild?.call();
          return MintNext3aHandoffScreen(
            store: taskStore ?? const MintNext3aTaskStore(),
            now: now,
          );
        },
      ),
    ],
  );
  onRouter?.call(router);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>(
        create: (_) => _SeededProfileProvider(_profile()),
      ),
      ChangeNotifierProvider<TimelineProvider>(create: (_) => _EmptyTimeline()),
      ChangeNotifierProvider<FinancialPlanProvider>(
        create: (_) => FinancialPlanProvider(),
      ),
      ChangeNotifierProvider<MintStateProvider>(
        create: (_) => MintStateProvider(),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: locale,
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: textScaler,
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
    ),
  );
}

Future<void> _mountRealToday(
  WidgetTester tester, {
  bool handoffEnabled = true,
  Size size = const Size(1200, 6000),
  Locale locale = const Locale('fr'),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  FeatureFlags.enableMintNext3aProductHandoff = handoffEnabled;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    _realTodayHarness(locale: locale, textScaler: textScaler),
  );
  await tester.pumpAndSettle();
  expect(_semantic('home_route_state'), findsOneWidget);
}

Future<void> _openMissingHandoff(WidgetTester tester) async {
  final entry = _semantic('action:today.open_mint_next_3a');
  if (entry.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      entry,
      120,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  expect(
    entry,
    findsOneWidget,
    reason: 'missing true Today entry action:today.open_mint_next_3a',
  );
  await tester.ensureVisible(entry);
  await tester.tap(entry);
  await tester.pumpAndSettle();
}

Future<void> _tapSemantic(WidgetTester tester, String id) async {
  final target = _semantic(id);
  expect(target, findsOneWidget, reason: 'missing product interaction $id');
  final interactive = find.descendant(
    of: target,
    matching: find.byWidgetPredicate(
      (widget) => widget is InkWell || widget is ButtonStyleButton,
    ),
  );
  final label = find.descendant(of: target, matching: find.byType(Text));
  final geometry = label.evaluate().isEmpty ? target : label.first;
  final viewportHeight =
      tester.view.physicalSize.height / tester.view.devicePixelRatio;
  await tester.ensureVisible(geometry);
  await tester.pumpAndSettle();
  for (var attempt = 0; attempt < 12; attempt++) {
    final rect = tester.getRect(geometry);
    final visibleHeight = rect.bottom.clamp(0.0, viewportHeight) -
        rect.top.clamp(0.0, viewportHeight);
    if ((rect.height <= viewportHeight &&
            rect.top >= 0 &&
            rect.bottom <= viewportHeight) ||
        (rect.height > viewportHeight && visibleHeight >= 48)) {
      break;
    }
    final list = find.ancestor(of: geometry, matching: find.byType(ListView));
    if (list.evaluate().isEmpty) {
      await tester.ensureVisible(geometry);
      break;
    }
    final distance = rect.top < 0
        ? rect.top.abs().clamp(48.0, 240.0)
        : -((rect.bottom - viewportHeight).clamp(48.0, 240.0));
    await tester.drag(list.first, Offset(0, distance.toDouble()));
    await tester.pumpAndSettle();
  }
  final visibleRect = tester.getRect(geometry);
  final visibleHeight = visibleRect.bottom.clamp(0.0, viewportHeight) -
      visibleRect.top.clamp(0.0, viewportHeight);
  if (visibleRect.height <= viewportHeight) {
    expect(visibleRect.top, greaterThanOrEqualTo(0),
        reason: '$id top safe-area; rect=$visibleRect');
    expect(visibleRect.bottom, lessThanOrEqualTo(viewportHeight),
        reason: '$id must be visible before activation; rect=$visibleRect');
  } else {
    expect(visibleHeight, greaterThanOrEqualTo(48),
        reason:
            '$id must expose a reachable viewport segment; rect=$visibleRect');
  }
  if (id.startsWith('action:') || id.startsWith('choice:')) {
    final targetSize = interactive.evaluate().isEmpty
        ? tester.getSize(target)
        : tester.getSize(interactive.first);
    expect(targetSize.height, greaterThanOrEqualTo(48),
        reason: '$id must keep a 48dp target');
  }
  if (visibleRect.height > viewportHeight) {
    await tester.tapAt(Offset(
      visibleRect.center.dx,
      (visibleRect.top + 24).clamp(24.0, viewportHeight - 24),
    ));
  } else {
    await tester.tap(target);
  }
  await tester.pumpAndSettle();
}

Future<void> _completeTeachBack(WidgetTester tester) async {
  expect(_semantic('node:3a.teach_back'), findsOneWidget);
  expect(_semantic('status:tax.personal_unavailable'), findsOneWidget);
  await _tapSemantic(tester, 'choice:3a.teach_back.latest_payment_only');
  await _tapSemantic(tester, 'action:3a.teach_back.check');
  expect(_semantic('feedback:3a.teach_back.retry'), findsOneWidget);
  final retryContext = tester.element(_semantic('action:3a.teach_back.retry'));
  expect(find.text(S.of(retryContext)!.commonRetry), findsOneWidget);
  expect(_semantic('action:3a.task.save'), findsNothing);
  await _tapSemantic(tester, 'action:3a.teach_back.retry');
  await _tapSemantic(tester, 'choice:3a.teach_back.annual_total_all_accounts');
  await _tapSemantic(tester, 'action:3a.teach_back.check');
  expect(_semantic('feedback:3a.teach_back.correct'), findsOneWidget);
  await _tapSemantic(tester, 'action:3a.teach_back.continue');
  expect(_semantic('node:3a.task_preview'), findsOneWidget);
  expect(_semantic('disclosure:3a.task.local_only'), findsOneWidget);
  expect(_semantic('task:today.3a.verify_annual_credited_total'), findsNothing);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _secureProbe = _SecureStoreProbe()..install();
  });

  tearDown(() {
    FeatureFlags.enableMintNext3aProductHandoff = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, null);
  });

  testWidgets('existing real Today remains usable without product handoff', (
    tester,
  ) async {
    await _mountRealToday(tester, handoffEnabled: false);
    expect(_semantic('home_route_state'), findsOneWidget);
    expect(_semantic('action:today.open_mint_next_3a'), findsNothing);
  });

  testWidgets('flag off blocks direct and stale deep-link entry before render',
      (
    tester,
  ) async {
    FeatureFlags.enableMintNext3aProductHandoff = false;

    for (final location in const [
      '/mint-next/3a',
      '/mint-next/3a?source=stale',
    ]) {
      await tester.pumpWidget(_realTodayHarness(initialLocation: location));
      await tester.pumpAndSettle();

      expect(_semantic('home_route_state'), findsOneWidget);
      expect(find.byType(MintNext3aHandoffScreen), findsNothing);
      expect(_semantic('node:3a.teach_back'), findsNothing);
      expect(_semantic('node:3a.task_detail'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('untrusted route extras cannot bypass the flag-off gate', (
    tester,
  ) async {
    FeatureFlags.enableMintNext3aProductHandoff = false;
    late GoRouter router;
    await tester.pumpWidget(_realTodayHarness(onRouter: (value) {
      router = value;
    }));
    await tester.pumpAndSettle();

    for (final extra in <Object?>[
      'today',
      const {'source': 'today'},
      Object(),
    ]) {
      unawaited(router.push('/mint-next/3a', extra: extra));
      await tester.pumpAndSettle();
      expect(_semantic('home_route_state'), findsOneWidget);
      expect(find.byType(MintNext3aHandoffScreen), findsNothing);
    }
  });

  testWidgets('direct entry stays blocked when an owned task already exists', (
    tester,
  ) async {
    FeatureFlags.enableMintNext3aProductHandoff = false;
    _secureProbe.values[_taskStorageKey] = jsonEncode(MintNext3aTask(
      taxYear: 2026,
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
      expiresAt: DateTime.utc(2027, 1, 31, 23, 59, 59),
    ).toJson());

    await tester.pumpWidget(
      _realTodayHarness(initialLocation: '/mint-next/3a'),
    );
    await tester.pumpAndSettle();

    expect(_semantic('home_route_state'), findsOneWidget);
    expect(
      _semantic('task:today.3a.verify_annual_credited_total'),
      findsOneWidget,
    );
    expect(find.byType(MintNext3aHandoffScreen), findsNothing);
    expect(_semantic('node:3a.task_detail'), findsNothing);
  });

  testWidgets('flag on keeps direct route available', (tester) async {
    FeatureFlags.enableMintNext3aProductHandoff = true;
    await tester.pumpWidget(
      _realTodayHarness(initialLocation: '/mint-next/3a'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MintNext3aHandoffScreen), findsOneWidget);
    expect(_semantic('node:3a.teach_back'), findsOneWidget);
  });

  testWidgets('stale creation callback cannot cross a flag-off refresh', (
    tester,
  ) async {
    FeatureFlags.enableMintNext3aProductHandoff = true;
    var handoffBuilds = 0;
    await tester.pumpWidget(_realTodayHarness(
      onHandoffBuild: () => handoffBuilds++,
    ));
    await tester.pumpAndSettle();
    final staleOnTap = tester
        .widget<Semantics>(_semantic('action:today.open_mint_next_3a'))
        .properties
        .onTap!;

    FeatureFlags.enableMintNext3aProductHandoff = false;
    staleOnTap();
    await tester.pumpAndSettle();

    expect(_semantic('home_route_state'), findsOneWidget);
    expect(handoffBuilds, 0);
    expect(find.byType(MintNext3aHandoffScreen), findsNothing);
  });

  testWidgets('real Today opens bounded 3a handoff before teach-back', (
    tester,
  ) async {
    await _withSemantics(tester, () async {
      await _mountRealToday(tester);
      final entry = tester.widget<Semantics>(
        _semantic('action:today.open_mint_next_3a'),
      );
      expect(entry.properties.button, isTrue);
      expect(entry.properties.onTap, isNotNull);
      final homeL10n = S.of(tester.element(
        _semantic('action:today.open_mint_next_3a'),
      ))!;
      expect(
        find.descendant(
          of: _semantic('action:today.open_mint_next_3a'),
          matching: find.text(homeL10n.promiseCta),
        ),
        findsOneWidget,
      );
      await _openMissingHandoff(tester);
      expect(_semantic('node:3a.teach_back'), findsOneWidget);
      final l10n = S.of(tester.element(_semantic('node:3a.teach_back')))!;
      expect(
        tester.semantics.simulatedAccessibilityTraversal().where((node) {
          final data = node.getSemanticsData();
          return data.flagsCollection.namesRoute &&
              data.label == l10n.mintNext3aTaskTitle;
        }),
        hasLength(1),
      );
    });
  });

  testWidgets('screen reader gets one labelled Today entry action', (
    tester,
  ) async {
    await _withSemantics(tester, () async {
      await _mountRealToday(tester);

      final entry = tester.getSemantics(
        _semantic('action:today.open_mint_next_3a'),
      );
      final data = entry.getSemanticsData();
      expect(data.label.trim(), isNotEmpty,
          reason: 'the identified entry must carry its spoken label');
      final l10n = S.of(tester.element(
        _semantic('action:today.open_mint_next_3a'),
      ))!;
      expect(data.label, startsWith(l10n.mintNext3aTeachBackQuestion),
          reason: 'the accessible name must contain the visible headline');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue,
          reason: 'label, role and activation must live on the same node');
      expect(entry.rect.height, greaterThanOrEqualTo(48));
    });
  });

  testWidgets('screen reader gets one route name and grouped choices', (
    tester,
  ) async {
    await _withSemantics(tester, () async {
      await _mountRealToday(tester);
      await _openMissingHandoff(tester);

      final l10n = S.of(tester.element(_semantic('node:3a.teach_back')))!;
      final traversal = tester.semantics
          .simulatedAccessibilityTraversal()
          .map((node) => node.getSemanticsData())
          .toList();
      final namedRoutes = traversal.where(
        (data) =>
            data.flagsCollection.namesRoute &&
            data.label == l10n.mintNext3aTaskTitle,
      );
      expect(namedRoutes, hasLength(1),
          reason: 'the current destination must be announced exactly once');

      final disabledCheck = tester.getSemantics(
        _semantic('action:3a.teach_back.check'),
      );
      expect(disabledCheck.flagsCollection.isEnabled, Tristate.isFalse);
      expect(
        disabledCheck.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
        reason: 'check must remain unavailable until an answer is selected',
      );
      expect(
        traversal,
        containsAllInOrder([
          isSemantics(label: l10n.mintNext3aTeachBackQuestion, isHeader: true),
          isSemantics(label: l10n.mintNext3aPersonalUnavailable),
          isSemantics(label: l10n.mintNext3aTeachBackChoiceAnnualTotal),
          isSemantics(label: l10n.mintNext3aTeachBackChoiceLatestPayment),
          isSemantics(label: l10n.mintNext3aTeachBackChoicePayMax),
          isSemantics(label: l10n.mintNext3aCountingHelpTitle),
          isSemantics(label: l10n.capCoverageCheckCtaLabel, isEnabled: false),
          isSemantics(label: l10n.mintNext3aSafeExitTitle),
        ]),
      );

      for (final id in const [
        'choice:3a.teach_back.latest_payment_only',
        'choice:3a.teach_back.annual_total_all_accounts',
        'choice:3a.teach_back.pay_max_without_checking',
      ]) {
        final choice = tester.getSemantics(_semantic(id)).getSemanticsData();
        expect(choice.label.trim(), isNotEmpty);
        expect(choice.flagsCollection.isInMutuallyExclusiveGroup, isTrue,
            reason: '$id must expose that only one answer can be selected');
        expect(choice.flagsCollection.isButton, isFalse,
            reason: '$id must expose a radio choice, not a button');
        expect(choice.flagsCollection.isChecked, CheckedState.isFalse);
        expect(choice.hasAction(SemanticsAction.tap), isTrue);
        expect(tester.getSemantics(_semantic(id)).rect.height,
            greaterThanOrEqualTo(48));
      }
      await _tapSemantic(
          tester, 'choice:3a.teach_back.annual_total_all_accounts');
      expect(
        tester
            .getSemantics(
              _semantic('choice:3a.teach_back.annual_total_all_accounts'),
            )
            .flagsCollection
            .isChecked,
        CheckedState.isTrue,
      );
      for (final id in const [
        'choice:3a.teach_back.latest_payment_only',
        'choice:3a.teach_back.pay_max_without_checking',
      ]) {
        expect(tester.getSemantics(_semantic(id)).flagsCollection.isChecked,
            CheckedState.isFalse);
      }
      final enabledCheck = tester.getSemantics(
        _semantic('action:3a.teach_back.check'),
      );
      expect(enabledCheck.flagsCollection.isEnabled, Tristate.isTrue);
      expect(enabledCheck.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });
  });

  testWidgets('screen reader choice flags follow Flutter radio platforms', (
    tester,
  ) async {
    await _withSemantics(tester, () async {
      try {
        for (final platform in const [
          TargetPlatform.android,
          TargetPlatform.iOS,
        ]) {
          debugDefaultTargetPlatformOverride = platform;
          _secureProbe.values.clear();
          await _mountRealToday(tester);
          await _openMissingHandoff(tester);
          await _tapSemantic(
              tester, 'choice:3a.teach_back.annual_total_all_accounts');
          final selected = tester.getSemantics(
            _semantic('choice:3a.teach_back.annual_total_all_accounts'),
          );
          final unselected = tester.getSemantics(
            _semantic('choice:3a.teach_back.latest_payment_only'),
          );
          expect(selected.flagsCollection.isChecked, CheckedState.isTrue);
          expect(selected.flagsCollection.isButton, isFalse);
          expect(
            selected.flagsCollection.isSelected,
            platform == TargetPlatform.iOS ? Tristate.isTrue : Tristate.none,
          );
          expect(
            unselected.hint,
            platform == TargetPlatform.iOS
                ? WidgetsLocalizations.of(tester.element(
                    _semantic('choice:3a.teach_back.latest_payment_only'),
                  )).radioButtonUnselectedLabel
                : isEmpty,
          );
          await tester.pumpWidget(const SizedBox.shrink());
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  testWidgets('screen reader gets labelled controls on the teach-back step', (
    tester,
  ) async {
    await _withSemantics(tester, () async {
      await _mountRealToday(tester);
      await _openMissingHandoff(tester);
      await _tapSemantic(tester, 'choice:3a.teach_back.latest_payment_only');

      for (final id in const [
        'action:3a.safe_exit.open',
        'action:3a.teach_back.check',
      ]) {
        final control = tester.getSemantics(_semantic(id));
        final data = control.getSemanticsData();
        expect(data.label.trim(), isNotEmpty,
            reason: '$id must carry its spoken label on the actionable node');
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(control.rect.height, greaterThanOrEqualTo(48));
      }
    });
  });

  testWidgets('screen reader gets headings and atomic live state changes', (
    tester,
  ) async {
    await _withSemantics(tester, () async {
      await _mountRealToday(tester);
      await _openMissingHandoff(tester);
      var l10n = S.of(tester.element(_semantic('node:3a.teach_back')))!;

      expect(
        tester
            .getSemantics(find.text(l10n.mintNext3aTeachBackQuestion))
            .flagsCollection
            .isHeader,
        isTrue,
      );
      await _tapSemantic(tester, 'choice:3a.teach_back.latest_payment_only');
      await _tapSemantic(tester, 'action:3a.teach_back.check');
      var feedback = tester.getSemantics(
        _semantic('feedback:3a.teach_back.retry'),
      );
      expect(feedback.flagsCollection.isLiveRegion, isTrue);
      expect(feedback.label, l10n.mintNext3aTeachBackFeedbackRetry);
      expect(
          feedback.getSemanticsData().hasAction(SemanticsAction.tap), isFalse,
          reason: 'the announcement must not absorb the retry control');

      await _tapSemantic(tester, 'action:3a.teach_back.retry');
      await _tapSemantic(
          tester, 'choice:3a.teach_back.annual_total_all_accounts');
      await _tapSemantic(tester, 'action:3a.teach_back.check');
      feedback = tester.getSemantics(
        _semantic('feedback:3a.teach_back.correct'),
      );
      expect(feedback.flagsCollection.isLiveRegion, isTrue);
      expect(feedback.label, l10n.mintNext3aTeachBackFeedbackCorrect);
      await _tapSemantic(tester, 'action:3a.teach_back.continue');
      expect(
        tester
            .getSemantics(find.descendant(
              of: _semantic('node:3a.task_preview'),
              matching: find.text(l10n.mintNext3aTaskTitle),
            ))
            .flagsCollection
            .isHeader,
        isTrue,
      );

      _secureProbe.failNextWrite = true;
      await _tapSemantic(tester, 'action:3a.task.save');
      final storageFailure = tester.getSemantics(
        _semantic('status:3a.task.storage_failed'),
      );
      expect(storageFailure.flagsCollection.isLiveRegion, isTrue);
      expect(
        storageFailure.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
        reason:
            'the failure announcement must not absorb retry or exit actions',
      );
      final retry = tester.getSemantics(
        _semantic('action:3a.task.storage_retry'),
      );
      expect(retry.label, l10n.mintNext3aSave);
      expect(retry.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      await _tapSemantic(tester, 'action:3a.task.storage_retry');
      l10n = S.of(tester.element(_semantic('node:3a.task_saved')))!;
      expect(
        tester
            .getSemantics(find.text(l10n.mintNext3aSavedTitle))
            .flagsCollection
            .isHeader,
        isTrue,
      );
    });
  });

  testWidgets('screen reader dialog is isolated, ordered and actionable', (
    tester,
  ) async {
    await _withSemantics(tester, () async {
      await _mountRealToday(tester);
      await _openMissingHandoff(tester);
      final l10n = S.of(tester.element(_semantic('node:3a.teach_back')))!;
      await _tapSemantic(tester, 'action:3a.safe_exit.open');

      final traversal = tester.semantics
          .simulatedAccessibilityTraversal()
          .map((node) => node.getSemanticsData())
          .toList();
      final dialogScope = find.semantics.byPredicate(
        (node) =>
            node.flagsCollection.scopesRoute && node.flagsCollection.namesRoute,
      );
      expect(dialogScope, findsOne);
      expect(
        traversal,
        containsAllInOrder([
          isSemantics(label: l10n.mintNext3aSafeExitTitle),
          isSemantics(label: l10n.mintNext3aSafeExitBody),
          isSemantics(
            label: l10n.mintNext3aSafeExitResume,
            isButton: true,
            hasTapAction: true,
          ),
          isSemantics(
            label: l10n.mintNext3aSafeExitLeave,
            isButton: true,
            hasTapAction: true,
          ),
        ]),
      );
      expect(
        traversal.where(
          (data) => data.identifier == 'action:3a.teach_back.check',
        ),
        isEmpty,
        reason: 'background controls must leave modal accessibility traversal',
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await _tapSemantic(tester, 'action:3a.safe_exit.resume');
    });
  });

  testWidgets('screen reader critical labels survive all six locales', (
    tester,
  ) async {
    await _withSemantics(tester, () async {
      for (final locale in const ['fr', 'en', 'de', 'it', 'es', 'pt']) {
        _secureProbe.values.clear();
        await _mountRealToday(tester, locale: Locale(locale));
        final todayL10n = S.of(tester.element(
          _semantic('action:today.open_mint_next_3a'),
        ))!;
        final today = tester.getSemantics(
          _semantic('action:today.open_mint_next_3a'),
        );
        expect(today.label, startsWith(todayL10n.mintNext3aTeachBackQuestion),
            reason:
                'Today accessible name must match visible title in $locale');
        expect(today.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

        await _openMissingHandoff(tester);
        final l10n = S.of(tester.element(_semantic('node:3a.teach_back')))!;
        expect(
          tester.semantics.simulatedAccessibilityTraversal().where((node) {
            final data = node.getSemanticsData();
            return data.flagsCollection.namesRoute &&
                data.label == l10n.mintNext3aTaskTitle;
          }),
          hasLength(1),
          reason: 'route name must stay singular in $locale',
        );
        for (final id in const [
          'choice:3a.teach_back.latest_payment_only',
          'choice:3a.teach_back.annual_total_all_accounts',
          'choice:3a.teach_back.pay_max_without_checking',
        ]) {
          final choice = tester.getSemantics(_semantic(id));
          expect(choice.label.trim(), isNotEmpty, reason: '$id in $locale');
          expect(choice.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
          expect(
              choice.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });

  testWidgets('screen reader keeps saved task and delete journey atomic', (
    tester,
  ) async {
    await _withSemantics(tester, () async {
      await _mountRealToday(tester);
      await _openMissingHandoff(tester);
      await _completeTeachBack(tester);
      await _tapSemantic(tester, 'action:3a.task.save');
      await _tapSemantic(tester, 'action:3a.task.return_today');

      final l10n = S.of(tester.element(
        _semantic('action:today.3a_task.open'),
      ))!;
      final todayTask = tester.getSemantics(
        _semantic('action:today.3a_task.open'),
      );
      expect(todayTask.label, startsWith(l10n.mintNext3aTaskTitle));
      expect(todayTask.flagsCollection.isButton, isTrue);
      expect(
          todayTask.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      await _tapSemantic(tester, 'action:today.3a_task.open');
      expect(
        tester
            .getSemantics(find.descendant(
              of: _semantic('node:3a.task_detail'),
              matching: find.text(l10n.mintNext3aTaskTitle),
            ))
            .flagsCollection
            .isHeader,
        isTrue,
      );
      final delete = tester.getSemantics(_semantic('action:3a.task.delete'));
      expect(delete.label, l10n.mintNext3aDelete);
      expect(delete.flagsCollection.isButton, isTrue);
      expect(delete.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      await _tapSemantic(tester, 'action:3a.task.delete');

      final traversal = tester.semantics
          .simulatedAccessibilityTraversal()
          .map((node) => node.getSemanticsData())
          .toList();
      expect(
        traversal,
        containsAllInOrder([
          isSemantics(label: l10n.mintNext3aDeleteQuestion),
          isSemantics(label: l10n.mintNext3aDeleteBoundary),
          isSemantics(
            label: l10n.mintNext3aCancel,
            isButton: true,
            hasTapAction: true,
          ),
          isSemantics(
            label: l10n.mintNext3aDeleteConfirm,
            isButton: true,
            hasTapAction: true,
          ),
        ]),
      );
      expect(
        traversal.where(
          (data) => data.identifier == 'action:3a.task.delete',
        ),
        isEmpty,
        reason: 'the destructive background action must be modal-isolated',
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await _tapSemantic(tester, 'action:3a.task.delete_cancel');
    });
  });

  testWidgets('system back can leave a handoff whose initial read is pending', (
    tester,
  ) async {
    FeatureFlags.enableMintNext3aProductHandoff = true;
    final gate = Completer<void>();
    final adapter = _MemoryTaskAdapter();
    late GoRouter router;
    await tester.pumpWidget(_realTodayHarness(
      taskStore: MintNext3aTaskStore(adapter: adapter),
      onRouter: (value) => router = value,
    ));
    await tester.pumpAndSettle();
    adapter.readGate = gate;
    unawaited(router.push('/mint-next/3a'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MintNext3aHandoffScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MintNext3aHandoffScreen), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(_semantic('home_route_state'), findsOneWidget);
  });

  testWidgets('teach-back gates explicit task save without personal CHF', (
    tester,
  ) async {
    await _mountRealToday(tester);
    await _openMissingHandoff(tester);
    await _completeTeachBack(tester);
    await _tapSemantic(tester, 'action:3a.task.leave_without_saving');
    expect(
      _semantic('task:today.3a.verify_annual_credited_total'),
      findsNothing,
    );
  });

  testWidgets('year rollover cannot change the resolved fiscal task year', (
    tester,
  ) async {
    final adapter = _MemoryTaskAdapter();
    final store = MintNext3aTaskStore(adapter: adapter);
    var clockCalls = 0;
    DateTime clock() => clockCalls++ == 0
        ? DateTime.utc(2026, 12, 31, 23, 59, 59)
        : DateTime.utc(2027, 1, 1);

    FeatureFlags.enableMintNext3aProductHandoff = true;
    await tester.pumpWidget(_realTodayHarness(
      initialLocation: '/mint-next/3a',
      taskStore: store,
      now: clock,
    ));
    await tester.pumpAndSettle();
    await _completeTeachBack(tester);
    await _tapSemantic(tester, 'action:3a.task.save');

    final persisted = jsonDecode(adapter.value!) as Map<String, dynamic>;
    expect(persisted['tax_year'], 2026);
    expect(persisted['created_at'], '2026-12-31T23:59:59.000Z');
    expect(clockCalls, 1);
  });

  testWidgets('January carryover names the stored fiscal year explicitly', (
    tester,
  ) async {
    final adapter = _MemoryTaskAdapter();
    final store = MintNext3aTaskStore(adapter: adapter);
    await store.save(
      taxYear: 2026,
      at: DateTime.utc(2026, 12, 31, 12),
    );
    FeatureFlags.enableMintNext3aProductHandoff = true;

    await tester.pumpWidget(_realTodayHarness(
      initialLocation: '/mint-next/3a',
      taskStore: store,
      now: () => DateTime.utc(2027, 1, 15),
    ));
    await tester.pumpAndSettle();

    final l10n = S.of(tester.element(_semantic('node:3a.task_detail')))!;
    expect(find.text(l10n.mintNext3aTaskBody(2026)), findsOneWidget);
    expect(find.textContaining('cette année'), findsNothing);

    final januaryStore = MintNext3aTaskStore(
      adapter: adapter,
      now: () => DateTime.utc(2027, 1, 15),
    );
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      home: Scaffold(body: MintNext3aHandoffCard(store: januaryStore)),
    ));
    await tester.pumpAndSettle();
    final todayL10n = S.of(tester.element(find.byType(MintNext3aHandoffCard)))!;
    expect(find.text(todayL10n.mintNext3aTodayStatus(2026)), findsOneWidget);
  });

  testWidgets('saved task restores once and deletes durably', (tester) async {
    await _mountRealToday(tester);
    await _openMissingHandoff(tester);
    await _completeTeachBack(tester);
    expect(_semantic('node:3a.task_preview'), findsOneWidget);
    final save = _semantic('action:3a.task.save');
    expect(save, findsOneWidget);
    await tester.tap(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(_semantic('node:3a.task_saved'), findsOneWidget);
    await _tapSemantic(tester, 'action:3a.task.return_today');
    expect(
      _semantic('task:today.3a.verify_annual_credited_total'),
      findsOneWidget,
    );

    final persisted = Map<String, String>.from(_secureProbe.values);
    final taskKeys = persisted.keys.where(
      (key) => key.startsWith('mint_next_3a_task'),
    );
    expect(taskKeys, orderedEquals(const [_taskStorageKey]));
    final payload =
        jsonDecode(persisted[_taskStorageKey]!) as Map<String, dynamic>;
    expect(payload.keys.toSet(), {
      'schema_version',
      'task_id',
      'tax_year',
      'status',
      'created_at',
      'updated_at',
      'expires_at',
      'source',
    });
    expect(payload['schema_version'], 1);
    expect(payload['task_id'], '3a.verify_annual_credited_total');
    expect(payload['tax_year'], isA<int>());
    expect(payload['status'], 'open');
    expect(payload['source'], 'explicit_user_confirmation');
    expect(DateTime.tryParse(payload['created_at'] as String), isNotNull);
    expect(DateTime.tryParse(payload['updated_at'] as String), isNotNull);
    expect(DateTime.tryParse(payload['expires_at'] as String), isNotNull);

    // Replace the secure-storage adapter: the next app surface must read the
    // serialized record, not retain a process singleton or widget state.
    _secureProbe = _SecureStoreProbe(persisted)..install();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_realTodayHarness());
    await tester.pumpAndSettle();
    expect(_secureProbe.readKeys, contains(_taskStorageKey));
    expect(
      _semantic('task:today.3a.verify_annual_credited_total'),
      findsOneWidget,
    );
    await _tapSemantic(tester, 'action:today.3a_task.open');
    expect(find.textContaining('${(payload['tax_year'] as int) + 1}'),
        findsOneWidget);
    await _tapSemantic(tester, 'action:3a.task.delete');
    expect(_semantic('overlay:3a.task.delete_confirm'), findsOneWidget);
    await _tapSemantic(tester, 'action:3a.task.delete_confirm');
    expect(_secureProbe.values.containsKey(_taskStorageKey), isFalse);
    expect(
      _semantic('task:today.3a.verify_annual_credited_total'),
      findsNothing,
    );

    final afterDelete = Map<String, String>.from(_secureProbe.values);
    _secureProbe = _SecureStoreProbe(afterDelete)..install();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_realTodayHarness());
    await tester.pumpAndSettle();
    expect(_secureProbe.readKeys, contains(_taskStorageKey));
    expect(
      _semantic('task:today.3a.verify_annual_credited_total'),
      findsNothing,
    );
  });

  testWidgets('saved task remains open-only and stays deletable',
      (tester) async {
    await _mountRealToday(tester);
    await _openMissingHandoff(tester);
    await _completeTeachBack(tester);
    await _tapSemantic(tester, 'action:3a.task.save');
    await _tapSemantic(tester, 'action:3a.task.return_today');
    await _tapSemantic(tester, 'action:today.3a_task.open');

    expect(_semantic('action:3a.task.complete'), findsNothing);
    expect(_semantic('action:3a.task.delete'), findsOneWidget);

    await _tapSemantic(tester, 'action:3a.task.return_today');
    final l10n = S.of(tester.element(find.byType(MintNext3aHandoffCard)))!;
    expect(find.text(l10n.mintNext3aTodayStatus(2026)), findsOneWidget);

    final payload = jsonDecode(_secureProbe.values[_taskStorageKey]!)
        as Map<String, dynamic>;
    expect(payload['status'], 'open');
  });

  testWidgets('safe exit creates no task and housing stays absent', (
    tester,
  ) async {
    await _mountRealToday(tester);
    await _openMissingHandoff(tester);
    await _tapSemantic(tester, 'action:3a.safe_exit.open');
    expect(_semantic('overlay:3a.safe_exit'), findsOneWidget);
    await _tapSemantic(tester, 'action:3a.safe_exit.resume');
    expect(_semantic('node:3a.teach_back'), findsOneWidget);
    await _tapSemantic(tester, 'action:3a.safe_exit.open');
    await _tapSemantic(tester, 'action:3a.safe_exit.leave_without_saving');
    expect(
      _semantic('task:today.3a.verify_annual_credited_total'),
      findsNothing,
    );
    expect(_semantic('node:fact_logement'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_realTodayHarness());
    await tester.pumpAndSettle();
    expect(
      _semantic('task:today.3a.verify_annual_credited_total'),
      findsNothing,
    );
  });

  testWidgets('storage failure claims nothing and retry needs a fresh read', (
    tester,
  ) async {
    await _mountRealToday(tester);
    await _openMissingHandoff(tester);
    await _completeTeachBack(tester);
    _secureProbe.failNextWrite = true;

    await _tapSemantic(tester, 'action:3a.task.save');
    expect(_semantic('status:3a.task.storage_failed'), findsOneWidget);
    expect(_semantic('action:3a.task.storage_retry'), findsOneWidget);
    expect(_semantic('action:3a.task.leave_without_saving'), findsOneWidget);
    expect(_semantic('node:3a.task_saved'), findsNothing);
    expect(_secureProbe.values.containsKey(_taskStorageKey), isFalse);

    expect(_semantic('node:3a.task_preview'), findsOneWidget);
    await _tapSemantic(tester, 'action:3a.task.storage_retry');
    expect(_semantic('node:3a.task_saved'), findsOneWidget);
    expect(_secureProbe.readKeys.where((key) => key == _taskStorageKey).length,
        greaterThanOrEqualTo(2));
  });

  testWidgets('flag off keeps an existing task in delete-only mode', (
    tester,
  ) async {
    await _mountRealToday(tester);
    await _openMissingHandoff(tester);
    await _completeTeachBack(tester);
    await _tapSemantic(tester, 'action:3a.task.save');
    await _tapSemantic(tester, 'action:3a.task.return_today');

    FeatureFlags.enableMintNext3aProductHandoff = false;
    await tester.pumpAndSettle();
    expect(_semantic('action:today.open_mint_next_3a'), findsNothing);
    expect(_semantic('task:today.3a.verify_annual_credited_total'),
        findsOneWidget);
    await _tapSemantic(tester, 'action:today.3a_task.open');
    expect(_semantic('node:3a.task_detail'), findsOneWidget);
    expect(_semantic('action:3a.task.delete'), findsOneWidget);
    expect(_semantic('action:3a.safe_exit.open'), findsNothing);
    expect(_semantic('node:3a.teach_back'), findsNothing);
    expect(_semantic('node:3a.task_preview'), findsNothing);
  });

  testWidgets('flag off plus uncertain read keeps recovery access visible', (
    tester,
  ) async {
    FeatureFlags.enableMintNext3aProductHandoff = false;
    _secureProbe.failRead = true;
    await _mountRealToday(tester, handoffEnabled: false);

    expect(_semantic('action:today.3a_task.recover'), findsOneWidget);
    await _tapSemantic(tester, 'action:today.3a_task.recover');
    expect(_semantic('status:3a.task.storage_failed'), findsOneWidget);
    expect(_semantic('action:3a.task.storage_retry'), findsOneWidget);
  });

  testWidgets('flag off uncertain read permits blind owned-key deletion', (
    tester,
  ) async {
    _secureProbe.values[_taskStorageKey] = jsonEncode(MintNext3aTask(
      taxYear: 2026,
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
      expiresAt: DateTime.utc(2027, 1, 31, 23, 59, 59),
    ).toJson());
    _secureProbe.failRead = true;
    await _mountRealToday(tester, handoffEnabled: false);
    await _tapSemantic(tester, 'action:today.3a_task.recover');

    await _tapSemantic(tester, 'action:3a.task.delete_unverified');
    expect(_semantic('overlay:3a.task.delete_confirm'), findsOneWidget);
    await _tapSemantic(tester, 'action:3a.task.delete_confirm');

    expect(_secureProbe.values.containsKey(_taskStorageKey), isFalse);
    expect(_semantic('home_route_state'), findsOneWidget);
  });

  testWidgets('failed blind deletion remains honest and retryable', (
    tester,
  ) async {
    _secureProbe.values[_taskStorageKey] = 'opaque-unreadable-owned-value';
    _secureProbe.failRead = true;
    _secureProbe.failDelete = true;
    await _mountRealToday(tester, handoffEnabled: false);
    await _tapSemantic(tester, 'action:today.3a_task.recover');

    await _tapSemantic(tester, 'action:3a.task.delete_unverified');
    expect(_semantic('overlay:3a.task.delete_confirm'), findsOneWidget);
    await _tapSemantic(tester, 'action:3a.task.delete_confirm');

    expect(_secureProbe.values.containsKey(_taskStorageKey), isTrue);
    expect(_semantic('status:3a.task.storage_failed'), findsOneWidget);
    expect(_semantic('action:3a.task.storage_retry'), findsOneWidget);

    _secureProbe.failDelete = false;
    await _tapSemantic(tester, 'action:3a.task.storage_retry');
    expect(_secureProbe.values.containsKey(_taskStorageKey), isFalse);
  });

  testWidgets('flag turning off during save leaves no owned task', (
    tester,
  ) async {
    await _mountRealToday(tester);
    await _openMissingHandoff(tester);
    await _completeTeachBack(tester);
    final gate = Completer<void>();
    _secureProbe.writeGate = gate;

    await tester.tap(_semantic('action:3a.task.save'));
    await tester.pump();
    FeatureFlags.enableMintNext3aProductHandoff = false;
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();

    expect(_secureProbe.values.containsKey(_taskStorageKey), isFalse);
    expect(_semantic('home_route_state'), findsOneWidget);
    expect(_semantic('node:3a.task_saved'), findsNothing);
  });

  testWidgets('leave during an in-flight save cleans before navigating', (
    tester,
  ) async {
    await _mountRealToday(tester);
    await _openMissingHandoff(tester);
    await _completeTeachBack(tester);
    final gate = Completer<void>();
    _secureProbe.writeGate = gate;

    await tester.tap(_semantic('action:3a.task.save'));
    await tester.pump();
    await _tapSemantic(tester, 'action:3a.task.leave_without_saving');
    expect(_semantic('node:3a.task_preview'), findsOneWidget);
    expect(_semantic('status:3a.task.cleanup_pending'), findsOneWidget);
    expect(_semantic('action:3a.task.save'), findsNothing);
    expect(_semantic('action:3a.task.leave_without_saving'), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();

    expect(_secureProbe.values.containsKey(_taskStorageKey), isFalse);
    expect(_semantic('home_route_state'), findsOneWidget);
  });

  testWidgets('safe-exit leave during save also cleans before navigating', (
    tester,
  ) async {
    await _mountRealToday(tester);
    await _openMissingHandoff(tester);
    await _completeTeachBack(tester);
    final gate = Completer<void>();
    _secureProbe.writeGate = gate;

    await tester.tap(_semantic('action:3a.task.save'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await _tapSemantic(tester, 'action:3a.safe_exit.leave_without_saving');
    expect(_semantic('node:3a.task_preview'), findsOneWidget);
    expect(_semantic('status:3a.task.cleanup_pending'), findsOneWidget);
    expect(_semantic('action:3a.task.save'), findsNothing);
    expect(_semantic('action:3a.task.leave_without_saving'), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();

    expect(_secureProbe.values.containsKey(_taskStorageKey), isFalse);
    expect(_semantic('home_route_state'), findsOneWidget);
  });

  testWidgets('system back during save uses safe exit and cleans before leave',
      (
    tester,
  ) async {
    await _mountRealToday(tester);
    await _openMissingHandoff(tester);
    await _completeTeachBack(tester);
    final gate = Completer<void>();
    _secureProbe.writeGate = gate;

    await tester.tap(_semantic('action:3a.task.save'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(_semantic('overlay:3a.safe_exit'), findsOneWidget);
    await _tapSemantic(tester, 'action:3a.safe_exit.leave_without_saving');
    expect(_semantic('status:3a.task.cleanup_pending'), findsOneWidget);
    expect(_semantic('home_route_state'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(_secureProbe.values.containsKey(_taskStorageKey), isFalse);
    expect(_semantic('home_route_state'), findsOneWidget);
  });

  testWidgets('post-write read failure never claims nothing was saved', (
    tester,
  ) async {
    await _mountRealToday(tester);
    await _openMissingHandoff(tester);
    await _completeTeachBack(tester);
    _secureProbe.failReadsAfterWrite = 2;

    await _tapSemantic(tester, 'action:3a.task.save');

    final l10n = S.of(
      tester.element(_semantic('status:3a.task.storage_failed')),
    )!;
    expect(_secureProbe.values.containsKey(_taskStorageKey), isTrue);
    expect(
        find.text(l10n.mintNext3aStorageFailure('verifyRead')), findsOneWidget);
    expect(find.text(l10n.mintNext3aStorageFailure('write')), findsNothing);
    expect(_semantic('action:3a.task.return_today'), findsOneWidget);
    expect(_semantic('action:3a.task.leave_without_saving'), findsNothing);
  });

  testWidgets('kill-switch cleanup failure exposes persisted-task truth', (
    tester,
  ) async {
    await _mountRealToday(tester);
    await _openMissingHandoff(tester);
    await _completeTeachBack(tester);
    final gate = Completer<void>();
    _secureProbe.writeGate = gate;
    _secureProbe.failDelete = true;

    await tester.tap(_semantic('action:3a.task.save'));
    await tester.pump();
    FeatureFlags.enableMintNext3aProductHandoff = false;
    gate.complete();
    await tester.pumpAndSettle();

    expect(_secureProbe.values.containsKey(_taskStorageKey), isTrue);
    expect(_semantic('status:3a.task.storage_failed'), findsOneWidget);
    final l10n = S.of(
      tester.element(_semantic('status:3a.task.storage_failed')),
    )!;
    expect(find.text(l10n.mintNext3aStorageFailure('cleanupDelete')),
        findsOneWidget);
    _secureProbe.failDelete = false;
    await _tapSemantic(tester, 'action:3a.task.storage_retry');
    expect(_secureProbe.values.containsKey(_taskStorageKey), isFalse);
    expect(_semantic('home_route_state'), findsOneWidget);
  });

  testWidgets('secure-storage read failure has retry and safe leave', (
    tester,
  ) async {
    _secureProbe.failRead = true;
    await _mountRealToday(tester);
    await _tapSemantic(tester, 'action:today.3a_task.recover');
    expect(_semantic('status:3a.task.storage_failed'), findsOneWidget);
    final readL10n = S.of(
      tester.element(_semantic('status:3a.task.storage_failed')),
    )!;
    expect(
        find.text(readL10n.mintNext3aStorageFailure('read')), findsOneWidget);
    expect(find.text(readL10n.mintNext3aStorageFailure('write')), findsNothing);
    expect(_semantic('action:3a.task.storage_retry'), findsOneWidget);
    expect(_semantic('action:3a.task.return_today'), findsOneWidget);
    expect(_semantic('action:3a.task.leave_without_saving'), findsNothing);

    _secureProbe.failRead = false;
    await _tapSemantic(tester, 'action:3a.task.storage_retry');
    expect(_semantic('node:3a.teach_back'), findsOneWidget);
    expect(_secureProbe.values.containsKey(_taskStorageKey), isFalse);
  });

  testWidgets('selected choice has a non-colour visual indicator', (
    tester,
  ) async {
    await _mountRealToday(tester);
    await _openMissingHandoff(tester);

    expect(_semantic('indicator:3a.teach_back.annualTotal.selected'),
        findsNothing);
    await _tapSemantic(
      tester,
      'choice:3a.teach_back.annual_total_all_accounts',
    );
    expect(_semantic('indicator:3a.teach_back.annualTotal.selected'),
        findsOneWidget);
  });

  testWidgets('reduced motion has static loading help and safe exit', (
    tester,
  ) async {
    FeatureFlags.enableMintNext3aProductHandoff = true;
    final gate = Completer<void>();
    final adapter = _MemoryTaskAdapter()..readGate = gate;
    await tester.pumpWidget(_realTodayHarness(
      initialLocation: '/mint-next/3a',
      taskStore: MintNext3aTaskStore(adapter: adapter),
      disableAnimations: true,
    ));
    await tester.pump();

    expect(_semantic('status:3a.loading'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
        find.text(S.of(tester.element(find.byType(Scaffold)))!.loadingGeneric),
        findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);

    gate.complete();
    await tester.pumpAndSettle();
    final expansion = tester.widget<ExpansionTile>(find.byType(ExpansionTile));
    expect(expansion.expansionAnimationStyle, AnimationStyle.noAnimation);
    await tester.tap(find.byType(ExpansionTile));
    await tester.pump();
    expect(
        find.text(S
            .of(tester.element(find.byType(ExpansionTile)))!
            .mintNext3aCountingHelpBody),
        findsOneWidget);

    await tester.ensureVisible(_semantic('action:3a.safe_exit.open'));
    await tester.pump();
    await tester.tap(_semantic('action:3a.safe_exit.open'));
    await tester.pump();
    final overlay = _semantic('overlay:3a.safe_exit');
    expect(overlay, findsOneWidget);
    expect(
      ModalRoute.of(tester.element(overlay))!.transitionDuration,
      Duration.zero,
    );
  });

  testWidgets('default motion keeps framework loading help and dialog motion', (
    tester,
  ) async {
    FeatureFlags.enableMintNext3aProductHandoff = true;
    final gate = Completer<void>();
    final adapter = _MemoryTaskAdapter()..readGate = gate;
    await tester.pumpWidget(_realTodayHarness(
      initialLocation: '/mint-next/3a',
      taskStore: MintNext3aTaskStore(adapter: adapter),
    ));
    await tester.pump();

    final progress = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(progress.value, isNull);
    expect(_semantic('status:3a.loading'), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);

    gate.complete();
    await tester.pumpAndSettle();
    final expansion = tester.widget<ExpansionTile>(find.byType(ExpansionTile));
    expect(expansion.expansionAnimationStyle, isNull);
    await tester.tap(find.byType(ExpansionTile));
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    await tester.ensureVisible(_semantic('action:3a.safe_exit.open'));
    await tester.pump();
    await tester.tap(_semantic('action:3a.safe_exit.open'));
    await tester.pump();
    final overlay = _semantic('overlay:3a.safe_exit');
    expect(overlay, findsOneWidget);
    expect(
      ModalRoute.of(tester.element(overlay))!.transitionDuration,
      greaterThan(Duration.zero),
    );
  });

  testWidgets('reduced motion delete confirmation opens without transition', (
    tester,
  ) async {
    final adapter = _MemoryTaskAdapter();
    final store = MintNext3aTaskStore(adapter: adapter);
    await store.save(taxYear: 2026, at: DateTime.utc(2026, 8, 1));
    FeatureFlags.enableMintNext3aProductHandoff = true;
    await tester.pumpWidget(_realTodayHarness(
      initialLocation: '/mint-next/3a',
      taskStore: store,
      disableAnimations: true,
    ));
    await tester.pumpAndSettle();
    await tester.tap(_semantic('action:3a.task.delete'));
    await tester.pump();

    final overlay = _semantic('overlay:3a.task.delete_confirm');
    expect(overlay, findsOneWidget);
    expect(
      ModalRoute.of(tester.element(overlay))!.transitionDuration,
      Duration.zero,
    );
  });

  testWidgets('default motion keeps delete confirmation transition', (
    tester,
  ) async {
    final adapter = _MemoryTaskAdapter();
    final store = MintNext3aTaskStore(adapter: adapter);
    await store.save(taxYear: 2026, at: DateTime.utc(2026, 8, 1));
    FeatureFlags.enableMintNext3aProductHandoff = true;
    await tester.pumpWidget(_realTodayHarness(
      initialLocation: '/mint-next/3a',
      taskStore: store,
    ));
    await tester.pumpAndSettle();
    await tester.tap(_semantic('action:3a.task.delete'));
    await tester.pump();

    final overlay = _semantic('overlay:3a.task.delete_confirm');
    expect(overlay, findsOneWidget);
    expect(
      ModalRoute.of(tester.element(overlay))!.transitionDuration,
      greaterThan(Duration.zero),
    );
  });

  testWidgets('safe-exit cancel restores focus to its opener', (tester) async {
    await _mountRealToday(tester);
    await _openMissingHandoff(tester);
    final opener = tester.widget<TextButton>(find.descendant(
      of: _semantic('action:3a.safe_exit.open'),
      matching: find.byType(TextButton),
    ));
    opener.focusNode!.requestFocus();
    await tester.pump();

    await _tapSemantic(tester, 'action:3a.safe_exit.open');
    await _tapSemantic(tester, 'action:3a.safe_exit.resume');

    expect(opener.focusNode!.hasFocus, isTrue);
  });

  testWidgets('delete cancel restores focus to its opener', (tester) async {
    await _mountRealToday(tester);
    await _openMissingHandoff(tester);
    await _completeTeachBack(tester);
    await _tapSemantic(tester, 'action:3a.task.save');
    await _tapSemantic(tester, 'action:3a.task.return_today');
    await _tapSemantic(tester, 'action:today.3a_task.open');
    final opener = tester.widget<FilledButton>(find.descendant(
      of: _semantic('action:3a.task.delete'),
      matching: find.byType(FilledButton),
    ));
    opener.focusNode!.requestFocus();
    await tester.pump();

    await _tapSemantic(tester, 'action:3a.task.delete');
    await _tapSemantic(tester, 'action:3a.task.delete_cancel');

    expect(opener.focusNode!.hasFocus, isTrue);
  });

  testWidgets('delete failure stays honest and preserves retry access', (
    tester,
  ) async {
    await _mountRealToday(tester);
    await _openMissingHandoff(tester);
    await _completeTeachBack(tester);
    await _tapSemantic(tester, 'action:3a.task.save');
    await _tapSemantic(tester, 'action:3a.task.return_today');
    await _tapSemantic(tester, 'action:today.3a_task.open');
    await _tapSemantic(tester, 'action:3a.task.delete');
    _secureProbe.failDelete = true;
    await _tapSemantic(tester, 'action:3a.task.delete_confirm');

    expect(_semantic('status:3a.task.storage_failed'), findsOneWidget);
    final deleteL10n = S.of(
      tester.element(_semantic('status:3a.task.storage_failed')),
    )!;
    expect(find.text(deleteL10n.mintNext3aStorageFailure('delete')),
        findsOneWidget);
    expect(
        find.text(deleteL10n.mintNext3aStorageFailure('write')), findsNothing);
    expect(_secureProbe.values.containsKey(_taskStorageKey), isTrue);
    _secureProbe.failDelete = false;
    await _tapSemantic(tester, 'action:3a.task.storage_retry');
    expect(_secureProbe.values.containsKey(_taskStorageKey), isFalse);
    expect(_semantic('home_route_state'), findsOneWidget);
  });

  testWidgets('compact text scale two remains scrollable in six locales', (
    tester,
  ) async {
    for (final locale in const ['fr', 'en', 'de', 'it', 'es', 'pt']) {
      _secureProbe.values.clear();
      await _mountRealToday(
        tester,
        size: const Size(320, 700),
        locale: Locale(locale),
        textScaler: const TextScaler.linear(2),
      );
      expect(find.byType(CustomScrollView), findsOneWidget);
      await tester.pumpWidget(
        _realTodayHarness(
          locale: Locale(locale),
          textScaler: const TextScaler.linear(2),
          initialLocation: '/mint-next/3a',
        ),
      );
      await tester.pumpAndSettle();
      expect(_semantic('node:3a.teach_back'), findsOneWidget);
      final l10n = S.of(tester.element(_semantic('node:3a.teach_back')))!;
      await _tapSemantic(tester, 'action:3a.safe_exit.open');
      expect(_semantic('overlay:3a.safe_exit'), findsOneWidget);
      await _tapSemantic(tester, 'action:3a.safe_exit.resume');
      await tester.pumpWidget(
        _realTodayHarness(
          locale: Locale(locale),
          textScaler: const TextScaler.linear(2),
          initialLocation: '/mint-next/3a',
        ),
      );
      await tester.pumpAndSettle();
      await _tapSemantic(tester, 'choice:3a.teach_back.latest_payment_only');
      await _tapSemantic(tester, 'action:3a.teach_back.check');
      expect(_semantic('feedback:3a.teach_back.retry'), findsOneWidget);
      await _tapSemantic(tester, 'action:3a.teach_back.retry');
      await _tapSemantic(
          tester, 'choice:3a.teach_back.annual_total_all_accounts');
      expect(
        find.descendant(
          of: _semantic('action:3a.teach_back.check'),
          matching: find.text(l10n.capCoverageCheckCtaLabel),
        ),
        findsOneWidget,
      );
      await _tapSemantic(tester, 'action:3a.teach_back.check');
      expect(
        find.descendant(
          of: _semantic('action:3a.teach_back.continue'),
          matching: find.text(l10n.milestoneContinueBtn),
        ),
        findsOneWidget,
      );
      await _tapSemantic(tester, 'action:3a.teach_back.continue');
      expect(_semantic('action:3a.task.save'), findsOneWidget,
          reason: 'save must remain scroll-reachable for $locale');
      expect(
        find.descendant(
          of: _semantic('action:3a.task.save'),
          matching: find.text(l10n.mintNext3aSave),
        ),
        findsOneWidget,
      );
      _secureProbe.failNextWrite = true;
      await _tapSemantic(tester, 'action:3a.task.save');
      expect(_semantic('status:3a.task.storage_failed'), findsOneWidget);
      await _tapSemantic(tester, 'action:3a.task.storage_retry');
      expect(_semantic('node:3a.task_saved'), findsOneWidget);
      await tester.pumpWidget(
        _realTodayHarness(
          locale: Locale(locale),
          textScaler: const TextScaler.linear(2),
          initialLocation: '/mint-next/3a',
        ),
      );
      await tester.pumpAndSettle();
      expect(_semantic('node:3a.task_detail'), findsOneWidget);
      await _tapSemantic(tester, 'action:3a.task.delete');
      expect(_semantic('overlay:3a.task.delete_confirm'), findsOneWidget);
      await _tapSemantic(tester, 'action:3a.task.delete_cancel');
      expect(_semantic('node:3a.task_detail'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
