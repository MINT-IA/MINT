import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/donation_screen.dart';
import 'package:provider/provider.dart';

/// i18n wiring contract for donation_screen (dette audit 2026-07 + lot B3).
///
/// Positive proof that the user-facing labels formerly hardcoded in FR
/// (types de donation, régimes matrimoniaux, liens de parenté, libellé d'âge,
/// disclaimer de repli) rendent désormais la valeur ARB via [S]. Chaque
/// assertion compare le
/// texte rendu à la valeur du getter localisé — jamais à un littéral FR (qui
/// ré-introduirait la dette). Si un getter cassait au runtime, le build de
/// l'écran lèverait avant même l'assertion.
class _EmptyProvider extends CoachProfileProvider {
  @override
  CoachProfile? get profile => null;
}

Future<S> _pumpAndLocalize(WidgetTester tester) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<CoachProfileProvider>.value(
      value: _EmptyProvider(),
      child: const MaterialApp(
        locale: Locale('fr'),
        localizationsDelegates: [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: DonationScreen(),
      ),
    ),
  );
  await tester.pump();
  return S.of(tester.element(find.byType(DonationScreen)))!;
}

void main() {
  testWidgets('type-de-donation chips render the ARB value, not hardcoded FR',
      (tester) async {
    final l = await _pumpAndLocalize(tester);
    // Les trois libellés de type sont adossés ARB (donationTypeEspeces/...).
    expect(find.text(l.donationTypeEspeces), findsWidgets);
    expect(find.text(l.donationTypeImmobilier), findsWidgets);
    expect(find.text(l.donationTypeTitres), findsWidgets);
  });

  testWidgets('régime-matrimonial chips render the ARB value',
      (tester) async {
    final l = await _pumpAndLocalize(tester);
    expect(find.text(l.donationRegimeParticipation), findsWidgets);
    expect(find.text(l.donationRegimeCommunaute), findsWidgets);
    expect(find.text(l.donationRegimeSeparation), findsWidgets);
  });

  testWidgets('lien-de-parenté chips render the ARB value, not hardcoded FR',
      (tester) async {
    final l = await _pumpAndLocalize(tester);
    // Les 6 catégories du socle (conjoint/descendant/…) sont résolues via
    // _lienParenteLabel → ARB, en miroir des régimes matrimoniaux.
    expect(find.text(l.donationLienConjoint), findsWidgets);
    expect(find.text(l.donationLienDescendant), findsWidgets);
    expect(find.text(l.donationLienParent), findsWidgets);
    expect(find.text(l.donationLienFratrie), findsWidgets);
    expect(find.text(l.donationLienConcubin), findsWidgets);
    expect(find.text(l.donationLienTiers), findsWidgets);
  });

  testWidgets('age picker formats via the shared ageYears ARB key',
      (tester) async {
    final l = await _pumpAndLocalize(tester);
    // Âge par défaut du donateur = 55 (aucun profil) → « 55 ans » via ageYears.
    expect(find.text(l.ageYears('55')), findsOneWidget);
  });

  testWidgets('disclaimer fallback renders the ARB value with no result',
      (tester) async {
    final l = await _pumpAndLocalize(tester);
    // Sans résultat calculé, le pied affiche le repli ARB (au sens de la LSFin).
    expect(find.text(l.donationDisclaimerFallback), findsOneWidget);
  });
}
