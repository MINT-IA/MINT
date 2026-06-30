import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/screens/auth/login_screen.dart';
import 'package:mint_mobile/services/apple_sign_in_service.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

void main() {
  Widget testApp() {
    return MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(),
        child: const LoginScreen(),
      ),
    );
  }

  testWidgets('Apple login does not request recreate-after-delete opt-in',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AppleSignInService.resetOverrides();
    AppleSignInService.signInOverride = () async => null;
    try {
      await tester.pumpWidget(testApp());
      await tester.pump();

      await tester.tap(find.byType(SignInWithAppleButton));
      await tester.pump();

      expect(
        AppleSignInService.debugLastAllowRecreateAfterDeleteForTest,
        isFalse,
      );
    } finally {
      AppleSignInService.resetOverrides();
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
