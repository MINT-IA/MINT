import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/confidence_bar.dart';

void main() {
  Widget buildTestWidget({
    double score = 65,
    bool showLabel = true,
    List<Map<String, dynamic>>? enrichmentActions,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ConfidenceBar(
            score: score,
            showLabel: showLabel,
            enrichmentActions: enrichmentActions,
          ),
        ),
      ),
    );
  }

  group('ConfidenceBar', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(ConfidenceBar), findsOneWidget);
    });

    testWidgets('shows score percentage', (tester) async {
      await tester.pumpWidget(buildTestWidget(score: 72));
      await tester.pumpAndSettle();
      expect(find.textContaining('72%'), findsWidgets);
    });

    testWidgets('P1-I: shows zone description', (tester) async {
      await tester.pumpWidget(buildTestWidget(score: 75));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bonne'), findsWidgets);
    });

    testWidgets('P1-I: shows "Photo parfaite" at 95%', (tester) async {
      await tester.pumpWidget(buildTestWidget(score: 95));
      await tester.pumpAndSettle();
      expect(find.textContaining('Photo'), findsWidgets);
    });

    testWidgets('P1-I: shows zone markers', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.textContaining('40%'), findsWidgets);
      expect(find.textContaining('70%'), findsWidgets);
    });

    testWidgets('P1-I: shows enrichment actions when score < 80',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        score: 55,
        enrichmentActions: [
          {'label': 'Scanne ton certificat LPP', 'icon': Icons.camera_alt},
          {'label': 'V\u00e9rifie ta couverture AI'},
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('LPP'), findsWidgets);
      expect(find.textContaining('am\u00e9liorer'), findsWidgets);
    });

    testWidgets('P1-I: hides enrichment when score >= 80', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        score: 85,
        enrichmentActions: [
          {'label': 'Action inutile'},
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('am\u00e9liorer'), findsNothing);
    });

    testWidgets('handles zero score', (tester) async {
      await tester.pumpWidget(buildTestWidget(score: 0));
      await tester.pumpAndSettle();
      expect(find.byType(ConfidenceBar), findsOneWidget);
    });

    testWidgets('handles 100 score', (tester) async {
      await tester.pumpWidget(buildTestWidget(score: 100));
      await tester.pumpAndSettle();
      expect(find.byType(ConfidenceBar), findsOneWidget);
    });

    testWidgets('hides label when showLabel=false', (tester) async {
      await tester.pumpWidget(buildTestWidget(showLabel: false));
      await tester.pumpAndSettle();
      expect(find.textContaining('Qualit\u00e9'), findsNothing);
    });

    testWidgets('has Semantics', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byType(Semantics), findsWidgets);
    });
  });
}
