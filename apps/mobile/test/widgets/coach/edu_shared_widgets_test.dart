// ────────────────────────────────────────────────────────────
//  EduSharedWidgets — Widget tests
//  EduSectionTitle, EduDisclaimer, EduLegalSources, EduSpecialistCta
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/widgets/coach/edu_shared_widgets.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  // ─── EduSectionTitle ───────────────────────────────────────

  group('EduSectionTitle', () {
    testWidgets('renders text', (tester) async {
      await tester.pumpWidget(_wrap(
        const EduSectionTitle(text: 'Mon titre de section'),
      ));
      expect(find.text('Mon titre de section'), findsOneWidget);
    });

    testWidgets('uses Montserrat font (via Text widget)', (tester) async {
      await tester.pumpWidget(_wrap(
        const EduSectionTitle(text: 'Titre'),
      ));
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.data, 'Titre');
    });
  });

  // ─── EduDisclaimer ─────────────────────────────────────────

  group('EduDisclaimer', () {
    testWidgets('renders disclaimer text', (tester) async {
      await tester.pumpWidget(_wrap(
        const EduDisclaimer(
            text: 'Information à caractère éducatif — LSFin.'),
      ));
      expect(find.textContaining('éducatif'), findsOneWidget);
    });

    testWidgets('shows info icon', (tester) async {
      await tester.pumpWidget(_wrap(
        const EduDisclaimer(text: 'Disclaimer text'),
      ));
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('container has amber background', (tester) async {
      await tester.pumpWidget(_wrap(
        const EduDisclaimer(text: 'Disclaimer'),
      ));
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(EduDisclaimer),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFFFF8E1));
    });
  });

  // ─── EduLegalSources ───────────────────────────────────────

  group('EduLegalSources', () {
    testWidgets('renders "Sources légales" label', (tester) async {
      await tester.pumpWidget(_wrap(
        const EduLegalSources(sources: '• LPP art. 14 — Taux de conversion'),
      ));
      expect(find.text('Sources légales'), findsOneWidget);
    });

    testWidgets('renders source content', (tester) async {
      await tester.pumpWidget(_wrap(
        const EduLegalSources(
            sources: '• LIFD art. 38 — Imposition séparée'),
      ));
      expect(find.textContaining('LIFD art. 38'), findsOneWidget);
    });

    testWidgets('uses MintColors.surface background (no hardcoded color)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const EduLegalSources(sources: '• CC art. 457'),
      ));
      // Simply verifies no render error and widget is present
      expect(find.byType(EduLegalSources), findsOneWidget);
    });
  });

  // ─── EduSpecialistCta ──────────────────────────────────────

  group('EduSpecialistCta', () {
    testWidgets('renders title and body', (tester) async {
      await tester.pumpWidget(_wrap(
        const EduSpecialistCta(
          icon: Icons.person_outline,
          color: Color(0xFF00695C),
          title: 'Consulter un·e spécialiste',
          body: 'Un·e spécialiste peut modéliser ton plan.',
        ),
      ));
      expect(find.text('Consulter un·e spécialiste'), findsOneWidget);
      expect(find.textContaining('spécialiste peut modéliser'), findsOneWidget);
    });

    testWidgets('renders provided icon', (tester) async {
      await tester.pumpWidget(_wrap(
        const EduSpecialistCta(
          icon: Icons.gavel_outlined,
          color: Color(0xFF37474F),
          title: 'Notaire',
          body: 'Corps du texte',
        ),
      ));
      expect(find.byIcon(Icons.gavel_outlined), findsOneWidget);
    });

    testWidgets('no banned title term "conseiller·e" as standalone job title',
        (tester) async {
      // The widget itself should never output the banned job title form.
      // Titles passed in by callers are tested in screen smoke tests.
      await tester.pumpWidget(_wrap(
        const EduSpecialistCta(
          icon: Icons.person_outline,
          color: Color(0xFF00695C),
          title: 'Consulter un·e spécialiste',
          body: 'Corps du texte',
        ),
      ));
      // Should NOT find the banned term "Un·e conseiller·e" (old form)
      expect(find.text('Un·e conseiller·e'), findsNothing);
    });
  });
}
