import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/coach/succession_evidence_quest.dart';
import 'package:provider/provider.dart';

final class _MemoryPersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements TaxProfilePersistence, LppProfilePersistence {
  _MemoryPersistence(this.answers);
  Map<String, dynamic> answers;
  int saves = 0;

  @override
  Future<Map<String, dynamic>> loadAnswers() async =>
      Map<String, dynamic>.from(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    saves++;
    answers = Map<String, dynamic>.from(next);
  }
}

Map<String, dynamic> _unknownRoot({Object? will}) => <String, dynamic>{
      'q_birth_year': 1980,
      'q_canton': 'VD',
      '_coach_estate_evidence_v1': jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'matrimonialRegime': null,
        'registeredPartnershipPropertyRegime': null,
        'estateInstruments': <String, dynamic>{
          'will': will ?? <String, dynamic>{'state': 'unknown'},
          'inheritancePact': <String, dynamic>{'state': 'unknown'},
          'incapacityMandate': <String, dynamic>{'state': 'unknown'},
          'advanceCareDirective': <String, dynamic>{'state': 'unknown'},
        },
      }),
    };

Map<String, dynamic> _allAbsentRoot() {
  final now = DateTime.utc(2026, 7, 20).toIso8601String();
  Map<String, dynamic> absent(String id) => <String, dynamic>{
        'state': 'confirmedAbsent',
        'confirmation': <String, dynamic>{
          'evidenceId': id,
          'ownerKind': 'self',
          'source': 'userInput',
          'confirmedAt': now,
          'civilStatusAtConfirmation': 'celibataire',
        },
      };
  final answers = _unknownRoot();
  answers['_coach_estate_evidence_v1'] = jsonEncode(<String, dynamic>{
    'schemaVersion': 1,
    'matrimonialRegime': null,
    'registeredPartnershipPropertyRegime': null,
    'estateInstruments': <String, dynamic>{
      'will': absent('11111111-1111-4111-8111-111111111111'),
      'inheritancePact': absent('22222222-2222-4222-8222-222222222222'),
      'incapacityMandate': absent('33333333-3333-4333-8333-333333333333'),
      'advanceCareDirective': absent('44444444-4444-4444-8444-444444444444'),
    },
  });
  return answers;
}

Future<({CoachProfileProvider provider, _MemoryPersistence persistence})>
    _provider(Map<String, dynamic> answers, {String civil = 'celibataire'}) async {
  answers['q_civil_status'] = civil;
  final persistence = _MemoryPersistence(answers);
  final provider = CoachProfileProvider(
    taxProfilePersistence: persistence,
    lppProfilePersistence: persistence,
    estateProfilePersistence: persistence,
    now: () => DateTime.utc(2026, 7, 20, 12),
  );
  await provider.loadFromWizard();
  persistence.saves = 0;
  return (provider: provider, persistence: persistence);
}

Widget _wrap(CoachProfileProvider provider) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const SuccessionEvidenceQuest()),
    GoRoute(
      path: '/data-block/:type',
      builder: (_, state) => Text('route:${state.uri}'),
    ),
  ]);
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('ambiguous civil status guards and routes to exact collector',
      (tester) async {
    final loaded = await _provider(_unknownRoot(), civil: 'partenariat');
    await tester.pumpWidget(_wrap(loaded.provider));
    expect(find.byKey(const Key('succession_civil_status_guard')), findsOneWidget);
    expect(loaded.persistence.saves, 0);
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('inputKey=q_civil_status'), findsOneWidget);
  });

  testWidgets('marriage and LPart use dedicated arrangement writers',
      (tester) async {
    for (final civil in <String>['marie', 'registeredPartnership']) {
      final loaded = await _provider(_unknownRoot(), civil: civil);
      await tester.pumpWidget(_wrap(loaded.provider));
      expect(find.byKey(const Key('succession_arrangement_question')), findsOneWidget);
      await tester.tap(find.byKey(const Key('succession_arrangement_save')));
      await tester.pumpAndSettle();
      final root = jsonDecode(loaded.persistence.answers['_coach_estate_evidence_v1'] as String) as Map;
      expect(root[civil == 'marie' ? 'matrimonialRegime' : 'registeredPartnershipPropertyRegime'], isNotNull);
      expect(loaded.persistence.saves, 1);
    }
  });

  testWidgets('present requires explicit source date and legal year',
      (tester) async {
    final loaded = await _provider(_unknownRoot());
    await tester.pumpWidget(_wrap(loaded.provider));
    await tester.tap(find.byKey(const Key('succession_instrument_will_present')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('succession_instrument_will_save')));
    await tester.pump();
    expect(find.byKey(const Key('succession_instrument_will_invalid')), findsOneWidget);
    expect(loaded.persistence.saves, 0);
    await tester.enterText(find.byKey(const Key('succession_instrument_will_source_date')), '2026-01-15');
    await tester.enterText(find.byKey(const Key('succession_instrument_will_legal_year')), '2026');
    await tester.tap(find.byKey(const Key('succession_instrument_will_save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('succession_answer_saved')), findsOneWidget);
    expect(loaded.persistence.saves, 1);
  });

  testWidgets('absence persists once and never auto-advances', (tester) async {
    final loaded = await _provider(_unknownRoot());
    await tester.pumpWidget(_wrap(loaded.provider));
    await tester.tap(find.byKey(const Key('succession_instrument_will_absent')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('succession_answer_saved')), findsOneWidget);
    expect(find.byKey(const Key('succession_instrument_inheritancePact_question')), findsNothing);
    expect(loaded.persistence.saves, 1);
    await tester.tap(find.byKey(const Key('succession_next_question')));
    await tester.pump();
    expect(find.byKey(const Key('succession_instrument_inheritancePact_question')), findsOneWidget);
  });

  testWidgets('invalid root blocks every save and offers only reload/support',
      (tester) async {
    final loaded = await _provider(_unknownRoot(will: <String, dynamic>{'state': 'confirmedPresent'}));
    await tester.pumpWidget(_wrap(loaded.provider));
    expect(find.byKey(const Key('succession_reference_invalid')), findsOneWidget);
    expect(find.textContaining('support'), findsOneWidget);
    expect(find.byKey(const Key('succession_instrument_will_save')), findsNothing);
    expect(loaded.persistence.saves, 0);
  });

  testWidgets('terminal survey copy remains neutral and bounded', (tester) async {
    final loaded = await _provider(_allAbsentRoot());
    await tester.pumpWidget(_wrap(loaded.provider));
    expect(find.byKey(const Key('succession_reference_survey_recorded')), findsOneWidget);
    expect(find.textContaining('ne confirme ni le dossier'), findsOneWidget);
    expect(find.textContaining('prêt'), findsNothing);
    expect(loaded.persistence.saves, 0);
  });
}
