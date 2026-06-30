import 'dart:ui' show SemanticsAction;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/auth/register_screen.dart';
import 'package:mint_mobile/services/account_handoff_service.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/apple_sign_in_service.dart';
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

Future<void> _acceptRequiredConsentsAndTapApple(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(Checkbox).at(0));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(Checkbox).at(0));
  await tester.pump();
  await tester.ensureVisible(find.byType(Checkbox).at(1));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(Checkbox).at(1));
  await tester.pump();
  await tester.ensureVisible(find.byType(SignInWithAppleButton));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(SignInWithAppleButton));
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FeatureFlags.enableMvpWedgeOnboarding = false;
  });

  tearDown(() {
    FeatureFlags.enableMvpWedgeOnboarding = false;
    AppleSignInService.resetOverrides();
  });

  testWidgets('iOS registration exposes Apple and email immediately',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      final emailField = find.widgetWithText(TextFormField, 'Adresse e-mail');
      expect(find.byType(SignInWithAppleButton), findsOneWidget);
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(emailField, findsOneWidget);
      expect(tester.getTopLeft(emailField).dy, lessThan(560));
      expect(
        tester.getTopLeft(emailField).dy,
        lessThan(tester.getTopLeft(find.byType(Checkbox).first).dy),
      );
      expect(find.text('Créer avec e-mail'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('registration create CTA exposes runtime semantics id',
      (tester) async {
    final semantics = tester.ensureSemantics();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      final createAccountSemantics = find.byKey(
        const ValueKey('auth_register_create_account_semantics'),
      );

      await tester.ensureVisible(createAccountSemantics);
      await tester.pumpAndSettle();

      final node = tester.getSemantics(createAccountSemantics);
      expect(node.identifier, 'auth_register_create_account');
      expect(node.label, 'Créer mon compte');
      expect(node.flagsCollection.isButton, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      semantics.dispose();
    }
  });

  testWidgets('registration create CTA is inert without required consents',
      (tester) async {
    final semantics = tester.ensureSemantics();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      final createAccountSemantics = find.byKey(
        const ValueKey('auth_register_create_account_semantics'),
      );
      final createAccount = find.byKey(
        const ValueKey('auth_register_create_account'),
      );

      await tester.ensureVisible(createAccountSemantics);
      await tester.pumpAndSettle();

      final data =
          tester.getSemantics(createAccountSemantics).getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isFalse);

      await tester.tap(createAccount);
      await tester.pump();

      expect(find.text('Adresse e-mail invalide'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      semantics.dispose();
    }
  });

  testWidgets('registration form exposes runtime field anchors',
      (tester) async {
    final semantics = tester.ensureSemantics();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      const anchors = <String, String>{
        'auth_register_email_field': 'Adresse e-mail',
        'auth_register_first_name_field': 'Prénom',
        'auth_register_password_field': 'Mot de passe',
        'auth_register_confirm_password_field': 'Confirmer le mot de passe',
      };

      for (final entry in anchors.entries) {
        final finder = find.byKey(ValueKey('${entry.key}_semantics'));
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();

        final node = tester.getSemantics(finder);
        expect(node.identifier, entry.key);
        expect(node.label, entry.value);
        expect(node.flagsCollection.isTextField, isTrue);
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
      semantics.dispose();
    }
  });

  testWidgets('required consents expose runtime tap actions', (tester) async {
    final semantics = tester.ensureSemantics();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      const anchors = <String>[
        'auth_register_accept_cgu',
        'auth_register_confirm_18',
      ];

      for (final identifier in anchors) {
        final finder = find.byKey(ValueKey('${identifier}_semantics'));
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();

        final node = tester.getSemantics(finder);
        final data = node.getSemanticsData();
        expect(node.identifier, identifier);
        expect(node.flagsCollection.isButton, isTrue);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
      semantics.dispose();
    }
  });

  testWidgets('Apple registration requires legal consents before native auth',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      await tester.ensureVisible(find.byType(SignInWithAppleButton));
      await tester.pumpAndSettle();
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

  testWidgets('legal consent labels toggle their checkboxes', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      final cguCheckbox = find.byKey(
        const ValueKey('auth_register_accept_cgu'),
      );
      final cguLabel = find.byKey(
        const ValueKey('auth_register_accept_cgu_label'),
      );
      final ageCheckbox = find.byKey(
        const ValueKey('auth_register_confirm_18'),
      );
      final ageLabel = find.byKey(
        const ValueKey('auth_register_confirm_18_label'),
      );

      await tester.ensureVisible(cguLabel);
      await tester.pumpAndSettle();
      await tester.tap(cguLabel);
      await tester.pump();

      await tester.ensureVisible(ageLabel);
      await tester.pumpAndSettle();
      await tester.tap(ageLabel);
      await tester.pump();

      expect(tester.widget<Checkbox>(cguCheckbox).value, isTrue);
      expect(tester.widget<Checkbox>(ageCheckbox).value, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('date of birth field opens the picker', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      final dobField = find.byKey(
        const ValueKey('auth_register_dob_field'),
      );

      await tester.ensureVisible(dobField);
      await tester.pumpAndSettle();
      await tester.tap(dobField);
      await tester.pumpAndSettle();

      expect(find.text('Valider'), findsOneWidget);
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

  testWidgets('Apple recreate-required opens email fallback with guidance',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AppleSignInService.signInOverride = () async {
      throw const ApiException('recreate_required', statusCode: 409);
    };
    try {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      await _acceptRequiredConsentsAndTapApple(tester);

      expect(
        find.text(
          'Inscription indisponible pour le moment. Utilise le mode local puis réessaie plus tard.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(
        find.text(
          'Action impossible pour le moment. Réessaie dans quelques instants.',
        ),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Apple provider failure also opens email fallback',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AppleSignInService.signInOverride = () async => {
          'accessToken': 'token-without-user',
          'email': 'relay@example.invalid',
        };
    try {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      await _acceptRequiredConsentsAndTapApple(tester);

      expect(
        find.text(
          'Le service de compte n’est pas disponible sur cet environnement. Utilise le mode local.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('native Apple auth failure keeps email path visible',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AppleSignInService.signInOverride = () async {
      throw const SignInWithAppleAuthorizationException(
        code: AuthorizationErrorCode.unknown,
        message: 'Authorization failed',
      );
    };
    try {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      await _acceptRequiredConsentsAndTapApple(tester);

      expect(
        find.text(
          'Le service de compte n’est pas disponible sur cet environnement. Utilise le mode local.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(
        find.text(
          'Action impossible pour le moment. Réessaie dans quelques instants.',
        ),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('native Apple platform failure does not show generic auth copy',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AppleSignInService.signInOverride = () async {
      throw PlatformException(
        code: 'authorization_error',
        message:
            'The operation couldn’t be completed. (com.apple.AuthenticationServices.AuthorizationError error 1000.)',
      );
    };
    try {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      await _acceptRequiredConsentsAndTapApple(tester);

      expect(
        find.text(
          'Le service de compte n’est pas disponible sur cet environnement. Utilise le mode local.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(
        find.text(
          'Action impossible pour le moment. Réessaie dans quelques instants.',
        ),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('backend Apple verification failure does not show generic copy',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AppleSignInService.signInOverride = () async {
      throw const ApiException(
        'Apple identity verification unavailable',
        statusCode: 503,
      );
    };
    try {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      await _acceptRequiredConsentsAndTapApple(tester);

      expect(
        find.text(
          'Le service de compte n’est pas disponible sur cet environnement. Utilise le mode local.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(
        find.text(
          'Action impossible pour le moment. Réessaie dans quelques instants.',
        ),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Apple cancellation does not show service unavailable guidance',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AppleSignInService.signInOverride = () async {
      throw const SignInWithAppleAuthorizationException(
        code: AuthorizationErrorCode.canceled,
        message: 'User canceled Apple Sign-In',
      );
    };
    try {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      await _acceptRequiredConsentsAndTapApple(tester);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Le service de compte n’est pas disponible sur cet environnement. Utilise le mode local.',
        ),
        findsNothing,
      );
      expect(
        find.text(
          'Action impossible pour le moment. Réessaie dans quelques instants.',
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('native Apple platform cancellation stays silent',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AppleSignInService.signInOverride = () async {
      throw PlatformException(
        code: 'authorization_error',
        message:
            'The operation couldn’t be completed. (com.apple.AuthenticationServices.AuthorizationError error 1001.)',
      );
    };
    try {
      await tester.pumpWidget(_testApp());
      await tester.pump();

      await _acceptRequiredConsentsAndTapApple(tester);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Le service de compte n’est pas disponible sur cet environnement. Utilise le mode local.',
        ),
        findsNothing,
      );
      expect(
        find.text(
          'Action impossible pour le moment. Réessaie dans quelques instants.',
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
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
