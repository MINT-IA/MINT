import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/coach/succession_evidence_quest.dart';
import 'package:provider/provider.dart';

final class _MemoryPersistence
    with SerializedCanonicalAnswerMutationPersistence
    implements TaxProfilePersistence, LppProfilePersistence {
  _MemoryPersistence(this.answers);
  Map<String, dynamic> answers;
  int saves = 0;
  Object? saveFailure;

  @override
  Future<Map<String, dynamic>> loadAnswers() async =>
      Map<String, dynamic>.from(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> next) async {
    saves++;
    final failure = saveFailure;
    if (failure != null) throw failure;
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

Map<String, dynamic> _staleRoot() {
  final answers = _unknownRoot();
  final raw = jsonDecode(answers['_coach_estate_evidence_v1'] as String) as Map;
  (raw['estateInstruments'] as Map)['will'] = <String, dynamic>{
    'state': 'confirmedAbsent',
    'confirmation': <String, dynamic>{
      'evidenceId': '55555555-5555-4555-8555-555555555555',
      'ownerKind': 'self',
      'source': 'userInput',
      'confirmedAt': DateTime.utc(2026, 7, 20).toIso8601String(),
      'civilStatusAtConfirmation': 'marie',
    },
  };
  answers['_coach_estate_evidence_v1'] = jsonEncode(raw);
  return answers;
}

Map<String, dynamic> _stalePresentRoot({
  String kind = 'will',
}) {
  final answers = _unknownRoot();
  final raw = jsonDecode(answers['_coach_estate_evidence_v1'] as String) as Map;
  (raw['estateInstruments'] as Map)[kind] = <String, dynamic>{
    'state': 'confirmedPresent',
    'evidence': <String, dynamic>{
      'evidenceId': '77777777-7777-4777-8777-777777777777',
      'ownerKind': 'self',
      'source': 'certificate',
      'sourceDate': '2026-01-15',
      'legalYear': 2026,
      'confirmedAt': DateTime.utc(2026, 7, 20).toIso8601String(),
      'civilStatusAtConfirmation': 'marie',
    },
  };
  answers['_coach_estate_evidence_v1'] = jsonEncode(raw);
  return answers;
}

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
    _provider(Map<String, dynamic> answers,
        {String civil = 'celibataire'}) async {
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
  );
}

void main() {
  testWidgets('ambiguous civil status guards and routes to exact collector',
      (tester) async {
    final loaded = await _provider(_unknownRoot(), civil: 'partenariat');
    expect(loaded.provider.profile!.civilStatusNeedsConfirmation, isTrue);
    await tester.pumpWidget(_wrap(loaded.provider));
    expect(
        find.byKey(const Key('succession_civil_status_guard')), findsOneWidget);
    expect(find.byKey(const Key('succession_civil_status_confirm')),
        findsOneWidget);
    expect(loaded.persistence.saves, 0);
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('inputKey=q_civil_status'), findsOneWidget);
  });

  testWidgets('marriage and LPart require explicit dedicated choices',
      (tester) async {
    for (final civil in <String>['marie', 'registeredPartnership']) {
      final loaded = await _provider(_unknownRoot(), civil: civil);
      await tester.pumpWidget(_wrap(loaded.provider));
      final save = find.byKey(const Key('succession_arrangement_save'));
      expect(find.byKey(const Key('succession_arrangement_question')),
          findsOneWidget);
      expect(tester.widget<ElevatedButton>(save).onPressed, isNull);
      expect(loaded.persistence.saves, 0);

      await tester.tap(find.byKey(const Key('succession_arrangement_enum')));
      await tester.pumpAndSettle();
      final label = civil == 'marie'
          ? 'Séparation de biens'
          : 'Autre convention patrimoniale';
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(save).onPressed, isNotNull);
      await tester.tap(save);
      await tester.pumpAndSettle();

      final root = jsonDecode(
              loaded.persistence.answers['_coach_estate_evidence_v1'] as String)
          as Map;
      final branch = civil == 'marie'
          ? 'matrimonialRegime'
          : 'registeredPartnershipPropertyRegime';
      final otherBranch = civil == 'marie'
          ? 'registeredPartnershipPropertyRegime'
          : 'matrimonialRegime';
      expect((root[branch] as Map)['kind'],
          civil == 'marie' ? 'separationOfProperty' : 'otherPropertyAgreement');
      expect(root[otherBranch], isNull);
      expect(loaded.persistence.saves, 1);
    }
  });

  testWidgets('LPart presents the exact three distinct property labels',
      (tester) async {
    final loaded = await _provider(
      _unknownRoot(),
      civil: 'registeredPartnership',
    );
    await tester.pumpWidget(_wrap(loaded.provider));
    expect(
      find.text('Rapports patrimoniaux du partenariat enregistré déclarés'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('succession_arrangement_enum')));
    await tester.pumpAndSettle();
    expect(
      find.text('Séparation des biens — règle de base LPart'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Convention prévoyant un partage selon les règles de la participation aux acquêts',
      ),
      findsOneWidget,
    );
    expect(find.text('Autre convention patrimoniale'), findsOneWidget);
  });

  testWidgets('present requires explicit source date and legal year',
      (tester) async {
    final loaded = await _provider(_unknownRoot());
    await tester.pumpWidget(_wrap(loaded.provider));
    await tester
        .tap(find.byKey(const Key('succession_instrument_will_present')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('succession_instrument_will_save')));
    await tester.pump();
    expect(find.byKey(const Key('succession_instrument_will_validation_error')),
        findsOneWidget);
    expect(loaded.persistence.saves, 0);
    await tester.enterText(
        find.byKey(const Key('succession_instrument_will_source_date')),
        '2026-01-15');
    await tester.enterText(
        find.byKey(const Key('succession_instrument_will_legal_year')), '2026');
    await tester.tap(find.byKey(const Key('succession_instrument_will_save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('succession_answer_saved')), findsOneWidget);
    expect(loaded.persistence.saves, 1);
    final root = jsonDecode(
      loaded.persistence.answers['_coach_estate_evidence_v1'] as String,
    ) as Map;
    final slot = (root['estateInstruments'] as Map)['will'] as Map;
    expect(slot['state'], 'confirmedPresent');
    expect((slot['evidence'] as Map)['source'], 'certificate');
    expect((slot['evidence'] as Map)['sourceDate'], '2026-01-15');
    expect((slot['evidence'] as Map)['legalYear'], 2026);
    expect(
      loaded.provider.profile!.estateInstrumentSlots.first.state,
      EstateInstrumentSlotState.confirmedPresent,
    );
    for (final kind in <String>[
      'inheritancePact',
      'incapacityMandate',
      'advanceCareDirective',
    ]) {
      expect((root['estateInstruments'] as Map)[kind], {'state': 'unknown'});
    }
  });

  testWidgets('absence persists once and never auto-advances', (tester) async {
    final loaded = await _provider(_unknownRoot());
    await tester.pumpWidget(_wrap(loaded.provider));
    await tester
        .tap(find.byKey(const Key('succession_instrument_will_absent')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('succession_answer_saved')), findsOneWidget);
    expect(
        find.byKey(const Key('succession_instrument_inheritancePact_question')),
        findsNothing);
    expect(loaded.persistence.saves, 1);
    final root = jsonDecode(
      loaded.persistence.answers['_coach_estate_evidence_v1'] as String,
    ) as Map;
    final slots = root['estateInstruments'] as Map;
    expect((slots['will'] as Map)['state'], 'confirmedAbsent');
    expect(
        ((slots['will'] as Map)['confirmation'] as Map)['source'], 'userInput');
    for (final kind in <String>[
      'inheritancePact',
      'incapacityMandate',
      'advanceCareDirective',
    ]) {
      expect(slots[kind], {'state': 'unknown'});
    }
    await tester.tap(find.byKey(const Key('succession_next_question')));
    await tester.pump();
    expect(
        find.byKey(const Key('succession_instrument_inheritancePact_question')),
        findsOneWidget);
  });

  testWidgets('stale present reconfirms unchanged metadata in one tap',
      (tester) async {
    final loaded = await _provider(_stalePresentRoot());
    await tester.pumpWidget(_wrap(loaded.provider));
    final prior = find.byKey(
      const Key('succession_instrument_will_prior_state'),
    );
    expect(prior, findsOneWidget);
    expect(find.descendant(of: prior, matching: find.text('Présent')),
        findsOneWidget);
    expect(find.descendant(of: prior, matching: find.text('2026-01-15')),
        findsOneWidget);
    expect(find.descendant(of: prior, matching: find.text('2026')),
        findsOneWidget);
    expect(
        find.textContaining('effets juridiques non vérifiés'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('succession_instrument_will_reconfirm')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('succession_answer_saved')), findsOneWidget);
    final root = jsonDecode(
      loaded.persistence.answers['_coach_estate_evidence_v1'] as String,
    ) as Map;
    final evidence = (((root['estateInstruments'] as Map)['will']
        as Map)['evidence'] as Map);
    expect(evidence['sourceDate'], '2026-01-15');
    expect(evidence['legalYear'], 2026);
    expect(loaded.persistence.saves, 1);
  });

  testWidgets('stale slot is asked before earlier unknown enum slots',
      (tester) async {
    final loaded = await _provider(
      _stalePresentRoot(kind: 'inheritancePact'),
    );
    await tester.pumpWidget(_wrap(loaded.provider));
    expect(
      find.byKey(
        const Key('succession_instrument_inheritancePact_question'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('succession_instrument_will_question')),
      findsNothing,
    );
  });

  testWidgets('stale absence reconfirms with rendered evidence CAS id',
      (tester) async {
    final loaded = await _provider(_staleRoot());
    await tester.pumpWidget(_wrap(loaded.provider));
    expect(find.byKey(const Key('succession_instrument_will_stale')),
        findsOneWidget);
    final prior = find.byKey(
      const Key('succession_instrument_will_prior_state'),
    );
    expect(find.descendant(of: prior, matching: find.text('Absent')),
        findsOneWidget);
    expect(find.descendant(of: prior, matching: find.text('2026-07-20')),
        findsOneWidget);
    expect(find.textContaining('déclaration non vérifiée'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('succession_instrument_will_reconfirm')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('succession_answer_saved')), findsOneWidget);
    expect(loaded.persistence.saves, 1);
  });

  testWidgets('divorce and widow states surface the prior-union question',
      (tester) async {
    for (final civil in <String>['divorce', 'veuf']) {
      final loaded = await _provider(_unknownRoot(), civil: civil);
      await tester.pumpWidget(_wrap(loaded.provider));
      expect(
        find.byKey(const Key('succession_prior_union_specialist_question')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('succession_instrument_will_question')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('succession_arrangement_question')),
        findsNothing,
      );
    }
  });

  testWidgets('persistence failure retains the card and allows retry',
      (tester) async {
    final loaded = await _provider(_unknownRoot());
    loaded.persistence.saveFailure = Exception('disk unavailable');
    await tester.pumpWidget(_wrap(loaded.provider));
    await tester.tap(
      find.byKey(const Key('succession_instrument_will_absent')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('succession_answer_saved')), findsNothing);
    expect(
      find.byKey(const Key('succession_instrument_will_question')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('succession_instrument_will_save_error')),
      findsOneWidget,
    );
    loaded.persistence.saveFailure = null;
    await tester.tap(
      find.byKey(const Key('succession_instrument_will_absent')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('succession_answer_saved')), findsOneWidget);
  });

  testWidgets('CAS loss refreshes and never shows optimistic success',
      (tester) async {
    final loaded = await _provider(_unknownRoot());
    await tester.pumpWidget(_wrap(loaded.provider));
    final changed = _unknownRoot();
    final raw =
        jsonDecode(changed['_coach_estate_evidence_v1'] as String) as Map;
    (raw['estateInstruments'] as Map)['will'] = <String, dynamic>{
      'state': 'confirmedAbsent',
      'confirmation': <String, dynamic>{
        'evidenceId': '66666666-6666-4666-8666-666666666666',
        'ownerKind': 'self',
        'source': 'userInput',
        'confirmedAt': DateTime.utc(2026, 7, 20).toIso8601String(),
        'civilStatusAtConfirmation': 'celibataire',
      },
    };
    loaded.persistence.answers['_coach_estate_evidence_v1'] = jsonEncode(raw);
    await tester
        .tap(find.byKey(const Key('succession_instrument_will_absent')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('succession_answer_saved')), findsNothing);
    expect(find.textContaining('données ont changé'), findsOneWidget);
    expect(loaded.persistence.saves, 0);
  });

  testWidgets('invalid root blocks every save and offers only reload/support',
      (tester) async {
    final loaded = await _provider(
        _unknownRoot(will: <String, dynamic>{'state': 'confirmedPresent'}));
    await tester.pumpWidget(_wrap(loaded.provider));
    expect(
        find.byKey(const Key('succession_reference_invalid')), findsOneWidget);
    expect(find.textContaining('support'), findsOneWidget);
    expect(
        find.byKey(const Key('succession_instrument_will_save')), findsNothing);
    final exactRoot = loaded.persistence.answers['_coach_estate_evidence_v1'];
    expect(loaded.persistence.saves, 0);
    await tester.tap(find.text('Recharger'));
    await tester.pumpAndSettle();
    expect(loaded.persistence.answers['_coach_estate_evidence_v1'], exactRoot);
    expect(loaded.persistence.saves, 0);
  });

  testWidgets('terminal survey copy remains neutral and bounded',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final loaded = await _provider(_allAbsentRoot());
    await tester.pumpWidget(_wrap(loaded.provider));
    expect(find.byKey(const Key('succession_reference_survey_recorded')),
        findsOneWidget);
    expect(find.textContaining('ne constitue pas un dossier'), findsOneWidget);
    expect(find.textContaining('prêt pour'), findsOneWidget);
    expect(find.textContaining('contenu, validité et effets non vérifiés'),
        findsOneWidget);
    for (final kind in <String>[
      'will',
      'inheritancePact',
      'incapacityMandate',
      'advanceCareDirective',
    ]) {
      final summary = find.byKey(Key('succession_instrument_${kind}_summary'));
      expect(summary, findsOneWidget);
      expect(
        find.descendant(of: summary, matching: find.textContaining('Absent')),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: summary, matching: find.textContaining('2026-07-20')),
        findsOneWidget,
      );
    }
    expect(loaded.persistence.saves, 0);
    await tester.tap(
      find.byKey(const Key('succession_instrument_will_modify')),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('succession_instrument_will_question')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('succession_instrument_will_absent')),
      findsOneWidget,
    );
  });
}
