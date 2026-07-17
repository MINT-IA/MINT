import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/simulator_3a_screen.dart';
import 'package:mint_mobile/widgets/common/mint_empty_state.dart';
import 'package:mint_mobile/widgets/common/safe_mode_gate.dart';
import 'package:provider/provider.dart';

const _namedDebtReaders = <String>{
  'lib/screens/simulator_3a_screen.dart',
};

const _retiredDeadWidgets = <String>{
  'lib/widgets/simulators/buyback_widget.dart',
  'lib/widgets/recommendation_card.dart',
};

final class _LedgerProvider extends CoachProfileProvider {
  _LedgerProvider(this._current);

  final CoachProfile? _current;

  @override
  CoachProfile? get profile => _current;

  @override
  bool get hasProfile => _current != null;

  @override
  bool get isLoaded => true;
}

CoachProfile _profile(
    {required bool debtCrisis, double liquidSavings = 100000}) {
  return CoachProfile.defaults().copyWith(
    birthYear: 1990,
    canton: 'VD',
    salaireBrutMensuel: 8000,
    patrimoine: PatrimoineProfile(epargneLiquide: liquidSavings),
    depenses: const DepensesProfile(loyer: 1500, assuranceMaladie: 400),
    dettes: debtCrisis
        ? const DetteProfile(creditConsommation: 1000)
        : const DetteProfile(),
  );
}

Widget _localized({required CoachProfile? profile, required Widget child}) {
  return ChangeNotifierProvider<CoachProfileProvider>.value(
    value: _LedgerProvider(profile),
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: child,
    ),
  );
}

Iterable<String> _legacyProviderReferences() sync* {
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final source = entity.readAsStringSync();
    if (RegExp(r'\bProfileProvider\b').hasMatch(source) ||
        source.contains('providers/profile_provider.dart')) {
      yield entity.path;
    }
  }
}

void main() {
  group('G1-BND-01 legacy provider migration', () {
    test('the historical five reconcile to one production debt reader', () {
      expect(_namedDebtReaders, hasLength(1));
      expect(
        File('lib/widgets/comparators/pillar3a_comparator_widget.dart')
            .existsSync(),
        isFalse,
      );
      for (final path in _retiredDeadWidgets) {
        expect(File(path).existsSync(), isFalse, reason: path);
      }

      for (final path in _namedDebtReaders) {
        final source = File(path).readAsStringSync();
        expect(source, contains('CoachProfileProvider'), reason: path);
        expect(source, contains('.isInDebtCrisis'), reason: path);
        expect(
          RegExp(r'\bProfileProvider\b').hasMatch(source),
          isFalse,
          reason: path,
        );
        expect(
          source,
          isNot(matches(RegExp(r'isInDebtCrisis\s*\?\?\s*false'))),
          reason: '$path must not turn an absent ledger profile into debt-free',
        );
      }
    });

    test('live library grep is zero for the legacy provider', () {
      expect(_legacyProviderReferences(), isEmpty);
    });

    test('the legacy provider file and app registration are removed', () {
      expect(File('lib/providers/profile_provider.dart').existsSync(), isFalse);
      final app = File('lib/app.dart').readAsStringSync();
      expect(RegExp(r'\bProfileProvider\b').hasMatch(app), isFalse);
      expect(app, isNot(contains('providers/profile_provider.dart')));
    });

    test('canonical debt semantics are protective, not any-debt aliases', () {
      final safe = _profile(debtCrisis: false);
      final crisis = _profile(debtCrisis: true);
      final emergencyFundOnly = _profile(debtCrisis: false, liquidSavings: 0);

      expect(safe.isInDebtCrisis, isFalse);
      expect(crisis.isInDebtCrisis, isTrue);
      expect(emergencyFundOnly.dettes.creditConsommation, isNull);
      expect(emergencyFundOnly.dettes.leasing, isNull);
      expect(emergencyFundOnly.dettes.autresDettes, isNull);
      expect(emergencyFundOnly.isInDebtCrisis, isTrue);
    });

    testWidgets(
        'an emergency-fund-only crisis uses a generic non-debt lock title',
        (tester) async {
      final emergencyFundOnly = _profile(debtCrisis: false, liquidSavings: 0);

      await tester.pumpWidget(
        _localized(
          profile: emergencyFundOnly,
          child: const Simulator3aScreen(),
        ),
      );
      await tester.pump();
      expect(find.byType(SafeModeGate), findsWidgets);
      expect(
        find.text('Stabilité financière prioritaire'),
        findsOneWidget,
      );
      expect(find.text('Priorité au désendettement'), findsNothing);
      expect(
        find.text(
          "Les stratégies d'investissement 3a restent en pause pendant la "
          'stabilisation de ta situation financière. Ordre recommandé\u00a0: '
          "stabiliser d'abord, placer ensuite.",
        ),
        findsOneWidget,
      );
      expect(find.textContaining('tes dettes actives'), findsNothing);
    });

    testWidgets('an absent profile offers the diagnostic path to coach chat',
        (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Simulator3aScreen(),
          ),
          GoRoute(
            path: '/coach/chat',
            builder: (_, __) => const Scaffold(
              body: Text('coach-chat-destination'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<CoachProfileProvider>.value(
          value: _LedgerProvider(null),
          child: MaterialApp.router(
            locale: const Locale('fr'),
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MintEmptyState), findsOneWidget);
      expect(find.text('Aucun profil renseigné'), findsOneWidget);
      expect(find.text('Commencer le diagnostic'), findsOneWidget);

      await tester.tap(find.text('Commencer le diagnostic'));
      await tester.pumpAndSettle();
      expect(find.text('coach-chat-destination'), findsOneWidget);
    });
  });
}
