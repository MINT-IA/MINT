// Régression : valider un montant faisait planter l'app en debug.
//
// CE QUI EST DÉMONTRÉ ICI. Avec l'ancien ordre — `onChanged(clamped)` d'abord,
// `Navigator.of(ctx).pop()` ensuite — ces tests échouent sur
// `assert(_dependents.isEmpty)` dans `InheritedElement.debugDeactivated()`.
// Avec l'ordre inverse, ils passent. L'ordre est le déclencheur.
//
// CE QUI N'EST PAS DÉMONTRÉ. Le mécanisme interne exact. Un `setState` parent
// pendant qu'une route modale est montée est normalement licite ; conclure que
// « la reconstruction invalide les dépendances héritées de la feuille » serait
// une explication plausible, pas une preuve. Ne pas la présenter comme la cause
// racine.
//
// POURQUOI CELA COMPTAIT. L'assert n'existe qu'en debug, donc l'incident était
// invisible en release. Mais il rendait TOUT fait saisissable inconfirmable sur
// simulateur, et donc la preuve device des écrans « gate dur » impossible à
// produire. 17 fichiers dépendent de ce widget.
//
// CONDITION DE REPRODUCTION. Le parent doit vraiment faire `setState` : un hôte
// qui ne reconstruit pas ne reproduit rien. C'est pourquoi `_Host` et
// `_FieldOnly` sont des `StatefulWidget` et non de simples conteneurs.
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

/// Même hôte, mais poussé sur une route : permet de constater qu'un `pop` de
/// trop ferait disparaître l'écran du dessous.
class _HostWithPage extends StatelessWidget {
  const _HostWithPage({required this.onValue});

  final ValueChanged<double> onValue;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: TextButton(
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Page du dessous'),
                        _FieldOnly(onValue: onValue),
                      ],
                    ),
                  ),
                ),
              ),
              child: const Text('Ouvrir la page'),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldOnly extends StatefulWidget {
  const _FieldOnly({required this.onValue});

  final ValueChanged<double> onValue;

  @override
  State<_FieldOnly> createState() => _FieldOnlyState();
}

class _FieldOnlyState extends State<_FieldOnly> {
  double _value = 1000;

  @override
  Widget build(BuildContext context) {
    return MintAmountField(
      label: 'Revenu annuel',
      value: _value,
      formatValue: (v) => v.round().toString(),
      onChanged: (v) {
        setState(() => _value = v);
        widget.onValue(v);
      },
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

    testWidgets('valider deux fois pendant l\'animation de fermeture '
        'ne notifie qu\'une fois et ne dépile pas l\'écran du dessous',
        (tester) async {
      // Une route reste montée pendant son animation inverse. Sans garde, la
      // seconde validation rappelle `onChanged` ET rejoue `Navigator.pop()` —
      // qui ferme alors l'écran SOUS la feuille. L'utilisateur qui tape deux
      // fois sur « OK » se retrouverait éjecté de l'écran.
      final received = <double>[];
      await tester.pumpWidget(_HostWithPage(onValue: received.add));

      await tester.tap(find.text('Ouvrir la page'));
      await tester.pumpAndSettle();
      expect(find.text('Page du dessous'), findsOneWidget);

      await tester.tap(find.text('Revenu annuel'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '4200');

      // Deux validations sans laisser l'animation se terminer.
      await tester.tap(find.text('OK'));
      await tester.pump(const Duration(milliseconds: 20));
      final okStillThere = find.text('OK').evaluate().isNotEmpty;
      if (okStillThere) {
        await tester.tap(find.text('OK'), warnIfMissed: false);
      }
      await tester.pumpAndSettle();

      expect(received, [4200.0],
          reason: 'une seule notification, même si le bouton est tapé deux fois');
      expect(find.text('Page du dessous'), findsOneWidget,
          reason: "l'écran du dessous ne doit pas avoir été dépilé");
    });

    testWidgets('la fermeture ne lève aucune exception, frame par frame',
        (tester) async {
      // `pumpAndSettle` saute d'un coup jusqu'à la stabilité et masque donc la
      // fenêtre dangereuse : les frames de l'animation inverse.
      final received = <double>[];
      await tester.pumpWidget(_Host(onValue: received.add));

      await tester.tap(find.text('Revenu annuel'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '4200');
      await tester.tap(find.text('OK'));

      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        expect(tester.takeException(), isNull,
            reason: 'aucune exception à la frame $i de la fermeture');
      }
      await tester.pumpAndSettle();
      expect(received, [4200.0]);
    });

    testWidgets('fermer la feuille sans valider ne notifie rien',
        (tester) async {
      final received = <double>[];
      await tester.pumpWidget(_Host(onValue: received.add));

      await tester.tap(find.text('Revenu annuel'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '4200');

      // Fermeture par glissement vers le bas, sans passer par « OK ».
      await tester.drag(find.byType(TextField), const Offset(0, 600));
      await tester.pumpAndSettle();

      expect(received, isEmpty,
          reason: 'une feuille abandonnée ne doit rien écrire');
      expect(find.byType(TextField), findsNothing);
    });
  });
}
