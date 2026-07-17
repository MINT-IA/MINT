import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/recommendation.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/simulator_3a_screen.dart';
import 'package:mint_mobile/widgets/common/safe_mode_gate.dart';
import 'package:mint_mobile/widgets/recommendation_card.dart';
import 'package:mint_mobile/widgets/simulators/buyback_widget.dart';
import 'package:provider/provider.dart';

const _namedDebtReaders = <String>{
  'lib/screens/simulator_3a_screen.dart',
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

CoachProfile _profile({required bool debtCrisis}) {
  return CoachProfile.defaults().copyWith(
    birthYear: 1990,
    canton: 'VD',
    salaireBrutMensuel: 8000,
    patrimoine: const PatrimoineProfile(epargneLiquide: 100000),
    depenses: const DepensesProfile(loyer: 1500, assuranceMaladie: 400),
    dettes: debtCrisis
        ? const DetteProfile(creditConsommation: 1000)
        : const DetteProfile(),
  );
}

Recommendation _recommendation() => Recommendation(
      id: 'recommendation',
      kind: 'fiscalite',
      title: 'Planifier un versement 3a',
      summary: 'Résumé',
      why: <String>['Raison'],
      assumptions: <String>['Hypothèse'],
      impact: const Impact(amountCHF: 1000, period: Period.yearly),
      risks: <String>['Risque'],
      alternatives: <String>['Alternative'],
      evidenceLinks: <EvidenceLink>[],
      nextActions: <NextAction>[],
    );

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
    test('the historical five reconcile to three live debt readers', () {
      expect(_namedDebtReaders, hasLength(3));
      expect(
        File('lib/widgets/comparators/pillar3a_comparator_widget.dart')
            .existsSync(),
        isFalse,
      );

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

      expect(safe.isInDebtCrisis, isFalse);
      expect(crisis.isInDebtCrisis, isTrue);
    });

    testWidgets('the three named readers lock from the canonical crisis state',
        (tester) async {
      final crisis = _profile(debtCrisis: true);

      await tester.pumpWidget(
        _localized(
          profile: crisis,
          child: const Simulator3aScreen(),
        ),
      );
      await tester.pump();
      expect(find.byType(SafeModeGate), findsWidgets);

      await tester.pumpWidget(
        _localized(
          profile: crisis,
          child: const Scaffold(
            body: BuybackWidget(
              totalBuybackPotential: 50000,
              taxableIncome: 120000,
              canton: 'VD',
              civilStatus: 'single',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(SafeModeGate), findsOneWidget);

      await tester.pumpWidget(
        _localized(
          profile: crisis,
          child: Scaffold(
            body: RecommendationCard(recommendation: _recommendation()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(SafeModeGate), findsOneWidget);
    });

    testWidgets('an absent ledger profile never becomes debt-free by default',
        (tester) async {
      await tester.pumpWidget(
        _localized(
          profile: null,
          child: Scaffold(
            body: RecommendationCard(recommendation: _recommendation()),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Planifier un versement 3a'), findsNothing);

      await tester.pumpWidget(
        _localized(
          profile: null,
          child: const Scaffold(
            body: BuybackWidget(
              totalBuybackPotential: 50000,
              taxableIncome: 120000,
              canton: 'VD',
              civilStatus: 'single',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(SafeModeGate), findsNothing);
    });
  });
}
