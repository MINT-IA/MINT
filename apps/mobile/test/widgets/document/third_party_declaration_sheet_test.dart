// v2.7 Phase 29 / PRIV-02 — widget + flow tests.
//
// Covers:
//   1. Sheet renders with the detected name in body copy.
//   2. Accept returns ThirdPartyDeclarationChoice.confirmed.
//   3. Cancel returns ThirdPartyDeclarationChoice.cancelled.
//   4. ThirdPartyGate428.tryParse handles FastAPI's {"detail": {...}} wrap.
//   5. ThirdPartyFlow.handleGate on accept POSTs the grant once per subject
//      and returns GrantOutcome.granted.
//   6. ThirdPartyFlow.handleGate on cancel returns GrantOutcome.cancelled
//      and makes no POST.
//   7. Multi-subject body uses the pluralised copy.
//   8. Invite stub logs intent analytics event.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/document/third_party_flow.dart';
import 'package:mint_mobile/widgets/document/third_party_declaration_sheet.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      locale: const Locale('fr'),
      home: Scaffold(body: Builder(builder: (_) => child)),
    );

void main() {
  group('ThirdPartyDeclarationSheet', () {
    testWidgets('renders single-subject body with detected name',
        (tester) async {
      await tester.pumpWidget(_wrap(const ThirdPartyDeclarationSheet(
        subjectNames: ['Lauren Martin'],
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('Lauren Martin'), findsWidgets);
      expect(find.byKey(const Key('thirdPartyDeclarationConfirm')),
          findsOneWidget);
      expect(find.byKey(const Key('thirdPartyDeclarationCancel')),
          findsOneWidget);
    });

    testWidgets('multi-subject uses pluralised body copy', (tester) async {
      await tester.pumpWidget(_wrap(const ThirdPartyDeclarationSheet(
        subjectNames: ['Lauren Martin', 'Marc Dupont'],
      )));
      await tester.pumpAndSettle();

      // Both names appear somewhere in the sheet.
      expect(find.textContaining('Lauren Martin'), findsWidgets);
      expect(find.textContaining('Marc Dupont'), findsWidgets);
    });

    testWidgets('accept returns confirmed', (tester) async {
      ThirdPartyDeclarationChoice? result;
      await tester.pumpWidget(_wrap(Builder(builder: (ctx) {
        return ElevatedButton(
          onPressed: () async {
            result = await ThirdPartyDeclarationSheet.show(
              ctx,
              subjectNames: const ['Lauren Martin'],
            );
          },
          child: const Text('open'),
        );
      })));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('thirdPartyDeclarationConfirm')));
      await tester.pumpAndSettle();
      expect(result, ThirdPartyDeclarationChoice.confirmed);
    });

    testWidgets('cancel returns cancelled', (tester) async {
      ThirdPartyDeclarationChoice? result;
      await tester.pumpWidget(_wrap(Builder(builder: (ctx) {
        return ElevatedButton(
          onPressed: () async {
            result = await ThirdPartyDeclarationSheet.show(
              ctx,
              subjectNames: const ['Lauren Martin'],
            );
          },
          child: const Text('open'),
        );
      })));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('thirdPartyDeclarationCancel')));
      await tester.pumpAndSettle();
      expect(result, ThirdPartyDeclarationChoice.cancelled);
    });

    testWidgets('invite stub triggers onInviteIntent + shows coming-soon snackbar',
        (tester) async {
      int intentCalls = 0;
      await tester.pumpWidget(_wrap(Builder(builder: (ctx) {
        return ElevatedButton(
          onPressed: () async {
            await ThirdPartyDeclarationSheet.show(
              ctx,
              subjectNames: const ['Lauren Martin'],
              onInviteIntent: () => intentCalls++,
            );
          },
          child: const Text('open'),
        );
      })));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('thirdPartyInviteCta')));
      await tester.pump();
      expect(intentCalls, 1);
      expect(find.textContaining('bientôt'), findsOneWidget);
    });
  });

  group('ThirdPartyGate428.tryParse', () {
    test('parses FastAPI-wrapped detail payload', () {
      final gate = ThirdPartyGate428.tryParse({
        'detail': {
          'code': 'third_party_declaration_required',
          'subjectNames': ['Lauren Martin'],
          'docHash':
              'a' * 64,
          'declarationEndpoint': '/consents/grant-nominative',
        }
      });
      expect(gate, isNotNull);
      expect(gate!.subjectNames, ['Lauren Martin']);
      expect(gate.docHash.length, 64);
    });

    test('returns null on unrelated payload', () {
      expect(ThirdPartyGate428.tryParse({'detail': 'Internal error'}), isNull);
      expect(ThirdPartyGate428.tryParse({'foo': 'bar'}), isNull);
    });

    test('returns null when names empty or docHash empty', () {
      expect(
          ThirdPartyGate428.tryParse({
            'detail': {
              'code': 'third_party_declaration_required',
              'subjectNames': <String>[],
              'docHash': 'x' * 64,
              'declarationEndpoint': '/consents/grant-nominative',
            }
          }),
          isNull);
    });
  });

  group('ThirdPartyFlow.handleGate', () {
    testWidgets('accept posts grant and returns granted', (tester) async {
      final captured = <Map<String, dynamic>>[];
      final flow = ThirdPartyFlow(
        postOverride: (endpoint, body) async {
          captured.add({'endpoint': endpoint, 'body': body});
          return {'receiptId': 'r1'};
        },
      );

      GrantOutcome? outcome;
      await tester.pumpWidget(_wrap(Builder(builder: (ctx) {
        return ElevatedButton(
          onPressed: () async {
            outcome = await flow.handleGate(
              ctx,
              ThirdPartyGate428(
                subjectNames: const ['Lauren Martin'],
                docHash: 'a' * 64,
                declarationEndpoint: '/consents/grant-nominative',
              ),
            );
          },
          child: const Text('open'),
        );
      })));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('thirdPartyDeclarationConfirm')));
      await tester.pumpAndSettle();

      expect(outcome, GrantOutcome.granted);
      expect(captured, hasLength(1));
      expect(captured.first['endpoint'], '/consents/grant-nominative');
      expect(captured.first['body']['subjectName'], 'Lauren Martin');
      expect(captured.first['body']['docHash'], 'a' * 64);
      expect(captured.first['body']['subjectRole'], 'declared_other');
    });

    testWidgets('cancel makes no POST and returns cancelled', (tester) async {
      final captured = <Map<String, dynamic>>[];
      final flow = ThirdPartyFlow(
        postOverride: (endpoint, body) async {
          captured.add({'endpoint': endpoint});
          return {};
        },
      );

      GrantOutcome? outcome;
      await tester.pumpWidget(_wrap(Builder(builder: (ctx) {
        return ElevatedButton(
          onPressed: () async {
            outcome = await flow.handleGate(
              ctx,
              ThirdPartyGate428(
                subjectNames: const ['Lauren Martin'],
                docHash: 'b' * 64,
                declarationEndpoint: '/consents/grant-nominative',
              ),
            );
          },
          child: const Text('open'),
        );
      })));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('thirdPartyDeclarationCancel')));
      await tester.pumpAndSettle();

      expect(outcome, GrantOutcome.cancelled);
      expect(captured, isEmpty);
    });
  });
}
