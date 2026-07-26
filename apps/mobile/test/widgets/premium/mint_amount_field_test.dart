// Régression : valider un montant faisait planter l'app en debug.
//
// `_applyValue` appelait `onChanged(clamped)` — donc le `setState` du parent,
// donc une reconstruction de l'arbre — PUIS `Navigator.of(ctx).pop()`, dans la
// même frame. La feuille modale était encore montée et dépendait d'éléments
// hérités que la reconstruction invalidait : Flutter levait
// `assert(_dependents.isEmpty)` dans `InheritedElement.debugDeactivated()`.
//
// L'assert n'existe qu'en debug, donc l'incident était invisible en release —
// mais il rendait TOUT fait saisissable inconfirmable sur simulateur, et donc
// toute la preuve device des écrans « gate dur » impossible à produire.
//
// Ces tests montent le widget dans un parent qui fait vraiment `setState`,
// c'est-à-dire la condition réelle d'usage. Sans le correctif, ils échouent.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';

/// Parent qui reconstruit à chaque changement — comme les écrans réels.
class _Host extends StatefulWidget {
  const _Host({this.min, this.max, required this.onValue});

  final double? min;
  final double? max;
  final ValueChanged<double> onValue;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  double _value = 1000;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(scaffoldBackgroundColor: MintColors.background),
      home: Scaffold(
        body: Center(
          child: MintAmountField(
            label: 'Revenu annuel',
            value: _value,
            formatValue: (v) => v.round().toString(),
            min: widget.min,
            max: widget.max,
            onChanged: (v) {
              setState(() => _value = v);
              widget.onValue(v);
            },
          ),
        ),
      ),
    );
  }
}

Future<void> _openSheetAndSubmit(
  WidgetTester tester,
  String text, {
  bool viaKeyboard = false,
}) async {
  await tester.tap(find.text('Revenu annuel'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), text);
  if (viaKeyboard) {
    await tester.testTextInput.receiveAction(TextInputAction.done);
  } else {
    await tester.tap(find.text('OK'));
  }
  await tester.pumpAndSettle();
}

void main() {
  group('MintAmountField — valider un montant ne doit pas planter', () {
    testWidgets('via le bouton OK : la valeur remonte, la feuille se ferme',
        (tester) async {
      final received = <double>[];
      await tester.pumpWidget(_Host(onValue: received.add));

      await _openSheetAndSubmit(tester, '4200');

      expect(received, [4200.0], reason: 'la valeur saisie doit remonter');
      expect(find.byType(TextField), findsNothing,
          reason: 'la feuille modale doit être fermée');
      expect(find.text('4200'), findsOneWidget,
          reason: 'le parent doit afficher la nouvelle valeur');
    });

    testWidgets('via la touche « done » du clavier : même contrat',
        (tester) async {
      final received = <double>[];
      await tester.pumpWidget(_Host(onValue: received.add));

      await _openSheetAndSubmit(tester, '7350', viaKeyboard: true);

      expect(received, [7350.0]);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('une valeur hors bornes est ramenée dans la plage, sans planter',
        (tester) async {
      final received = <double>[];
      await tester.pumpWidget(
        _Host(min: 500, max: 9000, onValue: received.add),
      );

      await _openSheetAndSubmit(tester, '99999');

      expect(received, [9000.0], reason: 'doit être ramenée au maximum');
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('deux saisies successives : le cycle est reproductible',
        (tester) async {
      final received = <double>[];
      await tester.pumpWidget(_Host(onValue: received.add));

      await _openSheetAndSubmit(tester, '3000');
      await _openSheetAndSubmit(tester, '5500');

      expect(received, [3000.0, 5500.0]);
      expect(find.text('5500'), findsOneWidget);
    });
  });
}
