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
    return 'Cherche si une cotisation ordinaire a été créditée pour $taxYear sur chacun de tes 3a. Si un transfert, un rachat ou un remboursement rend la réponse incertaine, garde « Je ne sais pas ».';
  }

  @override
  String get contributionUnknownListLabel => 'Comment vérifier sans deviner';

  @override
  String contributionUnknownProviderStatement(int taxYear) {
    return 'Dans l’app ou le relevé de chaque banque ou fintech 3a, cherche un crédit reçu pour $taxYear.';
  }

  @override
  String get contributionUnknownInsuranceCertificate =>
      'Pour une assurance 3a, regarde l’attestation annuelle ou demande quelle cotisation ordinaire a été créditée.';

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
    return 'Ensuite, MINT demandera le total ordinaire déjà crédité pour $taxYear.';
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

  @override
  String batch11AmountEyebrow(int taxYear) {
    return 'TES VERSEMENTS 3A · $taxYear';
  }

  @override
  String batch11AmountTitle(int taxYear) {
    return 'Combien tes 3a ont-ils reçu au total en $taxYear ?';
  }

  @override
  String get batch11AmountBody =>
      'Commence par ton prestataire 3a. Si tu en as plusieurs, indique après ce premier montant qu’il t’en manque un.';

  @override
  String get batch11ProviderNameLabel => 'Prestataire 3a';

  @override
  String get batch11ProviderNamePrivacy =>
      'N’indique aucun numéro de compte, de police, AVS ou IBAN.';

  @override
  String batch11OrdinaryAmountLabel(int taxYear) {
    return 'Cotisations ordinaires créditées · $taxYear';
  }

  @override
  String get batch11NotTaxResult =>
      'Ce total n’est pas encore un résultat fiscal.';

  @override
  String batch11AllProvidersReviewed(int taxYear) {
    return 'Je n’ai qu’un seul prestataire 3a et j’ai vérifié son total pour $taxYear';
  }

  @override
  String get batch11WhereFindTitle => 'Où trouver le montant ?';

  @override
  String get batch11WhereFindBody =>
      'Sur l’attestation de chaque prestataire, cherche « Total des cotisations au pilier 3a ». Utilise ce total une seule fois, même s’il couvre plusieurs contrats.';

  @override
  String get batch11UnknownAmount => 'Je ne connais encore aucun montant';

  @override
  String get batch11Continue => 'Continuer';

  @override
  String get batch11CorrectPrevious => 'Corriger ma réponse précédente';

  @override
  String get batch11ProviderNameEmpty => 'Indique le nom du prestataire.';

  @override
  String get batch11ProviderNameSensitive =>
      'Utilise seulement le nom du prestataire, sans numéro de compte, de police, AVS ou IBAN.';

  @override
  String get batch11AmountInvalid => 'Indique un montant CHF valide.';

  @override
  String get batch11AmountZero => 'Le montant doit être supérieur à zéro.';

  @override
  String get batch11ReviewAllRequired =>
      'Confirme que tu as vérifié tous tes 3a.';

  @override
  String get batch11HelpTitle => 'Retrouve d’abord un montant confirmé.';

  @override
  String get batch11HelpUnknownBody =>
      'Commence par l’attestation d’un prestataire 3a. Cherche son total de cotisations ordinaires pour l’année, sans ajouter transfert, rachat ni remboursement.';

  @override
  String get batch11HelpFoundFirst => 'J’ai trouvé un premier montant';

  @override
  String get batch11HelpEducationOnly =>
      'Continuer avec une explication générale';

  @override
  String get batch11HelpBack => 'Revenir à la saisie';

  @override
  String get batch11MissingAmount => 'J’ai plusieurs prestataires 3a';

  @override
  String get batch11HelpPartialBody =>
      'Ce premier parcours ne peut pas encore additionner plusieurs prestataires. Ne confirme pas ce total ici. Si tu t’es trompé et n’en as qu’un, corrige ta déclaration ; sinon, continue avec une explication générale.';

  @override
  String get batch11HelpFoundPartial =>
      'En fait, je n’ai qu’un seul prestataire';

  @override
  String batch12PositiveCantonTitle(int taxYear) {
    return 'Le total de tes cotisations ordinaires pour $taxYear est prêt.';
  }

  @override
  String get batch12PositiveCantonBody =>
      'Aucun résultat fiscal n’est encore calculé. L’étape suivante demandera ton canton.';

  @override
  String get batch12CorrectAmounts => 'Corriger mes montants';

  @override
  String get batch14AmountBody =>
      'Ajoute chaque prestataire 3a séparément. MINT additionne les montants localement, sans calculer encore de résultat fiscal.';

  @override
  String get batch14AddProvider => 'Ajouter un prestataire 3a';

  @override
  String batch14ProviderRowLabel(int index) {
    return 'Prestataire 3a n°$index';
  }

  @override
  String batch14ProvisionalSubtotal(String amount) {
    return 'Addition provisoire — aucun résultat fiscal calculé : $amount';
  }

  @override
  String batch14AllReviewed(int taxYear) {
    return 'Je confirme avoir inclus, pour $taxYear, uniquement les versements ordinaires réellement crédités chez tous mes prestataires 3a';
  }

  @override
  String get batch14RemoveEmpty => 'Supprimer cette ligne vide';

  @override
  String get batch14Duplicate =>
      'Ce prestataire est déjà présent. Corrige sa ligne pour éviter un double comptage.';

  @override
  String get batch14AggregateOverflow =>
      'L’addition est trop grande. Vérifie les montants indiqués.';

  @override
  String get batch14EmptyBeforeAdd =>
      'Commence la ligne vide ou supprime-la avant d’en ajouter une autre.';

  @override
  String batch14ClassificationGuide(int taxYear) {
    return 'Pour $taxYear, une ligne correspond au total annuel d’un prestataire, même si tu y as plusieurs contrats ou polices. Indique uniquement les versements ordinaires réellement crédités et compte chaque montant une seule fois. N’inclus pas les transferts, rachats rétroactifs, paiements encore en attente ou seulement débités, ni le rendement. Après une correction ou un remboursement, utilise le montant net confirmé par le prestataire.';
  }

  @override
  String get batch14Privacy =>
      'Saisie locale et éphémère : rien n’est enregistré ni envoyé. N’indique aucun numéro de compte, de police, AVS ou IBAN. Quitter efface les noms et montants.';

  @override
  String get batch14RemovedAnnouncement =>
      'Ligne vide supprimée. Le focus est placé sur la ligne voisine.';

  @override
  String get batch14ProviderCapacity =>
      'Cette saisie accepte au maximum 50 prestataires. Vérifie la liste avant de continuer.';

  @override
  String get batch15RemoveProvider => 'Retirer cette ligne de ma saisie';

  @override
  String batch15TombstoneLabel(int rowNumber) {
    return 'Ligne $rowNumber retirée de cette saisie';
  }

  @override
  String batch15UndoRemoval(int rowNumber) {
    return 'Annuler le retrait de la ligne $rowNumber';
  }

  @override
  String batch15FinalizeRemoval(int rowNumber) {
    return 'Effacer définitivement la ligne $rowNumber de cette saisie';
  }

  @override
  String batch15TombstonedAnnouncement(String subtotal) {
    return 'Ligne retirée de cette saisie. Nouveau sous-total provisoire : $subtotal.';
  }

  @override
  String batch15RestoredAnnouncement(String subtotal) {
    return 'Ligne restaurée dans cette saisie. Nouveau sous-total provisoire : $subtotal.';
  }

  @override
  String get batch15FinalizedAnnouncement =>
      'La ligne supprimée a été définitivement effacée de cette saisie.';

  @override
  String get batch15NoProvisionalSubtotal => 'aucun montant positif saisi';

  @override
  String get batch15ResolveTombstoneError =>
      'Annule le retrait ou efface définitivement cette ligne avant de continuer.';

  @override
  String get batch16AnnualOrdinaryTotalMeaning =>
      'Saisis une seule fois, pour chaque prestataire, le total annuel des cotisations ordinaires indiqué sur son attestation annuelle.';

  @override
  String batch16ActuallyCreditedMeaning(int taxYear) {
    return 'Compte uniquement ce qui a réellement été crédité pour $taxYear, pas ce qui était prévu, envoyé ou débité.';
  }

  @override
  String get batch16ExcludedMovementsMeaning =>
      'N’inclus pas les transferts, rachats rétroactifs, mouvements en attente, remboursements ni gains de placement.';

  @override
  String get batch16ProviderConfirmedNetMeaning =>
      'Après une correction ou un remboursement, demande au prestataire son total net confirmé des cotisations ordinaires; ne soustrais rien toi-même.';

  @override
  String get batch16InsuranceCertificateMeaning =>
      'Pour une assurance, utilise l’attestation annuelle; n’utilise ni la valeur de rachat ni la répartition risque/épargne.';

  @override
  String get batch16RefundVsAllZeroMeaning =>
      'Le remboursement intégral d’un prestataire ne signifie pas que tous les prestataires sont à zéro.';

  @override
  String get batch16MintNotVerifiedMeaning =>
      'MINT n’a pas vérifié le montant saisi.';

  @override
  String get batch16NoTaxAdviceMeaning =>
      'Cette étape ne produit ni résultat fiscal ni recommandation.';

  @override
  String batch16RowContext(int rowNumber, int taxYear) {
    return 'ligne $rowNumber · $taxYear';
  }

  @override
  String get batch16HelpTitle => 'Besoin d’aide ?';

  @override
  String get batch16HelpCompactTitle => 'Aide';

  @override
  String get batch16HelpCompactBody => 'MINT : non vérifié.';

  @override
  String get batch16HelpBody =>
      'MINT n’a pas vérifié ce total. Choisis seulement si tu es sûr.';

  @override
  String get batch16HelpDetails => 'Comprendre les règles pour cette ligne';

  @override
  String get batch16HelpProviderTotal => 'Total ordinaire obtenu';

  @override
  String get batch16HelpProviderTotalCompact => 'Total 3a reçu';

  @override
  String get batch16HelpProviderRefunded =>
      'Remboursement intégral de ce prestataire';

  @override
  String get batch16HelpAllZero => 'Tous mes prestataires sont à zéro';

  @override
  String get batch16HelpEducation => 'Je veux comprendre ce qui compte';

  @override
  String get batch16HelpBack => 'Revenir à la saisie';

  @override
  String get batch16StatusUnreviewed => 'À vérifier';

  @override
  String get batch16StatusConfirmed => 'Confirmé';

  @override
  String get batch16StatusUnresolved => 'Question non résolue';

  @override
  String get batch16UnresolvedError =>
      'Réponds à cette question avant de continuer.';

  @override
  String get batch16CorrectionTitle => 'Corriger cette réponse';

  @override
  String get batch16CorrectionDataLoss =>
      'Si tu choisis « Non » ou « Je ne sais pas », MINT effacera immédiatement tous les prestataires et montants de cette saisie locale. Cette action ne peut pas être annulée.';

  @override
  String get batch16CurrentYes => 'Réponse actuelle : Oui';

  @override
  String get batch16Unselected => 'Aucune réponse sélectionnée';

  @override
  String get batch16ChooseYes => 'Choisir Oui';

  @override
  String get batch16ChooseNo => 'Non — effacer ces montants et continuer';

  @override
  String get batch16ChooseUnknown =>
      'Je ne sais pas — effacer ces montants et vérifier';

  @override
  String get batch16Back => 'Retour';
}
