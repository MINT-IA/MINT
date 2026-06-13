import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/screens/auth/register_screen.dart';

Widget _testApp() {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    home: ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider(),
      child: const RegisterScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
