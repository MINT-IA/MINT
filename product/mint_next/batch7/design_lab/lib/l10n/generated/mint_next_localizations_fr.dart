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

  @override
  String get quitJourney => 'Quitter ce parcours';

  @override
  String contributionEyebrow(int taxYear) {
    return 'TES VERSEMENTS 3A · $taxYear';
  }

  @override
  String contributionTitle(int taxYear) {
    return 'En $taxYear, l’un de tes 3a a-t-il reçu un nouveau versement ?';
  }

  @override
  String get contributionBody =>
      'Réponds pour tous tes 3a, y compris une assurance 3a.';

  @override
  String contributionCreditedNote(int taxYear) {
    return 'Compte seulement l’argent neuf reçu pour $taxYear. Un paiement seulement envoyé ou débité ne compte pas encore ; un transfert, un rendement ou un remboursement de frais non plus.';
  }

  @override
  String get contributionAmountNote =>
      'Pas besoin de connaître le total maintenant. On te le demandera seulement si tu réponds oui.';

  @override
  String get contributionChoiceYes => 'Oui, un nouveau versement a été reçu';

  @override
  String get contributionChoiceNo => 'Non, aucun nouveau versement';

  @override
  String get contributionChoiceUnknown => 'Je ne sais pas';

  @override
  String contributionChoiceGroupLabel(int taxYear) {
    return 'Nouveaux versements 3a reçus en $taxYear';
  }

  @override
  String get contributionEdgeHelp => 'Ce qui compte — et ce qui ne compte pas';

  @override
  String get contributionEdgePending =>
      'Un paiement planifié, envoyé ou débité ne compte qu’une fois reçu sur ton 3a.';

  @override
  String get contributionEdgeTransfer =>
      'Ne compte pas un transfert entre deux 3a : ce n’est pas de l’argent neuf.';

  @override
  String get contributionEdgeBuyback =>
      'Garde séparé un rachat pour une année passée.';

  @override
  String get contributionEdgeFullRefund =>
      'Après un remboursement complet, réponds non si aucune cotisation ordinaire effective ne reste.';

  @override
  String get contributionEdgePartialRefund =>
      'Après un remboursement partiel, réponds oui si le prestataire confirme qu’un montant net positif reste.';

  @override
  String get contributionEdgeUnclearCorrection =>
      'Si une correction rend le montant effectif incertain, choisis « Je ne sais pas ».';

  @override
  String get contributionEdgeMixedTransfer =>
      'Si un transfert et de l’argent neuf arrivent ensemble, compte seulement l’argent neuf.';

  @override
  String get contributionEdgeReturn =>
      'Ne compte pas les rendements ou les intérêts comme un versement.';

  @override
  String get contributionEdgeAdjustment =>
      'Ne compte pas un remboursement de frais, une ristourne ou un autre ajustement.';

  @override
  String get contributionUnknownEyebrow => 'AUCUN SOUCI';

  @override
  String get contributionUnknownTitle =>
      'Tu peux vérifier sans additionner toi-même.';

  @override
  String contributionUnknownBody(int taxYear) {
    return 'Cherche si une cotisation ordinaire a été reçue pour $taxYear sur chacun de tes 3a. Si un transfert, un rachat ou un remboursement rend la réponse incertaine, garde « Je ne sais pas ».';
  }

  @override
  String get contributionUnknownListLabel => 'Comment vérifier sans deviner';

  @override
  String contributionUnknownProviderStatement(int taxYear) {
    return 'Dans l’app ou le relevé de chaque banque ou fintech 3a, cherche un crédit reçu pour $taxYear.';
  }

  @override
  String get contributionUnknownInsuranceCertificate =>
      'Pour une assurance 3a, regarde l’attestation annuelle ou demande quelle cotisation ordinaire a été reçue.';

  @override
  String get contributionUnknownProviderQuestion =>
      'En cas de doute, demande au prestataire si le mouvement est une cotisation ordinaire, un transfert, un rachat ou un remboursement.';

  @override
  String get contributionUnknownTransferWarning =>
      'N’additionne jamais un transfert entre deux 3a. Ce serait compter le même argent deux fois.';

  @override
  String get contributionUnknownEducationLimit =>
      'Tu peux continuer sans montant personnel. MINT montrera seulement une explication générale.';

  @override
  String get contributionUnknownContinueEducation =>
      'Continuer avec une explication générale';

  @override
  String get contributionBackToQuestion => 'Revenir à la question';

  @override
  String contributionAmountBoundaryTitle(int taxYear) {
    return 'Ensuite, MINT demandera le total ordinaire déjà reçu pour $taxYear.';
  }

  @override
  String contributionAmountBoundaryBody(int taxYear) {
    return 'Le total devra couvrir tous tes comptes et polices 3a. Après un remboursement partiel, tu pourras utiliser le montant net confirmé par le prestataire. Pour l’instant, aucun montant n’est connu ni calculé.';
  }

  @override
  String contributionCantonBoundaryTitle(int taxYear) {
    return 'D’après ta réponse, aucun versement ordinaire n’est retenu pour $taxYear.';
  }

  @override
  String get contributionCantonBoundaryBody =>
      'Aucun résultat fiscal n’est encore calculé. L’étape suivante demandera ton canton.';

  @override
  String get contributionBoundaryBack => 'Corriger ma réponse';

  @override
  String get contributionEducationTitle =>
      'Tu peux comprendre la règle sans donner de montant.';

  @override
  String get contributionEducationBody =>
      'Cette explication reste générale : aucun montant personnel, aucune marge 3a et aucune économie fiscale personnelle ne sont calculés.';

  @override
  String get contributionEducationBack => 'Revenir aux vérifications';
}
