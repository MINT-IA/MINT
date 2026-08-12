import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/screens/auth/login_screen.dart';
import 'package:mint_mobile/services/api_service.dart';
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

  // Router harness so the recreate CTA's `context.go('/auth/register')` resolves.
  Widget routedApp() {
    final router = GoRouter(
      initialLocation: '/auth/login',
      routes: [
        GoRoute(
          path: '/auth/login',
          builder: (_, __) => ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(),
            child: const LoginScreen(),
          ),
        ),
        GoRoute(
          path: '/auth/register',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('REGISTER_STUB'))),
        ),
      ],
    );
    return MaterialApp.router(
      routerConfig: router,
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
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

  testWidgets(
      'Apple login recreate_required shows localized copy + recreate CTA, '
      'never the raw backend English', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AppleSignInService.resetOverrides();
    // The Apple verify endpoint returns 409 with an English server message.
    AppleSignInService.signInOverride = () async {
      throw const ApiException(
        'Apple account was deleted. Recreate it explicitly to continue.',
        statusCode: 409,
        backendCode: 'recreate_required',
      );
    };
    try {
      final l10n = await S.delegate.load(const Locale('fr'));
      await tester.pumpWidget(testApp());
      await tester.pump();

      await tester.tap(find.byType(SignInWithAppleButton));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // The raw backend English must NEVER reach the UI.
      expect(find.textContaining('Apple account was deleted'), findsNothing);
      expect(find.textContaining('Recreate it explicitly'), findsNothing);
      // Localized error + explicit recreate CTA are shown instead.
      expect(
        find.text(l10n.authErrorAccountDeletedRecreate),
        findsOneWidget,
      );
      expect(find.text(l10n.authRecreateAccountCta), findsOneWidget);
    } finally {
      AppleSignInService.resetOverrides();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('recreate CTA routes to the register flow', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AppleSignInService.resetOverrides();
    AppleSignInService.signInOverride = () async {
      throw const ApiException(
        'Apple account was deleted. Recreate it explicitly to continue.',
        statusCode: 409,
        backendCode: 'recreate_required',
      );
    };
    try {
      final l10n = await S.delegate.load(const Locale('fr'));
      await tester.pumpWidget(routedApp());
      await tester.pump();

      await tester.tap(find.byType(SignInWithAppleButton));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      final cta = find.text(l10n.authRecreateAccountCta);
      expect(cta, findsOneWidget);
      await tester.ensureVisible(cta);
      await tester.tap(cta);
      await tester.pumpAndSettle();

      // The recreate CTA lands on the register flow (which sends
      // allowRecreateAfterDelete=true to Apple verify).
      expect(find.text('REGISTER_STUB'), findsOneWidget);
    } finally {
      AppleSignInService.resetOverrides();
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
