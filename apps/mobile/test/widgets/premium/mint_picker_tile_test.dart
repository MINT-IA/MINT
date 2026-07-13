import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/premium/mint_picker_tile.dart';

void main() {
  testWidgets(
      'nullable value shows placeholder and publishes min only after OK',
      (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MintPickerTile(
            value: null,
            label: 'Années hors Suisse',
            placeholder: 'À renseigner',
            minValue: 0,
            maxValue: 44,
            formatValue: (value) => '$value ans',
            onChanged: changes.add,
          ),
        ),
      ),
    );

    expect(find.text('À renseigner'), findsOneWidget);

    await tester.tap(find.text('À renseigner'));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
    expect(
      picker.scrollController!.initialItem,
      0,
    );
    expect(changes, isEmpty, reason: 'opening or scrolling must not publish');

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(changes, isEmpty, reason: 'dismissing must preserve unknown');

    await tester.tap(find.text('À renseigner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(changes, [0], reason: 'OK is the explicit user selection');
  });
}
