/// Phase 53-03 — widget test for Tab 1 commitments + check-ins card.
///
/// Asserts the four contracts from `53-03-PLAN.md` T-04:
///   1. Profile with both → card renders both sections.
///   2. Profile with only check-ins → check-ins section shows, commitments
///      section absent (FutureBuilder returns empty list).
///   3. Both empty → SizedBox.shrink (card not present in tree).
///   4. Tap on item → navigation to /coach/chat invoked.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/commitment_service.dart';
import 'package:mint_mobile/widgets/aujourdhui/commitments_and_checkins_card.dart';

class _FakeCommitmentService implements CommitmentService {
  _FakeCommitmentService(this._items);
  final List<Map<String, dynamic>> _items;

  @override
  Future<List<Map<String, dynamic>>> getCommitments({String? status}) async =>
      _items;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCoachProfileProvider extends ChangeNotifier
    implements CoachProfileProvider {
  _FakeCoachProfileProvider(this._profile);
  CoachProfile? _profile;

  @override
  CoachProfile? get profile => _profile;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CoachProfile _profileWithCheckIns(int n) {
  final base = CoachProfile.defaults();
  final checkIns = List.generate(
    n,
    (i) => MonthlyCheckIn(
      month: DateTime(2026, 1 + (i % 12)),
      versements: {'3a_user': 604.83},
      completedAt: DateTime.now().subtract(Duration(days: i + 1)),
    ),
  );
  return base.copyWithCheckIns(checkIns);
}

Widget _harness({
  required Widget child,
  required CoachProfileProvider provider,
  GoRouter? router,
}) {
  final r = router ??
      GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => Scaffold(body: child)),
          GoRoute(path: '/coach/chat', builder: (_, __) => const Scaffold()),
        ],
      );
  return MaterialApp.router(
    routerConfig: r,
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    builder: (context, child) =>
        ChangeNotifierProvider<CoachProfileProvider>.value(
      value: provider,
      child: child!,
    ),
  );
}

void main() {
  testWidgets('renders both sections when both data sources non-empty',
      (tester) async {
    final provider = _FakeCoachProfileProvider(_profileWithCheckIns(2));
    final service = _FakeCommitmentService(const [
      {
        'whenText': 'Lundi à 9h',
        'ifThenText': 'je verse 100 CHF sur le 3a',
        'createdAt': '2026-04-30T08:00:00Z',
      },
    ]);
    await tester.pumpWidget(
      _harness(
        provider: provider,
        child: CommitmentsAndCheckinsCard(commitmentService: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('engagements'), findsOneWidget);
    expect(find.textContaining('check-ins'), findsOneWidget);
    expect(find.textContaining('Lundi à 9h'), findsOneWidget);
  });

  testWidgets('shows only check-ins section when commitments empty',
      (tester) async {
    final provider = _FakeCoachProfileProvider(_profileWithCheckIns(1));
    final service = _FakeCommitmentService(const []);
    await tester.pumpWidget(
      _harness(
        provider: provider,
        child: CommitmentsAndCheckinsCard(commitmentService: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('engagements'), findsNothing);
    expect(find.textContaining('check-ins'), findsOneWidget);
  });

  testWidgets('hides card entirely when both data sources empty',
      (tester) async {
    final provider = _FakeCoachProfileProvider(CoachProfile.defaults());
    final service = _FakeCommitmentService(const []);
    await tester.pumpWidget(
      _harness(
        provider: provider,
        child: CommitmentsAndCheckinsCard(commitmentService: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CommitmentsAndCheckinsCard), findsOneWidget);
    // The card should render as SizedBox.shrink — no headers visible
    expect(find.textContaining('engagements'), findsNothing);
    expect(find.textContaining('check-ins'), findsNothing);
  });

  testWidgets('tap on item navigates to /coach/chat', (tester) async {
    final provider = _FakeCoachProfileProvider(_profileWithCheckIns(1));
    final service = _FakeCommitmentService(const []);
    String? lastNavigated;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: CommitmentsAndCheckinsCard(commitmentService: service),
          ),
        ),
        GoRoute(
          path: '/coach/chat',
          builder: (_, __) {
            lastNavigated = '/coach/chat';
            return const Scaffold();
          },
        ),
      ],
    );
    await tester.pumpWidget(
      _harness(provider: provider, router: router, child: const SizedBox()),
    );
    await tester.pumpAndSettle();

    final checkInRow = find.byIcon(Icons.check_circle_outline_rounded);
    expect(checkInRow, findsOneWidget);
    await tester.tap(checkInRow);
    await tester.pumpAndSettle();

    expect(lastNavigated, equals('/coach/chat'));
  });
}
