import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/screens/settings/confidentialite_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('root privacy settings route has an in-app exit', (tester) async {
    final router = GoRouter(
      initialLocation: '/settings/confidentialite',
      routes: [
        GoRoute(
          path: '/settings/confidentialite',
          builder: (_, __) => const ConfidentialiteSettingsScreen(),
        ),
        GoRoute(
          path: '/profile/bilan',
          builder: (_, __) => const Scaffold(body: Text('Profil')),
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: const Locale('fr'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Confidentialité'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Profil'), findsOneWidget);
  });
}
