import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/avancement_hoirie_widget.dart';

void main() {
  final children = [
    const HoirieChild(name: 'Alice', emoji: '👧'),
    const HoirieChild(name: 'Bob', emoji: '👦'),
    const HoirieChild(name: 'Clara', emoji: '👧'),
  ];

  Widget buildWidget() => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AvancementHoirieWidget(
              totalPatrimoine: 600000,
              donationAmount: 100000,
              children: children,
              donationRecipientIndex: 0,
            ),
          ),
        ),
      );

  testWidgets('renders title', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('hoirie'), findsWidgets);
  });

  testWidgets('shows donation amount', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining("100'000"), findsWidgets);
  });

  testWidgets('shows children names', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('Alice'), findsWidgets);
    expect(find.textContaining('Bob'), findsWidgets);
  });

  testWidgets('shows CC legal reference', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('CC'), findsWidgets);
  });

  testWidgets('shows rapport à la masse', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('masse'), findsWidgets);
  });

  testWidgets('shows disclaimer', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.textContaining('conseil'), findsOneWidget);
  });

  testWidgets('has Semantics label', (tester) async {
    await tester.pumpWidget(buildWidget());
    expect(find.bySemanticsLabel(RegExp('hoirie', caseSensitive: false)), findsOneWidget);
  });
}
