// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/widgets/onboarding/premier_eclairage_card.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

const _snapshotKey = 'premier_eclairage_snapshot_v1';

Map<String, dynamic> _normalSnapshot({String? confidenceMode}) => {
      'value': '7\'258 CHF',
      'title': 'Ton économie 3a annuelle',
      'subtitle': 'Montant déductible maximum pilier 3a.',
      'suggestedRoute': '/pilier-3a',
      'colorKey': 'success',
      'confidenceMode': confidenceMode ?? 'real',
    };

Future<Widget> _buildCard({
  Map<String, dynamic>? snapshot,
  VoidCallback? onDismiss,
  void Function(String)? onNavigate,
}) async {
  // Set SharedPreferences mock values
  final prefs = <String, Object>{};
  if (snapshot != null) {
    prefs[_snapshotKey] = jsonEncode(snapshot);
  }
  SharedPreferences.setMockInitialValues(prefs);

  return MaterialApp.router(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: const [Locale('fr')],
    locale: const Locale('fr'),
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: PremierEclairageCard(
              onDismiss: onDismiss ?? () {},
              onNavigate: onNavigate ?? (_) {},
            ),
          ),
        ),
        GoRoute(
          path: '/pilier-3a',
          builder: (_, __) => const Scaffold(body: Text('pilier-3a')),
        ),
        GoRoute(
          path: '/onboarding/quick-start',
          builder: (_, __) => const Scaffold(body: Text('quick-start')),
        ),
      ],
    ),
  );
}

// ─── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('PremierEclairageCard', () {
    testWidgets('shows number and title from snapshot', (tester) async {
      final widget = await _buildCard(snapshot: _normalSnapshot());
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text("7'258 CHF"), findsOneWidget);
      expect(find.text('Ton économie 3a annuelle'), findsOneWidget);
    });

    testWidgets('shows subtitle from snapshot', (tester) async {
      final widget = await _buildCard(snapshot: _normalSnapshot());
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Montant déductible maximum pilier 3a.'),
          findsOneWidget);
    });

    testWidgets('CTA tap calls onNavigate with suggestedRoute from snapshot',
        (tester) async {
      String? capturedRoute;
      final widget = await _buildCard(
        snapshot: _normalSnapshot(),
        onNavigate: (r) => capturedRoute = r,
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Find the "Comprendre" button
      await tester.tap(find.text('Comprendre'));
      await tester.pump();

      expect(capturedRoute, '/pilier-3a');
    });

    testWidgets('dismiss tap calls onDismiss', (tester) async {
      var dismissed = false;
      final widget = await _buildCard(
        snapshot: _normalSnapshot(),
        onDismiss: () => dismissed = true,
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('shows error state when snapshot is null', (tester) async {
      final widget = await _buildCard(snapshot: null);
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Calcul non disponible'), findsOneWidget);
      expect(find.text('Complète ton profil pour voir ton premier aperçu.'),
          findsOneWidget);
      expect(find.text('Personnaliser'), findsOneWidget);
    });

    testWidgets(
        'pedagogical mode shows estimate label',
        (tester) async {
      final widget = await _buildCard(
        snapshot: _normalSnapshot(confidenceMode: 'pedagogical'),
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Estimation moyenne suisse'), findsOneWidget);
    });

    testWidgets('card shows mandatory disclaimer text', (tester) async {
      final widget = await _buildCard(snapshot: _normalSnapshot());
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Disclaimer contains "LSFin" per CLAUDE.md §6 requirement
      expect(
        find.textContaining('LSFin'),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('error state personalise CTA calls onNavigate with coach chat',
        (tester) async {
      // P10-02b: QuickStartScreen deleted → CTA now routes to /coach/chat.
      String? capturedRoute;
      final widget = await _buildCard(
        snapshot: null,
        onNavigate: (r) => capturedRoute = r,
      );
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Personnaliser'));
      await tester.pump();

      expect(capturedRoute, '/coach/chat');
    });
  });
}
