import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/fullscreen_chart_wrapper.dart';

const _landscapeOrientations = [
  'DeviceOrientation.portraitUp',
  'DeviceOrientation.landscapeLeft',
  'DeviceOrientation.landscapeRight',
];
const _portraitOnly = ['DeviceOrientation.portraitUp'];

class _RecordingNavigatorObserver extends NavigatorObserver {
  final pushedRoutes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}

List<List<dynamic>> _recordOrientationCalls() {
  final calls = <List<dynamic>>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'SystemChrome.setPreferredOrientations') {
      calls.add(List<dynamic>.from(call.arguments as List));
    }
    return null;
  });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  return calls;
}

Widget _chartWrapper({
  bool allowLandscape = true,
  Widget? legend,
  String? disclaimer,
}) {
  return FullscreenChartWrapper(
    title: 'Projection',
    legend: legend,
    disclaimer: disclaimer,
    allowLandscape: allowLandscape,
    child: const SizedBox(
      width: 320,
      height: 180,
      child: Center(child: Text('Inline chart')),
    ),
  );
}

Future<void> _pumpChart(
  WidgetTester tester, {
  bool allowLandscape = true,
  Widget? legend,
  String? disclaimer,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: _chartWrapper(
          allowLandscape: allowLandscape,
          legend: legend,
          disclaimer: disclaimer,
        ),
      ),
    ),
  );
}

Future<void> _openOverlay(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.fullscreen));
  await tester.pumpAndSettle();
}

Future<void> _closeOverlay(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.close));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens and closes a fullscreen chart overlay', (tester) async {
    await _pumpChart(
      tester,
      legend: const Text('Legend'),
      disclaimer: 'Indicative only',
    );

    expect(find.text('Projection'), findsNothing);
    expect(find.text('Inline chart'), findsOneWidget);

    await _openOverlay(tester);

    expect(find.text('Projection'), findsOneWidget);
    expect(find.text('Legend'), findsOneWidget);
    expect(find.text('Indicative only'), findsOneWidget);

    await _closeOverlay(tester);

    expect(find.text('Projection'), findsNothing);
    expect(find.text('Inline chart'), findsOneWidget);
  });

  testWidgets('opens overlay on the nearest shell navigator', (tester) async {
    final rootObserver = _RecordingNavigatorObserver();
    final shellObserver = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [rootObserver],
        home: Navigator(
          observers: [shellObserver],
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => Scaffold(body: _chartWrapper()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    rootObserver.pushedRoutes.clear();
    shellObserver.pushedRoutes.clear();

    await _openOverlay(tester);

    expect(rootObserver.pushedRoutes, isEmpty);
    expect(shellObserver.pushedRoutes, hasLength(1));
    expect(find.text('Projection'), findsOneWidget);
  });

  testWidgets('restores portrait orientation when overlay closes',
      (tester) async {
    final orientationCalls = _recordOrientationCalls();

    await _pumpChart(tester);
    await _openOverlay(tester);

    expect(orientationCalls.last, _landscapeOrientations);

    await _closeOverlay(tester);

    expect(orientationCalls, hasLength(2));
    expect(orientationCalls.last, _portraitOnly);
  });

  testWidgets('restores portrait orientation when overlay is popped',
      (tester) async {
    final orientationCalls = _recordOrientationCalls();

    await _pumpChart(tester);
    await _openOverlay(tester);

    expect(orientationCalls.last, _landscapeOrientations);

    final overlayContext = tester.element(find.text('Projection'));
    await Navigator.of(overlayContext).maybePop();
    await tester.pumpAndSettle();

    expect(find.text('Projection'), findsNothing);
    expect(orientationCalls, hasLength(2));
    expect(orientationCalls.last, _portraitOnly);
  });

  testWidgets('keeps portrait only when landscape is disabled', (tester) async {
    final orientationCalls = _recordOrientationCalls();

    await _pumpChart(tester, allowLandscape: false);
    await _openOverlay(tester);

    expect(orientationCalls, hasLength(1));
    expect(orientationCalls.last, _portraitOnly);

    await _closeOverlay(tester);

    expect(orientationCalls, hasLength(2));
    expect(orientationCalls.last, _portraitOnly);
  });
}
