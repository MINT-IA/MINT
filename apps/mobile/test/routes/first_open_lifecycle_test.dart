// Bascule 4 — beat `b4_lifecycle`.
//
// LE CONTRAT (storyboard first_open.storyboard.json)
//
//   « Premier lancement, abandon APRÈS disclosure affichée/fermée mais avant
//     CTA (relance sur landing, sans mode local implicite), abandon après CTA
//     (relance sur Aujourd'hui, mode local persisté) — jamais de reprise du
//     wizard. »
//
// CE QUE CE FICHIER PROUVE, ET CE QU'IL NE PROUVE PAS
//
// Il prouve la DÉCISION : étant donné ce qui a survécu sur le disque, le
// chemin de démarrage (`AuthProvider.checkAuth`) choisit la bonne destination.
//
// Il ne prouve PAS la RELANCE. Un axe adverse l'a formulé mieux que moi :
// « `setMockInitialValues()` ne prouve pas une frontière de processus. » Une
// vraie relance — arrêt de l'app, redémarrage, stores conservés — appartient
// au beat `b4_cold_start_receipt`, qui la pilote sur simulateur sans fixture.
// Écrire ici « la relance marche » serait précisément le théâtre que la
// bascule 4 existe pour bannir.
//
// L'ÉTAT QUI DÉCIDE, ET POURQUOI C'EST LA PRÉSENCE ET NON LA VALEUR
//
// `auth_provider.dart:603` lit `prefs.containsKey('auth_local_mode')`. Ce
// n'est pas un détail d'implémentation : une préférence ABSENTE veut dire
// « aucun choix explicite encore », ce qui n'est pas la même chose que
// « choix explicite : non ». Tester la valeur au lieu de la présence
// laisserait un défaut d'origine passer — celui où une valeur par défaut
// `false` se ferait lire comme une décision de la personne.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/auth_lifecycle_state.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secureStorage =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Le coffre est VIDE, pas en panne. Sans ce simulacre, `checkAuth()`
    // lève et rend `sessionExpired` — ce qui masquerait la décision qu'on
    // veut mesurer derrière une panne de plateforme.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, (call) async {
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, null);
  });

  /// Ce qui a survécu au redémarrage, et rien d'autre.
  Future<AuthProvider> demarrerAvec(Map<String, Object> disque) async {
    SharedPreferences.setMockInitialValues(disque);
    final auth = AuthProvider();
    await auth.checkAuth();
    return auth;
  }

  test(
      'a relaunch after the disclosure was shown but before the CTA lands on '
      'the landing without any implicit local mode', () async {
    // La personne a vu la disclosure et fermé l'app. Elle n'a RIEN choisi.
    // Le disque ne porte donc aucune trace de mode local.
    final auth = await demarrerAvec(<String, Object>{
      'mint_install_marker_v1': true,
    });

    expect(auth.authLifecycle.state, AuthLifecycleKind.freshVisitor,
        reason: "aucun choix explicite n'a été fait — la personne est une "
            'visiteuse fraîche, pas une invitée');

    expect(auth.authLifecycle.allowsMainNavigation, isFalse,
        reason: "c'est CE booléen qui tient la porte de la coque. S'il "
            'passait à true sans CTA, la personne se retrouverait dans '
            "Aujourd'hui sans avoir jamais accepté d'y entrer");

    // DEUX CHOSES QUE J'AI CONFONDUES, ET QU'IL NE FAUT PAS CONFONDRE.
    //
    // Ma première version exigeait ici `isLocalMode == false`. Elle a échoué,
    // et le code avait raison : sans clé, `isLocalMode` vaut TRUE — et c'est
    // délibéré. `coach_profile_provider.dart:569` lit
    // `getBool('auth_local_mode') ?? true` pour SAUTER la poussée vers le
    // serveur. Sans choix explicite, MINT ne synchronise pas.
    //
    // `isLocalMode` est donc un défaut de TRAITEMENT DES DONNÉES, fail-safe
    // par construction. Le « mode local implicite » que le contrat interdit
    // est un octroi d'ACCÈS — et celui-là est bien refusé, deux assertions
    // plus haut. Confondre les deux ferait « corriger » une protection.
    expect(auth.isLocalMode, isTrue,
        reason: 'sans choix explicite, aucune donnée ne part vers le serveur '
            '— le défaut protège, il n\'ouvre rien');
  });

  test(
      'a relaunch after the CTA lands on the shell in persisted local mode '
      'and never resumes the wizard', () async {
    // La personne a touché le CTA : le choix est écrit sur le disque.
    final auth = await demarrerAvec(<String, Object>{
      'mint_install_marker_v1': true,
      'auth_local_mode': true,
    });

    expect(auth.authLifecycle.state, AuthLifecycleKind.guestEmpty,
        reason: 'le choix explicite fait d\'elle une invitée locale');

    expect(auth.authLifecycle.allowsMainNavigation, isTrue,
        reason: 'la coque lui est ouverte, parce qu\'elle l\'a demandée');

    expect(auth.isLocalMode, isTrue,
        reason: 'le mode local a SURVÉCU au redémarrage — sinon elle devrait '
            'redemander à chaque lancement ce qu\'elle a déjà accepté');
  });

  test(
      'an absent preference is not a decision — presence is what the startup '
      'path reads', () async {
    // CE QUE CE TEST TIENT, ET CE QU'IL NE TIENT PAS — vérifié par mutation.
    //
    // Sa première version annonçait qu'il attraperait un refactor de
    // `prefs.containsKey(...)` en `prefs.getBool(...) ?? false`. J'ai fait la
    // mutation : les trois tests restent VERTS. La prétention était fausse.
    //
    // Pourquoi : les deux formes sont aujourd'hui indiscernables dans leur
    // effet, parce que `_isLocalMode` porte déjà la valeur de la clé. Quand
    // elle vaut `false`, `_isLocalMode` vaut `false`, et le `&&` retombe sur
    // le même résultat par les deux chemins. La distinction présence/valeur
    // est DÉFENSIVE — elle n'est pas encore observable.
    //
    // Ce test pin donc les RÉSULTATS des trois états de disque, pas le
    // mécanisme qui les produit. C'est moins que ce que je voulais écrire, et
    // c'est ce qui est vrai.
    final sansCle = await demarrerAvec(<String, Object>{
      'mint_install_marker_v1': true,
    });
    final avecFalse = await demarrerAvec(<String, Object>{
      'mint_install_marker_v1': true,
      'auth_local_mode': false,
    });

    expect(sansCle.authLifecycle.allowsMainNavigation, isFalse);
    expect(avecFalse.authLifecycle.allowsMainNavigation, isFalse,
        reason: 'les deux mènent à la landing, mais pour des raisons '
            'différentes — et aucune ne doit ouvrir la coque');

    // Et la nuance qui compte pour la vie privée : « pas de clé » garde le
    // traitement local, tandis qu'un `false` explicite dit l'inverse. Les
    // deux ferment la porte de la coque ; ils ne disent PAS la même chose
    // sur les données.
    expect(sansCle.isLocalMode, isTrue,
        reason: 'aucun choix ⇒ rien ne part, par défaut');
    expect(avecFalse.isLocalMode, isFalse,
        reason: 'un false explicite est une décision, et elle est respectée');
  });
}
