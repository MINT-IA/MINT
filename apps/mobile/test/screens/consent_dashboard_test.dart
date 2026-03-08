import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/screens/consent_dashboard_screen.dart';
import 'package:mint_mobile/services/privacy_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

void main() {
  // =========================================================================
  // CONSENT DASHBOARD SCREEN — Smoke tests
  // =========================================================================
  //
  // Tests the ConsentDashboardScreen which uses PrivacyService to display
  // 6 data consent categories (1 required, 5 optional) with switches,
  // export/revoke buttons, disclaimer, and legal sources.
  // =========================================================================

  Widget buildApp() {
    return const MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: ConsentDashboardScreen(),
    );
  }

  group('ConsentDashboardScreen - rendu initial', () {
    testWidgets('renders without error', (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('CENTRE DE CONTROLE DATA'), findsOneWidget);
    });

    testWidgets('displays all 6 category cards', (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      // Verify each category label is displayed
      for (final cat in PrivacyService.dataCategories) {
        final label = cat['label'] as String;
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'Category "$label" should be visible',
        );
      }
    });

    testWidgets('required category shows "Requis" tag',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      // core_profile is the only required category => "Requis" tag
      expect(find.text('Requis'), findsOneWidget);
    });

    testWidgets('optional categories have switches',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      // 5 optional categories => 5 switches
      // Switch.adaptive renders as Switch on test platform
      expect(find.byType(Switch), findsNWidgets(5));
    });

    testWidgets('section headers are displayed', (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      expect(find.text('Consentements requis'), findsOneWidget);
      expect(find.text('Consentements optionnels'), findsOneWidget);
    });
  });

  group('ConsentDashboardScreen - boutons', () {
    testWidgets('revoke all button exists', (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      expect(
        find.text('REVOQUER TOUS LES CONSENTEMENTS OPTIONNELS'),
        findsOneWidget,
      );
    });

    testWidgets('export button exists', (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      expect(
        find.text('Exporter mes donnees (nLPD art. 28)'),
        findsOneWidget,
      );
    });
  });

  group('ConsentDashboardScreen - disclaimer et sources', () {
    testWidgets('disclaimer text is displayed', (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      // The disclaimer is from PrivacyService.disclaimer
      // Check for a distinctive substring rather than the full text
      expect(
        find.textContaining('nLPD'),
        findsWidgets,
      );
      expect(
        find.textContaining('jamais vendues'),
        findsOneWidget,
      );
    });

    testWidgets('legal sources section is displayed',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      expect(find.text('Sources legales'), findsOneWidget);

      // Verify at least one source bullet is rendered
      for (final source in PrivacyService.sources) {
        expect(
          find.textContaining(source.substring(0, 10)),
          findsWidgets,
          reason: 'Source "$source" should be visible',
        );
      }
    });
  });

  group('ConsentDashboardScreen - security header', () {
    testWidgets('security message is displayed', (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      expect(
        find.textContaining('Tes donnees restent sur ton appareil'),
        findsOneWidget,
      );
    });

    testWidgets('lock icon is displayed', (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      expect(find.byIcon(Icons.lock_person_outlined), findsOneWidget);
    });
  });

  group('ConsentDashboardScreen - category details', () {
    testWidgets('each category shows description',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      for (final cat in PrivacyService.dataCategories) {
        final description = cat['description'] as String;
        expect(
          find.text(description),
          findsOneWidget,
          reason: 'Description for "${cat['id']}" should be visible',
        );
      }
    });

    testWidgets('each category shows retention days tag',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      for (final cat in PrivacyService.dataCategories) {
        final retentionDays = cat['retentionDays'] as int;
        expect(
          find.textContaining('Conservation: $retentionDays jours'),
          findsWidgets,
          reason: 'Retention tag for "${cat['id']}" should be visible',
        );
      }
    });

    testWidgets('each category shows legal basis tag',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      for (final cat in PrivacyService.dataCategories) {
        final legalBasis = cat['legalBasis'] as String;
        expect(
          find.text(legalBasis),
          findsWidgets,
          reason: 'Legal basis tag for "${cat['id']}" should be visible',
        );
      }
    });
  });
}
