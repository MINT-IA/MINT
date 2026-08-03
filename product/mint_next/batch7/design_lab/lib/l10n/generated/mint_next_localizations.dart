import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'mint_next_localizations_de.dart';
import 'mint_next_localizations_en.dart';
import 'mint_next_localizations_es.dart';
import 'mint_next_localizations_fr.dart';
import 'mint_next_localizations_it.dart';
import 'mint_next_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of MintNextLocalizations
/// returned by `MintNextLocalizations.of(context)`.
///
/// Applications need to include `MintNextLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/mint_next_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: MintNextLocalizations.localizationsDelegates,
///   supportedLocales: MintNextLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the MintNextLocalizations.supportedLocales
/// property.
abstract class MintNextLocalizations {
  MintNextLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static MintNextLocalizations of(BuildContext context) {
    return Localizations.of<MintNextLocalizations>(
      context,
      MintNextLocalizations,
    )!;
  }

  static const LocalizationsDelegate<MintNextLocalizations> delegate =
      _MintNextLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('pt'),
  ];

  /// No description provided for @brand.
  ///
  /// In fr, this message translates to:
  /// **'MINT'**
  String get brand;

  /// No description provided for @quit.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get quit;

  /// No description provided for @todayEyebrow.
  ///
  /// In fr, this message translates to:
  /// **'AUJOURD’HUI · 3A'**
  String get todayEyebrow;

  /// No description provided for @todayTitle.
  ///
  /// In fr, this message translates to:
  /// **'Que change un versement 3a cette année ?'**
  String get todayTitle;

  /// No description provided for @todayBody.
  ///
  /// In fr, this message translates to:
  /// **'On va comprendre ses effets, une étape à la fois. MINT t’informe, mais ne décide pas à ta place.'**
  String get todayBody;

  /// No description provided for @start.
  ///
  /// In fr, this message translates to:
  /// **'Comprendre'**
  String get start;

  /// No description provided for @orientationEyebrow.
  ///
  /// In fr, this message translates to:
  /// **'AVANT LES CHIFFRES'**
  String get orientationEyebrow;

  /// No description provided for @orientationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Épargner pour ta retraite peut aussi réduire tes impôts.'**
  String get orientationTitle;

  /// No description provided for @orientationBody.
  ///
  /// In fr, this message translates to:
  /// **'Un versement 3a peut diminuer ton revenu imposable — le montant sur lequel tes impôts sont calculés. Ton argent disponible baisse maintenant et le capital 3a reste lié jusqu’à la retraite, sauf dans les cas prévus par la loi.'**
  String get orientationBody;

  /// No description provided for @orientationNote.
  ///
  /// In fr, this message translates to:
  /// **'On vérifiera d’abord l’année et ta situation. Aucun montant ne sera recommandé.'**
  String get orientationNote;

  /// No description provided for @continueLabel.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get continueLabel;

  /// No description provided for @backLabel.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get backLabel;

  /// No description provided for @taxYearEyebrow.
  ///
  /// In fr, this message translates to:
  /// **'ÉTAPE 1 · ANNÉE FISCALE'**
  String get taxYearEyebrow;

  /// No description provided for @taxYearTitle.
  ///
  /// In fr, this message translates to:
  /// **'De quelle année parle-t-on ?'**
  String get taxYearTitle;

  /// No description provided for @taxYearBody.
  ///
  /// In fr, this message translates to:
  /// **'Le plafond dépend de l’année et de ta situation, notamment de ton revenu professionnel et de ton affiliation à une caisse de pension. L’année en cours est proposée, jamais choisie à ta place.'**
  String get taxYearBody;

  /// No description provided for @currentYearLabel.
  ///
  /// In fr, this message translates to:
  /// **'Année en cours : {year}'**
  String currentYearLabel(int year);

  /// No description provided for @confirmYear.
  ///
  /// In fr, this message translates to:
  /// **'Choisir {year}'**
  String confirmYear(int year);

  /// No description provided for @yearChosen.
  ///
  /// In fr, this message translates to:
  /// **'Année {year} sélectionnée'**
  String yearChosen(int year);

  /// No description provided for @partialBoundary.
  ///
  /// In fr, this message translates to:
  /// **'Le prochain écran sera ajouté dans le lot suivant. Rien n’est enregistré.'**
  String get partialBoundary;

  /// No description provided for @safeExitTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tu veux t’arrêter ici ?'**
  String get safeExitTitle;

  /// No description provided for @safeExitBody.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée financière personnelle n’est enregistrée dans ce Design Lab.'**
  String get safeExitBody;

  /// No description provided for @resume.
  ///
  /// In fr, this message translates to:
  /// **'Continuer ici'**
  String get resume;

  /// No description provided for @leave.
  ///
  /// In fr, this message translates to:
  /// **'Quitter sans enregistrer'**
  String get leave;

  /// No description provided for @dismissedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Parcours fermé'**
  String get dismissedTitle;

  /// No description provided for @startShort.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get startShort;

  /// No description provided for @keepReferenceUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Repère local — bientôt disponible'**
  String get keepReferenceUnavailable;

  /// No description provided for @lppQuestionEyebrow.
  ///
  /// In fr, this message translates to:
  /// **'TA SITUATION'**
  String get lppQuestionEyebrow;

  /// No description provided for @lppQuestionTitle.
  ///
  /// In fr, this message translates to:
  /// **'As-tu actuellement une caisse de pension ?'**
  String get lppQuestionTitle;

  /// No description provided for @lppQuestionBody.
  ///
  /// In fr, this message translates to:
  /// **'C’est aussi appelé LPP ou 2e pilier. Tu peux être affilié·e par ton emploi ou volontairement. Ici, on te demande si tu es couvert·e actuellement, pas combien tu verses.'**
  String get lppQuestionBody;

  /// No description provided for @lppQuestionEvidence.
  ///
  /// In fr, this message translates to:
  /// **'Pour vérifier, cherche une ligne LPP ou caisse de pension sur une fiche de salaire, consulte un certificat récent, ou demande à ta caisse, ton employeur ou aux RH.'**
  String get lppQuestionEvidence;

  /// No description provided for @lppChoiceYes.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get lppChoiceYes;

  /// No description provided for @lppChoiceNo.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get lppChoiceNo;

  /// No description provided for @lppChoiceUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Je ne sais pas'**
  String get lppChoiceUnknown;

  /// No description provided for @lppUnknownEyebrow.
  ///
  /// In fr, this message translates to:
  /// **'AUCUN SOUCI'**
  String get lppUnknownEyebrow;

  /// No description provided for @lppUnknownTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tu peux le vérifier sans deviner.'**
  String get lppUnknownTitle;

  /// No description provided for @lppUnknownBody.
  ///
  /// In fr, this message translates to:
  /// **'Commence par ce qui est le plus facile pour toi. Quand tu as la réponse, reprends ce parcours et réponds à nouveau à la question.'**
  String get lppUnknownBody;

  /// No description provided for @lppUnknownListLabel.
  ///
  /// In fr, this message translates to:
  /// **'Trois façons de vérifier ton affiliation'**
  String get lppUnknownListLabel;

  /// No description provided for @lppUnknownPayslip.
  ///
  /// In fr, this message translates to:
  /// **'Cherche une ligne LPP, 2e pilier, CP ou caisse de pension sur une fiche de salaire récente.'**
  String get lppUnknownPayslip;

  /// No description provided for @lppUnknownCertificate.
  ///
  /// In fr, this message translates to:
  /// **'Cherche un certificat de prévoyance récent envoyé par ta caisse de pension.'**
  String get lppUnknownCertificate;

  /// No description provided for @lppUnknownAsk.
  ///
  /// In fr, this message translates to:
  /// **'Demande à ta caisse de pension, ton employeur ou aux RH si tu es actuellement affilié·e.'**
  String get lppUnknownAsk;

  /// No description provided for @lppBackToQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Revenir à la question'**
  String get lppBackToQuestion;

  /// No description provided for @lppKeepChecklist.
  ///
  /// In fr, this message translates to:
  /// **'Garder cette liste sur cet appareil'**
  String get lppKeepChecklist;

  /// No description provided for @localReferenceUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Bientôt disponible'**
  String get localReferenceUnavailable;

  /// No description provided for @withoutLppEyebrow.
  ///
  /// In fr, this message translates to:
  /// **'UNE AUTRE RÈGLE S’APPLIQUE'**
  String get withoutLppEyebrow;

  /// No description provided for @withoutLppTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tu peux peut-être verser dans un 3a, mais avec d’autres règles.'**
  String get withoutLppTitle;

  /// No description provided for @withoutLppBody.
  ///
  /// In fr, this message translates to:
  /// **'Ta réponse ne signifie pas que tu n’as pas droit au 3a. Ce premier calcul ne couvre simplement pas encore ce cas.'**
  String get withoutLppBody;

  /// No description provided for @lppCorrectAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Corriger ma réponse'**
  String get lppCorrectAnswer;

  /// No description provided for @withoutLppKeepExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Garder cette explication sur cet appareil'**
  String get withoutLppKeepExplanation;

  /// No description provided for @nextStepEyebrow.
  ///
  /// In fr, this message translates to:
  /// **'ÉTAPE SUIVANTE'**
  String get nextStepEyebrow;

  /// No description provided for @nextStepTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ton affiliation est claire.'**
  String get nextStepTitle;

  /// No description provided for @nextStepBody.
  ///
  /// In fr, this message translates to:
  /// **'La prochaine question portera sur ce que tu as déjà versé cette année. Elle sera ajoutée dans le prochain petit lot. Rien n’est enregistré.'**
  String get nextStepBody;

  /// No description provided for @quitJourney.
  ///
  /// In fr, this message translates to:
  /// **'Quitter ce parcours'**
  String get quitJourney;

  /// No description provided for @contributionEyebrow.
  ///
  /// In fr, this message translates to:
  /// **'TES VERSEMENTS 3A · {taxYear}'**
  String contributionEyebrow(int taxYear);

  /// No description provided for @contributionTitle.
  ///
  /// In fr, this message translates to:
  /// **'En {taxYear}, l’un de tes 3a a-t-il reçu un nouveau versement ?'**
  String contributionTitle(int taxYear);

  /// No description provided for @contributionBody.
  ///
  /// In fr, this message translates to:
  /// **'Réponds pour tous tes 3a, y compris une assurance 3a.'**
  String get contributionBody;

  /// No description provided for @contributionCreditedNote.
  ///
  /// In fr, this message translates to:
  /// **'Compte seulement l’argent neuf reçu pour {taxYear}. Un paiement seulement envoyé ou débité ne compte pas encore ; un transfert, un rendement ou un remboursement de frais non plus.'**
  String contributionCreditedNote(int taxYear);

  /// No description provided for @contributionAmountNote.
  ///
  /// In fr, this message translates to:
  /// **'Pas besoin de connaître le total maintenant. On te le demandera seulement si tu réponds oui.'**
  String get contributionAmountNote;

  /// No description provided for @contributionChoiceYes.
  ///
  /// In fr, this message translates to:
  /// **'Oui, un nouveau versement a été reçu'**
  String get contributionChoiceYes;

  /// No description provided for @contributionChoiceNo.
  ///
  /// In fr, this message translates to:
  /// **'Non, aucun nouveau versement'**
  String get contributionChoiceNo;

  /// No description provided for @contributionChoiceUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Je ne sais pas'**
  String get contributionChoiceUnknown;

  /// No description provided for @contributionChoiceGroupLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nouveaux versements 3a reçus en {taxYear}'**
  String contributionChoiceGroupLabel(int taxYear);

  /// No description provided for @contributionEdgeHelp.
  ///
  /// In fr, this message translates to:
  /// **'Ce qui compte — et ce qui ne compte pas'**
  String get contributionEdgeHelp;

  /// No description provided for @contributionEdgePending.
  ///
  /// In fr, this message translates to:
  /// **'Un paiement planifié, envoyé ou débité ne compte qu’une fois reçu sur ton 3a.'**
  String get contributionEdgePending;

  /// No description provided for @contributionEdgeTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Ne compte pas un transfert entre deux 3a : ce n’est pas de l’argent neuf.'**
  String get contributionEdgeTransfer;

  /// No description provided for @contributionEdgeBuyback.
  ///
  /// In fr, this message translates to:
  /// **'Garde séparé un rachat pour une année passée.'**
  String get contributionEdgeBuyback;

  /// No description provided for @contributionEdgeFullRefund.
  ///
  /// In fr, this message translates to:
  /// **'Après un remboursement complet, réponds non si aucune cotisation ordinaire effective ne reste.'**
  String get contributionEdgeFullRefund;

  /// No description provided for @contributionEdgePartialRefund.
  ///
  /// In fr, this message translates to:
  /// **'Après un remboursement partiel, réponds oui si le prestataire confirme qu’un montant net positif reste.'**
  String get contributionEdgePartialRefund;

  /// No description provided for @contributionEdgeUnclearCorrection.
  ///
  /// In fr, this message translates to:
  /// **'Si une correction rend le montant effectif incertain, choisis « Je ne sais pas ».'**
  String get contributionEdgeUnclearCorrection;

  /// No description provided for @contributionEdgeMixedTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Si un transfert et de l’argent neuf arrivent ensemble, compte seulement l’argent neuf.'**
  String get contributionEdgeMixedTransfer;

  /// No description provided for @contributionEdgeReturn.
  ///
  /// In fr, this message translates to:
  /// **'Ne compte pas les rendements ou les intérêts comme un versement.'**
  String get contributionEdgeReturn;

  /// No description provided for @contributionEdgeAdjustment.
  ///
  /// In fr, this message translates to:
  /// **'Ne compte pas un remboursement de frais, une ristourne ou un autre ajustement.'**
  String get contributionEdgeAdjustment;

  /// No description provided for @contributionUnknownEyebrow.
  ///
  /// In fr, this message translates to:
  /// **'AUCUN SOUCI'**
  String get contributionUnknownEyebrow;

  /// No description provided for @contributionUnknownTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tu peux vérifier sans additionner toi-même.'**
  String get contributionUnknownTitle;

  /// No description provided for @contributionUnknownBody.
  ///
  /// In fr, this message translates to:
  /// **'Cherche si une cotisation ordinaire a été créditée pour {taxYear} sur chacun de tes 3a. Si un transfert, un rachat ou un remboursement rend la réponse incertaine, garde « Je ne sais pas ».'**
  String contributionUnknownBody(int taxYear);

  /// No description provided for @contributionUnknownListLabel.
  ///
  /// In fr, this message translates to:
  /// **'Comment vérifier sans deviner'**
  String get contributionUnknownListLabel;

  /// No description provided for @contributionUnknownProviderStatement.
  ///
  /// In fr, this message translates to:
  /// **'Dans l’app ou le relevé de chaque banque ou fintech 3a, cherche un crédit reçu pour {taxYear}.'**
  String contributionUnknownProviderStatement(int taxYear);

  /// No description provided for @contributionUnknownInsuranceCertificate.
  ///
  /// In fr, this message translates to:
  /// **'Pour une assurance 3a, regarde l’attestation annuelle ou demande quelle cotisation ordinaire a été créditée.'**
  String get contributionUnknownInsuranceCertificate;

  /// No description provided for @contributionUnknownProviderQuestion.
  ///
  /// In fr, this message translates to:
  /// **'En cas de doute, demande au prestataire si le mouvement est une cotisation ordinaire, un transfert, un rachat ou un remboursement.'**
  String get contributionUnknownProviderQuestion;

  /// No description provided for @contributionUnknownTransferWarning.
  ///
  /// In fr, this message translates to:
  /// **'N’additionne jamais un transfert entre deux 3a. Ce serait compter le même argent deux fois.'**
  String get contributionUnknownTransferWarning;

  /// No description provided for @contributionUnknownEducationLimit.
  ///
  /// In fr, this message translates to:
  /// **'Tu peux continuer sans montant personnel. MINT montrera seulement une explication générale.'**
  String get contributionUnknownEducationLimit;

  /// No description provided for @contributionUnknownContinueEducation.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec une explication générale'**
  String get contributionUnknownContinueEducation;

  /// No description provided for @contributionBackToQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Revenir à la question'**
  String get contributionBackToQuestion;

  /// No description provided for @contributionAmountBoundaryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ensuite, MINT demandera le total ordinaire déjà crédité pour {taxYear}.'**
  String contributionAmountBoundaryTitle(int taxYear);

  /// No description provided for @contributionAmountBoundaryBody.
  ///
  /// In fr, this message translates to:
  /// **'Le total devra couvrir tous tes comptes et polices 3a. Après un remboursement partiel, tu pourras utiliser le montant net confirmé par le prestataire. Pour l’instant, aucun montant n’est connu ni calculé.'**
  String contributionAmountBoundaryBody(int taxYear);

  /// No description provided for @contributionCantonBoundaryTitle.
  ///
  /// In fr, this message translates to:
  /// **'D’après ta réponse, aucun versement ordinaire n’est retenu pour {taxYear}.'**
  String contributionCantonBoundaryTitle(int taxYear);

  /// No description provided for @contributionCantonBoundaryBody.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat fiscal n’est encore calculé. L’étape suivante demandera ton canton.'**
  String get contributionCantonBoundaryBody;

  /// No description provided for @contributionBoundaryBack.
  ///
  /// In fr, this message translates to:
  /// **'Corriger ma réponse'**
  String get contributionBoundaryBack;

  /// No description provided for @contributionEducationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tu peux comprendre la règle sans donner de montant.'**
  String get contributionEducationTitle;

  /// No description provided for @contributionEducationBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette explication reste générale : aucun montant personnel, aucune marge 3a et aucune économie fiscale personnelle ne sont calculés.'**
  String get contributionEducationBody;

  /// No description provided for @contributionEducationBack.
  ///
  /// In fr, this message translates to:
  /// **'Revenir aux vérifications'**
  String get contributionEducationBack;

  /// No description provided for @batch11AmountEyebrow.
  ///
  /// In fr, this message translates to:
  /// **'TES VERSEMENTS 3A · {taxYear}'**
  String batch11AmountEyebrow(int taxYear);

  /// No description provided for @batch11AmountTitle.
  ///
  /// In fr, this message translates to:
  /// **'Combien tes 3a ont-ils reçu au total en {taxYear} ?'**
  String batch11AmountTitle(int taxYear);

  /// No description provided for @batch11AmountBody.
  ///
  /// In fr, this message translates to:
  /// **'Saisis le total ordinaire indiqué par chaque prestataire 3a. MINT additionne les montants.'**
  String get batch11AmountBody;

  /// No description provided for @batch11ProviderNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom du prestataire (par ex. VIAC ou ta banque)'**
  String get batch11ProviderNameLabel;

  /// No description provided for @batch11ProviderNamePrivacy.
  ///
  /// In fr, this message translates to:
  /// **'N’indique aucun numéro de compte, de police, AVS ou IBAN.'**
  String get batch11ProviderNamePrivacy;

  /// No description provided for @batch11OrdinaryAmountLabel.
  ///
  /// In fr, this message translates to:
  /// **'Montant ordinaire confirmé pour {taxYear}'**
  String batch11OrdinaryAmountLabel(int taxYear);

  /// No description provided for @batch11NotTaxResult.
  ///
  /// In fr, this message translates to:
  /// **'Ce total n’est pas encore un résultat fiscal.'**
  String get batch11NotTaxResult;

  /// No description provided for @batch11AllProvidersReviewed.
  ///
  /// In fr, this message translates to:
  /// **'J’ai vérifié tous mes 3a pour {taxYear}'**
  String batch11AllProvidersReviewed(int taxYear);

  /// No description provided for @batch11WhereFindTitle.
  ///
  /// In fr, this message translates to:
  /// **'Où trouver le montant ?'**
  String get batch11WhereFindTitle;

  /// No description provided for @batch11WhereFindBody.
  ///
  /// In fr, this message translates to:
  /// **'Sur l’attestation de chaque prestataire, cherche « Total des cotisations au pilier 3a ». Utilise ce total une seule fois, même s’il couvre plusieurs contrats.'**
  String get batch11WhereFindBody;

  /// No description provided for @batch11UnknownAmount.
  ///
  /// In fr, this message translates to:
  /// **'Je ne connais encore aucun montant'**
  String get batch11UnknownAmount;

  /// No description provided for @batch11Continue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get batch11Continue;

  /// No description provided for @batch11CorrectPrevious.
  ///
  /// In fr, this message translates to:
  /// **'Corriger ma réponse précédente'**
  String get batch11CorrectPrevious;

  /// No description provided for @batch11ProviderNameEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Indique le nom du prestataire.'**
  String get batch11ProviderNameEmpty;

  /// No description provided for @batch11ProviderNameSensitive.
  ///
  /// In fr, this message translates to:
  /// **'Utilise seulement le nom du prestataire, sans numéro de compte, de police, AVS ou IBAN.'**
  String get batch11ProviderNameSensitive;

  /// No description provided for @batch11AmountInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Indique un montant CHF valide.'**
  String get batch11AmountInvalid;

  /// No description provided for @batch11AmountZero.
  ///
  /// In fr, this message translates to:
  /// **'Le montant doit être supérieur à zéro.'**
  String get batch11AmountZero;

  /// No description provided for @batch11ReviewAllRequired.
  ///
  /// In fr, this message translates to:
  /// **'Confirme que tu as vérifié tous tes 3a.'**
  String get batch11ReviewAllRequired;

  /// No description provided for @batch11HelpTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retrouve d’abord un montant confirmé.'**
  String get batch11HelpTitle;

  /// No description provided for @batch11HelpUnknownBody.
  ///
  /// In fr, this message translates to:
  /// **'Commence par l’attestation d’un prestataire 3a. Cherche son total de cotisations ordinaires pour l’année, sans ajouter transfert, rachat ni remboursement.'**
  String get batch11HelpUnknownBody;

  /// No description provided for @batch11HelpFoundFirst.
  ///
  /// In fr, this message translates to:
  /// **'J’ai trouvé un premier montant'**
  String get batch11HelpFoundFirst;

  /// No description provided for @batch11HelpEducationOnly.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec une explication générale'**
  String get batch11HelpEducationOnly;

  /// No description provided for @batch11HelpBack.
  ///
  /// In fr, this message translates to:
  /// **'Revenir à la saisie'**
  String get batch11HelpBack;

  /// No description provided for @batch11MissingAmount.
  ///
  /// In fr, this message translates to:
  /// **'Il me manque le montant d’un de mes 3a'**
  String get batch11MissingAmount;

  /// No description provided for @batch11HelpPartialBody.
  ///
  /// In fr, this message translates to:
  /// **'Garde les montants déjà saisis. Il manque encore au moins un prestataire : retrouve son total confirmé avant de valider.'**
  String get batch11HelpPartialBody;

  /// No description provided for @batch11HelpFoundPartial.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter le montant manquant'**
  String get batch11HelpFoundPartial;
}

class _MintNextLocalizationsDelegate
    extends LocalizationsDelegate<MintNextLocalizations> {
  const _MintNextLocalizationsDelegate();

  @override
  Future<MintNextLocalizations> load(Locale locale) {
    return SynchronousFuture<MintNextLocalizations>(
      lookupMintNextLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'it',
    'pt',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_MintNextLocalizationsDelegate old) => false;
}

MintNextLocalizations lookupMintNextLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return MintNextLocalizationsDe();
    case 'en':
      return MintNextLocalizationsEn();
    case 'es':
      return MintNextLocalizationsEs();
    case 'fr':
      return MintNextLocalizationsFr();
    case 'it':
      return MintNextLocalizationsIt();
    case 'pt':
      return MintNextLocalizationsPt();
  }

  throw FlutterError(
    'MintNextLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
