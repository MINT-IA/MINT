// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'mint_next_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class MintNextLocalizationsFr extends MintNextLocalizations {
  MintNextLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get brand => 'MINT';

  @override
  String get quit => 'Quitter';

  @override
  String get todayEyebrow => 'AUJOURD’HUI · 3A';

  @override
  String get todayTitle => 'Que change un versement 3a cette année ?';

  @override
  String get todayBody =>
      'On va comprendre ses effets, une étape à la fois. MINT t’informe, mais ne décide pas à ta place.';

  @override
  String get start => 'Comprendre';

  @override
  String get orientationEyebrow => 'AVANT LES CHIFFRES';

  @override
  String get orientationTitle =>
      'Épargner pour ta retraite peut aussi réduire tes impôts.';

  @override
  String get orientationBody =>
      'Un versement 3a peut diminuer ton revenu imposable — le montant sur lequel tes impôts sont calculés. Ton argent disponible baisse maintenant et le capital 3a reste lié jusqu’à la retraite, sauf dans les cas prévus par la loi.';

  @override
  String get orientationNote =>
      'On vérifiera d’abord l’année et ta situation. Aucun montant ne sera recommandé.';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get backLabel => 'Retour';

  @override
  String get taxYearEyebrow => 'ÉTAPE 1 · ANNÉE FISCALE';

  @override
  String get taxYearTitle => 'De quelle année parle-t-on ?';

  @override
  String get taxYearBody =>
      'Le plafond dépend de l’année et de ta situation, notamment de ton revenu professionnel et de ton affiliation à une caisse de pension. L’année en cours est proposée, jamais choisie à ta place.';

  @override
  String currentYearLabel(int year) {
    return 'Année en cours : $year';
  }

  @override
  String confirmYear(int year) {
    return 'Choisir $year';
  }

  @override
  String yearChosen(int year) {
    return 'Année $year sélectionnée';
  }

  @override
  String get partialBoundary =>
      'Le prochain écran sera ajouté dans le lot suivant. Rien n’est enregistré.';

  @override
  String get safeExitTitle => 'Tu veux t’arrêter ici ?';

  @override
  String get safeExitBody =>
      'Aucune donnée financière personnelle n’est enregistrée dans ce Design Lab.';

  @override
  String get resume => 'Continuer ici';

  @override
  String get leave => 'Quitter sans enregistrer';

  @override
  String get dismissedTitle => 'Parcours fermé';

  @override
  String get startShort => 'Commencer';

  @override
  String get keepReferenceUnavailable => 'Repère local — bientôt disponible';

  @override
  String get lppQuestionEyebrow => 'TA SITUATION';

  @override
  String get lppQuestionTitle => 'As-tu actuellement une caisse de pension ?';

  @override
  String get lppQuestionBody =>
      'C’est aussi appelé LPP ou 2e pilier. Tu peux être affilié·e par ton emploi ou volontairement. Ici, on te demande si tu es couvert·e actuellement, pas combien tu verses.';

  @override
  String get lppQuestionEvidence =>
      'Pour vérifier, cherche une ligne LPP ou caisse de pension sur une fiche de salaire, consulte un certificat récent, ou demande à ta caisse, ton employeur ou aux RH.';

  @override
  String get lppChoiceYes => 'Oui';

  @override
  String get lppChoiceNo => 'Non';

  @override
  String get lppChoiceUnknown => 'Je ne sais pas';

  @override
  String get lppUnknownEyebrow => 'AUCUN SOUCI';

  @override
  String get lppUnknownTitle => 'Tu peux le vérifier sans deviner.';

  @override
  String get lppUnknownBody =>
      'Commence par ce qui est le plus facile pour toi. Quand tu as la réponse, reprends ce parcours et réponds à nouveau à la question.';

  @override
  String get lppUnknownListLabel => 'Trois façons de vérifier ton affiliation';

  @override
  String get lppUnknownPayslip =>
      'Cherche une ligne LPP, 2e pilier, CP ou caisse de pension sur une fiche de salaire récente.';

  @override
  String get lppUnknownCertificate =>
      'Cherche un certificat de prévoyance récent envoyé par ta caisse de pension.';

  @override
  String get lppUnknownAsk =>
      'Demande à ta caisse de pension, ton employeur ou aux RH si tu es actuellement affilié·e.';

  @override
  String get lppBackToQuestion => 'Revenir à la question';

  @override
  String get lppKeepChecklist => 'Garder cette liste sur cet appareil';

  @override
  String get localReferenceUnavailable => 'Bientôt disponible';

  @override
  String get withoutLppEyebrow => 'UNE AUTRE RÈGLE S’APPLIQUE';

  @override
  String get withoutLppTitle =>
      'Tu peux peut-être verser dans un 3a, mais avec d’autres règles.';

  @override
  String get withoutLppBody =>
      'Ta réponse ne signifie pas que tu n’as pas droit au 3a. Ce premier calcul ne couvre simplement pas encore ce cas.';

  @override
  String get lppCorrectAnswer => 'Corriger ma réponse';

  @override
  String get withoutLppKeepExplanation =>
      'Garder cette explication sur cet appareil';

  @override
  String get nextStepEyebrow => 'ÉTAPE SUIVANTE';

  @override
  String get nextStepTitle => 'Ton affiliation est claire.';

  @override
  String get nextStepBody =>
      'La prochaine question portera sur ce que tu as déjà versé cette année. Elle sera ajoutée dans le prochain petit lot. Rien n’est enregistré.';
}
