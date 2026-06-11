import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/mariage_screen.dart';

// ─────────────────────────────────────────────────────────────────────
//  MARIAGE WHAT-IF — D9 (l'outil what-if déclare ses hypothèses)
//
//  D9: l'écran Mariage fabrique un « Revenu 2 » par défaut (60'000) pour
//      un profil sans conjoint connu. Un outil what-if a le DROIT d'avoir
//      des hypothèses — mais il doit les ÉTIQUETER comme telles et les
//      rendre éditables, jamais les présenter comme un fait du profil.
//
//  Ghost conjoint (Codex W2 review) : `fromWizardAnswers` recréait un
//      `ConjointProfile` depuis TOUTE clé `q_partner_*` résiduelle quel que
//      soit l'état du ménage. Un user qui repasse en `single` (ou divorce
//      en quittant le couple) gardait un conjoint fantôme. La reconstruction
//      est désormais gated sur la cohérence `q_household_type`.
// ─────────────────────────────────────────────────────────────────────

const _localizations = [
  S.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Salaried single profile — NO conjoint declared. The « Revenu 2 » must
/// therefore be a labelled, editable hypothesis (not a profile fact).
Map<String, dynamic> _singleAnswers() => {
      'q_birth_year': 1985,
      'q_canton': 'VD',
      'q_net_income_period_chf': 6500.0,
      'q_pay_frequency': 'monthly',
      'q_gross_salary_annual': 96000.0,
      'q_employment_status': 'salarie',
      'q_household_type': 'single',
      'q_civil_status': 'celibataire',
    };

/// Couple profile WITH a real declared partner income. « Revenu 2 » must be
/// prefilled from the real conjoint and shown WITHOUT a hypothesis label.
Map<String, dynamic> _coupleAnswers() => {
      'q_birth_year': 1985,
      'q_canton': 'VD',
      'q_net_income_period_chf': 6500.0,
      'q_pay_frequency': 'monthly',
      'q_gross_salary_annual': 96000.0,
      'q_employment_status': 'salarie',
      'q_household_type': 'couple',
      'q_civil_status': 'marie',
      'q_partner_net_income_chf': 5000.0,
      'q_partner_birth_year': 1987,
      'q_partner_employment_status': 'salarie',
    };

Widget _buildHarness(CoachProfileProvider coachProvider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>.value(value: coachProvider),
      ChangeNotifierProvider<ByokProvider>(create: (_) => ByokProvider()),
      ChangeNotifierProvider<SlmProvider>(create: (_) => SlmProvider()),
    ],
    child: const MaterialApp(
      locale: Locale('fr'),
      localizationsDelegates: _localizations,
      supportedLocales: S.supportedLocales,
      home: MariageScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('D9 — what-if mariage déclare ses hypothèses', () {
    testWidgets(
        'profil SANS conjoint → « Revenu 2 » porte une étiquette hypothèse éditable',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final provider = CoachProfileProvider()..updateFromAnswers(_singleAnswers());
      expect(provider.profile, isNotNull);
      expect(provider.profile!.conjoint, isNull,
          reason: 'profil single : aucun conjoint réel');

      await tester.pumpWidget(_buildHarness(provider));
      await tester.pump(const Duration(seconds: 1));
      tester.takeException(); // drain any layout overflow in the test viewport

      // L'étiquette « hypothèse » doit être visible pour le profil sans conjoint.
      expect(find.byKey(const Key('mariage_revenu2_hypothesis_note')),
          findsOneWidget,
          reason:
              'D9 : sans conjoint réel, le Revenu 2 (60\'000) est une hypothèse de l\'outil — il doit être étiqueté comme tel');

      // Le champ Revenu 2 reste éditable (MintAmountField tapable).
      expect(find.byKey(const Key('mariage_revenu2_field')), findsOneWidget,
          reason: 'D9 : l\'hypothèse Revenu 2 doit rester éditable');
    });

    testWidgets(
        'profil AVEC conjoint réel → Revenu 2 réel, SANS étiquette hypothèse',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final provider = CoachProfileProvider()..updateFromAnswers(_coupleAnswers());
      expect(provider.profile, isNotNull);
      expect(provider.profile!.conjoint, isNotNull,
          reason: 'profil couple avec revenu partenaire déclaré → conjoint réel');

      await tester.pumpWidget(_buildHarness(provider));
      await tester.pump(const Duration(seconds: 1));
      tester.takeException();

      // Conjoint réel : pas d'étiquette hypothèse sur le Revenu 2.
      expect(find.byKey(const Key('mariage_revenu2_hypothesis_note')),
          findsNothing,
          reason:
              'D9 : avec un conjoint réel, le Revenu 2 est un fait — pas une hypothèse');
    });
  });

  group('Ghost conjoint — reconstruction gated sur le ménage', () {
    test(
        'q_household_type=single + clés q_partner_* résiduelles → AUCUN conjoint',
        () {
      final answers = {
        'q_birth_year': 1985,
        'q_household_type': 'single',
        'q_civil_status': 'divorce',
        // Résidus d'un ancien couple non purgés côté stockage.
        'q_partner_net_income_chf': 5000.0,
        'q_partner_birth_year': 1987,
        'q_partner_employment_status': 'salarie',
      };
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.conjoint, isNull,
          reason:
              'ghost conjoint : un ménage déclaré single ne doit JAMAIS reconstruire un conjoint depuis des clés résiduelles');
    });

    test('q_household_type=couple + clés q_partner_* → conjoint reconstruit',
        () {
      final answers = {
        'q_birth_year': 1985,
        'q_household_type': 'couple',
        'q_civil_status': 'marie',
        'q_partner_net_income_chf': 5000.0,
        'q_partner_birth_year': 1987,
        'q_partner_employment_status': 'salarie',
      };
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.conjoint, isNotNull,
          reason:
              'un ménage couple cohérent avec données partenaire doit reconstruire le conjoint');
    });

    test(
        'divorcé qui vit en couple (household=couple) → conjoint conservé (pas keyé sur etatCivil seul)',
        () {
      // Un divorcé PEUT vivre en couple : la reconstruction doit dépendre de
      // la cohérence du ménage, pas de l'état civil seul.
      final answers = {
        'q_birth_year': 1985,
        'q_household_type': 'couple',
        'q_civil_status': 'divorce',
        'q_partner_net_income_chf': 4200.0,
        'q_partner_birth_year': 1986,
        'q_partner_employment_status': 'salarie',
      };
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.conjoint, isNotNull,
          reason:
              'un divorcé en concubinage déclaré (household=couple) garde son conjoint réel');
    });
  });

  // ───────────────────────────────────────────────────────────────────
  //  Ghost conjoint — directions P1/P2 (Codex W5 review)
  //
  //  L'onboarding V2 (MintSceneEtatCivil → onboarding_provider.dart) n'écrit
  //  QUE `q_civil_status`, jamais `q_household_type`. Keyer le gate sur le seul
  //  `q_household_type` cassait dans deux directions :
  //    [P1] `q_household_type=single` PÉRIMÉ + `q_civil_status=marié` FRAIS +
  //         vrai conjoint → le vrai conjoint était silencieusement supprimé.
  //    [P2] `q_household_type` ABSENT + `q_civil_status` non-couple + clés
  //         `q_partner_*` résiduelles → conjoint fantôme toujours ressuscité.
  //  Le fix lit les DEUX signaux, l'état civil frais primant.
  // ───────────────────────────────────────────────────────────────────
  group('Ghost conjoint — état civil frais prime sur household périmé (W5)', () {
    test(
        '[P1] q_household_type=single PÉRIMÉ + q_civil_status=marie FRAIS + vrai conjoint → conjoint conservé',
        () {
      // Profil V2 : onboarding réécrit q_civil_status=marie après un ancien
      // q_household_type=single persisté. Le vrai conjoint NE doit PAS être
      // supprimé — l'état civil frais (marié) prime sur le household périmé.
      final answers = {
        'q_birth_year': 1985,
        'q_household_type': 'single', // périmé, non purgé côté stockage
        'q_civil_status': 'marie', // frais (V2 MintSceneEtatCivil)
        'q_partner_net_income_chf': 5000.0,
        'q_partner_birth_year': 1987,
        'q_partner_employment_status': 'salarie',
      };
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.conjoint, isNotNull,
          reason:
              'P1 : un état civil marié frais doit reconstruire le vrai conjoint malgré un q_household_type=single périmé');
    });

    test(
        '[P2] q_household_type ABSENT + q_civil_status non-couple + clés q_partner_* résiduelles → AUCUN conjoint',
        () {
      // Profil V2 : aucun q_household_type écrit. État civil non-couple +
      // résidus q_partner_* d'un ancien couple → conjoint fantôme historique
      // (bug W2 jamais corrigé pour les profils de forme V2).
      final answers = {
        'q_birth_year': 1985,
        // q_household_type ABSENT (onboarding V2 ne l'écrit pas)
        'q_civil_status': 'divorce',
        'q_partner_net_income_chf': 5000.0,
        'q_partner_birth_year': 1987,
        'q_partner_employment_status': 'salarie',
      };
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.conjoint, isNull,
          reason:
              'P2 : un état civil non-couple sans q_household_type ne doit JAMAIS ressusciter un conjoint depuis des clés résiduelles');
    });

    test(
        '[P2-célibataire] q_household_type ABSENT + q_civil_status=celibataire + résidus → AUCUN conjoint',
        () {
      final answers = {
        'q_birth_year': 1985,
        // q_household_type ABSENT
        'q_civil_status': 'celibataire',
        'q_partner_net_income_chf': 4800.0,
        'q_partner_birth_year': 1988,
        'q_partner_employment_status': 'salarie',
      };
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.conjoint, isNull,
          reason:
              'P2 : un célibataire (V2, sans household) ne doit pas ressusciter un conjoint fantôme');
    });

    test(
        '[divorcé+couple, V2] q_household_type=couple explicite + q_civil_status=divorce → conjoint conservé',
        () {
      // Propriété plan 17 préservée : un divorcé qui déclare household=couple
      // garde son conjoint réel, même avec le nouveau gate.
      final answers = {
        'q_birth_year': 1985,
        'q_household_type': 'couple', // déclaration explicite vie de couple
        'q_civil_status': 'divorce',
        'q_partner_net_income_chf': 4200.0,
        'q_partner_birth_year': 1986,
        'q_partner_employment_status': 'salarie',
      };
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.conjoint, isNotNull,
          reason:
              'un divorcé qui déclare explicitement household=couple garde son conjoint réel (propriété plan 17)');
    });

    test(
        '[état civil absent — legacy] aucun q_civil_status + q_household_type=single + résidus → AUCUN conjoint',
        () {
      // Profils legacy (avant V2) : pas de q_civil_status. Comportement
      // historique préservé — on exclut le seul household=single explicite.
      final answers = {
        'q_birth_year': 1985,
        'q_household_type': 'single',
        // q_civil_status ABSENT (profil legacy)
        'q_partner_net_income_chf': 5000.0,
        'q_partner_birth_year': 1987,
        'q_partner_employment_status': 'salarie',
      };
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.conjoint, isNull,
          reason:
              'legacy : sans état civil, on exclut le household=single explicite (comportement historique)');
    });

    test(
        '[état civil absent — legacy] aucun q_civil_status + aucun q_household_type + résidus → conjoint conservé (legacy allow)',
        () {
      // Profils legacy sans aucun signal de ménage : comportement historique
      // = legacy allow (pas de régression sur les anciens profils couple).
      final answers = {
        'q_birth_year': 1985,
        // ni q_civil_status ni q_household_type
        'q_partner_net_income_chf': 5000.0,
        'q_partner_birth_year': 1987,
        'q_partner_employment_status': 'salarie',
      };
      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.conjoint, isNotNull,
          reason:
              'legacy allow : sans aucun signal de ménage, les anciens profils couple ne régressent pas');
    });
  });
}
