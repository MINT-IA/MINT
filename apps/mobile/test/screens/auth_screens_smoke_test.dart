import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

// Screens under test
import 'package:mint_mobile/screens/auth/login_screen.dart';
import 'package:mint_mobile/screens/auth/register_screen.dart';
import 'package:mint_mobile/screens/auth/forgot_password_screen.dart';
import 'package:mint_mobile/screens/auth/verify_email_screen.dart';
import 'package:mint_mobile/screens/byok_settings_screen.dart';

// Dependencies
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';

void main() {
  /// Helper to wrap screens that require localizations + AuthProvider
  Widget buildAuthTestable(Widget child) {
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
        child: child,
      ),
    );
  }

  /// Helper to wrap ByokSettingsScreen with required ByokProvider
  Widget buildByokTestable(Widget child) {
    return MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: ChangeNotifierProvider<ByokProvider>(
        create: (_) => ByokProvider(),
        child: child,
      ),
    );
  }

  // ===========================================================================
  // 1. LOGIN SCREEN
  // ===========================================================================

  group('LoginScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const LoginScreen()));
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows login title', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const LoginScreen()));
      await tester.pump();

      expect(find.text('Connexion'), findsOneWidget);
    });

    testWidgets('shows subtitle about Financial OS', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const LoginScreen()));
      await tester.pump();

      expect(
        find.textContaining('Financial OS'),
        findsOneWidget,
      );
    });

    testWidgets('shows email input field', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const LoginScreen()));
      await tester.pump();

      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('shows password input field', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const LoginScreen()));
      await tester.pump();

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('shows password visibility toggle', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const LoginScreen()));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('shows Se connecter button', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const LoginScreen()));
      await tester.pump();

      expect(find.text('Se connecter'), findsWidgets);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('shows register link for new users', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const LoginScreen()));
      await tester.pump();

      expect(find.textContaining('Pas encore de compte'), findsOneWidget);
    });

    testWidgets('shows forgot password link', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const LoginScreen()));
      await tester.pump();

      expect(find.text('Mot de passe oublié ?'), findsOneWidget);
    });

    testWidgets('shows verify email link', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const LoginScreen()));
      await tester.pump();

      expect(find.text('Vérifier mon e-mail'), findsOneWidget);
    });

    testWidgets('shows Retour button', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const LoginScreen()));
      await tester.pump();

      expect(find.text('Retour'), findsOneWidget);
    });

    testWidgets('shows MINT logo icon', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const LoginScreen()));
      await tester.pump();

      expect(find.byIcon(Icons.token_rounded), findsOneWidget);
    });

    testWidgets('has Form widget for validation', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const LoginScreen()));
      await tester.pump();

      expect(find.byType(Form), findsOneWidget);
    });
  });

  // ===========================================================================
  // 2. FORGOT PASSWORD SCREEN
  // ===========================================================================

  group('ForgotPasswordScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const ForgotPasswordScreen()));
      await tester.pump();

      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      expect(find.textContaining('Réinitialiser'), findsOneWidget);
    });

    testWidgets('shows email, token and password fields', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const ForgotPasswordScreen()));
      await tester.pump();

      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(find.byIcon(Icons.key_outlined), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
      expect(find.textContaining('Envoyer le lien'), findsOneWidget);
    });
  });

  group('VerifyEmailScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const VerifyEmailScreen()));
      await tester.pump();

      expect(find.byType(VerifyEmailScreen), findsOneWidget);
      expect(find.textContaining('Vérifier mon e-mail'), findsOneWidget);
    });

    testWidgets('shows email and token fields', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const VerifyEmailScreen()));
      await tester.pump();

      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(find.byIcon(Icons.key_outlined), findsOneWidget);
      expect(find.textContaining('Envoyer le lien'), findsOneWidget);
    });
  });

  // ===========================================================================
  // 3. REGISTER SCREEN
  // ===========================================================================

  group('RegisterScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const RegisterScreen()));
      await tester.pump();

      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows register title', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const RegisterScreen()));
      await tester.pump();

      expect(find.textContaining('er ton compte'), findsWidgets);
    });

    testWidgets('shows subtitle about optional account and local mode',
        (tester) async {
      await tester.pumpWidget(buildAuthTestable(const RegisterScreen()));
      await tester.pump();

      expect(
        find.textContaining('Compte optionnel'),
        findsOneWidget,
      );
    });

    testWidgets('shows email input field', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const RegisterScreen()));
      await tester.pump();

      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    });

    testWidgets('shows display name field', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const RegisterScreen()));
      await tester.pump();

      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });

    testWidgets('shows password and confirm password fields', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const RegisterScreen()));
      await tester.pump();

      // Two lock_outline icons (password + confirm)
      expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
    });

    testWidgets('shows password requirement info box', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const RegisterScreen()));
      await tester.pump();

      expect(
        find.textContaining('8 caract'),
        findsWidgets,
      );
    });

    testWidgets('shows create account button', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const RegisterScreen()));
      await tester.pump();

      // Scroll down to see button
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
      await tester.pump();

      expect(find.textContaining('er mon compte'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('shows continue in local mode button', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const RegisterScreen()));
      await tester.pump();

      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -260));
      await tester.pump();

      expect(find.text('Continuer en mode local'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsWidgets);
    });

    testWidgets('shows login link for existing users', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const RegisterScreen()));
      await tester.pump();

      // Scroll down
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pump();

      expect(find.textContaining('inscrit'), findsOneWidget);
    });

    testWidgets('shows MINT logo icon', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const RegisterScreen()));
      await tester.pump();

      expect(find.byIcon(Icons.token_rounded), findsOneWidget);
    });

    testWidgets('has Form widget for validation', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const RegisterScreen()));
      await tester.pump();

      expect(find.byType(Form), findsOneWidget);
    });

    testWidgets('shows Retour button', (tester) async {
      await tester.pumpWidget(buildAuthTestable(const RegisterScreen()));
      await tester.pump();

      // Scroll down
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.pump();

      expect(find.text('Retour'), findsOneWidget);
    });
  });

  // ===========================================================================
  // 4. BYOK SETTINGS SCREEN
  // ===========================================================================

  group('ByokSettingsScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildByokTestable(const ByokSettingsScreen()));
      await tester.pump();

      expect(find.byType(ByokSettingsScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows Intelligence artificielle title', (tester) async {
      await tester.pumpWidget(buildByokTestable(const ByokSettingsScreen()));
      await tester.pump();

      expect(find.text('Intelligence artificielle'), findsWidgets);
    });

    testWidgets('shows privacy card with key info', (tester) async {
      await tester.pumpWidget(buildByokTestable(const ByokSettingsScreen()));
      await tester.pump();

      expect(find.textContaining('donn\u00e9es'), findsWidgets);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('shows provider selector with 3 options', (tester) async {
      await tester.pumpWidget(buildByokTestable(const ByokSettingsScreen()));
      await tester.pump();

      expect(find.text('Claude'), findsOneWidget);
      expect(find.text('OpenAI'), findsOneWidget);
      expect(find.text('Mistral'), findsOneWidget);
    });

    testWidgets('shows Recommand\u00e9 badge on Claude', (tester) async {
      await tester.pumpWidget(buildByokTestable(const ByokSettingsScreen()));
      await tester.pump();

      expect(find.text('Recommand\u00e9'), findsOneWidget);
    });

    testWidgets('shows API key input field', (tester) async {
      await tester.pumpWidget(buildByokTestable(const ByokSettingsScreen()));
      await tester.pump();

      // Scroll to API key input
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows test and save buttons', (tester) async {
      await tester.pumpWidget(buildByokTestable(const ByokSettingsScreen()));
      await tester.pump();

      // Scroll down
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();

      expect(find.textContaining('Tester'), findsOneWidget);
      expect(find.text('Sauvegarder'), findsOneWidget);
    });

    testWidgets('shows educational BYOK section', (tester) async {
      await tester.pumpWidget(buildByokTestable(const ByokSettingsScreen()));
      await tester.pump();

      // Scroll down to educational section
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();

      expect(find.textContaining('BYOK'), findsWidgets);
    });

    testWidgets('shows help link to get API key', (tester) async {
      await tester.pumpWidget(buildByokTestable(const ByokSettingsScreen()));
      await tester.pump();

      // Scroll down
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();

      expect(find.textContaining('Obtenir une cl'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    });

    testWidgets('can switch provider to OpenAI', (tester) async {
      await tester.pumpWidget(buildByokTestable(const ByokSettingsScreen()));
      await tester.pump();

      // Tap on OpenAI chip
      await tester.tap(find.text('OpenAI'));
      await tester.pump();

      // Should still render correctly
      expect(find.byType(ByokSettingsScreen), findsOneWidget);
    });

    testWidgets('shows visibility toggle for API key', (tester) async {
      await tester.pumpWidget(buildByokTestable(const ByokSettingsScreen()));
      await tester.pump();

      // Scroll down
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('shows subtitle about LLM connection', (tester) async {
      await tester.pumpWidget(buildByokTestable(const ByokSettingsScreen()));
      await tester.pump();

      expect(
        find.textContaining('personnalis'),
        findsWidgets,
      );
    });
  });
}
