import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/auth/register_screen.dart';
import 'package:mint_mobile/services/account_handoff_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';

Widget _testApp({CoachProfileProvider? coachProfileProvider}) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider<CoachProfileProvider>.value(
          value: coachProfileProvider ?? CoachProfileProvider(),
        ),
      ],
      child: const RegisterScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FeatureFlags.enableMvpWedgeOnboarding = false;
  });

  tearDown(() {
    FeatureFlags.enableMvpWedgeOnboarding = false;
  });

  testWidgets('iOS registration starts with Apple and keeps email as fallback',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      expect(find.byType(SignInWithAppleButton), findsOneWidget);
      expect(find.text('Créer avec e-mail'), findsOneWidget);
      expect(find.byIcon(Icons.email_outlined), findsNothing);

      await tester.ensureVisible(find.text('Créer avec e-mail'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer avec e-mail'));
      await tester.pump();

      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Apple registration requires legal consents before native auth',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      await tester.tap(find.byType(SignInWithAppleButton));
      await tester.pump();

      expect(
        find.text(
            "Confirme les conditions et l'âge avant de créer ton compte."),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Apple registration explains date of birth is still needed',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      expect(
        find.textContaining('Apple ne transmet pas ta date de naissance'),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('registration exposes and persists anonymous handoff choice',
      (tester) async {
    FeatureFlags.enableMvpWedgeOnboarding = true;
    SharedPreferences.setMockInitialValues({
      'wizard_answers_v2': '{"q_canton":"VD"}',
    });

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(_testApp());
      await tester.pump();
      await tester.pump();

      expect(find.text('Données locales'), findsOneWidget);
      expect(find.text('Conserver'), findsOneWidget);
      expect(find.text('Repartir'), findsOneWidget);

      await tester.tap(find.text('Repartir'));
      await tester.pump();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(AccountHandoffService.choiceKey),
        'restart_clean',
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('registration detects session-only wedge profile',
      (tester) async {
    FeatureFlags.enableMvpWedgeOnboarding = true;
    final coachProfileProvider = CoachProfileProvider()
      ..updateFromAnswers({
        'onb_intent': 'explorer',
        'q_birth_year': 1992,
        'q_canton': 'VD',
        'q_net_income_period_chf': 7250,
      });

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(_testApp(
        coachProfileProvider: coachProfileProvider,
      ));
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          'Mint a des éléments sur cet appareil: diagnostic, brouillons ou discussion anonyme.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Aucune donnée locale Mint détectée sur cet appareil.'),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('non-iOS registration keeps legal consents after email fields',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      expect(find.byType(SignInWithAppleButton), findsNothing);
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);

      final emailTop = tester.getTopLeft(find.byIcon(Icons.email_outlined)).dy;
      final consentTop =
          tester.getTopLeft(find.textContaining('Je confirme avoir 18 ans')).dy;

      expect(emailTop, lessThan(consentTop));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
