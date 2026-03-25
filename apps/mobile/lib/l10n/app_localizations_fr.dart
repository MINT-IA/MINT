// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class SFr extends S {
  SFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'MINT';

  @override
  String get landingHero => 'Financial OS.';

  @override
  String get landingSubtitle => 'Votre copilote financier suisse.';

  @override
  String get landingBetaBadge => 'Bêta Privée';

  @override
  String get landingHeroPrefix => 'Le premier';

  @override
  String get landingSubtitleLong =>
      'L\'intelligence d\'un CFO, dans ta poche.\nZéro bullshit. Pur conseil.';

  @override
  String get landingFeature1Title => 'Diagnostic Instantané';

  @override
  String get landingFeature1Desc => 'Analyse 360° en 5 min chrono.';

  @override
  String get landingFeature2Title => '100% Privé & Local';

  @override
  String get landingFeature2Desc => 'Tes données restent sur ton device.';

  @override
  String get landingFeature3Title => 'Stratégie Neutre';

  @override
  String get landingFeature3Desc => 'Zéro commission. Zéro conflit.';

  @override
  String get landingDiagnosticSubtitle => 'Bilan 360° • 5 minutes';

  @override
  String get landingResumeDiagnostic => 'Reprendre mon diagnostic';

  @override
  String get startDiagnostic => 'Démarrer mon diagnostic';

  @override
  String get tabNow => 'MAINTENANT';

  @override
  String get tabExplore => 'Explorer';

  @override
  String get tabTrack => 'SUIVRE';

  @override
  String get budgetTitle => 'Maîtriser mon Budget';

  @override
  String get simulatorsTitle => 'Simulateurs de Voyage';

  @override
  String get recommendations => 'Vos Recommandations';

  @override
  String get disclaimer =>
      'Les résultats présentés sont des estimations à titre indicatif. Ils ne constituent pas un conseil financier personnalisé.';

  @override
  String get onboardingSkip => 'Passer';

  @override
  String onboardingProgress(String step, String total) {
    return 'Étape $step sur $total';
  }

  @override
  String get onboardingStep1Title => 'Bonjour, je suis votre mentor.';

  @override
  String get onboardingStep1Subtitle =>
      'Commençons par faire connaissance. Quelle est votre situation actuelle ?';

  @override
  String get onboardingHouseholdSingle => 'Seul(e)';

  @override
  String get onboardingHouseholdSingleDesc => 'Je gère mes finances en solo';

  @override
  String get onboardingHouseholdCouple => 'En couple';

  @override
  String get onboardingHouseholdCoupleDesc =>
      'Nous partageons nos objectifs financiers';

  @override
  String get onboardingHouseholdFamily => 'Famille';

  @override
  String get onboardingHouseholdFamilyDesc => 'Avec enfant(s) à charge';

  @override
  String get onboardingHouseholdSingleParent => 'Parent solo';

  @override
  String get onboardingHouseholdSingleParentDesc =>
      'Je gère seul(e) avec enfant(s) à charge';

  @override
  String get onboardingStep2Title => 'Très bien.';

  @override
  String get onboardingStep2Subtitle =>
      'Quel est le voyage financier que vous souhaitez entreprendre en priorité ?';

  @override
  String get onboardingGoalHouse => 'Devenir propriétaire';

  @override
  String get onboardingGoalHouseDesc => 'Préparer mon apport et mon hypothèque';

  @override
  String get onboardingGoalRetire => 'Sérénité Retraite';

  @override
  String get onboardingGoalRetireDesc => 'Maximiser mon avenir à long terme';

  @override
  String get onboardingGoalInvest => 'Investir & Grandir';

  @override
  String get onboardingGoalInvestDesc =>
      'Fructifier mes économies intelligemment';

  @override
  String get onboardingGoalTaxOptim => 'Optimisation Fiscale';

  @override
  String get onboardingGoalTaxOptimDesc => 'Réduire mes impôts légalement';

  @override
  String get onboardingStep3Title => 'Presque là.';

  @override
  String get onboardingStep3Subtitle =>
      'Ces détails nous permettent de personnaliser vos calculs selon la loi suisse.';

  @override
  String get onboardingCantonLabel => 'Canton de résidence';

  @override
  String get onboardingCantonHint => 'Sélectionnez votre canton';

  @override
  String get onboardingBirthYearLabel => 'Année de naissance (optionnel)';

  @override
  String get onboardingBirthYearHint => 'Ex: 1990';

  @override
  String get onboardingContinue => 'Continuer';

  @override
  String get onboardingStep4Title => 'Prêt à commencer ?';

  @override
  String get onboardingStep4Subtitle =>
      'Mint est un environnement sûr. Voici nos engagements envers vous.';

  @override
  String get onboardingTrustTransparency => 'Transparence totale';

  @override
  String get onboardingTrustTransparencyDesc =>
      'Toutes les hypothèses sont visibles.';

  @override
  String get onboardingTrustPrivacy => 'Vie privée';

  @override
  String get onboardingTrustPrivacyDesc =>
      'Calculs locaux, pas de stockage de données sensibles.';

  @override
  String get onboardingTrustSecurity => 'Sécurité';

  @override
  String get onboardingTrustSecurityDesc =>
      'Aucun accès direct à votre argent.';

  @override
  String get onboardingEnterSpace => 'Entrer dans mon espace';

  @override
  String get advisorMiniStep1Title => 'Quelle est ta priorité ?';

  @override
  String get advisorMiniStep1Subtitle =>
      'MINT s\'adapte à ce qui compte pour toi maintenant';

  @override
  String get advisorMiniFirstNameLabel => 'Prénom (optionnel)';

  @override
  String get advisorMiniFirstNameHint => 'Prénom';

  @override
  String get advisorMiniStressBudget => 'Maîtriser mon budget';

  @override
  String get advisorMiniStressDebt => 'Réduire mes dettes';

  @override
  String get advisorMiniStressTax => 'Optimiser mes impôts';

  @override
  String get advisorMiniStressRetirement => 'Sécuriser ma retraite';

  @override
  String advisorMiniResumeDiagnostic(String progress) {
    return 'Reprendre mon diagnostic ($progress%)';
  }

  @override
  String get advisorMiniFullDiagnostic => 'Diagnostic complet (10 min)';

  @override
  String get advisorMiniStep2Title => 'L\'essentiel';

  @override
  String get advisorMiniStep2Subtitle =>
      'Âge et canton changent tout en Suisse';

  @override
  String get advisorMiniBirthYearLabel => 'Année de naissance';

  @override
  String get advisorMiniBirthYearInvalid => 'Année invalide';

  @override
  String advisorMiniBirthYearRange(String maxYear) {
    return 'Entre 1940 et $maxYear';
  }

  @override
  String get advisorMiniCantonLabel => 'Canton de résidence';

  @override
  String get advisorMiniCantonHint => 'Sélectionner';

  @override
  String get advisorMiniStep3Title => 'Ton revenu';

  @override
  String get advisorMiniStep3Subtitle =>
      'Pour calculer ton potentiel d\'économie';

  @override
  String get advisorMiniIncomeLabel => 'Revenu net mensuel (CHF)';

  @override
  String get advisorMiniHousingTitle => 'Logement';

  @override
  String get advisorMiniHousingTenant => 'Locataire';

  @override
  String get advisorMiniHousingOwner => 'Propriétaire';

  @override
  String get advisorMiniHousingHosted => 'Hébergé·e / sans loyer';

  @override
  String get advisorMiniHousingCostTenant => 'Loyer / charges logement / mois';

  @override
  String get advisorMiniHousingCostOwner =>
      'Charges logement / hypothèque / mois';

  @override
  String get advisorMiniDebtPaymentsLabel =>
      'Remboursements dettes / leasing / mois';

  @override
  String get advisorMiniPatrimonyTitle => 'Patrimoine (optionnel)';

  @override
  String get advisorMiniCashSavingsLabel => 'Liquidités / épargne disponible';

  @override
  String get advisorMiniInvestmentsTotalLabel =>
      'Placements (titres, ETF, fonds)';

  @override
  String get advisorMiniPillar3aTotalLabel => 'Total 3a approximatif';

  @override
  String get advisorMiniCivilStatusLabel => 'État civil du couple';

  @override
  String get advisorMiniCivilStatusMarried => 'Marié·e';

  @override
  String get advisorMiniCivilStatusConcubinage => 'En concubinage';

  @override
  String get advisorMiniPartnerIncomeLabel =>
      'Revenu net mensuel du/de la partenaire';

  @override
  String get advisorMiniPartnerBirthYearLabel =>
      'Année de naissance du/de la partenaire';

  @override
  String get advisorMiniPartnerFirstNameLabel =>
      'Prénom du/de la partenaire (optionnel)';

  @override
  String get advisorMiniPartnerFirstNameHint => 'Prénom';

  @override
  String get advisorMiniPartnerStatusHint => 'Partenaire';

  @override
  String get advisorMiniPartnerStatusInactive => 'Sans activité';

  @override
  String get advisorMiniPartnerRequiredTitle => 'Infos partenaire requises';

  @override
  String get advisorMiniPartnerRequiredBody =>
      'Ajoute l\'état civil, le revenu, l\'année de naissance et le statut du partenaire pour une projection foyer fiable.';

  @override
  String get advisorMiniPartnerProfileTitle => 'Profil du/de la partenaire';

  @override
  String get advisorReadinessLabel => 'Complétude du profil';

  @override
  String get advisorReadinessLevel => 'Niveau';

  @override
  String get advisorReadinessSufficient =>
      'Socle suffisant pour un plan initial.';

  @override
  String get advisorReadinessToComplete => 'À compléter';

  @override
  String get advisorMiniCoachIntroTitle => 'Ton coach MINT';

  @override
  String get advisorMiniCoachIntroControl =>
      'Tu as maintenant un plan concret. On avance en 3 priorités sur 7 jours, puis on ajuste avec ton coach.';

  @override
  String get advisorMiniWelcomeTitle => 'Bienvenue !';

  @override
  String get advisorMiniWelcomeBody =>
      'Ton espace financier est prêt. Découvre ce que ton coach a préparé.';

  @override
  String get advisorMiniCoachIntroWarmth =>
      'On y va ensemble. Chaque semaine, je t\'aide à avancer sur un point concret.';

  @override
  String get advisorMiniCoachPriorityBaseline =>
      'Confirmer ton score et ta trajectoire de départ';

  @override
  String get advisorMiniCoachPriorityCouple =>
      'Aligner la stratégie du foyer pour éviter les angles morts de couple';

  @override
  String get advisorMiniCoachPrioritySingleParent =>
      'Prioriser la protection du foyer et le matelas de sécurité';

  @override
  String get advisorMiniCoachPriorityBudget =>
      'Stabiliser ton budget et tes charges fixes en premier';

  @override
  String get advisorMiniCoachPriorityTax =>
      'Identifier les optimisations fiscales prioritaires';

  @override
  String get advisorMiniCoachPriorityRetirement =>
      'Renforcer ta trajectoire retraite avec des actions concrètes';

  @override
  String get advisorMiniCoachPriorityRealEstate =>
      'Vérifier la soutenabilité de ton projet immobilier';

  @override
  String get advisorMiniCoachPriorityDebtFree =>
      'Accélérer ton désendettement sans casser ta liquidité';

  @override
  String get advisorMiniCoachPriorityWealth =>
      'Construire un plan d\'accumulation de patrimoine robuste';

  @override
  String get advisorMiniCoachPriorityPension =>
      'Optimiser 3a/LPP et le niveau de revenu à la retraite';

  @override
  String get advisorMiniQuickPickLabel => 'Choix rapide';

  @override
  String get advisorMiniQuickPickIncomeLabel => 'Montants fréquents';

  @override
  String get advisorMiniFixedCostsTitle => 'Charges fixes (optionnel)';

  @override
  String get advisorMiniFixedCostsHint =>
      'Inclure: internet/mobile, assurances ménage/RC/auto, transport, abonnements et frais récurrents.';

  @override
  String get advisorMiniFixedCostsSubtitle =>
      'Ajoute impôts, LAMal et autres fixes pour un budget réaliste dès le dashboard.';

  @override
  String get advisorMiniPrefillEstimates => 'Préremplir estimations';

  @override
  String get advisorMiniPrefillHint =>
      'Estimé selon ton canton — ajuste si différent.';

  @override
  String advisorMiniPrefillTaxCouple(String canton) {
    return 'Pré-rempli d\'après ton revenu ci-dessus (canton $canton, couple)';
  }

  @override
  String advisorMiniPrefillTaxSingle(String canton) {
    return 'Pré-rempli d\'après ton revenu ci-dessus (canton $canton)';
  }

  @override
  String advisorMiniPrefillLamalFamily(String adults, String children) {
    return 'LAMal estimée pour $adults adulte(s) + $children enfant(s)';
  }

  @override
  String advisorMiniPrefillLamalCouple(String adults) {
    return 'LAMal estimée pour $adults adultes';
  }

  @override
  String get advisorMiniPrefillLamalSingle => 'LAMal estimée pour 1 adulte';

  @override
  String get advisorMiniPrefillAdjust => 'Ajuste si différent.';

  @override
  String get advisorMiniTaxProvisionLabel => 'Provision impôts / mois';

  @override
  String get advisorMiniLamalLabel => 'Primes LAMal / mois';

  @override
  String get advisorMiniOtherFixedLabel => 'Autres charges fixes / mois';

  @override
  String get advisorMiniStep2AhaTitle => 'Ton canton en bref';

  @override
  String advisorMiniStep2AhaHorizon(String years) {
    return 'Horizon retraite : ~$years ans';
  }

  @override
  String advisorMiniStep2AhaTaxQualitative(String canton, String pressure) {
    return 'Fiscalité en $canton : $pressure par rapport à la moyenne suisse';
  }

  @override
  String get advisorMiniStep2AhaPressureLow => 'faible';

  @override
  String get advisorMiniStep2AhaPressureMedium => 'modérée';

  @override
  String get advisorMiniStep2AhaPressureHigh => 'élevée';

  @override
  String get advisorMiniStep2AhaPressureVeryHigh => 'très élevée';

  @override
  String get advisorMiniStep2AhaPressureLabel => 'Pression fiscale';

  @override
  String get advisorMiniStep2AhaQualitativeHint =>
      'On affinera avec ton revenu à l\'étape suivante.';

  @override
  String get advisorMiniStep2AhaDisclaimer =>
      'Ordre de grandeur éducatif, basé sur données cantonales de référence MINT.';

  @override
  String get advisorMiniProjectionDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil financier (LAVS/LPP).';

  @override
  String get advisorMiniExitTitle => 'Tu quittes maintenant ?';

  @override
  String get advisorMiniExitBodyControl =>
      'Ta progression est sauvegardée. Tu peux reprendre plus tard.';

  @override
  String get advisorMiniExitBodyChallenge =>
      'Encore quelques secondes et tu obtiens ta trajectoire personnalisée.';

  @override
  String get advisorMiniExitStay => 'Continuer';

  @override
  String get advisorMiniExitLeave => 'Quitter';

  @override
  String get advisorMiniMetricsTitle => 'Métriques onboarding';

  @override
  String get advisorMiniMetricsSubtitle =>
      'Pilotage local des variantes control/challenge';

  @override
  String get advisorMiniMetricsControl => 'Control';

  @override
  String get advisorMiniMetricsChallenge => 'Challenge';

  @override
  String get advisorMiniMetricsStarts => 'Starts';

  @override
  String get advisorMiniMetricsCompletionRate => 'Taux de completion';

  @override
  String get advisorMiniMetricsExitStayRate =>
      'Taux de stay apres prompt sortie';

  @override
  String get advisorMiniMetricsAhaToStep3 => 'Step2 A-ha -> Step3';

  @override
  String get advisorMiniMetricsQuickPicks => 'Quick picks';

  @override
  String get advisorMiniMetricsAvgStepTime => 'Temps moyen par étape';

  @override
  String get advisorMiniMetricsReset => 'Reset metrics';

  @override
  String advisorMiniEtaLabel(String seconds) {
    return 'Temps restant estimé : ${seconds}s';
  }

  @override
  String get advisorMiniEtaConfidenceHigh => 'Confiance haute';

  @override
  String get advisorMiniEtaConfidenceLow => 'Confiance moyenne';

  @override
  String get advisorMiniEmploymentLabel => 'Statut professionnel';

  @override
  String get advisorMiniHouseholdLabel => 'Ton foyer';

  @override
  String get advisorMiniHouseholdSubtitle =>
      'On ajuste impôts et charges fixes selon ta situation';

  @override
  String get advisorMiniReadyTitle => 'Validation';

  @override
  String get advisorMiniReadyLabel => 'Ce que MINT a compris';

  @override
  String get advisorMiniReadyStep1 =>
      'Priorité enregistrée. On personnalise la trajectoire.';

  @override
  String get advisorMiniReadyStep2 =>
      'Base fiscale prête. Le contexte cantonal est calibré.';

  @override
  String get advisorMiniReadyStep3 =>
      'Profil minimum prêt. Projection indicative disponible.';

  @override
  String advisorMiniReadyStress(String label) {
    return 'Priorité: $label';
  }

  @override
  String advisorMiniReadyProfile(String employment, String household) {
    return 'Profil: $employment · $household';
  }

  @override
  String advisorMiniReadyLocation(String canton, String horizon) {
    return 'Base fiscale: $canton · $horizon';
  }

  @override
  String advisorMiniReadyIncome(String income) {
    return 'Revenu net: CHF $income/mois';
  }

  @override
  String advisorMiniReadyFixed(String count) {
    return 'Charges fixes captées: $count/3';
  }

  @override
  String get advisorMiniEmploymentEmployee => 'Salarié·e';

  @override
  String get advisorMiniEmploymentSelfEmployed => 'Indépendant·e';

  @override
  String get advisorMiniEmploymentStudent => 'Étudiant·e / Apprenti·e';

  @override
  String get advisorMiniEmploymentUnemployed => 'Sans emploi';

  @override
  String get advisorMiniSeeProjection => 'Voir ma projection';

  @override
  String get advisorMiniPreferFullDiagnostic =>
      'Je préfère le diagnostic complet (10 min)';

  @override
  String advisorMiniQuickInsight(String low, String high, String horizon) {
    return 'Estimation rapide : une épargne régulière entre CHF $low et CHF $high/mois peut déjà changer ta trajectoire. $horizon';
  }

  @override
  String advisorMiniHorizon(String years) {
    return 'Horizon retraite : ~$years ans.';
  }

  @override
  String get advisorMiniStep4Title => 'Ton objectif';

  @override
  String get advisorMiniStep4Subtitle =>
      'MINT personnalise ton plan selon ta priorité principale';

  @override
  String get advisorMiniGoalRetirement => 'Préparer ma retraite';

  @override
  String get advisorMiniGoalRealEstate => 'Acheter un bien immobilier';

  @override
  String get advisorMiniGoalDebtFree => 'Réduire mes dettes';

  @override
  String get advisorMiniGoalIndependence =>
      'Construire mon indépendance financière';

  @override
  String get advisorMiniActivateDashboard => 'Activer mon dashboard';

  @override
  String get advisorMiniAdjustLater =>
      'Tu pourras tout ajuster ensuite depuis Dashboard et Agir.';

  @override
  String advisorMiniPreviewTitle(String goal) {
    return 'Preview trajectoire : $goal';
  }

  @override
  String advisorMiniPreviewSubtitle(String years) {
    return 'Projection indicative sur ~$years ans';
  }

  @override
  String get advisorMiniPreviewPrudent => 'Prudent';

  @override
  String get advisorMiniPreviewBase => 'Base';

  @override
  String get advisorMiniPreviewOptimistic => 'Optimiste';

  @override
  String get homeSafeModeActive => 'MODE PROTECTION ACTIVÉ';

  @override
  String get homeHide => 'Masquer';

  @override
  String get homeSafeModeMessage =>
      'Nous avons détecté des signaux de tension. Il pourrait être utile de stabiliser ton budget avant d\'explorer d\'autres options.';

  @override
  String get homeSafeModeResources => 'Ressources & Aides gratuites';

  @override
  String get homeMentorAdvisor => 'Mentor Advisor';

  @override
  String get homeMentorDescription =>
      'Lancez votre session personnalisée pour obtenir un diagnostic complet de votre situation financière.';

  @override
  String get homeStartSession => 'Démarrer ma session';

  @override
  String get homeSimulator3a => 'Retraite 3a';

  @override
  String get homeSimulatorGrowth => 'Croissance';

  @override
  String get homeSimulatorLeasing => 'Leasing';

  @override
  String get homeSimulatorCredit => 'Crédit Conso';

  @override
  String get homeReportV2Title => '🧪 NOUVEAU : Rapport V2 (Démo)';

  @override
  String get homeReportV2Subtitle =>
      'Score par cercle, comparateur 3a, stratégie LPP';

  @override
  String get profileTitle => 'MON PROFIL MENTOR';

  @override
  String get profilePrecisionIndex => 'Precision Index';

  @override
  String get profilePrecisionMessage =>
      'Plus votre profil est complet, plus votre rapport \"Statement of Advice\" est puissant.';

  @override
  String get profileFactFindTitle => 'Détails FactFind';

  @override
  String get profileSectionIdentity => 'Identité & Foyer';

  @override
  String get profileSectionIncome => 'Revenus & Épargne';

  @override
  String get profileSectionPension => 'Prévoyance (LPP)';

  @override
  String get profileSectionProperty => 'Immobilier & Dettes';

  @override
  String get profileStatusComplete => 'Complet';

  @override
  String get profileStatusPartial => 'Partial (Net)';

  @override
  String get profileStatusMissing => 'Manquant';

  @override
  String get profileReward15 => '+15% de précision';

  @override
  String get profileReward10 => '+10% de précision';

  @override
  String get profileSecurityTitle => 'Sécurité & Data';

  @override
  String get profileConsentControl => 'Contrôle des Partages';

  @override
  String get profileConsentManage => 'Gérer mes accès bLink';

  @override
  String get profileAccountTitle => 'Compte';

  @override
  String get profileUser => 'Utilisateur';

  @override
  String get profileDeleteData => 'Supprimer mes données locales';

  @override
  String get rentVsCapitalTitle => 'Rente vs Capital';

  @override
  String get rentVsCapitalDescription =>
      'Comparez la rente viagère et le retrait en capital de votre 2e pilier';

  @override
  String get rentVsCapitalSubtitle => 'Simulez votre 2e pilier • LPP';

  @override
  String get rentVsCapitalAvoirOblig => 'Avoir obligatoire';

  @override
  String get rentVsCapitalAvoirSurob => 'Avoir surobligatoire';

  @override
  String get rentVsCapitalTauxConversion => 'Taux de conversion surobligatoire';

  @override
  String get rentVsCapitalAgeRetraite => 'Âge de la retraite';

  @override
  String get rentVsCapitalCanton => 'Canton';

  @override
  String get rentVsCapitalStatutCivil => 'Statut civil';

  @override
  String get rentVsCapitalSingle => 'Seul';

  @override
  String get rentVsCapitalMarried => 'Marié';

  @override
  String get rentVsCapitalRenteViagere => 'Rente viagère';

  @override
  String get rentVsCapitalCapitalNet => 'Capital net';

  @override
  String get rentVsCapitalBreakEven => 'Break-even';

  @override
  String get rentVsCapitalCapitalA85 => 'Capital à 85 ans';

  @override
  String get rentVsCapitalJamais => 'Jamais';

  @override
  String get rentVsCapitalPrudent => 'Prudent (1%)';

  @override
  String get rentVsCapitalCentral => 'Central (3%)';

  @override
  String get rentVsCapitalOptimiste => 'Optimiste (5%)';

  @override
  String get rentVsCapitalTauxConversionExpl =>
      'Le taux de conversion détermine le montant de votre rente annuelle en fonction de votre avoir de vieillesse. Le taux légal minimum est de 6.8% pour la part obligatoire (LPP art. 14). Pour la part surobligatoire, chaque caisse de pension fixe son propre taux, généralement entre 3% et 6%.';

  @override
  String get rentVsCapitalChoixExpl =>
      'La rente offre un revenu régulier à vie, mais s\'arrête au décès (avec éventuellement une rente de survivant réduite). Le capital donne plus de flexibilité, mais comporte un risque d\'épuisement si les rendements sont faibles ou la longévité élevée.';

  @override
  String get rentVsCapitalDisclaimer =>
      'Les résultats présentés sont des estimations à titre indicatif. Ils ne constituent pas un conseil financier personnalisé. Consultez votre caisse de pension et un·e spécialiste qualifié·e avant toute décision.';

  @override
  String get disabilityGapTitle => 'Mon filet de sécurité';

  @override
  String get disabilityGapSubtitle =>
      'Que se passe-t-il si je ne peux plus travailler ?';

  @override
  String get disabilityGapRevenu => 'Revenu mensuel net';

  @override
  String get disabilityGapCanton => 'Canton';

  @override
  String get disabilityGapStatut => 'Statut professionnel';

  @override
  String get disabilityGapSalarie => 'Salarié';

  @override
  String get disabilityGapIndependant => 'Indépendant';

  @override
  String get disabilityGapAnciennete => 'Années d\'ancienneté';

  @override
  String get disabilityGapIjm => 'IJM collective via mon employeur';

  @override
  String get disabilityGapDegre => 'Degré d\'invalidité';

  @override
  String get disabilityGapPhase1 => 'Phase 1 — Employeur';

  @override
  String get disabilityGapPhase2 => 'Phase 2 — IJM';

  @override
  String get disabilityGapPhase3 => 'Phase 3 — AI + LPP';

  @override
  String get disabilityGapRevenuActuel => 'Revenu actuel';

  @override
  String get disabilityGapGapMensuel => 'Gap mensuel maximal';

  @override
  String get disabilityGapRiskCritical => 'Risque critique';

  @override
  String get disabilityGapRiskHigh => 'Risque élevé';

  @override
  String get disabilityGapRiskMedium => 'Risque modéré';

  @override
  String get disabilityGapRiskLow => 'Risque faible';

  @override
  String get disabilityGapDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil en assurance au sens de la LSFin. Tes couvertures réelles dépendent de ton contrat de travail et de ta caisse de pension.';

  @override
  String get disabilityGapIjmExpl =>
      'L\'IJM (indemnité journalière maladie) est une assurance qui couvre 80% de votre salaire pendant max. 720 jours en cas de maladie. L\'employeur n\'est pas obligé de la souscrire, mais beaucoup le font via une assurance collective. Sans IJM, après la période légale de maintien du salaire, vous ne recevez plus rien jusqu\'à l\'éventuelle rente AI.';

  @override
  String get disabilityGapCo324aExpl =>
      'Selon l\'art. 324a CO, l\'employeur doit verser le salaire pendant une durée limitée en cas de maladie. Cette durée dépend des années de service et de l\'échelle cantonale applicable (bernoise, zurichoise ou bâloise). Après cette période, seule l\'IJM (si existante) prend le relais.';

  @override
  String get authLogin => 'Se connecter';

  @override
  String get authRegister => 'Créer un compte';

  @override
  String get authEmail => 'Adresse e-mail';

  @override
  String get authPassword => 'Mot de passe';

  @override
  String get authConfirmPassword => 'Confirmer le mot de passe';

  @override
  String get authDisplayName => 'Nom d\'affichage (optionnel)';

  @override
  String get authCreateAccount => 'Créer mon compte';

  @override
  String get authAlreadyAccount => 'Déjà inscrit ?';

  @override
  String get authNoAccount => 'Pas encore de compte ?';

  @override
  String get authLogout => 'Se déconnecter';

  @override
  String get authLoginTitle => 'Connexion';

  @override
  String get authRegisterTitle => 'Créer ton compte';

  @override
  String get authPasswordHint => 'Minimum 8 caractères';

  @override
  String get authError => 'Erreur de connexion';

  @override
  String get authEmailInvalid => 'Adresse e-mail invalide';

  @override
  String get authPasswordTooShort =>
      'Le mot de passe doit contenir au moins 8 caractères';

  @override
  String get authPasswordMismatch => 'Les mots de passe ne correspondent pas';

  @override
  String get authForgotTitle => 'Réinitialiser le mot de passe';

  @override
  String get authForgotSteps =>
      '1) Demande un lien  2) Colle le token  3) Choisis un nouveau mot de passe';

  @override
  String get authForgotSendLink => 'Envoyer le lien de réinitialisation';

  @override
  String get authForgotResetTokenLabel => 'Token de réinitialisation';

  @override
  String get authForgotNewPasswordLabel => 'Nouveau mot de passe';

  @override
  String get authForgotSubmitNewPassword => 'Valider le nouveau mot de passe';

  @override
  String get authForgotRequestAccepted =>
      'Si un compte existe, un lien de réinitialisation a été envoyé.';

  @override
  String get authForgotResetSuccess => 'Mot de passe mis à jour. Connecte-toi.';

  @override
  String get authVerifyTitle => 'Vérifier mon e-mail';

  @override
  String get authVerifyInstructions =>
      'Demande un nouveau lien puis colle le token de vérification.';

  @override
  String get authVerifySendLink => 'Envoyer le lien de vérification';

  @override
  String get authVerifyTokenLabel => 'Token de vérification';

  @override
  String get authVerifySubmit => 'Valider la vérification';

  @override
  String get authVerifyRequestAccepted =>
      'Lien de vérification envoyé (si compte existant).';

  @override
  String get authVerifySuccess => 'E-mail vérifié. Tu peux te connecter.';

  @override
  String get authTokenRequired => 'Token requis.';

  @override
  String get authEmailInvalidPrompt => 'Entre une adresse e-mail valide.';

  @override
  String get authDebugTokenLabel => 'Token debug (tests)';

  @override
  String get adminObsTitle => 'Admin Observability';

  @override
  String get adminObsExportCsv => 'Exporter CSV cohortes';

  @override
  String get adminObsCsvCopied => 'CSV cohortes copié dans le presse-papiers';

  @override
  String get adminObsExportFailed => 'Export impossible';

  @override
  String get adminObsWindowLabel => 'Fenêtre';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonDays => 'jours';

  @override
  String get analyticsConsentTitle => 'Statistiques anonymes';

  @override
  String get analyticsConsentMessage =>
      'MINT utilise des statistiques anonymes pour améliorer l\'expérience. Aucune donnée personnelle n\'est collectée.';

  @override
  String get analyticsAccept => 'Accepter';

  @override
  String get analyticsRefuse => 'Refuser';

  @override
  String get askMintTitle => 'Ask MINT';

  @override
  String get askMintSubtitle => 'Pose tes questions sur la finance suisse';

  @override
  String get askMintConfigureTitle => 'Configure ton IA';

  @override
  String get askMintConfigureBody =>
      'Pour poser des questions sur la finance suisse, connecte ta propre clé API (Claude, OpenAI ou Mistral). Ta clé est chiffrée localement et jamais stockée sur nos serveurs.';

  @override
  String get askMintConfigureButton => 'Configurer ma clé API';

  @override
  String get askMintEmptyTitle => 'Pose-moi une question';

  @override
  String get askMintEmptySubtitle =>
      'Je peux t\'aider sur la finance suisse : 3e pilier, LPP, impôts, budget...';

  @override
  String get askMintSuggestedTitle => 'SUGGESTIONS';

  @override
  String get askMintSuggestion1 =>
      'Comment fonctionne le 3e pilier en Suisse ?';

  @override
  String get askMintSuggestion2 =>
      'Dois-je choisir la rente ou le capital LPP ?';

  @override
  String get askMintSuggestion3 => 'Comment optimiser mes impôts ?';

  @override
  String get askMintSuggestion4 => 'Qu\'est-ce que le rachat LPP ?';

  @override
  String get askMintInputHint => 'Pose ta question sur la finance suisse...';

  @override
  String get askMintSourcesTitle => 'Sources';

  @override
  String get askMintErrorInvalidKey =>
      'Ta clé API semble invalide ou expirée. Vérifie-la dans les paramètres.';

  @override
  String get askMintErrorRateLimit =>
      'Limite de requêtes atteinte. Attends quelques instants avant de réessayer.';

  @override
  String get askMintErrorGeneric =>
      'Une erreur est survenue. Vérifie ta connexion et réessaie.';

  @override
  String get askMintDisclaimer =>
      'Les réponses sont générées par IA et ne constituent pas un conseil financier personnalisé.';

  @override
  String get byokTitle => 'Intelligence artificielle';

  @override
  String get byokSubtitle =>
      'Connecte ton propre LLM pour des réponses personnalisées';

  @override
  String get byokProviderLabel => 'Fournisseur';

  @override
  String get byokApiKeyLabel => 'Clé API';

  @override
  String get byokTestButton => 'Tester la clé';

  @override
  String get byokTesting => 'Test en cours...';

  @override
  String get byokSaveButton => 'Sauvegarder';

  @override
  String get byokSaved => 'Clé sauvegardée avec succès';

  @override
  String get byokTestSuccess => 'Connexion réussie ! Ton IA est prête.';

  @override
  String get byokPrivacyTitle => 'Ta clé, tes données';

  @override
  String get byokPrivacyBody =>
      'Ta clé API est stockée de manière chiffrée sur ton appareil. Elle est transmise de façon sécurisée (HTTPS) à notre serveur pour communiquer avec le fournisseur IA, puis immédiatement supprimée — jamais stockée côté serveur.';

  @override
  String get byokPrivacyShort =>
      'Clé chiffrée localement, jamais stockée sur nos serveurs';

  @override
  String get byokClearButton => 'Supprimer la clé sauvegardée';

  @override
  String get byokClearTitle => 'Supprimer la clé ?';

  @override
  String get byokClearMessage =>
      'Cela supprimera ta clé API stockée localement. Tu pourras en configurer une nouvelle à tout moment.';

  @override
  String get byokClearCancel => 'Annuler';

  @override
  String get byokClearConfirm => 'Supprimer';

  @override
  String get byokLearnTitle => 'À propos du BYOK';

  @override
  String get byokLearnHeading =>
      'Qu\'est-ce que le BYOK (Bring Your Own Key) ?';

  @override
  String get byokLearnBody =>
      'Le BYOK te permet d\'utiliser ta propre clé API d\'un fournisseur d\'IA (Claude, OpenAI, Mistral) pour obtenir des réponses personnalisées sur la finance suisse.\n\nAvantages :\n• Contrôle total sur tes données\n• Aucun coût caché côté MINT\n• Tu paies uniquement ce que tu consommes\n• Clé stockée de manière chiffrée sur ton appareil';

  @override
  String get profileAiTitle => 'Intelligence Artificielle';

  @override
  String get profileAiByok => 'Ask MINT (BYOK)';

  @override
  String get profileAiConfigured => 'Configuré';

  @override
  String get profileAiNotConfigured => 'Non configuré';

  @override
  String get documentsTitle => 'Mes documents';

  @override
  String get documentsSubtitle =>
      'Upload et analyse de tes documents financiers';

  @override
  String get documentsUploadTitle => 'Upload ton certificat LPP';

  @override
  String get documentsUploadBody =>
      'MINT extrait automatiquement tes données de prévoyance professionnelle';

  @override
  String get documentsUploadButton => 'Choisir un fichier PDF';

  @override
  String get documentsAnalyzing => 'Analyse en cours...';

  @override
  String documentsConfidence(String confidence) {
    return 'Confiance : $confidence%';
  }

  @override
  String documentsFieldsFound(String found, String total) {
    return '$found champs extraits sur $total';
  }

  @override
  String get documentsConfirmButton => 'Confirmer et mettre à jour mon profil';

  @override
  String get documentsDeleteButton => 'Supprimer ce document';

  @override
  String get documentsDeleteTitle => 'Supprimer le document ?';

  @override
  String get documentsDeleteMessage => 'Cette action est irréversible.';

  @override
  String get documentsPrivacy =>
      'Tes documents sont analysés localement et ne sont jamais partagés avec des tiers. Tu peux les supprimer à tout moment.';

  @override
  String get documentsEmpty => 'Aucun document';

  @override
  String get documentsLppCertificate => 'Certificat LPP';

  @override
  String get documentsUnknown => 'Document inconnu';

  @override
  String get documentsCategoryEpargne => 'Épargne';

  @override
  String get documentsCategorySalaire => 'Salaire';

  @override
  String get documentsCategoryTaux => 'Taux de conversion';

  @override
  String get documentsCategoryRisque => 'Couverture risque';

  @override
  String get documentsCategoryRachat => 'Rachat';

  @override
  String get documentsCategoryCotisations => 'Cotisations';

  @override
  String get documentsFieldAvoirObligatoire =>
      'Avoir de vieillesse obligatoire';

  @override
  String get documentsFieldAvoirSurobligatoire =>
      'Avoir de vieillesse surobligatoire';

  @override
  String get documentsFieldAvoirTotal => 'Avoir de vieillesse total';

  @override
  String get documentsFieldSalaireAssure => 'Salaire assuré';

  @override
  String get documentsFieldSalaireAvs => 'Salaire AVS';

  @override
  String get documentsFieldDeductionCoordination => 'Déduction de coordination';

  @override
  String get documentsFieldTauxObligatoire => 'Taux de conversion obligatoire';

  @override
  String get documentsFieldTauxSurobligatoire =>
      'Taux de conversion surobligatoire';

  @override
  String get documentsFieldTauxEnveloppe => 'Taux de conversion enveloppe';

  @override
  String get documentsFieldRenteInvalidite => 'Rente d\'invalidité annuelle';

  @override
  String get documentsFieldCapitalDeces => 'Capital-décès';

  @override
  String get documentsFieldRenteConjoint => 'Rente de conjoint annuelle';

  @override
  String get documentsFieldRenteEnfant => 'Rente d\'enfant annuelle';

  @override
  String get documentsFieldRachatMax => 'Rachat maximum possible';

  @override
  String get documentsFieldCotisationEmploye => 'Cotisation employé annuelle';

  @override
  String get documentsFieldCotisationEmployeur =>
      'Cotisation employeur annuelle';

  @override
  String get documentsWarningsTitle => 'Points d\'attention';

  @override
  String get profileDocuments => 'Mes documents';

  @override
  String profileDocumentsCount(String count) {
    return '$count document(s)';
  }

  @override
  String get bankImportTitle => 'Importer mes relevés';

  @override
  String get bankImportSubtitle => 'Analyse automatique de tes transactions';

  @override
  String get bankImportUploadTitle => 'Importe ton relevé bancaire';

  @override
  String get bankImportUploadBody =>
      'CSV ou PDF — UBS, PostFinance, Raiffeisen, ZKB et autres banques suisses';

  @override
  String get bankImportUploadButton => 'Choisir un fichier';

  @override
  String get bankImportAnalyzing => 'Analyse des transactions...';

  @override
  String bankImportBankDetected(String bank) {
    return '$bank détecté';
  }

  @override
  String bankImportPeriod(String start, String end) {
    return 'Période : $start - $end';
  }

  @override
  String bankImportTransactionCount(String count) {
    return '$count transactions';
  }

  @override
  String get bankImportIncome => 'Revenus';

  @override
  String get bankImportExpenses => 'Dépenses';

  @override
  String get bankImportCategories => 'Répartition par catégorie';

  @override
  String get bankImportRecurring => 'Charges récurrentes détectées';

  @override
  String bankImportPerMonth(String amount) {
    return '$amount/mois';
  }

  @override
  String get bankImportBudgetPreview => 'Ton budget estimé';

  @override
  String get bankImportMonthlyIncome => 'Revenu mensuel';

  @override
  String get bankImportFixedCharges => 'Charges fixes';

  @override
  String get bankImportVariable => 'Dépenses variables';

  @override
  String get bankImportSavingsRate => 'Taux d\'épargne';

  @override
  String get bankImportButton => 'Importer dans mon budget';

  @override
  String get bankImportPrivacy =>
      'Tes relevés sont analysés localement. Les transactions ne sont jamais stockées sur nos serveurs.';

  @override
  String get bankImportSuccess => 'Budget mis à jour avec succès';

  @override
  String get bankImportCategoryLogement => 'Logement';

  @override
  String get bankImportCategoryAlimentation => 'Alimentation';

  @override
  String get bankImportCategoryTransport => 'Transport';

  @override
  String get bankImportCategoryAssurance => 'Assurance';

  @override
  String get bankImportCategoryTelecom => 'Télécom';

  @override
  String get bankImportCategoryImpots => 'Impôts';

  @override
  String get bankImportCategorySante => 'Santé';

  @override
  String get bankImportCategoryLoisirs => 'Loisirs';

  @override
  String get bankImportCategoryEpargne => 'Épargne';

  @override
  String get bankImportCategorySalaire => 'Salaire';

  @override
  String get bankImportCategoryRestaurant => 'Restaurant';

  @override
  String get bankImportCategoryDivers => 'Divers';

  @override
  String get jobCompareTitle => 'Comparer deux emplois';

  @override
  String get jobCompareSubtitle => 'Découvre le salaire invisible';

  @override
  String get jobCompareIntro =>
      'Le salaire brut ne dit pas tout. Compare le salaire invisible (prévoyance, assurances) entre deux postes.';

  @override
  String get jobCompareCurrentJob => 'EMPLOI ACTUEL';

  @override
  String get jobCompareNewJob => 'EMPLOI ENVISAGÉ';

  @override
  String get jobCompareSalaireBrut => 'Salaire brut annuel';

  @override
  String get jobCompareAge => 'Ton âge';

  @override
  String get jobComparePartEmployeur => 'Part employeur LPP';

  @override
  String get jobCompareTauxConversion => 'Taux de conversion';

  @override
  String get jobCompareAvoirVieillesse => 'Avoir de vieillesse actuel';

  @override
  String get jobCompareCouvertureInvalidite => 'Couverture invalidité';

  @override
  String get jobCompareCapitalDeces => 'Capital-décès';

  @override
  String get jobCompareRachatMax => 'Rachat maximum';

  @override
  String get jobCompareIjm => 'IJM collective incluse';

  @override
  String get jobCompareButton => 'Comparer';

  @override
  String get jobCompareResults => 'Résultats';

  @override
  String get jobCompareAxis => 'Axe';

  @override
  String get jobCompareActuel => 'Actuel';

  @override
  String get jobCompareNouveau => 'Nouveau';

  @override
  String get jobCompareDelta => 'Différence';

  @override
  String get jobCompareSalaireNet => 'Salaire net';

  @override
  String get jobCompareCotisLpp => 'Cotis. LPP';

  @override
  String get jobCompareCapitalRetraite => 'Capital retraite';

  @override
  String get jobCompareRenteMois => 'Rente/mois';

  @override
  String get jobCompareCouvertureDeces => 'Couverture décès';

  @override
  String get jobCompareInvalidite => 'Couverture invalidité';

  @override
  String get jobCompareRachat => 'Rachat max';

  @override
  String get jobCompareLifetimeImpact => 'Impact sur toute la retraite';

  @override
  String get jobCompareAlerts => 'Points d\'attention';

  @override
  String get jobCompareChecklist => 'Avant de signer';

  @override
  String get jobCompareChecklistReglement =>
      'Demander le règlement de la caisse de pension';

  @override
  String get jobCompareChecklistTaux =>
      'Vérifier le taux de conversion surobligatoire';

  @override
  String get jobCompareChecklistPart => 'Comparer la part employeur';

  @override
  String get jobCompareChecklistCoordination =>
      'Vérifier la déduction de coordination';

  @override
  String get jobCompareChecklistIjm => 'Demander si IJM collective incluse';

  @override
  String get jobCompareChecklistRachat =>
      'Vérifier le délai de carence pour le rachat';

  @override
  String get jobCompareChecklistRisque =>
      'Calculer l\'impact sur les prestations de risque';

  @override
  String get jobCompareChecklistLibrePassage =>
      'Vérifier le libre passage : transfert en 30 jours max';

  @override
  String get jobCompareEducational =>
      'Le salaire invisible représente 10-30% de ta rémunération totale.';

  @override
  String get jobCompareVerdictBetter =>
      'Le nouveau poste est globalement plus avantageux';

  @override
  String get jobCompareVerdictWorse =>
      'Le poste actuel offre une protection plus solide';

  @override
  String get jobCompareVerdictComparable => 'Les deux postes sont comparables';

  @override
  String get jobCompareDetailedComparison => 'Comparaison détaillée';

  @override
  String get jobCompareDetailedSubtitle => '7 axes de prévoyance';

  @override
  String get jobCompareReduce => 'Réduire';

  @override
  String get jobCompareShowDetails => 'Voir les détails';

  @override
  String get jobCompareChecklistSubtitle => 'Checklist de vérification';

  @override
  String get jobCompareLifetimeTitle => 'Impact sur toute la retraite';

  @override
  String get jobCompareDisclaimer =>
      'Les résultats présentés sont des estimations à titre indicatif. Ils ne constituent pas un conseil financier personnalisé. Consulte ta caisse de pension et un·e spécialiste qualifié·e avant toute décision.';

  @override
  String get divorceTitle => 'Impact financier d\'un divorce';

  @override
  String get divorceSubtitle => 'Anticipez les conséquences financières';

  @override
  String get divorceIntro =>
      'Un divorce a des conséquences financières souvent sous-estimées : partage du patrimoine, de la prévoyance (LPP/3a), impact fiscal et pension alimentaire.';

  @override
  String get divorceSituationFamiliale => 'SITUATION FAMILIALE';

  @override
  String get divorceSituationSubtitle => 'Durée du mariage, enfants, régime';

  @override
  String get divorceDureeMariage => 'Durée du mariage';

  @override
  String get divorceNombreEnfants => 'Nombre d\'enfants';

  @override
  String get divorceRegimeMatrimonial => 'Régime matrimonial';

  @override
  String get divorceRegimeAcquets => 'Participation aux acquêts (défaut)';

  @override
  String get divorceRegimeCommunaute => 'Communauté de biens';

  @override
  String get divorceRegimeSeparation => 'Séparation de biens';

  @override
  String get divorceRevenus => 'REVENUS';

  @override
  String get divorceRevenusSubtitle => 'Revenu annuel de chaque conjoint';

  @override
  String get divorceConjoint1Revenu => 'Conjoint 1 — revenu annuel';

  @override
  String get divorceConjoint2Revenu => 'Conjoint 2 — revenu annuel';

  @override
  String get divorcePrevoyance => 'PRÉVOYANCE';

  @override
  String get divorcePrevoyanceSubtitle =>
      'LPP et 3a accumulés pendant le mariage';

  @override
  String get divorceLppConjoint1 => 'LPP Conjoint 1 (pendant le mariage)';

  @override
  String get divorceLppConjoint2 => 'LPP Conjoint 2 (pendant le mariage)';

  @override
  String get divorce3aConjoint1 => '3a Conjoint 1';

  @override
  String get divorce3aConjoint2 => '3a Conjoint 2';

  @override
  String get divorcePatrimoine => 'PATRIMOINE';

  @override
  String get divorcePatrimoineSubtitle => 'Fortune et dettes communes';

  @override
  String get divorceFortuneCommune => 'Fortune commune';

  @override
  String get divorceDettesCommunes => 'Dettes communes';

  @override
  String get divorceSimuler => 'Simuler';

  @override
  String get divorcePartageLpp => 'PARTAGE LPP';

  @override
  String get divorceTotalLpp => 'Total LPP (pendant le mariage)';

  @override
  String get divorcePartConjoint1 => 'Part Conjoint 1';

  @override
  String get divorcePartConjoint2 => 'Part Conjoint 2';

  @override
  String get divorceTransfert => 'Transfert';

  @override
  String get divorceImpactFiscal => 'IMPACT FISCAL';

  @override
  String get divorceImpotMarie => 'Impôt estimé (marié)';

  @override
  String get divorceImpotConjoint1 => 'Impôt Conjoint 1 (individuel)';

  @override
  String get divorceImpotConjoint2 => 'Impôt Conjoint 2 (individuel)';

  @override
  String get divorceTotalApresDivorce => 'Total après divorce';

  @override
  String get divorceDifference => 'Différence';

  @override
  String get divorcePartagePatrimoine => 'PARTAGE DU PATRIMOINE';

  @override
  String get divorceFortuneNette => 'Fortune nette';

  @override
  String get divorcePensionAlimentaire => 'PENSION ALIMENTAIRE (ESTIMATION)';

  @override
  String get divorcePensionAlimentaireNote =>
      'Estimation basée sur l\'écart de revenus et le nombre d\'enfants. Le montant réel dépend de nombreux facteurs.';

  @override
  String get divorcePointsAttention => 'POINTS D\'ATTENTION';

  @override
  String get divorceActions => 'Actions à entreprendre';

  @override
  String get divorceActionsSubtitle => 'Checklist de préparation';

  @override
  String get divorceEduAcquets =>
      'Qu\'est-ce que la participation aux acquêts ?';

  @override
  String get divorceEduAcquetsBody =>
      'La participation aux acquêts est le régime matrimonial par défaut en Suisse (CC art. 181 ss). Les acquêts sont partagés à parts égales en cas de divorce.';

  @override
  String get divorceEduLpp => 'Comment fonctionne le partage LPP ?';

  @override
  String get divorceEduLppBody =>
      'Les avoirs LPP accumulés pendant le mariage sont partagés à parts égales (CC art. 122).';

  @override
  String get divorceDisclaimer =>
      'Les résultats présentés sont des estimations à titre indicatif et ne constituent pas un conseil juridique ou financier personnalisé. Chaque situation est unique. Consultez un(e) avocat(e) spécialisé(e) en droit de la famille et un·e spécialiste en finances avant toute décision.';

  @override
  String get successionTitle => 'Succession et transmission';

  @override
  String get successionSubtitle => 'Nouveau droit successoral 2023';

  @override
  String get successionIntro =>
      'Le nouveau droit successoral (2023) a élargi la quotité disponible. Vous avez désormais plus de liberté pour avantager certains héritiers.';

  @override
  String get successionSituationPersonnelle => 'Situation personnelle';

  @override
  String get successionSituationSubtitle => 'Statut civil, héritiers';

  @override
  String get successionStatutCivil => 'Statut civil';

  @override
  String get successionCivilMarie => 'Marié·e';

  @override
  String get successionCivilCelibataire => 'Célibataire';

  @override
  String get successionCivilDivorce => 'Divorcé·e';

  @override
  String get successionCivilVeuf => 'Veuf/Veuve';

  @override
  String get successionCivilConcubinage => 'Concubinage';

  @override
  String get successionNombreEnfants => 'Nombre d\'enfants';

  @override
  String get successionParentsVivants => 'Parents vivants';

  @override
  String get successionFratrie => 'Fratrie (frères/sœurs)';

  @override
  String get successionConcubin => 'Concubin(e)';

  @override
  String get successionFortune => 'Fortune';

  @override
  String get successionFortuneSubtitle => 'Patrimoine total, 3a, LPP';

  @override
  String get successionFortuneTotale => 'Fortune totale';

  @override
  String get successionAvoirs3a => 'Avoirs 3a';

  @override
  String get successionCapitalDecesLpp => 'Capital décès LPP';

  @override
  String get successionCanton => 'Canton';

  @override
  String get successionTestament => 'Testament';

  @override
  String get successionTestamentSubtitle => 'CC art. 498–504';

  @override
  String get successionHasTestament => 'J\'ai un testament';

  @override
  String get successionQuotiteBeneficiaire =>
      'Qui reçoit la quotité disponible ?';

  @override
  String get successionBeneficiaireConjoint => 'Conjoint(e)';

  @override
  String get successionBeneficiaireEnfants => 'Enfants';

  @override
  String get successionBeneficiaireConcubin => 'Concubin(e)';

  @override
  String get successionBeneficiaireTiers => 'Tiers / Œuvre';

  @override
  String get successionSimuler => 'Simuler';

  @override
  String get successionRepartitionLegale => 'Répartition légale';

  @override
  String get successionRepartitionTestament => 'Répartition avec testament';

  @override
  String get successionReservesHereditaires => 'Réserves héréditaires (2023)';

  @override
  String get successionReservesNote =>
      'Montants protégés par la loi (intouchables)';

  @override
  String get successionQuotiteDisponible => 'Quotité disponible';

  @override
  String get successionQuotiteNote =>
      'Ce montant peut être librement attribué par testament.';

  @override
  String get successionFiscalite => 'Fiscalité successorale';

  @override
  String get successionExonere => 'Exonéré';

  @override
  String get successionTotalImpot => 'Total impôt successoral';

  @override
  String get succession3aOpp3 => 'Bénéficiaires 3a (OPP3 art. 2)';

  @override
  String get succession3aNote =>
      'Le 3e pilier ne suit PAS votre testament. L\'ordre de bénéficiaires est fixé par la loi.';

  @override
  String get successionPointsAttention => 'Points d\'attention';

  @override
  String get successionChecklist => 'Protection de mes proches';

  @override
  String get successionChecklistSubtitle => 'Actions à entreprendre';

  @override
  String get successionEduQuotite => 'Qu\'est-ce que la quotité disponible ?';

  @override
  String get successionEduQuotiteBody =>
      'La quotité disponible est la part de votre succession que vous pouvez librement attribuer par testament. Depuis 2023, la réserve des descendants est de 1/2.';

  @override
  String get successionEdu3a => 'Le 3a et la succession : attention !';

  @override
  String get successionEdu3aBody =>
      'Le 3e pilier est versé directement selon l\'OPP3, pas selon votre testament.';

  @override
  String get successionEduConcubin => 'Les concubins et la succession';

  @override
  String get successionEduConcubinBody =>
      'Les concubins n\'ont aucun droit successoral légal. Sans testament, ils ne reçoivent rien.';

  @override
  String get successionDisclaimer =>
      'Information à caractère éducatif, ne constitue pas un conseil juridique (LSFin/CC). Consulte un·e spécialiste pour ta situation.';

  @override
  String get lifeEventsSection => 'Événements de vie';

  @override
  String get lifeEventDivorce => 'Divorce';

  @override
  String get lifeEventSuccession => 'Succession';

  @override
  String get coachingTitle => 'Coaching proactif';

  @override
  String get coachingSubtitle => 'Vos suggestions personnalisées';

  @override
  String get coachingIntro =>
      'Suggestions personnalisées basées sur votre profil. Plus votre profil est complet, plus les conseils sont pertinents.';

  @override
  String get coachingFilterAll => 'Tous';

  @override
  String get coachingFilterHigh => 'Haute priorité';

  @override
  String get coachingFilterFiscal => 'Fiscalité';

  @override
  String get coachingFilterPrevoyance => 'Prévoyance';

  @override
  String get coachingFilterBudget => 'Budget';

  @override
  String get coachingFilterRetraite => 'Retraite';

  @override
  String get coachingNoTips =>
      'Ton profil est complet. Rien à signaler pour l’instant.';

  @override
  String coachingImpact(String amount) {
    return 'Impact estimé : $amount';
  }

  @override
  String get coachingSource => 'Source';

  @override
  String coachingTipCount(String count) {
    return '$count conseils';
  }

  @override
  String get coachingPriorityHigh => 'Haute priorité';

  @override
  String get coachingPriorityMedium => 'Priorité moyenne';

  @override
  String get coachingPriorityLow => 'Information';

  @override
  String get coaching3aDeadlineTitle => 'Versement 3a avant le 31 décembre';

  @override
  String coaching3aDeadlineMessage(
      String remaining, String plafond, String impact) {
    return 'Il vous reste $remaining de marge sur votre plafond 3a ($plafond). Un versement avant le 31 décembre pourrait réduire votre charge fiscale d\'environ $impact.';
  }

  @override
  String get coaching3aDeadlineAction => 'Simuler mon 3a';

  @override
  String get coaching3aMissingTitle => 'Vous n\'avez pas de 3e pilier';

  @override
  String coaching3aMissingMessage(
      String plafond, String impact, String canton) {
    return 'Ouvrir un 3e pilier vous permettrait de déduire jusqu\'à $plafond de votre revenu imposable chaque année. L\'économie fiscale estimée est de $impact par an dans le canton de $canton.';
  }

  @override
  String get coaching3aMissingAction => 'Découvrir le 3e pilier';

  @override
  String get coaching3aNotMaxedTitle => 'Plafond 3a non atteint';

  @override
  String coaching3aNotMaxedMessage(
      String current, String plafond, String remaining, String impact) {
    return 'Votre versement 3a actuel est de $current sur un plafond de $plafond. Verser le solde de $remaining pourrait représenter une économie fiscale d\'environ $impact.';
  }

  @override
  String get coaching3aNotMaxedAction => 'Simuler mon 3a';

  @override
  String get coachingLppBuybackTitle => 'Rachat LPP possible';

  @override
  String coachingLppBuybackMessage(String gap, String impact) {
    return 'Vous avez une lacune de prévoyance de $gap. Un rachat volontaire pourrait vous faire économiser environ $impact d\'impôts tout en améliorant votre retraite.';
  }

  @override
  String get coachingLppBuybackAction => 'Simuler un rachat LPP';

  @override
  String get coachingTaxDeadlineTitle => 'Déclaration d\'impôts à rendre';

  @override
  String coachingTaxDeadlineMessage(String canton, String days) {
    return 'Le délai pour votre déclaration fiscale dans le canton de $canton est le 31 mars. Il reste $days jours.';
  }

  @override
  String get coachingTaxDeadlineAction => 'Voir ma checklist fiscale';

  @override
  String coachingRetirementTitle(String years) {
    return 'Retraite dans $years ans';
  }

  @override
  String coachingRetirementMessage(String years) {
    return 'À $years ans de la retraite, il est important de vérifier votre stratégie de prévoyance. Avez-vous optimisé vos rachats LPP ? Vos comptes 3a sont-ils diversifiés ?';
  }

  @override
  String get coachingRetirementAction => 'Planifier ma retraite';

  @override
  String get coachingEmergencyTitle => 'Réserve d\'urgence insuffisante';

  @override
  String coachingEmergencyMessage(String months, String deficit) {
    return 'Votre épargne disponible couvre $months mois de charges fixes. Les experts recommandent au moins 3 mois. Il vous manque environ $deficit pour atteindre ce seuil.';
  }

  @override
  String get coachingEmergencyAction => 'Voir mon budget';

  @override
  String coachingDebtTitle(String ratio) {
    return 'Taux d\'endettement élevé ($ratio%)';
  }

  @override
  String coachingDebtMessage(String ratio) {
    return 'Votre taux d\'endettement estimé est de $ratio%, au-dessus du seuil de 33% recommandé par les banques suisses.';
  }

  @override
  String get coachingDebtAction => 'Analyser mes dettes';

  @override
  String get coachingPartTimeTitle => 'Temps partiel : lacune de prévoyance';

  @override
  String coachingPartTimeMessage(String rate) {
    return 'À $rate% d\'activité, votre prévoyance professionnelle est réduite. La déduction de coordination pénalise davantage les temps partiels.';
  }

  @override
  String get coachingPartTimeAction => 'Simuler ma prévoyance';

  @override
  String get coachingIndependantTitle => 'Indépendant : pas de LPP obligatoire';

  @override
  String get coachingIndependantMessage =>
      'En tant qu\'indépendant, vous n\'êtes pas soumis à la LPP obligatoire. Votre prévoyance repose sur l\'AVS et votre 3e pilier. Pensez à maximiser votre 3a.';

  @override
  String get coachingIndependantAction => 'Explorer mes options';

  @override
  String get coachingBudgetMissingTitle => 'Pas encore de budget';

  @override
  String get coachingBudgetMissingMessage =>
      'Un budget structuré est la base de toute stratégie financière. Il permet d\'identifier votre capacité d\'épargne réelle.';

  @override
  String get coachingBudgetMissingAction => 'Créer mon budget';

  @override
  String get coachingAge25Title => '25 ans : démarrer son 3e pilier';

  @override
  String get coachingAge25Message =>
      'À 25 ans, c\'est le moment idéal pour ouvrir un 3e pilier. Grâce aux intérêts composés, chaque année compte.';

  @override
  String get coachingAge35Title => '35 ans : faire le point prévoyance';

  @override
  String get coachingAge35Message =>
      'À 35 ans, vérifiez que votre prévoyance est sur la bonne trajectoire. Avez-vous un 3a ? Votre LPP est-elle suffisante ?';

  @override
  String get coachingAge45Title => '45 ans : optimiser sa stratégie';

  @override
  String get coachingAge45Message =>
      'À 45 ans, il reste 20 ans avant la retraite. C\'est le moment d\'optimiser : maximiser le 3a, envisager des rachats LPP.';

  @override
  String get coachingAge50Title => '50 ans : préparer sa retraite';

  @override
  String get coachingAge50Message =>
      'À 50 ans, la retraite se rapproche. Vérifiez votre avoir LPP, planifiez vos derniers rachats.';

  @override
  String get coachingAge55Title => '55 ans : dernière ligne droite';

  @override
  String get coachingAge55Message =>
      'À 55 ans, la planification fiscale du retrait devient cruciale. Échelonner les retraits 3a peut représenter une économie significative.';

  @override
  String get coachingAge58Title => '58 ans : retraite anticipée possible';

  @override
  String get coachingAge58Message =>
      'Dès 58 ans, un retrait anticipé de votre 2e pilier est envisageable. Attention : la rente sera réduite.';

  @override
  String get coachingAge63Title => '63 ans : derniers ajustements';

  @override
  String get coachingAge63Message =>
      'À 2 ans de la retraite légale, finalisez votre stratégie. Dernier rachat LPP, choix rente/capital.';

  @override
  String get coachingDisclaimer =>
      'Les suggestions présentées sont des pistes de réflexion basées sur des estimations simplifiées. Elles ne constituent pas un conseil financier personnalisé. Consultez un professionnel qualifié avant toute décision.';

  @override
  String get coachingDemoMode =>
      'Mode démo : profil exemple (35 ans, VD, CHF 85\'000). Complétez votre diagnostic pour des conseils personnalisés.';

  @override
  String get coachingNowCardTitle => 'Coaching proactif';

  @override
  String get coachingNowCardSubtitle =>
      'Conseils personnalisés selon votre profil';

  @override
  String get coachingCategoryFiscalite => 'Fiscalité';

  @override
  String get coachingCategoryPrevoyance => 'Prévoyance';

  @override
  String get coachingCategoryBudget => 'Budget';

  @override
  String get coachingCategoryRetraite => 'Retraite';

  @override
  String get segmentsSection => 'Segments';

  @override
  String get segmentsGenderGapTitle => 'Gender gap prévoyance';

  @override
  String get segmentsGenderGapSubtitle =>
      'Impact du temps partiel sur la retraite';

  @override
  String get segmentsGenderGapAppBar => 'GENDER GAP PRÉVOYANCE';

  @override
  String get segmentsGenderGapHeader => 'Lacune de prévoyance';

  @override
  String get segmentsGenderGapHeaderSub =>
      'Impact du temps partiel sur la retraite';

  @override
  String get segmentsGenderGapIntro =>
      'La déduction de coordination (CHF 25\'725) n\'est pas proratisée pour le temps partiel, ce qui pénalise davantage les personnes travaillant à temps réduit. Déplacez le curseur pour voir l\'impact.';

  @override
  String get segmentsGenderGapTauxLabel => 'Taux d\'activité';

  @override
  String get segmentsGenderGapParams => 'Paramètres';

  @override
  String get segmentsGenderGapRevenuLabel => 'Revenu annuel brut (100%)';

  @override
  String get segmentsGenderGapAgeLabel => 'Âge';

  @override
  String get segmentsGenderGapAvoirLabel => 'Avoir LPP actuel';

  @override
  String get segmentsGenderGapAnneesCotisLabel => 'Années de cotisation';

  @override
  String get segmentsGenderGapCantonLabel => 'Canton';

  @override
  String get segmentsGenderGapRenteTitle => 'Rente LPP estimée';

  @override
  String segmentsGenderGapRenteSub(String years) {
    return 'Projection à $years ans (âge 65)';
  }

  @override
  String get segmentsGenderGapAt100 => 'À 100%';

  @override
  String segmentsGenderGapAtCurrent(String rate) {
    return 'À $rate%';
  }

  @override
  String get segmentsGenderGapLacuneAnnuelle => 'Lacune annuelle';

  @override
  String get segmentsGenderGapLacuneTotale => 'Lacune totale (~20 ans)';

  @override
  String get segmentsGenderGapCoordinationTitle =>
      'Comprendre la déduction de coordination';

  @override
  String get segmentsGenderGapCoordinationBody =>
      'La déduction de coordination est un montant fixe de CHF 25\'725 soustrait de votre salaire brut pour calculer le salaire coordonné (base LPP). Ce montant est le même que vous travailliez à 100% ou à 50%.';

  @override
  String get segmentsGenderGapSalaireBrut100 => 'Salaire brut à 100%';

  @override
  String get segmentsGenderGapSalaireCoord100 => 'Salaire coordonné à 100%';

  @override
  String segmentsGenderGapSalaireBrutCurrent(String rate) {
    return 'Salaire brut à $rate%';
  }

  @override
  String segmentsGenderGapSalaireCoordCurrent(String rate) {
    return 'Salaire coordonné à $rate%';
  }

  @override
  String get segmentsGenderGapDeductionFixe => 'Déduction coordination (fixe)';

  @override
  String get segmentsGenderGapOfsTitle => 'Statistique OFS';

  @override
  String get segmentsGenderGapOfsStat =>
      'En Suisse, les femmes touchent en moyenne 37% de rente de moins que les hommes (OFS 2024)';

  @override
  String get segmentsGenderGapRecTitle => 'RECOMMANDATIONS';

  @override
  String get segmentsGenderGapRecRachat => 'Rachat LPP volontaire';

  @override
  String get segmentsGenderGapRecRachatDesc =>
      'Un rachat volontaire permet de combler partiellement la lacune de prévoyance tout en bénéficiant d\'une déduction fiscale.';

  @override
  String get segmentsGenderGapRec3a => '3e pilier maximisé';

  @override
  String get segmentsGenderGapRec3aDesc =>
      'Versez le plafond annuel de CHF 7\'258 (salariés) pour compenser partiellement la lacune LPP.';

  @override
  String get segmentsGenderGapRecCoord =>
      'Vérifier la proratisation de la coordination';

  @override
  String get segmentsGenderGapRecCoordDesc =>
      'Certaines caisses de pension proratisent la déduction de coordination en fonction du taux d\'activité.';

  @override
  String get segmentsGenderGapRecTaux =>
      'Explorer une augmentation du taux d\'activité';

  @override
  String get segmentsGenderGapRecTauxDesc =>
      'Même une augmentation de 10 à 20 points peut réduire significativement la lacune.';

  @override
  String get segmentsGenderGapDisclaimer =>
      'Les résultats présentés sont des estimations simplifiées à titre indicatif. Ils ne constituent pas un conseil financier personnalisé. Consultez votre caisse de pension et un professionnel qualifié.';

  @override
  String get segmentsGenderGapSources => 'Sources';

  @override
  String get segmentsFrontalierTitle => 'Frontalier';

  @override
  String get segmentsFrontalierSubtitle => 'Droits et obligations par pays';

  @override
  String get segmentsFrontalierAppBar => 'PARCOURS FRONTALIER';

  @override
  String get segmentsFrontalierHeader => 'Travailleur frontalier';

  @override
  String get segmentsFrontalierHeaderSub => 'Droits et obligations par pays';

  @override
  String get segmentsFrontalierIntro =>
      'Les règles fiscales, de prévoyance et d\'assurance varient selon votre pays de résidence et votre canton de travail.';

  @override
  String get segmentsFrontalierPaysLabel => 'Pays de résidence';

  @override
  String get segmentsFrontalierCantonLabel => 'Canton de travail';

  @override
  String get segmentsFrontalierRulesTitle => 'RÈGLES APPLICABLES';

  @override
  String get segmentsFrontalierCatFiscal => 'Régime fiscal';

  @override
  String get segmentsFrontalierCat3a => '3e pilier';

  @override
  String get segmentsFrontalierCatLpp => 'LPP / Libre passage';

  @override
  String get segmentsFrontalierCatAvs => 'AVS / Coordination';

  @override
  String get segmentsFrontalierQuasiResidentTitle =>
      'Statut quasi-résident (GE)';

  @override
  String get segmentsFrontalierQuasiResidentDesc =>
      'Le statut de quasi-résident est accessible si au moins 90% des revenus de votre ménage proviennent de Suisse.';

  @override
  String get segmentsFrontalierQuasiResidentCondition =>
      'Condition : >= 90% des revenus du ménage provenant de Suisse';

  @override
  String get segmentsFrontalierChecklist => 'Checklist frontalier';

  @override
  String get segmentsFrontalierPaysFR => 'France';

  @override
  String get segmentsFrontalierPaysDE => 'Allemagne';

  @override
  String get segmentsFrontalierPaysIT => 'Italie';

  @override
  String get segmentsFrontalierPaysAT => 'Autriche';

  @override
  String get segmentsFrontalierPaysLI => 'Liechtenstein';

  @override
  String get segmentsFrontalierAttention => 'Attention';

  @override
  String get segmentsFrontalierDisclaimer =>
      'Les informations présentées sont générales et peuvent varier selon votre situation personnelle. Consultez un fiduciaire spécialisé en situations transfrontalières.';

  @override
  String get segmentsFrontalierSources => 'Sources';

  @override
  String get segmentsIndependantTitle => 'Indépendant';

  @override
  String get segmentsIndependantSubtitle => 'Couverture et protection sociale';

  @override
  String get segmentsIndependantAppBar => 'PARCOURS INDÉPENDANT';

  @override
  String get segmentsIndependantHeader => 'Indépendant';

  @override
  String get segmentsIndependantHeaderSub =>
      'Analyse de couverture et protection';

  @override
  String get segmentsIndependantIntro =>
      'En tant qu\'indépendant, vous n\'avez pas de LPP obligatoire, pas d\'IJM, et pas de LAA. Votre protection dépend de vos démarches personnelles.';

  @override
  String get segmentsIndependantRevenuLabel => 'Revenu net annuel';

  @override
  String get segmentsIndependantCoverageTitle => 'Ma couverture actuelle';

  @override
  String get segmentsIndependantLpp => 'LPP (affiliation volontaire)';

  @override
  String get segmentsIndependantIjm => 'IJM (indemnité journalière maladie)';

  @override
  String get segmentsIndependantLaa => 'LAA (assurance accident)';

  @override
  String get segmentsIndependant3a => '3e pilier (3a)';

  @override
  String get segmentsIndependantAnalyseTitle => 'ANALYSE DE COUVERTURE';

  @override
  String get segmentsIndependantCouvert => 'Couvert';

  @override
  String get segmentsIndependantNonCouvert => 'NON COUVERT';

  @override
  String get segmentsIndependantCritique => 'NON COUVERT — Critique';

  @override
  String get segmentsIndependantProtectionTitle =>
      'Coût de ma protection complète';

  @override
  String get segmentsIndependantProtectionSub => 'Estimation mensuelle';

  @override
  String get segmentsIndependantAvs => 'AVS / AI / APG';

  @override
  String get segmentsIndependantIjmEst => 'IJM (estimation)';

  @override
  String get segmentsIndependantLaaEst => 'LAA (estimation)';

  @override
  String get segmentsIndependant3aMax => '3e pilier (max)';

  @override
  String get segmentsIndependantTotalMensuel => 'Total mensuel';

  @override
  String get segmentsIndependantAvsTitle => 'Cotisation AVS indépendant';

  @override
  String segmentsIndependantAvsDesc(String amount) {
    return 'Votre cotisation AVS estimée : $amount/an (taux dégressif pour les revenus inférieurs à CHF 58\'800).';
  }

  @override
  String get segmentsIndependant3aTitle => '3e pilier — plafond indépendant';

  @override
  String get segmentsIndependant3aWithLpp =>
      'Avec LPP volontaire : plafond 3a standard de CHF 7\'258/an.';

  @override
  String get segmentsIndependant3aWithoutLpp =>
      'Sans LPP : plafond 3a \'grand\' de 20% du revenu net, max CHF 36\'288/an.';

  @override
  String get segmentsIndependantRecTitle => 'RECOMMANDATIONS';

  @override
  String get segmentsIndependantDisclaimer =>
      'Les montants présentés sont des estimations indicatives. Consultez un fiduciaire ou un assureur avant toute décision.';

  @override
  String get segmentsIndependantSources => 'Sources';

  @override
  String get segmentsIndependantAlertIjm =>
      'CRITIQUE : Vous n\'avez pas d\'assurance IJM. En cas de maladie, vous n\'aurez aucun revenu de remplacement.';

  @override
  String get segmentsIndependantAlertLaa =>
      'IMPORTANT : Sans assurance accident individuelle (LAA), les frais médicaux en cas d\'accident ne sont pas couverts.';

  @override
  String get segmentsIndependantAlertLpp =>
      'Votre prévoyance repose uniquement sur l\'AVS et le 3e pilier.';

  @override
  String get segmentsIndependantAlert3a =>
      'Vous ne profitez pas du 3e pilier. Plafond indépendant : CHF 36\'288/an.';

  @override
  String get segmentsDemoMode =>
      'Mode démo : profil exemple. Complétez votre diagnostic pour des résultats personnalisés.';

  @override
  String get assurancesLamalTitle => 'Optimiseur franchise LAMal';

  @override
  String get assurancesLamalSubtitle =>
      'Trouvez la franchise idéale selon vos frais de santé';

  @override
  String get assurancesLamalPrimeMensuelle => 'Prime mensuelle (franchise 300)';

  @override
  String get assurancesLamalDepensesSante => 'Frais de santé annuels estimés';

  @override
  String get assurancesLamalAdulte => 'Adulte';

  @override
  String get assurancesLamalEnfant => 'Enfant';

  @override
  String get assurancesLamalFranchise => 'Franchise';

  @override
  String get assurancesLamalPrimeAnnuelle => 'Prime annuelle';

  @override
  String get assurancesLamalCoutTotal => 'Coût total';

  @override
  String get assurancesLamalEconomie => 'Économie vs 300';

  @override
  String get assurancesLamalOptimale => 'Franchise recommandée';

  @override
  String get assurancesLamalBreakEven => 'Seuil de rentabilité';

  @override
  String get assurancesLamalDelaiRappel =>
      'Rappel : modification possible avant le 30 novembre';

  @override
  String get assurancesLamalQuotePart => 'Quote-part (10%, max 700 CHF)';

  @override
  String get assurancesCoverageTitle => 'Check-up couverture';

  @override
  String get assurancesCoverageSubtitle =>
      'Évaluez votre protection assurantielle';

  @override
  String get assurancesCoverageScore => 'Score de couverture';

  @override
  String get assurancesCoverageLacunes => 'Lacunes identifiées';

  @override
  String get assurancesCoverageStatut => 'Statut professionnel';

  @override
  String get assurancesCoverageSalarie => 'Salarié·e';

  @override
  String get assurancesCoverageIndependant => 'Indépendant·e';

  @override
  String get assurancesCoverageSansEmploi => 'Sans emploi';

  @override
  String get assurancesCoverageHypotheque => 'Hypothèque en cours';

  @override
  String get assurancesCoverageFamille => 'Personnes à charge';

  @override
  String get assurancesCoverageLocataire => 'Locataire';

  @override
  String get assurancesCoverageVoyages => 'Voyages fréquents';

  @override
  String get assurancesCoverageIjm => 'IJM collective (employeur)';

  @override
  String get assurancesCoverageLaa => 'LAA (assurance accident)';

  @override
  String get assurancesCoverageRc => 'RC privée';

  @override
  String get assurancesCoverageMenage => 'Assurance ménage';

  @override
  String get assurancesCoverageJuridique => 'Protection juridique';

  @override
  String get assurancesCoverageVoyage => 'Assurance voyage';

  @override
  String get assurancesCoverageDeces => 'Assurance décès';

  @override
  String get assurancesCoverageCouvert => 'Couvert';

  @override
  String get assurancesCoverageNonCouvert => 'Non couvert';

  @override
  String get assurancesCoverageAVerifier => 'À vérifier';

  @override
  String get assurancesCoverageCritique => 'Critique';

  @override
  String get assurancesCoverageHaute => 'Haute';

  @override
  String get assurancesCoverageMoyenne => 'Moyenne';

  @override
  String get assurancesCoverageBasse => 'Basse';

  @override
  String get assurancesDemoMode => 'MODE DÉMO';

  @override
  String get assurancesDisclaimer =>
      'Cette analyse est indicative. Les primes varient selon l\'assureur, la région et le modèle d\'assurance. Consultez votre caisse maladie pour des chiffres exacts.';

  @override
  String get assurancesSection => 'Assurances';

  @override
  String get assurancesLamalTile => 'Franchise LAMal';

  @override
  String get assurancesLamalTileSub => 'Trouvez la franchise idéale';

  @override
  String get assurancesCoverageTile => 'Check-up couverture';

  @override
  String get assurancesCoverageTileSub =>
      'Évaluez votre protection assurantielle';

  @override
  String get openBankingTitle => 'Open Banking';

  @override
  String get openBankingSubtitle => 'Connectez vos comptes bancaires';

  @override
  String get openBankingFinmaGate =>
      'Fonctionnalité en préparation — consultation réglementaire FINMA en cours';

  @override
  String get openBankingDemoData =>
      'Les données affichées sont des exemples de démonstration';

  @override
  String get openBankingTotalBalance => 'Solde total';

  @override
  String get openBankingAccounts => 'Comptes connectés';

  @override
  String get openBankingAddBank => 'Ajouter une banque';

  @override
  String get openBankingAddBankDisabled =>
      'Disponible après consultation FINMA';

  @override
  String get openBankingTransactions => 'Transactions';

  @override
  String get openBankingNoTransactions => 'Aucune transaction';

  @override
  String get openBankingIncome => 'Revenus';

  @override
  String get openBankingExpenses => 'Dépenses';

  @override
  String get openBankingNetSavings => 'Épargne nette';

  @override
  String get openBankingSavingsRate => 'Taux d\'épargne';

  @override
  String get openBankingConsents => 'Consentements';

  @override
  String get openBankingConsentActive => 'Actif';

  @override
  String get openBankingConsentExpiring => 'Expire bientôt';

  @override
  String get openBankingConsentExpired => 'Expiré';

  @override
  String get openBankingConsentRevoke => 'Révoquer';

  @override
  String get openBankingConsentRevoked => 'Révoqué';

  @override
  String get openBankingConsentScopes => 'Autorisations';

  @override
  String get openBankingConsentScopeAccounts => 'Comptes';

  @override
  String get openBankingConsentScopeBalances => 'Soldes';

  @override
  String get openBankingConsentScopeTransactions => 'Transactions';

  @override
  String get openBankingConsentDuration => 'Durée maximale : 90 jours';

  @override
  String get openBankingNlpdTitle => 'Vos droits (nLPD)';

  @override
  String get openBankingNlpdRevoke =>
      'Vous pouvez révoquer votre consentement à tout moment';

  @override
  String get openBankingNlpdNoSharing =>
      'Vos données ne sont jamais partagées avec des tiers';

  @override
  String get openBankingNlpdReadOnly =>
      'Accès en lecture seule — aucune opération financière';

  @override
  String get openBankingNlpdDuration =>
      'Durée maximale de consentement : 90 jours';

  @override
  String get openBankingSelectBank => 'Choisir une banque';

  @override
  String get openBankingSelectScopes => 'Choisir les autorisations';

  @override
  String get openBankingConfirm => 'Confirmer';

  @override
  String get openBankingCancel => 'Annuler';

  @override
  String get openBankingBack => 'Retour';

  @override
  String get openBankingNext => 'Suivant';

  @override
  String get openBankingCategoryAll => 'Toutes';

  @override
  String get openBankingCategoryAlimentation => 'Alimentation';

  @override
  String get openBankingCategoryTransport => 'Transport';

  @override
  String get openBankingCategoryLogement => 'Logement';

  @override
  String get openBankingCategoryTelecom => 'Télécom';

  @override
  String get openBankingCategoryAssurances => 'Assurances';

  @override
  String get openBankingCategoryEnergie => 'Énergie';

  @override
  String get openBankingCategorySante => 'Santé';

  @override
  String get openBankingCategoryLoisirs => 'Loisirs';

  @override
  String get openBankingCategoryImpots => 'Impôts';

  @override
  String get openBankingCategoryEpargne => 'Épargne';

  @override
  String get openBankingCategoryDivers => 'Divers';

  @override
  String get openBankingCategoryRevenu => 'Revenu';

  @override
  String get openBankingLastSync => 'Dernière synchronisation';

  @override
  String get openBankingIbanMasked => 'IBAN masqué';

  @override
  String get openBankingFilterAll => 'Toutes';

  @override
  String get openBankingThisMonth => 'Ce mois';

  @override
  String get openBankingLastMonth => 'Mois précédent';

  @override
  String get openBankingDemoMode => 'MODE DÉMO';

  @override
  String get openBankingDisclaimer =>
      'Cette fonctionnalité est en cours de développement. Les données affichées sont des exemples. L\'activation du service Open Banking est soumise à une consultation réglementaire préalable.';

  @override
  String get openBankingBlink => 'Propulsé par bLink (SIX)';

  @override
  String get openBankingFinancialOverview => 'Aperçu financier';

  @override
  String get openBankingTopExpenses => 'Top 3 dépenses';

  @override
  String get openBankingViewTransactions => 'Voir les transactions';

  @override
  String get openBankingManageConsents => 'Gérer les consentements';

  @override
  String get openBankingMonthlySummary => 'Synthèse du mois';

  @override
  String get openBankingAddConsent => 'Ajouter un consentement';

  @override
  String get openBankingConsentGrantedOn => 'Accordé le';

  @override
  String get openBankingConsentExpiresOn => 'Expire le';

  @override
  String get openBankingConsentRevokedConfirm => 'Consentement révoqué';

  @override
  String get openBankingScopeAccountsDesc => 'Comptes (liste de vos comptes)';

  @override
  String get openBankingScopeBalancesDesc =>
      'Soldes (solde actuel de vos comptes)';

  @override
  String get openBankingScopeTransactionsDesc =>
      'Transactions (historique des mouvements)';

  @override
  String get openBankingReadOnlyInfo =>
      'Accès en lecture seule. Aucune opération financière ne peut être effectuée.';

  @override
  String get openBankingConsentConfirmText =>
      'En confirmant, vous autorisez MINT à accéder aux données sélectionnées en lecture seule pour une durée de 90 jours. Vous pouvez révoquer ce consentement à tout moment.';

  @override
  String get openBankingSection => 'Open Banking';

  @override
  String get openBankingTile => 'Open Banking';

  @override
  String get openBankingTileSub => 'Connectez vos comptes bancaires';

  @override
  String get lppDeepSection => 'LPP APPROFONDI';

  @override
  String get lppDeepRachatTitle => 'Rachat échelonné';

  @override
  String get lppDeepRachatSubtitle =>
      'Optimisez vos rachats LPP sur plusieurs années';

  @override
  String get lppDeepRachatAppBar => 'RACHAT LPP ÉCHELONNÉ';

  @override
  String get lppDeepRachatIntroTitle => 'Pourquoi échelonner ses rachats ?';

  @override
  String get lppDeepRachatIntroBody =>
      'L\'impôt suisse étant progressif, répartir un rachat LPP sur plusieurs années permet de rester dans des tranches marginales plus élevées chaque année, maximisant ainsi l\'économie fiscale totale.';

  @override
  String get lppDeepRachatParams => 'Paramètres';

  @override
  String get lppDeepRachatAvoirActuel => 'Avoir actuel LPP';

  @override
  String get lppDeepRachatMax => 'Rachat maximum';

  @override
  String get lppDeepRachatRevenu => 'Revenu imposable';

  @override
  String get lppDeepRachatTauxMarginal => 'Taux marginal estimé';

  @override
  String get lppDeepRachatHorizon => 'Horizon (années)';

  @override
  String get lppDeepRachatComparaison => 'Comparaison';

  @override
  String get lppDeepRachatBloc => 'TOUT EN 1 AN';

  @override
  String get lppDeepRachatBlocSub => 'Rachat bloc';

  @override
  String lppDeepRachatEchelonne(String years) {
    return 'ÉCHELONNÉ SUR $years ANS';
  }

  @override
  String get lppDeepRachatEchelonneSub => 'Rachat réparti';

  @override
  String get lppDeepRachatEconomie => 'Économie fiscale';

  @override
  String lppDeepRachatEconomieDelta(String amount) {
    return 'En échelonnant, vous économisez CHF $amount de plus en impôts.';
  }

  @override
  String get lppDeepRachatPlanAnnuel => 'Plan annuel';

  @override
  String get lppDeepRachatAnnee => 'Année';

  @override
  String get lppDeepRachatMontant => 'Rachat';

  @override
  String get lppDeepRachatEcoFiscale => 'Économie';

  @override
  String get lppDeepRachatCoutNet => 'Coût net';

  @override
  String get lppDeepRachatTotal => 'Total';

  @override
  String get lppDeepRachatBlocageEpl => 'LPP art. 79b al. 3 — Blocage EPL';

  @override
  String get lppDeepRachatBlocageEplBody =>
      'Après chaque rachat, tout retrait EPL (encouragement à la propriété du logement) est bloqué pendant 3 ans. Planifiez en conséquence si un achat immobilier est prévu.';

  @override
  String get lppDeepRachatDisclaimer =>
      'Simulation pédagogique basée sur une progressivité estimée. Le rachat LPP est soumis à acceptation par la caisse de pension. Consultez votre caisse de pension et un·e spécialiste en prévoyance avant toute décision.';

  @override
  String get lppDeepLibrePassageTitle => 'Libre passage';

  @override
  String get lppDeepLibrePassageSubtitle =>
      'Checklist en cas de changement d\'emploi ou départ';

  @override
  String get lppDeepLibrePassageAppBar => 'LIBRE PASSAGE';

  @override
  String get lppDeepLibrePassageSituation => 'Situation';

  @override
  String get lppDeepLibrePassageChangement => 'Changement d\'emploi';

  @override
  String get lppDeepLibrePassageDepart => 'Départ de Suisse';

  @override
  String get lppDeepLibrePassageCessation => 'Cessation d\'activité';

  @override
  String get lppDeepLibrePassageNewEmployer => 'Nouvel employeur';

  @override
  String get lppDeepLibrePassageNewEmployerSub =>
      'Avez-vous déjà un nouvel employeur ?';

  @override
  String get lppDeepLibrePassageAlertes => 'Alertes';

  @override
  String get lppDeepLibrePassageChecklist => 'Checklist';

  @override
  String get lppDeepLibrePassageRecommandations => 'Recommandations';

  @override
  String get lppDeepLibrePassageUrgenceCritique => 'Critique';

  @override
  String get lppDeepLibrePassageUrgenceHaute => 'Haute';

  @override
  String get lppDeepLibrePassageUrgenceMoyenne => 'Moyenne';

  @override
  String get lppDeepLibrePassageCentrale => 'Centrale du 2e pilier (sfbvg.ch)';

  @override
  String get lppDeepLibrePassageCentraleSub =>
      'Recherchez des avoirs de libre passage oubliés';

  @override
  String get lppDeepLibrePassagePrivacy =>
      'Vos données restent sur votre appareil. Aucune information n\'est transmise à des tiers. Conforme à la nLPD.';

  @override
  String get lppDeepLibrePassageDisclaimer =>
      'Ces informations sont pédagogiques et ne constituent pas un conseil juridique ou financier personnalisé. Les règles dépendent de votre caisse de pension et de votre situation. Base légale : LFLP, OLP.';

  @override
  String get lppDeepEplTitle => 'Retrait EPL';

  @override
  String get lppDeepEplSubtitle => 'Financer un logement avec votre 2e pilier';

  @override
  String get lppDeepEplAppBar => 'RETRAIT EPL';

  @override
  String get lppDeepEplIntroTitle => 'Retrait EPL — Propriété du logement';

  @override
  String get lppDeepEplIntroBody =>
      'L\'EPL permet d\'utiliser votre avoir LPP pour financer l\'achat d\'un logement en propriété, amortir une hypothèque ou financer des rénovations. Montant minimum : CHF 20\'000.';

  @override
  String get lppDeepEplParams => 'Paramètres';

  @override
  String get lppDeepEplAvoirTotal => 'Avoir LPP total';

  @override
  String get lppDeepEplAge => 'Âge';

  @override
  String get lppDeepEplMontantSouhaite => 'Montant souhaité';

  @override
  String get lppDeepEplRachatsRecents => 'Rachats LPP récents';

  @override
  String get lppDeepEplRachatsRecentsSub =>
      'Avez-vous effectué un rachat LPP ces 3 dernières années ?';

  @override
  String get lppDeepEplAnneesSDepuisRachat => 'Années depuis le rachat';

  @override
  String get lppDeepEplResultat => 'Résultat';

  @override
  String get lppDeepEplMontantMaxRetirable => 'Montant maximum retirable';

  @override
  String get lppDeepEplMontantApplicable => 'Montant applicable';

  @override
  String get lppDeepEplRetraitImpossible =>
      'Le retrait n\'est pas possible dans la configuration actuelle.';

  @override
  String get lppDeepEplImpactPrestations => 'Impact sur les prestations';

  @override
  String get lppDeepEplReductionInvalidite =>
      'Réduction rente invalidité (estimation annuelle)';

  @override
  String get lppDeepEplReductionDeces => 'Réduction capital-décès (estimation)';

  @override
  String get lppDeepEplImpactNote =>
      'Le retrait EPL réduit proportionnellement vos prestations de risque. Vérifiez auprès de votre caisse de pension les montants exacts.';

  @override
  String get lppDeepEplEstimationFiscale => 'Estimation fiscale';

  @override
  String get lppDeepEplMontantRetire => 'Montant retiré';

  @override
  String get lppDeepEplImpotEstime => 'Impôt estimé sur le retrait';

  @override
  String get lppDeepEplMontantNet => 'Montant net après impôt';

  @override
  String get lppDeepEplTaxNote =>
      'Le retrait en capital est imposé à un taux réduit (environ 1/5 du barème ordinaire). Le taux exact dépend du canton et de la situation personnelle.';

  @override
  String get lppDeepEplPointsAttention => 'Points d\'attention';

  @override
  String get lppDeepEplDisclaimer =>
      'Simulation pédagogique à titre indicatif. Le montant retirable exact dépend du règlement de votre caisse de pension. L\'impôt varie selon le canton et la situation personnelle. Base légale : art. 30c LPP, OEPL.';

  @override
  String get exploreTitle => 'Explorer';

  @override
  String get explorePillarComprendreTitle => 'Je veux comprendre';

  @override
  String get explorePillarComprendreSub =>
      'L\'essentiel de la finance suisse, sans jargon. Quiz inclus.';

  @override
  String get explorePillarComprendreCta => 'Explorer les 9 thèmes';

  @override
  String get explorePillarCalculerTitle => 'Je veux calculer';

  @override
  String get explorePillarCalculerSub =>
      'Simule, compare, optimise. 49 outils à ta disposition.';

  @override
  String get explorePillarCalculerCta => 'Voir tous les outils';

  @override
  String get explorePillarLifeTitle => 'Il m\'arrive quelque chose';

  @override
  String get explorePillarLifeSub =>
      'Mariage, naissance, divorce, déménagement... on t\'accompagne.';

  @override
  String get exploreGoalBudget => 'Maîtriser mon Budget';

  @override
  String get exploreGoalBudgetSub => 'Gérer mes dépenses → 3 min';

  @override
  String get exploreGoalProperty => 'Devenir Propriétaire';

  @override
  String get exploreGoalPropertySub => 'Simuler mon achat → 5 min';

  @override
  String get exploreGoalTax => 'Payer Moins d\'Impôts';

  @override
  String get exploreGoalTaxSub => 'Optimiser mon 3a → 3 min';

  @override
  String get exploreGoalRetirement => 'Préparer ma Retraite';

  @override
  String get exploreGoalRetirementSub => 'Voir mon plan → 10 min';

  @override
  String get exploreEventMarriage => 'Mariage';

  @override
  String get exploreEventMarriageSub => 'Impact fiscal et LPP';

  @override
  String get exploreEventBirth => 'Naissance';

  @override
  String get exploreEventBirthSub => 'Allocations et déductions';

  @override
  String get exploreEventConcubinage => 'Concubinage';

  @override
  String get exploreEventConcubinageSub => 'Protéger ton couple';

  @override
  String get exploreEventDivorce => 'Divorce';

  @override
  String get exploreEventDivorceSub => 'Partage LPP et AVS';

  @override
  String get exploreEventSuccession => 'Succession';

  @override
  String get exploreEventSuccessionSub => 'Droits et planning';

  @override
  String get exploreEventHouseSale => 'Vente immobilière';

  @override
  String get exploreEventHouseSaleSub => 'Impôt plus-value';

  @override
  String get exploreEventDonation => 'Donation';

  @override
  String get exploreEventDonationSub => 'Fiscalité et limites';

  @override
  String get exploreEventExpat => 'Expatriation';

  @override
  String get exploreEventExpatSub => 'Départ ou arrivée';

  @override
  String get exploreDocUploadLpp => 'Certificats & documents';

  @override
  String get exploreDocUploadLppSub => 'Certificat LPP, extraits AVS →';

  @override
  String get exploreAskMintTitle => 'Ask MINT';

  @override
  String get exploreAskMintConfigured => 'Pose tes questions finance suisse →';

  @override
  String get exploreAskMintNotConfigured => 'Configure ton IA pour commencer →';

  @override
  String get exploreLearn3a => 'C\'est quoi le 3a ?';

  @override
  String get exploreLearnLpp => 'LPP : Mode d\'emploi';

  @override
  String get exploreLearnFiscal => 'Fiscalité Suisse 101';

  @override
  String get coachWelcome => 'Bienvenue sur MINT';

  @override
  String coachHello(String firstName) {
    return 'Bonjour $firstName';
  }

  @override
  String get coachFitnessTitle => 'Ton Fitness Financier';

  @override
  String get coachFinancialForm => 'Forme financière';

  @override
  String get coachScoreComposite => 'Score composite · 3 piliers';

  @override
  String get coachPillarBudget => 'Budget';

  @override
  String get coachPillarPrevoyance => 'Prévoyance';

  @override
  String get coachPillarPatrimoine => 'Patrimoine';

  @override
  String get coachCompletePrompt =>
      'Complète ton diagnostic pour découvrir ton score';

  @override
  String get coachDiscoverScore => 'Découvrir mon score — 10 min';

  @override
  String get coachTrajectory => 'Ta trajectoire';

  @override
  String get coachTrajectoryPrompt => 'Ta trajectoire financière t\'attend';

  @override
  String get coachDidYouKnow => 'Le savais-tu ?';

  @override
  String get coachFact3a =>
      'Le 3e pilier peut te faire économiser jusqu\'à CHF 2\'500 d\'impôts par an, selon ton canton et ton revenu.';

  @override
  String get coachFact3aLink => 'Simuler mon économie 3a';

  @override
  String get coachFactAvs =>
      'En Suisse, chaque année AVS manquante = −2.3% de rente à vie. Un rattrapage est possible dans certains cas.';

  @override
  String get coachFactAvsLink => 'Vérifier mes années AVS';

  @override
  String get coachFactLpp =>
      'Le rachat LPP est l\'un des leviers fiscaux les plus puissants pour les salarié·es en Suisse. Il est intégralement déductible du revenu imposable.';

  @override
  String get coachFactLppLink => 'Explorer le rachat LPP';

  @override
  String get coachMotivation =>
      'Rejoins les milliers d\'utilisateurs qui ont déjà fait leur diagnostic financier';

  @override
  String get coachMotivationSub => 'et recevoir des actions concrètes.';

  @override
  String get coachLaunchDiagnostic => 'Lancer mon diagnostic';

  @override
  String get coachQuickActions => 'Actions rapides';

  @override
  String get coachCheckin => 'Check-in\nmensuel';

  @override
  String get coachVerse3a => 'Verser\n3a';

  @override
  String get coachSimBuyback => 'Simuler\nrachat';

  @override
  String get coachExplore => 'Explorer';

  @override
  String get coachPulseDisclaimer =>
      'Estimations éducatives — ne constitue pas un conseil financier. Les rendements passés ne présagent pas des rendements futurs. Consulte un·e spécialiste pour un plan personnalisé. LSFin.';

  @override
  String get eduTheme3aTitle => 'Le 3e pilier (3a)';

  @override
  String get eduTheme3aQuestion =>
      'C\'est quoi le 3a et pourquoi tout le monde en parle ?';

  @override
  String get eduTheme3aAction => 'Estimer mon économie fiscale';

  @override
  String get eduTheme3aReminder =>
      'Décembre → Dernier moment pour verser cette année';

  @override
  String get eduThemeLppTitle => 'La caisse de pension (LPP)';

  @override
  String get eduThemeLppQuestion => 'Est-ce que j\'ai une caisse de pension ?';

  @override
  String get eduThemeLppAction => 'Analyser mon certificat LPP';

  @override
  String get eduThemeLppReminder =>
      'Demander mon certificat LPP à mon employeur';

  @override
  String get eduThemeAvsTitle => 'Les lacunes AVS';

  @override
  String get eduThemeAvsQuestion =>
      'Ai-je des années de cotisation manquantes ?';

  @override
  String get eduThemeAvsAction => 'Vérifier mon extrait de compte AVS';

  @override
  String get eduThemeAvsReminder => 'Commander mon extrait sur ahv-iv.ch';

  @override
  String get eduThemeEmergencyTitle => 'Le fonds d\'urgence';

  @override
  String get eduThemeEmergencyQuestion => 'Combien je devrais avoir de côté ?';

  @override
  String get eduThemeEmergencyAction => 'Calculer mon objectif';

  @override
  String get eduThemeEmergencyReminder =>
      'Vérifier mon épargne de sécurité chaque trimestre';

  @override
  String get eduThemeDebtTitle => 'Les dettes';

  @override
  String get eduThemeDebtQuestion => 'Combien me coûte vraiment ma dette ?';

  @override
  String get eduThemeDebtAction => 'Calculer le coût total';

  @override
  String get eduThemeDebtReminder => 'Priorité: rembourser avant d\'investir';

  @override
  String get eduThemeMortgageTitle => 'L\'hypothèque';

  @override
  String get eduThemeMortgageQuestion =>
      'Fixe ou SARON, c\'est quoi la différence ?';

  @override
  String get eduThemeMortgageAction => 'Comparer les deux stratégies';

  @override
  String get eduThemeMortgageReminder =>
      'Avant renouvellement: comparer 3 mois à l\'avance';

  @override
  String get eduThemeBudgetTitle => 'Le reste à vivre';

  @override
  String get eduThemeBudgetQuestion =>
      'Combien il me reste après les charges fixes ?';

  @override
  String get eduThemeBudgetAction => 'Estimer mon reste à vivre';

  @override
  String get eduThemeBudgetReminder => 'Revoir mon budget chaque mois';

  @override
  String get eduThemeLamalTitle => 'Les subsides LAMal';

  @override
  String get eduThemeLamalQuestion =>
      'Ai-je droit à une aide pour mes primes ?';

  @override
  String get eduThemeLamalAction => 'Vérifier mon éligibilité';

  @override
  String get eduThemeLamalReminder => 'Les critères changent selon le canton';

  @override
  String get eduThemeFiscalTitle => 'La fiscalité suisse';

  @override
  String get eduThemeFiscalQuestion =>
      'Comment fonctionnent les impôts en Suisse ?';

  @override
  String get eduThemeFiscalAction => 'Simuler mon économie 3a';

  @override
  String get eduThemeFiscalReminder =>
      'Deadline déclaration fiscale : 31 mars (extensible)';

  @override
  String get eduHubTitle => 'J\'Y COMPRENDS RIEN';

  @override
  String get eduHubSubtitle =>
      'Pas de panique. Choisis un sujet, on t\'explique l\'essentiel et on te donne une action simple.';

  @override
  String get eduHubReadQuiz => 'Lire + quiz • 2 min';

  @override
  String get askMintSuggestDebt =>
      'J\'ai des dettes — par où commencer pour m\'en sortir ?';

  @override
  String askMintSuggestAge3a(String age) {
    return 'J\'ai $age ans, est-ce que je devrais déjà cotiser au 3e pilier ?';
  }

  @override
  String askMintSuggestAgeLpp(String age) {
    return 'J\'ai $age ans, est-ce que je devrais racheter du LPP ?';
  }

  @override
  String askMintSuggestAgeRetirement(String age) {
    return 'J\'ai $age ans, comment préparer ma retraite au mieux ?';
  }

  @override
  String get askMintSuggestSelfEmployed =>
      'Je suis indépendant·e — comment me protéger sans LPP ?';

  @override
  String get askMintSuggestUnemployed =>
      'Je suis au chômage — quel impact sur ma prévoyance ?';

  @override
  String askMintSuggestCanton(String canton) {
    return 'Quelles déductions fiscales sont possibles dans le canton de $canton ?';
  }

  @override
  String get askMintSuggestIncome =>
      'Avec mon revenu, combien je peux déduire fiscalement par an ?';

  @override
  String get askMintSuggestGeneric1 =>
      'Rente ou capital LPP — quelle est la différence ?';

  @override
  String get askMintSuggestGeneric2 =>
      'Comment optimiser mes impôts cette année ?';

  @override
  String get askMintSuggestGeneric3 =>
      'Qu\'est-ce que le rachat LPP et est-ce que ça vaut le coup ?';

  @override
  String get askMintSuggestGeneric4 =>
      'Comment fonctionne la franchise LAMal ?';

  @override
  String get askMintEmptyBody =>
      'Finance suisse, décryptage des lois, simulateurs — je t\'explique tout, sources à l\'appui.';

  @override
  String get askMintPrivacyBadge => 'Tes données restent sur ton appareil';

  @override
  String get askMintForYou => 'POUR TOI';

  @override
  String get byokRecommended => 'Recommandé';

  @override
  String byokGetKeyOn(String provider) {
    return 'Obtenir une clé sur $provider';
  }

  @override
  String get byokCopilotActivated => 'Ton copilote financier est activé';

  @override
  String get byokCopilotBody =>
      'Pose ta première question sur la finance suisse — 3e pilier, impôts, LPP, budget...';

  @override
  String get byokTryNow => 'Essayer maintenant';

  @override
  String get trajectoryTitle => 'Ta trajectoire';

  @override
  String trajectorySubtitle(String years) {
    return '3 scénarios · $years ans';
  }

  @override
  String get trajectoryOptimiste => 'Optimiste';

  @override
  String get trajectoryBase => 'Base';

  @override
  String get trajectoryPrudent => 'Prudent';

  @override
  String get trajectoryTauxRemplacement => 'Taux de remplacement estimé : ';

  @override
  String get trajectoryEmpty => 'Pas encore de projection disponible';

  @override
  String get trajectoryEmptySub =>
      'Complète ton profil pour voir ta trajectoire';

  @override
  String get trajectoryDisclaimer =>
      'Estimations éducatives — ne constitue pas un conseil financier.';

  @override
  String get trajectoryDragHint => 'Glisse pour explorer';

  @override
  String get trajectoryGoalLabel => 'Cible';

  @override
  String get agirTitle => 'AGIR';

  @override
  String get agirThisMonth => 'Ce mois';

  @override
  String get agirTimeline => 'Timeline';

  @override
  String get agirTimelineSub => 'Tes prochaines échéances';

  @override
  String get agirHistory => 'Historique';

  @override
  String get agirHistorySub => 'Tes check-ins passés';

  @override
  String agirCheckinDone(String month) {
    return 'Check-in $month effectué';
  }

  @override
  String get agirDone => 'Fait';

  @override
  String agirCheckinCta(String month) {
    return 'Faire mon check-in $month';
  }

  @override
  String get agirNoCheckin => 'Pas encore de check-in';

  @override
  String get agirNoCheckinSub =>
      'Fais ton premier check-in pour commencer à suivre ta progression.';

  @override
  String get agirTimeline3a => 'Dernier jour versement 3a';

  @override
  String get agirTimeline3aSub =>
      'Vérifie que ton plafond est atteint avant fin décembre.';

  @override
  String get agirTimeline3aCta => 'Vérifier mon 3a';

  @override
  String agirTimelineTax(String canton) {
    return 'Déclaration impôts $canton';
  }

  @override
  String get agirTimelineTaxSub =>
      'Pense à rassembler tes attestations 3a et LPP.';

  @override
  String get agirTimelineTaxCta => 'Préparer mes documents';

  @override
  String get agirTimelineLamal => 'Franchise LAMal (changer ?)';

  @override
  String get agirTimelineLamalSub =>
      'Évalue si ta franchise actuelle est toujours adaptée.';

  @override
  String get agirTimelineLamalCta => 'Simuler les franchises';

  @override
  String get agirTimelineRetireSub => 'Ton objectif principal.';

  @override
  String get agirAuto => 'Auto';

  @override
  String get agirManuel => 'Manuel';

  @override
  String get agirDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil financier personnalisé. Les échéances et projections sont indicatives. Consulte un·e spécialiste pour un accompagnement adapté. LSFin.';

  @override
  String checkinTitle(String month) {
    return 'CHECK-IN $month';
  }

  @override
  String checkinHeader(String month) {
    return 'Check-in $month';
  }

  @override
  String get checkinSubtitle => 'Confirme tes versements du mois';

  @override
  String get checkinPlannedSection => 'Versements planifiés';

  @override
  String get checkinEventsSection => 'Événements du mois';

  @override
  String get checkinExpenses => 'Dépenses exceptionnelles ?';

  @override
  String get checkinExpensesHint => 'Ex: 2000 (réparation voiture)';

  @override
  String get checkinRevenues => 'Revenus exceptionnels ?';

  @override
  String get checkinRevenuesHint => 'Ex: 5000 (bonus annuel)';

  @override
  String get checkinNoteSection => 'Note du mois (optionnel)';

  @override
  String get checkinNoteHint =>
      'Ex: Mois compliqué, dépense imprévue pour la voiture...';

  @override
  String get checkinSubmit => 'Valider le check-in';

  @override
  String get checkinInvalidAmount => 'Montant invalide';

  @override
  String checkinSuccessTitle(String month) {
    return 'C\'est fait ! Check-in $month complété';
  }

  @override
  String get checkinSeeTrajectory => 'Voir ma trajectoire mise à jour';

  @override
  String get checkinImpactLabel => 'Impact sur ta trajectoire';

  @override
  String checkinImpactCapital(String amount) {
    return 'Capital projeté +$amount ce mois';
  }

  @override
  String checkinImpactTotal(String amount) {
    return 'Total versements : $amount';
  }

  @override
  String get checkinStreakLabel => 'Série en cours';

  @override
  String checkinStreakCount(String count) {
    return '$count mois consécutifs on-track !';
  }

  @override
  String get checkinCoachTip => 'Tip du coach';

  @override
  String get checkinAuto => 'Auto';

  @override
  String get checkinManuel => 'Manuel';

  @override
  String get checkinDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil financier personnalisé. Les projections sont basées sur des hypothèses et peuvent varier. Consulte un·e spécialiste pour un accompagnement adapté. LSFin.';

  @override
  String get checkinAddContribution => 'Ajouter un versement';

  @override
  String get checkinCategoryLabel => 'Catégorie';

  @override
  String get checkinCat3a => 'Pilier 3a';

  @override
  String get checkinCatLpp => 'Rachat LPP';

  @override
  String get checkinCatInvest => 'Investissement';

  @override
  String get checkinCatEpargne => 'Epargne libre';

  @override
  String get checkinLabelField => 'Nom';

  @override
  String get checkinLabelHint => 'Ex: 3a VIAC, Epargne vacances...';

  @override
  String get checkinAmountField => 'Montant mensuel';

  @override
  String get checkinAutoToggle => 'Ordre permanent (automatique)';

  @override
  String get checkinAddConfirm => 'Ajouter';

  @override
  String get vaultTitle => 'Coffre-fort';

  @override
  String get vaultHeaderTitle => 'Ton coffre-fort financier';

  @override
  String get vaultHeaderSubtitle =>
      'Centralise, comprends et agis sur tes documents';

  @override
  String vaultDocCount(String count) {
    return '$count documents';
  }

  @override
  String get vaultCategoryLpp => 'Prévoyance LPP';

  @override
  String get vaultCategorySalary => 'Certificat de salaire';

  @override
  String get vaultCategory3a => '3e pilier';

  @override
  String get vaultCategoryInsurance => 'Assurances';

  @override
  String get vaultCategoryLease => 'Bail';

  @override
  String get vaultCategoryLamal => 'Santé (LAMal)';

  @override
  String get vaultCategoryOther => 'Autre';

  @override
  String vaultCategoryCount(String count) {
    return '$count';
  }

  @override
  String get vaultCategoryNone => 'Aucun';

  @override
  String get vaultGuidanceTitle => 'Guidance juridique';

  @override
  String get vaultGuidanceLeaseTitle => 'Bail — Tes droits de locataire';

  @override
  String get vaultGuidanceLeaseBody =>
      'En Suisse, le loyer peut être contesté s\'il dépasse le rendement admissible (CO art. 269). Le préavis légal est de 3 mois pour un appartement, sauf clause contraire dans le bail. L\'ASLOCA offre des consultations gratuites dans la plupart des cantons.';

  @override
  String get vaultGuidanceLeaseSource => 'CO art. 269-270, OBLF art. 12-13';

  @override
  String get vaultGuidanceInsuranceTitle => 'Assurances — Audit de couverture';

  @override
  String get vaultGuidanceInsuranceBody =>
      'La RC privée et l\'assurance ménage ne sont pas obligatoires en Suisse, mais fortement recommandées. Vérifie que ta somme assurée ménage couvre la valeur réelle de tes biens. La sous-assurance peut réduire l\'indemnisation proportionnellement (LCA art. 69).';

  @override
  String get vaultGuidanceInsuranceSource => 'LCA art. 69, CGA assureurs';

  @override
  String get vaultGuidanceLamalTitle => 'LAMal — Optimisation franchise';

  @override
  String get vaultGuidanceLamalBody =>
      'Tu peux changer de franchise LAMal chaque année au 30 novembre (franchise plus haute) ou au 31 décembre (franchise plus basse). Un·e adulte en bonne santé peut économiser jusqu\'à 1\'500 CHF/an avec une franchise de 2\'500 CHF vs 300 CHF.';

  @override
  String get vaultGuidanceLamalSource => 'LAMal art. 62, OAMal art. 93-94';

  @override
  String get vaultGuidanceSalaryTitle => 'Salaire — Vérification du certificat';

  @override
  String get vaultGuidanceSalaryBody =>
      'Ton certificat de salaire (Lohnausweis) est le document clé pour ta déclaration fiscale. Vérifie que les cotisations LPP, AVS et allocations familiales correspondent à tes fiches de paie. Toute erreur peut impacter tes impôts et ta prévoyance.';

  @override
  String get vaultGuidanceSalarySource => 'LIFD art. 127, OFS formulaire 11';

  @override
  String get vaultUploadTitle => 'Quel type de document ?';

  @override
  String get vaultUploadButton => 'Choisir un fichier PDF';

  @override
  String get vaultEmptyTitle => 'Aucun document';

  @override
  String get vaultEmptySubtitle =>
      'Ajoute ton premier document pour alimenter tes simulations avec des données réelles';

  @override
  String get vaultPremiumTitle => 'Coffre-fort Premium';

  @override
  String get vaultPremiumBody =>
      'Passe à MINT Premium pour stocker un nombre illimité de documents et débloquer l\'audit de couverture automatique';

  @override
  String get vaultPremiumCta => 'Découvrir Premium';

  @override
  String get vaultDocListTitle => 'Mes documents';

  @override
  String vaultConfidence(String confidence) {
    return 'Confiance : $confidence%';
  }

  @override
  String get vaultAnalyzing => 'Analyse en cours...';

  @override
  String get vaultDeleteTitle => 'Supprimer le document ?';

  @override
  String get vaultDeleteMessage => 'Cette action est irréversible.';

  @override
  String get vaultDeleteButton => 'Supprimer';

  @override
  String get vaultPrivacy =>
      'Tes documents sont analysés localement et ne sont jamais partagés avec des tiers. Tu peux les supprimer à tout moment.';

  @override
  String get vaultDisclaimer =>
      'MINT est un outil éducatif. Les informations juridiques présentées sont à titre informatif et ne constituent pas un conseil juridique personnalisé (LSFin, nLPD). Pour toute question spécifique, consulte un·e spécialiste qualifié·e.';

  @override
  String get soaTitle => 'Ton Plan Mint';

  @override
  String get soaScoreLabel => 'Score de Santé Financière';

  @override
  String get soaPrioritiesTitle => 'Tes 3 Actions Prioritaires';

  @override
  String get soaDiagnosticTitle => 'Diagnostic par Cercle';

  @override
  String get soaTaxTitle => 'Simulation Fiscale';

  @override
  String get soaRetirementTitle => 'Projection Retraite (65 ans)';

  @override
  String get soaLppTitle => 'Stratégie Rachat LPP';

  @override
  String get soaBudgetTitle => 'Ton Budget Calculé';

  @override
  String get soaTransparencyTitle => 'Transparence & Plan de Route';

  @override
  String get soaDisclaimerText =>
      'Outil éducatif — ne constitue pas un conseil financier au sens de la LSFin. Les montants sont des estimations basées sur les données déclarées.';

  @override
  String get soaNextTitle => 'Et ensuite ?';

  @override
  String get soaNextSubtitle => 'Modules adaptés à ton profil';

  @override
  String get soaExportPdf => 'Export PDF';

  @override
  String get soaActionStart => 'Commencer';

  @override
  String get soaTaxableIncome => 'Revenu imposable';

  @override
  String get soaDeductions => 'Déductions';

  @override
  String get soaEstimatedTax => 'Impôts estimés';

  @override
  String get soaEffectiveRate => 'Taux effectif';

  @override
  String get soaCapitalEstimate => 'Capital estimé';

  @override
  String get soaAvsRent => 'Rente AVS mensuelle';

  @override
  String get soaLppRent => 'Rente LPP mensuelle';

  @override
  String get soaTotalMonthly => 'TOTAL mensuel';

  @override
  String soaAvsGapWarning(String gap) {
    return 'Attention : Lacunes AVS détectées ($gap ans)';
  }

  @override
  String soaBuybackYear(String year) {
    return 'Année $year';
  }

  @override
  String soaBuybackAmount(String amount) {
    return 'Rachat: CHF $amount';
  }

  @override
  String soaBuybackSaving(String amount) {
    return 'Économie: CHF $amount';
  }

  @override
  String soaTotalSaving(String amount) {
    return 'Économie fiscale totale : CHF $amount';
  }

  @override
  String soaNature(String nature) {
    return 'Nature : $nature';
  }

  @override
  String get soaAssumptions => 'Hypothèses de Travail';

  @override
  String get soaConflicts => 'Conflits d\'intérêts & Commissions';

  @override
  String get soaNoConflict =>
      'Aucun conflit d\'intérêt identifié pour ce rapport.';

  @override
  String get soaSafeModeLocked => 'Priorité au désendettement';

  @override
  String get soaSafeModeMessage =>
      'Tes actions prioritaires sont remplacées par un plan de désendettement.';

  @override
  String get soaLimitations => 'Limitations';

  @override
  String get soaProtectionSources => 'Sources : LP art. 93, Directives CSIAS';

  @override
  String get soaPrevoyanceSources => 'Sources : LPP art. 14, OPP3, LAVS';

  @override
  String get soaCroissanceSources => 'Sources : LIFD art. 33';

  @override
  String get soaOptimisationSources => 'Sources : CC art. 470, LIFD';

  @override
  String get soaAvailableMonth => 'Disponible / mois';

  @override
  String get soaRemainder => 'Reste à vivre';

  @override
  String get soaEstimatedTaxLabel => 'Impôts Estimés';

  @override
  String get soaSavingsRate => 'Taux d\'épargne';

  @override
  String get soaSavingsGoal => 'Objectif: 20%';

  @override
  String get soaProtectionScore => 'Score Protection';

  @override
  String get soaActiveDebts => 'Dettes actives';

  @override
  String get soaSerene => 'Serein';

  @override
  String get soaNetIncome => 'Revenu net';

  @override
  String get soaHousing => 'Logement';

  @override
  String get soaDebtRepayment => 'Remboursement dettes';

  @override
  String get soaAvailable => 'Disponible';

  @override
  String get soaImportant => 'IMPORTANT:';

  @override
  String get soaDisclaimer1 =>
      'Ceci est un outil éducatif, ne constitue pas un conseil financier (LSFin).';

  @override
  String get soaDisclaimer2 =>
      'Les montants sont basés sur les informations déclarées.';

  @override
  String get soaDisclaimer3 =>
      '\'Disponible\' = Revenus - Logement - Dettes - Impôts - LAMal - Charges fixes.';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get profileCompleteBanner =>
      'Profil complet ! Ton coach dispose de toutes les données pour des conseils fiables.';

  @override
  String get profileAnnualRefreshTitle => 'Mise à jour annuelle';

  @override
  String get profileAnnualRefreshBody =>
      'Tes données datent de plus de 10 mois. Un check-up rapide (2 min) fiabilise ton plan.';

  @override
  String get profileAnnualRefreshCta => 'Lancer le check-up';

  @override
  String get profileDangerZoneTitle => 'Zone sensible';

  @override
  String get profileDangerZoneSubtitle =>
      'Réinitialise ton historique financier local sans supprimer ton compte.';

  @override
  String get profileResetDialogTitle => 'Réinitialiser ma situation ?';

  @override
  String get profileResetDialogBody =>
      'Cette action supprime ton diagnostic, tes check-ins, ton score et ton budget local.';

  @override
  String get profileResetDialogConfirmLabel => 'Tape RESET pour confirmer :';

  @override
  String get profileResetDialogInvalid => 'Mot-clé invalide.';

  @override
  String get profileResetDialogAction => 'Réinitialiser';

  @override
  String get profileResetSuccess => 'Historique financier local réinitialisé.';

  @override
  String get profileResetScopeNote =>
      'Conserve la connexion et la clé BYOK. Les documents backend ne sont pas supprimés.';

  @override
  String get coachPulseTitle => 'Coach Pulse';

  @override
  String get coachIaBadge => 'Coach IA';

  @override
  String get agirCoachPulseDone =>
      'Tu es à jour ce mois-ci. Priorise maintenant l\'action la plus impactante.';

  @override
  String get agirCoachPulsePending =>
      'Ton check-in mensuel est la prochaine action critique pour garder ta trajectoire fiable.';

  @override
  String agirCoachPulseWhyNow(String reason) {
    return 'Pourquoi maintenant: $reason';
  }

  @override
  String get agirScenarioBriefTitle => 'Scénarios de retraite en bref';

  @override
  String agirScenarioBriefSummary(
      String years, String baseCapital, String replacement, String gapCapital) {
    return 'Dans ~$years ans, ton scénario Base vise $baseCapital (~$replacement% de remplacement). L\'écart Prudent vs Optimiste est $gapCapital.';
  }

  @override
  String get agirScenarioBriefCta => 'Ouvrir la simulation complète';

  @override
  String get advisorMiniWeekOneCta => 'Lancer ma semaine 1';

  @override
  String get advisorMiniStartWithDashboard => 'Commencer avec le dashboard';

  @override
  String get advisorMiniCoachIntroChallenge =>
      'Objectif: passer de l\'analyse à l\'action cette semaine. On commence maintenant avec 3 priorités.';

  @override
  String get checkinScoreReasonStable =>
      'Score stable ce mois: continue la régularité de tes actions.';

  @override
  String checkinScoreReasonPositiveContrib(String amount) {
    return 'Hausse principale: versements confirmés ($amount) ce mois.';
  }

  @override
  String get checkinScoreReasonPositiveIncome =>
      'Hausse principale: revenu exceptionnel ajouté ce mois.';

  @override
  String get checkinScoreReasonPositiveGeneral =>
      'Hausse principale: progression globale de ta discipline financière.';

  @override
  String checkinScoreReasonNegativeExpense(String amount) {
    return 'Baisse principale: dépenses exceptionnelles ce mois ($amount).';
  }

  @override
  String checkinScoreReasonNegativeContrib(String amount) {
    return 'Baisse principale: réduction de tes versements planifiés ($amount/mois).';
  }

  @override
  String get checkinScoreReasonNegativeGeneral =>
      'Baisse temporaire ce mois. On ajuste le plan au prochain check-in.';

  @override
  String get checkinImpactPending => 'Impact en cours de calcul';

  @override
  String get coachDataQualityTitle => 'Qualite des donnees';

  @override
  String coachDataQualityBody(String dataPoints, String percentage) {
    return 'Calcul actuel: $dataPoints donnees saisies ($percentage%). Les postes non renseignes restent en estimation jusqu au diagnostic complet.';
  }

  @override
  String get coachShockTitle => 'Tes chiffres-chocs';

  @override
  String get coachShockSubtitle =>
      'Des montants personnalises pour eclairer tes decisions';

  @override
  String get coachScenarioDecodedTitle => 'Tes scenarios decryptes';

  @override
  String get coachBadgeStatic => 'Coach';

  @override
  String get agirActionsRecommendedTitle => 'Actions recommandees';

  @override
  String get agirActionsRecommendedSubtitle => 'Triees par priorite';

  @override
  String get profileCoachKnowledgeTitle => 'Ce que MINT sait de toi';

  @override
  String get profileStateFull => 'Profil complet';

  @override
  String get profileStatePartial => 'Profil partiel';

  @override
  String get profileStateMissing => 'Profil non renseigne';

  @override
  String profileCoachKnowledgeSummary(String profileState, String precision,
      String checkins, String scorePart) {
    return '$profileState • Precision $precision% • Check-ins: $checkins$scorePart';
  }

  @override
  String get profileChipEntered => 'saisi';

  @override
  String get profileChipEstimated => 'estime';

  @override
  String get profileChipToComplete => 'a completer';

  @override
  String get coachNarrativeModeConcise => 'Court';

  @override
  String get coachNarrativeModeDetailed => 'Detail';

  @override
  String get advisorMiniMetricsWinnerLive => 'Winner live';

  @override
  String get advisorMiniMetricsUplift => 'Uplift challenge vs control';

  @override
  String get advisorMiniMetricsSignal => 'Signal';

  @override
  String get advisorMiniMetricsSignalInsufficient =>
      'Attendre >=10 starts par variante';

  @override
  String get profileCoachMonthlyTitle => 'Resume coach du mois';

  @override
  String get profileCoachMonthlyTrendInsufficient =>
      'Pas encore assez de check-ins pour une tendance mensuelle.';

  @override
  String profileCoachMonthlyTrendUp(String delta) {
    return '+$delta points ce mois, bonne dynamique.';
  }

  @override
  String profileCoachMonthlyTrendDown(String delta) {
    return '-$delta points ce mois, on ajuste tes priorites.';
  }

  @override
  String get profileCoachMonthlyTrendFlat =>
      'Score stable ce mois, continue le rythme.';

  @override
  String profileCoachMonthlyByokPrefix(String trend) {
    return 'Lecture coach IA: $trend';
  }

  @override
  String get profileCoachMonthlyActionComplete =>
      'Prochaine étape: compléter ton diagnostic pour fiabiliser les recommandations.';

  @override
  String get profileCoachMonthlyActionCheckin =>
      'Prochaine étape: faire ton check-in mensuel pour recalibrer le plan.';

  @override
  String get profileCoachMonthlyActionAgir =>
      'Prochaine étape: exécuter une action prioritaire dans Agir.';

  @override
  String get profileGuidanceTitle => 'Section recommandee';

  @override
  String profileGuidanceBody(String section) {
    return 'Complete maintenant $section pour fiabiliser ton plan.';
  }

  @override
  String profileGuidanceCta(String section) {
    return 'Completer $section';
  }

  @override
  String get advisorMiniMetricsLiveTitle => 'Qualite onboarding live';

  @override
  String get advisorMiniMetricsLiveStep => 'Step courant';

  @override
  String get advisorMiniMetricsLiveQuality => 'Score qualite';

  @override
  String get advisorMiniMetricsLiveNext => 'Section recommandee';

  @override
  String get coachPersonaPriorityCouple => 'Priorité couple';

  @override
  String get coachPersonaPriorityFamily => 'Priorité famille';

  @override
  String get coachPersonaPrioritySingleParent => 'Priorité parent solo';

  @override
  String get coachPersonaPrioritySingle => 'Priorité personnelle';

  @override
  String get coachWizardSectionIdentity => 'Identité & foyer';

  @override
  String get coachWizardSectionIncome => 'Revenu & foyer';

  @override
  String get coachWizardSectionPension => 'Prévoyance';

  @override
  String get coachWizardSectionProperty => 'Immobilier & dettes';

  @override
  String coachPersonaGuidanceCouple(String section) {
    return 'Pour fiabiliser tes projections foyer, complete maintenant la section $section.';
  }

  @override
  String coachPersonaGuidanceSingleParent(String section) {
    return 'Ton plan depend de la protection du foyer. Complete maintenant la section $section.';
  }

  @override
  String coachPersonaGuidanceSingle(String section) {
    return 'Pour personnaliser ton plan coach, complete maintenant la section $section.';
  }

  @override
  String coachEnrichTargetTitle(String current, String target) {
    return 'Passe de $current% a $target% de precision';
  }

  @override
  String get coachEnrichBodyIdentity =>
      'Ajoute les bases identite/foyer pour activer des calculs fiables des aujourd hui.';

  @override
  String get coachEnrichBodyIncome =>
      'Complete revenus et structure du foyer pour des recommandations vraiment personnalisees.';

  @override
  String get coachEnrichBodyPension =>
      'Renseigne AVS/LPP/3a pour une projection retraite exploitable.';

  @override
  String get coachEnrichBodyProperty =>
      'Ajoute immobilier et dettes pour calibrer ton budget et ton risque reel.';

  @override
  String get coachEnrichBodyDefault =>
      'Le diagnostic complet prend 10 minutes et deverrouille ta trajectoire personnalisee.';

  @override
  String get coachEnrichActionIdentity => 'Compléter Identité & foyer';

  @override
  String get coachEnrichActionIncome => 'Completer Revenu & foyer';

  @override
  String get coachEnrichActionPension => 'Compléter Prévoyance';

  @override
  String get coachEnrichActionProperty => 'Completer Immobilier & dettes';

  @override
  String get coachEnrichActionDefault => 'Completer mon diagnostic';

  @override
  String coachAgirPartialTitle(String quality) {
    return 'Plan en construction ($quality%)';
  }

  @override
  String coachAgirPartialBody(String section) {
    return 'Pour activer tes actions prioritaires, complete maintenant la section $section.';
  }

  @override
  String coachAgirPartialAction(String section) {
    return 'Completer $section';
  }

  @override
  String get landingTagline => 'Ton coach financier suisse';

  @override
  String get landingRegister => 'S\'inscrire';

  @override
  String get landingHeroRetirementNow1 => 'Ta retraite,';

  @override
  String get landingHeroRetirementNow2 => 'c\'est maintenant.';

  @override
  String landingHeroCountdown1(String years) {
    return 'Dans $years ans,';
  }

  @override
  String get landingHeroCountdown1Single => 'Dans 1 an,';

  @override
  String get landingHeroCountdown2 => 'ta retraite commence.';

  @override
  String get landingHeroSubtitle =>
      'La plupart des Suisses découvrent leur écart de retraite trop tard.';

  @override
  String get landingSliderAge => 'Ton âge';

  @override
  String landingSliderAgeSuffix(String age) {
    return '$age ans';
  }

  @override
  String get landingSliderSalary => 'Ton salaire brut';

  @override
  String landingSliderSalarySuffix(String amount) {
    return '$amount CHF/an';
  }

  @override
  String get landingToday => 'Aujourd\'hui';

  @override
  String get landingChfPerMonth => 'CHF/mois';

  @override
  String get landingAtRetirement => 'À la retraite*';

  @override
  String landingDropPurchasingPower(String percent) {
    return '-$percent% de pouvoir d\'achat';
  }

  @override
  String landingLppCapNotice(String amount) {
    return 'Au-delà de $amount CHF/an, la rente obligatoire est plafonnée.';
  }

  @override
  String landingHookHigh(String amount) {
    return 'Un écart de $amount/mois, c\'est significatif. MINT t\'aide à comprendre où agir.';
  }

  @override
  String get landingHookMedium =>
      'Ton gap est gérable. MINT te montre les leviers concrets (rachat LPP, 3a, retraite anticipée).';

  @override
  String get landingHookLow =>
      'Tu es en bonne posture. MINT te montre comment maintenir le cap et optimiser tes piliers.';

  @override
  String get landingWhyMint => 'Pourquoi MINT ?';

  @override
  String get landingFeaturePillarsTitle =>
      'Tous tes piliers, un seul tableau de bord';

  @override
  String get landingFeaturePillarsSubtitle =>
      'AVS, LPP et 3a calculés selon ta situation réelle — pas des moyennes suisses.';

  @override
  String get landingFeatureCoachTitle => 'Coach adapté à ton stade de vie';

  @override
  String get landingFeatureCoachSubtitle =>
      '25 ans ou 60 ans, frontalier ou indépendant — les conseils changent selon qui tu es.';

  @override
  String get landingFeaturePrivacyTitle =>
      '100% privé, données sur ton appareil';

  @override
  String get landingFeaturePrivacySubtitle =>
      'Aucun partage, aucune pub. Ton profil reste local sauf si tu crées un compte.';

  @override
  String get landingTrustSwiss => 'Conçu en Suisse';

  @override
  String get landingTrustPrivate => '100% privé';

  @override
  String get landingTrustNoCommitment => 'Sans engagement';

  @override
  String get landingCtaTitle => 'Ton plan en 30 secondes';

  @override
  String get landingCtaSubtitle => '3 questions • Gratuit • Sans engagement';

  @override
  String get landingLegalFooter =>
      '*Estimation indicative (1er + 2e pilier), basée sur le salaire actuel comme proxy de carrière. Ne constitue pas un conseil financier au sens de la LSFin. Tes données restent sur ton appareil.';

  @override
  String get onboardingConsentTitle => 'Sauvegarde locale des réponses';

  @override
  String get onboardingConsentBody =>
      'Tes réponses peuvent être sauvegardées localement sur ton appareil pour reprendre plus tard. Aucune donnée n\'est envoyée sans ton accord.';

  @override
  String get onboardingConsentAllow => 'Autoriser';

  @override
  String get onboardingConsentContinueWithout => 'Continuer sans sauvegarde';

  @override
  String get profileBilanTitle => 'Mon aperçu financier';

  @override
  String get profileBilanSubtitleComplete =>
      'Revenus, prévoyance, patrimoine, dettes';

  @override
  String get profileBilanSubtitleIncomplete =>
      'Complète ton profil pour voir tes chiffres';

  @override
  String get profileFamilyTitle => 'Famille';

  @override
  String get profileHouseholdTitle => 'Notre ménage';

  @override
  String get profileHouseholdStatus => 'Couple+';

  @override
  String get profileAiSlmTitle => 'IA on-device (SLM)';

  @override
  String get profileAiSlmReady => 'Modèle prêt';

  @override
  String get profileAiSlmNotInstalled => 'Modèle non installé';

  @override
  String get profileLanguageTitle => 'Langue';

  @override
  String get profileAdminObservability => 'Admin observability';

  @override
  String get profileAdminAnalytics => 'Analytics beta testeurs';

  @override
  String get profileDeleteCloudAccount => 'Supprimer mon compte cloud';

  @override
  String get profileDeleteCloudTitle => 'Supprimer le compte ?';

  @override
  String get profileDeleteCloudBody =>
      'Cette action supprime ton compte cloud et les données associées. Tes données locales restent sur cet appareil.';

  @override
  String get profileDeleteCloudConfirm => 'Supprimer';

  @override
  String get profileDeleteCloudSuccess => 'Compte supprimé avec succès.';

  @override
  String get profileDeleteCloudError =>
      'Suppression impossible pour le moment. Réessaie plus tard.';

  @override
  String get dashboardDefaultUserName => 'Toi';

  @override
  String get dashboardDefaultConjointName => 'Conjoint·e';

  @override
  String get dashboardGoalRetirement => 'Retraite';

  @override
  String dashboardAppBarWithName(String firstName) {
    return 'Retraite · $firstName';
  }

  @override
  String get dashboardAppBarDefault => 'Mon tableau de bord';

  @override
  String get dashboardMyData => 'Mes données';

  @override
  String get dashboardQuickStartTitle =>
      'Découvre ta projection en 30 secondes';

  @override
  String get dashboardQuickStartBody =>
      '4 infos suffisent pour estimer ton revenu à la retraite. Tu pourras affiner avec des documents et des détails.';

  @override
  String get dashboardQuickStartCta => 'Commencer';

  @override
  String get dashboardEnrichScanTitle => 'Scanne ton certificat LPP';

  @override
  String get dashboardEnrichScanImpact => '+20 pts de précision';

  @override
  String get dashboardEnrichCoachTitle => 'Parle au Coach';

  @override
  String get dashboardEnrichCoachImpact => 'Réponds à tes questions';

  @override
  String get dashboardEnrichSimTitle => 'Simule un scénario';

  @override
  String get dashboardEnrichSimImpact => '3a, LPP, hypothèque...';

  @override
  String get dashboardNextSteps => 'Prochaines étapes';

  @override
  String get dashboardEduTitle => 'Le système de retraite suisse';

  @override
  String get dashboardEduAvs => '1er pilier — AVS';

  @override
  String get dashboardEduAvsDesc =>
      'Base obligatoire pour tous. Financé par tes cotisations (LAVS art. 21).';

  @override
  String get dashboardEduLpp => '2ème pilier — LPP';

  @override
  String get dashboardEduLppDesc =>
      'Prévoyance professionnelle via ta caisse de pension (LPP art. 14).';

  @override
  String get dashboardEdu3a => '3ème pilier — 3a';

  @override
  String get dashboardEdu3aDesc =>
      'Épargne volontaire avec déduction fiscale (OPP3 art. 7).';

  @override
  String get dashboardDisclaimer =>
      'Outil éducatif simplifié. Ne constitue pas un conseil financier (LSFin). Sources : LAVS art. 21-29, LPP art. 14, OPP3 art. 7.';

  @override
  String get dashboardCockpitLink => 'Cockpit détaillé';

  @override
  String dashboardImpactEstimate(String amount) {
    return 'Impact estimé : CHF $amount';
  }

  @override
  String get dashboardMetricMonthlyIncome => 'Revenu mensuel';

  @override
  String get dashboardMetricChfMonth => 'CHF/mois';

  @override
  String get dashboardMetricReplacementRate => 'Taux de remplacement';

  @override
  String get dashboardMetricRetirementDuration => 'Durée retraite estimée';

  @override
  String get dashboardMetricYears => 'ans';

  @override
  String get dashboardMetricLifeExpectancy =>
      'Espérance de vie estimée : 85 ans';

  @override
  String get dashboardMetricMonthlyGap => 'Écart mensuel';

  @override
  String get dashboardMetricVsTarget => 'Vs cible 70% du salaire brut';

  @override
  String get dashboardNextActionLabel => 'Améliorer ta précision';

  @override
  String get dashboardNextActionDetail =>
      'Scanne ton certificat LPP pour affiner tes projections.';

  @override
  String get dashboardWeatherSunny => 'Marchés favorables, épargne maximisée.';

  @override
  String get dashboardWeatherPartlyCloudy =>
      'Trajectoire actuelle, quelques ajustements.';

  @override
  String get dashboardWeatherRainy => 'Chocs de marché ou lacunes AVS/LPP.';

  @override
  String get dashboardAgeBandYoungTitle => 'Ton levier principal : le 3a';

  @override
  String get dashboardAgeBandYoungSubtitle =>
      'Chaque franc versé maintenant travaille 40 ans. Ouvrir ton 3a coûte 15 minutes.';

  @override
  String get dashboardAgeBandYoungCta => 'Simuler mon 3a';

  @override
  String get dashboardAgeBandStabTitle => '3a + protection famille';

  @override
  String get dashboardAgeBandStabSubtitle =>
      'Logement, couverture décès/invalidité : c\'est maintenant que l\'architecture se construit.';

  @override
  String get dashboardAgeBandStabCta => 'Voir les simulateurs';

  @override
  String get dashboardAgeBandPeakTitle => 'Rachat LPP + optimisation fiscale';

  @override
  String get dashboardAgeBandPeakSubtitle =>
      'Tes revenus sont au pic — c\'est la fenêtre pour réduire l\'écart de retraite.';

  @override
  String get dashboardAgeBandPeakCta => 'Simuler un rachat';

  @override
  String get dashboardAgeBandPreRetTitle => 'Ton gap retraite en CHF/mois';

  @override
  String get dashboardAgeBandPreRetSubtitle =>
      'Rente vs capital, retraite anticipée, rachat échelonné : les décisions se rapprochent.';

  @override
  String get dashboardAgeBandPreRetCta => 'Rente vs Capital';

  @override
  String get dashboardAgeBandRetWithdrawTitle => 'Ordre de retrait 3a';

  @override
  String get dashboardAgeBandRetWithdrawSubtitle =>
      'Échelonner tes retraits 3a sur 3–5 ans réduit l\'impôt de manière significative selon le canton.';

  @override
  String get dashboardAgeBandRetWithdrawCta => 'Planifier mes retraits';

  @override
  String get dashboardAgeBandRetSuccessionTitle => 'Succession & transmission';

  @override
  String get dashboardAgeBandRetSuccessionSubtitle =>
      'Testament, donation du vivant, bénéficiaires LPP : protéger ceux que tu aimes.';

  @override
  String get dashboardAgeBandRetSuccessionCta => 'Explorer';

  @override
  String get agirResetTooltip => 'Réinitialiser';

  @override
  String get agirResetHistoryLabel => 'Réinitialiser mon historique coach';

  @override
  String get agirResetDiagnosticLabel => 'Recommencer mon diagnostic';

  @override
  String get agirResetHistoryTitle => 'Réinitialiser ton historique coach ?';

  @override
  String get agirResetHistoryMessage =>
      'Cela supprime tes check-ins, ton historique de score et la progression des simulateurs.';

  @override
  String get agirResetHistoryCta => 'Réinitialiser';

  @override
  String get agirResetDiagnosticTitle => 'Recommencer ton diagnostic ?';

  @override
  String get agirResetDiagnosticMessage =>
      'Cela supprime ton diagnostic actuel et tes réponses mini-onboarding.';

  @override
  String get agirResetDiagnosticCta => 'Recommencer';

  @override
  String get agirHistoryResetSnackbar => 'Historique coach réinitialisé.';

  @override
  String get agirSwipeDone => 'Fait';

  @override
  String get agirSwipeSnooze => 'Reporter 30j';

  @override
  String agirSwipeDoneSnackbar(String title) {
    return '$title — marqué comme fait';
  }

  @override
  String agirSwipeSnoozeSnackbar(String title) {
    return '$title — reporté de 30 jours';
  }

  @override
  String get agirDependencyDebt => 'Après : remboursement dette';

  @override
  String get agirEmptyTitle => 'Ton plan d\'action t\'attend';

  @override
  String get agirEmptyBody =>
      'Complète ton diagnostic pour obtenir un plan mensuel personnalisé basé sur ta situation réelle.';

  @override
  String get agirEmptyLaunchCta => 'Lancer mon diagnostic — 10 min';

  @override
  String get agirNoContribTitle => 'Aucun versement planifié';

  @override
  String get agirNoContribBody =>
      'Fais ton premier check-in pour configurer tes versements mensuels.';

  @override
  String get agirNoContribCta => 'Configurer mes versements';

  @override
  String get agirProgressTitle => 'Progression annuelle';

  @override
  String agirProgressSubtitle(String year) {
    return 'Planifié vs versé en $year';
  }

  @override
  String get agirConfirmLabel => 'À confirmer';

  @override
  String agirVersesLabel(String amount) {
    return '$amount versés';
  }

  @override
  String agirObjectifLabel(String amount) {
    return 'Objectif : $amount';
  }

  @override
  String get agirPriorityImmediate => 'Priorité immédiate';

  @override
  String get agirPriorityTrimestre => 'Ce trimestre';

  @override
  String get agirPriorityAnnee => 'Cette année';

  @override
  String get agirPriorityLongTerme => 'Long terme';

  @override
  String get agirTimelineCheckinTitle => 'Check-in mensuel';

  @override
  String get agirTimelineCheckinDone =>
      'Fait — versements confirmés pour ce mois.';

  @override
  String get agirTimelineCheckinPending =>
      'Confirme tes versements du mois en 2 min.';

  @override
  String get agirTimelineCheckinCta => 'Faire mon check-in';

  @override
  String agirTimelineRetirementTitle(String name) {
    return 'Retraite $name (65 ans)';
  }

  @override
  String get agirTimelineThisMonth => 'Ce mois';

  @override
  String agirTimelineInMonths(String months) {
    return 'dans $months mois';
  }

  @override
  String agirTimelineInYears(String years) {
    return 'dans $years ans';
  }

  @override
  String get agirTimelineInOneYear => 'dans 1 an';

  @override
  String get agirPerYear => '/an';

  @override
  String get agirCoachPulseWhyDefault =>
      'Commence par une action simple pour enclencher ta dynamique.';

  @override
  String get checkinScoreTitle => 'Ton score financier';

  @override
  String checkinScorePositive(String delta) {
    return '+$delta pts — tes actions portent leurs fruits !';
  }

  @override
  String checkinScoreNegative(String delta) {
    return '$delta pts — continue, chaque mois compte';
  }

  @override
  String get budgetEmptyTitle => 'Ton budget se construit automatiquement';

  @override
  String get budgetEmptyBody =>
      'Complète ton diagnostic pour débloquer ton plan mensuel avec tes vrais revenus et charges.';

  @override
  String get budgetEmptyAction => 'Faire mon diagnostic';

  @override
  String get budgetMonthlyTitle => 'Budget mensuel';

  @override
  String get budgetAvailableThisMonth => 'Disponible ce mois';

  @override
  String get budgetNetIncome => 'Revenu net';

  @override
  String get budgetHousing => 'Logement';

  @override
  String get budgetDebtRepayment => 'Remboursement dettes';

  @override
  String get budgetDebts => 'Dettes';

  @override
  String get budgetTaxProvision => 'Provision impôts';

  @override
  String get budgetHealthInsurance => 'Primes maladie (LAMal)';

  @override
  String get budgetOtherFixed => 'Autres charges fixes';

  @override
  String get budgetNotProvided => '(non renseigné)';

  @override
  String get budgetQualityEstimated => 'estimé';

  @override
  String get budgetQualityEntered => 'saisi';

  @override
  String get budgetQualityMissing => 'manquant';

  @override
  String get budgetAvailable => 'Disponible';

  @override
  String get budgetMissingDataBanner =>
      'Certaines charges sont encore manquantes. Complète ton diagnostic pour fiabiliser ce budget.';

  @override
  String get budgetEstimatedDataBanner =>
      'Ce budget inclut des estimations (impôts/LAMal). Renseigne tes montants réels pour une projection plus fiable.';

  @override
  String get budgetCompleteData => 'Compléter mes données →';

  @override
  String get budgetEnvelopeFuture => '🔒 Futur (Épargne, Projets)';

  @override
  String get budgetEnvelopeVariables => '🛍️ Variables (Vivre)';

  @override
  String get budgetNeeds => 'Besoins';

  @override
  String get budgetLife => 'Vie';

  @override
  String get budgetFuture => 'Futur';

  @override
  String get budgetVariables => 'Variables';

  @override
  String get budgetExampleRent => 'Loyer';

  @override
  String get budgetExampleLamal => 'LAMal';

  @override
  String get budgetExampleTaxes => 'impôts';

  @override
  String get budgetExampleDebts => 'dettes';

  @override
  String get budgetExampleFood => 'Alimentation';

  @override
  String get budgetExampleTransport => 'transport';

  @override
  String get budgetExampleLeisure => 'loisirs';

  @override
  String get budgetExampleSavings => 'Épargne';

  @override
  String get budgetExampleProjects => 'projets';

  @override
  String budgetChiffreChoc503020(String monthly, String total) {
    return 'En épargnant CHF $monthly/mois, tu accumules CHF $total en 10 ans.';
  }

  @override
  String get budgetEmergencyFund => 'Fonds d\'urgence';

  @override
  String get budgetEmergencyGoalReached => 'Objectif atteint';

  @override
  String get budgetEmergencyOnTrack => 'En bonne voie';

  @override
  String get budgetEmergencyToReinforce => 'A renforcer';

  @override
  String budgetEmergencyMonthsCovered(String months) {
    return '$months mois couverts';
  }

  @override
  String budgetEmergencyTarget(String target) {
    return 'Cible : $target mois';
  }

  @override
  String get budgetEmergencyComplete =>
      'Tu es protégé·e contre les imprévus. Continue ainsi.';

  @override
  String budgetEmergencyIncomplete(String target) {
    return 'Épargne au moins $target mois de dépenses pour te protéger contre un imprévu (perte d\'emploi, réparation...).';
  }

  @override
  String get budgetDisclaimerTitle => 'IMPORTANT :';

  @override
  String get budgetDisclaimerEducational =>
      '• Ceci est un outil éducatif, ne constitue pas un conseil financier (LSFin).';

  @override
  String get budgetDisclaimerDeclarative =>
      '• Les montants sont basés sur les informations déclarées.';

  @override
  String get budgetDisclaimerFormula =>
      '• \'Disponible\' = Revenus - Logement - Dettes - Impôts - LAMal - Charges fixes.';

  @override
  String get toolsAllTools => 'Tous les outils';

  @override
  String get toolsSearchHint => 'Chercher un outil...';

  @override
  String toolsToolCount(String count) {
    return '$count outils';
  }

  @override
  String toolsCategoryCount(String count) {
    return '$count catégories';
  }

  @override
  String get toolsClear => 'Effacer';

  @override
  String get toolsNoResults => 'Aucun outil trouvé';

  @override
  String get toolsNoResultsHint => 'Essaie avec d\'autres mots-clés';

  @override
  String get toolsCatPrevoyance => 'Prévoyance';

  @override
  String get toolsRetirementPlanner => 'Planificateur retraite';

  @override
  String get toolsRetirementPlannerDesc => 'Simule ta retraite AVS + LPP + 3a';

  @override
  String get toolsSimulator3a => 'Simulateur 3a';

  @override
  String get toolsSimulator3aDesc => 'Calcule ton économie fiscale annuelle';

  @override
  String get toolsComparator3a => 'Comparateur 3a';

  @override
  String get toolsComparator3aDesc =>
      'Compare les providers (banque vs assurance)';

  @override
  String get toolsRealReturn3a => 'Rendement réel 3a';

  @override
  String get toolsRealReturn3aDesc => 'Rendement net après frais et inflation';

  @override
  String get toolsStaggeredWithdrawal3a => 'Retrait échelonné 3a';

  @override
  String get toolsStaggeredWithdrawal3aDesc =>
      'Optimise le retrait sur plusieurs années';

  @override
  String get toolsRenteVsCapital => 'Rente vs Capital';

  @override
  String get toolsRenteVsCapitalDesc =>
      'Compare rente LPP et retrait du capital';

  @override
  String get toolsRachatLpp => 'Rachat échelonné LPP';

  @override
  String get toolsRachatLppDesc =>
      'Optimise tes rachats LPP sur plusieurs années';

  @override
  String get toolsLibrePassage => 'Libre passage';

  @override
  String get toolsLibrePassageDesc =>
      'Checklist changement d\'emploi ou départ';

  @override
  String get toolsDisabilityGap => 'Filet de sécurité';

  @override
  String get toolsDisabilityGapDesc => 'Simule ton gap invalidité/décès';

  @override
  String get toolsGenderGap => 'Gender gap prévoyance';

  @override
  String get toolsGenderGapDesc => 'Impact du temps partiel sur ta retraite';

  @override
  String get toolsCatFamily => 'Famille';

  @override
  String get toolsMarriage => 'Mariage & fiscalité';

  @override
  String get toolsMarriageDesc =>
      'Pénalité/bonus du mariage + régimes + survivant';

  @override
  String get toolsBirth => 'Naissance & famille';

  @override
  String get toolsBirthDesc => 'Congé parental, allocations, impact fiscal';

  @override
  String get toolsConcubinage => 'Mariage vs Concubinage';

  @override
  String get toolsConcubinageDesc => 'Comparateur + checklist de protection';

  @override
  String get toolsDivorce => 'Simulateur divorce';

  @override
  String get toolsDivorceDesc => 'Impact financier du divorce sur la LPP';

  @override
  String get toolsSuccession => 'Simulateur succession';

  @override
  String get toolsSuccessionDesc => 'Calcule les parts légales et impôts';

  @override
  String get toolsCatEmployment => 'Emploi';

  @override
  String get toolsFirstJob => 'Premier emploi';

  @override
  String get toolsFirstJobDesc => 'Comprends ta fiche de salaire et tes droits';

  @override
  String get toolsUnemployment => 'Simulateur chômage';

  @override
  String get toolsUnemploymentDesc => 'Calcule tes indemnités et durée';

  @override
  String get toolsJobComparison => 'Comparateur d\'emploi';

  @override
  String get toolsJobComparisonDesc =>
      'Compare deux offres (net + LPP + avantages)';

  @override
  String get toolsSelfEmployed => 'Indépendant';

  @override
  String get toolsSelfEmployedDesc => 'Couverture sociale et protection';

  @override
  String get toolsAvsContributions => 'Cotisations AVS indép.';

  @override
  String get toolsAvsContributionsDesc => 'Calcule tes cotisations AVS/AI/APG';

  @override
  String get toolsIjm => 'Assurance IJM';

  @override
  String get toolsIjmDesc => 'Indemnité journalière maladie';

  @override
  String get tools3aSelfEmployed => '3a indépendant';

  @override
  String get tools3aSelfEmployedDesc => 'Plafond majoré pour indépendants';

  @override
  String get toolsDividendVsSalary => 'Dividende vs Salaire';

  @override
  String get toolsDividendVsSalaryDesc => 'Optimise ta rémunération en SA/Sàrl';

  @override
  String get toolsLppVoluntary => 'LPP volontaire';

  @override
  String get toolsLppVoluntaryDesc =>
      'Prévoyance facultative pour indépendants';

  @override
  String get toolsCrossBorder => 'Frontalier';

  @override
  String get toolsCrossBorderDesc => 'Impôt source, 90 jours, charges sociales';

  @override
  String get toolsExpatriation => 'Expatriation';

  @override
  String get toolsExpatriationDesc => 'Forfait fiscal, départ, lacunes AVS';

  @override
  String get toolsCatRealEstate => 'Immobilier';

  @override
  String get toolsAffordability => 'Capacité d\'achat';

  @override
  String get toolsAffordabilityDesc =>
      'Calcule le prix max que tu peux acheter';

  @override
  String get toolsAmortization => 'Plan d\'amortissement';

  @override
  String get toolsAmortizationDesc =>
      'Échéancier de remboursement hypothécaire';

  @override
  String get toolsSaronVsFixed => 'SARON vs Fixe';

  @override
  String get toolsSaronVsFixedDesc => 'Compare les types d\'hypothèque';

  @override
  String get toolsImputedRental => 'Valeur locative';

  @override
  String get toolsImputedRentalDesc => 'Estime la valeur locative imputée';

  @override
  String get toolsEplCombined => 'EPL combiné';

  @override
  String get toolsEplCombinedDesc => 'Retrait anticipé LPP + 3a pour logement';

  @override
  String get toolsEplLpp => 'Retrait EPL (LPP)';

  @override
  String get toolsEplLppDesc => 'Financer un logement avec ton 2e pilier';

  @override
  String get toolsCatTax => 'Fiscalité';

  @override
  String get toolsFiscalComparator => 'Comparateur fiscal';

  @override
  String get toolsFiscalComparatorDesc =>
      'Compare ta charge fiscale entre cantons';

  @override
  String get toolsCompoundInterest => 'Intérêts composés';

  @override
  String get toolsCompoundInterestDesc =>
      'Visualise la croissance de ton épargne';

  @override
  String get toolsCatHealth => 'Santé';

  @override
  String get toolsLamalDeductible => 'Franchise LAMal';

  @override
  String get toolsLamalDeductibleDesc => 'Trouve la franchise idéale pour toi';

  @override
  String get toolsCoverageCheckup => 'Check-up couverture';

  @override
  String get toolsCoverageCheckupDesc => 'Évalue ta protection assurantielle';

  @override
  String get toolsCatBudgetDebt => 'Budget & Dettes';

  @override
  String get toolsBudget => 'Budget';

  @override
  String get toolsBudgetDesc => 'Planifie et suis tes dépenses mensuelles';

  @override
  String get toolsDebtCheck => 'Check dette';

  @override
  String get toolsDebtCheckDesc => 'Évalue ton risque de surendettement';

  @override
  String get toolsDebtRatio => 'Ratio d\'endettement';

  @override
  String get toolsDebtRatioDesc => 'Diagnostic visuel de ta situation';

  @override
  String get toolsRepaymentPlan => 'Plan de remboursement';

  @override
  String get toolsRepaymentPlanDesc => 'Stratégie adaptée pour rembourser';

  @override
  String get toolsDebtHelp => 'Aide et ressources';

  @override
  String get toolsDebtHelpDesc => 'Contacts et organismes de soutien';

  @override
  String get toolsConsumerCredit => 'Crédit conso';

  @override
  String get toolsConsumerCreditDesc => 'Simule le coût réel d\'un crédit';

  @override
  String get toolsLeasing => 'Calculateur leasing';

  @override
  String get toolsLeasingDesc => 'Coût réel et alternatives au leasing';

  @override
  String get toolsCatBankDocs => 'Banque & Documents';

  @override
  String get toolsOpenBanking => 'Open Banking';

  @override
  String get toolsOpenBankingDesc => 'Connecte tes comptes bancaires';

  @override
  String get toolsBankImport => 'Import bancaire';

  @override
  String get toolsBankImportDesc => 'Importe tes relevés CSV/PDF';

  @override
  String get toolsDocuments => 'Mes documents';

  @override
  String get toolsDocumentsDesc => 'Certificats LPP et documents importants';

  @override
  String get toolsPortfolio => 'Portfolio';

  @override
  String get toolsPortfolioDesc => 'Vue d\'ensemble de ta situation';

  @override
  String get toolsTimeline => 'Timeline';

  @override
  String get toolsTimelineDesc => 'Tes échéances et rappels importants';

  @override
  String get toolsConsent => 'Consentements';

  @override
  String get toolsConsentDesc => 'Gère tes autorisations de données';

  @override
  String get vaultPremiumBadge => 'Premium';

  @override
  String get vaultExtractedFields => 'Champs extraits';

  @override
  String get vaultCancelButton => 'Annuler';

  @override
  String get vaultOkButton => 'OK';

  @override
  String get naissanceTitle => 'Naissance & famille';

  @override
  String get naissanceTabConge => 'Congé';

  @override
  String get naissanceTabAllocations => 'Allocations';

  @override
  String get naissanceTabImpact => 'Impact';

  @override
  String get naissanceTabChecklist => 'Checklist';

  @override
  String get naissanceLeaveType => 'Type de congé';

  @override
  String get naissanceMother => 'Mère';

  @override
  String get naissanceFather => 'Père';

  @override
  String get naissanceMonthlySalary => 'Salaire mensuel brut';

  @override
  String naissanceCongeLabel(String type) {
    return 'CONGÉ $type';
  }

  @override
  String naissanceWeeks(int count) {
    return '$count semaines';
  }

  @override
  String get naissanceApgPerDay => 'APG par jour';

  @override
  String get naissanceTotalApg => 'Total APG';

  @override
  String naissanceCappedAt(String amount) {
    return 'Plafonné à CHF $amount/jour';
  }

  @override
  String get naissanceDailyDetail => 'DÉTAIL QUOTIDIEN';

  @override
  String get naissanceSalaryPerDay => 'Salaire/jour';

  @override
  String get naissanceApgDay => 'APG/jour';

  @override
  String get naissanceDiffPerDay => 'Différence/jour';

  @override
  String get naissanceNoLoss => 'Aucune perte';

  @override
  String naissanceTotalLossEstimated(String amount) {
    return 'Perte totale estimée sur le congé : $amount';
  }

  @override
  String naissanceChiffreChocText(String type, String amount, int weeks) {
    return 'Ton congé $type représente $amount d\'APG sur $weeks semaines';
  }

  @override
  String get naissanceMaternite => 'maternité';

  @override
  String get naissancePaternite => 'paternité';

  @override
  String get naissanceCongeEducational =>
      'La Suisse a introduit le congé paternité en 2021 seulement. À 2 semaines, il reste l\'un des plus courts d\'Europe. Le congé maternité (14 semaines) existe depuis 2005.';

  @override
  String get naissanceCanton => 'Canton';

  @override
  String get naissanceNbEnfants => 'Nombre d\'enfants';

  @override
  String get naissanceRanking26 => 'ALLOCATIONS PAR CANTON';

  @override
  String naissanceBestCanton(String canton) {
    return '$canton offre parmi les allocations familiales les plus avantageuses de Suisse !';
  }

  @override
  String naissanceAllocDiff(String bestCanton, String canton, String amount) {
    return 'En habitant à $bestCanton au lieu de $canton, tu recevrais $amount de plus par an en allocations familiales.';
  }

  @override
  String get naissanceRevenuAnnuel => 'Revenu annuel brut';

  @override
  String get naissanceFraisGarde => 'Frais de garde mensuel/enfant';

  @override
  String get naissanceTaxSavings => 'Économies fiscales';

  @override
  String get naissanceDeductionPerChild => 'Déduction par enfant';

  @override
  String get naissanceDeductionChildcare => 'Déduction frais de garde';

  @override
  String get naissanceEstimatedTaxSaving => 'Économie fiscale estimée';

  @override
  String get naissanceAllowanceIncome => 'Revenu allocations';

  @override
  String get naissanceAnnualAllowances => 'Allocations annuelles';

  @override
  String get naissanceCareerImpact => 'Impact carrière (LPP)';

  @override
  String get naissanceEstimatedInterruption => 'Interruption estimée';

  @override
  String naissanceMonths(int count) {
    return '$count mois';
  }

  @override
  String get naissanceLppLossEstimated => 'Perte LPP estimée';

  @override
  String get naissanceLppLessContributions =>
      'Moins de cotisations LPP = moins de capital à la retraite';

  @override
  String get naissanceNetAnnualImpact => 'Impact net annuel estimé';

  @override
  String get naissanceNetFormula =>
      'Économies fiscales + allocations - coût estimé';

  @override
  String get naissanceWaterfallRevenu => 'Revenu brut annuel';

  @override
  String get naissanceWaterfallAlloc => 'Allocations familiales';

  @override
  String get naissanceWaterfallCosts => 'Coûts de base (est.)';

  @override
  String get naissanceWaterfallChildcare => 'Frais de garde annuels';

  @override
  String get naissanceWaterfallAfter => 'Après enfant(s)';

  @override
  String get naissanceChildCostEducational =>
      'Un enfant coûte en moyenne CHF 1\'500/mois en Suisse (alimentation, vêtements, activités, assurance). Mais les allocations et déductions fiscales réduisent significativement l\'impact net.';

  @override
  String get naissanceChecklistIntro =>
      'L\'arrivée d\'un enfant implique de nombreuses démarches administratives et financières. Voici les étapes à ne pas oublier.';

  @override
  String naissanceStepsCompleted(int done, int total) {
    return '$done/$total démarches effectuées';
  }

  @override
  String get naissanceDidYouKnow => 'Le savais-tu ?';

  @override
  String get naissanceDisclaimer =>
      'Estimations simplifiées à but éducatif — ne constitue pas un conseil en prévoyance ou conseil fiscal. Les montants dépendent de nombreux facteurs (canton, commune, situation familiale, etc.). Consulte un·e spécialiste pour un calcul personnalisé.';

  @override
  String get mariageTitle => 'Mariage & fiscalité';

  @override
  String get mariageTabImpots => 'Impôts';

  @override
  String get mariageTabRegime => 'Régime';

  @override
  String get mariageTabProtection => 'Protection';

  @override
  String get mariageRevenu1 => 'Revenu 1';

  @override
  String get mariageRevenu2 => 'Revenu 2';

  @override
  String get mariageCanton => 'Canton';

  @override
  String get mariageEnfants => 'Enfants';

  @override
  String get mariageFiscalComparison => 'COMPARAISON FISCALE';

  @override
  String get mariageTwoCelibataires => '2 célibataires';

  @override
  String get mariageMaries => 'Mariés';

  @override
  String mariagePenaltyAmount(String amount) {
    return 'Pénalité +$amount/an';
  }

  @override
  String mariageBonusAmount(String amount) {
    return 'Bonus -$amount/an';
  }

  @override
  String get mariageDeductions => 'DÉDUCTIONS MARIAGE';

  @override
  String get mariageDeductionCouple => 'Déduction couple marié';

  @override
  String get mariageDeductionInsurance => 'Déduction assurance (mariée)';

  @override
  String get mariageDeductionDualIncome => 'Déduction double revenu';

  @override
  String get mariageDeductionChildren => 'Déduction enfants';

  @override
  String get mariageTotalDeductions => 'Total déductions';

  @override
  String get mariageEducationalPenalty =>
      'Savais-tu que la pénalité du mariage touche ~700\'000 couples en Suisse ? Le Tribunal fédéral a jugé cette situation anticonstitutionnelle en 1984, mais elle n\'a toujours pas été corrigée.';

  @override
  String get mariageRegimeMatrimonial => 'RÉGIME MATRIMONIAL';

  @override
  String get mariageParticipation => 'Participation aux acquêts';

  @override
  String get mariageParticipationSub => 'Régime par défaut (CC art. 181)';

  @override
  String get mariageParticipationDesc =>
      'Chacun garde ses biens propres. Les acquêts (gains durant le mariage) sont partagés 50/50 en cas de dissolution.';

  @override
  String get mariageSeparation => 'Séparation de biens';

  @override
  String get mariageSeparationSub => 'CC art. 247';

  @override
  String get mariageSeparationDesc =>
      'Chacun conserve l\'intégralité de ses biens et de ses revenus. Aucun partage automatique.';

  @override
  String get mariageCommunaute => 'Communauté de biens';

  @override
  String get mariageCommunauteSub => 'CC art. 221';

  @override
  String get mariageCommunauteDesc =>
      'Tout est mis en commun : biens propres et acquêts. Partage égalitaire total en cas de dissolution.';

  @override
  String get mariagePatrimoine1 => 'Patrimoine Personne 1';

  @override
  String get mariagePatrimoine2 => 'Patrimoine Personne 2';

  @override
  String get mariageChiffreChocDefault =>
      'En régime par défaut, cette part de tes acquêts reviendrait à ton conjoint en cas de dissolution';

  @override
  String get mariageChiffreChocCommunaute =>
      'En communauté de biens, ce montant serait partagé avec ton conjoint';

  @override
  String get mariageProtectionIntro =>
      'Que se passe-t-il si l\'un de vous deux décède ? Compare la protection légale entre mariés et concubins.';

  @override
  String get mariageLppRenteLabel => 'Rente LPP mensuelle du défunt';

  @override
  String get mariageAvsSurvivor => 'Rente AVS de survivant';

  @override
  String get mariageAvsSurvivorSub => '80% de la rente maximale du défunt';

  @override
  String get mariageAvsSurvivorFootnote =>
      'LAVS art. 35 — uniquement pour les mariés';

  @override
  String get mariageLppSurvivor => 'Rente LPP de survivant';

  @override
  String get mariageLppSurvivorSub => '60% de la rente assurée du défunt';

  @override
  String get mariageLppSurvivorFootnote =>
      'LPP art. 19 — mariés (concubins : clause nécessaire)';

  @override
  String get mariageSurvivorMonthly => 'Revenu mensuel du survivant marié';

  @override
  String get mariageVsConcubin => 'MARIÉ VS CONCUBIN';

  @override
  String get mariageRenteAvsSurvivor => 'Rente AVS survivant';

  @override
  String get mariageRenteLppSurvivor => 'Rente LPP survivant';

  @override
  String get mariageHeritageExonere => 'Héritage exonéré';

  @override
  String get mariagePensionAlimentaire => 'Pension alimentaire';

  @override
  String get mariageConcubinWarning =>
      'En concubinage, le partenaire survivant n\'a droit à rien par défaut — ni rente AVS, ni héritage exonéré. Il faut tout prévoir par contrat.';

  @override
  String get mariageProtectionsEssentielles => 'PROTECTIONS ESSENTIELLES';

  @override
  String get mariageChecklistIntro =>
      'Le mariage a des conséquences financières et juridiques. Voici les démarches essentielles à anticiper pour bien te préparer.';

  @override
  String get mariageDisclaimer =>
      'Estimations simplifiées à but éducatif — ne constitue pas un conseil fiscal ou juridique. Les montants dépendent de nombreux facteurs (déductions, commune, fortune, etc.). Consulte un·e spécialiste fiscal·e pour un calcul personnalisé.';

  @override
  String get divorceAppBarTitle => 'Divorce — Impact financier';

  @override
  String get divorceHeaderTitle => 'Impact financier d\'un divorce';

  @override
  String get divorceHeaderSubtitle => 'Anticipez les conséquences financières';

  @override
  String get divorceIntroText =>
      'Un divorce a des conséquences financières souvent sous-estimées : partage du patrimoine, de la prévoyance (LPP/3a), impact fiscal et pension alimentaire. Cet outil vous aide à y voir plus clair.';

  @override
  String divorceYears(int count) {
    return '$count ans';
  }

  @override
  String get divorceNbEnfants => 'Nombre d\'enfants';

  @override
  String get divorceParticipationDefault =>
      'Participation aux acquêts (défaut)';

  @override
  String get divorceCommunaute => 'Communauté de biens';

  @override
  String get divorceSeparation => 'Séparation de biens';

  @override
  String get divorceFortune => 'Fortune commune';

  @override
  String get divorceDettes => 'Dettes communes';

  @override
  String get divorcePensionDescription =>
      'Estimation basée sur l\'écart de revenus et le nombre d\'enfants. Le montant réel dépend de nombreux facteurs (garde, besoins, train de vie).';

  @override
  String get divorceActionsTitle => 'Actions à entreprendre';

  @override
  String get divorceComprendre => 'COMPRENDRE';

  @override
  String get divorceEduParticipationTitle =>
      'Qu\'est-ce que la participation aux acquêts ?';

  @override
  String get divorceEduParticipationContent =>
      'La participation aux acquêts est le régime matrimonial par défaut en Suisse (CC art. 181 ss). Chaque conjoint conserve ses biens propres (ceux acquis avant le mariage ou par succession/donation). Les acquêts (biens acquis pendant le mariage) sont partagés à parts égales en cas de divorce. C\'est le régime le plus courant en Suisse.';

  @override
  String get divorceEduLppTitle => 'Comment fonctionne le partage LPP ?';

  @override
  String get divorceEduLppContent =>
      'Depuis le 1er janvier 2017 (CC art. 122), les avoirs de prévoyance professionnelle (2e pilier) accumulés pendant le mariage sont partagés à parts égales en cas de divorce. Le partage se fait directement entre les deux caisses de pension, sans passage par le compte personnel des conjoints. C\'est un droit impérieux auquel les conjoints ne peuvent renoncer que dans des conditions strictes.';

  @override
  String get successionAppBarTitle => 'Succession — Planification';

  @override
  String get successionHeaderTitle => 'Planifier ma succession';

  @override
  String get successionHeaderSubtitle => 'Nouveau droit successoral 2023';

  @override
  String get successionIntroText =>
      'Le nouveau droit successoral (2023) a élargi la quotité disponible. Tu as désormais plus de liberté pour avantager certains héritiers. Cet outil te montre la répartition légale et l\'impact d\'un testament.';

  @override
  String get donationAppBarTitle => 'Donation — Simulateur';

  @override
  String get donationHeaderTitle => 'Simuler une donation';

  @override
  String get donationHeaderSubtitle => 'Fiscalité, réserve héréditaire, impact';

  @override
  String get housingSaleAppBarTitle => 'Vente immobilière';

  @override
  String get housingSaleHeaderTitle => 'Simuler ta vente immobilière';

  @override
  String get housingSaleHeaderSubtitle =>
      'Impôt sur les gains, EPL, produit net';

  @override
  String get housingSaleCalculer => 'Calculer';

  @override
  String get lifeEventComprendre => 'COMPRENDRE';

  @override
  String get lifeEventPointsAttention => 'POINTS D\'ATTENTION';

  @override
  String get lifeEventActionsTitle => 'Actions à entreprendre';

  @override
  String get lifeEventChecklistSubtitle => 'Checklist de préparation';

  @override
  String get lifeEventDidYouKnow => 'Le savais-tu ?';

  @override
  String get unemploymentTitle => 'Perte d\'emploi';

  @override
  String get unemploymentHeaderDesc =>
      'Estime tes droits au chômage (LACI). Le calcul dépend de ton gain assuré, de ton âge et de la durée de cotisation au cours des 2 dernières années.';

  @override
  String get unemploymentGainSliderTitle => 'Gain assuré mensuel';

  @override
  String get unemploymentAgeSliderTitle => 'Ton âge';

  @override
  String unemploymentAgeValue(int age) {
    return '$age ans';
  }

  @override
  String get unemploymentAgeMin => '18 ans';

  @override
  String get unemploymentAgeMax => '65 ans';

  @override
  String get unemploymentContribTitle =>
      'Mois de cotisation (2 dernières années)';

  @override
  String unemploymentContribValue(int months) {
    return '$months mois';
  }

  @override
  String get unemploymentContribMax => '24 mois';

  @override
  String get unemploymentSituationTitle => 'Situation personnelle';

  @override
  String get unemploymentSituationSubtitle =>
      'Influence le taux d\'indemnisation (70% ou 80%)';

  @override
  String get unemploymentChildrenToggle => 'Obligation d\'entretien (enfants)';

  @override
  String get unemploymentDisabilityToggle => 'Handicap reconnu';

  @override
  String get unemploymentNotEligible => 'Non éligible';

  @override
  String get unemploymentCompensationRate => 'Taux d\'indemnisation';

  @override
  String get unemploymentRateEnhanced =>
      'Taux majoré (80%) : obligation d\'entretien, handicap, ou salaire < CHF 3\'797';

  @override
  String get unemploymentRateStandard =>
      'Taux standard (70%) : applicable dans les autres situations';

  @override
  String get unemploymentDailyBenefit => 'Indemnité /jour';

  @override
  String get unemploymentMonthlyBenefit => 'Indemnité /mois';

  @override
  String get unemploymentInsuredEarnings => 'Gain assuré retenu';

  @override
  String get unemploymentWaitingPeriod => 'Délai de carence';

  @override
  String unemploymentWaitingDays(int days) {
    return '$days jours';
  }

  @override
  String get unemploymentDurationHeader => 'DURÉE DES PRESTATIONS';

  @override
  String get unemploymentDailyBenefits => 'indemnités journalières';

  @override
  String get unemploymentCoverageMonths => 'mois de couverture';

  @override
  String get unemploymentYouTag => 'TOI';

  @override
  String get unemploymentChecklistHeader => 'CHECKLIST';

  @override
  String get unemploymentCheckItem1 =>
      'S\'inscrire à l\'ORP dès le 1er jour sans emploi';

  @override
  String get unemploymentCheckItem2 =>
      'Déposer le dossier à la caisse de chômage';

  @override
  String get unemploymentCheckItem3 => 'Adapter le budget au nouveau revenu';

  @override
  String get unemploymentCheckItem4 =>
      'Transférer l\'avoir LPP sur un compte de libre passage';

  @override
  String get unemploymentCheckItem5 =>
      'Vérifier les droits à une réduction de prime LAMal';

  @override
  String get unemploymentCheckItem6 =>
      'Mettre à jour le budget MINT avec le nouveau revenu';

  @override
  String get unemploymentGoodToKnow => 'BON À SAVOIR';

  @override
  String get unemploymentEduFastTitle => 'Inscription rapide';

  @override
  String get unemploymentEduFastBody =>
      'Inscris-toi à l\'ORP le plus tôt possible. Chaque jour de retard peut entraîner une suspension de tes indemnités.';

  @override
  String get unemploymentEdu3aTitle => '3e pilier en pause';

  @override
  String get unemploymentEdu3aBody =>
      'Sans revenu lucratif, tu ne peux plus cotiser au 3a. Les indemnités de chômage ne sont pas considérées comme un revenu lucratif au sens du 3e pilier.';

  @override
  String get unemploymentEduLppTitle => 'LPP et chômage';

  @override
  String get unemploymentEduLppBody =>
      'Pendant le chômage, seuls les risques décès et invalidité sont couverts par le LPP. L\'épargne vieillesse s\'arrête. Transfère ton avoir sur un compte de libre passage.';

  @override
  String get unemploymentEduLamalTitle => 'Réduction de prime LAMal';

  @override
  String get unemploymentEduLamalBody =>
      'Avec un revenu plus bas, tu pourrais avoir droit à des subsides LAMal. Fais la demande auprès de ton canton.';

  @override
  String get unemploymentTsunamiTitle => 'Ton tsunami financier en 3 vagues';

  @override
  String get unemploymentDisclaimer =>
      'Estimations éducatives — ne constitue pas un conseil au sens de la LSFin — LACI/LPP/OPP3. Les montants présentés sont approximatifs et dépendent de ta situation personnelle. Consulte un·e spécialiste ou l\'ORP de ton canton.';

  @override
  String get firstJobTitle => 'Premier emploi';

  @override
  String get firstJobHeaderDesc =>
      'Comprends ta fiche de salaire ! On te montre où vont tes cotisations, ce que ton employeur paie en plus, et les premiers réflexes financiers à adopter.';

  @override
  String get firstJobSalaryTitle => 'Salaire brut mensuel';

  @override
  String get firstJobActivityRate => 'Taux d\'activité';

  @override
  String get firstJob3aHeader => 'PILIER 3A — À OUVRIR MAINTENANT';

  @override
  String get firstJob3aAnnualCap => 'Plafond annuel';

  @override
  String get firstJob3aMonthlySuggestion => 'Suggestion /mois';

  @override
  String get firstJob3aWarningTitle => 'ATTENTION — ASSURANCE-VIE 3A';

  @override
  String get firstJobLamalHeader => 'COMPARAISON FRANCHISES LAMAL';

  @override
  String get firstJobChecklistHeader => 'PREMIERS RÉFLEXES';

  @override
  String get firstJobEduLppTitle => 'LPP dès 25 ans';

  @override
  String get firstJobEduLppBody =>
      'La cotisation LPP (2e pilier) commence à 25 ans pour l\'épargne vieillesse. Avant 25 ans, seuls les risques décès et invalidité sont couverts.';

  @override
  String get firstJobEdu13Title => '13e salaire';

  @override
  String get firstJobEdu13Body =>
      'Si ton contrat prévoit un 13e salaire, celui-ci est aussi soumis aux déductions sociales. Ton salaire mensuel brut est alors le salaire annuel divisé par 13.';

  @override
  String get firstJobEduBudgetTitle => 'Règle du 50/30/20';

  @override
  String get firstJobEduBudgetBody =>
      'Un bon réflexe pour ton premier salaire : 50% pour les dépenses fixes, 30% pour les loisirs, 20% pour l\'épargne et la prévoyance (3a inclus).';

  @override
  String get firstJobEduTaxTitle => 'Déclaration fiscale';

  @override
  String get firstJobEduTaxBody =>
      'Dès ton premier emploi, tu devras remplir une déclaration fiscale. Garde toutes tes attestations (salaire, 3a, frais professionnels).';

  @override
  String get firstJobAnalysisHeader => 'Analyse MINT — Le film de ton salaire';

  @override
  String get firstJobProfileBadge => 'Ton profil';

  @override
  String get firstJobIllustrativeBadge => 'Illustratif';

  @override
  String get firstJobDisclaimer =>
      'Estimations éducatives — ne constitue pas un conseil — LACI/LPP/OPP3. Les montants sont approximatifs et ne tiennent pas compte de toutes les spécificités cantonales. Consulte priminfo.admin.ch pour les primes LAMal exactes. Consulte un·e spécialiste en prévoyance.';

  @override
  String get independantAppBarTitle => 'PARCOURS INDÉPENDANT';

  @override
  String get independantTitle => 'Indépendant';

  @override
  String get independantSubtitle => 'Analyse de couverture et protection';

  @override
  String get independantIntroDesc =>
      'En tant qu\'indépendant, tu n\'as pas de LPP obligatoire, pas d\'IJM, et pas de LAA. Ta protection sociale dépend entièrement de tes démarches personnelles. Identifie tes lacunes.';

  @override
  String get independantRevenueTitle => 'Revenu net annuel';

  @override
  String independantAgeLabel(int age) {
    return 'Age : $age ans';
  }

  @override
  String get independantCoverageTitle => 'Ma couverture actuelle';

  @override
  String get independantToggleLpp => 'LPP (affiliation volontaire)';

  @override
  String get independantToggleIjm => 'IJM (indemnité journalière maladie)';

  @override
  String get independantToggleLaa => 'LAA (assurance accident)';

  @override
  String get independantToggle3a => '3e pilier (3a)';

  @override
  String get independantCoverageAnalysis => 'ANALYSE DE COUVERTURE';

  @override
  String get independantProtectionCostTitle => 'Coût de ma protection complète';

  @override
  String get independantProtectionCostSubtitle => 'Estimation mensuelle';

  @override
  String get independantTotalMonthly => 'Total mensuel';

  @override
  String get independantAvsTitle => 'Cotisation AVS indépendant';

  @override
  String get independant3aTitle => '3e pilier — plafond indépendant';

  @override
  String get independantRecommendationsHeader => 'RECOMMANDATIONS';

  @override
  String get independantAnalysisHeader => 'Analyse MINT — Ton kit indépendant';

  @override
  String get independantSourcesTitle => 'Sources';

  @override
  String get independantSourcesBody =>
      'LPP art. 4 (pas d\'obligation pour indépendants) / LPP art. 44 (affiliation volontaire) / OPP3 art. 7 (3a grand : 20% du revenu net, max 36\'288) / LAVS art. 8 (cotisations indépendants) / LAA art. 4 / LAMal';

  @override
  String get independantDisclaimer =>
      'Les montants présentés sont des estimations indicatives. Les cotisations réelles dépendent de ta situation personnelle et des offres d\'assurance disponibles. Consulte un fiduciaire ou un assureur avant toute décision.';

  @override
  String get jobCompareAgeTitle => 'Ton âge';

  @override
  String get jobCompareAgeSubtitle =>
      'Utilisé pour projeter le capital retraite';

  @override
  String get jobCompareSalaryLabel => 'Salaire brut annuel';

  @override
  String get jobCompareEmployerShare => 'Part employeur LPP';

  @override
  String get jobCompareConversionRate => 'Taux de conversion';

  @override
  String get jobCompareRetirementAssets => 'Avoir de vieillesse actuel';

  @override
  String get jobCompareDisabilityCoverage => 'Couverture invalidité';

  @override
  String get jobCompareDeathCapital => 'Capital-décès';

  @override
  String get jobCompareMaxBuyback => 'Rachat maximum';

  @override
  String get jobCompareVerdictLabel => 'VERDICT';

  @override
  String get jobCompareDetailedTitle => 'Comparaison détaillée';

  @override
  String get jobCompareRetirementImpact => 'IMPACT SUR TOUTE LA RETRAITE';

  @override
  String get jobCompareAttentionPoints => 'POINTS D\'ATTENTION';

  @override
  String get jobCompareChecklistTitle => 'Avant de signer';

  @override
  String get jobCompareUnderstandHeader => 'COMPRENDRE';

  @override
  String get jobCompareEduInvisibleTitle =>
      'Qu\'est-ce que le salaire invisible ?';

  @override
  String get jobCompareEduInvisibleBody =>
      'Le \"salaire invisible\" représente 10-30% de ta rémunération totale. Il inclut la part employeur à la caisse de pension (LPP), les assurances (IJM, accident), et parfois des avantages complémentaires. Deux postes au même salaire brut peuvent offrir des protections très différentes.';

  @override
  String get jobCompareEduCertTitle =>
      'Comment lire mon certificat de prévoyance ?';

  @override
  String get jobCompareEduCertBody =>
      'Ton certificat de prévoyance (LPP) contient toutes les informations nécessaires : salaire assuré, déduction de coordination, taux de cotisation, avoir de vieillesse, taux de conversion, prestations de risque (invalidité et décès), et rachat possible. Demande-le à ton RH ou à ta caisse de pension.';

  @override
  String get jobCompareAxisLabel => 'Axe';

  @override
  String get jobCompareCurrentLabel => 'Actuel';

  @override
  String get jobCompareNewLabel => 'Nouveau';

  @override
  String get disabilityGapParamsTitle => 'Tes paramètres';

  @override
  String get disabilityGapParamsSubtitle => 'Ajuste selon ta situation';

  @override
  String get disabilityGapIncomeLabel => 'Revenu mensuel net';

  @override
  String get disabilityGapCantonLabel => 'Canton';

  @override
  String get disabilityGapStatusLabel => 'Statut professionnel';

  @override
  String get disabilityGapEmployee => 'Salarié';

  @override
  String get disabilityGapSelfEmployed => 'Indép.';

  @override
  String get disabilityGapSeniorityLabel => 'Années d\'ancienneté';

  @override
  String get disabilityGapIjmLabel => 'IJM collective via mon employeur';

  @override
  String get disabilityGapDegreeLabel => 'Degré d\'invalidité';

  @override
  String get disabilityGapChartTitle => 'Évolution de ta couverture';

  @override
  String get disabilityGapChartSubtitle => 'Les 3 phases de protection';

  @override
  String get disabilityGapCurrentIncome => 'Revenu actuel';

  @override
  String get disabilityGapMaxGap => 'GAP MENSUEL MAXIMAL';

  @override
  String get disabilityGapPhaseDetail => 'DÉTAIL DES PHASES';

  @override
  String get disabilityGapPhase1Title => 'Phase 1: Employeur';

  @override
  String get disabilityGapPhase2Title => 'Phase 2: IJM';

  @override
  String get disabilityGapPhase3Title => 'Phase 3: AI + LPP';

  @override
  String get disabilityGapDurationLabel => 'Durée:';

  @override
  String get disabilityGapCoverageLabel => 'Couverture:';

  @override
  String get disabilityGapLegalLabel => 'Source légale:';

  @override
  String get disabilityGapIfYouAre => 'SI TU ES...';

  @override
  String get disabilityGapEduTitle => 'COMPRENDRE';

  @override
  String get disabilityGapEduIjmTitle => 'IJM vs AI : quelle différence ?';

  @override
  String get disabilityGapEduIjmBody =>
      'L\'IJM (indemnité journalière maladie) est une assurance qui couvre 80% de ton salaire pendant max. 720 jours en cas de maladie. L\'employeur n\'est pas obligé de la souscrire, mais beaucoup le font via une assurance collective. Sans IJM, après la période légale de maintien du salaire, tu ne recevez plus rien jusqu\'à l\'éventuelle rente AI.';

  @override
  String get disabilityGapEduCoTitle =>
      'L\'obligation de ton employeur (CO art. 324a)';

  @override
  String get disabilityGapEduCoBody =>
      'Selon l\'art. 324a CO, l\'employeur doit verser le salaire pendant une durée limitée en cas de maladie. Cette durée dépend des années de service et de l\'échelle cantonale applicable (bernoise, zurichoise ou bâloise). Après cette période, seule l\'IJM (si existante) prend le relais.';

  @override
  String get successionIntroDesc =>
      'Le nouveau droit successoral (2023) a élargi la quotité disponible. Tu as désormais plus de liberté pour avantager certains héritiers. Cet outil te montre la répartition légale et l\'impact d\'un testament.';

  @override
  String get successionSimulateButton => 'Simuler';

  @override
  String get successionLegalDistribution => 'RÉPARTITION LÉGALE';

  @override
  String get successionTestamentDistribution => 'RÉPARTITION AVEC TESTAMENT';

  @override
  String get successionReservesTitle => 'Réserves héréditaires';

  @override
  String get successionReservesSubtitle => 'CC art. 470–471';

  @override
  String get successionQuotiteTitle => 'Quotité disponible';

  @override
  String get successionQuotiteDesc =>
      'Ce montant peut être librement attribué par testament à la personne de ton choix.';

  @override
  String get successionBeneficiaries3aTitle => 'BÉNÉFICIAIRES 3a (OPP3 ART. 2)';

  @override
  String get successionBeneficiaries3aDesc =>
      'Le 3e pilier ne suit PAS ton testament. L\'ordre de bénéficiaires est fixé par la loi :';

  @override
  String get successionChecklistTitle => 'Checklist protection patrimoine';

  @override
  String get successionTotalTax => 'Total impôt successoral';

  @override
  String get successionTestamentSwitch => 'J\'ai un testament';

  @override
  String get successionBeneficiaryQuestion =>
      'Qui reçoit la quotité disponible ?';

  @override
  String get successionCivilStatusLabel => 'Statut civil';

  @override
  String get successionFortuneLabel => 'Fortune totale';

  @override
  String get successionAvoirs3aLabel => 'Avoirs 3a';

  @override
  String get successionDeathCapitalLabel => 'Capital décès LPP';

  @override
  String get successionChildrenLabel => 'Nombre d\'enfants';

  @override
  String get successionParentsAlive => 'Parents vivants';

  @override
  String get successionSiblings => 'Fratrie (frères/sœurs)';

  @override
  String get mariageProtectionItem1 =>
      'Rédiger un testament (clause d\'usufruit)';

  @override
  String get mariageProtectionItem2 =>
      'Clause bénéficiaire LPP (demander à ta caisse de pension)';

  @override
  String get mariageProtectionItem3 =>
      'Assurance-vie croisée (protection du partenaire)';

  @override
  String get mariageProtectionItem4 => 'Mandat pour cause d\'inaptitude';

  @override
  String get mariageProtectionItem5 => 'Directives anticipées du patient';

  @override
  String get mariageChecklistItem1Title =>
      'Simuler l\'impact fiscal du mariage';

  @override
  String get mariageChecklistItem1Desc =>
      'Avant de te marier, compare la charge fiscale à deux (mariés vs célibataires). Si tes revenus sont similaires et élevés, la pénalité de mariage peut représenter plusieurs milliers de francs par an.';

  @override
  String get mariageChecklistItem2Title => 'Choisir le régime matrimonial';

  @override
  String get mariageChecklistItem2Desc =>
      'Par défaut, c\'est la participation aux acquêts (CC art. 181). Si tu veux un autre régime (séparation de biens, communauté de biens), il faut signer un contrat de mariage chez le notaire AVANT ou pendant le mariage.';

  @override
  String get mariageChecklistItem3Title =>
      'Mettre à jour les clauses bénéficiaires LPP et 3a';

  @override
  String get mariageChecklistItem3Desc =>
      'Le mariage change l\'ordre des bénéficiaires. Ton conjoint devient automatiquement bénéficiaire de la rente de survivant LPP (LPP art. 19). Vérifie aussi les bénéficiaires de ton 3e pilier.';

  @override
  String get mariageChecklistItem4Title =>
      'Informer ton employeur et ta caisse maladie';

  @override
  String get mariageChecklistItem4Desc =>
      'Ton employeur doit mettre à jour tes données (état civil, déductions). Ta caisse maladie doit être informée — les primes ne changent pas, mais les subsides éventuels sont recalculés sur le revenu du ménage.';

  @override
  String get mariageChecklistItem5Title =>
      'Préparer la première déclaration commune';

  @override
  String get mariageChecklistItem5Desc =>
      'Dès l\'année du mariage, tu fais une seule déclaration fiscale commune. Rassemble les justificatifs des deux (certificats de salaire, 3a, LPP, etc.). Le passage à la déclaration commune peut changer ta tranche d\'imposition.';

  @override
  String get mariageChecklistItem6Title => 'Vérifier les rentes AVS de couple';

  @override
  String get mariageChecklistItem6Desc =>
      'La rente AVS maximale pour un couple est plafonnée à 150% de la rente individuelle maximale (LAVS art. 35). Si tu as droit à la rente max avec ton conjoint, le plafond peut réduire ton total.';

  @override
  String get mariageChecklistItem7Title => 'Adapter le testament';

  @override
  String get mariageChecklistItem7Desc =>
      'Le mariage modifie l\'ordre de succession. Le conjoint devient héritier légal avec des droits importants (CC art. 462). Si tu avais un testament en faveur d\'un tiers, il est peut-être à revoir.';

  @override
  String mariageChecklistProgress(int done, int total) {
    return '$done/$total démarches effectuées';
  }

  @override
  String get mariageRepartitionDissolution =>
      'RÉPARTITION EN CAS DE DISSOLUTION';

  @override
  String get mariagePersonne1Recoit => 'Personne 1 reçoit';

  @override
  String get mariagePersonne2Recoit => 'Personne 2 reçoit';

  @override
  String get mariagePersonne1Garde => 'Personne 1 garde';

  @override
  String get mariagePersonne2Garde => 'Personne 2 garde';

  @override
  String get successionSituationTitle => 'SITUATION PERSONNELLE';

  @override
  String get successionSituationSubtitle2 => 'Statut civil, héritiers';

  @override
  String get successionFortuneTitle => 'FORTUNE';

  @override
  String get successionFortuneSubtitle2 => 'Patrimoine total, 3a, LPP';

  @override
  String get successionTestamentTitle => 'Testament';

  @override
  String get successionTestamentSubtitle2 => 'Volontés testamentaires';

  @override
  String successionQuotitePct(String pct) {
    return 'soit $pct% de la succession';
  }

  @override
  String get successionExonereLabel => 'Exonéré';

  @override
  String successionFiscaliteCanton(String canton) {
    return 'FISCALITÉ SUCCESSORALE ($canton)';
  }

  @override
  String get successionEduQuotiteBody2 =>
      'La quotité disponible est la part de ta succession que tu peux librement attribuer par testament. Depuis le 1er janvier 2023, la réserve des descendants a été réduite de 3/4 à 1/2 de leur part légale. Les parents n\'ont plus de réserve. Cela te donne plus de liberté pour favoriser ton/ta conjoint·e, ton/ta concubin·e ou toute autre personne.';

  @override
  String get successionEdu3aBody2 =>
      'Le 3e pilier (pilier 3a) n\'entre PAS dans la masse successorale ordinaire. Il est versé directement aux bénéficiaires selon un ordre fixé par l\'OPP3 (art. 2) : conjoint/partenaire enregistré, puis descendants, parents, fratrie. Le concubin peut être désigné comme bénéficiaire, mais uniquement par une clause explicite déposée auprès de la fondation. Sans cette démarche, le/la concubin(e) ne reçoit rien du 3a.';

  @override
  String get successionEduConcubinBody2 =>
      'En droit suisse, les concubins n\'ont AUCUN droit successoral légal. Sans testament, un concubin ne reçoit rien. De plus, l\'impôt successoral pour les concubins est généralement bien plus élevé que pour les conjoints (souvent 20-25% au lieu de 0%). Pour protéger ton/ta concubin·e, il est essentiel de rédiger un testament, de vérifier les clauses bénéficiaires 3a/LPP et d\'envisager des assurances-vie.';

  @override
  String get successionDisclaimerText =>
      'Les résultats présentés sont des estimations à titre indicatif et ne constituent pas un conseil juridique ou notarial personnalisé. Le droit successoral comporte de nombreuses subtilités. Consultez un notaire ou un avocat spécialisé avant toute décision.';

  @override
  String get donationIntroText =>
      'Les donations en Suisse sont soumises à un impôt cantonal qui varie selon le lien de parenté et le canton. Depuis 2023, la réserve héréditaire a été réduite, te donnant plus de liberté. Cet outil t\'aide à estimer l\'impôt et à vérifier la compatibilité avec les droits des héritiers.';

  @override
  String get donationSectionTitle => 'DONATION';

  @override
  String get donationSectionSubtitle => 'Montant, bénéficiaire, type';

  @override
  String get donationMontantLabel => 'Montant de la donation';

  @override
  String get donationLienParente => 'Lien de parenté';

  @override
  String get donationTypeDonation => 'Type de donation';

  @override
  String get donationValeurImmobiliere => 'Valeur immobilière';

  @override
  String get donationAvancementHoirie => 'Avancement d\'hoirie';

  @override
  String get donationContexteSuccessoral => 'CONTEXTE SUCCESSORAL';

  @override
  String get donationContexteSubtitle => 'Famille, fortune, régime matrimonial';

  @override
  String get donationAgeLabel => 'Âge du donateur';

  @override
  String get donationNbEnfants => 'Nombre d\'enfants';

  @override
  String get donationFortuneTotale => 'Fortune totale du donateur';

  @override
  String get donationRegimeMatrimonial => 'Régime matrimonial';

  @override
  String get donationCalculer => 'Calculer';

  @override
  String get donationImpotTitle => 'IMPÔT SUR LA DONATION';

  @override
  String get donationExoneree => 'Exonérée';

  @override
  String donationTauxCanton(String taux, String canton) {
    return 'Taux : $taux% (canton $canton)';
  }

  @override
  String get donationMontantRow => 'Montant de la donation';

  @override
  String get donationLienRow => 'Lien de parenté';

  @override
  String get donationReserveTitle => 'RÉSERVE HÉRÉDITAIRE (2023)';

  @override
  String get donationReserveProtege =>
      'montant protégé par la loi (intouchable)';

  @override
  String get donationReserveNote =>
      'Depuis 2023, les parents n\'ont plus de réserve. La réserve des descendants est de 50% de leur part légale (CC art. 471).';

  @override
  String get donationQuotiteTitle => 'QUOTITÉ DISPONIBLE';

  @override
  String get donationQuotiteDesc => 'montant que tu peux librement donner';

  @override
  String donationDepassement(String amount) {
    return 'Dépassement de $amount — risque d\'action en réduction';
  }

  @override
  String get donationImpactTitle => 'IMPACT SUR LA SUCCESSION';

  @override
  String get donationAvancementNote =>
      'Avancement d\'hoirie : la donation sera rapportée à la masse successorale.';

  @override
  String get donationHorsPartNote =>
      'Donation hors part : elle est imputée sur la quotité disponible uniquement.';

  @override
  String get donationEduQuotiteTitle =>
      'Qu\'est-ce que la quotité disponible ?';

  @override
  String get donationEduQuotiteBody =>
      'La quotité disponible est la part de ta fortune que tu peux librement donner ou léguer sans empiéter sur les réserves héréditaires. Depuis le 1er janvier 2023, la réserve des descendants a été réduite de 3/4 à 1/2 de leur part légale, et les parents n\'ont plus de réserve. Cela te donne plus de liberté pour effectuer des donations.';

  @override
  String get donationEduAvancementTitle =>
      'Avancement d\'hoirie vs donation hors part';

  @override
  String get donationEduAvancementBody =>
      'Une donation en avancement d\'hoirie est une avance sur la part successorale du bénéficiaire. Elle sera rapportée à la masse successorale lors du décès. Une donation hors part (ou préciput) est imputée uniquement sur la quotité disponible et n\'est pas rapportée. Le choix entre les deux a un impact majeur sur l\'équilibre entre les héritiers.';

  @override
  String get donationEduConcubinTitle => 'Donations et concubins';

  @override
  String get donationEduConcubinBody =>
      'Les concubins n\'ont aucun droit successoral légal en Suisse. Une donation est le moyen le plus direct de les avantager. Cependant, l\'impôt cantonal sur les donations entre concubins est généralement élevé (18-25% selon les cantons). Schwyz fait exception : aucun impôt sur les donations quel que soit le lien. Envisager un testament en complément pour une protection complète.';

  @override
  String get donationDisclaimer =>
      'Cet outil éducatif fournit des estimations indicatives et ne constitue pas un conseil juridique, fiscal ou notarial personnalisé au sens de la LSFin. Consulte un·e spécialiste (notaire) pour ta situation.';

  @override
  String get donationCanton => 'Canton';

  @override
  String get housingSaleIntroText =>
      'Vendre un bien immobilier en Suisse implique un impôt sur les gains immobiliers (LHID art. 12), le remboursement éventuel des fonds de prévoyance utilisés (EPL) et des frais de transaction. Cet outil t\'aide à estimer le produit net de ta vente.';

  @override
  String get housingSaleBienTitle => 'BIEN IMMOBILIER';

  @override
  String get housingSaleBienSubtitle => 'Prix d\'achat, vente, investissements';

  @override
  String get housingSalePrixAchat => 'Prix d\'achat';

  @override
  String get housingSalePrixVente => 'Prix de vente';

  @override
  String get housingSaleAnneeAchat => 'Année d\'achat';

  @override
  String get housingSaleInvestissements => 'Investissements valorisants';

  @override
  String get housingSaleFraisAcquisition =>
      'Frais d\'acquisition (notaire, etc.)';

  @override
  String get housingSaleResidencePrincipale => 'Résidence principale';

  @override
  String get housingSaleFinancementTitle => 'FINANCEMENT';

  @override
  String get housingSaleFinancementSubtitle => 'Hypothèque restante';

  @override
  String get housingSaleHypotheque => 'Hypothèque restante';

  @override
  String get housingSaleEplTitle => 'EPL — PRÉVOYANCE UTILISÉE';

  @override
  String get housingSaleEplSubtitle => 'LPP et 3a utilisés pour l\'achat';

  @override
  String get housingSaleEplLpp => 'EPL LPP utilisé';

  @override
  String get housingSaleEpl3a => 'EPL 3a utilisé';

  @override
  String get housingSaleRemploiTitle => 'REMPLOI';

  @override
  String get housingSaleRemploiSubtitle =>
      'Projet de rachat d\'un nouveau bien';

  @override
  String get housingSaleProjetRemploi => 'Projet de remploi (rachat)';

  @override
  String get housingSalePrixNouveauBien => 'Prix du nouveau bien';

  @override
  String get housingSalePlusValueTitle => 'PLUS-VALUE IMMOBILIÈRE';

  @override
  String get housingSalePlusValueBrute => 'Plus-value brute';

  @override
  String get housingSalePlusValueImposable => 'Plus-value imposable';

  @override
  String get housingSaleDureeDetention => 'Durée de détention';

  @override
  String housingSaleYearsCount(int count) {
    return '$count ans';
  }

  @override
  String housingSaleImpotGainsCanton(String canton) {
    return 'IMPÔT SUR LES GAINS ($canton)';
  }

  @override
  String get housingSaleTauxImposition => 'Taux d\'imposition';

  @override
  String get housingSaleImpotGains => 'Impôt sur les gains';

  @override
  String get housingSaleReportRemploi => 'Report (remploi)';

  @override
  String get housingSaleImpotEffectif => 'Impôt effectif';

  @override
  String get housingSaleReportTitle => 'REPORT D\'IMPOSITION (REMPLOI)';

  @override
  String get housingSaleReportDesc =>
      'de plus-value reportée (non imposée maintenant)';

  @override
  String get housingSaleReportNote =>
      'Le report sera intégré lors de la revente du nouveau bien (LHID art. 12 al. 3).';

  @override
  String get housingSaleEplRepaymentTitle => 'REMBOURSEMENT EPL';

  @override
  String get housingSaleRemboursementLpp => 'Remboursement LPP';

  @override
  String get housingSaleRemboursement3a => 'Remboursement 3a';

  @override
  String get housingSaleEplNote =>
      'Obligation légale : les fonds de prévoyance utilisés pour l\'achat doivent être remboursés lors de la vente de la résidence principale (LPP art. 30d).';

  @override
  String get housingSaleProduitNetTitle => 'PRODUIT NET DE LA VENTE';

  @override
  String get housingSaleImpotPlusValue => 'Impôt plus-value';

  @override
  String get housingSaleRemboursementEplLpp => 'Remboursement EPL LPP';

  @override
  String get housingSaleRemboursementEpl3a => 'Remboursement EPL 3a';

  @override
  String get housingSaleEduImpotTitle =>
      'Comment fonctionne l\'impôt sur les gains immobiliers ?';

  @override
  String get housingSaleEduImpotBody =>
      'En Suisse, tout gain réalisé lors de la vente d\'un bien immobilier est soumis à un impôt cantonal spécifique (LHID art. 12). Le taux diminue avec la durée de détention du bien. Après 20-25 ans selon les cantons, le gain peut être totalement ou partiellement exonéré. Les investissements valorisants (rénovations) et les frais d\'acquisition sont déductibles de la plus-value.';

  @override
  String get housingSaleEduRemploiTitle => 'Qu\'est-ce que le remploi ?';

  @override
  String get housingSaleEduRemploiBody =>
      'Le remploi permet de reporter l\'imposition de la plus-value si tu rachètes un nouveau logement principal dans un délai raisonnable (généralement 2 ans). Si le nouveau bien coûte autant ou plus que l\'ancien, le report est total. Sinon, il est proportionnel. L\'impôt sera dû lors de la revente du nouveau bien.';

  @override
  String get housingSaleEduEplTitle => 'EPL : que se passe-t-il à la vente ?';

  @override
  String get housingSaleEduEplBody =>
      'Si tu as utilisé des fonds de prévoyance (EPL) pour l\'achat de ta résidence principale, tu dois les rembourser lors de la vente (LPP art. 30d). Ce remboursement est obligatoire et s\'effectue auprès de ta caisse de pension (LPP) et/ou de ta fondation 3a. Le montant est inscrit au registre foncier et ne peut pas être évité.';

  @override
  String get housingSaleDisclaimer =>
      'Cet outil éducatif fournit des estimations indicatives et ne constitue pas un conseil fiscal, juridique ou immobilier personnalisé au sens de la LSFin. Consulte un·e spécialiste pour ta situation personnelle.';

  @override
  String get housingSaleCanton => 'Canton';

  @override
  String get jobCompareDeltaLabel => 'Delta';

  @override
  String jobCompareRetirementBody(
      String betterJob, String annualDelta, String monthlyDelta) {
    return '$betterJob vaut $annualDelta/an de plus en rente viagère, soit $monthlyDelta/mois À VIE après la retraite.';
  }

  @override
  String jobCompareLifetime20Years(String amount) {
    return 'Sur 20 ans de retraite : $amount';
  }

  @override
  String jobCompareAxesFavorable(String favorable, String total) {
    return '$favorable axes favorables sur $total';
  }

  @override
  String get jobCompareCurrentJobWidget => 'Emploi actuel';

  @override
  String get jobCompareNewJobWidget => 'Emploi envisagé';

  @override
  String get jobCompareAxisSalary => 'Salaire brut';

  @override
  String get jobCompareAxisLpp => 'LPP cotisation';

  @override
  String get jobCompareAxisDistance => 'Distance';

  @override
  String get jobCompareAxisVacation => 'Vacances';

  @override
  String get jobCompareAxisWeeklyHours => 'Horaire hebdo';

  @override
  String get jobCompareChecklistSub => 'Checklist de vérification';

  @override
  String get independantJourJTitle => 'Le Jour J — La grande bascule';

  @override
  String get independantJourJSubtitle =>
      'Ce qui change en 1 jour quand tu deviens indépendant·e';

  @override
  String get independantJourJEmployee => 'Salarié·e';

  @override
  String get independantJourJSelfEmployed => 'Indépendant·e';

  @override
  String independantJourJChiffreChoc(String amount) {
    return 'Tu perds ~$amount/mois de protection invisible.\nTu n’as pas quitté un emploi. Tu as quitté un système de protection.';
  }

  @override
  String independantAvsBody(String amount) {
    return 'Ta cotisation AVS estimée : $amount/an (taux dégressif pour les revenus inférieurs à CHF 58’800, puis ~10.6% au-dessus).';
  }

  @override
  String get independantAvsSource =>
      'Source : LAVS art. 8 / Tables des cotisations AVS';

  @override
  String get independant3aWithLpp =>
      'Avec LPP volontaire : plafond 3a standard de CHF 7’258/an.';

  @override
  String independant3aWithoutLpp(String amount) {
    return 'Sans LPP : plafond 3a \"grand\" de 20% du revenu net, max $amount/an (plafond légal CHF 36’288).';
  }

  @override
  String get independant3aSource => 'Source : OPP3 art. 7';

  @override
  String get independantPerMonth => '/mois';

  @override
  String get independantPerYear => '/ an';

  @override
  String get independantCostAvs => 'AVS / AI / APG';

  @override
  String get independantCostIjm => 'IJM (estimation)';

  @override
  String get independantCostLaa => 'LAA (estimation)';

  @override
  String get independantCost3a => '3e pilier (max)';

  @override
  String disabilityGapSeniorityYears(String years) {
    return '$years ans';
  }

  @override
  String disabilityGapPhase1Duration(String weeks) {
    return '$weeks semaines';
  }

  @override
  String get disabilityGapPhase1Full => '100% du salaire';

  @override
  String get disabilityGapNoCoverage => 'Aucune couverture';

  @override
  String get disabilityGapNone => 'Aucune';

  @override
  String get disabilityGapPhase2Duration => 'Jusqu\'à 24 mois';

  @override
  String disabilityGapPhase2Coverage(String amount) {
    return '80% du salaire ($amount CHF/mois)';
  }

  @override
  String get disabilityGapCollectiveInsurance => 'Assurance collective';

  @override
  String get disabilityGapNotSubscribed => 'Non souscrite';

  @override
  String get disabilityGapPhase3Duration => 'Après 24 mois';

  @override
  String get disabilityGapActionSelfIjm => 'Souscris une IJM individuelle';

  @override
  String get disabilityGapActionSelfIjmSub =>
      'Priorité absolue pour les indépendants';

  @override
  String get disabilityGapActionCheckHr =>
      'Vérifie avec ton RH ta couverture maladie';

  @override
  String get disabilityGapActionCheckHrSub =>
      'Demande si une IJM collective existe';

  @override
  String get disabilityGapActionConditions =>
      'Demande les conditions exactes de ton IJM';

  @override
  String get disabilityGapActionConditionsSub =>
      'Délai d\'attente, durée, taux de couverture';

  @override
  String get successionMarried => 'Marié(e)';

  @override
  String get successionSingle => 'Célibataire';

  @override
  String get successionDivorced => 'Divorcé(e)';

  @override
  String get successionWidowed => 'Veuf/Veuve';

  @override
  String get successionConcubinage => 'Concubinage';

  @override
  String get successionConjoint => 'Conjoint(e)';

  @override
  String get successionChildren => 'Enfants';

  @override
  String get successionThirdParty => 'Tiers / Œuvre';

  @override
  String get successionQuotiteFreedom =>
      'Ce montant peut être librement attribué par testament à la personne de ton choix.';

  @override
  String get successionFiscalTitle => 'FISCALITÉ SUCCESSORALE';

  @override
  String get successionExempt => 'Exonéré';

  @override
  String get successionEduQuotiteTitle =>
      'Qu\'est-ce que la quotité disponible ?';

  @override
  String get successionEdu3aTitle => 'Le 3a et la succession : attention !';

  @override
  String get successionEduConcubinTitle => 'Les concubins et la succession';

  @override
  String get successionCantonLabel => 'Canton';

  @override
  String get debtCheckTitle => 'Check-up Santé Financière';

  @override
  String get debtCheckExportTooltip => 'Exporter mon bilan';

  @override
  String get debtCheckSectionDaily => 'Gestion quotidienne';

  @override
  String get debtCheckOverdraftQuestion => 'Es-tu régulièrement à découvert ?';

  @override
  String get debtCheckOverdraftSub =>
      'Ton compte passe en négatif avant la fin du mois.';

  @override
  String get debtCheckMultipleCreditsQuestion =>
      'As-tu plusieurs crédits en cours ?';

  @override
  String get debtCheckMultipleCreditsSub =>
      'Leasing, prêt, petits crédits, cartes de crédit...';

  @override
  String get debtCheckSectionObligations => 'Obligations';

  @override
  String get debtCheckLatePaymentsQuestion => 'As-tu des retards de paiement ?';

  @override
  String get debtCheckLatePaymentsSub =>
      'Factures, impôts ou loyers payés en retard.';

  @override
  String get debtCheckCollectionQuestion => 'As-tu reçu des poursuites ?';

  @override
  String get debtCheckCollectionSub => 'Commandements de payer ou saisies.';

  @override
  String get debtCheckSectionBehaviors => 'Comportements';

  @override
  String get debtCheckImpulsiveQuestion => 'Des achats impulsifs fréquents ?';

  @override
  String get debtCheckImpulsiveSub =>
      'Des dépenses non planifiées que tu regrettes.';

  @override
  String get debtCheckGamblingQuestion =>
      'Joues-tu de l\'argent régulièrement ?';

  @override
  String get debtCheckGamblingSub =>
      'Casinos, paris sportifs ou loteries fréquentes.';

  @override
  String get debtCheckAnalyzeButton => 'Analyser ma situation';

  @override
  String get debtCheckMentorTitle => 'Le mot du Mentor';

  @override
  String get debtCheckMentorBody =>
      'Ce check-up de 60 secondes nous permet de détecter les signaux d\'alerte avant qu\'ils ne deviennent critiques.';

  @override
  String get debtCheckYes => 'OUI';

  @override
  String get debtCheckNo => 'NON';

  @override
  String get debtCheckRiskLow => 'Risque Maîtrisé';

  @override
  String get debtCheckRiskMedium => 'Points d\'Attention';

  @override
  String get debtCheckRiskHigh => 'Alerte Critique';

  @override
  String get debtCheckRiskUnknown => 'Indéterminé';

  @override
  String debtCheckFactorsDetected(int count) {
    return '$count facteur(s) détecté(s)';
  }

  @override
  String get debtCheckRecommendationsTitle => 'RECOMMANDATIONS DU MENTOR';

  @override
  String get debtCheckValidateButton => 'Valider mon check-up';

  @override
  String get debtCheckRedoButton => 'Refaire le check-up';

  @override
  String get debtCheckHonestyQuote =>
      'L\'honnêteté envers soi-même est le premier pas vers la sérénité.';

  @override
  String get debtCheckGamblingSupportTitle => 'Soutien Jeux & Paris';

  @override
  String get debtCheckGamblingSupportBody =>
      'Un soutien professionnel et anonyme est disponible gratuitement.';

  @override
  String get debtCheckGamblingSupportCta => 'SOS Jeu - Aide en ligne';

  @override
  String get debtCheckPrivacyNote =>
      'Mint respecte ta vie privée. Aucune donnée n\'est stockée ou transmise.';

  @override
  String scoreRevealGreeting(String name) {
    return 'Voici ton score, $name.';
  }

  @override
  String get scoreRevealTitle => 'Ton diagnostic\nest prêt.';

  @override
  String get scoreRevealBudget => 'Budget';

  @override
  String get scoreRevealPrevoyance => 'Prévoyance';

  @override
  String get scoreRevealPatrimoine => 'Patrimoine';

  @override
  String get scoreRevealLevelExcellent => 'Excellent';

  @override
  String get scoreRevealLevelGood => 'Bon';

  @override
  String get scoreRevealLevelWarning => 'Attention';

  @override
  String get scoreRevealLevelCritical => 'Critique';

  @override
  String get scoreRevealCoachLabel => 'TON COACH';

  @override
  String get scoreRevealCtaDashboard => 'Voir mon dashboard';

  @override
  String get scoreRevealCtaReport => 'Voir le rapport détaillé';

  @override
  String get scoreRevealDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil financier (LSFin).';

  @override
  String get affordabilityTitle => 'Capacité d\'achat';

  @override
  String get affordabilitySource =>
      'Source : directive ASB sur le crédit hypothécaire, pratique bancaire suisse.';

  @override
  String get affordabilityIndicators => 'Indicateurs';

  @override
  String get affordabilityChargesRatio => 'Ratio charges / revenus';

  @override
  String get affordabilityEquityRatio => 'Fonds propres / prix';

  @override
  String get affordabilityOk => 'OK';

  @override
  String get affordabilityExceeded => 'Dépassé';

  @override
  String get affordabilityParameters => 'Tes hypothèses';

  @override
  String get affordabilityCanton => 'Canton';

  @override
  String get affordabilityGrossIncome => 'Revenu brut annuel';

  @override
  String get affordabilityTargetPrice => 'Prix d\'achat visé';

  @override
  String get affordabilityAvailableSavings => 'Épargne disponible';

  @override
  String get affordabilityPillar3a => 'Avoir 3a';

  @override
  String get affordabilityPillarLpp => 'Avoir LPP';

  @override
  String get affordabilityCalculationDetail => 'Détail du calcul';

  @override
  String get affordabilityEquityRequired => 'Fonds propres requis (20%)';

  @override
  String get affordabilitySavingsLabel => 'Épargne';

  @override
  String get affordabilityLppMax10 => 'Avoir LPP (max 10% du prix)';

  @override
  String get affordabilityTotalEquity => 'Total fonds propres';

  @override
  String affordabilityMortgagePercent(String percent) {
    return 'Hypothèque ($percent%)';
  }

  @override
  String get affordabilityMonthlyCharges => 'Charges mensuelles théoriques';

  @override
  String get affordabilityCalculationNote =>
      'Calcul théorique : hypothèque x (5% intérêt imputé + 1% amortissement) + prix x 1% frais accessoires. Max 33% du revenu brut.';

  @override
  String get amortizationSource =>
      'Source : OPP3 (pilier 3a), pratique hypothécaire suisse. Plafond 3a salarié 2026 : CHF 7\'258.';

  @override
  String get amortizationIntroTitle => 'Amortissement : direct ou indirect ?';

  @override
  String get amortizationIntroBody =>
      'En Suisse, l\'amortissement indirect est une spécificité unique : au lieu de rembourser directement la dette, tu verses dans un pilier 3a nanti. Tu bénéficies d\'une double déduction fiscale (intérêts + versement 3a) et ton capital reste investi.';

  @override
  String get amortizationDirect => 'Direct';

  @override
  String get amortizationDirectDesc =>
      'Tu rembourses la dette chaque année. Les intérêts diminuent progressivement.';

  @override
  String get amortizationIndirect => 'Indirect';

  @override
  String get amortizationIndirectDesc =>
      'Tu verses dans un 3a nanti. Double déduction fiscale.';

  @override
  String amortizationEvolutionTitle(int years) {
    return 'Évolution sur $years ans';
  }

  @override
  String get amortizationLegendDebtDirect => 'Dette (direct)';

  @override
  String get amortizationLegendDebtIndirect => 'Dette (indirect)';

  @override
  String get amortizationLegendCapital3a => 'Capital 3a';

  @override
  String get amortizationParameters => 'Paramètres';

  @override
  String get amortizationMortgageAmount => 'Montant hypothécaire';

  @override
  String get amortizationInterestRate => 'Taux d\'intérêt';

  @override
  String get amortizationDuration => 'Durée';

  @override
  String get amortizationMarginalRate => 'Taux marginal estimé';

  @override
  String get amortizationDetailedComparison => 'Comparaison détaillée';

  @override
  String get amortizationDirectTitle => 'Amortissement direct';

  @override
  String get amortizationTotalInterest => 'Total intérêts payés';

  @override
  String get amortizationNetCost => 'Coût net total';

  @override
  String get amortizationIndirectTitle => 'Amortissement indirect';

  @override
  String get amortizationCapital3aAccumulated => 'Capital 3a accumulé';

  @override
  String get fiscalComparatorTitle => 'Comparateur fiscal';

  @override
  String get fiscalTabMyTax => 'Mon impôt';

  @override
  String get fiscalTab26Cantons => '26 cantons';

  @override
  String get fiscalTabMove => 'Déménager';

  @override
  String get fiscalGrossAnnualIncome => 'Revenu brut annuel';

  @override
  String get fiscalCanton => 'Canton';

  @override
  String get fiscalCivilStatus => 'État civil';

  @override
  String get fiscalSingle => 'Célibataire';

  @override
  String get fiscalMarried => 'Marié·e';

  @override
  String get fiscalChildren => 'Enfants';

  @override
  String get fiscalNetWealth => 'Fortune nette';

  @override
  String get fiscalChurchMember => 'Membre d\'une Église';

  @override
  String get fiscalChurchTax => 'Impôt ecclésiastique';

  @override
  String get fiscalEffectiveRate => 'Taux effectif estimé';

  @override
  String fiscalBelowAverage(String rate) {
    return 'Inférieur à la moyenne suisse (~$rate%)';
  }

  @override
  String fiscalAboveAverage(String rate) {
    return 'Supérieur à la moyenne suisse (~$rate%)';
  }

  @override
  String get fiscalBreakdownTitle => 'DÉCOMPOSITION FISCALE';

  @override
  String get fiscalFederalTax => 'Impôt fédéral';

  @override
  String get fiscalCantonalCommunalTax => 'Impôt cantonal + communal';

  @override
  String get fiscalWealthTax => 'Impôt sur la fortune';

  @override
  String get fiscalTotalBurden => 'Charge fiscale totale';

  @override
  String get fiscalNationalPosition => 'POSITION NATIONALE';

  @override
  String get fiscalRanks => 'se classe';

  @override
  String get fiscalCantons => 'cantons';

  @override
  String get fiscalCheapest => 'Le moins cher';

  @override
  String get fiscalMostExpensive => 'Le plus cher';

  @override
  String get fiscalGapBetweenCantons =>
      'd\'écart entre le canton le moins et le plus cher';

  @override
  String get fiscalMoveIntro =>
      'Simule l\'impact fiscal d\'un déménagement entre deux cantons. Les paramètres de revenu et situation familiale sont partagés avec l\'onglet \"Mon impôt\".';

  @override
  String get fiscalCurrentCanton => 'Canton actuel';

  @override
  String get fiscalDestinationCanton => 'Canton de destination';

  @override
  String get fiscalIncomeTaxLabel => 'Impôts sur le revenu';

  @override
  String get fiscalEstimateNote => 'Estimatif selon taux cantonal';

  @override
  String get fiscalEstimatedRent => 'Loyer estimé';

  @override
  String get fiscalRentNote => 'Varie selon commune et surface';

  @override
  String get fiscalMovingCosts => 'Frais de déménagement';

  @override
  String get fiscalMovingCostsNote => 'Amorti sur 24 mois';

  @override
  String get fiscalWealthTaxTitle => 'IMPÔT SUR LA FORTUNE';

  @override
  String fiscalNetWealthAmount(String amount) {
    return 'Fortune nette : $amount';
  }

  @override
  String fiscalWealthSaving(String amount) {
    return 'Économie fortune : $amount/an';
  }

  @override
  String fiscalWealthSurcharge(String amount) {
    return 'Surcoût fortune : $amount/an';
  }

  @override
  String get fiscalWealthEquivalent => 'Impôt fortune équivalent';

  @override
  String get fiscalChecklist1 => 'Déclarer ton départ à ta commune actuelle';

  @override
  String get fiscalChecklist2 =>
      'S\'annoncer à la nouvelle commune dans les 14 jours';

  @override
  String get fiscalChecklist3 =>
      'Mettre à jour l\'adresse auprès de la caisse maladie';

  @override
  String get fiscalChecklist4 =>
      'Adapter la déclaration d\'impôts (prorata temporis)';

  @override
  String get fiscalChecklist5 =>
      'Vérifier les subsides LAMal du nouveau canton';

  @override
  String get fiscalChecklist6 =>
      'Transférer les inscriptions (véhicule, écoles, etc.)';

  @override
  String get fiscalChecklistTitle => 'CHECKLIST DÉMÉNAGEMENT';

  @override
  String get fiscalGoodToKnow => 'BON À SAVOIR';

  @override
  String get fiscalEduDateTitle => 'Date de référence : 31 décembre';

  @override
  String get fiscalEduDateBody =>
      'Tu es imposé dans le canton où tu résidais au 31 décembre de l\'année fiscale. Un déménagement au 30 décembre compte pour toute l\'année !';

  @override
  String get fiscalEduProrataTitle => 'Prorata temporis';

  @override
  String get fiscalEduProrataBody =>
      'L\'impôt fédéral est toujours le même. Seuls les impôts cantonaux et communaux changent. Le prorata s\'applique l\'année du déménagement.';

  @override
  String get fiscalEduRentTitle => 'Loyers et coût de la vie';

  @override
  String get fiscalEduRentBody =>
      'N\'oublie pas que les économies fiscales peuvent être compensées par des différences de loyer et de coût de la vie. Compare le budget global, pas seulement les impôts.';

  @override
  String get fiscalCommune => 'Commune';

  @override
  String get fiscalCapitalDefault => 'Chef-lieu (par défaut)';

  @override
  String get fiscalDisclaimer =>
      'Estimations simplifiées à but éducatif — ne constitue pas un conseil fiscal. Les taux effectifs dépendent de nombreux facteurs (déductions, fortune, commune, etc.). Consulte un·e spécialiste fiscal·e pour un calcul personnalisé.';

  @override
  String get expatTitle => 'Expatriation';

  @override
  String get expatTabForfait => 'Forfait';

  @override
  String get expatTabDeparture => 'Départ';

  @override
  String get expatTabAvs => 'AVS';

  @override
  String get expatForfaitEducation =>
      'Le forfait fiscal (imposition d\'après la dépense) permet aux personnes de nationalité étrangère de ne pas être imposées sur leur revenu mondial, mais sur la base de leurs dépenses de vie. Environ 5\'000 personnes en bénéficient en Suisse.';

  @override
  String get expatHighlightSchwyz => 'Fiscalité la plus avantageuse de Suisse';

  @override
  String get expatHighlightZug => 'Hub international, accès Zurich';

  @override
  String get expatCanton => 'Canton';

  @override
  String get expatLivingExpenses => 'Dépenses de vie annuelles';

  @override
  String get expatActualIncome => 'Revenu réel annuel';

  @override
  String get expatTaxComparison => 'COMPARAISON FISCALE';

  @override
  String get expatForfaitFiscal => 'Forfait fiscal';

  @override
  String get expatOrdinaryTaxation => 'Imposition ordinaire';

  @override
  String get expatOnActualIncome => 'Sur revenu réel';

  @override
  String get expatAbolishedCantons => 'Cantons ayant aboli le forfait';

  @override
  String expatAbolishedNote(String names) {
    return '$names — le forfait fiscal n\'est plus disponible dans ces cantons.';
  }

  @override
  String get expatDepartureDate => 'Date de départ';

  @override
  String get expatCurrentCanton => 'Canton actuel';

  @override
  String get expatPillar3aBalance => 'Solde pilier 3a';

  @override
  String get expatLppBalance => 'Solde LPP (avoir de vieillesse)';

  @override
  String get expatNoExitTax => 'Pas de taxe de sortie en Suisse';

  @override
  String get expatRecommendedTimeline => 'CHRONOLOGIE RECOMMANDÉE';

  @override
  String get expatDepartureChecklist => 'CHECKLIST DE DÉPART';

  @override
  String get expatAvsEducation =>
      'Pour toucher une rente AVS complète (max CHF 2\'520/mois), il faut 44 années de cotisation sans lacune. Chaque année manquante réduit ta rente d\'environ 2.3%. Si tu vis à l\'étranger, tu peux cotiser volontairement à l\'AVS pour éviter les lacunes.';

  @override
  String get expatYearsInSwitzerland => 'Années en Suisse';

  @override
  String get expatYearsAbroad => 'Années à l\'étranger';

  @override
  String get expatAvsCompleteness => 'COMPLÉTUDE AVS';

  @override
  String get expatOfPension => 'de rente';

  @override
  String get expatEstimatedPension => 'Rente estimée';

  @override
  String get expatAvsComplete =>
      'C\'est acquis : tu as tes 44 années complètes de cotisation. Ta rente AVS ne devrait pas être réduite.';

  @override
  String get expatPensionImpact => 'IMPACT SUR TA RENTE';

  @override
  String get expatMissingYears => 'Années manquantes';

  @override
  String get expatEstimatedReduction => 'Réduction estimée';

  @override
  String get expatMonthlyLoss => 'Perte mensuelle';

  @override
  String get expatAnnualLoss => 'Perte annuelle';

  @override
  String get expatVoluntaryContribution => 'COTISATION VOLONTAIRE';

  @override
  String get expatVoluntaryAvsTitle => 'AVS facultative depuis l\'étranger';

  @override
  String get expatMinContribution => 'Cotisation minimum';

  @override
  String get expatMaxContribution => 'Cotisation maximum';

  @override
  String get expatVoluntaryAvsBody =>
      'Tu peux cotiser volontairement à l\'AVS si tu vis à l\'étranger. Délai d\'inscription : 1 an après le départ de Suisse. Conditions : avoir cotisé au moins 5 ans consécutifs avant le départ.';

  @override
  String get expatRecommendation => 'RECOMMANDÉE';

  @override
  String get expatDidYouKnow => 'Le savais-tu ?';

  @override
  String get mariageTimelinePartner1 => 'Personne 1';

  @override
  String get mariageTimelinePartner2 => 'Personne 2';

  @override
  String get mariageTimelineCoachTip =>
      'Chaque phase de vie demande d\'adapter votre contrat de mariage et votre prévoyance.';

  @override
  String get mariageTimelineAct1Title => 'Vous travaillez tous les deux';

  @override
  String get mariageTimelineAct1Period => '0-10 ans de vie commune';

  @override
  String get mariageTimelineAct1Insight =>
      'Phase de construction : 3a, LPP, épargne commune. Profitez des deux revenus.';

  @override
  String get mariageTimelineAct2Title => 'Phase d\'épargne intensive';

  @override
  String get mariageTimelineAct2Period => '10-25 ans';

  @override
  String get mariageTimelineAct2Insight =>
      'Rachat LPP, 3a maximal, préparation retraite. Votre capital double.';

  @override
  String get mariageTimelineAct3Title => 'Retraite couple';

  @override
  String get mariageTimelineAct3Period => '25+ ans';

  @override
  String get mariageTimelineAct3Insight =>
      'Attention : plafond AVS couple (150% rente max). Planifier rente vs capital.';

  @override
  String get naissanceChecklistItem1Title =>
      'Inscrire bébé à l\'assurance maladie (3 mois)';

  @override
  String get naissanceChecklistItem1Desc =>
      'Tu as 3 mois après la naissance pour inscrire ton enfant auprès d\'une caisse maladie. Si tu le fais dans ce délai, la couverture est rétroactive dès la naissance. Passé ce délai, l\'enfant risque une interruption de couverture. Compare les primes enfants entre caisses — les écarts peuvent être significatifs.';

  @override
  String get naissanceChecklistItem2Title =>
      'Demander les allocations familiales';

  @override
  String get naissanceChecklistItem2Desc =>
      'Fais la demande auprès de ton employeur (ou de ta caisse d\'allocations si tu es indépendant·e). Les allocations sont versées dès le mois de naissance. Le montant dépend du canton (CHF 200 à CHF 305/mois par enfant).';

  @override
  String get naissanceChecklistItem3Title =>
      'Annoncer la naissance à l\'état civil';

  @override
  String get naissanceChecklistItem3Desc =>
      'L\'hôpital transmet généralement l\'annonce à l\'office de l\'état civil. Vérifie que l\'acte de naissance est bien établi. Tu en auras besoin pour toutes les démarches administratives.';

  @override
  String get naissanceChecklistItem4Title =>
      'Organiser le congé parental (APG)';

  @override
  String get naissanceChecklistItem4Desc =>
      'Congé maternité : 14 semaines à 80% du salaire (max CHF 220/jour). Congé paternité : 2 semaines (10 jours), à prendre dans les 6 mois. L\'inscription APG se fait via ton employeur ou directement auprès de la caisse de compensation.';

  @override
  String get naissanceChecklistItem5Title =>
      'Mettre à jour la déclaration fiscale';

  @override
  String get naissanceChecklistItem5Desc =>
      'Un enfant supplémentaire te donne droit à une déduction fiscale de CHF 6\'700/an (LIFD art. 35). Si tu as des frais de garde, tu peux déduire jusqu\'à CHF 25\'500/an. Pense à adapter tes acomptes d\'impôts pour l\'année en cours.';

  @override
  String get naissanceChecklistItem6Title => 'Adapter le budget familial';

  @override
  String get naissanceChecklistItem6Desc =>
      'Un enfant coûte en moyenne CHF 1\'200 à CHF 1\'500/mois en Suisse (alimentation, vêtements, activités, assurance, couches, etc.). Réévalue ton budget avec le module Budget de MINT.';

  @override
  String get naissanceChecklistItem7Title =>
      'Vérifier la prévoyance (LPP et 3a)';

  @override
  String get naissanceChecklistItem7Desc =>
      'Si tu réduis ton taux d\'activité, tes cotisations LPP baissent. Chaque année à temps partiel représente moins de capital à la retraite. Envisage de compenser en versant le maximum au 3e pilier (CHF 7\'258/an).';

  @override
  String get naissanceChecklistItem8Title =>
      'Rédiger ou mettre à jour le testament';

  @override
  String get naissanceChecklistItem8Desc =>
      'L\'arrivée d\'un enfant modifie l\'ordre successoral. Les enfants sont des héritiers réservataires (CC art. 471). Si tu as un testament, vérifie qu\'il respecte les réserves légales.';

  @override
  String get naissanceChecklistItem9Title =>
      'Souscrire une assurance risque décès/invalidité';

  @override
  String get naissanceChecklistItem9Desc =>
      'Avec un enfant à charge, la protection financière en cas de décès ou d\'invalidité devient encore plus importante. Vérifie ta couverture actuelle (LPP, assurance-vie) et complète si nécessaire.';

  @override
  String get naissanceBabyCostCreche => 'Crèche / garde';

  @override
  String get naissanceBabyCostCrecheNote =>
      'Tarif moyen subventionné — varie fortement selon canton';

  @override
  String get naissanceBabyCostAlimentation => 'Alimentation';

  @override
  String get naissanceBabyCostVetements => 'Vêtements & équipement';

  @override
  String get naissanceBabyCostLamal => 'LAMal enfant';

  @override
  String get naissanceBabyCostLamalNote =>
      'Prime moyenne enfant — sans franchise jusqu\'à 18 ans';

  @override
  String get naissanceBabyCostActivites => 'Activités & loisirs';

  @override
  String get naissanceBabyCostDivers => 'Divers (jouets, hygiène…)';

  @override
  String get waterfallBrutMensuel => 'Brut mensuel';

  @override
  String get waterfallAvsAc => 'AVS / AC';

  @override
  String get waterfallLppEmploye => 'LPP employé';

  @override
  String get waterfallNetFicheDePaie => 'Net fiche de paie';

  @override
  String get waterfallImpots => 'Impôts';

  @override
  String get waterfallDisponible => 'Disponible';

  @override
  String get waterfallLoyer => 'Loyer';

  @override
  String get waterfallLamal => 'LAMal';

  @override
  String get waterfallLeasing => 'Leasing';

  @override
  String get waterfallAutresFixes => 'Autres fixes';

  @override
  String get waterfallResteAVivre => 'Reste à vivre';

  @override
  String get waterfallPillar3a => '3a';

  @override
  String get waterfallInvestissement => 'Investissement';

  @override
  String get waterfallMargeLibre => 'Marge libre';

  @override
  String get waterfallTitle => 'Cascade budgétaire';

  @override
  String get narrativeDefaultName => 'Tu';

  @override
  String narrativeCouplePositiveMargin(String margin) {
    return 'Ensemble, vous avez une marge de $margin CHF/mois.';
  }

  @override
  String narrativeCoupleTightBudget(String margin) {
    return 'Ensemble, votre budget est serré de $margin CHF/mois.';
  }

  @override
  String narrativeCoupleHighPatrimoine(String patrimoine) {
    return 'Avec un patrimoine de $patrimoine CHF, vous avez des leviers.';
  }

  @override
  String narrativeHighHealth(String name) {
    return '$name, tu es en bonne santé financière. Continue.';
  }

  @override
  String narrativeHighHealthPatrimoine(String patrimoine) {
    return 'Ton patrimoine de $patrimoine CHF te donne une belle marge de manœuvre.';
  }

  @override
  String narrativeLowHealth(String name) {
    return '$name, concentre-toi sur l\'essentiel. On va stabiliser ensemble.';
  }

  @override
  String narrativeLowHealthPatrimoine(String patrimoine) {
    return 'Ton patrimoine de $patrimoine CHF est un atout à protéger.';
  }

  @override
  String narrativeMediumHealth(String name) {
    return '$name, tu as de bonnes bases. Quelques actions peuvent faire la différence.';
  }

  @override
  String narrativeMediumHealthPatrimoine(String patrimoine) {
    return 'Ton patrimoine de $patrimoine CHF est un bon point de départ.';
  }

  @override
  String narrativeConfidenceLabel(String score) {
    return 'Confiance profil : $score%';
  }

  @override
  String patrimoineCoupleTitleCouple(String firstName, String conjointName) {
    return 'Patrimoine — $firstName & $conjointName';
  }

  @override
  String patrimoineCoupleTitleSolo(String firstName) {
    return 'Patrimoine — $firstName';
  }

  @override
  String get patrimoineLiquide => 'LIQUIDE';

  @override
  String get patrimoineImmobilier => 'IMMOBILIER';

  @override
  String get patrimoinePrevoyance => 'PRÉVOYANCE';

  @override
  String get patrimoineEpargne => 'Épargne';

  @override
  String get patrimoineInvest => 'Invest.';

  @override
  String get patrimoineAucunBien => 'Aucun bien';

  @override
  String get patrimoineValeur => 'Valeur';

  @override
  String get patrimoineHypo => '−Hypo.';

  @override
  String get patrimoineNet => 'Net';

  @override
  String get patrimoineLtvSaine => 'LTV saine';

  @override
  String get patrimoineLtvAmortissement => 'Amortissement recommandé';

  @override
  String get patrimoineLtvElevee => 'LTV élevée — amortir';

  @override
  String patrimoineLtvDisplay(String percent) {
    return 'LTV $percent%';
  }

  @override
  String get patrimoineLpp => 'LPP';

  @override
  String get patrimoine3a => '3a';

  @override
  String get patrimoineLibrePassage => 'Libre pass.';

  @override
  String get patrimoineTotal => 'Total';

  @override
  String get patrimoineBrut => 'Patrimoine brut';

  @override
  String get patrimoineDettes => '−Dettes';

  @override
  String get patrimoineNetLabel => 'Patrimoine net';

  @override
  String patrimoineDont(String name, String amount) {
    return 'dont $name ~CHF $amount';
  }

  @override
  String get conjointProfilsLies => 'Profils liés';

  @override
  String get conjointProfilConjoint => 'Profil conjoint·e';

  @override
  String conjointDeclaredStatus(String name) {
    return '$name n\'a pas de compte MINT. Ses données sont estimées (🟡).';
  }

  @override
  String conjointInvitedStatus(String name) {
    return 'Invitation envoyée à $name. En attente de réponse.';
  }

  @override
  String conjointLinkedStatus(String name) {
    return '✅ Profils liés ! Les données de $name sont synchronisées.';
  }

  @override
  String conjointInviteLabel(String name) {
    return 'Inviter $name (5 questions, sans compte)';
  }

  @override
  String get conjointLierProfils => 'Lier nos profils';

  @override
  String get conjointRenvoyerInvitation => 'Renvoyer l\'invitation';

  @override
  String get conjointRegimeLabel => 'Régime matrimonial : ';

  @override
  String get conjointRegimeParticipation => 'Participation aux acquêts';

  @override
  String get conjointRegimeSeparation => 'Séparation de biens';

  @override
  String get conjointRegimeCommunaute => 'Communauté de biens';

  @override
  String get conjointRegimeDefault => '(défaut CC art. 196)';

  @override
  String get conjointModifier => 'modifier';

  @override
  String get futurHorizonTitle => 'Horizon Retraite';

  @override
  String get futurCoupleLabel => 'Couple';

  @override
  String get futurTauxRemplacement => 'Taux de remplacement';

  @override
  String get futurAgeRetraite => 'Age retraite';

  @override
  String get futurConfiance => 'Confiance';

  @override
  String get futurRevenuMensuelProjection =>
      'Revenu mensuel projeté à la retraite';

  @override
  String get futurRenteAvs => 'Rente AVS';

  @override
  String get futurRenteLpp => 'Rente LPP estimée';

  @override
  String get futurPilier3aSwr => 'Pilier 3a (SWR 4%)';

  @override
  String futurCapitalLabel(String amount) {
    return 'Capital $amount';
  }

  @override
  String get futurLibrePassageSwr => 'Libre passage (SWR 4%)';

  @override
  String get futurInvestissementsSwr => 'Investissements (SWR 4%)';

  @override
  String get futurTotalCoupleProjecte => 'Total couple projeté';

  @override
  String get futurTotalMensuelProjecte => 'Total mensuel projeté';

  @override
  String get futurCapitalRetraite => 'Capital à la retraite';

  @override
  String get futurCapitalTotal =>
      'Capital total (LPP + 3a + LP + investissements)';

  @override
  String get futurCapitalTaxHint =>
      'Le retrait en capital est taxé séparément (LIFD art. 38). Le SWR n\'est pas un revenu imposable.';

  @override
  String futurMargeIncertitude(String pct) {
    return 'Marge d\'incertitude (± $pct%)';
  }

  @override
  String futurFourchette(String low, String high) {
    return 'Fourchette : CHF $low – $high/mois';
  }

  @override
  String get futurCompleterProfil =>
      'Complete ton profil pour affiner la projection.';

  @override
  String get futurDisclaimer =>
      'Projection éducative — ne constitue pas un conseil (LSFin). SWR 4% = règle des 4%, résultats non assurés. Rentes AVS/LPP estimées selon LAVS art. 21-40, LPP art. 14-16.';

  @override
  String get futurExplorerDetails => 'Explorer les détails';

  @override
  String get financialSummaryTitle => 'APERÇU FINANCIER';

  @override
  String get financialSummaryNoProfile => 'Aucun profil renseigné';

  @override
  String get financialSummaryStartDiagnostic => 'Commencer le diagnostic';

  @override
  String get financialSummaryRestartDiagnostic => 'Recommencer le diagnostic';

  @override
  String get financialSummaryNarrativeFiscalite =>
      'L\'optimisation fiscale est ton premier levier : 3a, rachat LPP, déductions.';

  @override
  String get financialSummaryNarrativePrevoyance =>
      'Ta prévoyance détermine ton confort à la retraite. Chaque année compte.';

  @override
  String get financialSummaryNarrativeAvs =>
      'L\'AVS est la base de ta retraite. Vérifie tes lacunes de cotisation.';

  @override
  String get financialSummaryLegendSaisi => 'Saisi';

  @override
  String get financialSummaryLegendEstime => 'Estimé';

  @override
  String get financialSummaryLegendCertifie => 'Certifié';

  @override
  String get financialSummarySalaireBrutMensuel => 'Salaire brut mensuel';

  @override
  String get financialSummary13emeSalaire => '13ème salaire';

  @override
  String financialSummaryNemeMois(String n) {
    return '$nème mois';
  }

  @override
  String financialSummaryBonusEstime(String pct) {
    return 'Bonus estimé ($pct%)';
  }

  @override
  String financialSummaryConjointBrutMensuel(String name) {
    return '$name — brut mensuel';
  }

  @override
  String get financialSummaryDefaultConjoint => 'Conjoint·e';

  @override
  String get financialSummaryRevenuBrutAnnuel => 'Revenu brut annuel';

  @override
  String get financialSummaryRevenuBrutAnnuelCouple =>
      'Revenu brut annuel (couple)';

  @override
  String get financialSummarySoitLisseSur12Mois => 'soit lissé sur 12 mois';

  @override
  String get financialSummaryDeductionsSalariales => 'Déductions salariales';

  @override
  String get financialSummaryChargesSociales => 'Charges sociales (AVS/AI/AC)';

  @override
  String get financialSummaryCotisationLpp => 'Cotisation LPP employé·e';

  @override
  String get financialSummaryNetFicheDePaie => 'Net fiche de paie';

  @override
  String get financialSummaryNetFicheDePaieHint =>
      'Ce qui arrive sur ton compte chaque mois';

  @override
  String get financialSummaryFiscalite => 'Fiscalité';

  @override
  String get financialSummaryImpotEstime => 'Impôt estimé (ICC + IFD)';

  @override
  String get financialSummaryTauxMarginalEstime => 'Taux marginal estimé';

  @override
  String financialSummary13emeEtBonusHint(String label, String montant) {
    return '$label : ~$montant net/an (non inclus dans le mensuel)';
  }

  @override
  String get financialSummaryRevenusEtFiscalite => 'Revenus & Fiscalité';

  @override
  String get financialSummaryDisponibleApresImpot => 'Disponible après impôt';

  @override
  String get financialSummaryFootnoteRevenus =>
      'Estimation simplifiée. L\'AANP et l\'IJM varient selon l\'employeur et ne sont pas inclus. La LPP employé·e reflète le minimum légal (50/50) — ta caisse peut appliquer un autre split.';

  @override
  String get financialSummaryScanFicheSalaire => 'Scanner ma fiche de salaire';

  @override
  String get financialSummaryModifierRevenu => 'Modifier le revenu';

  @override
  String get financialSummaryEditSalaireBrut => 'Salaire brut mensuel (CHF)';

  @override
  String get financialSummaryAvs1erPilier => 'AVS (1er pilier)';

  @override
  String get financialSummaryAnneesCotisees => 'Années cotisées';

  @override
  String financialSummaryAnneesUnit(String n) {
    return '$n ans';
  }

  @override
  String get financialSummaryLacunes => 'Lacunes';

  @override
  String get financialSummaryRenteEstimee => 'Rente estimée';

  @override
  String get financialSummaryLpp2ePilier => 'LPP (2e pilier)';

  @override
  String get financialSummaryAvoirTotal => 'Avoir total';

  @override
  String get financialSummaryObligatoire => 'Obligatoire';

  @override
  String get financialSummarySurobligatoire => 'Surobligatoire';

  @override
  String get financialSummaryTauxConversion => 'Taux de conversion';

  @override
  String get financialSummaryRachatPossible => 'Rachat possible';

  @override
  String get financialSummaryRachatPlanifie => 'Rachat planifié';

  @override
  String get financialSummaryCaisse => 'Caisse';

  @override
  String get financialSummary3a3ePilier => '3a (3e pilier)';

  @override
  String financialSummaryNComptes(String n) {
    return '$n compte(s)';
  }

  @override
  String get financialSummaryLibrePassage => 'Libre passage';

  @override
  String financialSummaryCompteN(String n) {
    return 'Compte $n';
  }

  @override
  String financialSummaryConjointLpp(String name) {
    return '$name — LPP';
  }

  @override
  String financialSummaryConjoint3a(String name) {
    return '$name — 3a';
  }

  @override
  String get financialSummaryFatcaWarning =>
      '⚠️ FATCA — Seule une minorité de prestataires accepte (ex. Raiffeisen)';

  @override
  String get financialSummaryPrevoyanceTitle => 'Prévoyance';

  @override
  String get financialSummaryScanCertificatLpp =>
      'Scanner certificat LPP / AVS';

  @override
  String get financialSummaryModifierPrevoyance => 'Modifier la prévoyance';

  @override
  String get financialSummaryEditAvoirLpp => 'Avoir LPP total (CHF)';

  @override
  String get financialSummaryEditNombre3a => 'Nombre de comptes 3a';

  @override
  String get financialSummaryEditTotal3a => 'Total épargne 3a (CHF)';

  @override
  String get financialSummaryEditRachatLpp =>
      'Rachat LPP mensuel prévu (CHF/mois)';

  @override
  String get financialSummaryLiquidites => 'Liquidités';

  @override
  String get financialSummaryEpargneLiquide => 'Épargne liquide';

  @override
  String get financialSummaryInvestissements => 'Investissements';

  @override
  String get financialSummaryImmobilier => 'Immobilier';

  @override
  String get financialSummaryValeurEstimee => 'Valeur estimée';

  @override
  String get financialSummaryHypothequeRestante => 'Hypothèque restante';

  @override
  String get financialSummaryValeurNetteImmobiliere =>
      'Valeur nette immobilière';

  @override
  String financialSummaryLtvAmortissement(String pct) {
    return 'Ratio LTV : $pct% — amortissement 2ème rang obligatoire';
  }

  @override
  String financialSummaryLtvBonneVoie(String pct) {
    return 'Ratio LTV : $pct% — en bonne voie';
  }

  @override
  String financialSummaryLtvExcellent(String pct) {
    return 'Ratio LTV : $pct% — excellent';
  }

  @override
  String get financialSummaryPrevoyanceCapital => 'Prévoyance (capital)';

  @override
  String get financialSummaryAvoirLppTotal => 'Avoir LPP total';

  @override
  String financialSummaryCapital3a(String n, String s) {
    return 'Capital 3a ($n compte$s)';
  }

  @override
  String get financialSummaryPatrimoineBrut => 'Patrimoine brut';

  @override
  String get financialSummaryDettesTotales => 'Dettes totales';

  @override
  String get financialSummaryPatrimoine => 'Patrimoine';

  @override
  String get financialSummaryPatrimoineTotalBloque =>
      'Patrimoine total (y.c. prévoyance bloquée)';

  @override
  String get financialSummaryModifierPatrimoine => 'Modifier le patrimoine';

  @override
  String get financialSummaryEditEpargneLiquide => 'Épargne liquide (CHF)';

  @override
  String get financialSummaryEditInvestissements => 'Investissements (CHF)';

  @override
  String get financialSummaryEditValeurImmobiliere =>
      'Valeur immobilière (CHF)';

  @override
  String get financialSummaryLoyerCharges => 'Loyer / charges';

  @override
  String get financialSummaryAssuranceMaladie => 'Assurance maladie';

  @override
  String get financialSummaryElectriciteEnergie => 'Électricité / énergie';

  @override
  String get financialSummaryTransport => 'Transport';

  @override
  String get financialSummaryTelecom => 'Télécom';

  @override
  String get financialSummaryFraisMedicaux => 'Frais médicaux';

  @override
  String get financialSummaryAutresFraisFixes => 'Autres frais fixes';

  @override
  String get financialSummaryAucuneDepense => 'Aucune dépense renseignée';

  @override
  String get financialSummaryDepensesFixes => 'Dépenses fixes';

  @override
  String get financialSummaryTotalMensuel => 'Total mensuel';

  @override
  String get financialSummaryModifierDepenses => 'Modifier les dépenses';

  @override
  String get financialSummaryEditLoyerCharges => 'Loyer / charges (CHF/mois)';

  @override
  String get financialSummaryEditAssuranceMaladie =>
      'Assurance maladie (CHF/mois)';

  @override
  String get financialSummaryEditElectricite =>
      'Électricité / énergie (CHF/mois)';

  @override
  String get financialSummaryEditTransport => 'Transport (CHF/mois)';

  @override
  String get financialSummaryEditTelecom => 'Télécom (CHF/mois)';

  @override
  String get financialSummaryEditFraisMedicaux => 'Frais médicaux (CHF/mois)';

  @override
  String get financialSummaryEditAutresFraisFixes =>
      'Autres frais fixes (CHF/mois)';

  @override
  String get financialSummaryModifierDettes => 'Modifier les dettes';

  @override
  String get financialSummaryEditHypotheque => 'Hypothèque (CHF)';

  @override
  String get financialSummaryEditCreditConsommation =>
      'Crédit consommation (CHF)';

  @override
  String get financialSummaryEditLeasing => 'Leasing (CHF)';

  @override
  String get financialSummaryEditAutresDettes => 'Autres dettes (CHF)';

  @override
  String get financialSummaryDettes => 'Dettes';

  @override
  String get financialSummaryAucuneDetteDeclaree => 'Aucune dette déclarée — ';

  @override
  String get financialSummaryDetteStructurelle => 'Dette structurelle';

  @override
  String get financialSummaryHypotheque1erRang => 'Hypothèque 1er rang';

  @override
  String get financialSummaryHypotheque2emeRang => 'Hypothèque 2ème rang';

  @override
  String get financialSummaryHypotheque => 'Hypothèque';

  @override
  String get financialSummaryChargeMensuelle => 'Charge mensuelle';

  @override
  String financialSummaryEcheance(String date, String years) {
    return 'Échéance : $date (~$years ans)';
  }

  @override
  String financialSummaryInteretsDeductibles(String montant) {
    return 'Intérêts déductibles (LIFD art. 33) : $montant/an';
  }

  @override
  String get financialSummaryDetteConsommation => 'Dette à la consommation';

  @override
  String get financialSummaryCreditConsommation => 'Crédit consommation';

  @override
  String get financialSummaryMensualite => 'Mensualité';

  @override
  String get financialSummaryLeasing => 'Leasing';

  @override
  String get financialSummaryAutresDettes => 'Autres dettes';

  @override
  String financialSummaryConseilRemboursement(String taux) {
    return 'Rembourse d\'abord la dette à $taux% avant d\'investir. Chaque CHF remboursé = $taux% de rendement effectif.';
  }

  @override
  String get financialSummaryTotalDettes => 'Total dettes';

  @override
  String get financialSummaryScannerDocument => 'Scanner un document';

  @override
  String get financialSummaryCascadeBudgetaire => 'Cascade budgétaire';

  @override
  String get financialSummaryToi => 'Toi';

  @override
  String get financialSummaryConjointeDefault => 'Conjoint·e';

  @override
  String get financialSummaryDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil financier (LSFin, LAVS, LPP, LIFD). Les valeurs estimées (~) sont calculées à partir de moyennes suisses. Scanne tes certificats pour affiner la précision de tes projections.';

  @override
  String get financialSummaryEnregistrer => 'Enregistrer';

  @override
  String get financialSummaryCheckSalaireBrut => 'Salaire brut';

  @override
  String get financialSummaryCheckCanton => 'Canton';

  @override
  String get financialSummaryCheckAvoirLpp => 'Avoir LPP';

  @override
  String get financialSummaryCheckEpargne3a => 'Épargne 3a';

  @override
  String get financialSummaryCheckEpargneLiquide => 'Épargne liquide';

  @override
  String get financialSummaryCheckLoyerHypotheque => 'Loyer / hypothèque';

  @override
  String get financialSummaryCheckAssuranceMaladie => 'Assurance maladie';

  @override
  String get financialSummaryWhatIf3aQuestion =>
      'Et si tu maximisais ton 3a chaque année ?';

  @override
  String get financialSummaryWhatIf3aExplanation =>
      'À ton taux marginal, chaque franc versé en 3a te fait économiser ~30 % d\'impôts.';

  @override
  String get financialSummaryWhatIf3aAction => 'Simuler';

  @override
  String get financialSummaryWhatIfLppQuestion =>
      'Et si ta caisse LPP passait de 1 % à 3 % ?';

  @override
  String get financialSummaryWhatIfLppExplanation =>
      'Un rendement LPP plus élevé augmente ton capital à la retraite sans effort de ta part.';

  @override
  String get financialSummaryWhatIfLppAction => 'Comparer';

  @override
  String get financialSummaryWhatIfAchatQuestion =>
      'Et si tu achetais au lieu de louer ?';

  @override
  String get financialSummaryWhatIfAchatExplanation =>
      'L\'amortissement indirect via le 2e pilier peut réduire tes impôts tout en constituant un patrimoine.';

  @override
  String get financialSummaryWhatIfAchatAction => 'Explorer';

  @override
  String get dataQualityTitle => 'Qualité des données';

  @override
  String dataQualityMissingCount(String count) {
    return '$count information(s) à ajouter';
  }

  @override
  String get dataQualityComplete => 'Profil complet';

  @override
  String get dataQualityKnownSection => 'Données connues';

  @override
  String get dataQualityMissingSection => 'Données manquantes';

  @override
  String get dataQualityCompleteness => 'Complétude';

  @override
  String get dataQualityAccuracy => 'Exactitude';

  @override
  String get dataQualityFreshness => 'Fraîcheur';

  @override
  String get dataQualityCombined => 'Score combiné';

  @override
  String get dataQualityEnrich => 'Enrichir mon profil';

  @override
  String dataQualityEnrichWithImpact(String impact) {
    return 'Enrichir mon profil ($impact)';
  }

  @override
  String get confidenceLabelSalaire => 'Salaire brut';

  @override
  String get confidenceLabelAgeCanton => 'Âge / Canton';

  @override
  String get confidenceLabelAge => 'Âge';

  @override
  String get confidenceLabelCanton => 'Canton';

  @override
  String get confidenceLabelMenage => 'Situation du ménage';

  @override
  String get confidenceLabelAvoirLpp => 'Avoir LPP';

  @override
  String get confidenceLabelTauxConversion => 'Taux de conversion';

  @override
  String get confidenceLabelAnneesAvs => 'Années AVS';

  @override
  String get confidenceLabelEpargne3a => 'Épargne 3a';

  @override
  String get confidenceLabelPatrimoine => 'Patrimoine';

  @override
  String get confidencePromptFreshnessPrefix => 'Actualise : ';

  @override
  String confidencePromptFreshnessStale(String months) {
    return 'Donnée datant de $months mois — rescanne ton certificat';
  }

  @override
  String get confidencePromptFreshnessConfirm =>
      'Confirme que cette valeur est toujours actuelle';

  @override
  String get confidencePromptAccuracyPrefix => 'Confirme : ';

  @override
  String get confidencePromptAccuracyEstimated => 'Saisis ta valeur réelle';

  @override
  String get confidencePromptAccuracyCertificate =>
      'Scanne ton certificat pour confirmer';

  @override
  String get pulseTitle => 'Aujourd’hui';

  @override
  String pulseGreeting(String name) {
    return 'Bonjour $name';
  }

  @override
  String pulseGreetingCouple(String name1, String name2) {
    return 'Bonjour $name1 et $name2';
  }

  @override
  String get pulseWelcome => 'On regarde où tu en es.';

  @override
  String get pulseEmptyTitle => 'Trois questions, un premier chiffre.';

  @override
  String get pulseEmptySubtitle =>
      'Le reste viendra. Commence par ton profil, on fera parler les chiffres.';

  @override
  String get pulseEmptyCtaStart => 'Commencer';

  @override
  String get pulseVisibilityTitle => 'Visibilité financière';

  @override
  String get pulsePrioritiesTitle => 'Tes priorités';

  @override
  String get pulsePrioritiesSubtitle =>
      'Actions personnalisées selon ton profil';

  @override
  String get pulseComprendreTitle => 'Comprendre';

  @override
  String get pulseComprendreSubtitle => 'Explore tes simulateurs';

  @override
  String get pulseComprendreRenteCapital => 'Rente ou capital ?';

  @override
  String get pulseComprendreRenteCapitalSub =>
      'Compare les deux options de retrait';

  @override
  String get pulseComprendreRachatLpp => 'Simuler un rachat LPP';

  @override
  String get pulseComprendreRachatLppSub =>
      'Découvre l\'impact fiscal d\'un rachat';

  @override
  String get pulseComprendre3a => 'Explorer mon 3a';

  @override
  String get pulseComprendre3aSub => 'Découvre l\'économie d\'impôt annuelle';

  @override
  String get pulseComprendre_budget => 'Mon budget mensuel';

  @override
  String get pulseComprendre_budgetSub => 'Visualise tes revenus et dépenses';

  @override
  String get pulseComprendreAchat => 'Acheter un bien ?';

  @override
  String get pulseComprendreAchatSub => 'Estime ta capacité d\'emprunt';

  @override
  String get pulseDisclaimer =>
      'Outil éducatif. Ne constitue pas un conseil financier personnalisé. LSFin art. 3';

  @override
  String get pulseKeyFigRetraite => 'Retraite estimée';

  @override
  String pulseKeyFigRetraitePct(String pct) {
    return '$pct % du revenu';
  }

  @override
  String get pulseKeyFigBudgetLibre => 'Budget libre';

  @override
  String get pulseKeyFigPatrimoine => 'Patrimoine';

  @override
  String pulseAmountPerMonth(String amount) {
    return '$amount/mois';
  }

  @override
  String pulseCoupleRetraite(String montant) {
    return 'Retraite couple : $montant';
  }

  @override
  String pulseCoupleAlertWeak(String name, String score) {
    return 'Le profil de $name est à $score % de visibilité';
  }

  @override
  String get pulseAxisLiquidite => 'Liquidité';

  @override
  String get pulseAxisFiscalite => 'Fiscalité';

  @override
  String get pulseAxisRetraite => 'Retraite';

  @override
  String get pulseAxisSecurite => 'Sécurité';

  @override
  String get pulseHintAddSalary => 'Ajoute ton salaire pour commencer';

  @override
  String get pulseHintAddSavings => 'Renseigne ton épargne et investissements';

  @override
  String get pulseHintLiquiditeComplete =>
      'Tes données de liquidité sont complètes';

  @override
  String get pulseHintAddAgeCanton => 'Indique ton âge et canton de résidence';

  @override
  String get pulseHintScanTax => 'Scanne ta déclaration fiscale';

  @override
  String get pulseHintFiscaliteComplete =>
      'Tes données fiscales sont complètes';

  @override
  String get pulseHintAddLpp => 'Ajoute ton certificat LPP';

  @override
  String get pulseHintExtractAvs => 'Commande ton extrait AVS';

  @override
  String get pulseHintAdd3a => 'Renseigne tes comptes 3a';

  @override
  String get pulseHintRetraiteComplete => 'Tes données retraite sont complètes';

  @override
  String get pulseHintAddFamily => 'Indique ta situation familiale';

  @override
  String get pulseHintAddStatus => 'Complète ton statut professionnel';

  @override
  String get pulseHintSecuriteComplete =>
      'Tes données de sécurité sont complètes';

  @override
  String get pulseNarrativeExcellent =>
      'Tu as une vision claire de ta situation. Continue à maintenir tes données à jour.';

  @override
  String pulseNarrativeGood(String axis) {
    return 'Bonne visibilité ! Affine ta $axis pour aller plus loin.';
  }

  @override
  String pulseNarrativeModerate(String axis) {
    return 'Tu commences à y voir plus clair. Concentre-toi sur ta $axis.';
  }

  @override
  String pulseNarrativeWeak(String hint) {
    return 'Chaque information compte. Commence par $hint.';
  }

  @override
  String get pulseNoCheckinMsg =>
      'Aucun check-in ce mois. Enregistre tes versements pour suivre ta progression.';

  @override
  String get pulseCheckinBtn => 'Check-in';

  @override
  String pulseBriefingTitle(String trend) {
    return 'Bilan du mois — $trend';
  }

  @override
  String get pulseFriLiquidite => 'Liquidité';

  @override
  String get pulseFriFiscalite => 'Optimisation fiscale';

  @override
  String get pulseFriRetraite => 'Retraite';

  @override
  String get pulseFriRisque => 'Risques structurels';

  @override
  String get pulseFriTitle => 'Solidité financière';

  @override
  String pulseFriWeakest(String axis) {
    return 'Point le plus fragile : $axis';
  }

  @override
  String get lppBuybackAdvTitle => 'Optimisation de rachat LPP';

  @override
  String get lppBuybackAdvSubtitle => 'Effet levier fiscal + capitalisation';

  @override
  String get lppBuybackAdvPotential => 'Potentiel de rachat';

  @override
  String get lppBuybackAdvYears => 'Années jusqu\'à la retraite';

  @override
  String get lppBuybackAdvStaggering => 'Lissage (staggering)';

  @override
  String get lppBuybackAdvFundRate => 'Taux de la caisse LPP';

  @override
  String get lppBuybackAdvIncome => 'Revenu imposable';

  @override
  String get lppBuybackAdvFinalCapital => 'Valeur finale capitalisée';

  @override
  String lppBuybackAdvRealReturn(String pct) {
    return 'Rendement réel : $pct % / an';
  }

  @override
  String get lppBuybackAdvTaxSaving => 'Économie impôts';

  @override
  String get lppBuybackAdvNetEffort => 'Effort net';

  @override
  String get lppBuybackAdvTotalGain => 'Gain total de l\'opération';

  @override
  String get lppBuybackAdvCapitalMinusEffort => 'Capital - Effort net';

  @override
  String get lppBuybackAdvFundRateLabel => 'Taux LPP servi';

  @override
  String get lppBuybackAdvLeverageEffect => 'Effet levier fiscal';

  @override
  String get lppBuybackAdvBonASavoir => 'Bon à savoir';

  @override
  String get lppBuybackAdvBon1 =>
      'Le rachat LPP est l\'un des rares outils de planification fiscale accessibles à tous les salarié·e·s en Suisse.';

  @override
  String get lppBuybackAdvBon2 =>
      'Chaque franc racheté est déductible de ton revenu imposable (LIFD art. 33 al. 1 let. d).';

  @override
  String get lppBuybackAdvBon3 =>
      'Attention : tout retrait EPL est bloqué pendant 3 ans après un rachat (LPP art. 79b al. 3).';

  @override
  String get lppBuybackAdvDisclaimer =>
      'Simulation incluant l\'intérêt de la caisse et l\'économie d\'impôt lissée. Le rendement réel est calculé sur ton effort net réel.';

  @override
  String get householdTitle => 'Notre Famille';

  @override
  String get householdDiscoverCouplePlus => 'Découvrir Couple+';

  @override
  String get householdLoginPrompt => 'Connecte-toi pour gérer ton ménage';

  @override
  String get householdLogin => 'Se connecter';

  @override
  String get householdRetry => 'Réessayer';

  @override
  String get householdInvitePartner => 'Inviter mon/ma partenaire';

  @override
  String get householdRemoveMemberTitle => 'Retirer ce membre ?';

  @override
  String get householdRemoveMemberContent =>
      'Cette action est irréversible. Un délai de 30 jours s\'applique avant de pouvoir réinviter un nouveau partenaire.';

  @override
  String get householdCancel => 'Annuler';

  @override
  String get householdRemove => 'Retirer';

  @override
  String get householdSendInvitation => 'Envoyer l\'invitation';

  @override
  String get householdCodeCopied => 'Code copié';

  @override
  String get householdMessageCopied => 'Message copié';

  @override
  String get householdCopy => 'Copier';

  @override
  String get householdShare => 'Partager';

  @override
  String get householdHaveCode => 'J\'ai un code d\'invitation';

  @override
  String get householdCouplePlusTitle => 'Couple+';

  @override
  String get householdUpsellDescription =>
      'Optimise ta retraite à deux avec un abonnement Couple+. Projections partagées, retraits échelonnés, et coaching couple.';

  @override
  String get householdEmptyDescription =>
      'Optimise ta retraite à deux. Retraits échelonnés, projections couple, et calendrier fiscal commun.';

  @override
  String get householdHeaderTitle => 'Ménage Couple+';

  @override
  String get householdMembersTitle => 'Membres';

  @override
  String get householdOwnerBadge => 'Propriétaire';

  @override
  String get householdPendingStatus => 'Invitation en attente';

  @override
  String get householdActiveStatus => 'Actif';

  @override
  String get householdRemoveTooltip => 'Retirer du ménage';

  @override
  String get householdInviteSectionTitle => 'Inviter un·e partenaire';

  @override
  String get householdInviteInfo =>
      'Ton/ta partenaire recevra un code d\'invitation valable 72 heures.';

  @override
  String get householdEmailLabel => 'Email du/de la partenaire';

  @override
  String get householdEmailHint => 'partenaire@email.ch';

  @override
  String get householdInviteSentTitle => 'Invitation envoyée';

  @override
  String get householdValidFor => 'Valable 72 heures';

  @override
  String householdShareMessage(String code) {
    return 'Rejoins mon ménage MINT avec le code : $code\n\nOuvre l\'app MINT > Famille > J\'ai un code';
  }

  @override
  String householdMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count membre$_temp0 actif$_temp1';
  }

  @override
  String get householdPartnerDefault => 'Partenaire';

  @override
  String get documentScanCancel => 'Annuler';

  @override
  String get documentScanAnalyze => 'Analyser';

  @override
  String get documentScanTakePhoto => 'Prendre une photo';

  @override
  String get documentScanPasteOcr => 'Coller un texte OCR';

  @override
  String get documentScanCreateAccount => 'Créer un compte';

  @override
  String get documentScanRetakePhoto => 'Reprendre une photo';

  @override
  String get documentScanExtracting => 'Extraction en cours...';

  @override
  String get documentScanImportFile => 'Importer un fichier';

  @override
  String get documentScanOcrTitle => 'Texte OCR';

  @override
  String get documentScanPdfAuthTitle => 'Connexion requise pour le PDF';

  @override
  String get documentScanPdfAuthContent =>
      'L\'analyse PDF automatique passe par le backend et nécessite un compte connecté. Sans compte, tu peux scanner une photo.';

  @override
  String get documentScanOcrHint =>
      'Colle le texte OCR extrait de ton PDF pour continuer.';

  @override
  String get documentScanOcrRetryHint =>
      'Colle le texte OCR extrait si la photo reste illisible.';

  @override
  String get profileFamilySection => 'Famille';

  @override
  String get profileAnalyticsBeta => 'Analytics beta testeurs';

  @override
  String get profileDeleteAccountTitle => 'Supprimer le compte ?';

  @override
  String get profileDeleteAccountContent =>
      'Cette action supprime ton compte cloud et les données associées. Tes données locales restent sur cet appareil.';

  @override
  String get profileDeleteCancel => 'Annuler';

  @override
  String get profileDeleteConfirm => 'Supprimer';

  @override
  String get consentAllRevoked =>
      'Tous les consentements optionnels ont été révoqués.';

  @override
  String get consentClose => 'Fermer';

  @override
  String get consentExportData => 'Exporter mes données (nLPD art. 28)';

  @override
  String get consentRevokeAll => 'RÉVOQUER TOUS LES CONSENTEMENTS OPTIONNELS';

  @override
  String get consentControlCenter => 'CENTRE DE CONTRÔLE DATA';

  @override
  String get consentSecurityMessage =>
      'Tes données restent sur ton appareil. Tu gardes le contrôle total sur les accès tiers.';

  @override
  String get consentRequired => 'Requis';

  @override
  String get consentRequiredTitle => 'Consentements requis';

  @override
  String get consentOptionalTitle => 'Consentements optionnels';

  @override
  String get consentExportTitle => 'Export de tes données';

  @override
  String consentRetentionDays(int days) {
    return 'Conservation : $days jours';
  }

  @override
  String get consentLegalSources => 'Sources légales';

  @override
  String get pillar3aPaymentPerYear => 'Versement/an :';

  @override
  String get pillar3aDuration => 'Durée :';

  @override
  String get pillar3aOpenViac => 'Ouvrir mon compte VIAC';

  @override
  String get pillar3aFees => 'Frais';

  @override
  String get pillar3aReturn => 'Rendement';

  @override
  String get pillar3aAt65 => 'À 65 ans';

  @override
  String get pillar3aComparator => 'Comparateur 3a';

  @override
  String pillar3aProjection(int years) {
    return 'Projection sur $years ans';
  }

  @override
  String get pillar3aScenarioTitle => 'Scénario : Versement max annuel';

  @override
  String pillar3aDurationYears(int years) {
    return '$years ans (jusqu\'à 65 ans)';
  }

  @override
  String get pillar3aViacGainLabel => 'Avec VIAC au lieu d\'une banque :';

  @override
  String get pillar3aMoreAtRetirement => 'de plus à la retraite !';

  @override
  String get pillar3aDisclaimer =>
      'Hypothèses pédagogiques basées sur rendements historiques moyens. Rendements passés ne constituent pas une assurance de résultat pour les rendements futurs.';

  @override
  String get pillar3aCapitalEvolution => 'Évolution de ton capital 3a';

  @override
  String get pillar3aYearLabel => 'Année';

  @override
  String get pillar3aBank15 => 'Banque 1.5%';

  @override
  String get pillar3aViac45 => 'VIAC 4.5%';

  @override
  String pillar3aYearN(int n) {
    return 'Année $n';
  }

  @override
  String get pillar3aCompoundTip =>
      'Les dernières années font +50% du gain total grâce aux intérêts composés !';

  @override
  String get pillar3aRecommended => 'RECOMMANDÉ';

  @override
  String pillar3aVsBank(String amount) {
    return '$amount vs Banque';
  }

  @override
  String get wizardCollapse => 'Réduire';

  @override
  String get wizardUnderstandTopic => 'Comprendre ce sujet';

  @override
  String get wizardSeeSimulation => 'Voir simulation interactive';

  @override
  String get wizardNext => 'Suivant';

  @override
  String get wizardExplanation => 'Explication';

  @override
  String wizardValidateCount(int count) {
    return 'Valider ($count)';
  }

  @override
  String get wizardInvalidNumber => 'Entre un nombre valide';

  @override
  String wizardMinValue(String value) {
    return 'Minimum : $value';
  }

  @override
  String wizardMaxValue(String value) {
    return 'Maximum : $value';
  }

  @override
  String get wizardFieldRequired => 'Ce champ est requis';

  @override
  String get slmCancelDownload => 'Annuler le téléchargement';

  @override
  String get slmCancel => 'Annuler';

  @override
  String get slmDownload => 'Télécharger';

  @override
  String get slmDelete => 'Supprimer';

  @override
  String get slmIaOnDevice => 'IA on-device';

  @override
  String get slmPrivacyMessage =>
      'Le modèle fonctionne 100% sur ton appareil. Aucune donnée ne quitte ton téléphone.';

  @override
  String get slmDownloadModelTitle => 'Télécharger le modèle ?';

  @override
  String get slmDeleteModelTitle => 'Supprimer le modèle ?';

  @override
  String slmDeleteModelContent(String size) {
    return 'Cela libérera $size d\'espace. Tu pourras le re-télécharger à tout moment.';
  }

  @override
  String get slmDeleteModelButton => 'Supprimer le modèle';

  @override
  String get slmStartingDownload => 'Démarrage du téléchargement...';

  @override
  String get slmRetryDownload => 'Réessayer le téléchargement';

  @override
  String get slmDownloadUnavailable =>
      'Téléchargement indisponible sur ce build';

  @override
  String get slmEngineStatus => 'Statut du moteur';

  @override
  String get slmHowItWorks => 'Comment ça marche ?';

  @override
  String get landingPunchline1 => 'Le système financier suisse est puissant.';

  @override
  String get landingPunchline2 => 'Si tu le comprends.';

  @override
  String get landingCtaComprendre => 'Comprendre';

  @override
  String get landingJargon1 => 'Déduction de coordination';

  @override
  String get landingClear1 => 'Ce qu\'on te retire';

  @override
  String get landingJargon2 => 'Valeur locative';

  @override
  String get landingClear2 => 'L\'impôt sur ta maison';

  @override
  String get landingJargon3 => 'Taux marginal';

  @override
  String get landingClear3 => 'Ce que tu paies vraiment';

  @override
  String get landingJargon4 => 'Lacune de prévoyance';

  @override
  String get landingClear4 => 'Ce qui te manquera';

  @override
  String get landingJargon5 => 'Droit de mutation';

  @override
  String get landingClear5 => 'La taxe quand tu achètes';

  @override
  String get landingWhyNobody => 'Chaque année sans comprendre te coûte.';

  @override
  String get landingMintDoesIt => 'MINT le fait.';

  @override
  String get landingCtaCommencer => 'Commencer';

  @override
  String get landingLegalFooterShort =>
      'Outil éducatif. Ne constitue pas un conseil financier (LSFin). Données sur ton appareil.';

  @override
  String pulseDigitalTwinPct(String pct) {
    return 'Jumeau numérique : $pct%';
  }

  @override
  String get pulseDigitalTwinHint =>
      'Plus ton profil est complet, plus tes projections sont fiables.';

  @override
  String get pulseActionsThisMonth => 'À faire ce mois';

  @override
  String get pulseHeroChangeBtn => 'Changer';

  @override
  String get pulseCoachInsightTitle => 'L\'insight du coach';

  @override
  String get pulseRefineProfile => 'Affiner mon profil';

  @override
  String get pulseWhatIf3aQuestion => 'Et si tu versais le maximum en 3a ?';

  @override
  String pulseWhatIf3aImpact(String amount) {
    return '−CHF $amount/an d\'impôts';
  }

  @override
  String get pulseWhatIfLppQuestion => 'Et si tu rachetais du LPP ?';

  @override
  String pulseWhatIfLppImpact(String amount) {
    return 'Jusqu\'à −CHF $amount d\'impôts';
  }

  @override
  String get pulseWhatIfEarlyQuestion => 'Et si tu partais 1 an plus tôt ?';

  @override
  String pulseWhatIfEarlyImpact(String amount) {
    return '−CHF $amount/mois de rente';
  }

  @override
  String get pulseActionSignalSingular => '1 action à faire';

  @override
  String pulseActionSignalPlural(String count) {
    return '$count actions à faire';
  }

  @override
  String get agirTopActionCta => 'Commencer';

  @override
  String agirOtherActions(String count) {
    return '$count autres actions';
  }

  @override
  String get exploreSuggestionLabel => 'Suggestion pour toi';

  @override
  String get exploreSuggestion3aTitle => 'Le 3a : ton premier levier fiscal';

  @override
  String get exploreSuggestion3aSub =>
      'Découvre combien tu peux économiser d\'impôts';

  @override
  String get exploreSuggestionLppTitle => 'Rachat LPP : une opportunité ?';

  @override
  String get exploreSuggestionLppSub =>
      'Simule l\'impact sur ta retraite et tes impôts';

  @override
  String get exploreSuggestionRetirementTitle => 'Ta retraite approche';

  @override
  String get exploreSuggestionRetirementSub =>
      'Rente, capital ou mix ? Compare les options';

  @override
  String get exploreSuggestionBudgetTitle => 'Commence par ton budget';

  @override
  String get exploreSuggestionBudgetSub =>
      '3 minutes pour voir où va ton argent';

  @override
  String get pulseReadinessTitle => 'Forme financière';

  @override
  String get pulseReadinessGood => 'Bonne préparation';

  @override
  String get pulseReadinessProgress => 'En progression';

  @override
  String get pulseReadinessWeak => 'À renforcer';

  @override
  String pulseReadinessRetireIn(int years) {
    return 'Retraite dans $years ans';
  }

  @override
  String pulseReadinessYearsToAct(int years) {
    return 'Encore $years ans pour agir';
  }

  @override
  String get pulseReadinessActNow => 'L\'essentiel se joue maintenant';

  @override
  String get pulseReadinessRetired => 'Déjà à la retraite';

  @override
  String get pulseCompleteProfile => 'Complète ton profil';

  @override
  String get profileSectionMyFile => 'Mon dossier';

  @override
  String get profileSectionSettings => 'Réglages';

  @override
  String get profileCompletionLabel => 'Ton dossier';

  @override
  String get agirBudgetNet => 'Net';

  @override
  String get agirBudgetFixed => 'Fixes';

  @override
  String get agirBudgetAvailable => 'Dispo';

  @override
  String get agirBudgetSaved => 'Versé';

  @override
  String get agirBudgetRemaining => 'Reste';

  @override
  String get agirBudgetWarning =>
      'Tes versements dépassent ton budget disponible';

  @override
  String get enrichmentCtaScan => 'Scanner un document';

  @override
  String enrichmentCtaMissing(int count) {
    return '$count champ(s) à compléter';
  }

  @override
  String get heroGapTitle => 'À la retraite, il te manquera';

  @override
  String get heroGapCovered => 'Tu es bien couvert·e';

  @override
  String get heroGapPerMonth => '/mois';

  @override
  String get heroGapToday => 'Aujourd\'hui';

  @override
  String get heroGapRetirement => 'Retraite';

  @override
  String get heroGapConfidence => 'Confiance';

  @override
  String get heroGapScanCta => 'Scanner certificat LPP';

  @override
  String heroGapBoost(int percent) {
    return '+$percent % précision';
  }

  @override
  String get heroGapMetaphor5k =>
      'C\'est comme passer d\'un 5 pièces à un studio';

  @override
  String get heroGapMetaphor3k =>
      'C\'est comme renoncer à ta voiture et tes vacances';

  @override
  String get heroGapMetaphor1k => 'C\'est comme couper les sorties restaurant';

  @override
  String get heroGapMetaphorSmall => 'C\'est un café par jour de différence';

  @override
  String get drawerCeQueTuAs => 'Ce que tu as';

  @override
  String get drawerCeQueTuAsSubtitle => 'Patrimoine net';

  @override
  String get drawerCeQueTuDois => 'Ce que tu dois';

  @override
  String get drawerCeQueTuDoisSubtitle => 'Dettes totales';

  @override
  String get drawerCeQueTuAuras => 'Ce que tu auras';

  @override
  String get drawerCeQueTuAurasSubtitle => 'Revenu retraite projeté';

  @override
  String get shellWelcomeBack => 'De retour. Tes chiffres sont à jour.';

  @override
  String get shellRecommendationsUpdated => 'Recommandations mises à jour';

  @override
  String get pulseEnrichirTitle => 'Scanne ton certificat LPP';

  @override
  String pulseEnrichirSubtitle(String points) {
    return 'Confiance → +$points points';
  }

  @override
  String get pulseEnrichirCta => 'Scanner →';

  @override
  String get tabMoi => 'Moi';

  @override
  String get coupleSwitchSolo => 'Solo';

  @override
  String get coupleSwitchDuo => 'Duo';

  @override
  String get identityStatusSalarie => 'Salarié';

  @override
  String get identityStatusIndependant => 'Indépendant';

  @override
  String get identityStatusChomage => 'En recherche';

  @override
  String get identityStatusRetraite => 'Retraité';

  @override
  String get simLppBuybackTitle => 'Optimisation de Rachat LPP';

  @override
  String get simLppBuybackSubtitle => 'Effet levier fiscal + Capitalisation';

  @override
  String get simLppBuybackPotential => 'Potentiel de rachat';

  @override
  String get simLppBuybackYearsToRetirement => 'Années jusqu\'à la retraite';

  @override
  String get simLppBuybackStaggering => 'Lissage (staggering)';

  @override
  String get simLppBuybackFundRate => 'Taux de la caisse LPP';

  @override
  String get simLppBuybackTaxableIncome => 'Revenu imposable';

  @override
  String get simLppBuybackUnitChf => 'CHF';

  @override
  String get simLppBuybackUnitYears => 'ans';

  @override
  String get simLppBuybackFinalCapital => 'Valeur Finale Capitalisée';

  @override
  String simLppBuybackRealReturn(String rate) {
    return 'Rendement Réel : $rate % / an';
  }

  @override
  String get simLppBuybackTaxSavings => 'Économie Impôts';

  @override
  String get simLppBuybackNetEffort => 'Effort Net';

  @override
  String get simLppBuybackTotalGain => 'Gain Total de l\'opération';

  @override
  String get simLppBuybackCapitalMinusEffort => 'Capital - Effort Net';

  @override
  String get simLppBuybackFundRateLabel => 'Taux LPP servi';

  @override
  String get simLppBuybackFiscalLeverage => 'Effet levier fiscal';

  @override
  String get simLppBuybackBonASavoir => 'Bon à savoir';

  @override
  String get simLppBuybackBonASavoirItem1 =>
      'Le rachat LPP est l\'un des rares outils de planification fiscale accessibles à tous les salarié·e·s en Suisse.';

  @override
  String get simLppBuybackBonASavoirItem2 =>
      'Chaque franc racheté est déductible de ton revenu imposable (LIFD art. 33 al. 1 let. d).';

  @override
  String get simLppBuybackBonASavoirItem3 =>
      'Attention : tout retrait EPL est bloqué pendant 3 ans après un rachat (LPP art. 79b al. 3).';

  @override
  String simLppBuybackDisclaimer(
      String fundRate, int staggeringYears, String taxableIncome) {
    return 'Simulation incluant l\'intérêt de la caisse ($fundRate %) et l\'économie d\'impôt lissée sur $staggeringYears ans pour un revenu imposable de CHF $taxableIncome. Le rendement réel est calculé sur ton effort net réel.';
  }

  @override
  String get simRealInterestTitle => 'Simulateur d\'Intérêt Réel';

  @override
  String get simRealInterestSubtitle =>
      'Capital + Économie d\'impôt réinvestie (Virtuel)';

  @override
  String get simRealInterestAmount => 'Montant Investi';

  @override
  String get simRealInterestDuration => 'Durée';

  @override
  String get simRealInterestPessimistic => 'Pessimiste';

  @override
  String get simRealInterestNeutral => 'Neutre';

  @override
  String get simRealInterestOptimistic => 'Optimiste';

  @override
  String simRealInterestHypotheses(String rate) {
    return 'Hypothèses : Taux marginal $rate %. Rendements marché : 2 % / 4 % / 6 %.';
  }

  @override
  String get simRealInterestEducTitle => 'Comprendre le rendement réel';

  @override
  String get simRealInterestEducBullet1 =>
      'Le rendement réel = rendement nominal − inflation − frais';

  @override
  String get simRealInterestEducBullet2 =>
      'Un placement à 3 % avec 1.5 % d\'inflation et 0.5 % de frais rapporte seulement 1 % en réel';

  @override
  String get simRealInterestEducBullet3 =>
      'Sur 30 ans, cette différence peut représenter des dizaines de milliers de francs';

  @override
  String get simBuybackTitle => 'Stratégie Rachat LPP';

  @override
  String get simBuybackSubtitle => 'Optimisation par lissage (Staggering)';

  @override
  String get simBuybackDuration => 'Durée du lissage';

  @override
  String simBuybackYears(int count) {
    return '$count ans';
  }

  @override
  String get simBuybackLessOptimized => 'Moins Optimisé';

  @override
  String get simBuybackSingleShot => 'En 1 fois';

  @override
  String get simBuybackOptimized => 'Optimisé';

  @override
  String simBuybackInNTimes(int count) {
    return 'En $count fois';
  }

  @override
  String simBuybackEstimatedGain(String amount) {
    return 'Gain estimé : + CHF $amount';
  }

  @override
  String get simBuybackSavingsLabel => 'Économie';

  @override
  String get simBuybackMarginalRateQuestion =>
      'Qu\'est-ce que le taux marginal d\'imposition ?';

  @override
  String get simBuybackMarginalRateTitle => 'Taux marginal d\'imposition';

  @override
  String get simBuybackMarginalRateExplanation =>
      'Le taux marginal est le pourcentage d\'impôt sur ton dernier franc gagné. Plus ton revenu est élevé, plus ce taux est fort.';

  @override
  String get simBuybackMarginalRateTip =>
      'En lissant tes rachats, tu restes dans des tranches d\'imposition plus basses chaque année, ce qui augmente ton économie fiscale totale.';

  @override
  String get simBuybackLockedTitle => 'Rachat LPP bloqué';

  @override
  String get simBuybackLockedMessage =>
      'Le rachat LPP est désactivé en mode protection. Un rachat bloque ta liquidité pendant 3 ans (LPP art. 79b al. 3). Rembourse d\'abord tes dettes avant d\'immobiliser du capital.';

  @override
  String get pcWidgetTitle => 'Droits aux Prestations (PC)';

  @override
  String get pcWidgetSubtitle => 'Checklist d\'éligibilité locale';

  @override
  String get pcWidgetRevenus => 'Revenus';

  @override
  String get pcWidgetFortune => 'Fortune';

  @override
  String get pcWidgetLoyer => 'Loyer';

  @override
  String get pcWidgetEligible =>
      'Ta situation suggère un droit potentiel aux PC.';

  @override
  String get pcWidgetNotEligible =>
      'Tes revenus semblent suffisants selon les barèmes standards.';

  @override
  String pcWidgetFindOffice(String canton) {
    return 'Trouver l\'office PC ($canton)';
  }

  @override
  String get letterGenTitle => 'Secrétariat Automatique';

  @override
  String get letterGenSubtitle =>
      'Générez des modèles de lettres prêts à l\'emploi.';

  @override
  String get letterGenBuybackTitle => 'Demande de Rachat LPP';

  @override
  String get letterGenBuybackSubtitle =>
      'Pour connaître ton potentiel de rachat.';

  @override
  String get letterGenTaxTitle => 'Attestation Fiscale';

  @override
  String get letterGenTaxSubtitle => 'Pour ta déclaration d\'impôts.';

  @override
  String get letterGenDisclaimer =>
      'Ces documents sont des modèles à compléter. Ils ne constituent pas un avis de droit.';

  @override
  String get precisionPromptTitle => 'Précision disponible';

  @override
  String get precisionPromptPreciser => 'Préciser';

  @override
  String get precisionPromptContinuer => 'Continuer';

  @override
  String get earlyRetirementHeader => 'Et si je partais à…';

  @override
  String earlyRetirementAgeDisplay(int age) {
    return '$age ans';
  }

  @override
  String get earlyRetirementZoneRisky =>
      'Risqué — sacrifice financier important';

  @override
  String get earlyRetirementZoneFeasible => 'Faisable — avec compromis';

  @override
  String get earlyRetirementZoneStandard => 'Standard — pas de pénalité';

  @override
  String get earlyRetirementZoneBonus =>
      'Bonus — tu gagnes plus, mais moins longtemps';

  @override
  String earlyRetirementResultLine(int age, String amount) {
    return 'À $age ans : $amount/mois';
  }

  @override
  String earlyRetirementNarrativeEarly(
      String amount, int years, String plural) {
    return 'Tu perds $amount/mois à vie. Mais tu gagnes $years an$plural de liberté.';
  }

  @override
  String earlyRetirementNarrativeLate(String amount, int years, String plural) {
    return 'Tu gagnes $amount/mois de plus. $years an$plural de travail supplémentaire.';
  }

  @override
  String earlyRetirementLifetimeImpact(String amount) {
    return 'Impact estimé sur 25 ans : $amount';
  }

  @override
  String get earlyRetirementDisclaimer =>
      'Estimations éducatives — ne constitue pas un conseil financier (LSFin).';

  @override
  String earlyRetirementSemanticsLabel(int age) {
    return 'Simulateur de départ à la retraite. Âge sélectionné : $age ans.';
  }

  @override
  String get budgetReportTitle => 'Ton Budget Calculé';

  @override
  String get budgetReportDisponible => 'Disponible';

  @override
  String get budgetReportVariables => 'Variables (Vivre)';

  @override
  String get budgetReportFutur => 'Futur (Épargne)';

  @override
  String budgetReportChfAmount(String amount) {
    return 'CHF $amount';
  }

  @override
  String get budgetReportStopWarning =>
      'Attention : Aucune marge de manœuvre pour les dépenses variables.';

  @override
  String get ninetyDayGaugeTitle => 'Règle des 90 jours';

  @override
  String get ninetyDayGaugeSubtitle => 'Frontaliers  ·  Seuil fiscal';

  @override
  String get ninetyDayGaugeDaysOf90 => '/ 90 jours';

  @override
  String get ninetyDayGaugeStatusRed =>
      'Seuil dépassé — risque d\'imposition ordinaire en Suisse';

  @override
  String ninetyDayGaugeStatusOrange(int remaining, String plural) {
    return 'Attention : plus que $remaining jour$plural avant le seuil';
  }

  @override
  String ninetyDayGaugeStatusGreen(int remaining, String plural) {
    return 'Zone sûre — $remaining jour$plural restants avant le seuil';
  }

  @override
  String ninetyDayGaugeSemanticsLabel(int days, String status) {
    return 'Jauge de la règle des 90 jours. $days jours sur 90. $status';
  }

  @override
  String get ninetyDayGaugeZoneSafe => 'Zone sûre';

  @override
  String get ninetyDayGaugeZoneAttention => 'Attention';

  @override
  String get ninetyDayGaugeZoneRisk => 'Risque fiscal';

  @override
  String get forfaitFiscalTitle => 'Forfait fiscal vs Ordinaire';

  @override
  String get forfaitFiscalSubtitle => 'Comparaison annuelle  ·  Expatriés';

  @override
  String get forfaitFiscalSaving => 'Économie forfait';

  @override
  String get forfaitFiscalSurcharge => 'Surcoût forfait';

  @override
  String get forfaitFiscalPerYear => 'par année';

  @override
  String forfaitFiscalSemanticsLabel(
      String ordinary, String forfait, String savings) {
    return 'Comparaison forfait fiscal. Imposition ordinaire : $ordinary. Forfait fiscal : $forfait. Économie : $savings.';
  }

  @override
  String get forfaitFiscalOrdinaryLabel => 'Imposition\nordinaire';

  @override
  String get forfaitFiscalForfaitLabel => 'Forfait\nfiscal';

  @override
  String get forfaitFiscalBaseLine => 'Base forfaitaire';

  @override
  String get spendingMeterBudgetUnavailable => 'Budget non disponible';

  @override
  String get spendingMeterDisponible => 'Disponible';

  @override
  String spendingMeterVariablesLegend(int percent) {
    return 'Variables $percent%';
  }

  @override
  String spendingMeterFuturLegend(int percent) {
    return 'Futur $percent%';
  }

  @override
  String get avsGuideAppBarTitle => 'EXTRAIT AVS';

  @override
  String get avsGuideHeaderTitle => 'Comment obtenir ton extrait AVS';

  @override
  String get avsGuideHeaderSubtitle =>
      'L\'extrait de compte individuel (CI) contient tes années de cotisation, ton revenu moyen (RAMD) et tes éventuelles lacunes. C\'est la clé pour une projection AVS fiable.';

  @override
  String avsGuideConfidencePoints(int points) {
    return '+$points points de confiance';
  }

  @override
  String get avsGuideConfidenceSubtitle =>
      'Années de cotisation, RAMD, lacunes';

  @override
  String get avsGuideStepsTitle => 'En 4 étapes';

  @override
  String get avsGuideStep1Title => 'Va sur www.ahv-iv.ch';

  @override
  String get avsGuideStep1Subtitle =>
      'C\'est le site officiel de l\'AVS/AI. Tu peux aussi demander ton extrait directement à ta caisse de compensation.';

  @override
  String get avsGuideStep2Title =>
      'Connecte-toi avec ton eID ou crée un compte';

  @override
  String get avsGuideStep2Subtitle =>
      'Tu auras besoin de ton numéro AVS (756.XXXX.XXXX.XX, sur ta carte d\'assurance-maladie).';

  @override
  String get avsGuideStep3Title =>
      'Demande ton extrait de compte individuel (CI)';

  @override
  String get avsGuideStep3Subtitle =>
      'Cherche la section \"Extrait de compte\" ou \"Kontoauszug\". C\'est un document officiel qui récapitule toutes tes cotisations.';

  @override
  String get avsGuideStep4Title => 'Tu le recevras par courrier ou PDF';

  @override
  String get avsGuideStep4Subtitle =>
      'Selon ta caisse, l\'extrait arrive en 5 à 10 jours ouvrables. Certaines caisses proposent un téléchargement PDF immédiat.';

  @override
  String get avsGuideOpenAhvButton => 'Ouvrir ahv-iv.ch';

  @override
  String get avsGuideScanButton => 'J\'ai déjà mon extrait → Scanner';

  @override
  String get avsGuideTestMode => 'MODE TEST';

  @override
  String get avsGuideTestDescription =>
      'Pas d\'extrait AVS sous la main ? Teste le flux avec un exemple d\'extrait.';

  @override
  String get avsGuideTestButton => 'Utiliser un exemple';

  @override
  String get avsGuideFreeNote =>
      'L\'extrait AVS est gratuit et disponible en 5 à 10 jours ouvrables. Tu peux aussi te rendre à ta caisse de compensation cantonale.';

  @override
  String get avsGuidePrivacyNote =>
      'L\'image de ton extrait n\'est jamais stockée ni envoyée. L\'extraction se fait sur ton appareil. Seules les valeurs que tu confirmes sont conservées dans ton profil.';

  @override
  String avsGuideSnackbarError(String url) {
    return 'Impossible d\'ouvrir $url. Copie l\'adresse et ouvre-la dans ton navigateur.';
  }

  @override
  String get dataBlockDisclaimer =>
      'Outil éducatif simplifié. Ne constitue pas un conseil financier (LSFin).';

  @override
  String get dataBlockIncomplete =>
      'Ce bloc est encore incomplet. Ouvre la section dédiée pour ajouter les données manquantes.';

  @override
  String get dataBlockComplete => 'Ce bloc est complet.';

  @override
  String get dataBlockModeForm => 'Formulaire';

  @override
  String get dataBlockModeCoach => 'Parle au coach';

  @override
  String get dataBlockStatusComplete => 'Complet';

  @override
  String get dataBlockStatusPartial => 'Partiel';

  @override
  String get dataBlockStatusMissing => 'Manquant';

  @override
  String get dataBlockRevenuTitle => 'Revenu';

  @override
  String get dataBlockRevenuDesc =>
      'Ton salaire brut est la base de toutes les projections : prévoyance, impôts, budget. Plus il est précis, plus tes résultats seront fiables.';

  @override
  String get dataBlockRevenuCta => 'Préciser mon revenu';

  @override
  String get dataBlockLppTitle => 'Prévoyance LPP';

  @override
  String get dataBlockLppDesc =>
      'Ton avoir LPP (2e pilier) représente souvent le plus gros capital de ta prévoyance. Un certificat de prévoyance donne une valeur exacte plutôt qu\'une estimation.';

  @override
  String get dataBlockLppCta => 'Ajouter mon certificat LPP';

  @override
  String get dataBlockAvsTitle => 'Extrait AVS';

  @override
  String get dataBlockAvsDesc =>
      'L\'extrait AVS confirme tes années de cotisation effectives. Des lacunes (séjour à l\'étranger, années manquantes) réduisent ta rente AVS.';

  @override
  String get dataBlockAvsCta => 'Commander mon extrait AVS';

  @override
  String get dataBlock3aTitle => '3e pilier (3a)';

  @override
  String get dataBlock3aDesc =>
      'Tes comptes 3a s\'ajoutent à ta prévoyance et offrent un avantage fiscal. Renseigne les soldes actuels pour une vue complète.';

  @override
  String get dataBlock3aCta => 'Simuler mon 3a';

  @override
  String get dataBlockPatrimoineTitle => 'Patrimoine';

  @override
  String get dataBlockPatrimoineDesc =>
      'Épargne libre, investissements, immobilier : ces données complètent ta projection et permettent de calculer ton Financial Resilience Index.';

  @override
  String get dataBlockPatrimoineCta => 'Renseigner mon patrimoine';

  @override
  String get dataBlockFiscaliteTitle => 'Fiscalité';

  @override
  String get dataBlockFiscaliteDesc =>
      'Ta commune, ton revenu imposable et ta fortune déterminent ton taux marginal d\'imposition. Une déclaration fiscale ou un avis de taxation donne un taux réel plutôt qu\'estimé (coefficient communal 60%-130%).';

  @override
  String get dataBlockFiscaliteCta => 'Comparer ma fiscalité';

  @override
  String get dataBlockObjectifTitle => 'Objectif retraite';

  @override
  String get dataBlockObjectifDesc =>
      'À quel âge souhaites-tu arrêter de travailler ? Un objectif clair permet de calculer l\'effort d\'épargne nécessaire et les options (anticipation, retraite partielle).';

  @override
  String get dataBlockObjectifCta => 'Voir ma projection';

  @override
  String get dataBlockMenageTitle => 'Composition du ménage';

  @override
  String get dataBlockMenageDesc =>
      'En couple, les projections changent : AVS plafonnée pour les mariés (LAVS art. 35), rente de survivant (LPP art. 19), optimisation fiscale à deux.';

  @override
  String get dataBlockMenageCta => 'Gérer mon ménage';

  @override
  String get dataBlockUnknownTitle => 'Données';

  @override
  String get dataBlockUnknownDesc =>
      'Ce lien de données n’est plus à jour. Utilise la section recommandée pour compléter ton profil.';

  @override
  String get dataBlockUnknownCta => 'Ouvrir le diagnostic';

  @override
  String get dataBlockDefaultTitle => 'Données';

  @override
  String get dataBlockDefaultDesc =>
      'Complète ce bloc pour améliorer la précision de tes projections.';

  @override
  String get dataBlockDefaultCta => 'Compléter';

  @override
  String get renteVsCapitalAppBarTitle => 'Rente ou capital : ta décision';

  @override
  String get renteVsCapitalIntro =>
      'À la retraite, tu choisis une fois pour toutes : un revenu à vie ou ton capital en main.';

  @override
  String get renteVsCapitalRenteLabel => 'Rente';

  @override
  String get renteVsCapitalRenteExplanation =>
      'Ta caisse de pension te verse un montant fixe chaque mois, tant que tu vis — même si tu atteins 100 ans. En échange, tu ne récupères jamais ton capital.';

  @override
  String get renteVsCapitalCapitalLabel => 'Capital';

  @override
  String get renteVsCapitalCapitalExplanation =>
      'Tu récupères tout ton avoir LPP d\'un coup. Tu le places, tu retires ce dont tu as besoin chaque mois. Liberté totale, mais le risque de manquer est réel.';

  @override
  String get renteVsCapitalMixteLabel => 'Mixte';

  @override
  String get renteVsCapitalMixteExplanation =>
      'La partie obligatoire en rente (taux 6.8 %) + le surobligatoire en capital. Un compromis entre sécurité et flexibilité.';

  @override
  String get renteVsCapitalEstimateMode => 'Estimer pour moi';

  @override
  String get renteVsCapitalCertificateMode => 'J\'ai mon certificat';

  @override
  String get renteVsCapitalAge => 'Ton âge';

  @override
  String get renteVsCapitalSalary => 'Ton salaire brut annuel (CHF)';

  @override
  String get renteVsCapitalLppTotal => 'Ton avoir LPP actuel (CHF)';

  @override
  String renteVsCapitalEstimatedCapital(int age, String amount) {
    return 'Capital estimé à $age ans : ~$amount';
  }

  @override
  String renteVsCapitalEstimatedRente(String amount) {
    return 'Rente estimée : ~$amount/an';
  }

  @override
  String get renteVsCapitalProjectionSource =>
      'Projection basée sur ton âge, salaire et LPP actuel';

  @override
  String get renteVsCapitalLppOblig => 'Avoir LPP obligatoire (certificat LPP)';

  @override
  String get renteVsCapitalLppSurob =>
      'Avoir LPP surobligatoire (certificat LPP)';

  @override
  String get renteVsCapitalRenteProposed =>
      'Rente annuelle proposée (certificat LPP)';

  @override
  String get renteVsCapitalTcOblig => 'Taux conv. oblig. (%)';

  @override
  String get renteVsCapitalTcSurob => 'Taux conv. surob. (%)';

  @override
  String get renteVsCapitalMaxPrecision =>
      'Précision maximale — résultats basés sur tes vrais chiffres.';

  @override
  String get renteVsCapitalCanton => 'Canton';

  @override
  String get renteVsCapitalMarried => 'Marié·e';

  @override
  String get renteVsCapitalRetirementAge => 'Retraite prévue à';

  @override
  String renteVsCapitalAgeYears(int age) {
    return '$age ans';
  }

  @override
  String renteVsCapitalAccrocheTaxEpuise(String taxDelta, int age) {
    return 'Cette décision peut te coûter $taxDelta d\'impôts en trop — ou te laisser sans rien à $age ans. Tu ne peux la prendre qu\'une seule fois.';
  }

  @override
  String renteVsCapitalAccrocheTax(String taxDelta) {
    return 'Cette décision peut changer $taxDelta d\'impôts sur ta retraite. Tu ne peux la prendre qu\'une seule fois.';
  }

  @override
  String renteVsCapitalAccrocheEpuise(int age) {
    return 'Avec le capital, tu pourrais manquer d\'argent dès $age ans. Avec la rente, tu reçois un montant fixe à vie. Tu ne peux choisir qu\'une fois.';
  }

  @override
  String get renteVsCapitalHeroRente => 'RENTE';

  @override
  String get renteVsCapitalHeroCapital => 'CAPITAL';

  @override
  String get renteVsCapitalPerMonth => '/mois';

  @override
  String get renteVsCapitalForLife => 'à vie';

  @override
  String renteVsCapitalDuration(String duration) {
    return 'pendant $duration';
  }

  @override
  String get renteVsCapitalMicroRente =>
      'Ta caisse te verse ce montant chaque mois, tant que tu vis.';

  @override
  String renteVsCapitalMicroCapital(String swr, String rendement) {
    return 'Tu retires $swr % par an d\'un capital placé à $rendement %.';
  }

  @override
  String renteVsCapitalSyntheseCapitalHigher(String delta) {
    return 'Le capital te donne $delta/mois de plus, mais pourrait s\'épuiser.';
  }

  @override
  String renteVsCapitalSyntheseRenteHigher(String delta) {
    return 'La rente te donne $delta/mois de plus, et ne s\'arrête jamais.';
  }

  @override
  String get renteVsCapitalAvsEstimated => 'AVS estimée : ';

  @override
  String renteVsCapitalAvsAmount(String amount) {
    return '~$amount/mois';
  }

  @override
  String get renteVsCapitalAvsSupplementary =>
      ' supplémentaires dans les deux cas (LAVS art. 29)';

  @override
  String get renteVsCapitalLifeExpectancy => 'Et si je vis jusqu\'à...';

  @override
  String get renteVsCapitalLifeExpectancyRef =>
      'Espérance de vie suisse : hommes 84 ans · femmes 87 ans';

  @override
  String get renteVsCapitalChartTitle =>
      'Capital restant vs revenus cumulés de la rente';

  @override
  String get renteVsCapitalChartSubtitle =>
      'Capital (vert) : ce qu\'il reste après tes retraits. Rente (bleu) : total reçu depuis le départ. Le croisement = l\'âge auquel la rente a plus rapporté.';

  @override
  String get renteVsCapitalChartAxisLabel => 'Âge';

  @override
  String renteVsCapitalBeyondHorizon(int age) {
    return 'À $age ans : au-delà de l\'horizon de simulation.';
  }

  @override
  String renteVsCapitalDeltaAtAge(int age) {
    return 'À $age ans : ';
  }

  @override
  String get renteVsCapitalDeltaAdvance => 'd\'avance';

  @override
  String get renteVsCapitalEducationalTitle => 'Ce que ça change concrètement';

  @override
  String get renteVsCapitalFiscalTitle => 'Fiscalité';

  @override
  String get renteVsCapitalFiscalLeftSubtitle => 'Imposée chaque année';

  @override
  String get renteVsCapitalFiscalRightSubtitle => 'Taxé une seule fois';

  @override
  String get renteVsCapitalFiscalOver30years => 'sur 30 ans';

  @override
  String get renteVsCapitalFiscalAtRetrait => 'au retrait (LIFD art. 38)';

  @override
  String renteVsCapitalFiscalCapitalSaves(String amount) {
    return 'Sur 30 ans, le capital te fait économiser ~$amount d\'impôts.';
  }

  @override
  String renteVsCapitalFiscalRenteSaves(String amount) {
    return 'Sur 30 ans, la rente génère ~$amount d\'impôts en moins.';
  }

  @override
  String get renteVsCapitalInflationTitle => 'Inflation';

  @override
  String get renteVsCapitalInflationToday => 'Aujourd\'hui';

  @override
  String get renteVsCapitalInflationIn20Years => 'Dans 20 ans';

  @override
  String get renteVsCapitalInflationPurchasingPower => 'pouvoir d\'achat';

  @override
  String renteVsCapitalInflationBottomText(int percent) {
    return 'Ta rente LPP n\'est pas indexée. Elle achète $percent % de moins dans 20 ans.';
  }

  @override
  String get renteVsCapitalTransmissionTitle => 'Transmission';

  @override
  String get renteVsCapitalTransmissionLeftMarried => 'Ton conjoint reçoit';

  @override
  String get renteVsCapitalTransmissionLeftSingle => 'À ton décès';

  @override
  String renteVsCapitalTransmissionLeftValueMarried(String amount) {
    return '60 % = $amount/mois';
  }

  @override
  String get renteVsCapitalTransmissionLeftValueSingle => 'Rien';

  @override
  String get renteVsCapitalTransmissionLeftDetailMarried => 'LPP art. 19';

  @override
  String get renteVsCapitalTransmissionLeftDetailSingle => 'pour tes héritiers';

  @override
  String get renteVsCapitalTransmissionRightSubtitle =>
      'Tes héritiers reçoivent';

  @override
  String get renteVsCapitalTransmissionRightValue => '100 %';

  @override
  String get renteVsCapitalTransmissionRightDetail => 'du solde restant';

  @override
  String get renteVsCapitalTransmissionBottomMarried =>
      'Avec la rente, seul·e ton conjoint·e reçoit 60 %. Rien pour les enfants.';

  @override
  String get renteVsCapitalTransmissionBottomSingle =>
      'Avec la rente, rien ne revient à tes proches.';

  @override
  String get renteVsCapitalAffinerTitle => 'Affiner ta simulation';

  @override
  String get renteVsCapitalAffinerSubtitle => 'Pour ceux qui veulent creuser.';

  @override
  String get renteVsCapitalHypRendement => 'Ce que ton capital rapporte par an';

  @override
  String get renteVsCapitalHypSwr => 'Combien tu retires chaque année';

  @override
  String get renteVsCapitalHypInflation => 'Inflation';

  @override
  String get renteVsCapitalTornadoToggle => 'Voir le diagramme de sensibilité';

  @override
  String get renteVsCapitalImpactTitle =>
      'Qu\'est-ce qui change le plus le résultat ?';

  @override
  String get renteVsCapitalImpactSubtitle =>
      'Les paramètres les plus influents sur l\'écart entre tes options.';

  @override
  String get renteVsCapitalHypothesesTitle => 'Hypothèses de cette simulation';

  @override
  String get renteVsCapitalWarning => 'Avertissement';

  @override
  String renteVsCapitalSources(String sources) {
    return 'Sources : $sources';
  }

  @override
  String get renteVsCapitalRachatLabel => 'Rachat LPP annuel prévu (CHF)';

  @override
  String renteVsCapitalRachatMax(String amount) {
    return 'max $amount';
  }

  @override
  String get renteVsCapitalRachatHint => '0 (optionnel)';

  @override
  String get renteVsCapitalRachatTooltip =>
      'Si tu fais des rachats LPP chaque année, leur valeur futur est ajoutée au capital à la retraite. Blocage 3 ans avant EPL (LPP art. 79b).';

  @override
  String get renteVsCapitalEplLabel => 'Retrait EPL pour achat immobilier';

  @override
  String get renteVsCapitalEplHint => 'Montant retiré (min 20\'000)';

  @override
  String get renteVsCapitalEplTooltip =>
      'Le retrait EPL réduit ton avoir LPP et donc ton capital ou ta rente à la retraite. Minimum CHF 20\'000 (OPP2 art. 5). Bloque le rachat LPP pendant 3 ans.';

  @override
  String get renteVsCapitalEplLegalRef =>
      'LPP art. 30c — OPP2 art. 5 (min CHF 20\'000)';

  @override
  String get renteVsCapitalProfileAutoFill =>
      'Valeurs pré-remplies depuis ton profil';

  @override
  String get frontalierAppBarTitle => 'Frontalier';

  @override
  String get frontalierTabImpots => 'Impôts';

  @override
  String get frontalierTab90Jours => '90 jours';

  @override
  String get frontalierTabCharges => 'Charges';

  @override
  String get frontalierCantonTravail => 'Canton de travail';

  @override
  String get frontalierSalaireBrut => 'Salaire brut mensuel';

  @override
  String get frontalierEtatCivil => 'État civil';

  @override
  String get frontalierCelibataire => 'Célibataire';

  @override
  String get frontalierMarie => 'Marié(e)';

  @override
  String get frontalierEnfantsCharge => 'Enfants à charge';

  @override
  String get frontalierTauxEffectif => 'Taux effectif';

  @override
  String get frontalierTotalAnnuel => 'Total annuel';

  @override
  String get frontalierParMois => 'par mois';

  @override
  String get frontalierQuasiResidentTitle => 'Quasi-résident (Genève)';

  @override
  String get frontalierQuasiResidentDesc =>
      'Si plus de 90% de tes revenus mondiaux proviennent de Suisse, tu peux demander la taxation ordinaire avec déductions (3a, frais effectifs, etc.). Cela peut réduire significativement ton impôt.';

  @override
  String get frontalierTessinTitle => 'Tessin — régime spécial';

  @override
  String get frontalierEducationalTax =>
      'En Suisse, les frontaliers sont imposés à la source (barème C). Le taux varie selon le canton, l\'état civil et le nombre d\'enfants. À Genève, si plus de 90% de tes revenus mondiaux proviennent de Suisse, tu peux demander le statut de quasi-résident pour bénéficier des déductions.';

  @override
  String get frontalierJoursBureau => 'Jours au bureau en Suisse';

  @override
  String get frontalierJoursHomeOffice => 'Jours en home office à l\'étranger';

  @override
  String get frontalierJaugeRisque => 'JAUGE DE RISQUE';

  @override
  String get frontalierJoursHomeOfficeLabel => 'jours de home office';

  @override
  String get frontalierRiskLow => 'Pas de risque';

  @override
  String get frontalierRiskMedium => 'Zone d\'attention';

  @override
  String get frontalierRiskHigh => 'Risque fiscal — l\'imposition bascule';

  @override
  String frontalierDaysRemaining(int days) {
    return 'Il te reste $days jours de marge';
  }

  @override
  String get frontalierRecommandation => 'RECOMMANDATION';

  @override
  String get frontalierEducational90Days =>
      'Depuis 2023, les accords amiables entre la Suisse et ses voisins fixent un seuil de tolérance pour le télétravail des frontaliers. Au-delà de 90 jours de home office par an, les cotisations sociales et l\'imposition peuvent basculer vers le pays de résidence.';

  @override
  String get frontalierChargesCh => 'Charges CH';

  @override
  String frontalierChargesCountry(String country) {
    return 'Charges $country';
  }

  @override
  String frontalierDuSalaire(String percent) {
    return '$percent% du salaire';
  }

  @override
  String frontalierChargesChMoins(String amount) {
    return 'Charges CH moins élevées : $amount/an';
  }

  @override
  String frontalierChargesChPlus(String amount) {
    return 'Charges CH plus élevées : +$amount/an';
  }

  @override
  String get frontalierAssuranceMaladie => 'ASSURANCE MALADIE';

  @override
  String get frontalierLamalTitle => 'LAMal (suisse)';

  @override
  String get frontalierLamalDesc =>
      'Obligatoire si tu travailles en CH. Prime individuelle (~CHF 300-500/mois).';

  @override
  String get frontalierCmuTitle => 'CMU/Sécu (France)';

  @override
  String get frontalierCmuDesc =>
      'Droit d\'option possible pour les frontaliers FR. Cotisation ~8% du revenu fiscal.';

  @override
  String get frontalierAssurancePriveeTitle => 'Assurance privée (DE/IT/AT)';

  @override
  String get frontalierAssurancePriveeDesc =>
      'En Allemagne, option PKV pour hauts revenus. IT/AT : régime obligatoire du pays.';

  @override
  String get frontalierEducationalCharges =>
      'En tant que frontalier, tu cotises aux assurances sociales suisses (AVS/AI/APG, AC, LPP). Les taux sont généralement plus bas qu\'en France ou en Allemagne — mais la LAMal est à ta charge individuellement, ce qui peut compenser l\'avantage.';

  @override
  String get frontalierPaysResidence => 'Pays de résidence';

  @override
  String get frontalierLeSavaisTu => 'Le savais-tu ?';

  @override
  String get concubinageAppBarTitle => 'Mariage vs Concubinage';

  @override
  String get concubinageTabComparateur => 'Comparateur';

  @override
  String get concubinageTabChecklist => 'Checklist';

  @override
  String get concubinageRevenu1 => 'Revenu 1';

  @override
  String get concubinageRevenu2 => 'Revenu 2';

  @override
  String get concubinagePatrimoineTotal => 'Patrimoine total';

  @override
  String get concubinageCanton => 'Canton';

  @override
  String get concubinageAvantages => 'avantages';

  @override
  String get concubinageMariage => 'Mariage';

  @override
  String get concubinageConcubinage => 'Concubinage';

  @override
  String get concubinageDetailFiscal => 'DÉTAIL FISCAL';

  @override
  String get concubinageImpots2Celibataires => 'Impôts 2 célibataires';

  @override
  String get concubinageImpotsMaries => 'Impôts mariés';

  @override
  String get concubinagePenaliteMariage => 'Pénalité mariage';

  @override
  String get concubinageBonusMariage => 'Bonus mariage';

  @override
  String get concubinageImpotSuccession => 'IMPÔT SUR LA SUCCESSION';

  @override
  String get concubinagePatrimoineTransmis => 'Patrimoine transmis';

  @override
  String get concubinageMarieExonere => 'CHF 0 (exonéré)';

  @override
  String concubinageConcubinTaux(String taux) {
    return 'Concubin-e (~$taux%)';
  }

  @override
  String concubinageWarningSuccession(String impot, String patrimoine) {
    return 'En concubinage, ton partenaire paierait $impot d\'impôt successoral sur un patrimoine de $patrimoine. Marié-e, il/elle serait totalement exonéré-e.';
  }

  @override
  String get concubinageNeutralTitle =>
      'Aucune option n\'est universellement adaptée';

  @override
  String get concubinageNeutralDesc =>
      'Le choix entre mariage et concubinage dépend de ta situation : revenus, patrimoine, enfants, canton, projet de vie. Le mariage offre plus de protections légales automatiques, le concubinage plus de flexibilité. Un·e spécialiste peut t\'aider à y voir plus clair.';

  @override
  String get concubinageChecklistIntro =>
      'En concubinage, rien n\'est automatique. Voici les protections essentielles à mettre en place pour protéger ton/ta partenaire.';

  @override
  String concubinageProtectionsCount(int count, int total) {
    return '$count/$total protections en place';
  }

  @override
  String get concubinageChecklist1Title => 'Rédiger un testament';

  @override
  String get concubinageChecklist1Desc =>
      'Sans testament, ton partenaire n\'hérite de rien — tout va à tes parents ou à tes frères et sœurs. Un testament olographe (écrit à la main, daté, signé) suffit. Tu peux léguer la quotité disponible à ton/ta partenaire.';

  @override
  String get concubinageChecklist2Title => 'Clause bénéficiaire LPP';

  @override
  String get concubinageChecklist2Desc =>
      'Contacte ta caisse de pension pour inscrire ton/ta partenaire comme bénéficiaire. Sans cette clause, le capital décès LPP ne lui revient pas. La plupart des caisses acceptent le concubin sous conditions (ménage commun, etc.).';

  @override
  String get concubinageChecklist3Title => 'Convention de concubinage';

  @override
  String get concubinageChecklist3Desc =>
      'Un contrat écrit qui règle le partage des frais, la propriété des biens, et ce qui se passe en cas de séparation. Pas obligatoire, mais fortement recommandé — surtout si tu achètes un bien immobilier ensemble.';

  @override
  String get concubinageChecklist4Title => 'Assurance-vie croisée';

  @override
  String get concubinageChecklist4Desc =>
      'Une assurance-vie où chacun est bénéficiaire de l\'autre permet de compenser l\'absence de rente AVS/LPP de survivant. Compare les offres — les primes dépendent de l\'âge et du capital assuré.';

  @override
  String get concubinageChecklist5Title => 'Mandat pour cause d\'inaptitude';

  @override
  String get concubinageChecklist5Desc =>
      'Si tu deviens incapable de discernement (accident, maladie), ton/ta partenaire n\'a aucun pouvoir de représentation. Un mandat pour cause d\'inaptitude (CC art. 360 ss) lui donne ce droit.';

  @override
  String get concubinageChecklist6Title => 'Directives anticipées';

  @override
  String get concubinageChecklist6Desc =>
      'Un document qui précise tes volontés médicales en cas d\'incapacité. Tu peux y désigner ton/ta partenaire comme personne de confiance pour les décisions médicales (CC art. 370 ss).';

  @override
  String get concubinageChecklist7Title =>
      'Compte joint pour les dépenses communes';

  @override
  String get concubinageChecklist7Desc =>
      'Un compte commun simplifie la gestion des dépenses partagées (loyer, courses, factures). Définissez clairement la contribution de chacun. En cas de séparation, le solde est partagé à 50/50 sauf convention contraire.';

  @override
  String get concubinageChecklist8Title => 'Bail commun ou individuel';

  @override
  String get concubinageChecklist8Desc =>
      'Si tu es sur le bail avec ton/ta partenaire, vous êtes solidairement responsables. En cas de séparation, les deux doivent donner congé. Si un seul est titulaire, l\'autre n\'a aucun droit sur le logement.';

  @override
  String get concubinageDisclaimer =>
      'Informations simplifiées à but éducatif — ne constitue pas un conseil juridique ou fiscal. Les règles dépendent du canton, de la commune et de ta situation personnelle. Consulte un·e spécialiste juridique pour un avis personnalisé.';

  @override
  String get concubinageCriteriaImpots => 'Impôts';

  @override
  String get concubinageCriteriaPenaliteFiscale => 'Pénalité fiscale';

  @override
  String get concubinageCriteriaBonusFiscal => 'Bonus fiscal';

  @override
  String get concubinageCriteriaAvantageux => 'Avantageux';

  @override
  String get concubinageCriteriaDesavantageux => 'Désavantageux';

  @override
  String get concubinageCriteriaHeritage => 'Héritage';

  @override
  String get concubinageCriteriaHeritageMarriage => 'Exonéré (CC art. 462)';

  @override
  String get concubinageCriteriaHeritageConcubinage => 'Impôt cantonal';

  @override
  String get concubinageCriteriaProtection => 'Protection décès';

  @override
  String get concubinageCriteriaProtectionMarriage => 'AVS + LPP survivant';

  @override
  String get concubinageCriteriaProtectionConcubinage =>
      'Aucune rente automatique';

  @override
  String get concubinageCriteriaFlexibilite => 'Flexibilité';

  @override
  String get concubinageCriteriaFlexibiliteMarriage => 'Procédure judiciaire';

  @override
  String get concubinageCriteriaFlexibiliteConcubinage =>
      'Séparation simplifiée';

  @override
  String get concubinageCriteriaPension => 'Pension alim.';

  @override
  String get concubinageCriteriaPensionMarriage => 'Protégée par le juge';

  @override
  String get concubinageCriteriaPensionConcubinage => 'Accord préalable';

  @override
  String get concubinageMarieExonereLabel => 'Marié·e';

  @override
  String get frontalierChargesTotal => 'Total';

  @override
  String get frontalierJoursSuffix => 'jours';

  @override
  String get conversationHistoryTitle => 'Historique';

  @override
  String get conversationNew => 'Nouvelle conversation';

  @override
  String get conversationEmptyTitle => 'Aucune conversation';

  @override
  String get conversationEmptySubtitle =>
      'Commence à discuter avec ton coach pour voir l\'historique ici';

  @override
  String get conversationStartFirst => 'Démarrer une conversation';

  @override
  String get conversationErrorTitle => 'Erreur de chargement';

  @override
  String get conversationRetry => 'Réessayer';

  @override
  String get conversationDeleteTitle => 'Supprimer cette conversation ?';

  @override
  String get conversationDeleteConfirm => 'Cette action est irréversible.';

  @override
  String get conversationDeleteCancel => 'Annuler';

  @override
  String get conversationDeleteAction => 'Supprimer';

  @override
  String get conversationDateNow => 'À l\'instant';

  @override
  String get conversationDateYesterday => 'Hier';

  @override
  String conversationDateMinutesAgo(String minutes) {
    return 'Il y a $minutes min';
  }

  @override
  String conversationDateHoursAgo(String hours) {
    return 'Il y a ${hours}h';
  }

  @override
  String conversationDateFormatted(String day, String month) {
    return '$day $month';
  }

  @override
  String conversationMonth(String month) {
    String _temp0 = intl.Intl.selectLogic(
      month,
      {
        '1': 'janvier',
        '2': 'février',
        '3': 'mars',
        '4': 'avril',
        '5': 'mai',
        '6': 'juin',
        '7': 'juillet',
        '8': 'août',
        '9': 'septembre',
        '10': 'octobre',
        '11': 'novembre',
        '12': 'décembre',
        'other': 'mois',
      },
    );
    return '$_temp0';
  }

  @override
  String get achievementsTitle => 'Mes accomplissements';

  @override
  String get achievementsEmptyProfile =>
      'Complète ton profil pour débloquer les accomplissements.';

  @override
  String get achievementsDaysSingular => 'jour';

  @override
  String get achievementsDaysPlural => 'jours !';

  @override
  String achievementsRecord(int count) {
    return 'Record : $count jours';
  }

  @override
  String achievementsTotalDays(int count) {
    return '$count jours au total';
  }

  @override
  String get achievementsEngageCta =>
      'Fais une action aujourd\'hui pour maintenir ta série !';

  @override
  String get achievementsEngagedToday => 'Engagement enregistré aujourd\'hui';

  @override
  String get achievementsBadgesTitle => 'Badges';

  @override
  String get achievementsBadgesSubtitle =>
      'Régularité de tes check-ins mensuels';

  @override
  String achievementsBadgeMonths(int count) {
    return '$count mois';
  }

  @override
  String get achievementsMilestonesTitle => 'Milestones';

  @override
  String get achievementsMilestonesSubtitle => 'Tes jalons financiers';

  @override
  String get achievementsDisclaimer =>
      'Tes accomplissements sont personnels — MINT ne les compare jamais à d\'autres.';

  @override
  String get achievementsDayMon => 'L';

  @override
  String get achievementsDayTue => 'M';

  @override
  String get achievementsDayWed => 'M';

  @override
  String get achievementsDayThu => 'J';

  @override
  String get achievementsDayFri => 'V';

  @override
  String get achievementsDaySat => 'S';

  @override
  String get achievementsDaySun => 'D';

  @override
  String get achievementsBadgeFirstStepLabel => 'Premier pas';

  @override
  String get achievementsBadgeFirstStepDesc =>
      'Tu as fait ton premier check-in.';

  @override
  String get achievementsBadgeRegulierLabel => 'Régulier·e';

  @override
  String get achievementsBadgeRegulierDesc => '3 mois consécutifs de check-in.';

  @override
  String get achievementsBadgeConstantLabel => 'Constant·e';

  @override
  String get achievementsBadgeConstantDesc => '6 mois sans interruption.';

  @override
  String get achievementsBadgeDisciplineLabel => 'Discipliné·e';

  @override
  String get achievementsBadgeDisciplineDesc =>
      '12 mois consécutifs — une année complète.';

  @override
  String get achievementsCatPatrimoine => 'Patrimoine';

  @override
  String get achievementsCatPrevoyance => 'Prévoyance';

  @override
  String get achievementsCatSecurite => 'Sécurité';

  @override
  String get achievementsCatScoreFri => 'Score FRI';

  @override
  String get achievementsCatEngagement => 'Engagement';

  @override
  String get achievementsFriAbove50Label => 'Score FRI 50+';

  @override
  String get achievementsFriAbove50Desc =>
      'Atteindre un score de solidité de 50/100';

  @override
  String get achievementsFriAbove70Label => 'Score FRI 70+';

  @override
  String get achievementsFriAbove70Desc =>
      'Atteindre un score de solidité de 70/100';

  @override
  String get achievementsFriAbove85Label => 'Score FRI 85+';

  @override
  String get achievementsFriAbove85Desc => 'Zone d\'excellence — 85/100';

  @override
  String get achievementsFriImproved10Label => 'Progression +10';

  @override
  String get achievementsFriImproved10Desc =>
      'Gagner 10 points de score FRI en un mois';

  @override
  String get achievementsStreak6MonthsLabel => 'Série 6 mois';

  @override
  String get achievementsStreak6MonthsDesc => '6 mois consécutifs de check-in';

  @override
  String get achievementsStreak12MonthsLabel => 'Série 12 mois';

  @override
  String get achievementsStreak12MonthsDesc =>
      '12 mois consécutifs — une année complète';

  @override
  String get achievementsFirstArbitrageLabel => 'Premier arbitrage';

  @override
  String get achievementsFirstArbitrageDesc =>
      'Compléter ta première simulation d\'arbitrage';

  @override
  String get nudgeSalaryTitle => 'Jour de salaire !';

  @override
  String get nudgeSalaryMessage =>
      'As-tu pensé à ton virement 3a ce mois-ci ? Chaque mois compte pour ta prévoyance.';

  @override
  String get nudgeSalaryAction => 'Voir mon 3a';

  @override
  String get nudgeTaxTitle => 'Déclaration fiscale';

  @override
  String get nudgeTaxMessage =>
      'Vérifie la date limite de déclaration fiscale dans ton canton. As-tu pensé à vérifier tes déductions 3a et LPP ?';

  @override
  String get nudgeTaxAction => 'Simuler mes impôts';

  @override
  String get nudge3aTitle => 'Dernière ligne droite pour ton 3a';

  @override
  String get nudge3aMessageLastDay =>
      'C\'est le dernier jour pour verser sur ton 3a !';

  @override
  String nudge3aMessage(String days, String limit, String year) {
    return 'Il reste $days jour(s) pour verser jusqu\'à $limit CHF et réduire tes impôts $year.';
  }

  @override
  String get nudge3aAction => 'Calculer mon économie';

  @override
  String nudgeBirthdayTitle(String age) {
    return 'Tu as $age ans cette année !';
  }

  @override
  String get nudgeBirthdayAction => 'Voir mon tableau de bord';

  @override
  String get nudgeAnniversaryTitle => 'Déjà 1 an ensemble !';

  @override
  String get nudgeAnniversaryMessage =>
      'Tu utilises MINT depuis un an. C\'est le moment idéal pour actualiser ton profil et mesurer tes progrès.';

  @override
  String get nudgeAnniversaryAction => 'Actualiser mon profil';

  @override
  String get nudgeLppStartTitle => 'Début des cotisations LPP';

  @override
  String get nudgeLppChangeTitle => 'Changement de tranche LPP';

  @override
  String nudgeLppStartMessage(String rate) {
    return 'Tes cotisations LPP de vieillesse commencent cette année ($rate %). C\'est le début de ta prévoyance professionnelle.';
  }

  @override
  String nudgeLppChangeMessage(String age, String rate) {
    return 'À $age ans, ta bonification de vieillesse passe à $rate %. Cela pourrait être le bon moment pour envisager un rachat LPP.';
  }

  @override
  String get nudgeLppAction => 'Explorer le rachat';

  @override
  String get nudgeWeeklyTitle => 'Ça fait un moment !';

  @override
  String get nudgeWeeklyMessage =>
      'Ta situation financière évolue chaque semaine. Prends 2 minutes pour vérifier ton tableau de bord.';

  @override
  String get nudgeWeeklyAction => 'Voir mon Pulse';

  @override
  String get nudgeStreakTitle => 'Ta série est en danger !';

  @override
  String nudgeStreakMessage(String count) {
    return 'Tu as une série de $count jours. Une petite action aujourd\'hui suffit pour la maintenir.';
  }

  @override
  String get nudgeStreakAction => 'Continuer ma série';

  @override
  String get nudgeGoalTitle => 'Ton objectif approche';

  @override
  String nudgeGoalMessage(String desc, String days) {
    return '« $desc » — il reste $days jour(s). As-tu avancé sur ce sujet ?';
  }

  @override
  String get nudgeGoalAction => 'En parler au coach';

  @override
  String get nudgeFhsTitle => 'Ton score santé a baissé';

  @override
  String nudgeFhsMessage(String drop) {
    return 'Ton Financial Health Score a perdu $drop points. Voyons ensemble ce qui pourrait expliquer ce changement.';
  }

  @override
  String get nudgeFhsAction => 'Comprendre la baisse';

  @override
  String get recapEngagement => 'Engagement';

  @override
  String get recapBudget => 'Budget';

  @override
  String get recapGoals => 'Objectifs';

  @override
  String get recapFhs => 'Score financier';

  @override
  String get recapOnTrack => 'Budget dans les clous cette semaine.';

  @override
  String get recapOverBudget =>
      'Budget dépassé cette semaine — vérifie les postes principaux.';

  @override
  String get recapUnderBudget =>
      'Tu as dépensé moins que prévu — beau contrôle !';

  @override
  String get recapNoData => 'Pas assez de données budget cette semaine.';

  @override
  String recapDaysActive(String count) {
    return '$count jour(s) actif(s) cette semaine.';
  }

  @override
  String recapGoalsActive(String count) {
    return '$count objectif(s) en cours.';
  }

  @override
  String recapFhsUp(String delta) {
    return 'Score en hausse de +$delta points.';
  }

  @override
  String recapFhsDown(String delta) {
    return 'Score en baisse de $delta points.';
  }

  @override
  String get recapFhsStable => 'Score stable cette semaine.';

  @override
  String get recapTitle => 'Ton récap de la semaine';

  @override
  String recapPeriod(String start, String end) {
    return 'Du $start au $end';
  }

  @override
  String get recapBudgetTitle => 'Budget';

  @override
  String get recapBudgetSaved => 'Épargné cette semaine';

  @override
  String get recapBudgetRate => 'Taux d\'épargne';

  @override
  String get recapActionsTitle => 'Actions réalisées';

  @override
  String get recapActionsNone => 'Aucune action cette semaine';

  @override
  String get recapProgressTitle => 'Progression';

  @override
  String recapProgressDelta(String delta) {
    return '$delta pts de confiance';
  }

  @override
  String get recapHighlightsTitle => 'Points marquants';

  @override
  String get recapNextFocusTitle => 'La semaine prochaine';

  @override
  String get recapEmpty => 'Pas encore de données cette semaine';

  @override
  String get decesProcheTitre => 'Décès d\'un proche';

  @override
  String get decesProcheMoisRepudiation =>
      'mois pour accepter ou répudier la succession (CC art. 567)';

  @override
  String get decesProche48hTitre => 'Urgences : premières 48 heures';

  @override
  String get decesProche48hActe =>
      'Obtenir l\'acte de décès auprès de l\'état civil';

  @override
  String get decesProche48hBanque =>
      'Informer la banque — les comptes sont bloqués dès notification';

  @override
  String get decesProche48hAssurance =>
      'Contacter les assurances (vie, LAMal, ménage)';

  @override
  String get decesProche48hEmployeur =>
      'Prévenir l\'employeur du défunt pour le solde de salaire';

  @override
  String get decesProcheSituation => 'Ta situation';

  @override
  String get decesProcheLienParente => 'Lien avec le défunt';

  @override
  String get decesProcheLienConjoint => 'Conjoint·e';

  @override
  String get decesProcheLienParent => 'Parent';

  @override
  String get decesProcheLienEnfant => 'Enfant';

  @override
  String get decesProcheFortune => 'Fortune estimée du défunt';

  @override
  String get decesProcheCanton => 'Canton';

  @override
  String get decesProchTestament => 'Un testament existe';

  @override
  String get decesProchTimelineTitre => 'Chronologie de la succession';

  @override
  String get decesProchTimeline1Titre => 'Acte de décès & blocage';

  @override
  String get decesProchTimeline1Desc =>
      'L\'état civil délivre l\'acte. Les comptes bancaires sont gelés.';

  @override
  String get decesProchTimeline2Titre => 'Inventaire & notaire';

  @override
  String get decesProchTimeline2Desc =>
      'Le notaire ouvre la succession et établit l\'inventaire des biens.';

  @override
  String get decesProchTimeline3Titre => 'Délai de répudiation';

  @override
  String get decesProchTimeline3Desc =>
      '3 mois pour accepter ou répudier (CC art. 567). Passé ce délai, la succession est acceptée.';

  @override
  String get decesProchTimeline4Titre => 'Partage & impôts';

  @override
  String get decesProchTimeline4Desc =>
      'Déclaration de succession et paiement de l\'impôt cantonal (si applicable).';

  @override
  String get decesProchebeneficiairesTitre => 'Bénéficiaires LPP & 3a';

  @override
  String get decesProchebeneficiairesLpp => 'Capital LPP du défunt';

  @override
  String get decesProchebeneficiaires3a => 'Capital 3a du défunt';

  @override
  String get decesProchebeneficiairesNote =>
      'L\'ordre des bénéficiaires LPP est fixé par le règlement de la caisse (OPP2 art. 48). Le 3a suit l\'OPP3 art. 2.';

  @override
  String get decesProchImpactFiscalTitre => 'Impact fiscal';

  @override
  String decesProchImpactFiscalExempt(String canton) {
    return 'En $canton, le conjoint survivant est exonéré de l\'impôt de succession.';
  }

  @override
  String decesProchImpactFiscalTaxe(String canton) {
    return 'En $canton, les héritiers sont soumis à l\'impôt cantonal de succession. Le taux varie selon le lien de parenté.';
  }

  @override
  String get decesProchActionsTitre => 'Prochaines étapes';

  @override
  String get decesProchAction1 =>
      'Rassembler les documents : acte de décès, testament, certificats LPP et 3a';

  @override
  String get decesProchAction2 =>
      'Consulter un·e notaire pour l\'inventaire successoral';

  @override
  String get decesProchAction3 =>
      'Vérifier les bénéficiaires LPP et 3a auprès des caisses';

  @override
  String get decesProchDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil juridique ou fiscal (LSFin). Chaque succession est unique : consulte un·e notaire ou un·e spécialiste. Sources : CC art. 457-640, OPP2 art. 48, OPP3 art. 2.';

  @override
  String get demenagementTitre => 'Déménagement cantonal';

  @override
  String get demenagementChiffreChocSousTitre =>
      'économie (ou surcoût) annuel estimé';

  @override
  String demenagementChiffreChocDetail(String depart, String arrivee) {
    return 'En déménageant de $depart vers $arrivee (impôts + LAMal)';
  }

  @override
  String get demenagementSituation => 'Ta situation';

  @override
  String get demenagementCantonDepart => 'Canton actuel';

  @override
  String get demenagementCantonArrivee => 'Canton d\'arrivée';

  @override
  String get demenagementRevenu => 'Revenu brut annuel';

  @override
  String get demenagementCelibataire => 'Célibataire';

  @override
  String get demenagementMarie => 'Marié·e';

  @override
  String get demenagementFiscalTitre => 'Comparaison fiscale';

  @override
  String get demenagementEconomieFiscale => 'Économie fiscale estimée';

  @override
  String get demenagementLamalTitre => 'Primes LAMal';

  @override
  String get demenagementChecklistTitre => 'Checklist déménagement';

  @override
  String get demenagementChecklist1 =>
      'Annoncer le départ à la commune d\'origine (8 jours avant)';

  @override
  String get demenagementChecklist2 =>
      'S\'inscrire à la commune d\'arrivée (8 jours après)';

  @override
  String get demenagementChecklist3 =>
      'Changer de caisse LAMal ou mettre à jour la région de prime';

  @override
  String get demenagementChecklist4 =>
      'Adapter la déclaration fiscale (imposition au 31.12)';

  @override
  String get demenagementChecklist5 =>
      'Vérifier les allocations familiales cantonales';

  @override
  String get demenagementDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil fiscal (LSFin). Les chiffres sont des estimations basées sur des indices cantonaux simplifiés. Consulte un·e spécialiste pour ta situation. Sources : LIFD, LAMal, barèmes cantonaux 2025.';

  @override
  String get docScanAppBarTitle => 'SCANNER UN DOCUMENT';

  @override
  String get docScanHeaderTitle => 'Améliore la précision de ton profil';

  @override
  String get docScanHeaderSubtitle =>
      'Photographie un document financier et on extrait les chiffres pour toi. Tu vérifies ensuite chaque valeur avant confirmation.';

  @override
  String get docScanDocumentType => 'Type de document';

  @override
  String docScanConfidencePoints(int points) {
    return '+$points points de confiance';
  }

  @override
  String get docScanFromGallery => 'Depuis la galerie';

  @override
  String get docScanPasteOcrText => 'Coller le texte OCR';

  @override
  String get docScanUseExample => 'Utiliser un exemple de test';

  @override
  String get docScanPrivacyNote =>
      'L\'image est analysée localement (OCR sur l\'appareil). Si tu utilises l\'analyse Vision IA, l\'image est envoyée à ton fournisseur IA via ta propre clé API. Seules les valeurs confirmées sont conservées dans ton profil.';

  @override
  String get docScanCameraError =>
      'Impossible d\'ouvrir la caméra. Utilise la galerie.';

  @override
  String get docScanEmptyTextFile => 'Le fichier texte est vide.';

  @override
  String get docScanFileUnreadableTitle => 'Fichier non exploitable';

  @override
  String get docScanFileUnreadableMessage =>
      'Nous n\'avons pas pu lire ce fichier directement depuis ton appareil. Prends une photo du document ou colle un texte OCR.';

  @override
  String docScanImportError(String error) {
    return 'Impossible d\'importer le fichier : $error';
  }

  @override
  String get docScanOcrNotDetectedTitle => 'Texte non détecté';

  @override
  String get docScanOcrNotDetectedMessage =>
      'Nous n\'avons pas pu lire suffisamment de texte sur la photo.';

  @override
  String get docScanPhotoAnalysisTitle => 'Analyse de la photo indisponible';

  @override
  String get docScanPhotoAnalysisMessage =>
      'Nous n\'avons pas pu extraire le texte automatiquement. Réessaie avec une photo plus nette ou colle le texte OCR.';

  @override
  String get docScanNoFieldRecognized => 'Aucun champ reconnu automatiquement';

  @override
  String get docScanNoFieldHint =>
      'Ajoute ou corrige le texte OCR pour améliorer l\'analyse, puis relance.';

  @override
  String docScanParsingError(String error) {
    return 'Parsing impossible pour ce document : $error';
  }

  @override
  String get docScanOcrPasteHint => 'Colle ici le texte OCR brut…';

  @override
  String get docScanPdfDetected => 'PDF détecté';

  @override
  String get docScanPdfCannotRead =>
      'Impossible de lire ce PDF directement sur cet appareil. Prends une photo du document ou colle un texte OCR.';

  @override
  String get docScanPdfAnalysisUnavailable => 'Analyse PDF indisponible';

  @override
  String get docScanPdfNotParsed =>
      'Le PDF n\'a pas pu être analysé automatiquement. Tu peux prendre une photo (recommandé) ou coller un texte OCR.';

  @override
  String get docScanPdfNotAvailable =>
      'Le parsing PDF n\'est pas disponible dans ce contexte. Prends une photo ou colle un texte OCR.';

  @override
  String get docScanPdfOptimizedLpp =>
      'Pour le moment, le parsing PDF automatique est surtout optimisé pour les certificats LPP. Prends une photo du document.';

  @override
  String get docScanPdfTypeUnsupported =>
      'Type de document non pris en charge pour le parsing PDF.';

  @override
  String get docScanPdfNoData =>
      'Aucune donnée utile n\'a été extraite depuis ce PDF.';

  @override
  String docScanPdfBackendError(String error) {
    return 'Erreur backend pendant le parsing PDF : $error';
  }

  @override
  String get docScanBackendDisclaimer =>
      'Données extraites automatiquement : vérifie chaque valeur avant confirmation.';

  @override
  String get docScanBackendDisclaimerShort =>
      'Vérifie les montants avant confirmation. Outil éducatif (LSFin).';

  @override
  String get docScanVisionAnalyze => 'Analyser via Vision IA';

  @override
  String get docScanVisionDisclaimer =>
      'L\'image sera envoyée à ton fournisseur IA via ta clé API.';

  @override
  String get docScanVisionNoFields =>
      'L\'IA n\'a pas pu extraire de champs de ce document.';

  @override
  String get docScanVisionDefaultDisclaimer =>
      'Données extraites par IA : vérifie chaque valeur. Outil éducatif, ne constitue pas un conseil (LSFin).';

  @override
  String get docScanVisionConfigError =>
      'Configure une clé API dans les paramètres Coach.';

  @override
  String docScanVisionError(String error) {
    return 'Erreur Vision IA : $error';
  }

  @override
  String get docScanLabelLppTotal => 'Avoir LPP total';

  @override
  String get docScanLabelObligatoire => 'Part obligatoire';

  @override
  String get docScanLabelSurobligatoire => 'Part surobligatoire';

  @override
  String get docScanLabelTauxConvOblig => 'Taux de conversion obligatoire';

  @override
  String get docScanLabelTauxConvSuroblig =>
      'Taux de conversion surobligatoire';

  @override
  String get docScanLabelRachatMax => 'Rachat maximal';

  @override
  String get docScanLabelSalaireAssure => 'Salaire assuré';

  @override
  String get docScanLabelTauxRemuneration => 'Taux de rémunération';

  @override
  String get docImpactTitle => 'Ton profil est plus précis';

  @override
  String docImpactSubtitle(String docType) {
    return 'Les valeurs de ton $docType ont été intégrées dans tes projections.';
  }

  @override
  String get docImpactConfidenceLabel => '% confiance';

  @override
  String docImpactDeltaPoints(int points) {
    return '+$points points de confiance';
  }

  @override
  String get docImpactChiffreChocTitle => 'Chiffre choc recalculé';

  @override
  String docImpactLppRealAmount(String oblig) {
    return 'd\'avoir LPP réel (dont $oblig obligatoire)';
  }

  @override
  String docImpactRenteOblig(String amount) {
    return 'Rente obligatoire à 6.8% : CHF $amount/an';
  }

  @override
  String docImpactSurobligWithRate(String suroblig, String rate, String rente) {
    return 'Part surobligatoire (CHF $suroblig) à $rate% = CHF $rente/an';
  }

  @override
  String docImpactSurobligNoRate(String suroblig) {
    return 'Part surobligatoire (CHF $suroblig) = taux de conversion libre de la caisse';
  }

  @override
  String docImpactAvsYears(int years) {
    return '$years ans de cotisation';
  }

  @override
  String docImpactAvsCompletion(int maxYears, int pct) {
    return 'sur $maxYears nécessaires pour une rente AVS complète ($pct%)';
  }

  @override
  String get docImpactGenericMessage =>
      'Tes projections sont maintenant basées sur des valeurs réelles.';

  @override
  String get docImpactFieldsUpdated => 'Champs mis à jour';

  @override
  String get docImpactReturnDashboard => 'Retour au dashboard';

  @override
  String get docImpactDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil en prévoyance. Vérifie toujours avec ton certificat original (LSFin).';

  @override
  String get extractionReviewAppBar => 'VÉRIFICATION';

  @override
  String get extractionReviewTitle => 'Vérifie les valeurs extraites';

  @override
  String extractionReviewSubtitle(int count, String reviewPart) {
    return '$count champs détectés$reviewPart. Tu peux modifier chaque valeur avant de confirmer.';
  }

  @override
  String extractionReviewNeedsReview(int count) {
    return ' dont $count à vérifier';
  }

  @override
  String extractionReviewConfidence(int pct) {
    return 'Confiance extraction : $pct%';
  }

  @override
  String extractionReviewSourcePrefix(String text) {
    return 'Lu : \"$text\"';
  }

  @override
  String get extractionReviewConfirmAll => 'Confirmer tout';

  @override
  String extractionReviewEditTitle(String label) {
    return 'Modifier : $label';
  }

  @override
  String extractionReviewCurrentValue(String value) {
    return 'Valeur actuelle : $value';
  }

  @override
  String get extractionReviewNewValue => 'Nouvelle valeur';

  @override
  String get extractionReviewCancel => 'Annuler';

  @override
  String get extractionReviewValidate => 'Valider';

  @override
  String get extractionReviewEditTooltip => 'Modifier';

  @override
  String get firstSalaryFilmTitle => 'Le film de ton premier salaire';

  @override
  String firstSalaryFilmSubtitle(String amount) {
    return 'CHF $amount brut — 5 actes pour tout comprendre.';
  }

  @override
  String get firstSalaryAct1Label => '1 · Brut→Net';

  @override
  String get firstSalaryAct2Label => '2 · Invisible';

  @override
  String get firstSalaryAct3Label => '3 · 3a';

  @override
  String get firstSalaryAct4Label => '4 · LAMal';

  @override
  String get firstSalaryAct5Label => '5 · Action';

  @override
  String get firstSalaryAct1Title => 'La douche froide';

  @override
  String firstSalaryAct1Quote(String amount) {
    return '$amount CHF disparaissent. Mais ce n\'est pas perdu — c\'est ton futur.';
  }

  @override
  String firstSalaryGross(String amount) {
    return 'Brut : CHF $amount';
  }

  @override
  String firstSalaryNet(String amount) {
    return 'Net : CHF $amount';
  }

  @override
  String firstSalaryNetPercent(int pct) {
    return '$pct% net';
  }

  @override
  String get firstSalaryAct2Title => 'L\'argent invisible';

  @override
  String firstSalaryAct2Quote(String amount) {
    return 'Ton vrai salaire est CHF $amount. Ton employeur paie bien plus que tu ne crois.';
  }

  @override
  String get firstSalaryVisibleNet => '🌊 Visible : ton salaire net';

  @override
  String get firstSalaryVisibleNetSub => 'Ce que tu touches';

  @override
  String get firstSalaryCotisations => '💧 Tes cotisations';

  @override
  String get firstSalaryCotisationsSub => 'Déduits de ton brut';

  @override
  String get firstSalaryEmployerCotisations => '🏔️ Cotisations employeur';

  @override
  String get firstSalaryEmployerCotisationsSub => 'Invisibles sur ta fiche';

  @override
  String get firstSalaryTotalEmployerCost => 'Coût total employeur';

  @override
  String get firstSalaryAct3Title => 'Le cadeau fiscal 3a';

  @override
  String firstSalaryAct3Quote(String amount) {
    return 'CHF $amount/mois → potentiellement millionnaire. Commence maintenant.';
  }

  @override
  String get firstSalaryAt30 => 'À 30 ans';

  @override
  String get firstSalaryAt40 => 'À 40 ans';

  @override
  String get firstSalaryAt65 => 'À 65 ans';

  @override
  String get firstSalary3aInfo =>
      '💰 Plafond 2026 : CHF 7\'258/an · Déduction fiscale directe · OPP3 art. 7';

  @override
  String get firstSalaryAct4Title => 'Le piège LAMal';

  @override
  String get firstSalaryAct4Quote =>
      'La franchise pas chère peut te coûter cher si tu tombes malade.';

  @override
  String get firstSalaryFranchise300Advice =>
      'Conseillé si maladies chroniques';

  @override
  String get firstSalaryFranchise1500Advice => 'Bon compromis · Recommandé';

  @override
  String get firstSalaryFranchise2500Advice =>
      'Économise la prime · Si tu es en bonne santé';

  @override
  String firstSalaryFranchiseLabel(String label) {
    return 'Franchise $label';
  }

  @override
  String firstSalaryFranchisePrime(String amount) {
    return '−CHF $amount/mois prime';
  }

  @override
  String get firstSalaryLamalInfo =>
      '💡 LAMal art. 64 — Franchise annuelle choisie, renouvelable chaque année.';

  @override
  String get firstSalaryAct5Title => 'Ta checklist de démarrage';

  @override
  String get firstSalaryAct5Quote =>
      '5 actions. C\'est tout. Commence cette semaine.';

  @override
  String get firstSalaryWeek1 => 'Semaine 1';

  @override
  String get firstSalaryWeek2 => 'Semaine 2';

  @override
  String get firstSalaryBefore31Dec => 'Avant 31.12';

  @override
  String get firstSalaryTask1 => 'Ouvrir un compte 3a (banque ou fintech)';

  @override
  String get firstSalaryTask2 =>
      'Mettre en place un virement automatique mensuel';

  @override
  String get firstSalaryTask3 =>
      'Choisir ta franchise LAMal (recommandé : CHF 1\'500)';

  @override
  String get firstSalaryTask4 => 'Vérifier ta RC privée (env. CHF 100/an)';

  @override
  String get firstSalaryTask5 => 'Verser le maximum 3a avant le 31 décembre';

  @override
  String get firstSalaryBadgeTitle => 'Premier pas financier';

  @override
  String get firstSalaryBadgeSubtitle =>
      'Tu sais maintenant ce que 90% des gens ne savent jamais.';

  @override
  String get firstSalaryDisclaimer =>
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. Source : LAVS art. 3, LPP art. 7, LACI art. 3, OPP3 art. 7 (3a 7\'258 CHF/an). Taux cotisations indicatifs 2026. Projection 3a : rendement hypothétique 4%/an.';

  @override
  String get benchmarkAppBarTitle => 'Repères cantonaux';

  @override
  String get benchmarkOptInTitle => 'Activer les comparaisons cantonales';

  @override
  String get benchmarkOptInSubtitle =>
      'Compare ta situation à des ordres de grandeur issus des statistiques fédérales (OFS).';

  @override
  String get benchmarkExplanationTitle => 'Des repères, pas un classement';

  @override
  String get benchmarkExplanationBody =>
      'Active cette fonctionnalité pour situer ta situation financière par rapport à des profils similaires dans ton canton. Ces données sont des ordres de grandeur issus de statistiques fédérales anonymisées (OFS). Aucun classement, aucune comparaison sociale.';

  @override
  String get benchmarkNoProfile =>
      'Complète ton profil pour accéder aux repères cantonaux.';

  @override
  String benchmarkNoData(String canton, String ageGroup) {
    return 'Pas de données disponibles pour le canton $canton (tranche $ageGroup).';
  }

  @override
  String benchmarkSimilarProfiles(String canton, String ageGroup) {
    return 'Profils similaires : $canton, tranche $ageGroup';
  }

  @override
  String benchmarkSourceLabel(String source) {
    return 'Source : $source';
  }

  @override
  String get benchmarkWithinRange =>
      'Ta situation se situe dans la fourchette typique.';

  @override
  String get benchmarkAboveRange =>
      'Ta situation est au-delà de la fourchette typique.';

  @override
  String get benchmarkBelowRange =>
      'Ta situation est en-deçà de la fourchette typique.';

  @override
  String benchmarkTypicalRange(String low, String high) {
    return 'Fourchette typique : $low – $high';
  }

  @override
  String get tabPulse => 'Pulse';

  @override
  String get authGateDocScanTitle => 'Sécurise tes documents';

  @override
  String get authGateDocScanMessage =>
      'Tes certificats contiennent des données sensibles. Crée un compte pour les protéger avec un chiffrement de bout en bout.';

  @override
  String get authGateSalaryTitle => 'Protège tes données financières';

  @override
  String get authGateSalaryMessage =>
      'Ton salaire et tes données financières méritent un coffre-fort sécurisé.';

  @override
  String get authGateCoachTitle => 'Le coach a besoin de te connaître';

  @override
  String get authGateCoachMessage =>
      'Pour te donner des réponses personnalisées, le coach a besoin d\'un compte.';

  @override
  String get authGateGoalTitle => 'Suis tes progrès';

  @override
  String get authGateGoalMessage =>
      'Pour suivre tes objectifs dans le temps, crée ton compte.';

  @override
  String get authGateSimTitle => 'Sauvegarde ta simulation';

  @override
  String get authGateSimMessage =>
      'Pour retrouver cette simulation plus tard, crée ton compte.';

  @override
  String get authGateByokTitle => 'Protège ta clé API';

  @override
  String get authGateByokMessage =>
      'Ta clé API sera chiffrée dans ton espace sécurisé.';

  @override
  String get authGateCoupleTitle => 'Le mode couple nécessite un compte';

  @override
  String get authGateCoupleMessage =>
      'Pour inviter ton·ta partenaire, crée d\'abord ton compte personnel.';

  @override
  String get authGateProfileTitle => 'Enrichis ton profil en sécurité';

  @override
  String get authGateProfileMessage =>
      'Plus tu enrichis ton profil, plus tes projections sont précises. Sécurise tes données.';

  @override
  String get authGateCreateAccount => 'Créer mon compte';

  @override
  String get authGateLogin => 'J\'ai déjà un compte';

  @override
  String get authGatePrivacyNote =>
      'Tes données restent sur ton appareil et sont chiffrées.';

  @override
  String get budgetTaxProvisionNotProvided =>
      'Provision impôts (non renseigné)';

  @override
  String get budgetHealthInsuranceNotProvided =>
      'Primes maladie (LAMal) (non renseigné)';

  @override
  String get budgetOtherFixedCosts => 'Autres charges fixes';

  @override
  String get budgetOtherFixedCostsNotProvided =>
      'Autres charges fixes (non renseigné)';

  @override
  String get budgetQualityProvided => 'saisi';

  @override
  String get budgetBannerMissing =>
      'Certaines charges sont encore manquantes. Complète ton diagnostic pour fiabiliser ce budget.';

  @override
  String get budgetBannerEstimated =>
      'Ce budget inclut des estimations (impôts/LAMal). Renseigne tes montants réels pour une projection plus fiable.';

  @override
  String get budgetCompleteMyData => 'Compléter mes données →';

  @override
  String get budgetEmergencyFundTitle => 'Fonds d\'urgence';

  @override
  String get budgetGoalReached => 'Objectif atteint';

  @override
  String get budgetOnTrack => 'En bonne voie';

  @override
  String get budgetToReinforce => 'À renforcer';

  @override
  String budgetMonthsCovered(String months) {
    return '$months mois couverts';
  }

  @override
  String budgetTargetMonths(String target) {
    return 'Cible : $target mois';
  }

  @override
  String get budgetEmergencyProtected =>
      'Tu es protégé contre les imprévus. Continue ainsi.';

  @override
  String budgetEmergencySaveMore(String target) {
    return 'Épargne au moins $target mois de dépenses pour te protéger contre un imprévu (perte d\'emploi, réparation...).';
  }

  @override
  String get budgetExploreAlso => 'Explorer aussi';

  @override
  String get budgetDebtRatio => 'Ratio d\'endettement';

  @override
  String get budgetDebtRatioSubtitle => 'Évaluer ta situation de dette';

  @override
  String get budgetRepaymentPlan => 'Plan de remboursement';

  @override
  String get budgetRepaymentPlanSubtitle => 'Stratégie pour sortir de la dette';

  @override
  String get budgetHelpResources => 'Ressources d\'aide';

  @override
  String get budgetHelpResourcesSubtitle => 'Où trouver de l\'aide en Suisse';

  @override
  String get budgetCtaEvaluate => 'Évaluer';

  @override
  String get budgetCtaPlan => 'Planifier';

  @override
  String get budgetCtaDiscover => 'Découvrir';

  @override
  String get budgetDisclaimerImportant => 'IMPORTANT :';

  @override
  String get budgetDisclaimerBased =>
      '• Les montants sont basés sur les informations déclarées.';

  @override
  String get refreshReturnToDashboard => 'Retour au dashboard';

  @override
  String get refreshOptionNone => 'Aucun';

  @override
  String get refreshOptionPurchase => 'Achat';

  @override
  String get refreshOptionSale => 'Vente';

  @override
  String get refreshOptionRefinancing => 'Refinancement';

  @override
  String get refreshOptionMarriage => 'Mariage';

  @override
  String get refreshOptionBirth => 'Naissance';

  @override
  String get refreshOptionDivorce => 'Divorce';

  @override
  String get refreshOptionDeath => 'Décès';

  @override
  String get refreshProfileUpdated => 'Profil mis à jour !';

  @override
  String refreshScoreUp(String delta) {
    return 'Ton score a augmenté de $delta points !';
  }

  @override
  String refreshScoreDown(String delta) {
    return 'Ton score a baissé de $delta points — vérifions ensemble';
  }

  @override
  String get refreshScoreStable => 'Ton score est stable — continue comme ça !';

  @override
  String get refreshBefore => 'Avant';

  @override
  String get refreshAfter => 'Après';

  @override
  String get chiffreChocDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil financier (LSFin). Sources : LAVS art. 34, LPP art. 14-16, OPP3 art. 7.';

  @override
  String get chiffreChocAction => 'Qu\'est-ce que je peux faire ?';

  @override
  String get chiffreChocEnrich => 'Affiner mon profil';

  @override
  String chiffreChocConfidence(String count) {
    return 'Estimation basée sur $count informations. Plus tu précises, plus c\'est fiable.';
  }

  @override
  String get chatErrorInvalidKey =>
      'Ta clé API semble invalide ou expirée. Vérifie-la dans les paramètres.';

  @override
  String get chatErrorRateLimit =>
      'Limite de requêtes atteinte. Réessaie dans quelques instants.';

  @override
  String get chatErrorTechnical => 'Erreur technique. Réessaie plus tard.';

  @override
  String get chatErrorConnection =>
      'Erreur de connexion. Vérifie ta connexion internet ou ta clé API.';

  @override
  String get chatCoachMint => 'Coach MINT';

  @override
  String get chatEmptyStateMessage =>
      'Complète ton diagnostic pour discuter avec ton coach';

  @override
  String get chatStartButton => 'Commencer';

  @override
  String get chatDisclaimer =>
      'Outil éducatif — les réponses ne constituent pas un conseil financier. LSFin.';

  @override
  String get chatTooltipHistory => 'Historique';

  @override
  String get chatTooltipExport => 'Exporter la conversation';

  @override
  String get chatTooltipSettings => 'Paramètres IA';

  @override
  String get slmChooseModel => 'Choisis ton modèle';

  @override
  String get slmTwoSizesAvailable =>
      'Deux tailles disponibles selon ton appareil';

  @override
  String get slmRecommended => 'Recommandé';

  @override
  String get slmDownloadFailedMessage =>
      'Le téléchargement a échoué. Vérifie ta connexion WiFi et l\'espace disponible sur ton appareil.';

  @override
  String get slmInitError =>
      'Erreur d\'initialisation du modèle. Vérifie que ton appareil est compatible.';

  @override
  String get slmInitializing => 'Initialisation...';

  @override
  String get slmInitEngine => 'Initialiser le moteur';

  @override
  String get disabilityYourSituation => 'Ta situation';

  @override
  String get disabilityGrossMonthly => 'Salaire brut mensuel';

  @override
  String get disabilityYourAge => 'Ton âge';

  @override
  String get disabilityAvailableSavings => 'Épargne disponible';

  @override
  String get disabilityHasIjm => 'J\'ai une assurance IJM via mon employeur';

  @override
  String get disabilityExploreAlso => 'Explorer aussi';

  @override
  String get disabilityCoverageInsurance => 'Couverture assurance';

  @override
  String get disabilityCoverageSubtitle =>
      'IJM, AI, LPP — ton bulletin de notes';

  @override
  String get disabilitySelfEmployed => 'Indépendant';

  @override
  String get disabilitySelfEmployedSubtitle => 'Risques spécifiques sans LPP';

  @override
  String get disabilityCtaEvaluate => 'Évaluer';

  @override
  String get disabilityCtaAnalyze => 'Analyser';

  @override
  String get disabilityAppBarTitle => 'Si je ne peux plus travailler';

  @override
  String get disabilityStatLine1 => '1 personne sur 5';

  @override
  String get disabilityStatLine2 => 'sera touchée avant 65 ans';

  @override
  String get authRegisterSubtitle =>
      'Compte optionnel : tes données restent locales par défaut';

  @override
  String get authWhyCreateAccount => 'Pourquoi créer un compte ?';

  @override
  String get authBenefitProjections =>
      'Projections AVS/LPP alignées à ta situation';

  @override
  String get authBenefitCoach => 'Coach personnalisé avec ton prénom';

  @override
  String get authBenefitSync =>
      'Sauvegarde cloud + synchronisation multi-appareils';

  @override
  String get authFirstName => 'Prénom';

  @override
  String get authFirstNameRequired =>
      'Le prénom est nécessaire pour personnaliser ton coach';

  @override
  String get authBirthYear => 'Année de naissance';

  @override
  String get authBirthYearRequired => 'Nécessaire pour les projections AVS/LPP';

  @override
  String get authPasswordRequirements =>
      'Utilise au moins 8 caractères pour sécuriser ton compte';

  @override
  String get authCguAccept => 'J\'ai lu et j\'accepte les ';

  @override
  String get authCguLink => 'Conditions Générales';

  @override
  String get authCguAndPrivacy => ' et la ';

  @override
  String get authPrivacyLink => 'Politique de confidentialité';

  @override
  String get authConfirm18 => 'Je confirme avoir 18 ans révolus (CGU art. 4.1)';

  @override
  String get authConsentSection => 'Consentements optionnels';

  @override
  String get authConsentNotifications =>
      'Notifications coaching (rappels 3a, échéances fiscales)';

  @override
  String get authConsentAnalytics =>
      'Données anonymisées pour améliorer les benchmarks suisses';

  @override
  String get authPasswordWeak => 'Faible';

  @override
  String get authPasswordMedium => 'Moyen';

  @override
  String get authPasswordStrong => 'Fort';

  @override
  String get authPasswordVeryStrong => 'Très fort';

  @override
  String get authOrContinueWith => 'ou continuer avec';

  @override
  String get authPrivacyReassurance =>
      'Tes données restent chiffrées sur ton appareil. Aucune connexion bancaire.';

  @override
  String get authContinueLocal => 'Continuer en mode local';

  @override
  String get authBack => 'Retour';

  @override
  String coachGreetingSlm(String name) {
    return 'Salut $name. Tout reste sur ton appareil — rien ne sort. C\'est quoi ta question ?';
  }

  @override
  String coachGreetingDefault(String name, String scoreSuffix) {
    return 'Salut $name. Je regarde tes chiffres — dis-moi ce qui te trotte dans la tête.$scoreSuffix';
  }

  @override
  String coachScoreSuffix(int score) {
    return ' Ton score : $score/100 — voyons où ça coince.';
  }

  @override
  String get coachComplianceError =>
      'Je préfère ne pas répondre à ça. Reformule ta question, ou utilise un simulateur pour un chiffre direct.';

  @override
  String get coachErrorInvalidKey =>
      'Ta clé API semble invalide ou expirée. Vérifie-la dans les paramètres.';

  @override
  String get coachErrorRateLimit =>
      'Limite de requêtes atteinte. Réessaie dans quelques instants.';

  @override
  String get coachErrorGeneric => 'Erreur technique. Réessaie plus tard.';

  @override
  String get coachErrorBadRequest => 'Requête invalide. Reformule ta question.';

  @override
  String get coachErrorServiceUnavailable =>
      'Service temporairement indisponible. Réessaie dans quelques minutes.';

  @override
  String get coachErrorConnection =>
      'Erreur de connexion. Vérifie ta connexion internet ou ta clé API.';

  @override
  String get coachSuggestSimulate3a =>
      'Combien j’économise si je verse le max ?';

  @override
  String get coachSuggestView3a => 'J’ai combien sur mes comptes 3a ?';

  @override
  String get coachSuggestSimulateLpp => 'Ça vaut le coup de racheter du LPP ?';

  @override
  String get coachSuggestUnderstandLpp => 'Qu’est-ce que je touche à 65 ans ?';

  @override
  String get coachSuggestTrajectory => 'C’est grave si je fais rien ?';

  @override
  String get coachSuggestScenarios =>
      'Rente ou capital — qu’est-ce qui me convient ?';

  @override
  String get coachSuggestDeductions => 'Combien je récupère cette année ?';

  @override
  String get coachSuggestTaxImpact =>
      'Combien d’impôts en moins avec un rachat ?';

  @override
  String get coachSuggestFitness => 'Je suis où par rapport à mon objectif ?';

  @override
  String get coachSuggestRetirement =>
      'J’aurai assez pour vivre à la retraite ?';

  @override
  String get coachEmptyStateMessage =>
      'Pas encore de profil. Trois questions, et on discute.';

  @override
  String get coachEmptyStateButton => 'Faire mon diagnostic';

  @override
  String get coachTooltipHistory => 'Historique';

  @override
  String get coachTooltipExport => 'Exporter la conversation';

  @override
  String get coachTooltipSettings => 'Paramètres IA';

  @override
  String get coachTooltipLifeEvent => 'Événement de vie';

  @override
  String get coachTierSlm => 'IA on-device';

  @override
  String get coachTierByok => 'IA cloud (BYOK)';

  @override
  String get coachTierFallback => 'Mode hors-ligne';

  @override
  String get coachBadgeSlm => 'On-device';

  @override
  String get coachBadgeByok => 'Cloud';

  @override
  String get coachBadgeFallback => 'Hors-ligne';

  @override
  String get coachDisclaimer =>
      'Outil éducatif — les réponses ne constituent pas un conseil financier (LSFin art. 3). Consulte un·e spécialiste pour les décisions importantes.';

  @override
  String get coachLoading => 'Je regarde tes chiffres…';

  @override
  String get coachSources => 'Sources';

  @override
  String get coachInputHint => 'Une question sur tes finances ?';

  @override
  String get coachTitle => 'Coach MINT';

  @override
  String get coachFallbackName => 'ami·e';

  @override
  String get coachUserMessage => 'Ton message';

  @override
  String get coachCoachMessage => 'Réponse du coach';

  @override
  String get coachSendButton => 'Envoyer';

  @override
  String get profileDefaultName => 'Utilisateur';

  @override
  String profileNameAge(String name, int age) {
    return '$name, $age ans';
  }

  @override
  String get commonEdit => 'Modifier';

  @override
  String get profileSlmTitle => 'IA on-device (SLM)';

  @override
  String get profileSlmReady => 'Modèle prêt';

  @override
  String get profileSlmNotInstalled => 'Modèle non installé';

  @override
  String get profileDeleteAccountSuccess => 'Compte supprimé avec succès.';

  @override
  String get profileDeleteAccountError =>
      'Suppression impossible pour le moment. Réessaie plus tard.';

  @override
  String get profileChangeLanguage => 'Changer la langue';

  @override
  String profileDocCount(int count) {
    return '$count document(s)';
  }

  @override
  String get tabToday => 'Aujourd\'hui';

  @override
  String get tabDossier => 'Dossier';

  @override
  String get affordabilityInsightRevenueTitle =>
      'Ce qui te limite : ton revenu, pas tes fonds propres';

  @override
  String affordabilityInsightRevenueBody(
      String chargesTheoriques, String chargesReelles) {
    return 'Les banques suisses calculent avec un taux théorique de 5 % (directive ASB), même si le taux réel du marché est bien plus bas. C\'est un test de résistance : elles vérifient que tu pourrais assumer les charges si les taux remontaient. Tes charges théoriques : $chargesTheoriques/mois. Au taux réel (~1,5 %) : $chargesReelles/mois.';
  }

  @override
  String get affordabilityInsightEquityTitle =>
      'Ce qui te limite : tes fonds propres';

  @override
  String affordabilityInsightEquityBody(String manque) {
    return 'Il te manque environ CHF $manque de fonds propres pour atteindre le minimum de 20 % exigé par les banques.';
  }

  @override
  String get affordabilityInsightOkTitle =>
      'Bonne nouvelle : les deux critères sont remplis';

  @override
  String get affordabilityInsightOkBody =>
      'Ton revenu et tes fonds propres te permettent d\'accéder à ce bien. Pense à comparer les types d\'hypothèque et les stratégies d\'amortissement.';

  @override
  String affordabilityInsightLppCap(String lppUtilise, String lppTotal) {
    return 'Ton 2e pilier est plafonné : seuls CHF $lppUtilise sur $lppTotal sont comptés (max 10 % du prix, règle ASB).';
  }

  @override
  String get tabMint => 'Mint';

  @override
  String get pulseNarrativeRetirementClose =>
      'ta retraite approche. Chaque décision pèse un peu plus.';

  @override
  String pulseNarrativeYearsToAct(int yearsToRetire) {
    return 'tu as $yearsToRetire ans pour agir. Chaque année peut te rendre de l\'air.';
  }

  @override
  String get pulseNarrativeTimeToBuild =>
      'tu as le temps de construire. Autant lui donner une bonne forme.';

  @override
  String get pulseNarrativeDefault => 'tes chiffres commencent à parler.';

  @override
  String get pulseLabelReplacementRate => 'Part de train de vie conservée';

  @override
  String get pulseLabelRetirementIncome =>
      'Revenu mensuel possible à la retraite';

  @override
  String get pulseLabelFinancialScore => 'Degré de clarté de ta situation';

  @override
  String get exploreHubRetraiteTitle => 'Retraite';

  @override
  String get exploreHubRetraiteSubtitle => 'AVS, LPP, 3a, projections';

  @override
  String get exploreHubFamilleTitle => 'Famille';

  @override
  String get exploreHubFamilleSubtitle => 'Mariage, naissance, concubinage';

  @override
  String get exploreHubTravailTitle => 'Travail & Statut';

  @override
  String get exploreHubTravailSubtitle => 'Emploi, indépendant, frontalier';

  @override
  String get exploreHubLogementTitle => 'Logement';

  @override
  String get exploreHubLogementSubtitle => 'Hypothèque, achat, vente';

  @override
  String get exploreHubFiscaliteTitle => 'Fiscalité';

  @override
  String get exploreHubFiscaliteSubtitle => 'Impôts, comparateur cantonal';

  @override
  String get exploreHubPatrimoineTitle => 'Patrimoine & Succession';

  @override
  String get exploreHubPatrimoineSubtitle => 'Donation, héritage, allocation';

  @override
  String get exploreHubSanteTitle => 'Santé & Protection';

  @override
  String get exploreHubSanteSubtitle => 'LAMal, invalidité, couverture';

  @override
  String get dossierDocumentsTitle => 'Documents';

  @override
  String get dossierDocumentsSubtitle => 'Certificats, relevés, scans';

  @override
  String get dossierCoupleTitle => 'Couple';

  @override
  String get dossierCoupleSubtitle => 'Foyer, conjoint·e, projections duo';

  @override
  String get dossierBilanTitle => 'Bilan financier';

  @override
  String get dossierBilanSubtitle => 'Vue d\'ensemble de ton patrimoine';

  @override
  String get dossierReglages => 'Réglages';

  @override
  String get dossierConsentsTitle => 'Consentements';

  @override
  String get dossierConsentsSubtitle => 'Vie privée et partage de données';

  @override
  String get dossierAiTitle => 'IA & Coach';

  @override
  String get dossierAiSubtitle => 'Modèle local, clé API';

  @override
  String get dossierStartProfile => 'Commence ton profil';

  @override
  String dossierProfileCompleted(int percent) {
    return '$percent % complété';
  }

  @override
  String get exploreHubFeatured => 'Commencer par';

  @override
  String get exploreHubSeeAll => 'Tous les outils';

  @override
  String get exploreHubLearnMore => 'Lire l\'essentiel';

  @override
  String get retraiteHubFeaturedOverview => 'Aperçu retraite';

  @override
  String get retraiteHubFeaturedOverviewSub =>
      'Ton estimation personnalisée en 3 minutes';

  @override
  String get retraiteHubFeaturedRenteCapital => 'Rente vs Capital';

  @override
  String get retraiteHubFeaturedRenteCapitalSub =>
      'Compare les deux options côte à côte';

  @override
  String get retraiteHubFeaturedRachat => 'Rachat LPP';

  @override
  String get retraiteHubFeaturedRachatSub =>
      'Simule l\'impact fiscal d\'un rachat';

  @override
  String get retraiteHubToolPilier3a => 'Pilier 3a';

  @override
  String get retraiteHubTool3aComparateur => '3a Comparateur';

  @override
  String get retraiteHubTool3aRendement => '3a Rendement réel';

  @override
  String get retraiteHubTool3aRetrait => '3a Retrait échelonné';

  @override
  String get retraiteHubTool3aRetroactif => '3a Rétroactif';

  @override
  String get retraiteHubToolLibrePassage => 'Libre passage';

  @override
  String get retraiteHubToolDecaissement => 'Décaissement';

  @override
  String get retraiteHubToolEpl => 'EPL';

  @override
  String get familleHubFeaturedMariage => 'Mariage';

  @override
  String get familleHubFeaturedMariageSub =>
      'Impact sur tes impôts, AVS et prévoyance';

  @override
  String get familleHubFeaturedNaissance => 'Naissance';

  @override
  String get familleHubFeaturedNaissanceSub =>
      'Allocations, congé et ajustements financiers';

  @override
  String get familleHubFeaturedConcubinage => 'Concubinage';

  @override
  String get familleHubFeaturedConcubinageSub =>
      'Protéger ton couple sans mariage';

  @override
  String get familleHubToolDivorce => 'Divorce';

  @override
  String get familleHubToolDecesProche => 'Décès d\'un proche';

  @override
  String get travailHubFeaturedPremierEmploi => 'Premier emploi';

  @override
  String get travailHubFeaturedPremierEmploiSub =>
      'Tout ce qu\'il faut savoir pour bien démarrer';

  @override
  String get travailHubFeaturedChomage => 'Chômage';

  @override
  String get travailHubFeaturedChomageSub =>
      'Tes droits, indemnités et démarches';

  @override
  String get travailHubFeaturedIndependant => 'Indépendant';

  @override
  String get travailHubFeaturedIndependantSub =>
      'Prévoyance et fiscalité sur mesure';

  @override
  String get travailHubToolComparateurEmploi => 'Comparateur d\'emploi';

  @override
  String get travailHubToolFrontalier => 'Frontalier';

  @override
  String get travailHubToolExpatriation => 'Expatriation';

  @override
  String get travailHubToolGenderGap => 'Gender gap';

  @override
  String get travailHubToolAvsIndependant => 'AVS indépendant';

  @override
  String get travailHubToolIjm => 'IJM';

  @override
  String get travailHubTool3aIndependant => '3a indépendant';

  @override
  String get travailHubToolDividendeSalaire => 'Dividende vs Salaire';

  @override
  String get travailHubToolLppVolontaire => 'LPP volontaire';

  @override
  String get logementHubFeaturedCapacite => 'Capacité hypothécaire';

  @override
  String get logementHubFeaturedCapaciteSub => 'Combien peux-tu emprunter ?';

  @override
  String get logementHubFeaturedLocationPropriete => 'Location vs Propriété';

  @override
  String get logementHubFeaturedLocationProprieteSub =>
      'Compare les deux scénarios sur 20 ans';

  @override
  String get logementHubFeaturedVente => 'Vente immobilière';

  @override
  String get logementHubFeaturedVenteSub =>
      'Impôt sur le gain et réinvestissement';

  @override
  String get logementHubToolAmortissement => 'Amortissement';

  @override
  String get logementHubToolEplCombine => 'EPL combiné';

  @override
  String get logementHubToolValeurLocative => 'Valeur locative';

  @override
  String get logementHubToolSaronFixe => 'SARON vs Fixe';

  @override
  String get fiscaliteHubFeaturedComparateur => 'Comparateur fiscal';

  @override
  String get fiscaliteHubFeaturedComparateurSub =>
      'Estime ton impôt selon différents scénarios';

  @override
  String get fiscaliteHubFeaturedDemenagement => 'Déménagement cantonal';

  @override
  String get fiscaliteHubFeaturedDemenagementSub =>
      'Compare la fiscalité entre cantons';

  @override
  String get fiscaliteHubFeaturedAllocation => 'Allocation annuelle';

  @override
  String get fiscaliteHubFeaturedAllocationSub =>
      'Où placer ton épargne cette année ?';

  @override
  String get fiscaliteHubToolInteretsComposes => 'Intérêts composés';

  @override
  String get fiscaliteHubToolBilanArbitrage => 'Bilan arbitrage';

  @override
  String get patrimoineHubFeaturedSuccession => 'Succession';

  @override
  String get patrimoineHubFeaturedSuccessionSub =>
      'Anticipe la transmission de ton patrimoine';

  @override
  String get patrimoineHubFeaturedDonation => 'Donation';

  @override
  String get patrimoineHubFeaturedDonationSub =>
      'Fiscalité et impact sur ta prévoyance';

  @override
  String get patrimoineHubFeaturedRenteCapital => 'Rente vs Capital';

  @override
  String get patrimoineHubFeaturedRenteCapitalSub =>
      'Compare les deux options côte à côte';

  @override
  String get patrimoineHubToolBilan => 'Bilan financier';

  @override
  String get patrimoineHubToolPortfolio => 'Portfolio';

  @override
  String get santeHubFeaturedFranchise => 'Franchise LAMal';

  @override
  String get santeHubFeaturedFranchiseSub =>
      'Trouve la franchise qui te coûte le moins';

  @override
  String get santeHubFeaturedInvalidite => 'Invalidité';

  @override
  String get santeHubFeaturedInvaliditeSub =>
      'Estime ta couverture en cas d\'incapacité';

  @override
  String get santeHubFeaturedCheckup => 'Check-up couverture';

  @override
  String get santeHubFeaturedCheckupSub => 'Vérifie que tu es bien protégé·e';

  @override
  String get santeHubToolAssuranceInvalidite => 'Assurance invalidité';

  @override
  String get santeHubToolInvaliditeIndependant => 'Invalidité indépendant';

  @override
  String get dossierSlmTitle => 'IA embarquée';

  @override
  String get dossierSlmSubtitle => 'Tourne sur ton appareil, même hors ligne';

  @override
  String get dossierByokTitle => 'Clé IA perso';

  @override
  String get dossierByokSubtitle => 'Branche ton propre modèle IA';

  @override
  String get budgetErrorRetry => 'Le calcul a buté. Réessaie ?';

  @override
  String get budgetChiffreChocCaption =>
      'Soit ce qu\'il te reste après toutes tes charges fixes';

  @override
  String get budgetMethodTitle => 'Comprendre ce budget';

  @override
  String get budgetMethodBody =>
      'Ce budget sépare tes charges fixes (loyer, LAMal, impôts) de ton reste à vivre. La règle 50/30/20 suggère : 50 % pour les besoins, 30 % pour les envies, 20 % pour l\'épargne. C\'est un repère, pas une obligation.';

  @override
  String get budgetMethodSource =>
      'Source : méthode 50/30/20 (Elizabeth Warren, 2005)';

  @override
  String get budgetDisclaimerNote =>
      'Estimation éducative. Ne constitue pas un conseil financier (LSFin art. 3).';

  @override
  String get chiffreChocIfYouAct => 'Si tu agis';

  @override
  String get chiffreChocIfYouDontAct => 'Si tu ne fais rien';

  @override
  String get chiffreChocAvantApresGapAct =>
      'Un rachat LPP ou un 3a peut réduire cet écart de moitié.';

  @override
  String get chiffreChocAvantApresGapNoAct =>
      'L\'écart se creuse chaque année. À la retraite, il sera trop tard.';

  @override
  String get chiffreChocAvantApresLiquidityAct =>
      'Épargner 500 CHF/mois reconstitue 3 mois de réserve en 6 mois.';

  @override
  String get chiffreChocAvantApresLiquidityNoAct =>
      'Un imprévu sans réserve, c\'est un crédit à la consommation.';

  @override
  String get chiffreChocAvantApresTaxAct =>
      'Chaque année sans 3a, c\'est une économie d\'impôt perdue.';

  @override
  String get chiffreChocAvantApresTaxNoAct =>
      'Sans 3a, tu paies le taux plein et tu ne prépares pas ta retraite.';

  @override
  String get chiffreChocAvantApresIncomeAct =>
      'Quelques ajustements peuvent améliorer ta projection.';

  @override
  String get chiffreChocAvantApresIncomeNoAct =>
      'Ta situation actuelle reste stable, mais sans marge de progression.';

  @override
  String chiffreChocConfidenceSimple(String count) {
    return 'Basé sur $count données. Ajoutes-en pour affiner.';
  }

  @override
  String get quickStartTitle => 'Trois questions, un premier chiffre.';

  @override
  String get quickStartSubtitle => 'Le reste, c\'est toi qui décides quand.';

  @override
  String get quickStartFirstName => 'Ton prénom';

  @override
  String get quickStartFirstNameHint => 'Facultatif';

  @override
  String get quickStartAge => 'Ton âge';

  @override
  String quickStartAgeValue(String age) {
    return '$age ans';
  }

  @override
  String get quickStartSalary => 'Ton revenu brut annuel';

  @override
  String quickStartSalaryValue(String salary) {
    return '$salary/an';
  }

  @override
  String get quickStartNoIncome => 'Sans revenu';

  @override
  String get quickStartCanton => 'Canton';

  @override
  String get quickStartPreviewTitle => 'Premier aperçu retraite';

  @override
  String get quickStartVerdictGood => 'En bonne voie';

  @override
  String get quickStartVerdictWatch => 'À surveiller';

  @override
  String get quickStartVerdictGap => 'À traiter';

  @override
  String get quickStartToday => 'Aujourd\'hui';

  @override
  String get quickStartAtRetirement => 'À la retraite';

  @override
  String get quickStartPerMonth => '/mois';

  @override
  String quickStartDropPct(String pct, String gap) {
    return '-$pct % de pouvoir d\'achat ($gap/mois)';
  }

  @override
  String get quickStartDisclaimer =>
      'Estimation éducative. Pas un conseil financier (LSFin).';

  @override
  String get quickStartCta => 'Voir mon aperçu';

  @override
  String get quickStartSectionIdentity => 'Identité & Foyer';

  @override
  String get quickStartSectionIncome => 'Revenus & Épargne';

  @override
  String get quickStartSectionPension => 'Prévoyance (LPP)';

  @override
  String get quickStartSectionProperty => 'Immobilier & Dettes';

  @override
  String quickStartSectionGuidance(String label) {
    return 'Section : $label — mets à jour tes informations ci-dessous.';
  }

  @override
  String profileCompletionHint(int pct, String missing) {
    return '$pct % — il manque $missing';
  }

  @override
  String get profileMissingLpp => 'ton LPP';

  @override
  String get profileMissingIncome => 'tes revenus';

  @override
  String get profileMissingProperty => 'ton immobilier';

  @override
  String get profileMissingIdentity => 'ton identité';

  @override
  String get profileMissingAnd => ' et ';

  @override
  String profileAnnualRefreshDays(int days) {
    return 'Dernière mise à jour il y a $days jours';
  }

  @override
  String get chiffreChocBack => 'Retour';

  @override
  String get chiffreChocShowComparison => 'Afficher la comparaison';

  @override
  String get chiffreChocHideComparison => 'Masquer la comparaison';

  @override
  String get dashboardNextActionsTitle => 'Tes prochaines actions';

  @override
  String get dashboardExploreAlsoTitle => 'Explorer aussi';

  @override
  String get dashboardImproveAccuracyTitle => 'Améliore ta précision';

  @override
  String dashboardCurrentConfidence(int score) {
    return 'Confiance actuelle : $score%';
  }

  @override
  String dashboardPrecisionPtsGain(int pts) {
    return '+$pts pts de précision';
  }

  @override
  String get dashboardOnboardingHeroTitle => 'Ta retraite en un coup d’œil';

  @override
  String get dashboardOnboardingCta => 'Commencer — 2 min';

  @override
  String get dashboardOnboardingConsent =>
      'Aucune donnée stockée sans ton accord.';

  @override
  String get dashboardEducationTitle =>
      'Comment fonctionne la retraite en Suisse ?';

  @override
  String get dashboardEducationSubtitle =>
      'AVS, LPP, 3a — les bases en 5 minutes';

  @override
  String get dashboardCockpitTitle => 'Cockpit de détail';

  @override
  String get dashboardCockpitSubtitle => 'Décomposition par pilier';

  @override
  String get dashboardCockpitCta => 'Ouvrir';

  @override
  String get dashboardRenteVsCapitalTitle => 'Rente vs Capital';

  @override
  String get dashboardRenteVsCapitalSubtitle => 'Explorer le point d’équilibre';

  @override
  String get dashboardRenteVsCapitalCta => 'Simuler';

  @override
  String get dashboardRachatLppTitle => 'Rachat LPP';

  @override
  String get dashboardRachatLppSubtitle => 'Simuler l’impact fiscal';

  @override
  String get dashboardRachatLppCta => 'Calculer';

  @override
  String dashboardPrecisionGainPercent(int percent) {
    return 'Précision +$percent%';
  }

  @override
  String dashboardImpactChf(String amount) {
    return '+CHF $amount';
  }

  @override
  String dashboardDeadlineDays(int days) {
    return 'J-$days';
  }

  @override
  String dashboardBannerDeadline(String title, int days) {
    return '$title — J-$days';
  }

  @override
  String get dashboardOneLinerGoodTrack =>
      'Tu es en bonne voie pour maintenir ton niveau de vie.';

  @override
  String get dashboardOneLinerLevers =>
      'Des leviers existent pour améliorer ta projection.';

  @override
  String get dashboardOneLinerEveryAction =>
      'Chaque action compte — explore les pistes disponibles.';

  @override
  String get profileFamilyCouple => 'En couple';

  @override
  String get profileFamilySingle => 'Seul·e';

  @override
  String get renteVsCapitalErrorRetry =>
      'Le calcul a buté. Réessaie plus tard.';

  @override
  String get rachatEchelonneTitle => 'Rachat LPP échelonné';

  @override
  String get rachatEchelonneIntroTitle => 'Pourquoi échelonner ses rachats ?';

  @override
  String get rachatEchelonneIntroBody =>
      'L\'impôt suisse étant progressif, répartir un rachat LPP sur plusieurs années permet de rester dans des tranches marginales plus élevées chaque année, maximisant ainsi l\'économie fiscale totale. Ce simulateur compare les deux approches.';

  @override
  String get rachatEchelonneSavingsCaption =>
      'd\'économie supplémentaire en échelonnant';

  @override
  String get rachatEchelonneBlocBetter =>
      'Rachat en bloc plus avantageux dans ce cas';

  @override
  String get rachatEchelonneSituationLpp => 'Situation LPP';

  @override
  String get rachatEchelonneAvoirActuel => 'Avoir actuel LPP';

  @override
  String get rachatEchelonneRachatMax => 'Rachat maximum';

  @override
  String get rachatEchelonneSituationFiscale => 'Situation fiscale';

  @override
  String get rachatEchelonneCanton => 'Canton';

  @override
  String get rachatEchelonneEtatCivil => 'État civil';

  @override
  String get rachatEchelonneCelibataire => 'Célibataire';

  @override
  String get rachatEchelonneMarieE => 'Marié·e';

  @override
  String get rachatEchelonneRevenuImposable => 'Revenu imposable';

  @override
  String get rachatEchelonneTauxMarginal => 'Taux marginal estimé';

  @override
  String get rachatEchelonneTauxManuel => 'Valeur ajustée manuellement';

  @override
  String get rachatEchelonneAjuster => 'Ajuster';

  @override
  String get rachatEchelonneAuto => 'Auto';

  @override
  String get rachatEchelonneStrategie => 'Stratégie';

  @override
  String get rachatEchelonneHorizon => 'Horizon (années)';

  @override
  String get rachatEchelonneComparaison => 'Comparaison';

  @override
  String get rachatEchelonneBlocTitle => 'Tout en 1 an';

  @override
  String get rachatEchelonneBlocSubtitle => 'Rachat bloc';

  @override
  String get rachatEchelonneEchelonneSubtitle => 'Rachat réparti';

  @override
  String get rachatEchelonnePlusAdapte => 'Le plus adapté';

  @override
  String get rachatEchelonneEconomieFiscale => 'Économie fiscale';

  @override
  String get rachatEchelonneImpactTranche => 'Impact par tranche fiscale';

  @override
  String get rachatEchelonneImpactBlocExplain =>
      'En bloc, la déduction traverse plusieurs tranches (taux moyen plus bas). En échelonnant, chaque déduction reste dans la tranche la plus haute.';

  @override
  String get rachatEchelonneBloc => 'Bloc';

  @override
  String get rachatEchelonneEchelonne => 'Échelonné';

  @override
  String get rachatEchelonnePlanAnnuel => 'Plan annuel';

  @override
  String get rachatEchelonneTotal => 'Total';

  @override
  String get rachatEchelonneRachat => 'Rachat';

  @override
  String get rachatEchelonneBlockageTitle => 'LPP art. 79b al. 3 — Blocage EPL';

  @override
  String get rachatEchelonneBlockageBody =>
      'Après chaque rachat, tout retrait EPL (encouragement à la propriété du logement) est bloqué pendant 3 ans. Planifie en conséquence si un achat immobilier est prévu.';

  @override
  String get rachatEchelonneTauxMarginalTitle => 'Taux marginal d\'imposition';

  @override
  String get rachatEchelonneTauxMarginalBody =>
      'Le taux marginal est le pourcentage d\'impôt sur ton dernier franc gagné. Avec un taux de 32 %, chaque CHF 1\'000 déduit te fait économiser CHF 320. Plus ton revenu est élevé, plus ce taux augmente (progressivité de l\'impôt suisse).';

  @override
  String get rachatEchelonneTauxMarginalTip =>
      'C\'est pour ça qu\'échelonner tes rachats est malin : chaque tranche reste dans un taux marginal élevé.';

  @override
  String get rachatEchelonneTauxMarginalSemantics =>
      'Information sur le taux marginal';

  @override
  String get staggered3aTitle => 'Retrait 3a échelonné';

  @override
  String get staggered3aEconomie => 'Économie estimée';

  @override
  String get staggered3aIntroTitle => 'Pourquoi échelonner les retraits 3a ?';

  @override
  String get staggered3aIntroBody =>
      'L\'impôt sur le retrait en capital de prévoyance est progressif. En répartissant tes avoirs 3a sur plusieurs comptes et en les retirant sur différentes années fiscales, tu réduis le taux moyen d\'imposition. La loi autorise jusqu\'à 5 comptes 3a par personne (OPP3). Depuis la réforme AHV21 (2024), les retraits anticipés sont possibles dès l\'âge de 60 ans.';

  @override
  String get staggered3aParametres => 'Paramètres';

  @override
  String get staggered3aAvoirTotal => 'Avoir 3a total';

  @override
  String get staggered3aNbComptes => 'Nombre de comptes 3a';

  @override
  String get staggered3aCanton => 'Canton';

  @override
  String get staggered3aRevenuImposable => 'Revenu imposable';

  @override
  String get staggered3aAgeDebut => 'Âge début retraits';

  @override
  String get staggered3aAgeFin => 'Âge dernier retrait';

  @override
  String get staggered3aResultat => 'Résultat';

  @override
  String get staggered3aEnBloc => 'En bloc';

  @override
  String get staggered3aRetraitUnique => 'Retrait unique';

  @override
  String get staggered3aEchelonneLabel => 'Échelonné';

  @override
  String get staggered3aImpotEstime => 'Impôt estimé';

  @override
  String get staggered3aPlanAnnuel => 'Plan annuel';

  @override
  String get staggered3aAge => 'Âge';

  @override
  String get staggered3aRetrait => 'Retrait';

  @override
  String get staggered3aImpot => 'Impôt';

  @override
  String get staggered3aNet => 'Net';

  @override
  String get staggered3aTotal => 'Total';

  @override
  String get staggered3aAns => 'ans';

  @override
  String get optimDecaissementTitle => 'Ordre de retrait 3a';

  @override
  String get optimDecaissementChiffre => '+CHF 3\'500';

  @override
  String get optimDecaissementChiffreExplication =>
      'C\'est l\'impôt supplémentaire payé quand on retire 2 comptes 3a la même année plutôt que de les étaler sur 2 ans fiscales différentes — selon LIFD art. 38.';

  @override
  String get optimDecaissementPrincipe => 'Le principe de l\'échelonnement';

  @override
  String get optimDecaissementInfo1Title => '1 compte 3a par année fiscale';

  @override
  String get optimDecaissementInfo1Body =>
      'Le retrait du 3a est imposé séparément du revenu ordinaire (LIFD art. 38), mais le taux augmente avec le montant retiré. En fractionnant sur plusieurs années, chaque retrait reste dans une tranche basse.';

  @override
  String get optimDecaissementInfo2Title => 'Jusqu\'à 10 comptes 3a simultanés';

  @override
  String get optimDecaissementInfo2Body =>
      'Depuis 2026, tu peux détenir plusieurs comptes 3a simultanément (révision OPP3 2026). En les ouvrant progressivement, tu peux échelonner les retraits sur 3 à 10 ans selon ton plan.';

  @override
  String get optimDecaissementInfo3Title => 'La fiscalité varie par canton';

  @override
  String get optimDecaissementInfo3Body =>
      'Plusieurs cantons offrent des abattements supplémentaires. Le choix du canton de résidence au moment du retrait influence directement l\'imposition.';

  @override
  String get optimDecaissementIllustration =>
      'Illustration : CHF 150\'000 en 3a';

  @override
  String get optimDecaissementTableSpread => 'Étalement';

  @override
  String get optimDecaissementTableAmount => 'Montant/retrait';

  @override
  String get optimDecaissementTableTax => 'Impôt est.*';

  @override
  String get optimDecaissementTableRow1Spread => '1 an';

  @override
  String get optimDecaissementTableRow1Amount => 'CHF 150\'000';

  @override
  String get optimDecaissementTableRow1Tax => '~CHF 12\'500';

  @override
  String get optimDecaissementTableRow2Spread => '3 ans';

  @override
  String get optimDecaissementTableRow2Amount => 'CHF 50\'000/an';

  @override
  String get optimDecaissementTableRow2Tax => '~CHF 3\'200/an';

  @override
  String get optimDecaissementTableRow3Spread => '5 ans';

  @override
  String get optimDecaissementTableRow3Amount => 'CHF 30\'000/an';

  @override
  String get optimDecaissementTableRow3Tax => '~CHF 1\'700/an';

  @override
  String get optimDecaissementTableFootnote =>
      '* Estimations indicatives basées sur un taux cantonal moyen (ZH). Varie selon le canton et la situation fiscale individuelle.';

  @override
  String get optimDecaissementPlanTitle => 'Comment planifier ton décaissement';

  @override
  String get optimDecaissementStep1Title => 'Inventaire de tes comptes 3a';

  @override
  String get optimDecaissementStep1Body =>
      'Liste chaque compte 3a avec son solde et son établissement. Note les années prévues de retraite pour chaque retrait.';

  @override
  String get optimDecaissementStep2Title =>
      'Simule l\'impact fiscal par scénario';

  @override
  String get optimDecaissementStep2Body =>
      'Compare : tout retirer en 1 an vs. étaler sur 3, 5 ou 7 ans. L\'écart peut représenter plusieurs milliers de francs.';

  @override
  String get optimDecaissementStep3Title => 'Coordonne avec ta retraite LPP';

  @override
  String get optimDecaissementStep3Body =>
      'Attendre 1 à 2 ans après le retrait du capital LPP pour le premier 3a réduit la charge fiscale totale sur l\'année de départ.';

  @override
  String get optimDecaissementSpecialisteTitle => 'Consulter un·e spécialiste';

  @override
  String get optimDecaissementSpecialisteBody =>
      'Un·e spécialiste en prévoyance peut modéliser ton plan de décaissement précis selon ta situation.';

  @override
  String get optimDecaissementSources =>
      '• LIFD art. 38 — Imposition séparée des prestations en capital\n• OPP3 art. 3 — Conditions de retrait anticipé du pilier 3a\n• OPP3 art. 7 — Plafonds de déduction\n• OPP3 (révision 2026) — Possibilité de détenir plusieurs comptes 3a';

  @override
  String get optimDecaissementDisclaimer =>
      'Information à caractère éducatif, ne constitue pas un conseil fiscal au sens de la LSFin.';

  @override
  String get successionAlertTitle =>
      'Sans testament, ton concubin·e hérite de rien';

  @override
  String get successionAlertBody =>
      'Le droit successoral suisse (CC art. 457 ss) protège d\'abord les descendants, puis les parents et le conjoint·e légal·e. Sans lien légal et sans testament, un·e concubin·e est exclu·e de la succession.';

  @override
  String get successionNotionsCles => 'Les notions clés';

  @override
  String get successionReservesBody =>
      'Une part de ta succession est réservée par la loi à tes descendants et à ton conjoint·e. Cette part ne peut pas être écartée par testament.';

  @override
  String get successionQuotiteSubtitle => 'CC art. 470 al. 2';

  @override
  String get successionQuotiteBody =>
      'Ce qui reste après les réserves héréditaires est ta quotité disponible — la part que tu peux léguer librement.';

  @override
  String get successionTestamentBody =>
      'Deux formes valides : olographe (manuscrit) ou notarié (devant notaire). Pas de testament = succession légale par défaut.';

  @override
  String get successionDonationTitle => 'Donation du vivant';

  @override
  String get successionDonationSubtitle => 'CO art. 239 ss';

  @override
  String get successionDonationBody =>
      'Transmettre de ton vivant permet d\'anticiper la succession et de réduire potentiellement l\'impôt successoral.';

  @override
  String get successionBeneficiairesTitle => 'Bénéficiaires LPP et 3a';

  @override
  String get successionBeneficiairesSubtitle => 'LPP art. 20 · OPP3 art. 2';

  @override
  String get successionBeneficiairesBody =>
      'Le capital LPP et le solde 3a ne font pas partie de ta succession ordinaire — ils sont versés aux bénéficiaires désignés.';

  @override
  String get successionDecesProche => 'En cas de décès d\'un proche';

  @override
  String get successionCheck1 =>
      'Vérifier la désignation des bénéficiaires sur chaque compte 3a';

  @override
  String get successionCheck2 =>
      'Vérifier la désignation de bénéficiaire LPP auprès de ta caisse';

  @override
  String get successionCheck3 => 'Rédiger ou mettre à jour ton testament';

  @override
  String get successionCheck4 =>
      'Vérifier ton régime matrimonial si marié·e (CC art. 181 ss)';

  @override
  String get successionCheck5 =>
      'Informer tes proches de l\'emplacement de ton testament';

  @override
  String get successionSpecialisteTitle =>
      'Consulter un·e notaire ou spécialiste';

  @override
  String get successionSpecialisteBody =>
      'Un·e notaire ou spécialiste en droit successoral peut rédiger ou réviser ton testament.';

  @override
  String get successionSources =>
      '• CC art. 457–640 — Droit des successions\n• CC art. 470–471 — Réserves héréditaires\n• CC art. 498–504 — Formes du testament\n• LPP art. 20 — Bénéficiaires du capital LPP\n• OPP3 art. 2 — Bénéficiaires du pilier 3a';

  @override
  String naissanceAllocForCanton(String canton, int count, String plural) {
    return 'Allocations familiales à $canton pour $count enfant$plural';
  }

  @override
  String naissanceAllocContextNote(String canton, int count, String plural) {
    return '($canton, $count enfant$plural)';
  }

  @override
  String get affordabilityEmotionalPositif => 'Tu peux te l\'offrir';

  @override
  String get affordabilityEmotionalNegatif => 'Il te manque un bout du puzzle';

  @override
  String get affordabilityExploreAlso => 'Explorer aussi';

  @override
  String get affordabilityRelatedAmortTitle =>
      'Amortissement direct vs indirect';

  @override
  String get affordabilityRelatedAmortSubtitle =>
      'Impact fiscal de chaque stratégie';

  @override
  String get affordabilityRelatedSaronTitle => 'SARON vs taux fixe';

  @override
  String get affordabilityRelatedSaronSubtitle =>
      'Comparer les types d\'hypothèque';

  @override
  String get affordabilityRelatedValeurTitle => 'Valeur locative';

  @override
  String get affordabilityRelatedValeurSubtitle =>
      'Comprendre l\'imposition du logement';

  @override
  String get affordabilityRelatedEplTitle => 'EPL — Utiliser mon 2e pilier';

  @override
  String get affordabilityRelatedEplSubtitle =>
      'Retrait anticipé pour l\'achat';

  @override
  String get affordabilityRelatedSimulate => 'Simuler';

  @override
  String get affordabilityRelatedCompare => 'Comparer';

  @override
  String get affordabilityRelatedCalculate => 'Calculer';

  @override
  String get affordabilityAdvancedParams => 'Plus d\'hypothèses';

  @override
  String get demenagementTitreV2 => 'Déménager, ça rapporte combien ?';

  @override
  String get demenagementCtaOptimal => 'Trouver le canton adapté';

  @override
  String demenagementInsightPositif(String mois) {
    return 'Ce déménagement te fait gagner du pouvoir d\'achat. L\'économie couvre environ $mois mois de loyer moyen.';
  }

  @override
  String get demenagementInsightNegatif =>
      'Ce déménagement te coûte. Vérifie que le cadre de vie compense la différence.';

  @override
  String get demenagementBilanTotal => 'Bilan total (impôts + LAMal)';

  @override
  String divorceTransfertAmount(String amount, String direction) {
    return 'Transfert de $amount ($direction)';
  }

  @override
  String divorceFiscalDelta(String sign, String amount) {
    return 'Différence : $sign$amount/an';
  }

  @override
  String divorcePensionMois(String amount) {
    return '$amount/mois';
  }

  @override
  String divorcePensionAnnuel(String amount) {
    return 'soit $amount/an';
  }

  @override
  String get divorceConjoint1Label => 'Conjoint 1';

  @override
  String get divorceConjoint2Label => 'Conjoint 2';

  @override
  String get divorceSplitC1 => 'C1';

  @override
  String get divorceSplitC2 => 'C2';

  @override
  String get unemploymentVague1Label => 'Vague 1 · L\'urgence administrative';

  @override
  String get unemploymentVague1Text =>
      'Inscription ORP dans les 5 premiers jours. Sinon : perte d\'indemnités. Chaque jour de retard = indemnité perdue.';

  @override
  String get unemploymentVague2Label => 'Vague 2 · Le budget à ajuster';

  @override
  String get unemploymentVague2Text =>
      'Chute immédiate de revenus. L\'AC ne couvre ni les jours fériés ni le délai de carence (5–20 jours). Revois ton budget dès J+1.';

  @override
  String get unemploymentVague3Label => 'Vague 3 · Les décisions cachées';

  @override
  String get unemploymentVague3Text =>
      'Dans les 30 jours : transférer ton LPP (sinon institution supplétive). Avant le mois suivant : suspendre le 3a, revoir LAMal.';

  @override
  String get unemploymentBudgetLoyer => 'Loyer';

  @override
  String get unemploymentBudgetLamal => 'LAMal';

  @override
  String get unemploymentBudgetTransport => 'Transport';

  @override
  String get unemploymentBudgetLoisirs => 'Loisirs';

  @override
  String get unemploymentBudgetEpargne3a => 'Épargne 3a';

  @override
  String get unemploymentGainMin => 'CHF 0';

  @override
  String get unemploymentGainMax => 'CHF 12\'350';

  @override
  String get unemploymentBracket1 => '12–17 mois cotis.';

  @override
  String get unemploymentBracket1Value => '200 indemnités';

  @override
  String get unemploymentBracket2 => '18–21 mois cotis.';

  @override
  String get unemploymentBracket2Value => '260 indemnités';

  @override
  String unemploymentBracket3(int age) {
    return '>= 22 mois, < $age ans';
  }

  @override
  String get unemploymentBracket3Value => '400 indemnités';

  @override
  String unemploymentBracket4(int age) {
    return '>= 22 mois, >= $age ans';
  }

  @override
  String get unemploymentBracket4Value => '520 indemnités';

  @override
  String get allocAnnuelleTitle => 'Où placer tes CHF ?';

  @override
  String get allocAnnuelleBudgetTitle => 'Ton budget annuel';

  @override
  String get allocAnnuelleMontantLabel => 'Montant disponible par an (CHF)';

  @override
  String get allocAnnuelleTauxMarginal => 'Taux marginal d\'imposition estimé';

  @override
  String get allocAnnuelleAnneesRetraite => 'Années avant la retraite';

  @override
  String allocAnnuelleAnneesValue(int years) {
    return '$years ans';
  }

  @override
  String get allocAnnuelle3aMaxed => '3a déjà au maximum';

  @override
  String get allocAnnuelleRachatLpp => 'Potentiel de rachat LPP';

  @override
  String get allocAnnuelleRachatMontant => 'Montant de rachat possible (CHF)';

  @override
  String get allocAnnuelleProprietaire => 'Propriétaire immobilier';

  @override
  String get allocAnnuelleComparer => 'Comparer les stratégies';

  @override
  String get allocAnnuelleTrajectoires => 'Trajectoires comparées';

  @override
  String get allocAnnuelleGraphHint =>
      'Touche le graphique pour voir les valeurs à chaque année.';

  @override
  String get allocAnnuelleValeurTerminale => 'Valeur terminale estimée';

  @override
  String allocAnnuelleApresAnnees(int years) {
    return 'Après $years ans';
  }

  @override
  String get allocAnnuelleHypotheses => 'Hypothèses utilisées';

  @override
  String get allocAnnuelleRendementMarche => 'Rendement marché';

  @override
  String get allocAnnuelleRendementLpp => 'Rendement LPP';

  @override
  String get allocAnnuelleRendement3a => 'Rendement 3a';

  @override
  String get allocAnnuelleAvertissement => 'Avertissement';

  @override
  String allocAnnuelleSources(String sources) {
    return 'Sources : $sources';
  }

  @override
  String get allocAnnuellePreRempli => 'Valeurs pré-remplies depuis ton profil';

  @override
  String get allocAnnuelleEncouragement =>
      'Chaque franc placé intelligemment travaille pour toi. Compare les options et choisis en connaissance de cause.';

  @override
  String get expatTab2EduInsert =>
      'La Suisse ne prélève pas de taxe de sortie (exit tax) — contrairement aux États-Unis ou à la France. Tes gains en capital latents ne sont pas imposés au moment du départ. C\'est un avantage majeur pour les expatriés.';

  @override
  String get expatTimelineToday => 'Aujourd\'hui';

  @override
  String get expatTimelineTodayDesc => 'Commence à planifier';

  @override
  String get expatTimelineTodayTiming => 'Maintenant';

  @override
  String get expatTimeline2to3Months => '2-3 mois avant';

  @override
  String get expatTimeline2to3MonthsDesc =>
      'Annoncer à la commune, résilier LAMal';

  @override
  String expatTimeline2to3MonthsTiming(int months) {
    return 'Dans ~$months mois';
  }

  @override
  String get expatTimeline1Month => '1 mois avant';

  @override
  String get expatTimeline1MonthDesc => 'Retirer 3a, transférer LPP';

  @override
  String expatTimeline1MonthTiming(int months) {
    return 'Dans ~$months mois';
  }

  @override
  String get expatTimelineDDay => 'Jour J';

  @override
  String get expatTimelineDDayDesc => 'Départ effectif';

  @override
  String expatTimelineDDayTiming(int days) {
    return 'Dans $days jours';
  }

  @override
  String get expatTimeline30After => '30 jours après';

  @override
  String get expatTimeline30AfterDesc => 'Déclarer impôts prorata temporis';

  @override
  String get expatTimeline30AfterTiming => 'Après le départ';

  @override
  String get expatTimelineUrgent => 'Urgent !';

  @override
  String get expatTimelinePassed => 'Passé';

  @override
  String expatSavingsBadge(String amount, String percent) {
    return 'Économie : $amount (-$percent%)';
  }

  @override
  String expatForfaitMoreCostly(String amount) {
    return 'Forfait plus coûteux : +$amount';
  }

  @override
  String expatForfaitBase(String amount) {
    return 'Base : $amount';
  }

  @override
  String expatAvsReductionExplain(String percent) {
    return 'Chaque année manquante réduit ta rente d\'environ $percent%. La réduction est définitive et s\'applique à vie.';
  }

  @override
  String expatAvsChiffreChoc(String amount) {
    return '-$amount/an sur ta rente AVS';
  }

  @override
  String expatDepartChiffreChoc(String amount) {
    return '$amount de capital à sécuriser avant ton départ';
  }

  @override
  String get independantCoveredLabel => 'Couvert';

  @override
  String get independantCriticalLabel => 'Non couvert — critique';

  @override
  String get independantHighLabel => 'Non couvert';

  @override
  String get independantLowLabel => 'Non couvert';

  @override
  String fiscalIncomeInfoLabel(String income, String status, String children) {
    return 'Revenu : $income | $status$children';
  }

  @override
  String get fiscalStatusMarried => 'Marié·e';

  @override
  String get fiscalStatusSingle => 'Célibataire';

  @override
  String fiscalChildrenSuffix(int count) {
    return ' + $count enfant(s)';
  }

  @override
  String get fiscalPerMonth => '/mois';

  @override
  String get sim3aTitle => 'Ton 3e pilier';

  @override
  String get sim3aExportTooltip => 'Exporter mon bilan';

  @override
  String get sim3aCoachTitle => 'Le conseil du Mentor';

  @override
  String get sim3aCoachBody =>
      'Le 3a est l\'un des outils les plus efficaces d\'optimisation en Suisse. L\'économie fiscale immédiate est un avantage concret.';

  @override
  String get sim3aParamsHeader => 'Tes paramètres';

  @override
  String get sim3aAnnualContribution => 'Versement annuel';

  @override
  String get sim3aAnnualContributionIndep =>
      'Versement annuel (indép. sans LPP)';

  @override
  String get sim3aMarginalRate => 'Taux marginal d\'imposition';

  @override
  String get sim3aYearsToRetirement => 'Années jusqu\'à la retraite';

  @override
  String get sim3aExpectedReturn => 'Rendement annuel espéré';

  @override
  String sim3aYearsSuffix(int count) {
    return '$count ans';
  }

  @override
  String get sim3aAnnualTaxSaved => 'Gain fiscal annuel';

  @override
  String get sim3aFinalCapital => 'Capital au terme';

  @override
  String get sim3aCumulativeTaxSaved => 'Économie fiscale cumulée';

  @override
  String get sim3aStrategyHeader => 'Stratégie gagnante';

  @override
  String get sim3aStratBankTitle => 'Bancaire > Assurance';

  @override
  String get sim3aStratBankBody =>
      'Évite les contrats d\'assurance liés. Reste flexible avec un 3a bancaire investi.';

  @override
  String get sim3aStrat5AccountsTitle => 'La règle des 5 comptes';

  @override
  String get sim3aStrat5AccountsBody =>
      'Ouvre plusieurs comptes pour retirer de manière échelonnée et réduire la progression fiscale au retrait.';

  @override
  String get sim3aStrat100ActionsTitle => '100 % Actions';

  @override
  String get sim3aStrat100ActionsBody =>
      'Si ta retraite est dans plus de 15 ans, une stratégie actions pourrait maximiser ton capital.';

  @override
  String get sim3aExploreAlso => 'Explorer aussi';

  @override
  String get sim3aProviderComparator => 'Comparateur prestataires';

  @override
  String get sim3aProviderComparatorSub => 'VIAC, Finpension, frankly...';

  @override
  String get sim3aRealReturn => 'Rendement réel';

  @override
  String get sim3aRealReturnSub => 'Après frais, inflation et fiscal';

  @override
  String get sim3aStaggeredWithdrawal => 'Retrait échelonné';

  @override
  String get sim3aStaggeredWithdrawalSub =>
      'Étaler les retraits pour réduire l\'impôt';

  @override
  String get sim3aCtaCompare => 'Comparer';

  @override
  String get sim3aCtaCalculate => 'Calculer';

  @override
  String get sim3aCtaPlan => 'Planifier';

  @override
  String get sim3aDisclaimer =>
      'Estimation éducative. Les économies réelles dépendent de ton lieu de résidence et de ta situation familiale. Ne constitue pas un conseil financier (LSFin).';

  @override
  String get sim3aDebtLockedTitle => 'Priorité au désendettement';

  @override
  String get sim3aDebtLockedMessage =>
      'En mode protection, les recommandations d\'action 3a sont désactivées. La priorité est de stabiliser ta situation financière avant de verser dans le 3a.';

  @override
  String get sim3aDebtStrategyTitle => 'Stratégie bloquée';

  @override
  String get sim3aDebtStrategyMessage =>
      'Les stratégies d\'investissement 3a sont désactivées tant que tu as des dettes actives. Rembourser tes dettes est un rendement plus élevé que tout placement.';

  @override
  String get realReturnTitle => 'Rendement réel 3a';

  @override
  String get realReturnChiffreChocLabel => 'Taux équivalent sur effort net';

  @override
  String realReturnVsNominal(String rate) {
    return 'vs $rate % taux net 3a (brut − frais)';
  }

  @override
  String realReturnEffortNet(String amount, String pts) {
    return 'Effort net : $amount/an | Prime fiscale implicite : +$pts pts';
  }

  @override
  String get realReturnParams => 'Paramètres';

  @override
  String get realReturnAnnualPayment => 'Versement annuel';

  @override
  String get realReturnMarginalRate => 'Taux marginal';

  @override
  String get realReturnGrossReturn => 'Rendement brut';

  @override
  String get realReturnMgmtFees => 'Frais de gestion';

  @override
  String get realReturnDuration => 'Durée de placement';

  @override
  String realReturnYearsSuffix(int count) {
    return '$count ans';
  }

  @override
  String get realReturnCompared => 'Rendements comparés';

  @override
  String get realReturnNominal3a => 'Rendement nominal 3a';

  @override
  String get realReturnRealWithFiscal => 'Rendement réel (avec fiscal)';

  @override
  String get realReturnEquivNote =>
      'Ce taux est un taux équivalent : il ne représente pas un rendement de marché attendu.';

  @override
  String get realReturnSavingsAccount => 'Rendement compte épargne';

  @override
  String realReturnFinalCapital(int years) {
    return 'Capital final après $years ans';
  }

  @override
  String get realReturn3aFintech => '3a Fintech + fiscal';

  @override
  String get realReturnSavings15 => 'Compte épargne 1,5 %';

  @override
  String realReturnGainVsSavings(String amount) {
    return 'Gain vs épargne classique : CHF $amount';
  }

  @override
  String get realReturnFiscalDetail => 'Détail économie fiscale';

  @override
  String get realReturnTotalPayments => 'Total versements';

  @override
  String get realReturnFinalCapital3a => 'Capital final 3a (hors fiscal)';

  @override
  String get realReturnCumulativeFiscal => 'Économie fiscale cumulée';

  @override
  String get realReturnTotalWithFiscal => 'Total avec avantage fiscal';

  @override
  String realReturnAhaMoment(String netAmount) {
    return 'Ton effort réel : $netAmount/an. Le fisc finance la différence — c\'est un levier rare en Suisse.';
  }

  @override
  String get realReturnPerYear => '/ an';

  @override
  String get genderGapAppBarTitle => 'Lacune de prévoyance';

  @override
  String get genderGapHeaderTitle => 'Lacune de prévoyance';

  @override
  String get genderGapHeaderSubtitle =>
      'Impact du temps partiel sur la retraite';

  @override
  String get genderGapIntro =>
      'La déduction de coordination (CHF 26\'460) n\'est pas proratisée pour le temps partiel, ce qui pénalise davantage les personnes travaillant à temps réduit. Déplace le curseur pour voir l\'impact.';

  @override
  String get genderGapTauxActivite => 'Taux d\'activité';

  @override
  String get genderGapParametres => 'Paramètres';

  @override
  String get genderGapRevenuAnnuel => 'Revenu annuel brut (100%)';

  @override
  String get genderGapAge => 'Âge';

  @override
  String genderGapAgeValue(String age) {
    return '$age ans';
  }

  @override
  String get genderGapAvoirLpp => 'Avoir LPP actuel';

  @override
  String get genderGapAnneesCotisation => 'Années de cotisation';

  @override
  String get genderGapCanton => 'Canton';

  @override
  String get genderGapDemoMode =>
      'Mode démo : profil exemple. Complète ton diagnostic pour des résultats personnalisés.';

  @override
  String get genderGapRenteLppEstimee => 'Rente LPP estimée';

  @override
  String genderGapProjection(String annees) {
    return 'Projection à $annees ans (âge 65)';
  }

  @override
  String get genderGapAt100 => 'À 100%';

  @override
  String genderGapAtTaux(String taux) {
    return 'À $taux%';
  }

  @override
  String get genderGapPerYear => '/an';

  @override
  String get genderGapLacuneAnnuelle => 'Lacune annuelle';

  @override
  String get genderGapLacuneTotale => 'Lacune totale (~20 ans)';

  @override
  String get genderGapCoordinationTitle =>
      'Comprendre la déduction de coordination';

  @override
  String get genderGapCoordinationBody =>
      'La déduction de coordination est un montant fixe de CHF 26\'460 soustrait de ton salaire brut pour calculer le salaire coordonné (base LPP). Ce montant est le même que tu travailles à 100% ou à 50%.';

  @override
  String get genderGapSalaireBrut100 => 'Salaire brut à 100%';

  @override
  String get genderGapSalaireCoordonne100 => 'Salaire coordonné à 100%';

  @override
  String genderGapSalaireBrutTaux(String taux) {
    return 'Salaire brut à $taux%';
  }

  @override
  String genderGapSalaireCoordonneTaux(String taux) {
    return 'Salaire coordonné à $taux%';
  }

  @override
  String get genderGapDeductionFixe => 'Déduction coordination (fixe)';

  @override
  String get genderGapSourceCoordination => 'Source : LPP art. 8, OPP2 art. 5';

  @override
  String get genderGapStatOfsTitle => 'Statistique OFS';

  @override
  String get genderGapRecommandations => 'Recommandations';

  @override
  String get genderGapDisclaimer =>
      'Les résultats présentés sont des estimations simplifiées à titre indicatif. Ils ne constituent pas un conseil financier personnalisé. Consulte ta caisse de pension et un·e spécialiste qualifié·e avant toute décision.';

  @override
  String get genderGapSources => 'Sources';

  @override
  String get genderGapSourcesBody =>
      'LPP art. 8 (déduction de coordination) / LPP art. 14 (taux de conversion 6.8%) / OPP2 art. 5 / OPP3 art. 7 / LPP art. 79b (rachat volontaire) / OFS 2024 (statistiques gender gap)';

  @override
  String get achievementsErrorMessage => 'Le chargement a buté. On réessaie ?';

  @override
  String get documentsEmptyVoice =>
      'C\'est vide pour l\'instant. Un scan de certificat, et tout s\'éclaire.';

  @override
  String documentsConfidenceChoc(String count, String pct) {
    return '$count documents = $pct% de confiance';
  }

  @override
  String get lamalFranchiseAppBarTitle => 'Franchise LAMal';

  @override
  String get lamalFranchiseDemoMode => 'MODE DÉMO';

  @override
  String get lamalFranchiseHeaderTitle => 'Ta franchise LAMal';

  @override
  String get lamalFranchiseHeaderSubtitle =>
      'Trouve la franchise idéale selon tes frais de santé';

  @override
  String get lamalFranchiseIntro =>
      'Une franchise élevée réduit ta prime mensuelle, mais augmente tes frais en cas de maladie. Déplace les curseurs pour trouver l\'équilibre.';

  @override
  String get lamalFranchiseToggleAdulte => 'Adulte';

  @override
  String get lamalFranchiseToggleEnfant => 'Enfant';

  @override
  String get lamalFranchisePrimeSliderLabel =>
      'Prime mensuelle (franchise 300)';

  @override
  String get lamalFranchiseDepensesSliderLabel =>
      'Frais de santé annuels estimés';

  @override
  String get lamalFranchiseComparisonHeader => 'COMPARAISON DES FRANCHISES';

  @override
  String get lamalFranchiseRecommandee => 'RECOMMANDÉE';

  @override
  String lamalFranchiseTotalPrefix(String amount) {
    return 'Total : $amount';
  }

  @override
  String get lamalFranchisePrimeAn => 'Prime/an';

  @override
  String get lamalFranchiseQuotePart => 'Quote-part';

  @override
  String get lamalFranchiseEconomie => 'Économie';

  @override
  String get lamalFranchiseBreakEvenTitle => 'Seuils de rentabilité';

  @override
  String lamalFranchiseBreakEvenItem(String seuil, String basse, String haute) {
    return 'Au-dessus de $seuil de frais, la franchise $basse devient plus avantageuse que $haute.';
  }

  @override
  String get lamalFranchiseRecommandationsHeader => 'RECOMMANDATIONS';

  @override
  String get lamalFranchiseAlertText =>
      'Rappel : changement de franchise possible avant le 30 novembre de chaque année pour l\'année suivante.';

  @override
  String get lamalFranchiseDisclaimer =>
      'Estimation éducative. Les primes varient selon l\'assureur, la région et le modèle d\'assurance. Ne constitue pas un conseil financier (LSFin).';

  @override
  String get lamalFranchiseSourcesHeader => 'Sources';

  @override
  String get lamalFranchiseSourcesBody =>
      'LAMal art. 62-64 (franchise et quote-part) / OAMal (ordonnance) / priminfo.admin.ch (comparateur officiel) / LAMal art. 7 (libre choix de l\'assureur) / LAMal art. 41a (modèles alternatifs)';

  @override
  String get lamalFranchisePrimeMin => 'CHF 200';

  @override
  String get lamalFranchisePrimeMax => 'CHF 600';

  @override
  String get lamalFranchiseDepensesMin => 'CHF 0';

  @override
  String get lamalFranchiseDepensesMax => 'CHF 10\'000';

  @override
  String get lamalFranchiseSelectAdulte => 'Sélectionner adulte';

  @override
  String get lamalFranchiseSelectEnfant => 'Sélectionner enfant';

  @override
  String get firstJobCantonLabel => 'Canton';

  @override
  String get firstJobSalaryMin => 'CHF 2\'000';

  @override
  String get firstJobSalaryMax => 'CHF 15\'000';

  @override
  String get firstJobActivityMin => '10 %';

  @override
  String get firstJobActivityMax => '100 %';

  @override
  String firstJobFiscalSavings(String amount) {
    return 'Économie fiscale estimée : ~$amount/an';
  }

  @override
  String firstJobFranchiseSavings(String amount) {
    return 'Franchise 2 500 vs 300 : économie estimée de ~$amount/an en primes';
  }

  @override
  String get firstJobTopBadge => 'TOP';

  @override
  String get authLoginSubtitle => 'Accède à ton espace financier personnel';

  @override
  String get authPasswordRequired => 'Mot de passe requis';

  @override
  String get authForgotPasswordLink => 'Mot de passe oublié ?';

  @override
  String get authVerifyEmailLink => 'Vérifier mon e-mail';

  @override
  String get authDateOfBirth => 'Date de naissance';

  @override
  String get authDateOfBirthHint => 'jj.mm.aaaa';

  @override
  String get authDateOfBirthRequired =>
      'Nécessaire pour les projections AVS/LPP';

  @override
  String get authDateOfBirthTooYoung =>
      'Tu dois avoir 18 ans révolus (CGU art. 4.1)';

  @override
  String get authDateOfBirthHelp => 'Date de naissance';

  @override
  String get authDateOfBirthCancel => 'Annuler';

  @override
  String get authDateOfBirthConfirm => 'Valider';

  @override
  String get authPasswordHintFull =>
      '8+ caractères, majuscule, chiffre, symbole';

  @override
  String get authPasswordMinChars => 'Minimum 8 caractères';

  @override
  String get authPasswordNeedUppercase => 'Au moins une majuscule requise';

  @override
  String get authPasswordNeedDigit => 'Au moins un chiffre requis';

  @override
  String get authPasswordNeedSpecial =>
      'Au moins un caractère spécial requis (!@#\$...)';

  @override
  String get authConfirmRequired => 'Confirmation requise';

  @override
  String get authPrivacyPolicyText => 'politique de confidentialité';

  @override
  String get slmStatusRunning => 'Prêt — le coach utilise l\'IA on-device';

  @override
  String get slmStatusReady => 'Modèle téléchargé — initialisation requise';

  @override
  String get slmStatusError =>
      'Erreur — appareil non compatible ou mémoire insuffisante';

  @override
  String get slmStatusDownloading => 'Téléchargement en cours...';

  @override
  String get slmStatusNotDownloaded => 'Modèle non téléchargé';

  @override
  String get slmStatusModelReady => 'Modèle prêt — lance l\'initialisation';

  @override
  String slmSizeLabel(String size) {
    return 'Taille : $size';
  }

  @override
  String slmVersionLabel(String version) {
    return 'Version : $version';
  }

  @override
  String slmWifiEstimate(int minutes) {
    return '~$minutes min sur WiFi';
  }

  @override
  String slmDownloadButton(String size) {
    return 'Télécharger ($size)';
  }

  @override
  String slmDownloadDialogBody(String size, int minutes, String hint) {
    return 'Le modèle fait $size. Assure-toi d\'être connecté en WiFi pour éviter une consommation importante de données mobiles.\n\n~$minutes min sur WiFi. Compatible : $hint.';
  }

  @override
  String slmDownloadFailedSnack(String reason) {
    return 'Échec du téléchargement. $reason';
  }

  @override
  String get slmDownloadFailedDefault =>
      'Vérifie ta connexion WiFi et l\'espace disponible.';

  @override
  String get slmDownloadNotAvailable =>
      'Ce build ne permet pas le téléchargement du modèle.';

  @override
  String slmInfoDownload(int minutes) {
    return 'Télécharge le modèle une fois (~$minutes min sur WiFi)';
  }

  @override
  String get slmInfoOnDevice => 'L\'IA tourne directement sur ton téléphone';

  @override
  String get slmInfoOffline => 'Fonctionne même sans connexion internet';

  @override
  String get slmInfoPrivacy => 'Tes données ne quittent jamais ton appareil';

  @override
  String get slmInfoSpeed => 'Réponses en 2-4 secondes sur un appareil récent';

  @override
  String slmInfoSourceModel(String modelId) {
    return 'Source modèle : $modelId';
  }

  @override
  String get slmInfoAuthConfigured =>
      'Authentification HuggingFace : configurée';

  @override
  String get slmInfoAuthNotConfigured =>
      'Authentification HuggingFace : non configurée (download impossible si URL Gemma gated)';

  @override
  String slmInfoCompatibility(String hint, String size, int ram) {
    return 'Compatibilité : $hint.\nLe modèle nécessite $size d\'espace disque et ~$ram Go de RAM.';
  }

  @override
  String get consentErrorMessage =>
      'Une erreur est survenue. Réessaie plus tard.';

  @override
  String get adminObsAuthBilling => 'Auth & Billing';

  @override
  String get adminObsOnboardingQuality => 'Qualité onboarding';

  @override
  String get adminObsCohorts => 'Cohortes (variant x platform)';

  @override
  String get adminObsNoData => 'Aucune donnée';

  @override
  String get adminAnalyticsTitle => 'Analytics';

  @override
  String get adminAnalyticsLoadError => 'Impossible de charger les analytics';

  @override
  String get adminAnalyticsRetry => 'Réessayer';

  @override
  String get adminAnalyticsFunnel => 'Funnel de conversion';

  @override
  String get adminAnalyticsByScreen => 'Évènements par écran';

  @override
  String get adminAnalyticsByCategory => 'Évènements par catégorie';

  @override
  String get adminAnalyticsNoFunnel => 'Pas encore de données de funnel.';

  @override
  String get adminAnalyticsNoData => 'Pas encore de données.';

  @override
  String get adminAnalyticsSessions => 'Sessions';

  @override
  String get adminAnalyticsEvents => 'Évènements';

  @override
  String get amortizationAppBarTitle => 'Direct vs indirect';

  @override
  String get eplCombinedAppBarTitle => 'EPL multi-sources';

  @override
  String get eplCombinedMinRequired => 'Minimum requis : 20 %';

  @override
  String get eplCombinedFundsBreakdown => 'Répartition des fonds propres';

  @override
  String get eplCombinedParameters => 'Paramètres';

  @override
  String get eplCombinedCanton => 'Canton';

  @override
  String get eplCombinedTargetPrice => 'Prix d\'achat cible';

  @override
  String get eplCombinedCashSavings => 'Épargne cash';

  @override
  String get eplCombinedAvoir3a => 'Avoir 3a';

  @override
  String get eplCombinedAvoirLpp => 'Avoir LPP';

  @override
  String get eplCombinedSourcesDetail => 'Détail des sources';

  @override
  String get eplCombinedTotalEquity => 'Total fonds propres';

  @override
  String get eplCombinedEstimatedTaxes => 'Impôts estimés (3a + LPP)';

  @override
  String get eplCombinedNetTotal => 'Montant net total';

  @override
  String get eplCombinedRequiredEquity => 'Fonds propres requis (20 %)';

  @override
  String get eplCombinedEstimatedTax => 'Impôt estimé';

  @override
  String get eplCombinedNet => 'Net';

  @override
  String get eplCombinedRecommendedOrder => 'Ordre recommandé';

  @override
  String get eplCombinedOrderCashTitle => 'Épargne cash';

  @override
  String get eplCombinedOrderCashReason =>
      'Aucun impôt, pas d\'impact sur la prévoyance';

  @override
  String get eplCombinedOrder3aTitle => 'Retrait 3a';

  @override
  String get eplCombinedOrder3aReason =>
      'Impôt réduit sur le retrait, impact limité sur la prévoyance vieillesse';

  @override
  String get eplCombinedOrderLppTitle => 'Retrait LPP (EPL)';

  @override
  String get eplCombinedOrderLppReason =>
      'Impact direct sur les prestations de risque (invalidité, décès). À utiliser en dernier recours.';

  @override
  String get eplCombinedAttentionPoints => 'Points d\'attention';

  @override
  String get eplCombinedSource =>
      'Source : LPP art. 30c (EPL), OPP3, LIFD art. 38. Taux cantonaux estimés à titre pédagogique.';

  @override
  String get eplCombinedPriceOfProperty => 'du prix';

  @override
  String get imputedRentalAppBarTitle => 'Valeur locative';

  @override
  String get imputedRentalIntroTitle => 'Qu\'est-ce que la valeur locative ?';

  @override
  String get imputedRentalIntroBody =>
      'En Suisse, les propriétaires doivent déclarer un revenu fictif (valeur locative) correspondant au loyer qu\'ils pourraient obtenir en louant leur bien. En contrepartie, ils peuvent déduire les intérêts hypothécaires et les frais d\'entretien.';

  @override
  String get imputedRentalDecomposition => 'Décomposition';

  @override
  String get imputedRentalBarLocative => 'Valeur locative';

  @override
  String get imputedRentalBarDeductions => 'Déductions';

  @override
  String get imputedRentalAddedIncome => 'Revenu imposable ajouté';

  @override
  String get imputedRentalLocativeValue => 'Valeur locative';

  @override
  String get imputedRentalDeductionsLabel => 'Déductions';

  @override
  String get imputedRentalMortgageInterest => 'Intérêts hypothécaires';

  @override
  String get imputedRentalMaintenanceCosts => 'Frais d\'entretien';

  @override
  String get imputedRentalBuildingInsurance =>
      'Assurance bâtiment (estimation)';

  @override
  String get imputedRentalTotalDeductions => 'Total déductions';

  @override
  String get imputedRentalNetImpact => 'Impact net sur le revenu imposable';

  @override
  String imputedRentalFiscalImpact(String rate) {
    return 'Impact fiscal estimé (taux marginal $rate %)';
  }

  @override
  String get imputedRentalParameters => 'Paramètres';

  @override
  String get imputedRentalCanton => 'Canton';

  @override
  String get imputedRentalPropertyValue => 'Valeur vénale du bien';

  @override
  String get imputedRentalAnnualInterest => 'Intérêts hypothécaires annuels';

  @override
  String get imputedRentalEffectiveMaintenance =>
      'Frais d\'entretien effectifs';

  @override
  String get imputedRentalOldProperty => 'Bien ancien (≥ 10 ans)';

  @override
  String get imputedRentalForfaitOld =>
      'Forfait entretien : 20 % de la valeur locative';

  @override
  String get imputedRentalForfaitNew =>
      'Forfait entretien : 10 % de la valeur locative';

  @override
  String get imputedRentalMarginalRate => 'Taux marginal estimé';

  @override
  String get imputedRentalSource =>
      'Source : LIFD art. 21 al. 1 let. b, art. 32. Taux cantonaux estimés à titre pédagogique.';

  @override
  String get saronVsFixedAppBarTitle => 'SARON vs fixe';

  @override
  String saronVsFixedCumulativeCost(int years) {
    return 'Coût cumulé sur $years ans';
  }

  @override
  String get saronVsFixedLegendFixed => 'Fixe';

  @override
  String get saronVsFixedLegendSaronStable => 'SARON stable';

  @override
  String get saronVsFixedLegendSaronRise => 'SARON hausse';

  @override
  String get saronVsFixedParameters => 'Paramètres';

  @override
  String get saronVsFixedMortgageAmount => 'Montant hypothécaire';

  @override
  String get saronVsFixedDuration => 'Durée';

  @override
  String saronVsFixedYears(int years) {
    return '$years ans';
  }

  @override
  String get saronVsFixedCostComparison => 'Comparaison des coûts';

  @override
  String saronVsFixedRate(String rate) {
    return 'Taux : $rate';
  }

  @override
  String get saronVsFixedInsightText =>
      'Le SARON hausse simule +0,25 %/an les 3 premières années. En réalité, l\'évolution dépend de la politique monétaire de la BNS.';

  @override
  String get saronVsFixedSource =>
      'Source : taux indicatifs marché suisse 2026. Ne constitue pas un conseil hypothécaire.';

  @override
  String get avsCotisationsTitle => 'Cotisations AVS';

  @override
  String get avsCotisationsHeaderInfo =>
      'En tant qu’indépendant·e, tu paies l’intégralité des cotisations AVS/AI/APG toi-même. Un·e salarié·e n’en paie que la moitié (5.3 %), l’employeur couvrant le reste.';

  @override
  String get avsCotisationsRevenuLabel => 'Ton revenu net annuel';

  @override
  String get avsCotisationsSliderMin => 'CHF 0';

  @override
  String get avsCotisationsSliderMax250k => 'CHF 250’000';

  @override
  String avsCotisationsChiffreChocCaption(String amount) {
    return 'En tant qu’indépendant·e, tu paies $amount/an de plus qu’un·e salarié·e';
  }

  @override
  String get avsCotisationsTauxEffectif => 'Taux effectif';

  @override
  String get avsCotisationsCotisationAn => 'Cotisation /an';

  @override
  String get avsCotisationsCotisationMois => 'Cotisation /mois';

  @override
  String get avsCotisationsTranche => 'Tranche';

  @override
  String get avsCotisationsComparaisonTitle => 'Comparaison annuelle';

  @override
  String get avsCotisationsIndependant => 'Indépendant·e';

  @override
  String get avsCotisationsSalarie => 'Salarié·e (part employée)';

  @override
  String avsCotisationsSurcout(String amount) {
    return 'Surcoût indépendant·e : +$amount/an';
  }

  @override
  String get avsCotisationsBaremeTitle => 'Ton positionnement sur le barème';

  @override
  String avsCotisationsTauxEffectifLabel(String taux) {
    return 'Ton taux effectif : $taux %';
  }

  @override
  String get avsCotisationsBonASavoir => 'Bon à savoir';

  @override
  String get avsCotisationsEduDegressifTitle => 'Barème dégressif';

  @override
  String get avsCotisationsEduDegressifBody =>
      'Le taux diminue pour les bas revenus (entre CHF 10’100 et CHF 60’500). Au-dessus de CHF 60’500, le taux plein de 10.6 % s’applique.';

  @override
  String get avsCotisationsEduDoubleChargeTitle => 'Double charge';

  @override
  String get avsCotisationsEduDoubleChargeBody =>
      'Un·e salarié·e ne paie que 5.3 % ; l’employeur prend en charge l’autre moitié. En tant qu’indépendant·e, tu assumes la totalité.';

  @override
  String get avsCotisationsEduMinTitle => 'Cotisation minimale';

  @override
  String get avsCotisationsEduMinBody =>
      'Même avec un revenu très faible, la cotisation minimale est de CHF 530/an.';

  @override
  String get avsCotisationsDisclaimer =>
      'Les montants présentés sont des estimations basées sur le barème AVS/AI/APG en vigueur. Les cotisations réelles peuvent varier selon ta situation personnelle. Consulte ta caisse de compensation pour un décompte exact.';

  @override
  String get ijmTitle => 'Assurance IJM';

  @override
  String get ijmHeaderInfo =>
      'L’assurance IJM (indemnité journalière maladie) compense ta perte de revenu en cas de maladie. En tant qu’indépendant·e, aucune protection n’est prévue par défaut : c’est à toi de t’assurer.';

  @override
  String get ijmRevenuMensuel => 'Revenu mensuel';

  @override
  String get ijmSliderMinChf0 => 'CHF 0';

  @override
  String get ijmSliderMax20k => 'CHF 20’000';

  @override
  String get ijmTonAge => 'Ton âge';

  @override
  String get ijmAgeMin => '18 ans';

  @override
  String get ijmAgeMax => '65 ans';

  @override
  String get ijmDelaiCarence => 'Délai de carence';

  @override
  String get ijmDelaiCarenceDesc =>
      'Période pendant laquelle tu ne reçois aucune indemnité';

  @override
  String get ijmJours => 'jours';

  @override
  String ijmChiffreChocCaption(String amount, int jours) {
    return 'Sans assurance IJM, tu perds $amount pendant le délai de carence de $jours jours';
  }

  @override
  String get ijmHighRiskTitle => 'Primes élevées après 50 ans';

  @override
  String get ijmHighRiskBody =>
      'Les primes IJM augmentent fortement avec l’âge. Après 50 ans, le coût peut être 3 à 4 fois supérieur à celui d’une personne de 30 ans. Considère un délai de carence plus long pour réduire la prime.';

  @override
  String get ijmPrimeMois => 'Prime /mois';

  @override
  String get ijmPrimeAn => 'Prime /an';

  @override
  String get ijmIndemniteJour => 'Indemnité /jour';

  @override
  String get ijmTrancheAge => 'Tranche d’âge';

  @override
  String get ijmTimelineTitle => 'Chronologie de couverture';

  @override
  String get ijmTimelineCouvert => 'Couvert';

  @override
  String get ijmTimelineNoCoverage => 'Pas de couverture';

  @override
  String get ijmTimelineCoverageIjm => 'Couverture IJM (80 %)';

  @override
  String ijmTimelineSummary(int jours, String amount) {
    return 'Pendant les $jours premiers jours de maladie, tu n’as aucun revenu. Ensuite, tu reçois $amount/jour (80 % de ton revenu mensuel).';
  }

  @override
  String get ijmStrategies => 'Stratégies';

  @override
  String get ijmEduFondsTitle => 'Constitution d’un fonds de carence';

  @override
  String get ijmEduFondsBody =>
      'Mets de côté l’équivalent de 3 mois de revenus pour couvrir le délai de carence. Cela te permet de choisir un délai de 90 jours et de réduire ta prime.';

  @override
  String get ijmEduComparerTitle => 'Comparer les offres';

  @override
  String get ijmEduComparerBody =>
      'Les primes varient fortement entre assureurs. Demande plusieurs devis et compare les conditions (exclusions, durée des prestations, montant couvert).';

  @override
  String get ijmEduLamalTitle => 'Couverture LAMal insuffisante';

  @override
  String get ijmEduLamalBody =>
      'La LAMal ne couvre que les frais médicaux, pas la perte de gain. L’IJM est indispensable pour protéger ton revenu.';

  @override
  String get ijmDisclaimer =>
      'Les primes présentées sont des estimations basées sur des moyennes du marché. Les primes réelles dépendent de l’assureur, de ta profession et de ton état de santé. Demande un devis personnalisé à un·e spécialiste.';

  @override
  String ijmJoursCarenceLabel(int jours) {
    return '$jours jours de carence';
  }

  @override
  String get pillar3aIndepTitle => '3e pilier indépendant';

  @override
  String get pillar3aIndepHeaderInfo =>
      'En tant qu’indépendant·e sans LPP, tu as accès au «grand 3a» : tu peux déduire jusqu’à 20 % de ton revenu net (max CHF 36’288/an), au lieu de CHF 7’258 pour un·e salarié·e. C’est un avantage fiscal majeur.';

  @override
  String get pillar3aIndepLppToggle => 'Affilié·e à une LPP volontaire ?';

  @override
  String get pillar3aIndepPlafondPetit => 'Plafond 3a : CHF 7’258 (petit 3a)';

  @override
  String get pillar3aIndepPlafondGrand =>
      'Plafond 3a : 20 % du revenu, max CHF 36’288 (grand 3a)';

  @override
  String get pillar3aIndepRevenuLabel => 'Revenu net annuel';

  @override
  String get pillar3aIndepSliderMax300k => 'CHF 300’000';

  @override
  String get pillar3aIndepTauxLabel => 'Taux marginal d’imposition';

  @override
  String get pillar3aIndepChiffreChocCaption =>
      'd’économie fiscale annuelle grâce au 3e pilier';

  @override
  String pillar3aIndepChiffreChocAvantageSalarie(String amount) {
    return 'Tu économises $amount/an d’impôts de plus qu’un·e salarié·e grâce au grand 3a';
  }

  @override
  String get pillar3aIndepPlafondApplicable => 'Plafond applicable';

  @override
  String get pillar3aIndepEconomieFiscaleAn => 'Économie fiscale /an';

  @override
  String get pillar3aIndepPlafondSalarie => 'Plafond salarié·e';

  @override
  String get pillar3aIndepEconomieSalarie => 'Économie salarié·e';

  @override
  String get pillar3aIndepPlafondsCompares => 'Plafonds comparés';

  @override
  String pillar3aIndepSuperPouvoir(int multiplier) {
    return '×$multiplier ton super-pouvoir';
  }

  @override
  String get pillar3aIndepSalarie => 'Salarié·e';

  @override
  String get pillar3aIndepIndependantToi => 'Indépendant·e (toi)';

  @override
  String get pillar3aIndepGrand3aMax => 'Grand 3a (max légal)';

  @override
  String get pillar3aIndepEn20ans => 'En 20 ans à 4 %';

  @override
  String get pillar3aIndepVs => 'vs';

  @override
  String get pillar3aIndepToi => 'Toi';

  @override
  String pillar3aIndepDifference(String amount) {
    return 'Différence : +$amount';
  }

  @override
  String get pillar3aIndepBonASavoir => 'Bon à savoir';

  @override
  String get pillar3aIndepEduComptesTitle => 'Ouvre plusieurs comptes 3a';

  @override
  String get pillar3aIndepEduComptesBody =>
      'Même avec le grand 3a, la stratégie des comptes multiples (jusqu’à 5) est recommandée pour optimiser le retrait échelonné à la retraite.';

  @override
  String get pillar3aIndepEduConditionTitle => 'Condition : pas de LPP';

  @override
  String get pillar3aIndepEduConditionBody =>
      'Le grand 3a (20 % du revenu, max 36’288) n’est accessible que si tu n’es pas affilié·e à une LPP volontaire. Avec LPP, le plafond tombe à 7’258.';

  @override
  String get pillar3aIndepEduInvestirTitle => 'Investir plutôt qu’épargner';

  @override
  String get pillar3aIndepEduInvestirBody =>
      'Pour un horizon long (>10 ans), un 3a investi en actions peut offrir un rendement bien supérieur à un compte d’épargne 3a classique.';

  @override
  String get pillar3aIndepDisclaimer =>
      'Les économies fiscales sont calculées sur la base du taux marginal indiqué. Le taux réel dépend de ton canton, de ta commune et de ta situation familiale. Consulte un·e spécialiste pour un calcul personnalisé.';

  @override
  String get dividendeVsSalaireTitle => 'Dividende vs Salaire';

  @override
  String get dividendeVsSalaireHeaderInfo =>
      'Si tu possèdes une SA ou Sàrl, tu peux te verser une combinaison de salaire et de dividendes. Le dividende est imposé à 50 % (participation qualifiante) et échappe aux cotisations AVS. Trouve le split le plus adapté.';

  @override
  String get dividendeVsSalaireBenefice => 'Bénéfice total';

  @override
  String get dividendeVsSalaireSliderMax500k => 'CHF 500’000';

  @override
  String get dividendeVsSalairePartSalaire => 'Part salaire';

  @override
  String get dividendeVsSalaireTauxMarginal => 'Taux marginal d’imposition';

  @override
  String dividendeVsSalaireChiffreChocPositive(String amount) {
    return 'Le split adapté te fait économiser $amount/an par rapport à 100 % salaire';
  }

  @override
  String get dividendeVsSalaireChiffreChocNeutral =>
      'Ajuste le split pour trouver une économie';

  @override
  String get dividendeVsSalaireRequalificationTitle =>
      'Risque de requalification';

  @override
  String get dividendeVsSalaireRequalificationBody =>
      'Si la part salaire est inférieure à ~60 % du bénéfice, l’administration fiscale peut requalifier une partie des dividendes en salaire (pratique cantonale variable). Cela entraîne des cotisations AVS rétroactives.';

  @override
  String get dividendeVsSalairePartSalaireLabel => 'Part salaire';

  @override
  String get dividendeVsSalairePartDividende => 'Part dividende';

  @override
  String dividendeVsSalairePctBenefice(int pct) {
    return '$pct % du bénéfice';
  }

  @override
  String get dividendeVsSalaireChargeSalaire => 'Charge sur salaire';

  @override
  String get dividendeVsSalaireChargeDividende => 'Charge sur dividende';

  @override
  String get dividendeVsSalaireChargeTotalSplit => 'Charge totale (split)';

  @override
  String get dividendeVsSalaireCharge100Salaire => 'Charge si 100 % salaire';

  @override
  String get dividendeVsSalaireChartTitle => 'Charge totale par split';

  @override
  String get dividendeVsSalairePctSalaire0 => '0 % salaire';

  @override
  String get dividendeVsSalairePctSalaire100 => '100 % salaire';

  @override
  String get dividendeVsSalaireChargeTotale => 'Charge totale';

  @override
  String get dividendeVsSalaireSplitAdapte => 'Split adapté';

  @override
  String get dividendeVsSalairePositionActuelle => 'Position actuelle';

  @override
  String get dividendeVsSalaireARetenir => 'À retenir';

  @override
  String get dividendeVsSalaireEduImpotTitle => 'Impôt sur le bénéfice';

  @override
  String get dividendeVsSalaireEduImpotBody =>
      'Rappelle-toi que le bénéfice distribué en dividende est imposé d’abord au niveau de la société (impôt sur le bénéfice), puis au niveau personnel (double imposition économique).';

  @override
  String get dividendeVsSalaireEduAvsTitle => 'AVS uniquement sur le salaire';

  @override
  String get dividendeVsSalaireEduAvsBody =>
      'Les cotisations AVS (environ 12.5 % au total) ne s’appliquent qu’à la part salaire. Le dividende échappe aux charges sociales, d’où l’intérêt d’ajuster le split.';

  @override
  String get dividendeVsSalaireEduCantonalTitle => 'Pratique cantonale';

  @override
  String get dividendeVsSalaireEduCantonalBody =>
      'Les autorités fiscales surveillent les distributions excessives de dividendes. Un salaire «conforme au marché» est attendu. La limite varie selon les cantons.';

  @override
  String get dividendeVsSalaireDisclaimer =>
      'Simulation simplifiée. L’impôt sur le bénéfice de la société, les déductions personnelles et les règles cantonales ne sont pas intégrés dans ce calcul. Consulte un·e spécialiste pour une analyse complète.';

  @override
  String get dividendeVsSalaireCantonalDisclaimer =>
      'L’impact fiscal dépend de la pratique cantonale. Les seuils de requalification varient d’un canton à l’autre.';

  @override
  String get dividendeVsSalaireComplianceFooter =>
      'Outil éducatif — ne constitue pas un conseil financier (LSFin).';

  @override
  String get dividendeVsSalaireSources =>
      'Sources : LIFD art. 18, 20, 33 ; CO art. 660';

  @override
  String get lppVolontaireTitle => 'LPP volontaire';

  @override
  String get lppVolontaireHeaderInfo =>
      'En tant qu’indépendant·e, tu peux t’affilier volontairement à une caisse de pension (LPP). Les cotisations sont entièrement déductibles de ton revenu imposable, et tu construis ton 2e pilier retraite.';

  @override
  String get lppVolontaireRevenuLabel => 'Revenu net annuel';

  @override
  String get lppVolontaireSliderMax250k => 'CHF 250’000';

  @override
  String get lppVolontaireTonAge => 'Ton âge';

  @override
  String get lppVolontaireAgeMin => '25 ans';

  @override
  String get lppVolontaireAgeMax => '65 ans';

  @override
  String get lppVolontaireTauxMarginal => 'Taux marginal d’imposition';

  @override
  String lppVolontaireChiffreChocCaption(String amount) {
    return 'Sans LPP volontaire, tu perds $amount/an de capitalisation retraite';
  }

  @override
  String get lppVolontaireSalaireCoordonne => 'Salaire coordonné';

  @override
  String get lppVolontaireTauxBonification => 'Taux bonification';

  @override
  String get lppVolontaireCotisationAn => 'Cotisation /an';

  @override
  String get lppVolontaireEconomieFiscaleAn => 'Économie fiscale /an';

  @override
  String get lppVolontaireTrancheAge => 'Tranche d’âge';

  @override
  String get lppVolontaireProjectionTitle => 'Projection retraite annuelle';

  @override
  String get lppVolontaireSansLpp => 'Sans LPP (AVS seule)';

  @override
  String get lppVolontaireAvecLpp => 'Avec LPP volontaire';

  @override
  String lppVolontaireGapLabel(String amount) {
    return 'La LPP volontaire pourrait ajouter $amount/an à ta rente de retraite';
  }

  @override
  String get lppVolontaireBonificationTitle => 'Taux de bonification par âge';

  @override
  String get lppVolontaireToi => 'TOI';

  @override
  String get lppVolontaireBonASavoir => 'Bon à savoir';

  @override
  String get lppVolontaireEduAffiliationTitle => 'Affiliation volontaire';

  @override
  String get lppVolontaireEduAffiliationBody =>
      'Les indépendant·e·s peuvent s’affilier volontairement à la LPP via une fondation collective, une caisse de branche ou la caisse cantonale.';

  @override
  String get lppVolontaireEduFiscalTitle => 'Double avantage fiscal';

  @override
  String get lppVolontaireEduFiscalBody =>
      'Les cotisations LPP volontaires sont entièrement déductibles du revenu imposable. De plus, le capital LPP n’est pas soumis à l’impôt sur la fortune.';

  @override
  String get lppVolontaireEduImpact3aTitle => 'Impact sur le 3a';

  @override
  String get lppVolontaireEduImpact3aBody =>
      'Si tu t’affilies à une LPP volontaire, ton plafond 3a passe du «grand 3a» (max CHF 36’288) au «petit 3a» (CHF 7’258). Évalue le trade-off.';

  @override
  String get lppVolontaireDisclaimer =>
      'Les projections de rente sont des estimations basées sur un rendement projeté de 1.5 %/an et un taux de conversion de 6.8 %. Les prestations réelles dépendent de la caisse de pension choisie et de l’évolution des marchés. Consulte un·e spécialiste en prévoyance.';

  @override
  String lppVolontairePerAn(String amount) {
    return '$amount/an';
  }

  @override
  String get coverageCheckTitle => 'Check-up couverture';

  @override
  String get coverageCheckAppBarTitle => 'Check-up couverture';

  @override
  String get coverageCheckSubtitle => 'Évalue ta protection assurantielle';

  @override
  String get coverageCheckDemoMode => 'MODE DÉMO';

  @override
  String get coverageCheckTonProfil => 'Ton profil';

  @override
  String get coverageCheckStatut => 'Statut professionnel';

  @override
  String get coverageCheckSalarie => 'Salarié·e';

  @override
  String get coverageCheckIndependant => 'Indépendant·e';

  @override
  String get coverageCheckSansEmploi => 'Sans emploi';

  @override
  String get coverageCheckHypotheque => 'Hypothèque en cours';

  @override
  String get coverageCheckPersonnesCharge => 'Personnes à charge';

  @override
  String get coverageCheckLocataire => 'Locataire';

  @override
  String get coverageCheckVoyages => 'Voyages fréquents';

  @override
  String get coverageCheckCouvertureActuelle => 'Ma couverture actuelle';

  @override
  String get coverageCheckIjm => 'IJM collective (employeur)';

  @override
  String get coverageCheckLaa => 'LAA (assurance accident)';

  @override
  String get coverageCheckRcPrivee => 'RC privée';

  @override
  String get coverageCheckMenage => 'Assurance ménage';

  @override
  String get coverageCheckProtJuridique => 'Protection juridique';

  @override
  String get coverageCheckVoyage => 'Assurance voyage';

  @override
  String get coverageCheckDeces => 'Assurance décès';

  @override
  String get coverageCheckScore => 'Score de couverture';

  @override
  String coverageCheckLacunes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lacunes critiques',
      one: '$count lacune critique',
    );
    return '$_temp0';
  }

  @override
  String get coverageCheckAnalyseTitle => 'Analyse détaillée';

  @override
  String get coverageCheckRecommandationsTitle => 'Recommandations';

  @override
  String get coverageCheckCouvert => 'Couvert';

  @override
  String get coverageCheckNonCouvert => 'Non couvert';

  @override
  String get coverageCheckAVerifier => 'À vérifier';

  @override
  String get coverageCheckCritique => 'Critique';

  @override
  String get coverageCheckHaute => 'Haute';

  @override
  String get coverageCheckMoyenne => 'Moyenne';

  @override
  String get coverageCheckBasse => 'Basse';

  @override
  String get coverageCheckDisclaimer =>
      'Cette analyse est indicative et ne constitue pas un conseil en assurance personnalisé. Les primes varient selon l’assureur et ton profil. Consulte un·e spécialiste en assurances pour une évaluation complète.';

  @override
  String get coverageCheckSources => 'Sources';

  @override
  String get coverageCheckSourcesBody =>
      'CO art. 41 (RC) / CO art. 324a (IJM employeur) / LAA art. 4 (assurance accident) / LAMal art. 34 (couverture à l’étranger) / LCA (assurance décès) / Droit cantonal (ménage)';

  @override
  String get coverageCheckSlashHundred => '/ 100';

  @override
  String coverageCheckAnsLabel(int age) {
    return '$age ans';
  }

  @override
  String get eplAppBarTitle => 'Retrait EPL';

  @override
  String get eplIntroTitle => 'Retrait EPL — Propriété du logement';

  @override
  String get eplIntroBody =>
      'L’EPL permet d’utiliser ton avoir LPP pour financer l’achat d’un logement en propriété, amortir une hypothèque ou financer des rénovations. Montant minimum : CHF 20’000. Ce retrait a un impact direct sur tes prestations de risque.';

  @override
  String get eplSectionParametres => 'Paramètres';

  @override
  String get eplLabelAvoirTotal => 'Avoir LPP total';

  @override
  String get eplLabelAge => 'Âge';

  @override
  String eplLabelAgeFormat(int age) {
    return '$age ans';
  }

  @override
  String get eplLabelMontantSouhaite => 'Montant souhaité';

  @override
  String get eplLabelCanton => 'Canton';

  @override
  String get eplLabelRachatsRecents => 'Rachats LPP récents';

  @override
  String get eplLabelRachatsQuestion =>
      'As-tu effectué un rachat LPP ces 3 dernières années ?';

  @override
  String get eplLabelAnneesSDepuisRachat => 'Années depuis le rachat';

  @override
  String eplLabelAnneesSDepuisRachatFormat(int years, String suffix) {
    return '$years an$suffix';
  }

  @override
  String get eplSectionResultat => 'Résultat';

  @override
  String get eplMontantMaxRetirable => 'Montant maximum retirable';

  @override
  String get eplMontantApplicable => 'Montant applicable';

  @override
  String get eplRetraitImpossible =>
      'Le retrait n’est pas possible dans la configuration actuelle.';

  @override
  String get eplSectionImpactPrestations => 'Impact sur les prestations';

  @override
  String get eplReductionInvalidite =>
      'Réduction rente invalidité (estimation annuelle)';

  @override
  String get eplReductionDeces => 'Réduction capital-décès (estimation)';

  @override
  String get eplImpactPrestationsNote =>
      'Le retrait EPL réduit proportionnellement tes prestations de risque. Vérifie auprès de ta caisse de pension les montants exacts et les possibilités d’assurance complémentaire.';

  @override
  String get eplSectionImpactRente => 'Impact sur la rente';

  @override
  String get eplRenteSansEpl => 'Rente sans EPL';

  @override
  String get eplRenteAvecEpl => 'Rente avec EPL';

  @override
  String get eplPerteMensuelle => 'Perte mensuelle';

  @override
  String get eplImpactRenteNote =>
      'Estimation éducative basée sur un salaire de CHF 100’000, rendement caisse 2%, taux de conversion 6.8%. Le montant réel dépend de ta situation.';

  @override
  String get eplSectionFiscale => 'Estimation fiscale';

  @override
  String get eplMontantRetire => 'Montant retiré';

  @override
  String get eplImpotEstime => 'Impôt estimé sur le retrait';

  @override
  String get eplMontantNet => 'Montant net après impôt';

  @override
  String get eplFiscaleNote =>
      'Le retrait en capital est imposé à un taux réduit (environ 1/5 du barème ordinaire). Le taux exact dépend du canton, de la commune et de la situation personnelle.';

  @override
  String get eplSectionPointsAttention => 'Points d’attention';

  @override
  String get librePassageAppBarTitle => 'Libre passage';

  @override
  String get librePassageSectionSituation => 'Situation';

  @override
  String get librePassageChipChangementEmploi => 'Changement d’emploi';

  @override
  String get librePassageChipDepartSuisse => 'Départ de Suisse';

  @override
  String get librePassageChipCessationActivite => 'Cessation d’activité';

  @override
  String get librePassageSectionProfil => 'Ton profil';

  @override
  String get librePassageLabelAge => 'Ton âge';

  @override
  String librePassageLabelAgeFormat(int age) {
    return '$age ans';
  }

  @override
  String get librePassageLabelAvoir => 'Avoir de libre passage';

  @override
  String get librePassageLabelNouvelEmployeur => 'Nouvel employeur';

  @override
  String get librePassageLabelNouvelEmployeurQuestion =>
      'As-tu déjà un nouvel employeur ?';

  @override
  String get librePassageSectionAlertes => 'Alertes';

  @override
  String get librePassageSectionChecklist => 'Checklist';

  @override
  String get librePassageUrgenceCritique => 'Critique';

  @override
  String get librePassageUrgenceHaute => 'Haute';

  @override
  String get librePassageUrgenceMoyenne => 'Moyenne';

  @override
  String get librePassageSectionRecommandations => 'Recommandations';

  @override
  String get librePassageCentrale2eTitle => 'Centrale du 2e pilier (sfbvg.ch)';

  @override
  String get librePassageCentrale2eSubtitle =>
      'Rechercher des avoirs de libre passage oubliés';

  @override
  String get librePassagePrivacyNote =>
      'Tes données restent sur ton appareil. Aucune information n’est transmise à des tiers. Conforme à la nLPD.';

  @override
  String get providerComparatorAppBarTitle => 'Comparateur 3a';

  @override
  String providerComparatorChiffreChocLabel(int duree) {
    return 'Différence sur $duree ans';
  }

  @override
  String get providerComparatorChiffreChocSubtitle =>
      'entre le provider le plus et le moins performant';

  @override
  String get providerComparatorSectionParametres => 'Paramètres';

  @override
  String get providerComparatorLabelAge => 'Âge';

  @override
  String providerComparatorLabelAgeFormat(int age) {
    return '$age ans';
  }

  @override
  String get providerComparatorLabelVersement => 'Versement annuel';

  @override
  String get providerComparatorLabelDuree => 'Durée';

  @override
  String providerComparatorLabelDureeFormat(int duree) {
    return '$duree ans';
  }

  @override
  String get providerComparatorLabelProfilRisque => 'Profil de risque';

  @override
  String get providerComparatorProfilPrudent => 'Prudent';

  @override
  String get providerComparatorProfilEquilibre => 'Équilibré';

  @override
  String get providerComparatorProfilDynamique => 'Dynamique';

  @override
  String get providerComparatorSectionComparaison => 'Comparaison';

  @override
  String get providerComparatorRendement => 'Rendement';

  @override
  String get providerComparatorFrais => 'Frais';

  @override
  String get providerComparatorCapitalFinal => 'Capital final';

  @override
  String get providerComparatorWarningLabel => 'Attention';

  @override
  String providerComparatorDiffVsPremier(String amount) {
    return '-CHF $amount vs premier';
  }

  @override
  String get providerComparatorAssuranceTitle => 'Attention — Assurance 3a';

  @override
  String get providerComparatorAssuranceNote =>
      'Les assurances 3a combinent épargne et couverture risque, mais les frais élevés (souvent > 1.5%) et la rigidité du contrat les rendent défavorables pour les jeunes épargnants.';

  @override
  String documentDetailFieldsExtracted(int found, int total) {
    return '$found champs extraits sur $total';
  }

  @override
  String get documentDetailProfileUpdated => 'Profil mis à jour avec succès';

  @override
  String get documentDetailCancelButton => 'Annuler';

  @override
  String get portfolioTitle => 'Mon patrimoine';

  @override
  String get portfolioNetWorth => 'Valeur totale nette';

  @override
  String get portfolioReadiness => 'Readiness Index';

  @override
  String get portfolioEnvelopeTitle => 'Répartition par enveloppe';

  @override
  String get portfolioLibre => 'Libre (Compte Placement)';

  @override
  String get portfolioLie => 'Lié (Pilier 3a)';

  @override
  String get portfolioReserve => 'Réservé (Fonds d\'urgence)';

  @override
  String get portfolioCoachAdvice =>
      'Ton allocation est saine. Pense à rééquilibrer ton 3a prochainement.';

  @override
  String get portfolioDebtWarning =>
      'Alerte Dettes : Ta priorité absolue est le désendettement avant tout réinvestissement.';

  @override
  String get portfolioSafeModeTitle => 'Priorité au désendettement';

  @override
  String get portfolioSafeModeMsg =>
      'Les conseils d\'allocation sont désactivés en mode protection. Ta priorité est de réduire tes dettes avant de rééquilibrer ton patrimoine.';

  @override
  String get portfolioRetirement => 'Pérennité Retraite';

  @override
  String get portfolioProperty => 'Projet Immobilier';

  @override
  String get portfolioFamily => 'Protection Famille';

  @override
  String get portfolioToday => 'aujourd\'hui';

  @override
  String get timelineTitle => 'Mon parcours';

  @override
  String get timelineHeader => 'Ta vie financière,\nétape par étape.';

  @override
  String get timelineSubheader =>
      'Outils essentiels et événements de vie — tout est là.';

  @override
  String get timelineSectionTitle => 'Événements de vie';

  @override
  String get timelineSectionSubtitle =>
      'Sélectionne un événement pour simuler son impact financier.';

  @override
  String get confidenceDashboardTitle => 'Précision de ton profil';

  @override
  String get confidenceDetailByAxis => 'Détail par axe';

  @override
  String get confidenceFeatureGates => 'Fonctionnalités débloquées';

  @override
  String get confidenceImprove => 'Améliore ta précision';

  @override
  String confidenceRequired(int percent) {
    return '$percent % requis';
  }

  @override
  String get confidenceLevelExcellent => 'Excellente';

  @override
  String get confidenceLevelGood => 'Bonne';

  @override
  String get confidenceLevelOk => 'Correcte';

  @override
  String get confidenceLevelImprove => 'À améliorer';

  @override
  String get confidenceLevelInsufficient => 'Insuffisante';

  @override
  String get confidenceSources => 'Sources';

  @override
  String get cockpitDetailTitle => 'Cockpit détaillé';

  @override
  String get cockpitEmptyMsg =>
      'Complète ton profil pour accéder au cockpit détaillé.';

  @override
  String get cockpitEnrichCta => 'Enrichir mon profil';

  @override
  String get cockpitDisclaimer =>
      'Outil éducatif simplifié. Ne constitue pas un conseil financier (LSFin). Sources : LAVS art. 21-29, LPP art. 14, OPP3 art. 7.';

  @override
  String get annualRefreshTitle => 'Check-up annuel';

  @override
  String get annualRefreshIntro =>
      'Quelques questions rapides pour mettre ton profil à jour.';

  @override
  String get annualRefreshSubmit => 'Mettre à jour mon profil';

  @override
  String get annualRefreshResult => 'Profil mis à jour !';

  @override
  String get annualRefreshDashboard => 'Retour au dashboard';

  @override
  String get annualRefreshDisclaimer =>
      'Cet outil est à but éducatif et ne constitue pas un conseil financier au sens de la LSFin. Consulte un·e spécialiste pour des conseils personnalisés.';

  @override
  String get acceptInvitationTitle => 'Rejoindre un ménage';

  @override
  String get acceptInvitationPrompt =>
      'Entre le code reçu de ton/ta partenaire';

  @override
  String get acceptInvitationCodeValidity =>
      'Le code est valable 72 heures après l\'envoi.';

  @override
  String get acceptInvitationJoin => 'Rejoindre le ménage';

  @override
  String get acceptInvitationSuccess => 'Bienvenue dans le ménage !';

  @override
  String get acceptInvitationSuccessBody =>
      'Tu as rejoint le ménage Couple+. Tes projections de retraite sont désormais liées.';

  @override
  String get acceptInvitationViewHousehold => 'Voir mon ménage';

  @override
  String get financialReportTitle => 'Ton Plan Mint';

  @override
  String get financialReportBudget => 'Ton Budget';

  @override
  String get financialReportProtection => 'Ta Protection';

  @override
  String get financialReportRetirement => 'Ta Retraite';

  @override
  String get financialReportTax => 'Tes Impôts';

  @override
  String get financialReportPriorities => 'Tes 3 actions prioritaires';

  @override
  String get financialReportOptimize3a => 'Optimise ton 3a';

  @override
  String get financialReportLppStrategy => 'Stratégie Rachat LPP';

  @override
  String get financialReportTransparency => 'Transparence et conformité';

  @override
  String get financialReportLegalMention => 'Mention légale';

  @override
  String get financialReportDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil financier au sens de la LSFin. Les montants sont des estimations basées sur les données déclarées.';

  @override
  String get capKindComplete => 'Compléter';

  @override
  String get capKindCorrect => 'Corriger';

  @override
  String get capKindOptimize => 'Optimiser';

  @override
  String get capKindSecure => 'Sécuriser';

  @override
  String get capKindPrepare => 'Préparer';

  @override
  String get proofSheetSources => 'Sources';

  @override
  String get pulseFeedbackRecalculated => 'Impact recalculé';

  @override
  String get pulseFeedbackAddedRecently => 'Ajouté récemment';

  @override
  String get debtRatioTitle => 'Diagnostic dette';

  @override
  String get debtRatioSubLabel => 'Ratio dette / revenus';

  @override
  String get debtRatioRefineLabel => 'Affiner le diagnostic';

  @override
  String get debtRatioMinVital => 'Minimum vital (LP art. 93)';

  @override
  String get debtRatioRecommandations => 'Recommandations';

  @override
  String get debtRatioCtaRouge => 'Crée ton plan de remboursement';

  @override
  String get debtRatioCtaOrange => 'Optimise tes remboursements';

  @override
  String get debtRatioAidePro => 'Aide professionnelle';

  @override
  String get repaymentTitle => 'Plan de remboursement';

  @override
  String get repaymentLibereDans => 'Libéré dans';

  @override
  String get repaymentMesDettes => 'Mes dettes';

  @override
  String get repaymentBudgetLabel => 'Budget remboursement';

  @override
  String get repaymentComparaisonStrategies => 'Comparaison des stratégies';

  @override
  String get repaymentStrategyNote =>
      'Le choix dépend de ta personnalité financière, pas seulement du coût.';

  @override
  String get repaymentTimelineTitle => 'Timeline (Avalanche)';

  @override
  String get repaymentTimelineMois => 'Mois';

  @override
  String get repaymentTimelinePaiement => 'Paiement';

  @override
  String get repaymentTimelineSolde => 'Solde restant';

  @override
  String get retroactive3aTitle => 'Rattrapage 3a';

  @override
  String get retroactive3aHeroTitle => 'Rattrapage 3a — Nouveauté 2026';

  @override
  String get retroactive3aHeroSubtitle =>
      'Rattrape jusqu’à 10 ans de cotisations manquées';

  @override
  String get retroactive3aParametres => 'Paramètres';

  @override
  String get retroactive3aAnneesARattraper => 'Années à rattraper';

  @override
  String get retroactive3aTauxMarginal => 'Taux marginal d’imposition';

  @override
  String get retroactive3aAffilieLpp => 'Affilié·e à une caisse LPP';

  @override
  String get retroactive3aPetit3a => 'Petit 3a : CHF 7’258/an';

  @override
  String get retroactive3aGrand3a =>
      'Grand 3a : 20 % du revenu net, max CHF 36’288/an';

  @override
  String get retroactive3aEconomiesFiscales => 'Économies fiscales estimées';

  @override
  String get retroactive3aDetailParAnnee => 'Détail par année';

  @override
  String get retroactive3aHeaderAnnee => 'Année';

  @override
  String get retroactive3aHeaderPlafond => 'Plafond';

  @override
  String get retroactive3aHeaderDeductible => 'Déductible';

  @override
  String get retroactive3aTotal => 'Total';

  @override
  String get retroactive3aAnneeCourante => 'Année en cours';

  @override
  String get retroactive3aImpactAvantApres => 'Impact avant / après';

  @override
  String get retroactive3aSansRattrapage => 'Sans rattrapage';

  @override
  String get retroactive3aAnneeCouranteSeule => 'Année courante seule';

  @override
  String get retroactive3aAvecRattrapage => 'Avec rattrapage';

  @override
  String get retroactive3aEconomieFiscale => 'd’économie fiscale';

  @override
  String get retroactive3aProchainesEtapes => 'Prochaines étapes';

  @override
  String get retroactive3aOuvrirCompte => 'Ouvrir un compte 3a';

  @override
  String get retroactive3aOuvrirCompteSubtitle =>
      'Compare les prestataires et ouvre un compte dédié au rattrapage.';

  @override
  String get retroactive3aPrepDocuments => 'Préparer les documents';

  @override
  String get retroactive3aPrepDocumentsSubtitle =>
      'Certificat de salaire, attestation de cotisations AVS, justificatif d’absence de 3a pour chaque année.';

  @override
  String get retroactive3aConsulterSpecialiste => 'Consulter un·e spécialiste';

  @override
  String get retroactive3aConsulterSpecialisteSubtitle =>
      'Un·e expert·e fiscal·e peut confirmer ton taux marginal et optimiser le calendrier de versement.';

  @override
  String get retroactive3aSources => 'Sources';

  @override
  String coverageCriticalGaps(Object count) {
    return 'lacune$count critique$count';
  }

  @override
  String get coverageCriticalGapSingular => 'lacune critique';

  @override
  String get coverageCriticalGapPlural => 'lacunes critiques';

  @override
  String get reportTonPlanMint => 'Ton Plan Mint';

  @override
  String get reportCommencer => 'Commencer';

  @override
  String get reportOptimise3a => 'Optimise ton 3a';

  @override
  String get reportActions => '🎯 Tes 3 Actions Prioritaires';

  @override
  String get reportMentionLegale => 'Mention légale';

  @override
  String get reportDisclaimerText =>
      'Outil éducatif — ne constitue pas un conseil financier au sens de la LSFin. Les montants sont des estimations basées sur les données déclarées.';

  @override
  String get compoundTitle => 'Intérêts Composés';

  @override
  String get compoundMentorTitle => 'L\'avis du Mentor';

  @override
  String get compoundMentorIntro => 'Comprendre l\'';

  @override
  String get compoundMentorOutro =>
      ', c\'est comprendre comment ton argent travaille pour toi pendant que tu dors.';

  @override
  String get compoundConfiguration => 'Configuration';

  @override
  String get compoundCapitalDepart => 'Capital de départ';

  @override
  String get compoundEpargneMensuelle => 'Épargne mensuelle';

  @override
  String get compoundTauxRendement => 'Taux (Rendement annuel)';

  @override
  String get compoundHorizonTemps => 'Horizon de temps';

  @override
  String get compoundValeurFinale => 'Valeur Finale Potentielle';

  @override
  String compoundGainsPercent(String percent) {
    return '$percent% de ce montant provient uniquement de tes gains de placement.';
  }

  @override
  String get compoundLeconsTitle => 'Leçons Méditées';

  @override
  String get compoundTempsRoi => 'Le temps est roi';

  @override
  String get compoundTempsRoiBody =>
      'Attendre 5 ans avant de commencer peut te faire perdre la moitié de ton capital final.';

  @override
  String get compoundEffetLevier => 'L\'effet de levier';

  @override
  String get compoundEffetLevierBody =>
      'Une fois lancé, ton capital génère ses propres intérêts, qui en génèrent d\'autres à leur tour.';

  @override
  String get compoundDiscipline => 'Discipline';

  @override
  String get compoundDisciplineBody =>
      'La régularité des versements mensuels est souvent plus efficace que la recherche du moment idéal pour investir.';

  @override
  String get compoundDisclaimer =>
      'Calcul théorique basé sur un rendement constant. Les performances passées ne constituent pas une assurance de résultat pour les résultats futurs.';

  @override
  String get leasingTitle => 'Analyse Anti-Leasing';

  @override
  String get leasingMentorTitle => 'Réflexion du Mentor';

  @override
  String get leasingMentorBody =>
      'Le leasing est souvent une \"fuite\" de capital. Cet argent pourrait servir à construire ton patrimoine plutôt qu\'à financer la dépréciation d\'un véhicule.';

  @override
  String get leasingDonneesContrat => 'Données du Contrat';

  @override
  String get leasingMensualitePrevue => 'Mensualité prévue';

  @override
  String get leasingDuree => 'Durée du leasing';

  @override
  String get leasingRendementAlternatif => 'Rendement alternatif espéré';

  @override
  String get leasingCoutOpportunite20 => 'Coût d\'opportunité sur 20 ans';

  @override
  String get leasingInvestirAuLieu =>
      'Si tu investissais cette mensualité au lieu de payer un leasing, voilà le capital que tu aurais construit.';

  @override
  String leasingFondsPropres(String amount) {
    return 'C\'est environ $amount de fonds propres pour un achat immobilier.';
  }

  @override
  String get leasingAlternativesTitle => 'S\'écarter du Trou Noir';

  @override
  String get leasingOccasion => 'Occasion de Qualité';

  @override
  String get leasingOccasionBody =>
      'Acheter cash une voiture de 3-4 ans réduit drastiquement la perte de valeur.';

  @override
  String get leasingAboGeneral => 'Abo Général / Transports';

  @override
  String get leasingAboGeneralBody =>
      'Le confort du train en Suisse est souvent plus rentable et serein.';

  @override
  String get leasingMobility => 'Mobility / Partage';

  @override
  String get leasingMobilityBody =>
      'Ne paie que quand tu roules. Pas d\'assurance, pas d\'entretien, pas de leasing.';

  @override
  String get leasingDisclaimer =>
      'Le leasing reste une option pour certains professionnels. Cette analyse vise à sensibiliser le particulier sur le coût à long terme.';

  @override
  String get creditTitle => 'Crédit à la Consommation';

  @override
  String get creditMentorTitle => 'Points d\'attention du Mentor';

  @override
  String get creditMentorBody =>
      'En Suisse, un crédit coûte entre 4% et 10%. Cet argent \"perdu\" en intérêts pourrait être investi pour ton avenir.';

  @override
  String get creditParametres => 'Paramètres';

  @override
  String get creditMontantEmprunter => 'Montant à emprunter';

  @override
  String get creditDureeRemboursement => 'Durée du remboursement';

  @override
  String get creditTauxAnnuel => 'Taux annuel effectif';

  @override
  String get creditTaMensualite => 'Ta Mensualité';

  @override
  String get creditCoutInterets => 'Coût des intérêts :';

  @override
  String get creditRateWarning =>
      'Attention : Ce taux dépasse le max légal suisse de 10%.';

  @override
  String get creditConseilsTitle => 'Conseils du Mentor';

  @override
  String get creditEpargnerDabord => 'Épargner d\'abord';

  @override
  String creditEpargnerDabordBody(String amount) {
    return 'En économisant pendant 12 mois au lieu d\'emprunter, tu gardes $amount dans ta poche.';
  }

  @override
  String get creditCercleConfiance => 'Cercle de confiance';

  @override
  String get creditCercleConfianceBody =>
      'Un prêt familial peut souvent être obtenu à 0% d\'intérêt.';

  @override
  String get creditDettesConseils => 'Dettes Conseils Suisse';

  @override
  String get creditDettesConseilsBody =>
      'Contacte-les AVANT de signer si ta situation est fragile.';

  @override
  String get creditDisclaimer =>
      'Information à but préventif. Ne constitue pas un conseil juridique ou financier. Loi suisse sur le crédit à la consommation (LCC) appliquée.';

  @override
  String get arbitrageBilanTitle => 'Bilan d\'arbitrage';

  @override
  String get arbitrageBilanEmptyProfile =>
      'Complète ton profil pour voir tes pistes d\'arbitrage';

  @override
  String get arbitrageBilanLeviers => 'Tes leviers d\'action';

  @override
  String arbitrageBilanPotentiel(String amount) {
    return '$amount/mois de potentiel identifié';
  }

  @override
  String get arbitrageBilanCaveat =>
      'Ces pistes ne s\'additionnent pas forcément — certaines sont liées entre elles.';

  @override
  String get arbitrageBilanDebloquer => 'Débloque d\'autres pistes';

  @override
  String get arbitrageBilanLiens => 'Liens entre ces pistes';

  @override
  String get arbitrageBilanScenario =>
      'Dans ce scénario simulé — à explorer en détail';

  @override
  String get arbitrageBilanDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil financier (LSFin). Sources : LPP art. 14, 79b / LIFD art. 22, 33, 38 / OPP3 art. 7.';

  @override
  String get arbitrageBilanCrossDep1 =>
      'Si tu retires ton LPP en capital, le calendrier de retraits change fondamentalement.';

  @override
  String get arbitrageBilanCrossDep2 =>
      'Un rachat LPP augmente aussi le capital disponible pour le choix rente vs capital.';

  @override
  String get annualRefreshSubtitle =>
      'Quelques questions rapides pour mettre ton profil à jour.';

  @override
  String get annualRefreshQ1 => 'Ton salaire brut mensuel a-t-il changé ?';

  @override
  String get annualRefreshQ2 => 'Ta situation professionnelle';

  @override
  String get annualRefreshQ3 => 'Ton avoir LPP actuel';

  @override
  String get annualRefreshQ3Help =>
      'Regarde ton certificat de prévoyance (tu le reçois chaque janvier)';

  @override
  String get annualRefreshQ4 => 'Ton solde 3a approximatif';

  @override
  String get annualRefreshQ4Help =>
      'Connecte-toi sur ton app 3a pour voir le solde exact';

  @override
  String get annualRefreshQ5 => 'Un projet immobilier en vue ?';

  @override
  String get annualRefreshQ6 => 'Un changement familial cette année ?';

  @override
  String get annualRefreshQ7 => 'Ta tolérance au risque';

  @override
  String annualRefreshScoreUp(int delta) {
    return 'Ton score a augmenté de $delta points !';
  }

  @override
  String annualRefreshScoreDown(int delta) {
    return 'Ton score a baissé de $delta points — vérifions ensemble';
  }

  @override
  String get annualRefreshScoreStable =>
      'Ton score est stable — continue comme ça !';

  @override
  String get annualRefreshRetour => 'Retour au dashboard';

  @override
  String get annualRefreshAvant => 'Avant';

  @override
  String get annualRefreshApres => 'Après';

  @override
  String get annualRefreshMontantPositif => 'Le montant doit être positif';

  @override
  String get annualRefreshMemeEmploi => 'Même emploi';

  @override
  String get annualRefreshNouvelEmploi => 'Nouvel emploi';

  @override
  String get annualRefreshIndependant => 'Indépendant·e';

  @override
  String get annualRefreshSansEmploi => 'Sans emploi';

  @override
  String get annualRefreshAucun => 'Aucun';

  @override
  String get annualRefreshAchat => 'Achat';

  @override
  String get annualRefreshVente => 'Vente';

  @override
  String get annualRefreshRefinancement => 'Refinancement';

  @override
  String get annualRefreshMariage => 'Mariage';

  @override
  String get annualRefreshNaissance => 'Naissance';

  @override
  String get annualRefreshDivorce => 'Divorce';

  @override
  String get annualRefreshDeces => 'Décès';

  @override
  String get annualRefreshConservateur => 'Conservateur';

  @override
  String get annualRefreshModere => 'Modéré';

  @override
  String get annualRefreshAgressif => 'Agressif';

  @override
  String get themeInconnu => 'Thème inconnu';

  @override
  String get themeInconnuBody => 'Ce thème n\'existe pas. Retour en arrière.';

  @override
  String get acceptInvitationVoirMenage => 'Voir mon ménage';

  @override
  String get helpResourceSiteWeb => 'Site web';

  @override
  String get locationProjetImmobilier => 'Ton projet immobilier';

  @override
  String get locationCapitalDispo => 'Capital disponible / fonds propres (CHF)';

  @override
  String get locationLoyerMensuel => 'Loyer mensuel actuel (CHF)';

  @override
  String get locationPrixBien => 'Prix du bien immobilier (CHF)';

  @override
  String get locationCanton => 'Canton';

  @override
  String get locationMarie => 'Marié·e';

  @override
  String get locationComparer => 'Comparer les trajectoires';

  @override
  String get locationLouerOuAcheter => 'Louer ou acheter ?';

  @override
  String get locationTrajectoires => 'Trajectoires comparées';

  @override
  String get locationToucheGraphique =>
      'Touche le graphique pour voir les valeurs à chaque année.';

  @override
  String get locationCapaciteFinma =>
      'Vérification de la capacité financière (FINMA)';

  @override
  String locationChargeTheorique(String amount) {
    return 'Charge théorique annuelle : $amount (taux théorique 5 % + amortissement 1 % + entretien 1 %). Les banques exigent que cette charge ne dépasse pas 1/3 de ton revenu brut annuel.';
  }

  @override
  String locationRevenuMinimum(String amount) {
    return 'Revenu brut minimum nécessaire : $amount';
  }

  @override
  String get locationHypotheses => 'Hypothèses utilisées';

  @override
  String get locationRendementMarche => 'Rendement marché';

  @override
  String get locationAppreciationImmo => 'Appréciation immobilière';

  @override
  String get locationTauxHypo => 'Taux hypothécaire';

  @override
  String get locationHorizon => 'Horizon';

  @override
  String get locationValeursProfil => 'Valeurs pré-remplies depuis ton profil';

  @override
  String get locationAvertissement => 'Avertissement';

  @override
  String reportBonjour(String name) {
    return 'Bonjour $name !';
  }

  @override
  String reportProfileSummary(int age, String canton, String civilStatus) {
    return '$age ans • $canton • $civilStatus';
  }

  @override
  String get reportStatusGood => 'Ta base est solide, continue ainsi !';

  @override
  String get reportStatusMedium => 'Quelques ajustements pour être serein';

  @override
  String get reportStatusLow => 'Priorité : stabilise ta situation';

  @override
  String get reportReasonDebt => 'Dette à la consommation active.';

  @override
  String get reportReasonLeasing => 'Leasing actif avec charge mensuelle.';

  @override
  String reportReasonPayments(String amount) {
    return 'Remboursements de dette : CHF $amount / mois.';
  }

  @override
  String get reportReasonEmergency =>
      'Fonds d\'urgence insuffisant (< 3 mois).';

  @override
  String get reportReasonFragility =>
      'Signal de fragilité détecté : priorité à la stabilité budgétaire.';

  @override
  String get reportBudgetTitle => 'Ton Budget';

  @override
  String get reportBudgetKeyLabel => 'Reste à vivre (après fixes)';

  @override
  String get reportBudgetAction => 'Configurer mes enveloppes';

  @override
  String get reportProtectionTitle => 'Ta Protection';

  @override
  String get reportProtectionKeyLabel => 'Fonds d\'urgence (cible : 6 mois)';

  @override
  String get reportProtectionSource => 'Source : LP art. 93 — Minimum vital';

  @override
  String get reportProtectionAction => 'Constituer mon fonds d\'urgence';

  @override
  String get reportRetirementTitle => 'Ta Retraite';

  @override
  String get reportRetirementKeyLabel => 'Revenu estimé à 65 ans';

  @override
  String get reportRetirementSource => 'Sources : LPP art. 14, OPP3, LAVS';

  @override
  String get reportRetirement3aNone =>
      'Pas encore de 3a — jusqu\'à CHF 7’258/an de déduction fiscale possible';

  @override
  String get reportRetirement3aOne =>
      '1 compte 3a — ouvre un 2e pour optimiser le retrait';

  @override
  String reportRetirement3aMulti(int count) {
    return '$count comptes 3a — bonne diversification';
  }

  @override
  String reportRetirementLppText(String available, String savings) {
    return 'Rachat LPP disponible : CHF $available — économie fiscale estimée : CHF $savings';
  }

  @override
  String get reportTaxTitle => 'Tes Impôts';

  @override
  String reportTaxKeyLabel(String rate) {
    return 'Impôts estimés (taux effectif : $rate %)';
  }

  @override
  String get reportTaxAction => 'Comparer 26 cantons';

  @override
  String get reportTaxSource => 'Source : LIFD art. 33';

  @override
  String get reportTaxIncome => 'Revenu imposable';

  @override
  String get reportTaxDeductions => 'Déductions';

  @override
  String get reportTaxEstimated => 'Impôts estimés';

  @override
  String reportTaxSavings(String amount) {
    return 'Économie possible avec rachat LPP : CHF $amount/an';
  }

  @override
  String get reportSafeModePriority => 'Priorité au désendettement';

  @override
  String get reportSafeModeActions =>
      'Tes actions prioritaires sont remplacées par un plan de désendettement. Stabilise ta situation avant d\'explorer les recommandations.';

  @override
  String get reportSafeMode3a =>
      'Le comparateur 3a est désactivée tant que tu as des dettes actives. Rembourser tes dettes est prioritaire avant toute épargne 3a.';

  @override
  String get reportSafeModeLpp => 'Rachat LPP bloqué';

  @override
  String get reportSafeModeLppMessage =>
      'Le rachat LPP est désactivé en mode protection. Rembourser tes dettes avant de bloquer de la liquidité dans la prévoyance.';

  @override
  String get reportLppTitle => '💰 Stratégie Rachat LPP';

  @override
  String reportLppEconomie(String amount) {
    return 'Économie fiscale totale : CHF $amount';
  }

  @override
  String reportLppYear(int year) {
    return 'Année $year';
  }

  @override
  String reportLppBuyback(String amount) {
    return 'Rachat : CHF $amount';
  }

  @override
  String reportLppSaving(String amount) {
    return 'Économie : CHF $amount';
  }

  @override
  String get reportLppHowTitle => 'Comment ça marche ?';

  @override
  String get reportLppHowBody =>
      'Comprends pourquoi échelonner tes rachats LPP te fait économiser des milliers de francs supplémentaires.';

  @override
  String get reportSoaTitle => 'Transparence et conformité';

  @override
  String get reportSoaNature => 'Nature du service';

  @override
  String reportSoaEduPhases(int count) {
    return 'Éducation financière — $count phases identifiées';
  }

  @override
  String get reportSoaEduSimple => 'Éducation financière personnalisée';

  @override
  String get reportSoaHypotheses => 'Hypothèses de travail';

  @override
  String get reportSoaHyp1 => 'Revenus déclarés stables sur la période';

  @override
  String get reportSoaHyp2 => 'Taux de conversion LPP obligatoire : 6.8 %';

  @override
  String get reportSoaHyp3 => 'Plafond 3a salarié : 7’258 CHF/an';

  @override
  String get reportSoaHyp4 => 'Rente AVS maximale : 30’240 CHF/an';

  @override
  String get reportSoaConflicts => 'Conflits d\'intérêts';

  @override
  String get reportSoaNoConflict =>
      'Aucun conflit d\'intérêt identifié pour ce rapport.';

  @override
  String get reportSoaNoCommission =>
      'MINT ne perçoit aucune commission sur les produits mentionnés.';

  @override
  String get reportSoaLimitations => 'Limitations';

  @override
  String get reportSoaLim1 =>
      'Basé sur les informations déclaratives uniquement';

  @override
  String get reportSoaLim2 =>
      'Estimation fiscale approximative (taux moyens cantonaux)';

  @override
  String get reportSoaLim3 =>
      'Ne prend pas en compte les revenus de fortune mobilière';

  @override
  String get reportSoaLim4 =>
      'Les projections ne tiennent pas compte de l\'inflation';

  @override
  String get checkinEvolution => 'Ton évolution';

  @override
  String get portfolioReadinessTitle => 'Readiness Index (Milestones)';

  @override
  String get portfolioPerennite => 'Pérennité Retraite';

  @override
  String get portfolioProjetImmo => 'Projet Immobilier';

  @override
  String get portfolioProtectionFamille => 'Protection Famille';

  @override
  String get portfolioAllocationSaine =>
      'Ton allocation est saine. Pense à rééquilibrer ton 3a prochainement.';

  @override
  String get portfolioAlerteDettes =>
      'Alerte Dettes : Ta priorité absolue est le désendettement avant tout réinvestissement.';

  @override
  String get dividendeSplitMin => '0% salaire';

  @override
  String get dividendeSplitMax => '100% salaire';

  @override
  String get disabilityInsAppBarTitle => 'Ma couverture';

  @override
  String get disabilityInsTitle => 'Ma couverture invalidité';

  @override
  String get disabilityInsSubtitle =>
      'Bulletin scolaire · Franchise LAMal · AI/APG';

  @override
  String get disabilityInsRefineSituation => 'Affine ta situation';

  @override
  String get disabilityInsGrossSalary => 'Salaire brut mensuel';

  @override
  String get disabilityInsSavings => 'Épargne disponible';

  @override
  String get disabilityInsIjmEmployer => 'IJM via mon employeur';

  @override
  String get disabilityInsPrivateLossInsurance =>
      'Assurance perte de gain privée';

  @override
  String get disabilityInsDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil en assurance. Les montants de franchise et primes sont indicatifs. Compare les offres sur comparaison.ch ou via un·e courtier·ère indépendant·e.';

  @override
  String get disabilityInsSources =>
      '• LAMal art. 64-64a (franchise)\n• OAMal art. 93 (primes)\n• LAI art. 28 (rente AI)\n• LPP art. 23-26 (invalidité 2e pilier)';

  @override
  String repaymentDiffStrategies(String amount) {
    return 'Différence entre les deux stratégies : CHF $amount';
  }

  @override
  String get repaymentAddDebtHint =>
      'Ajoutez vos dettes pour générer un plan de remboursement.';

  @override
  String get repaymentAddDebtTooltip => 'Ajouter une dette';

  @override
  String get repaymentDebtNameHint => 'Nom de la dette';

  @override
  String get repaymentFieldAmount => 'Montant';

  @override
  String get repaymentFieldAmountLabel => 'Montant de la dette';

  @override
  String get repaymentFieldRate => 'Taux';

  @override
  String get repaymentFieldRateLabel => 'Taux annuel';

  @override
  String get repaymentFieldInstallment => 'Mensualité';

  @override
  String get repaymentFieldInstallmentLabel => 'Mensualité minimum';

  @override
  String get repaymentNewDebt => 'Nouvelle dette';

  @override
  String get repaymentBudgetEditorLabel => 'Budget mensuel de remboursement';

  @override
  String repaymentBudgetDisplay(String amount) {
    return 'CHF $amount / mois';
  }

  @override
  String get repaymentAvalancheTitle => 'AVALANCHE';

  @override
  String get repaymentAvalancheSubtitle => 'Taux haut d\'abord';

  @override
  String get repaymentAvalanchePro => 'Moins d\'intérêts payés';

  @override
  String get repaymentSnowballTitle => 'BOULE DE NEIGE';

  @override
  String get repaymentSnowballSubtitle => 'Petit solde d\'abord';

  @override
  String get repaymentSnowballPro => 'Motivation par petites victoires';

  @override
  String get repaymentRowLiberation => 'Date libération';

  @override
  String get repaymentRowInterets => 'Intérêts totaux';

  @override
  String repaymentDifference(String amount) {
    return 'Différence : CHF $amount';
  }

  @override
  String get repaymentValidate => 'Valider';

  @override
  String get repaymentEmptyState =>
      'Ajoutez vos dettes et définissez votre budget mensuel de remboursement pour voir le plan.';

  @override
  String repaymentMinMax(String minVal, String maxVal) {
    return 'Min $minVal · Max $maxVal';
  }

  @override
  String repaymentInteretsDisplay(String amount) {
    return 'CHF $amount intérêts';
  }

  @override
  String repaymentDurationDisplay(int months) {
    return '$months mois';
  }

  @override
  String get debtRatioLevelSain => 'SAIN';

  @override
  String get debtRatioLevelAttention => 'ATTENTION';

  @override
  String get debtRatioLevelCritique => 'CRITIQUE';

  @override
  String get debtRatioRevenuNet => 'Revenu net';

  @override
  String get debtRatioChargesDette => 'Charges dette';

  @override
  String get debtRatioLoyer => 'Loyer';

  @override
  String get debtRatioAutresCharges => 'Autres charges';

  @override
  String get debtRatioRefineSuffix => 'Loyer, situation, enfants';

  @override
  String get debtRatioSituation => 'Situation';

  @override
  String get debtRatioSeul => 'Seul·e';

  @override
  String get debtRatioEnCouple => 'En couple';

  @override
  String get debtRatioEnfants => 'Enfants';

  @override
  String get debtRatioMinimumVitalLabel => 'Minimum vital';

  @override
  String get debtRatioMargeDisponible => 'Marge disponible';

  @override
  String get debtRatioMinVitalWarning =>
      'Votre marge résiduelle est inférieure au minimum vital. Contactez un service d\'aide professionnelle.';

  @override
  String get debtRatioCtaSemantics => 'Créer un plan de remboursement';

  @override
  String get debtRatioCtaDescription =>
      'Compare avalanche et boule de neige pour rembourser plus vite.';

  @override
  String get debtRatioDetteConseilNom => 'Dettes Conseils Suisse';

  @override
  String get debtRatioDetteConseilDesc => 'Conseil gratuit et confidentiel';

  @override
  String get debtRatioCaritasNom => 'Caritas — Aide aux dettes';

  @override
  String get debtRatioCaritasDesc => 'Aide au désendettement et négociation';

  @override
  String get debtRatioValidate => 'Valider';

  @override
  String debtRatioMinMaxDisplay(String minVal, String maxVal) {
    return 'Min $minVal · Max $maxVal';
  }

  @override
  String get timelineCatFamille => 'FAMILLE';

  @override
  String get timelineCatProfessionnel => 'PROFESSIONNEL';

  @override
  String get timelineCatPatrimoine => 'PATRIMOINE';

  @override
  String get timelineCatSante => 'SANTÉ';

  @override
  String get timelineCatMobilite => 'MOBILITÉ';

  @override
  String get timelineCatCrise => 'CRISE';

  @override
  String get timelineSectionTitleUpper => 'ÉVÉNEMENTS DE VIE';

  @override
  String get timelineEventMariageTitle => 'Mariage';

  @override
  String get timelineEventMariageSub =>
      'Impact LPP, AVS, impôts et régime matrimonial';

  @override
  String get timelineEventConcubinageTitle => 'Concubinage';

  @override
  String get timelineEventConcubitageSub =>
      'Prévoyance, succession et fiscalité du couple non marié';

  @override
  String get timelineEventNaissanceTitle => 'Naissance';

  @override
  String get timelineEventNaissanceSub =>
      'Allocations, déductions fiscales et assurances';

  @override
  String get timelineEventDivorceTitle => 'Divorce';

  @override
  String get timelineEventDivorceSub =>
      'Partage LPP, pension et réorganisation financière';

  @override
  String get timelineEventSuccessionTitle => 'Succession';

  @override
  String get timelineEventSuccessionSub =>
      'Réserves héréditaires, partage et impôts (CC art. 457ss)';

  @override
  String get timelineEventPremierEmploiTitle => 'Premier emploi';

  @override
  String get timelineEventPremierEmploiSub =>
      'Premiers pas : AVS, LPP, 3a et budget';

  @override
  String get timelineEventChangementEmploiTitle => 'Changement d\'emploi';

  @override
  String get timelineEventChangementEmploiSub =>
      'Comparaison LPP, libre passage et négociation';

  @override
  String get timelineEventIndependantTitle => 'Indépendant';

  @override
  String get timelineEventIndependantSub =>
      'AVS, LPP volontaire, 3a élargi et dividende vs salaire';

  @override
  String get timelineEventPerteEmploiTitle => 'Perte d\'emploi';

  @override
  String get timelineEventPerteEmploiSub =>
      'Chômage, délai de carence et protection prévoyance';

  @override
  String get timelineEventRetraiteTitle => 'Retraite';

  @override
  String get timelineEventRetraiteSub =>
      'Rente vs capital, échelonnement 3a, lacune AVS';

  @override
  String get timelineEventAchatImmoTitle => 'Achat immobilier';

  @override
  String get timelineEventAchatImmoSub =>
      'Capacité d\'emprunt, EPL et impôt sur la valeur locative';

  @override
  String get timelineEventVenteImmoTitle => 'Vente immobilière';

  @override
  String get timelineEventVenteImmoSub =>
      'Plus-value, impôt cantonal et remploi';

  @override
  String get timelineEventHeritageTitle => 'Héritage';

  @override
  String get timelineEventHeritageSub =>
      'Estimation, impôt cantonal et partage successoral';

  @override
  String get timelineEventDonationTitle => 'Donation';

  @override
  String get timelineEventDonationSub =>
      'Impôt cantonal, réserves et quotité disponible';

  @override
  String get timelineEventInvaliditeTitle => 'Invalidité';

  @override
  String get timelineEventInvaliditeSub =>
      'Lacune de couverture AI + LPP et prévention';

  @override
  String get timelineEventDemenagementTitle => 'Déménagement cantonal';

  @override
  String get timelineEventDemenagementSub =>
      'Impact fiscal du changement de canton (26 barèmes)';

  @override
  String get timelineEventExpatriationTitle => 'Expatriation / Frontalier';

  @override
  String get timelineEventExpatriationSub =>
      'Double imposition, 3a et couverture sociale';

  @override
  String get timelineEventSurendettementTitle => 'Surendettement';

  @override
  String get timelineEventSurendettementSub =>
      'Ratio d\'endettement, plan de remboursement et aide';

  @override
  String get timelineQuickCheckupTitle => 'Check-up financier';

  @override
  String get timelineQuickCheckupSub => 'Lancer le diagnostic complet';

  @override
  String get timelineQuickBudgetTitle => 'Budget';

  @override
  String get timelineQuickBudgetSub => 'Gérer le cashflow mensuel';

  @override
  String get timelineQuickPilier3aTitle => 'Pilier 3a';

  @override
  String get timelineQuickPilier3aSub => 'Optimiser la déduction fiscale';

  @override
  String get timelineQuickFiscaliteTitle => 'Fiscalité';

  @override
  String get timelineQuickFiscaliteSub => 'Comparer 26 cantons';

  @override
  String get consentFinmaTitle => 'Fonctionnalité en préparation';

  @override
  String get consentFinmaDesc =>
      'Consultation réglementaire FINMA en cours. Les données affichées sont des exemples de démonstration.';

  @override
  String get consentModeDemo => 'MODE DÉMO';

  @override
  String get consentActiveSection => 'CONSENTEMENTS ACTIFS';

  @override
  String get consentAutorisations => 'Autorisations';

  @override
  String consentGrantedAtLabel(String date) {
    return 'Accordé le $date';
  }

  @override
  String consentExpiresAtLabel(String date) {
    return 'Expire le $date';
  }

  @override
  String get consentRevokedLabel => 'Consentement révoqué';

  @override
  String get consentNlpdTitle => 'Tes droits (nLPD)';

  @override
  String get consentNlpdSubtitle =>
      'Tes droits selon la nLPD (Loi fédérale sur la protection des données) :';

  @override
  String get consentNlpdPoint1 =>
      '• Tu peux révoquer ton consentement à tout moment';

  @override
  String get consentNlpdPoint2 =>
      '• Tes données ne sont jamais partagées avec des tiers';

  @override
  String get consentNlpdPoint3 =>
      '• Accès en lecture seule — aucune opération financière';

  @override
  String get consentNlpdPoint4 =>
      '• Durée maximale de consentement : 90 jours (renouvelable)';

  @override
  String get consentStepBanque => 'Banque';

  @override
  String get consentStepAutorisations => 'Autorisations';

  @override
  String get consentStepConfirmation => 'Confirmation';

  @override
  String get consentSelectBankTitle => 'Choisir une banque';

  @override
  String get consentSelectScopesTitle => 'Choisir les autorisations';

  @override
  String consentSelectedBankLabel(String bank) {
    return 'Banque sélectionnée : $bank';
  }

  @override
  String get consentScopeAccountsDesc => 'Comptes (liste de tes comptes)';

  @override
  String get consentScopeBalancesDesc => 'Soldes (solde actuel de tes comptes)';

  @override
  String get consentScopeTransactionsDesc =>
      'Transactions (historique des mouvements)';

  @override
  String get consentReadOnlyInfo =>
      'Accès en lecture seule. Aucune opération financière ne peut être effectuée.';

  @override
  String get consentConfirmTitle => 'Confirmation';

  @override
  String get consentConfirmBanque => 'Banque';

  @override
  String get consentConfirmAutorisations => 'Autorisations';

  @override
  String get consentConfirmDuree => 'Durée';

  @override
  String get consentConfirmDureeValue => '90 jours';

  @override
  String get consentConfirmAcces => 'Accès';

  @override
  String get consentConfirmAccesValue => 'Lecture seule';

  @override
  String get consentConfirmDisclaimer =>
      'En confirmant, tu autorises MINT à accéder aux données sélectionnées en lecture seule pour une durée de 90 jours. Tu peux révoquer ce consentement à tout moment.';

  @override
  String get consentAnnuler => 'Annuler';

  @override
  String get consentScopeComptes => 'Comptes';

  @override
  String get consentScopeSoldes => 'Soldes';

  @override
  String get consentScopeTransactions => 'Transactions';

  @override
  String get consentStatusActif => 'Actif';

  @override
  String get consentStatusExpirantBientot => 'Expire bientôt';

  @override
  String get consentStatusExpire => 'Expiré';

  @override
  String get consentStatusRevoque => 'Révoqué';

  @override
  String get consentStatusInconnu => 'Inconnu';

  @override
  String get consentDisclaimer =>
      'Cette fonctionnalité est en cours de développement. Les données affichées sont des exemples. L\'activation du service Open Banking est soumise à une consultation réglementaire préalable.';

  @override
  String get openBankingHubFinmaTitle => 'Fonctionnalité en préparation';

  @override
  String get openBankingHubFinmaDesc =>
      'Consultation réglementaire FINMA en cours. Les données affichées sont des exemples de démonstration.';

  @override
  String get openBankingHubSubtitle => 'Connecte tes comptes bancaires';

  @override
  String get openBankingHubConnectedAccounts => 'COMPTES CONNECTES';

  @override
  String get openBankingHubApercu => 'APERCU FINANCIER';

  @override
  String get openBankingHubNavigation => 'NAVIGATION';

  @override
  String get openBankingHubViewTransactions => 'Voir les transactions';

  @override
  String get openBankingHubViewTransactionsDesc =>
      'Historique détaillé par catégorie';

  @override
  String get openBankingHubManageConsents => 'Gérer les consentements';

  @override
  String get openBankingHubManageConsentsDesc =>
      'Droits nLPD, révocation, scopes';

  @override
  String get openBankingHubSoldeTotal => 'Solde total';

  @override
  String get openBankingHubComptesConnectes => '3 comptes connectés';

  @override
  String get openBankingHubRevenus => 'Revenus';

  @override
  String get openBankingHubDepenses => 'Dépenses';

  @override
  String get openBankingHubEpargneNette => 'Épargne nette';

  @override
  String get openBankingHubTop3Depenses => 'Top 3 dépenses';

  @override
  String get openBankingHubAddBankLabel => 'Ajouter une banque';

  @override
  String openBankingHubSyncMinutes(int minutes) {
    return 'Il y a $minutes min';
  }

  @override
  String openBankingHubSyncHours(int hours) {
    return 'Il y a ${hours}h';
  }

  @override
  String openBankingHubSyncDays(int days) {
    return 'Il y a ${days}j';
  }

  @override
  String get transactionListFinmaTitle => 'Fonctionnalité en préparation';

  @override
  String get transactionListFinmaDesc =>
      'Consultation réglementaire FINMA en cours. Les données affichées sont des exemples de démonstration.';

  @override
  String get transactionListThisMonth => 'Ce mois';

  @override
  String get transactionListLastMonth => 'Mois précédent';

  @override
  String get transactionListNoTransaction => 'Aucune transaction';

  @override
  String get transactionListRevenus => 'Revenus';

  @override
  String get transactionListDepenses => 'Dépenses';

  @override
  String get transactionListEpargneNette => 'Épargne nette';

  @override
  String get transactionListTauxEpargne => 'Taux d’épargne';

  @override
  String get transactionListModeDemo => 'MODE DÉMO';

  @override
  String get lppVolontaireRevenuMax250k => 'CHF 250’000';

  @override
  String get lppVolontaireSalaireCoordLabel => 'Salaire coordonné';

  @override
  String get lppVolontaireTauxBonifLabel => 'Taux bonification';

  @override
  String get lppVolontaireCotisationLabel => 'Cotisation /an';

  @override
  String get lppVolontaireEconomieFiscaleLabel => 'Économie fiscale /an';

  @override
  String get lppVolontaireTrancheAgeLabel => 'Tranche d’âge';

  @override
  String get lppVolontaireCHF0 => 'CHF 0';

  @override
  String get lppVolontaireTaux10 => '10 %';

  @override
  String get lppVolontaireTaux45 => '45 %';

  @override
  String get pillar3aIndepPlafondApplicableLabel => 'Plafond applicable';

  @override
  String get pillar3aIndepEconomieFiscaleAnLabel => 'Économie fiscale /an';

  @override
  String get pillar3aIndepPlafondSalarieLabel => 'Plafond salarié·e';

  @override
  String get pillar3aIndepEconomieSalarieLabel => 'Économie salarié·e';

  @override
  String get pillar3aIndepCHF0 => 'CHF 0';

  @override
  String get pillar3aIndepTaux10 => '10 %';

  @override
  String get pillar3aIndepTaux45 => '45 %';

  @override
  String get actionSuccessNext => 'La suite';

  @override
  String get actionSuccessDone => 'Compris';

  @override
  String get dividendeBeneficeTotal => 'Bénéfice total';

  @override
  String get dividendePartSalaire => 'Part salaire';

  @override
  String get dividendeTauxMarginal => 'Taux marginal d\'imposition';

  @override
  String get successionUrgence => 'Urgence immédiate';

  @override
  String get successionDemarches => 'Démarches administratives';

  @override
  String get successionLegale => 'Succession légale';

  @override
  String get disabilityGapEmployerSub =>
      'CO art. 324a — 3 à 26 semaines selon ancienneté';

  @override
  String get disabilityGapAiDelaySub =>
      'Délai moyen décision AI : 14 mois · LAI art. 28 + LPP art. 23';

  @override
  String get indepCaisseLpp => 'Caisse LPP facultative';

  @override
  String get indepCaisseLppSub => 'Protection rente invalidité + retraite';

  @override
  String get indepGrand3a => 'Grand 3a (sans LPP)';

  @override
  String get indepAdminUrgent => 'Administratif urgent';

  @override
  String get indepPrevoyance => 'Prévoyance';

  @override
  String get indepOptiFiscale => 'Optimisation fiscale';

  @override
  String get fhsLevelExcellent => 'Excellent';

  @override
  String get fhsLevelBon => 'Bon';

  @override
  String get fhsLevelAmeliorer => 'À améliorer';

  @override
  String get fhsLevelCritique => 'Critique';

  @override
  String fhsDeltaLabel(String delta) {
    return 'Tendance : $delta vs hier';
  }

  @override
  String fhsDeltaText(String delta) {
    return '$delta vs hier';
  }

  @override
  String get fhsBreakdownLiquidite => 'Liquidité';

  @override
  String get fhsBreakdownFiscalite => 'Fiscalité';

  @override
  String get fhsBreakdownRetraite => 'Retraite';

  @override
  String get fhsBreakdownRisque => 'Risque';

  @override
  String avsGapLifetimeLoss(String amount) {
    return 'Sur 20 ans de retraite, c\'est $amount de moins — définitivement.';
  }

  @override
  String get avsGapCalculation =>
      'Calcul : rente mensuelle × 13 mois/an (13ᵉ rente AVS dès déc. 2026)';

  @override
  String get chiffreChocRenteCalculation =>
      '(calcul : rente mensuelle × 13 mois/an, 13ᵉ rente incluse).';

  @override
  String get coachBriefingFallbackGreeting => 'Bonjour';

  @override
  String get coachBriefingBadgeLlm => 'Coach IA';

  @override
  String get coachBriefingBadge => 'Coach';

  @override
  String coachBriefingConfidenceLow(String score) {
    return 'Confiance $score % — Enrichir';
  }

  @override
  String coachBriefingConfidence(String score) {
    return 'Confiance $score %';
  }

  @override
  String coachBriefingImpactEstimated(String amount) {
    return 'Impact estimé : CHF $amount';
  }

  @override
  String get chiffreChocSectionDisclaimer =>
      'Simulation à titre éducatif uniquement. Ne constitue pas un conseil en placement ou prévoyance (LSFin). Hypothèses modifiables — résultats non assurés.';

  @override
  String get concubinageTabProtection => 'Protection';

  @override
  String concubinageHeroChiffreChoc(String montant) {
    return 'CHF $montant de patrimoine exposé';
  }

  @override
  String get concubinageHeroChiffreChocDesc =>
      'En concubinage, ton partenaire n’est pas héritier légal. Sans testament, ce montant lui échappe entièrement.';

  @override
  String get concubinageEducationalAvs =>
      'En Suisse, le plafond de 150 % sur les rentes AVS de couple (LAVS art. 35) ne s’applique qu’aux mariés. Les concubins touchent chacun leur rente individuelle complète — un avantage réel quand les deux ont cotisé au maximum.';

  @override
  String get concubinageEducationalLpp =>
      'La rente LPP de survivant (60 % de la rente du défunt, LPP art. 19) est réservée aux époux. En concubinage, seul le règlement de la caisse peut prévoir un capital décès — et il faut en faire la demande.';

  @override
  String get concubinageEducationalSuccession =>
      'Un conjoint marié est exonéré d’impôt successoral dans la plupart des cantons (CC art. 462). Un concubin paie l’impôt au taux des tiers, souvent entre 20 % et 40 %.';

  @override
  String get concubinageProtectionIntro =>
      'En concubinage, la Suisse ne protège pas comme le mariage. Voici ce qui change et ce que tu peux anticiper.';

  @override
  String get concubinageProtectionAvsSurvivor => 'Rente AVS de survivant';

  @override
  String get concubinageProtectionAvsSurvivorMarried =>
      '80 % de la rente du défunt (LAVS art. 23)';

  @override
  String get concubinageProtectionAvsSurvivorConcubin =>
      'Aucune rente — 0 CHF/mois';

  @override
  String get concubinageProtectionLppSurvivor => 'Rente LPP de survivant';

  @override
  String get concubinageProtectionLppSurvivorMarried =>
      '60 % de la rente du défunt (LPP art. 19)';

  @override
  String get concubinageProtectionLppSurvivorConcubin =>
      'Selon règlement caisse uniquement';

  @override
  String get concubinageProtectionHeritage => 'Héritage légal';

  @override
  String get concubinageProtectionHeritageMarried => 'Exonéré (CC art. 462)';

  @override
  String get concubinageProtectionHeritageConcubin =>
      'Impôt cantonal (20-40 %)';

  @override
  String get concubinageProtectionPension => 'Pension alimentaire';

  @override
  String get concubinageProtectionPensionMarried => 'Protégée par le juge';

  @override
  String get concubinageProtectionPensionConcubin => 'Aucune obligation légale';

  @override
  String get concubinageProtectionAvsPlafond => 'Plafond AVS couple';

  @override
  String get concubinageProtectionAvsPlafondMarried =>
      '150 % max (LAVS art. 35)';

  @override
  String get concubinageProtectionAvsPlafondConcubin =>
      'Pas de plafond — 2×100 %';

  @override
  String get concubinageProtectionMaried => 'Marié';

  @override
  String get concubinageProtectionConcubinLabel => 'Concubin';

  @override
  String get concubinageProtectionWarning =>
      'En concubinage, si ton partenaire décède, tu ne reçois ni rente AVS, ni rente LPP automatique, et tu n’es pas héritier légal. Chaque protection doit être anticipée.';

  @override
  String get concubinageProtectionLppSlider =>
      'Rente LPP mensuelle du partenaire';

  @override
  String concubinageProtectionSurvivorTotal(String montant) {
    return '$montant/mois pour le conjoint survivant marié';
  }

  @override
  String get concubinageProtectionSurvivorZero =>
      'CHF 0/mois pour le concubin survivant sans démarche';

  @override
  String get concubinageDecisionMatrixTitle => 'Mariage vs Concubinage';

  @override
  String get concubinageDecisionMatrixSubtitle =>
      'Comparaison des droits et obligations';

  @override
  String get concubinageDecisionMatrixColumnMarriage => 'Mariage';

  @override
  String get concubinageDecisionMatrixColumnConcubinage => 'Concubinage';

  @override
  String get concubinageDecisionMatrixConclusionTitle => 'Conclusion neutre';

  @override
  String get concubinageDecisionMatrixConclusionDesc =>
      'Le choix dépend de ta situation personnelle. Consulte un·e notaire pour une analyse complète.';

  @override
  String get mortgageJourneyTitle => 'Parcours achat immobilier';

  @override
  String get mortgageJourneySubtitle =>
      '7 étapes pour passer de « est-ce que je peux ? » à « j\'ai signé ! »';

  @override
  String get mortgageJourneyPrevious => 'Précédent';

  @override
  String get mortgageJourneyNextStep => 'Étape suivante';

  @override
  String get mortgageJourneyComplete => '✅ Parcours complet !';

  @override
  String get clause3aTitle => 'La clause 3a oubliée';

  @override
  String get clause3aQuestion => 'As-tu déposé une clause bénéficiaire ?';

  @override
  String get clause3aStepsTitle => 'Comment déposer une clause en 5 minutes :';

  @override
  String clause3aFeedbackOk(String partner) {
    return 'Bien ! Vérifie que la clause désigne bien $partner — et qu’elle est à jour après chaque événement de vie.';
  }

  @override
  String get clause3aFeedbackNok =>
      'Action prioritaire : dépose ta clause bénéficiaire auprès de ta fondation 3a — en 5 minutes.';

  @override
  String get fiscalSuperpowerTitle => 'Le super-pouvoir fiscal';

  @override
  String get fiscalSuperpowerSubtitle =>
      'L’État te rend de l’argent pour avoir un enfant.';

  @override
  String get fiscalSuperpowerTaxBenefits => 'Tes avantages fiscaux';

  @override
  String get babyCostTitle => 'Le coût du bonheur';

  @override
  String get babyCostBreakdownTitle => 'Décomposition mensuelle';

  @override
  String get lifeEventSheetTitle => 'Il m’arrive quelque chose';

  @override
  String get lifeEventSheetSubtitle =>
      'Choisis un événement pour voir l’impact financier';

  @override
  String get lifeEventSheetSectionFamille => 'Famille';

  @override
  String get lifeEventSheetSectionPro => 'Professionnel';

  @override
  String get lifeEventSheetSectionPatrimoine => 'Patrimoine';

  @override
  String get lifeEventSheetSectionMobilite => 'Mobilité';

  @override
  String get lifeEventSheetSectionSante => 'Santé';

  @override
  String get lifeEventSheetSectionCrise => 'Crise';

  @override
  String get lifeEventLabelMariage => 'Je me marie';

  @override
  String get lifeEventLabelDivorce => 'Je divorce';

  @override
  String get lifeEventLabelNaissance => 'J’attends un enfant';

  @override
  String get lifeEventLabelConcubinage => 'On vit ensemble';

  @override
  String get lifeEventLabelDeces => 'Décès d’un proche';

  @override
  String get lifeEventLabelPremierEmploi => 'Premier emploi';

  @override
  String get lifeEventLabelNouveauJob => 'Nouveau job';

  @override
  String get lifeEventLabelIndependant => 'Je me mets à mon compte';

  @override
  String get lifeEventLabelPerteEmploi => 'Perte d’emploi';

  @override
  String get lifeEventLabelRetraite => 'Je pars à la retraite';

  @override
  String get lifeEventLabelAchatImmo => 'Achat immobilier';

  @override
  String get lifeEventLabelVenteImmo => 'Vente immobilière';

  @override
  String get lifeEventLabelHeritage => 'Je reçois un héritage';

  @override
  String get lifeEventLabelDonation => 'Je veux donner à mes enfants';

  @override
  String get lifeEventLabelDemenagement => 'Déménagement de canton';

  @override
  String get lifeEventLabelExpatriation => 'Je pars à l’étranger';

  @override
  String get lifeEventLabelInvalidite => 'Suis-je bien couvert·e ?';

  @override
  String get lifeEventLabelDettes => 'J’ai des dettes';

  @override
  String get lifeEventPromptMariage =>
      'Je me marie — quel impact sur mes impôts, mon AVS et ma prévoyance ?';

  @override
  String get lifeEventPromptDivorce =>
      'Je divorce — que se passe-t-il avec la LPP et les impôts ?';

  @override
  String get lifeEventPromptNaissance =>
      'J’attends un enfant — quelles aides et déductions sont disponibles ?';

  @override
  String get lifeEventPromptConcubinage =>
      'On n’est pas mariés — comment se protéger en cas de pépin ?';

  @override
  String get lifeEventPromptDeces =>
      'Décès d’un proche — quelles démarches financières dois-je faire ?';

  @override
  String get lifeEventPromptPremierEmploi =>
      'C’est mon premier job — que dois-je savoir sur ma prévoyance et mes cotisations ?';

  @override
  String get lifeEventPromptNouveauJob =>
      'Je change d’emploi — comment comparer les offres et gérer mon libre passage ?';

  @override
  String get lifeEventPromptIndependant =>
      'Je me mets à mon compte — quelles options de prévoyance sans LPP ?';

  @override
  String get lifeEventPromptPerteEmploi =>
      'J’ai perdu mon emploi — quelles sont mes indemnités et combien de temps ?';

  @override
  String get lifeEventPromptRetraite =>
      'Quand puis-je partir à la retraite et combien vais-je toucher ?';

  @override
  String get lifeEventPromptAchatImmo =>
      'Est-ce que je peux acheter un bien immobilier avec mes revenus et mon apport ?';

  @override
  String get lifeEventPromptVenteImmo =>
      'Je vends mon bien — quel impôt sur le gain immobilier dois-je prévoir ?';

  @override
  String get lifeEventPromptHeritage =>
      'Je reçois un héritage — quelles sont les conséquences fiscales ?';

  @override
  String get lifeEventPromptDonation =>
      'Je veux donner à mes enfants — quel impact fiscal et quelles limites ?';

  @override
  String get lifeEventPromptDemenagement =>
      'Je déménage de canton — quel impact fiscal dois-je anticiper ?';

  @override
  String get lifeEventPromptExpatriation =>
      'Je pars à l’étranger — que faire de ma prévoyance AVS, LPP et 3a ?';

  @override
  String get lifeEventPromptInvalidite =>
      'Suis-je bien couvert·e en cas d’invalidité ou d’accident ?';

  @override
  String get lifeEventPromptDettes =>
      'J’ai des dettes — comment les gérer sans toucher à ma prévoyance ?';

  @override
  String compoundDisclaimerInflation(String inflation) {
    return 'Hypothèses pédagogiques (inflation $inflation %). Les rendements passés ne constituent pas une assurance de résultat pour les rendements futurs.';
  }

  @override
  String get interactive3aDisclaimer =>
      'Hypothèses pédagogiques. Les rendements passés ne constituent pas une assurance de résultat.';

  @override
  String get milestoneContinueBtn => 'Continuer';

  @override
  String get slmAutoPromptTitle => 'Coach IA sur ton appareil';

  @override
  String get slmAutoPromptBody =>
      'MINT peut installer un modèle d’IA directement sur ton téléphone pour des conseils personnalisés — 100 % privé, aucune donnée ne quitte ton appareil.';

  @override
  String get slmAutoInstalledMsg =>
      'Coach IA installé ! Tes conseils seront personnalisés.';

  @override
  String get slmInstallBtn => 'Installer le coach IA';

  @override
  String get slmLaterBtn => 'Plus tard';

  @override
  String get rcDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil financier (LSFin art. 3).';

  @override
  String rcPillar3aTitle(String year) {
    return 'Versement 3a $year';
  }

  @override
  String get rcPillar3aSubtitle => 'Économie fiscale estimée';

  @override
  String rcPillar3aExplanation(String plafond) {
    return 'Économie d’impôt estimée si tu verses le plafond de $plafond CHF';
  }

  @override
  String get rcPillar3aCtaLabel => 'Simuler mon 3a';

  @override
  String get rcLppBuybackTitle => 'Rachat LPP';

  @override
  String get rcLppBuybackSubtitle => 'Potentiel de rachat disponible';

  @override
  String rcLppBuybackExplanation(String taxSaving, String rachatSimule) {
    return 'Rachat possible. Économie fiscale estimée de $taxSaving CHF sur $rachatSimule CHF';
  }

  @override
  String get rcLppBuybackCtaLabel => 'Simuler un rachat';

  @override
  String get rcReplacementRateTitle => 'Taux de remplacement';

  @override
  String rcReplacementRateSubtitle(String age) {
    return 'Projection à $age ans';
  }

  @override
  String rcReplacementRateExplanation(
      String totalMonthly, String currentMonthly) {
    return 'Revenu estimé à la retraite : $totalMonthly CHF/mois vs $currentMonthly CHF/mois actuellement';
  }

  @override
  String get rcReplacementRateCtaLabel => 'Explorer mes scénarios';

  @override
  String get rcReplacementRateAlerte =>
      'Taux inférieur au seuil recommandé de 60 %. Explore les options.';

  @override
  String get rcAvsGapTitle => 'Lacune AVS';

  @override
  String rcAvsGapSubtitle(String lacunes) {
    return '$lacunes années de cotisation manquantes';
  }

  @override
  String get rcAvsGapExplanation =>
      'Réduction estimée de ta rente AVS annuelle due aux lacunes';

  @override
  String get rcAvsGapCtaLabel => 'Voir mon extrait AVS';

  @override
  String get rcCoupleAlertTitle => 'Écart de visibilité couple';

  @override
  String rcCoupleAlertSubtitle(String name, String score) {
    return '$name à $score %';
  }

  @override
  String rcCoupleAlertExplanation(String gap) {
    return 'Écart de $gap points entre vos deux profils. Équilibrer améliore la projection couple.';
  }

  @override
  String get rcCoupleAlertCtaLabel => 'Enrichir le profil couple';

  @override
  String get rcIndependantTitle => 'Prévoyance indépendant';

  @override
  String get rcIndependantSubtitle =>
      'Sans LPP, ton 3a est ta prévoyance principale';

  @override
  String rcIndependantExplanation(String max3a, String current3a) {
    return 'Plafond 3a sans LPP : $max3a CHF/an. Capital 3a actuel : $current3a CHF';
  }

  @override
  String get rcIndependantCtaLabel => 'Explorer mes options';

  @override
  String get rcTaxOptTitle => 'Optimisation fiscale';

  @override
  String get rcTaxOptSubtitle => 'Déductions estimées disponibles';

  @override
  String rcTaxOptExplanation(String plafond3a) {
    return 'Économie d’impôt estimée via 3a ($plafond3a CHF) + rachat LPP';
  }

  @override
  String get rcTaxOptCtaLabel => 'Découvrir mes déductions';

  @override
  String get rcPatrimoineTitle => 'Patrimoine';

  @override
  String get rcPatrimoineSubtitleLow => 'Coussin de sécurité insuffisant';

  @override
  String get rcPatrimoineSubtitleOk => 'Vue d’ensemble';

  @override
  String rcPatrimoineExplanationLow(String epargne, String coussinMin) {
    return 'Épargne liquide ($epargne CHF) inférieure à 3 mois de charges ($coussinMin CHF)';
  }

  @override
  String rcPatrimoineExplanationOk(String epargne, String investissements) {
    return 'Épargne $epargne CHF + investissements $investissements CHF';
  }

  @override
  String get rcPatrimoineCtaLabelLow => 'Analyser mon budget';

  @override
  String get rcPatrimoineCtaLabelOk => 'Voir mon patrimoine';

  @override
  String rcPatrimoineAlerte(String coussinMin) {
    return 'Coussin de sécurité recommandé : $coussinMin CHF (3 mois de charges)';
  }

  @override
  String get rcMortgageTitle => 'Hypothèque';

  @override
  String rcMortgageSubtitle(String ltv) {
    return 'Ratio LTV : $ltv %';
  }

  @override
  String rcMortgageExplanation(String propertyValue) {
    return 'Solde hypothécaire. Valeur du bien : $propertyValue CHF';
  }

  @override
  String get rcMortgageCtaLabel => 'Simuler la capacité';

  @override
  String get rcCtaDetail => 'Voir le détail →';

  @override
  String get rcLibrePassageTitle => 'Libre passage';

  @override
  String get rcLibrePassageSubtitle =>
      'Que faire de ton avoir de libre passage ?';

  @override
  String get rcRenteVsCapitalTitle => 'Rente vs Capital';

  @override
  String get rcRenteVsCapitalSubtitle =>
      'Rente ou capital : chiffrer les deux options';

  @override
  String get rcFiscalComparatorTitle => 'Comparateur cantonal';

  @override
  String get rcFiscalComparatorSubtitle => 'Combien gagnerais-tu à déménager ?';

  @override
  String get rcStaggeredWithdrawalTitle => 'Retrait 3a échelonné';

  @override
  String get rcStaggeredWithdrawalSubtitle =>
      'Étaler les retraits pour réduire l’impôt';

  @override
  String get rcRealReturn3aTitle => 'Rendement réel 3a';

  @override
  String get rcRealReturn3aSubtitle =>
      'Rendement après frais, inflation et fiscal';

  @override
  String get rcComparator3aTitle => 'Comparateur 3a';

  @override
  String get rcComparator3aSubtitle => 'Compare les prestataires 3a';

  @override
  String get rcRentVsBuyTitle => 'Louer ou acheter';

  @override
  String get rcRentVsBuySubtitle =>
      'Compare les deux scénarios sur le long terme';

  @override
  String get rcAmortizationTitle => 'Amortissement';

  @override
  String get rcAmortizationSubtitle =>
      'Direct vs indirect — quel impact fiscal';

  @override
  String get rcImputedRentalTitle => 'Valeur locative';

  @override
  String get rcImputedRentalSubtitle => 'Comprendre l’imposition du logement';

  @override
  String get rcSaronVsFixedTitle => 'SARON vs taux fixe';

  @override
  String get rcSaronVsFixedSubtitle => 'Quel type d’hypothèque choisir';

  @override
  String get rcEplTitle => 'Retrait EPL';

  @override
  String get rcEplSubtitle => 'Utiliser ton 2e pilier pour l’immobilier';

  @override
  String get rcHousingSaleTitle => 'Vente immobilière';

  @override
  String get rcHousingSaleSubtitle => 'Impôt sur le gain immobilier + remploi';

  @override
  String get rcMariageTitle => 'Impact du mariage';

  @override
  String get rcMariageSubtitle => 'Impôts, AVS, LPP, succession';

  @override
  String get rcDivorceTitle => 'Simulateur divorce';

  @override
  String get rcDivorceSubtitle => 'Partage LPP, pension, impôts';

  @override
  String get rcNaissanceTitle => 'Impact d’une naissance';

  @override
  String get rcNaissanceSubtitle => 'Allocations, déductions, budget';

  @override
  String get rcConcubinageTitle => 'Protection concubinage';

  @override
  String get rcConcubinageSubtitle => 'Droits, risques et solutions';

  @override
  String get rcSuccessionTitle => 'Succession';

  @override
  String get rcSuccessionSubtitle => 'Simuler la transmission du patrimoine';

  @override
  String get rcDonationTitle => 'Donation';

  @override
  String get rcDonationSubtitle => 'Impact fiscal d’une donation';

  @override
  String get rcUnemploymentTitle => 'Perte d’emploi';

  @override
  String get rcUnemploymentSubtitle => 'Indemnités, durée, démarches';

  @override
  String get rcFirstJobTitle => 'Premier emploi';

  @override
  String get rcFirstJobSubtitle => 'Tout comprendre dès le départ';

  @override
  String get rcExpatriationTitle => 'Expatriation';

  @override
  String get rcExpatriationSubtitle => 'Impact sur AVS, LPP, 3a et impôts';

  @override
  String get rcFrontalierTitle => 'Frontalier';

  @override
  String get rcFrontalierSubtitle => 'Impôt source et particularités';

  @override
  String get rcJobComparisonTitle => 'Comparateur d’offres';

  @override
  String get rcJobComparisonSubtitle =>
      'Net + prévoyance : quelle offre vaut vraiment plus ?';

  @override
  String get rcDividendeVsSalaireTitle => 'Dividende vs Salaire';

  @override
  String get rcDividendeVsSalaireSubtitle =>
      'Optimiser la rémunération en SARL/SA';

  @override
  String get rcLamalFranchiseTitle => 'Franchise LAMal';

  @override
  String get rcLamalFranchiseSubtitle => 'Quelle franchise choisir ?';

  @override
  String get rcCoverageCheckTitle => 'Check de couverture';

  @override
  String get rcCoverageCheckSubtitle => 'Vérifier tes couvertures';

  @override
  String get rcDisabilityTitle => 'Invalidité — lacune de revenu';

  @override
  String get rcDisabilitySubtitle => 'Gap entre revenu actuel et rentes AI/LPP';

  @override
  String get rcGenderGapTitle => 'Écart femmes/hommes';

  @override
  String get rcGenderGapSubtitle => 'Impact du temps partiel sur la retraite';

  @override
  String get rcBudgetTitle => 'Budget';

  @override
  String get rcBudgetSubtitle => 'Combien il te reste à la fin du mois ?';

  @override
  String get rcDebtRatioTitle => 'Ratio d’endettement';

  @override
  String get rcDebtRatioSubtitle =>
      'À partir de quel seuil les dettes deviennent dangereuses ?';

  @override
  String get rcCompoundInterestTitle => 'Intérêts composés';

  @override
  String get rcCompoundInterestSubtitle =>
      'Simuler la croissance de ton épargne';

  @override
  String get rcLeasingTitle => 'Simulateur leasing';

  @override
  String get rcLeasingSubtitle => 'Coût réel d’un leasing auto';

  @override
  String get rcConsumerCreditTitle => 'Crédit consommation';

  @override
  String get rcConsumerCreditSubtitle => 'Coût total d’un crédit conso';

  @override
  String get rcAllocationAnnuelleTitle => 'Allocation annuelle';

  @override
  String get rcAllocationAnnuelleSubtitle =>
      'Où placer ton épargne cette année';

  @override
  String get rcSuggestedPrompt50PlusRetirement =>
      'Quand la retraite devient-elle tenable ?';

  @override
  String get rcSuggestedPromptRenteOuCapital =>
      'Rente ou capital : qu’est-ce qui me laisse le plus d’air ?';

  @override
  String get rcSuggestedPromptRachatLpp =>
      'Que vaut un rachat LPP dans mon cas ?';

  @override
  String get rcSuggestedPromptAllegerImpots =>
      'Où alléger mes impôts cette année ?';

  @override
  String get rcSuggestedPromptVersement3a =>
      'Combien verser en 3a cette année ?';

  @override
  String get nudgeSalaryBody =>
      'As-tu pensé à ton virement 3a ce mois-ci ? Chaque mois compte pour ta prévoyance.';

  @override
  String get nudgeTaxDeadlineTitle => 'Déclaration fiscale';

  @override
  String get nudgeTaxDeadlineBody =>
      'Vérifie la date limite de déclaration fiscale dans ton canton. As-tu pensé à tes déductions 3a et LPP ?';

  @override
  String get nudge3aDeadlineTitle => 'Dernière ligne droite pour ton 3a';

  @override
  String nudge3aDeadlineBody(String days, String limit, String year) {
    return 'Il reste $days jour(s) pour verser jusqu\'à $limit CHF et réduire tes impôts $year.';
  }

  @override
  String get nudgeBirthdayBody =>
      'Une étape qui peut marquer un tournant pour ta prévoyance. As-tu simulé l’impact de cette année ?';

  @override
  String get nudgeProfileTitle => 'Ton profil mérite d’être enrichi';

  @override
  String get nudgeProfileBody =>
      'Plus ton profil est complet, plus MINT peut t’offrir des insights pertinents. Quelques informations suffisent.';

  @override
  String get nudgeInactiveTitle => 'Ça fait un moment !';

  @override
  String get nudgeInactiveBody =>
      'Ta situation financière évolue chaque semaine. Prends 2 minutes pour vérifier ton tableau de bord.';

  @override
  String get nudgeGoalProgressTitle => 'Ton objectif avance !';

  @override
  String nudgeGoalProgressBody(String progress) {
    return 'Tu as atteint $progress % de ton objectif. Continue sur cette lancée.';
  }

  @override
  String get nudgeAnniversaryBody =>
      'Tu utilises MINT depuis un an. C’est le moment idéal pour actualiser ton profil et mesurer tes progrès.';

  @override
  String get nudgeLppBuybackTitle => 'Fenêtre de rachat LPP';

  @override
  String nudgeLppBuybackBody(String year) {
    return 'La fin d’année $year approche : c’est le dernier moment pour effectuer un rachat LPP déductible.';
  }

  @override
  String get nudgeNewYearTitle => 'Nouvelle année, nouveau départ !';

  @override
  String nudgeNewYearBody(String year) {
    return '$year : une nouvelle enveloppe 3a s’ouvre. C’est le bon moment pour planifier tes versements.';
  }

  @override
  String get rcSuggestedPromptCommencer3a =>
      'Pourquoi commencer le 3a maintenant ?';

  @override
  String get rcSuggestedPrompt2ePilier =>
      'Le 2e pilier, concrètement, ça fait quoi ?';

  @override
  String get rcSuggestedPromptIndependant =>
      'Indépendant : qu’est-ce que je dois reconstruire ?';

  @override
  String get rcSuggestedPromptCouple =>
      'Où notre prévoyance de couple boite-t-elle ?';

  @override
  String get rcSuggestedPromptFatca =>
      'FATCA : qu’est-ce que ça change pour mon 3a ?';

  @override
  String get rcUnitPts => 'pts';

  @override
  String get routeSuggestionCta => 'Ouvrir';

  @override
  String get routeSuggestionPartialWarning =>
      'Estimation — données incomplètes';

  @override
  String get routeSuggestionBlocked =>
      'Il me manque des infos pour t’y emmener';

  @override
  String get routeReturnAcknowledge =>
      'Tu es de retour ! Si tu as ajusté des données, je recalcule dès que tu m’en parles.';

  @override
  String get routeReturnCompleted => 'J’ai noté. Tes données sont à jour.';

  @override
  String get routeReturnAbandoned =>
      'Pas de souci — on y reviendra quand tu veux.';

  @override
  String get routeReturnChanged =>
      'Tes chiffres ont changé. Je recalcule la trajectoire.';

  @override
  String get hypothesisEditorTitle => 'Hypothèses de simulation';

  @override
  String get hypothesisEditorSubtitle =>
      'Ajuste les paramètres pour voir l’impact sur les trajectoires.';

  @override
  String get lifecyclePhaseDemarrage => 'Démarrage';

  @override
  String get lifecyclePhaseDemarrageDesc =>
      'Premiers pas dans la vie active : budget, 3a et bonnes habitudes.';

  @override
  String get lifecyclePhaseConstruction => 'Construction';

  @override
  String get lifecyclePhaseConstructionDesc =>
      'Accélération de carrière, épargne, premier logement, projets de famille.';

  @override
  String get lifecyclePhaseAcceleration => 'Accélération';

  @override
  String get lifecyclePhaseAccelerationDesc =>
      'Phase de revenus élevés : optimisation LPP, fiscalité et patrimoine.';

  @override
  String get lifecyclePhaseConsolidation => 'Consolidation';

  @override
  String get lifecyclePhaseConsolidationDesc =>
      'Préparation de la retraite, rachat LPP, début de planification successorale.';

  @override
  String get lifecyclePhaseTransition => 'Transition';

  @override
  String get lifecyclePhaseTransitionDesc =>
      'Décisions pré-retraite : rente ou capital, séquence de retraits.';

  @override
  String get lifecyclePhaseRetraite => 'Retraite';

  @override
  String get lifecyclePhaseRetraiteDesc =>
      'Mise en œuvre de la retraite, adaptation du budget, gestion du patrimoine.';

  @override
  String get lifecyclePhaseTransmission => 'Transmission';

  @override
  String get lifecyclePhaseTransmissionDesc =>
      'Planification successorale, donations et transmission du patrimoine.';

  @override
  String get challengeWeeklyTitle => 'Défi de la semaine';

  @override
  String get challengeCompleted => 'Défi réussi !';

  @override
  String challengeStreak(int count) {
    return '$count semaines consécutives';
  }

  @override
  String get challengeBudget01Title =>
      'Vérifie tes 3 plus grosses dépenses de la semaine';

  @override
  String get challengeBudget01Desc =>
      'Imagine savoir exactement où part chaque franc : ouvre ton budget et repère les 3 postes les plus élevés cette semaine. Tu pourrais être surpris·e.';

  @override
  String get challengeBudget02Title =>
      'Calcule ton taux d’épargne mensuel réel';

  @override
  String get challengeBudget02Desc =>
      'Ton taux d’épargne, c’est ce qui reste après toutes les dépenses. Vérifie s’il dépasse 10 % de ton revenu net.';

  @override
  String get challengeBudget03Title =>
      'Compare le coût de tes assurances avec une offre alternative';

  @override
  String get challengeBudget03Desc =>
      'Les primes d’assurance peuvent varier de 30 % d’un assureur à l’autre. Vérifie si tu pourrais économiser en changeant de caisse.';

  @override
  String get challengeBudget04Title => 'Analyse tes frais fixes vs variables';

  @override
  String get challengeBudget04Desc =>
      'Sépare tes charges fixes (loyer, assurances) et variables (sorties, loisirs). C’est la base pour optimiser ton budget.';

  @override
  String get challengeBudget05Title => 'Vérifie ton ratio d’endettement';

  @override
  String get challengeBudget05Desc =>
      'Ton ratio d’endettement ne devrait pas dépasser 33 % de ton revenu brut. Calcule-le pour savoir où tu en es.';

  @override
  String get challengeBudget06Title => 'Simule le coût réel de ton leasing';

  @override
  String get challengeBudget06Desc =>
      'Un leasing, c’est plus que la mensualité : assurance, entretien, valeur résiduelle. Calcule le coût total.';

  @override
  String get challengeBudget07Title => 'Évalue ton matelas de sécurité en mois';

  @override
  String get challengeBudget07Desc =>
      'Combien de mois pourrais-tu tenir sans revenu ? C’est une question importante pour ta tranquillité d’esprit. L’idéal est 3 à 6 mois de charges.';

  @override
  String get challengeBudget08Title =>
      'Vérifie si tu pourrais réduire ton crédit à la consommation';

  @override
  String get challengeBudget08Desc =>
      'Un crédit conso à 8-12 % est très coûteux. Regarde si tu peux accélérer le remboursement ou le consolider.';

  @override
  String get challengeEpargne01Title => 'Mets de côté CHF 50 cette semaine';

  @override
  String get challengeEpargne01Desc =>
      'Même un petit montant compte : CHF 50 par semaine, c’est CHF 2’600 par an. Le plus dur, c’est de commencer.';

  @override
  String get challengeEpargne02Title =>
      'Vérifie ton solde 3a et compare au plafond';

  @override
  String get challengeEpargne02Desc =>
      'Le plafond 3a salarié est de CHF 7’258 par an. Vérifie combien tu as déjà versé cette année.';

  @override
  String get challengeEpargne03Title => 'Simule un rachat LPP de CHF 5’000';

  @override
  String get challengeEpargne03Desc =>
      'Un rachat LPP est déductible des impôts. Simule l’impact d’un rachat de CHF 5’000 sur ta prévoyance et ta fiscalité.';

  @override
  String get challengeEpargne04Title =>
      'Vérifie si tu peux encore verser au 3a cette année';

  @override
  String get challengeEpargne04Desc =>
      'Le versement 3a est annuel : si tu n’as pas encore versé le maximum, il reste peut-être du temps.';

  @override
  String get challengeEpargne05Title =>
      'Compare les rendements de tes comptes 3a';

  @override
  String get challengeEpargne05Desc =>
      'Tous les comptes 3a ne se valent pas. Compare le rendement de tes comptes avec le simulateur.';

  @override
  String get challengeEpargne06Title =>
      'Calcule le rendement réel de ton 3a après inflation';

  @override
  String get challengeEpargne06Desc =>
      'Un rendement de 1 % avec une inflation de 1,5 %, c’est un rendement réel négatif. Vérifie ta situation.';

  @override
  String get challengeEpargne07Title =>
      'Simule un retrait échelonné de tes comptes 3a';

  @override
  String get challengeEpargne07Desc =>
      'Retirer tes 3a sur plusieurs années peut réduire l’impôt. Simule la stratégie de retrait échelonné.';

  @override
  String get challengeEpargne08Title =>
      'Vérifie si tu peux cotiser rétroactivement au 3a';

  @override
  String get challengeEpargne08Desc =>
      'Depuis 2025, tu peux rattraper des années sans versement. Vérifie si tu es éligible au 3a rétroactif.';

  @override
  String get challengeEpargne09Title =>
      'Vérifie ton libre passage si tu as changé d’employeur';

  @override
  String get challengeEpargne09Desc =>
      'Lors d’un changement d’emploi, ton capital LPP est transféré sur un compte de libre passage. Vérifie que rien n’a été oublié.';

  @override
  String get challengePrevoyance01Title => 'Demande ton extrait de compte AVS';

  @override
  String get challengePrevoyance01Desc =>
      'Ton extrait AVS montre tes années de cotisation et ta rente estimée. Demande-le gratuitement sur lavs.ch.';

  @override
  String get challengePrevoyance02Title => 'Vérifie ta couverture invalidité';

  @override
  String get challengePrevoyance02Desc =>
      'En cas d’invalidité, ta rente AI + LPP couvre-t-elle tes charges ? Vérifie le gap éventuel.';

  @override
  String get challengePrevoyance03Title =>
      'Compare rente vs capital pour ta LPP';

  @override
  String get challengePrevoyance03Desc =>
      'Rente à vie ou capital ? Chaque option a ses avantages fiscaux et de flexibilité. Compare les scénarios.';

  @override
  String get challengePrevoyance04Title => 'Consulte ta projection retraite';

  @override
  String get challengePrevoyance04Desc =>
      'Imagine ta vie à la retraite : AVS + LPP + 3a, combien auras-tu réellement ? Vérifie si tu es sur la bonne trajectoire. Chaque année compte.';

  @override
  String get challengePrevoyance05Title =>
      'Optimise ta séquence de décaissement';

  @override
  String get challengePrevoyance05Desc =>
      'L’ordre dans lequel tu retires tes piliers a un impact fiscal majeur. Simule différentes séquences.';

  @override
  String get challengePrevoyance06Title => 'Vérifie tes lacunes AVS';

  @override
  String get challengePrevoyance06Desc =>
      'Chaque année sans cotisation AVS réduit ta rente : l’impact peut être important sur le long terme. Vérifie si tu as des lacunes à combler.';

  @override
  String get challengePrevoyance07Title => 'Planifie ta succession';

  @override
  String get challengePrevoyance07Desc =>
      'Qui hérite de quoi en droit suisse ? Vérifie les parts réservataires et si un testament est nécessaire.';

  @override
  String get challengePrevoyance08Title =>
      'Vérifie ta couverture en cas de chômage';

  @override
  String get challengePrevoyance08Desc =>
      'Perdre son emploi, c’est stressant. Savoir combien tu toucherais et pendant combien de temps peut te rassurer. Simule ta situation.';

  @override
  String get challengePrevoyance09Title =>
      'Vérifie la couverture invalidité de ton activité indépendante';

  @override
  String get challengePrevoyance09Desc =>
      'En tant qu’indépendant·e, ta couverture AI peut être insuffisante. Vérifie si une IJM complémentaire serait utile.';

  @override
  String get challengeFiscalite01Title => 'Estime ton économie fiscale 3a';

  @override
  String get challengeFiscalite01Desc =>
      'Chaque franc versé en 3a est déductible. Calcule combien tu économises en impôts cette année.';

  @override
  String get challengeFiscalite02Title =>
      'Vérifie si un rachat LPP serait déductible cette année';

  @override
  String get challengeFiscalite02Desc =>
      'Les rachats LPP sont déductibles du revenu imposable. Vérifie ton potentiel de rachat et l’économie fiscale.';

  @override
  String get challengeFiscalite03Title =>
      'Simule l’impôt sur un retrait de capital';

  @override
  String get challengeFiscalite03Desc =>
      'Le retrait de capital (LPP/3a) est taxé séparément à un taux réduit. Simule l’impôt pour différents montants.';

  @override
  String get challengeFiscalite04Title =>
      'Compare salaire vs dividende si tu es indépendant·e';

  @override
  String get challengeFiscalite04Desc =>
      'Le mix salaire/dividende adapté à ta situation dépend de ton revenu et de ton canton. Simule les deux scénarios.';

  @override
  String get challengeFiscalite05Title =>
      'Vérifie la valeur locative imputée de ton bien';

  @override
  String get challengeFiscalite05Desc =>
      'Si tu es propriétaire, la valeur locative est ajoutée à ton revenu imposable. Vérifie si elle est correcte.';

  @override
  String get challengeFiscalite06Title => 'Calcule ta charge fiscale globale';

  @override
  String get challengeFiscalite06Desc =>
      'Impôt fédéral + cantonal + communal : calcule ta charge fiscale totale en pourcentage de ton revenu.';

  @override
  String get challengeFiscalite07Title => 'Vérifie ta conformité FATCA';

  @override
  String get challengeFiscalite07Desc =>
      'En tant que citoyen·ne US, tes comptes suisses sont soumis à FATCA. Vérifie que ta situation est en ordre.';

  @override
  String get challengeFiscalite08Title => 'Vérifie ton imposition à la source';

  @override
  String get challengeFiscalite08Desc =>
      'En tant que frontalier·ère, tu es imposé·e à la source. Vérifie que le taux appliqué correspond à ta situation.';

  @override
  String get challengePatrimoine01Title =>
      'Calcule ta capacité d’emprunt hypothécaire';

  @override
  String get challengePatrimoine01Desc =>
      'Avec la règle des 1/3, vérifie combien tu pourrais emprunter pour un achat immobilier.';

  @override
  String get challengePatrimoine02Title =>
      'Simule SARON vs taux fixe pour ton hypothèque';

  @override
  String get challengePatrimoine02Desc =>
      'SARON (variable) ou taux fixe ? Simule les deux scénarios sur 10 ans pour voir la différence.';

  @override
  String get challengePatrimoine03Title => 'Compare location vs propriété';

  @override
  String get challengePatrimoine03Desc =>
      'Acheter n’est pas toujours mieux que louer. Compare les deux options sur 20 ans avec le simulateur.';

  @override
  String get challengePatrimoine04Title =>
      'Simule un EPL (retrait anticipé LPP pour ton logement)';

  @override
  String get challengePatrimoine04Desc =>
      'Tu peux utiliser ton 2e pilier pour financer ton logement. Simule l’impact sur ta retraite.';

  @override
  String get challengePatrimoine05Title =>
      'Consulte ton bilan patrimonial complet';

  @override
  String get challengePatrimoine05Desc =>
      'Actifs, passifs, patrimoine net : fais le point sur ta situation financière globale. C’est un moment important pour prendre du recul.';

  @override
  String get challengePatrimoine06Title =>
      'Vérifie ton allocation annuelle d’épargne';

  @override
  String get challengePatrimoine06Desc =>
      'Entre 3a, rachat LPP et amortissement hypothécaire, comment répartir ton épargne cette année ? Chaque choix a un impact fiscal différent.';

  @override
  String get challengePatrimoine07Title =>
      'Simule l’impact d’un amortissement hypothécaire';

  @override
  String get challengePatrimoine07Desc =>
      'Amortir directement ou indirectement via le 3a ? Simule les deux options et leur impact fiscal.';

  @override
  String get challengePatrimoine08Title =>
      'Simule l’effet des intérêts composés sur 20 ans';

  @override
  String get challengePatrimoine08Desc =>
      'Même un petit rendement crée un effet boule de neige. Simule la croissance de ton épargne sur 20 ans.';

  @override
  String get challengeEducation01Title => 'Lis l’article sur la 13e rente AVS';

  @override
  String get challengeEducation01Desc =>
      'Depuis 2026, la 13e rente AVS augmente ta rente annuelle. Découvre ce que ça change concrètement pour toi.';

  @override
  String get challengeEducation02Title =>
      'Comprends la différence entre taux de conversion min et surobligatoire';

  @override
  String get challengeEducation02Desc =>
      'Le taux de conversion LPP de 6,8 % ne s’applique qu’au minimum. Ta caisse peut avoir un taux différent pour le surobligatoire.';

  @override
  String get challengeEducation03Title =>
      'Découvre comment fonctionne le 1er pilier';

  @override
  String get challengeEducation03Desc =>
      'L’AVS est un système par répartition : les actifs financent les retraités. Comprends les bases de ta future rente.';

  @override
  String get challengeEducation04Title => 'Comprends le système des 3 piliers';

  @override
  String get challengeEducation04Desc =>
      'AVS + LPP + 3a : chaque pilier a son rôle. Comprends comment ils se complètent pour ta retraite.';

  @override
  String get challengeEducation05Title =>
      'Explore le concept de taux de remplacement';

  @override
  String get challengeEducation05Desc =>
      'Le taux de remplacement mesure le rapport entre ta rente et ton dernier salaire. L’objectif courant est 60-80 %.';

  @override
  String get challengeEducation06Title =>
      'Comprends les bonifications LPP par tranche d’âge';

  @override
  String get challengeEducation06Desc =>
      'Les bonifications LPP augmentent avec l’âge : 7 %, 10 %, 15 %, 18 %. Vérifie dans quelle tranche tu es.';

  @override
  String get challengeEducation07Title =>
      'Découvre les conséquences financières du concubinage';

  @override
  String get challengeEducation07Desc =>
      'En concubinage, tu n’as pas les mêmes droits successoraux qu’un·e marié·e. Vérifie les protections nécessaires.';

  @override
  String get challengeEducation08Title =>
      'Comprends l’impact du gender gap sur la retraite';

  @override
  String get challengeEducation08Desc =>
      'Les femmes touchent en moyenne 37 % de rente en moins. Comprends les causes et les solutions possibles.';

  @override
  String get challengeArchetypeEu01Title =>
      'Vérifie tes années de cotisation EU pour l’AVS';

  @override
  String get challengeArchetypeEu01Desc =>
      'Grâce aux accords bilatéraux, tes années cotisées dans l’UE comptent pour ta rente AVS suisse. Demande une attestation E205 pour vérifier la totalisation.';

  @override
  String get challengeArchetypeNonEu01Title =>
      'Vérifie si une convention de sécurité sociale couvre ton pays';

  @override
  String get challengeArchetypeNonEu01Desc =>
      'Sans convention bilatérale, tes cotisations étrangères ne comptent pas pour l’AVS. Vérifie si ton pays d’origine a un accord avec la Suisse.';

  @override
  String get challengeArchetypeReturning01Title =>
      'Vérifie ton potentiel de rachat LPP après ton retour en Suisse';

  @override
  String get challengeArchetypeReturning01Desc =>
      'De retour en Suisse après un séjour à l’étranger ? Tu pourrais avoir un potentiel de rachat LPP important, déductible fiscalement. Simule le montant.';

  @override
  String get voiceMicLabel => 'Parler au micro';

  @override
  String get voiceMicListening => 'J’écoute…';

  @override
  String get voiceMicProcessing => 'Traitement…';

  @override
  String get voiceSpeakerLabel => 'Écouter la réponse';

  @override
  String get voiceSpeakerStop => 'Arrêter la lecture';

  @override
  String get voiceUnavailable =>
      'Fonctions vocales non disponibles sur cet appareil';

  @override
  String get voicePermissionNeeded => 'Autorise le micro pour utiliser la voix';

  @override
  String get voiceNoSpeech => 'Je n’ai rien entendu. Réessaie.';

  @override
  String get voiceError => 'Erreur vocale. Utilise le clavier.';

  @override
  String get benchmarkTitle => 'Profils similaires dans ton canton';

  @override
  String get benchmarkSubtitle => 'Données agrégées et anonymisées (OFS)';

  @override
  String get benchmarkOptInBody =>
      'Compare ta situation aux médianes de ton canton. Données anonymisées, jamais de classement.';

  @override
  String get benchmarkOptInButton => 'Activer';

  @override
  String get benchmarkOptOutButton => 'Désactiver';

  @override
  String get benchmarkDisclaimer =>
      'Données agrégées OFS — outil éducatif, pas un classement. Ne constitue pas un conseil (LSFin art. 3).';

  @override
  String benchmarkInsightIncome(String canton, String amount) {
    return 'Le revenu médian dans le canton de $canton est de CHF $amount/an';
  }

  @override
  String benchmarkInsightSavings(String rate) {
    return 'Un profil similaire épargne environ $rate% de son revenu';
  }

  @override
  String benchmarkInsightTax(String canton, String level) {
    return 'La charge fiscale dans $canton est $level par rapport à la moyenne suisse';
  }

  @override
  String benchmarkInsightHousing(String amount) {
    return 'Le loyer médian pour un 4 pièces est de CHF $amount/mois';
  }

  @override
  String benchmarkInsight3a(String rate) {
    return 'Environ $rate% des actifs versent dans le 3a';
  }

  @override
  String benchmarkInsightLpp(String rate) {
    return 'Le taux de couverture LPP est de $rate%';
  }

  @override
  String get benchmarkTaxLevelBelow => 'inférieure';

  @override
  String get benchmarkTaxLevelAverage => 'comparable';

  @override
  String get benchmarkTaxLevelAbove => 'supérieure';

  @override
  String get benchmarkNoDataCanton => 'Données non disponibles pour ce canton';

  @override
  String get llmFailoverActive => 'Basculement automatique activé';

  @override
  String get llmProviderClaude => 'Claude (Anthropic)';

  @override
  String get llmProviderOpenai => 'GPT-4o (OpenAI)';

  @override
  String get llmProviderMistral => 'Mistral';

  @override
  String get llmProviderLocal => 'Modèle local';

  @override
  String get llmCircuitOpen => 'Service temporairement indisponible';

  @override
  String get llmAllProvidersDown =>
      'Tous les services IA sont indisponibles. Mode hors-ligne activé.';

  @override
  String get llmQualityGood => 'Qualité de réponse : bonne';

  @override
  String get llmQualityDegraded => 'Qualité de réponse : dégradée';

  @override
  String get gamificationCommunityTitle => 'Défi du mois';

  @override
  String get gamificationSeasonalTitle => 'Événements saisonniers';

  @override
  String get gamificationMilestonesTitle => 'Tes accomplissements';

  @override
  String get gamificationOptInPrompt => 'Participer aux défis communautaires';

  @override
  String get communityChallenge01Title => 'Prépare ta déclaration d’impôts';

  @override
  String get communityChallenge01Desc =>
      'Janvier est le bon moment pour rassembler tes documents fiscaux. Contacte ton canton pour connaître la date limite et les pièces requises.';

  @override
  String get communityChallenge02Title => 'Identifie tes déductions fiscales';

  @override
  String get communityChallenge02Desc =>
      'Frais professionnels, intérêts hypothécaires, dons : répertorie toutes les déductions auxquelles tu as droit avant de soumettre ta déclaration.';

  @override
  String get communityChallenge03Title =>
      'Vérifie ton versement 3a avant la deadline';

  @override
  String get communityChallenge03Desc =>
      'Certains cantons permettent de compléter le versement 3a de l’année précédente jusqu’en mars. Vérifie les règles de ton canton.';

  @override
  String get communityChallenge04Title =>
      'Consulte ton certificat de prévoyance LPP';

  @override
  String get communityChallenge04Desc =>
      'Ton certificat annuel LPP est arrivé. Prends 10 minutes pour comprendre ton avoir, ton taux de conversion et ton potentiel de rachat.';

  @override
  String get communityChallenge05Title => 'Simule un rachat LPP';

  @override
  String get communityChallenge05Desc =>
      'Un rachat LPP améliore ta retraite ET réduit tes impôts. Calcule combien tu pourrais racheter et l’impact fiscal dans ton canton.';

  @override
  String get communityChallenge06Title => 'Fais ton bilan mi-annuel';

  @override
  String get communityChallenge06Desc =>
      '6 mois se sont écoulés : révise tes objectifs financiers, vérifie si tu es sur la bonne trajectoire et ajuste si nécessaire.';

  @override
  String get communityChallenge07Title =>
      'Définis ton objectif d’épargne estivale';

  @override
  String get communityChallenge07Desc =>
      'L’été peut impacter ton budget. Définis un objectif d’épargne pour juillet et suis ta progression jusqu’à fin août.';

  @override
  String get communityChallenge08Title =>
      'Constitue ou renforce ton fonds d’urgence';

  @override
  String get communityChallenge08Desc =>
      'Un fonds d’urgence de 3 à 6 mois de charges fixes te protège des aléas. Vérifie où tu en es et planifie les versements manquants.';

  @override
  String get communityChallenge09Title =>
      'Programme ton versement 3a d’automne';

  @override
  String get communityChallenge09Desc =>
      'Septembre est idéal pour programmer ton prochain versement 3a. Étaler les versements sur l’année réduit le stress de la deadline de décembre.';

  @override
  String get communityChallenge10Title => 'Célèbre le mois de la prévoyance';

  @override
  String get communityChallenge10Desc =>
      'Octobre est le mois officiel de la prévoyance en Suisse. Consulte ta projection de retraite et identifie une action concrète pour améliorer ta situation.';

  @override
  String get communityChallenge11Title =>
      'Planifie tes dernières optimisations de fin d’année';

  @override
  String get communityChallenge11Desc =>
      'Il reste quelques semaines pour agir : versement 3a, don à une association, déclaration de frais. Identifie ce que tu peux encore faire avant le 31 décembre.';

  @override
  String get communityChallenge12Title => 'Verse ton 3a avant le 31 décembre';

  @override
  String get communityChallenge12Desc =>
      'La deadline 3a approche. Verse jusqu’à CHF 7’258 (salarié avec LPP) avant le 31 décembre pour bénéficier de la déduction fiscale de cette année.';

  @override
  String get seasonalTaxSeasonTitle => 'Saison des impôts';

  @override
  String get seasonalTaxSeasonDesc =>
      'Février-mars : c’est le moment de préparer ta déclaration d’impôts. Rassemble tes justificatifs et identifie tes déductions.';

  @override
  String get seasonal3aCountdownTitle => 'Compte à rebours 3e pilier';

  @override
  String get seasonal3aCountdownDesc =>
      'La deadline du 31 décembre approche pour les versements 3a. Vérifie ton solde et planifie ton versement pour maximiser ta déduction fiscale.';

  @override
  String get seasonalNewYearResolutionsTitle => 'Résolutions financières';

  @override
  String get seasonalNewYearResolutionsDesc =>
      'Nouvelle année, nouveaux objectifs financiers. Définis 1 ou 2 actions concrètes que tu vas mettre en place cette année.';

  @override
  String get seasonalMidYearReviewTitle => 'Revue mi-annuelle';

  @override
  String get seasonalMidYearReviewDesc =>
      'Le cap des 6 mois est atteint. Prends un moment pour vérifier ta progression vers tes objectifs et ajuster si nécessaire.';

  @override
  String get seasonalRetirementMonthTitle => 'Mois de la prévoyance';

  @override
  String get seasonalRetirementMonthDesc =>
      'Octobre est le mois national de la prévoyance en Suisse. C’est le moment de vérifier ta projection de retraite et ton taux de remplacement.';

  @override
  String get milestoneEngagementFirstWeekTitle => 'Première semaine';

  @override
  String get milestoneEngagementFirstWeekDesc =>
      'Tu utilises MINT depuis 7 jours. Construire des habitudes, ça commence ici.';

  @override
  String get milestoneEngagementOneMonthTitle => 'Un mois fidèle';

  @override
  String get milestoneEngagementOneMonthDesc =>
      '30 jours avec MINT. Ta curiosité financière est au rendez-vous.';

  @override
  String get milestoneEngagementCitoyenTitle => 'Citoyen MINT';

  @override
  String get milestoneEngagementCitoyenDesc =>
      '90 jours : tu fais partie des personnes qui prennent leur avenir financier en main.';

  @override
  String get milestoneEngagementFideleTitle => 'Fidèle 6 mois';

  @override
  String get milestoneEngagementFideleDesc =>
      '180 jours de suivi financier. Ta régularité construit une vision claire de ta situation.';

  @override
  String get milestoneEngagementVeteranTitle => 'Vétéran MINT';

  @override
  String get milestoneEngagementVeteranDesc =>
      '365 jours avec MINT. Une année complète de conscience financière.';

  @override
  String get milestoneKnowledgeCurieuxTitle => 'Curieux';

  @override
  String get milestoneKnowledgeCurieuxDesc =>
      'Tu as exploré 5 concepts financiers. La connaissance, c’est le point de départ de toute décision éclairée.';

  @override
  String get milestoneKnowledgeEclaireTitle => 'Éclairé';

  @override
  String get milestoneKnowledgeEclaireDesc =>
      '20 insights parcourus. Tu construis une vision solide du système financier suisse.';

  @override
  String get milestoneKnowledgeExpertTitle => 'Expert';

  @override
  String get milestoneKnowledgeExpertDesc =>
      '50 concepts explorés. Tu maîtrises les fondamentaux de la prévoyance suisse.';

  @override
  String get milestoneKnowledgeStrategisteTitle => 'Stratège';

  @override
  String get milestoneKnowledgeStrategisteDesc =>
      '100 insights. Tu as une vision stratégique de tes finances sur le long terme.';

  @override
  String get milestoneKnowledgeMaitreTitle => 'Maître';

  @override
  String get milestoneKnowledgeMaitreDesc =>
      '200 concepts parcourus. Ta culture financière est un atout concret pour tes décisions de vie.';

  @override
  String get milestoneActionPremierPasTitle => 'Premier pas';

  @override
  String get milestoneActionPremierPasDesc =>
      'Tu as effectué ta première action financière concrète. Chaque grand changement commence par une première étape.';

  @override
  String get milestoneActionActeurTitle => 'Acteur';

  @override
  String get milestoneActionActeurDesc =>
      '5 actions financières réalisées. Tu passes de la réflexion à l’action.';

  @override
  String get milestoneActionMaitreDestinTitle => 'Maître de son destin';

  @override
  String get milestoneActionMaitreDestinDesc =>
      '20 actions concrètes. Tu pilotes activement ta situation financière.';

  @override
  String get milestoneActionBatisseurTitle => 'Bâtisseur';

  @override
  String get milestoneActionBatisseurDesc =>
      '50 actions financières. Tu construis patiemment une situation solide.';

  @override
  String get milestoneActionArchitecteTitle => 'Architecte';

  @override
  String get milestoneActionArchitecteDesc =>
      '100 actions. Tu es l’architecte de ta liberté financière.';

  @override
  String get milestoneConsistencyFlammeNaissanteTitle => 'Flamme naissante';

  @override
  String get milestoneConsistencyFlammeNaissanteDesc =>
      '2 semaines consécutives. Ta régularité prend forme.';

  @override
  String get milestoneConsistencyFlammeViveTitle => 'Flamme vive';

  @override
  String get milestoneConsistencyFlammeViveDesc =>
      '4 semaines sans interruption. Ta discipline financière est en marche.';

  @override
  String get milestoneConsistencyFlammeEtermelleTitle => 'Flamme éternelle';

  @override
  String get milestoneConsistencyFlammeEtermelleDesc =>
      '12 semaines consécutives. Ta constance est devenue une habitude.';

  @override
  String get milestoneConsistencyConfianceTitle => 'Profil de confiance';

  @override
  String get milestoneConsistencyConfianceDesc =>
      'Ton profil a atteint un score de confiance de 70 %. Tes données permettent des calculs fiables.';

  @override
  String get milestoneConsistencyChallengesTitle => '6 défis accomplis';

  @override
  String get milestoneConsistencyChallengesDesc =>
      'Tu as relevé 6 défis du mois. Six mois d’engagement financier concret.';

  @override
  String get rcSalaryLabel => 'Ton revenu';

  @override
  String get rcAgeLabel => 'Ton âge';

  @override
  String get rcCantonLabel => 'Ton canton';

  @override
  String get rcCivilStatusLabel => 'Ta situation civile';

  @override
  String get rcEmploymentStatusLabel => 'Ton statut professionnel';

  @override
  String get rcLppLabel => 'Tes données LPP';

  @override
  String get expertTitle => 'Consulter un·e spécialiste';

  @override
  String get expertSubtitle =>
      'MINT prépare ton dossier pour un rendez-vous efficace';

  @override
  String get expertDisclaimer =>
      'MINT facilite la mise en relation — ne remplace pas un conseil personnalisé (LSFin art. 3)';

  @override
  String get expertSpecRetirement => 'Retraite';

  @override
  String get expertSpecSuccession => 'Succession';

  @override
  String get expertSpecExpatriation => 'Expatriation';

  @override
  String get expertSpecDivorce => 'Divorce';

  @override
  String get expertSpecSelfEmployment => 'Indépendant·e';

  @override
  String get expertSpecRealEstate => 'Immobilier';

  @override
  String get expertSpecTax => 'Fiscalité';

  @override
  String get expertSpecDebt => 'Gestion de dettes';

  @override
  String get expertDossierTitle => 'Ton dossier préparé';

  @override
  String expertDossierIncomplete(int count) {
    return 'Profil incomplet — $count données manquantes';
  }

  @override
  String get expertRequestSession => 'Demander un rendez-vous';

  @override
  String get expertSessionRequested => 'Demande envoyée';

  @override
  String get expertMissingData =>
      'Donnée estimée — à confirmer avec le·la spécialiste';

  @override
  String get expertDossierSectionSituation => 'Situation personnelle';

  @override
  String get expertDossierSectionPrevoyance => 'Prévoyance';

  @override
  String get expertDossierSectionPatrimoine => 'Patrimoine';

  @override
  String get expertDossierSectionFinancement => 'Financement';

  @override
  String get expertDossierSectionDeductions => 'Déductions fiscales';

  @override
  String get expertDossierSectionBudget => 'Budget & dettes';

  @override
  String get expertItemAge => 'Âge';

  @override
  String get expertItemSalaryRange => 'Revenu brut annuel';

  @override
  String get expertItemCoupleStatus => 'Situation familiale';

  @override
  String get expertItemConjointAge => 'Âge du·de la conjoint·e';

  @override
  String get expertItemLppBalance => 'Avoir LPP';

  @override
  String get expertItem3aStatus => 'Pilier 3a';

  @override
  String get expertItem3aBalance => 'Capital 3a';

  @override
  String get expertItemLppBuybackPotential => 'Rachat LPP possible';

  @override
  String get expertItemAvsYears => 'Années AVS cotisées';

  @override
  String get expertItemReplacementRate => 'Taux de remplacement estimé';

  @override
  String get expertItemFamilyStatus => 'Situation civile';

  @override
  String get expertItemChildren => 'Enfants';

  @override
  String get expertItemPatrimoineRange => 'Patrimoine estimé';

  @override
  String get expertItemPropertyStatus => 'Logement';

  @override
  String get expertItemPropertyValue => 'Valeur immobilière';

  @override
  String get expertItemNationality => 'Nationalité';

  @override
  String get expertItemArchetype => 'Profil fiscal';

  @override
  String get expertItemYearsInCh => 'Années en Suisse';

  @override
  String get expertItemResidencePermit => 'Permis de séjour';

  @override
  String get expertItemAvsStatus => 'Statut AVS';

  @override
  String get expertItemAvsGaps => 'Lacunes AVS';

  @override
  String get expertItemCivilStatus => 'Statut civil';

  @override
  String get expertItemConjointLpp => 'LPP conjoint·e';

  @override
  String get expertItemEmploymentStatus => 'Statut professionnel';

  @override
  String get expertItemLppCoverage => 'Couverture LPP';

  @override
  String get expertItemCanton => 'Canton';

  @override
  String get expertItemCurrentHousing => 'Logement actuel';

  @override
  String get expertItemEquityEstimate => 'Fonds propres disponibles';

  @override
  String get expertItemLppEpl => 'EPL LPP possible';

  @override
  String get expertItemMortgageBalance => 'Hypothèque en cours';

  @override
  String get expertItemDebtRatio => 'Ratio d\'endettement';

  @override
  String get expertItemChargesVsIncome => 'Charges vs revenu';

  @override
  String get expertItemDebtType => 'Types de dettes';

  @override
  String get expertValueUnknown => 'Non renseigné';

  @override
  String get expertValueNone => 'Aucun·e';

  @override
  String get expertValueOwner => 'Propriétaire';

  @override
  String get expertValueTenant => 'Locataire';

  @override
  String get expertValueSingle => 'Célibataire';

  @override
  String get expertValueMarried => 'Marié·e';

  @override
  String get expertValueDivorced => 'Divorcé·e';

  @override
  String get expertValueWidowed => 'Veuf·ve';

  @override
  String get expertValueConcubinage => 'En concubinage';

  @override
  String get expertValue3aActive => 'Actif';

  @override
  String get expertValue3aInactive => 'Inactif';

  @override
  String get expertValueLppYes => 'Couvert·e';

  @override
  String get expertValueLppNo => 'Non couvert·e';

  @override
  String get expertValueLppEplPossible => 'Possible (à vérifier)';

  @override
  String get expertValueDebtNone => 'Pas de dettes';

  @override
  String get expertValueDebtLow => 'Faible (< 50 % du revenu annuel)';

  @override
  String get expertValueDebtMedium => 'Modéré (50–100 % du revenu annuel)';

  @override
  String get expertValueDebtHigh => 'Élevé (> 100 % du revenu annuel)';

  @override
  String get expertValueChargesNone => 'Aucune charge de dette';

  @override
  String get expertValueSalarie => 'Salarié·e';

  @override
  String get expertValueIndependant => 'Indépendant·e';

  @override
  String get expertValueChomage => 'Au chômage';

  @override
  String get expertValueRetraite => 'Retraité·e';

  @override
  String get expertDebtTypeConso => 'Crédit conso';

  @override
  String get expertDebtTypeLeasing => 'Leasing';

  @override
  String get expertDebtTypeHypo => 'Hypothèque';

  @override
  String get expertDebtTypeAutre => 'Autres dettes';

  @override
  String get expertArchetypeSwissNative => 'Résident·e suisse';

  @override
  String get expertArchetypeExpatEu => 'Expat EU/AELE';

  @override
  String get expertArchetypeExpatNonEu => 'Expat hors EU';

  @override
  String get expertArchetypeExpatUs => 'Résident·e US (FATCA)';

  @override
  String get expertArchetypeIndepWithLpp => 'Indépendant·e avec LPP';

  @override
  String get expertArchetypeIndepNoLpp => 'Indépendant·e sans LPP';

  @override
  String get expertArchetypeCrossBorder => 'Frontalier·ère';

  @override
  String get expertArchetypeReturningSwiss => 'Suisse de retour';

  @override
  String get expertMissingLppBalance => 'Avoir LPP non renseigné';

  @override
  String get expertMissingAvsYears => 'Années AVS non renseignées';

  @override
  String get expertMissingLppBuyback => 'Lacune de rachat LPP inconnue';

  @override
  String get expertMissing3a => 'Capital 3a non renseigné';

  @override
  String get expertMissingConjoint => 'Données conjoint·e manquantes';

  @override
  String get expertMissingPatrimoine => 'Patrimoine non renseigné';

  @override
  String get expertMissingHousing => 'Situation logement inconnue';

  @override
  String get expertMissingChildren => 'Nombre d\'enfants non renseigné';

  @override
  String get expertMissingNationality => 'Nationalité non renseignée';

  @override
  String get expertMissingArrivalAge =>
      'Âge d\'arrivée en Suisse non renseigné';

  @override
  String get expertMissingPermit => 'Permis de séjour non renseigné';

  @override
  String get expertMissingConjointLpp => 'LPP conjoint·e non renseignée';

  @override
  String get expertMissingIndependantStatus =>
      'Statut indépendant non confirmé';

  @override
  String get expertMissingLppCoverage => 'Couverture LPP non renseignée';

  @override
  String get expertMissingCanton => 'Canton non renseigné';

  @override
  String get expertMissingEquity => 'Fonds propres non renseignés';

  @override
  String get expertMissingHousingStatus => 'Statut logement non renseigné';

  @override
  String get expertMissingDebtDetail => 'Détail des dettes manquant';

  @override
  String get expertMissingMensualites =>
      'Mensualités de dettes non renseignées';

  @override
  String get agentFormTitle => 'Formulaire pré-rempli';

  @override
  String get agentFormDisclaimer =>
      'Vérifie chaque champ avant envoi. MINT ne soumet rien à ta place.';

  @override
  String get agentFormValidateAll => 'Je confirme avoir vérifié';

  @override
  String get agentFormEstimated => 'Estimé — à confirmer';

  @override
  String get agentLetterTitle => 'Lettre préparée';

  @override
  String get agentLetterDisclaimer =>
      'Adapte et envoie toi-même. MINT ne transmet rien.';

  @override
  String get agentLetterPensionSubject => 'Demande d\'extrait de prévoyance';

  @override
  String get agentLetterTransferSubject =>
      'Demande de transfert de libre passage';

  @override
  String get agentLetterAvsSubject => 'Demande d\'extrait de compte AVS';

  @override
  String get agentLetterPlaceholderName => '[Ton nom complet]';

  @override
  String get agentLetterPlaceholderAddress => '[Ton adresse]';

  @override
  String get agentLetterPlaceholderSsn => '[Ton numéro AVS]';

  @override
  String get agentLetterPlaceholderDate => '[Date]';

  @override
  String get agentTaxFormTitle => 'Déclaration d\'impôt — pré-remplissage';

  @override
  String get agent3aFormTitle => 'Attestation 3a';

  @override
  String get agentLppFormTitle => 'Formulaire de rachat LPP';

  @override
  String agentFieldSource(String source) {
    return 'Source : $source';
  }

  @override
  String get agentValidationRequired =>
      'Validation requise avant toute utilisation';

  @override
  String get agentOutputDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil financier, fiscal ou juridique. Vérifie chaque information. Conforme à la LSFin.';

  @override
  String get agentNoAction =>
      'MINT ne soumet, ne transmet et n\'exécute rien automatiquement.';

  @override
  String get agentSpecialistLabel => 'un·e spécialiste agréé·e';

  @override
  String get agentLppBuybackTitle => 'Demande de rachat LPP';

  @override
  String get agentPensionFundSubject => 'Demande de certificat de prévoyance';

  @override
  String get agentLppTransferSubject =>
      'Demande de transfert de prévoyance (libre passage)';

  @override
  String get agentFormCantonFallback => '[canton]';

  @override
  String get agentFormRevenuBrut => 'Revenu brut estimé';

  @override
  String get agentFormCanton => 'Canton de domicile';

  @override
  String get agentFormSituationFamiliale => 'Situation familiale';

  @override
  String get agentFormNbEnfants => 'Nombre d\'enfants';

  @override
  String get agentFormDeduction3a => 'Déduction 3a possible';

  @override
  String get agentFormRachatLppDeductible => 'Rachat LPP déductible estimé';

  @override
  String get agentFormStatutProfessionnel => 'Statut professionnel';

  @override
  String get agentFormBeneficiaireNom => 'Nom du/de la bénéficiaire';

  @override
  String get agentFormNumeroCompte3a => 'Numéro de compte 3a';

  @override
  String agentFormMontantVersement(String plafond, String year) {
    return '~$plafond CHF (plafond $year)';
  }

  @override
  String get agentFormMontantVersementLabel => 'Montant versement annuel';

  @override
  String get agentFormTypeContrat => 'Type de contrat';

  @override
  String get agentFormTypeContratSalarie => 'Salarié·e avec LPP';

  @override
  String get agentFormTypeContratIndependant => 'Indépendant·e sans LPP';

  @override
  String get agentFormToComplete => '[À compléter]';

  @override
  String get agentFormTitulaireNom => 'Nom du/de la titulaire';

  @override
  String get agentFormNumeroPolice => 'Numéro de police';

  @override
  String get agentFormAvoirLpp => 'Avoir LPP actuel';

  @override
  String get agentFormRachatMax => 'Rachat maximum disponible';

  @override
  String get agentFormRachatsDeja => 'Rachats déjà effectués';

  @override
  String get agentFormMontantRachatSouhaite => 'Montant du rachat souhaité';

  @override
  String get agentFormToCompleteAupres => '[À compléter auprès de la caisse]';

  @override
  String agentFormToCompleteMax(String max) {
    return '[À saisir — max $max CHF]';
  }

  @override
  String get agentFormCivilCelibataire => 'Célibataire';

  @override
  String get agentFormCivilMarie => 'Marié·e';

  @override
  String get agentFormCivilDivorce => 'Divorcé·e';

  @override
  String get agentFormCivilVeuf => 'Veuf·ve';

  @override
  String get agentFormCivilConcubinage => 'Concubinage';

  @override
  String get agentFormEmplSalarie => 'Salarié·e';

  @override
  String get agentFormEmplIndependant => 'Indépendant·e';

  @override
  String get agentFormEmplChomage => 'En recherche d\'emploi';

  @override
  String get agentFormEmplRetraite => 'Retraité·e';

  @override
  String get agentLetterCaisseFallback => '[Nom de la caisse de pension]';

  @override
  String get agentLetterPostalCity => '[Code postal et ville]';

  @override
  String get agentLetterCaisseAddress => '[Adresse de la caisse]';

  @override
  String get agentLetterPoliceNumber => '[Numéro de police : À compléter]';

  @override
  String get agentLetterCaisseCurrentName => '[Caisse de pension actuelle]';

  @override
  String get agentLetterCaisseCurrentAddress =>
      '[Adresse de la caisse actuelle]';

  @override
  String get agentLetterToComplete => '[À compléter]';

  @override
  String get agentLetterAvsOrg => 'Caisse de compensation AVS compétente';

  @override
  String get agentLetterAvsAddress => '[Adresse]';

  @override
  String agentLetterPensionFundBody(
      String name,
      String address,
      String postalCity,
      String caisse,
      String caisseAddress,
      String date,
      String dateFormatted,
      String subject,
      String year,
      String policeNumber) {
    return '$name\n$address\n$postalCity\n\n$caisse\n$caisseAddress\n$postalCity\n\n$date, le $dateFormatted\n\nObjet : $subject\n\nMadame, Monsieur,\n\nPar la présente, je me permets de vous adresser les demandes suivantes concernant mon dossier de prévoyance professionnelle :\n\n1. Certificat de prévoyance actualisé $year (avoir de vieillesse, prestations couvertes, taux de conversion applicable)\n\n2. Confirmation de ma capacité de rachat (montant maximal selon l\'art. 79b LPP)\n\n3. Simulation de retraite anticipée (projection de l\'avoir et de la rente à 63 et 64 ans, le cas échéant)\n\nJe vous remercie par avance de votre diligence et reste à votre disposition pour tout complément d\'information.\n\nVeuillez agréer, Madame, Monsieur, mes salutations distinguées.\n\n$name\n$policeNumber';
  }

  @override
  String agentLetterLppTransferBody(
      String name,
      String address,
      String postalCity,
      String caisseSource,
      String caisseCurrentAddress,
      String date,
      String dateFormatted,
      String subject,
      String toComplete) {
    return '$name\n$address\n$postalCity\n\n$caisseSource\n$caisseCurrentAddress\n$postalCity\n\n$date, le $dateFormatted\n\nObjet : $subject\n\nMadame, Monsieur,\n\nEn raison de la cessation de mes rapports de travail / de mon départ de Suisse (biffer la mention inutile), je vous prie de bien vouloir procéder au transfert de mon avoir de libre passage.\n\nMontant à transférer : la totalité de mon avoir de libre passage à la date de sortie.\n\nEtablissement de destination :\nNom : $toComplete\nIBAN ou numéro de compte : $toComplete\nAdresse : $toComplete\n\nDate de sortie : $toComplete\n\nJe vous remercie de votre diligence et de me confirmer la bonne exécution de ce transfert.\n\nVeuillez agréer, Madame, Monsieur, mes salutations distinguées.\n\n$name';
  }

  @override
  String agentLetterAvsExtractBody(
      String name,
      String ssn,
      String address,
      String postalCity,
      String avsOrg,
      String avsAddress,
      String date,
      String dateFormatted,
      String subject) {
    return '$name\n$ssn\n$address\n$postalCity\n\n$avsOrg\n$avsAddress\n$postalCity\n\n$date, le $dateFormatted\n\nObjet : $subject\n\nMadame, Monsieur,\n\nJe vous prie de bien vouloir m\'adresser un extrait de mon compte individuel AVS (CI) afin de vérifier l\'état de mes cotisations et d\'identifier d\'éventuelles lacunes.\n\nJe vous remercie par avance de votre diligence.\n\nVeuillez agréer, Madame, Monsieur, mes salutations distinguées.\n\n$name';
  }

  @override
  String get seasonalEventCta => 'En parler au coach';

  @override
  String get communityChallengeCta => 'Relever le défi';

  @override
  String get dossierExpertSectionTitle => 'Consulter un·e spécialiste';

  @override
  String get expertPrepareDossierCta => 'Préparer mon dossier';

  @override
  String get dossierAgentSectionTitle => 'Documents préparés';

  @override
  String get agentFormsTaxCta => 'Préparer ma déclaration';

  @override
  String get agentFormsTaxSubtitle => 'Pré-remplissage depuis ton profil';

  @override
  String get agentFormsAvsCta => 'Demander mon extrait AVS';

  @override
  String get agentFormsAvsSubtitle => 'Modèle de lettre prêt à envoyer';

  @override
  String get agentFormsLppCta => 'Demander un transfert LPP';

  @override
  String get agentFormsLppSubtitle => 'Lettre de transfert de libre passage';

  @override
  String get notifThreeATitle => 'Deadline 3a';

  @override
  String get notifThreeA92Days => 'Il reste 92 jours pour verser sur ton 3a.';

  @override
  String notifThreeA61Days(String saving) {
    return 'Il reste 61 jours. Économie estimée : CHF $saving.';
  }

  @override
  String notifThreeALastMonth(String saving) {
    return 'Dernier mois pour ton 3a. CHF $saving d\'économie en jeu.';
  }

  @override
  String get notifThreeA11Days => '11 jours. Dernier rappel 3a.';

  @override
  String notifNewYearTitle(String year) {
    return 'Nouveaux plafonds $year';
  }

  @override
  String notifNewYearBody(String year) {
    return 'Nouveaux plafonds $year. Ton économie potentielle a changé.';
  }

  @override
  String get notifCheckInTitle => 'Check-in mensuel';

  @override
  String get notifCheckInBody => 'Ton check-in mensuel est disponible.';

  @override
  String get notifTaxTitle => 'Déclaration fiscale';

  @override
  String get notifTax44Days =>
      'Déclaration fiscale dans 44 jours. Pense à rassembler tes documents.';

  @override
  String get notifTax16Days =>
      'Déclaration fiscale dans 16 jours. Commence à la remplir.';

  @override
  String get notifTaxLastWeek =>
      'Déclaration à rendre avant le 31 mars. Dernière semaine.';

  @override
  String get notifFriTitle => 'Score de solidité';

  @override
  String notifFriCheckIn(String delta) {
    return 'Depuis ton dernier check-in : $delta points.';
  }

  @override
  String notifFriImproved(String delta) {
    return 'Ta solidité a progressé de $delta points.';
  }

  @override
  String get notifProfileUpdatedTitle => 'Profil mis à jour';

  @override
  String get notifProfileUpdatedBody =>
      'Ton profil a été mis à jour. Nouvelles projections disponibles.';

  @override
  String get notifOffTrackTitle => 'Tu t\'éloignes de ton plan';

  @override
  String notifOffTrackBody(String adherence, String total, String impact) {
    return 'Adhérence à $adherence% sur $total actions. Indication linéaire (hors rendement/fiscalité) : ~CHF $impact.';
  }

  @override
  String get agentTaskTaxDeclarationTitle =>
      'Pré-remplissage déclaration fiscale';

  @override
  String get agentTaskTaxDeclarationDesc =>
      'Estimation des champs principaux de ta déclaration d\'impôts basée sur ton profil MINT. Tous les montants sont approximatifs.';

  @override
  String get agentTaskThreeAFormTitle => 'Pré-remplissage formulaire 3a';

  @override
  String get agentTaskThreeAFormDesc =>
      'Informations de base pour un versement 3e pilier. Le plafond est calculé selon ton statut professionnel.';

  @override
  String get agentTaskCaisseLetterTitle => 'Lettre à la caisse de pension';

  @override
  String get agentTaskCaisseLetterDesc =>
      'Modèle de lettre formelle pour demander un certificat LPP, une confirmation de rachat et une simulation de retraite anticipée.';

  @override
  String get agentTaskFiscalDossierTitle => 'Préparation dossier fiscal';

  @override
  String get agentTaskFiscalDossierDesc =>
      'Résumé éducatif de ta situation fiscale estimée avec les déductions possibles et les questions à poser à un·e spécialiste.';

  @override
  String get agentTaskAvsExtractTitle => 'Demande d\'extrait AVS';

  @override
  String get agentTaskAvsExtractDesc =>
      'Modèle de lettre pour demander un extrait de compte individuel (CI) auprès de ta caisse de compensation AVS.';

  @override
  String get agentTaskLppCertificateTitle => 'Demande certificat LPP';

  @override
  String get agentTaskLppCertificateDesc =>
      'Modèle de lettre pour demander un certificat de prévoyance professionnelle actualisé à ta caisse de pension.';

  @override
  String get agentTaskDisclaimer =>
      'Cet outil est purement éducatif et ne constitue pas un conseil financier, fiscal ou juridique. Les montants affichés sont des estimations indicatives. Consultez un·e spécialiste agréé·e avant toute décision. Conforme à la LSFin.';

  @override
  String get agentTaskValidationPromptDefault =>
      'Vérifie attentivement chaque information avant toute utilisation. Tous les champs sont des estimations à confirmer.';

  @override
  String get agentTaskValidationPromptLetter =>
      'Vérifie les informations et complète les champs entre crochets avant d\'envoyer cette lettre.';

  @override
  String get agentTaskValidationPromptRequest =>
      'Vérifie les informations et complète les champs entre crochets avant d\'envoyer cette demande.';

  @override
  String agentFieldRevenuBrutValue(String range) {
    return '~$range CHF/an';
  }

  @override
  String agentFieldRachatLppValue(String range) {
    return '~$range CHF';
  }

  @override
  String get agentFieldAnneRef => 'Année de référence';

  @override
  String get agentFieldCaissePension => 'Caisse de pension';

  @override
  String get agentFieldAddressPerso => 'Adresse personnelle';

  @override
  String get agentFieldAddresseCaisse => 'Adresse de la caisse';

  @override
  String get agentFieldNumeroPolice => 'Numéro de police';

  @override
  String get agentFieldNumeroAvs => 'Numéro AVS';

  @override
  String get agentFieldAddresseCaisseAvs => 'Adresse de la caisse AVS';

  @override
  String get agentFiscalDossierRevenu => 'Revenu brut estimé';

  @override
  String get agentFiscalDossierPlafond3a => 'Plafond 3a applicable';

  @override
  String get agentFiscalDossierRachat => 'Rachat LPP disponible';

  @override
  String get agentFiscalDossierCapital3a => 'Capital 3a accumulé';

  @override
  String get proactiveLifecycleChange =>
      'Tu viens d’entrer dans une nouvelle phase de vie. On regarde ce que ça change pour toi ?';

  @override
  String get proactiveWeeklyRecap =>
      'Ton récap de la semaine est prêt. Tu veux le voir ?';

  @override
  String proactiveGoalMilestone(String progress) {
    return 'Ton objectif a franchi les $progress %. Bien joué !';
  }

  @override
  String proactiveSeasonalReminder(String event) {
    return 'C’est la saison $event. Un bon moment pour…';
  }

  @override
  String proactiveInactivityReturn(String days) {
    return 'Content de te revoir ! Ça fait $days jours. On fait le point ?';
  }

  @override
  String proactiveConfidenceUp(String delta) {
    return 'Ta confiance a progressé de $delta pts depuis la dernière fois.';
  }

  @override
  String get proactiveNewCap => 'J’ai une nouvelle priorité pour toi.';

  @override
  String get dossierToolsSection => 'Outils';

  @override
  String get dossierToolsCta => 'Voir tous les outils';

  @override
  String get pulseNarrativeBudgetGoal => 'ta marge mensuelle :';

  @override
  String get pulseNarrativeHousingGoal => 'ta capacité d’achat estimée :';

  @override
  String get pulseNarrativeRetirementGoal => 'ton taux de remplacement :';

  @override
  String get pulseLabelBudgetFree => 'Marge libre ce mois-ci';

  @override
  String get pulseLabelPurchasingCapacity => 'Capacité d’achat estimée';

  @override
  String capSequenceProgress(int completed, int total) {
    return '$completed/$total étapes';
  }

  @override
  String get capSequenceComplete => 'Plan complété !';

  @override
  String get capSequenceCurrentStep => 'Prochaine étape';

  @override
  String get capStepRetirement01Title => 'Connaître ton salaire brut';

  @override
  String get capStepRetirement01Desc =>
      'La base de tous les calculs de retraite.';

  @override
  String get capStepRetirement02Title => 'Estimer ta rente AVS';

  @override
  String get capStepRetirement02Desc =>
      'Tes années cotisées déterminent ton 1er pilier.';

  @override
  String get capStepRetirement03Title => 'Vérifier ton avoir LPP';

  @override
  String get capStepRetirement03Desc =>
      'Le certificat LPP révèle ton capital 2e pilier.';

  @override
  String get capStepRetirement04Title => 'Calculer ton taux de remplacement';

  @override
  String get capStepRetirement04Desc =>
      'Combien de ton salaire tu toucheras à la retraite.';

  @override
  String get capStepRetirement05Title => 'Simuler un versement 3a';

  @override
  String get capStepRetirement05Desc =>
      'Déduire jusqu’à 7’258 CHF et booster ta retraite.';

  @override
  String get capStepRetirement06Title => 'Évaluer un rachat LPP';

  @override
  String get capStepRetirement06Desc =>
      'Combler les lacunes et réduire tes impôts.';

  @override
  String get capStepRetirement07Title => 'Comparer rente vs capital';

  @override
  String get capStepRetirement07Desc =>
      'Toucher une rente mensuelle ou retirer le capital ?';

  @override
  String get capStepRetirement08Title => 'Planifier le décaissement';

  @override
  String get capStepRetirement08Desc =>
      'L’ordre de retrait impacte ta fiscalité.';

  @override
  String get capStepRetirement09Title => 'Optimiser fiscalement';

  @override
  String get capStepRetirement09Desc =>
      '3a, rachat, timing : réduire l’imposition du capital.';

  @override
  String get capStepRetirement10Title => 'Consulter un·e spécialiste';

  @override
  String get capStepRetirement10Desc =>
      'Un regard expert sur ta situation complète.';

  @override
  String get capStepBudget01Title => 'Connaître tes revenus';

  @override
  String get capStepBudget01Desc =>
      'Le point de départ de tout bilan budgétaire.';

  @override
  String get capStepBudget02Title => 'Lister tes charges fixes';

  @override
  String get capStepBudget02Desc =>
      'Loyer, assurance maladie, transports : les inévitables.';

  @override
  String get capStepBudget03Title => 'Calculer ta marge libre';

  @override
  String get capStepBudget03Desc =>
      'Ce qui reste après les charges — ton vrai terrain de jeu.';

  @override
  String get capStepBudget04Title => 'Identifier les économies possibles';

  @override
  String get capStepBudget04Desc => 'Petits ajustements, grand impact mensuel.';

  @override
  String get capStepBudget05Title => 'Construire une épargne de précaution';

  @override
  String get capStepBudget05Desc =>
      '3 mois de charges liquides : ton filet de sécurité.';

  @override
  String get capStepBudget06Title => 'Planifier le 3a';

  @override
  String get capStepBudget06Desc =>
      'Chaque franc versé réduit tes impôts et prépare la retraite.';

  @override
  String get capStepHousing01Title => 'Connaître tes revenus';

  @override
  String get capStepHousing01Desc => 'La base du calcul de capacité d’achat.';

  @override
  String get capStepHousing02Title => 'Évaluer tes fonds propres';

  @override
  String get capStepHousing02Desc =>
      'Épargne, 3a et LPP : assembler l’apport nécessaire.';

  @override
  String get capStepHousing03Title => 'Calculer ta capacité d’achat';

  @override
  String get capStepHousing03Desc => 'Jusqu’à quel prix peux-tu acheter ?';

  @override
  String get capStepHousing04Title => 'Simuler l’hypothèque';

  @override
  String get capStepHousing04Desc =>
      'Charge mensuelle, amortissement, taux théorique.';

  @override
  String get capStepHousing05Title => 'Évaluer l’EPL (2e pilier)';

  @override
  String get capStepHousing05Desc =>
      'Retrait anticipé LPP pour financer l’apport.';

  @override
  String get capStepHousing06Title => 'Comparer location vs achat';

  @override
  String get capStepHousing06Desc => 'Le calcul qui dépasse les intuitions.';

  @override
  String get capStepHousing07Title => 'Consulter un·e spécialiste';

  @override
  String get capStepHousing07Desc =>
      'Notaire, courtier, spécialiste : quand impliquer qui.';

  @override
  String get goalSelectorTitle => 'Quel est ton objectif principal ?';

  @override
  String get goalSelectorAuto => 'Laisser MINT décider';

  @override
  String get goalSelectorAutoDesc =>
      'MINT adapte automatiquement selon ton profil';

  @override
  String get goalRetirementTitle => 'Ma retraite';

  @override
  String get goalRetirementDesc => 'Planifier la transition vers la retraite';

  @override
  String get goalBudgetTitle => 'Mon budget';

  @override
  String get goalBudgetDesc => 'Maîtriser mes dépenses et épargner';

  @override
  String get goalHousingTitle => 'Acheter un logement';

  @override
  String get goalHousingDesc => 'Évaluer ma capacité et planifier l’achat';

  @override
  String get goalTaxTitle => 'Payer moins d’impôts';

  @override
  String get goalTaxDesc => 'Optimiser mes déductions (3a, rachat LPP)';

  @override
  String get goalDebtTitle => 'Gérer mes dettes';

  @override
  String get goalDebtDesc => 'Retrouver de la marge et rembourser';

  @override
  String get goalBirthTitle => 'Préparer une naissance';

  @override
  String get goalBirthDesc => 'Anticiper les coûts et adapter le budget';

  @override
  String get goalIndependentTitle => 'Devenir indépendant·e';

  @override
  String get goalIndependentDesc => 'Prévoyance, fiscalité et couverture';

  @override
  String pulseGoalChip(String goal) {
    return 'Objectif : $goal';
  }

  @override
  String get dossierProfileSection => 'Mon profil';

  @override
  String get dossierPlanSection => 'Mon plan';

  @override
  String get dossierDataSection => 'Mes données';

  @override
  String get dossierConfidenceLabel => 'Fiabilité du dossier';

  @override
  String get dossierCompleteCta => 'Compléter mon profil';

  @override
  String get dossierChooseGoalCta => 'Choisir un objectif';

  @override
  String get dossierScanLppCta => 'Scanner mon certificat LPP';

  @override
  String get dossierDataRevenu => 'Revenu';

  @override
  String get dossierDataLpp => '2e pilier';

  @override
  String get dossierData3a => '3e pilier';

  @override
  String get dossierDataBudget => 'Marge mensuelle';

  @override
  String get dossierDataUnknown => 'Non renseigné';

  @override
  String dossierPlanProgress(int done, int total) {
    return '$done / $total étapes';
  }

  @override
  String get dossierPlanChangeGoal => 'Changer d’objectif';

  @override
  String get dossierPlanCurrentStep => 'Étape en cours';

  @override
  String get dossierPlanNextStep => 'Prochaine étape';

  @override
  String dossierConfidencePct(int pct) {
    return '$pct %';
  }

  @override
  String memoryRefTopic(int days, String topic) {
    return 'Il y a $days jours, tu m’avais parlé de $topic.';
  }

  @override
  String memoryRefGoal(String goal) {
    return 'Tu t’étais fixé l’objectif : $goal. On fait le point ?';
  }

  @override
  String memoryRefScreenVisit(String screen) {
    return 'La dernière fois, tu avais utilisé $screen.';
  }

  @override
  String get memoryRefRecentInsights => 'Ce que je retiens de nos échanges :';

  @override
  String openerBudgetDeficit(String deficit) {
    return 'CHF $deficit/mois de déficit. On regarde où ça coince ?';
  }

  @override
  String opener3aDeadline(String days, String plafond) {
    return 'Il reste $days jours pour verser jusqu’à $plafond CHF dans ton 3a.';
  }

  @override
  String openerGapWarning(String rate, String gap) {
    return 'Ton taux de remplacement : $rate %. À la retraite, il te manquerait CHF $gap/mois.';
  }

  @override
  String openerSavingsOpportunity(String plafond) {
    return 'Ton 3a : CHF 0 cette année. $plafond CHF d’économie d’impôt en jeu.';
  }

  @override
  String openerProgressCelebration(String delta) {
    return 'Ta fiabilité a gagné $delta points. Tes chiffres sont plus précis.';
  }

  @override
  String openerPlanProgress(String n, String total, String next) {
    return 'Étape $n/$total validée. Prochaine : $next.';
  }

  @override
  String get semanticsBackButton => 'Retour';

  @override
  String get semanticsDecrement => 'Diminuer';

  @override
  String get semanticsIncrement => 'Augmenter';

  @override
  String get frontalierDisclaimer =>
      'Estimations simplifiées à but éducatif — ne constitue pas un conseil fiscal ou juridique. Les montants dépendent de nombreux facteurs (déductions, commune, fortune, convention internationale, etc.). Consulte un·e spécialiste fiscal·e pour une analyse personnalisée. LSFin.';

  @override
  String get firstJobPayslipAvsLabel => 'AVS/AI/APG';

  @override
  String get firstJobPayslipAvsExplanation =>
      'Cotisation salarié·e : 5.3% du brut. Ton employeur paie aussi 5.3% en plus.';

  @override
  String get firstJobPayslipLppLabel => 'LPP (2e pilier)';

  @override
  String get firstJobPayslipLppExplanation =>
      'Épargne vieillesse obligatoire dès 25 ans. Le taux exact dépend de ta caisse et ton âge.';

  @override
  String get firstJobPayslipImpotLabel => 'Impôt à la source (estimation)';

  @override
  String get firstJobPayslipImpotExplanation =>
      'Retenu directement sur le salaire si tu es imposé·e à la source. Le taux varie selon canton, statut et revenu.';

  @override
  String get firstJobChecklistDeadline1 => 'Avant de quitter';

  @override
  String get firstJobChecklistAction1 =>
      'Demande ton certificat LPP à ton employeur actuel.';

  @override
  String get firstJobChecklistConsequence1 =>
      'Sans certificat, tu ne peux pas vérifier que le montant transféré est correct.';

  @override
  String get firstJobChecklistDeadline2 => '30 jours';

  @override
  String get firstJobChecklistAction2 =>
      'Vérifie que ton avoir LPP a été transféré à la caisse de ton nouvel employeur.';

  @override
  String get firstJobChecklistConsequence2 =>
      'Sans transfert, ton capital va à la Fondation supplétive à un taux de 0.05%.';

  @override
  String get firstJobChecklistDeadline3 => '1 mois';

  @override
  String get firstJobChecklistAction3 =>
      'Informe ton assurance-maladie LAMal du changement d\'employeur si tu bénéficiais d\'une couverture collective.';

  @override
  String get firstJobChecklistDeadline4 => 'Dès le premier salaire';

  @override
  String get firstJobChecklistAction4 =>
      'Continue tes versements au pilier 3a — l\'interruption te coûte des déductions fiscales.';

  @override
  String get firstJobBudgetBesoins => 'Besoins';

  @override
  String get firstJobBudgetLoyer => 'Loyer';

  @override
  String get firstJobBudgetTransport => 'Transport';

  @override
  String get firstJobBudgetAlimentation => 'Alimentation';

  @override
  String get firstJobBudgetEnvies => 'Envies';

  @override
  String get firstJobBudgetLoisirs => 'Loisirs';

  @override
  String get firstJobBudgetRestaurants => 'Restaurants';

  @override
  String get firstJobBudgetVoyages => 'Voyages';

  @override
  String get firstJobBudgetShopping => 'Shopping';

  @override
  String get firstJobBudgetEpargne => 'Épargne & 3a';

  @override
  String get firstJobBudgetPilier3a => 'Pilier 3a';

  @override
  String get firstJobBudgetEpargneCourt => 'Épargne';

  @override
  String get firstJobBudgetFondsUrgence => 'Fonds d\'urgence';

  @override
  String firstJobBudgetChiffreChoc(String annual, String future) {
    return 'Si tu épargnes $annual CHF/an dès maintenant, tu auras ~$future CHF à 65 ans.';
  }

  @override
  String get firstJobScenarioMySalary => 'Mon salaire';

  @override
  String get firstJobScenarioDefault => 'Défaut';

  @override
  String get firstJobScenarioMedianCH => 'Médian CH';

  @override
  String get firstJobScenarioBoosted => '+20%';

  @override
  String firstJobScenarioSemantics(String label) {
    return 'Scénario salaire : $label';
  }

  @override
  String get pulseRetirementIncome => 'Revenu retraite estimé';

  @override
  String get pulseCapImpact => 'Levier identifié';

  @override
  String get dossierAddConjointCta => 'Ajouter mon·ma conjoint·e';

  @override
  String get dossierDataAvs => '1er pilier';

  @override
  String get dossierDataFiscalite => 'Fiscalité';

  @override
  String get pulseRetirementIncomeEstimated => 'Retraite estimée (minimum LPP)';

  @override
  String get dossierScanLppPrecision =>
      'Scanne ton certificat pour des projections plus précises';

  @override
  String get pulsePlanTitle => 'Mon plan';

  @override
  String pulsePlanProgress(int completed, int total) {
    return '$completed/$total';
  }

  @override
  String pulsePlanNextStep(String stepName) {
    return 'Prochaine étape : $stepName';
  }

  @override
  String get dossierCoachingTitle => 'Accompagnement';

  @override
  String get dossierCoachingSubtitle => 'Fréquence des rappels et suggestions';

  @override
  String get coachingSheetSubtitle =>
      'Choisis à quel rythme MINT t\'accompagne';

  @override
  String get coachingIntensityDiscret => 'Discret';

  @override
  String get coachingIntensityCalme => 'Calme';

  @override
  String get coachingIntensityEquilibre => 'Équilibré';

  @override
  String get coachingIntensityAttentif => 'Attentif';

  @override
  String get coachingIntensityProactif => 'Proactif';

  @override
  String get coachingDescDiscret =>
      'MINT te laisse tranquille. Rappels rares, uniquement les échéances critiques.';

  @override
  String get coachingDescCalme =>
      'MINT intervient de temps en temps. Un rappel tous les 3 jours maximum.';

  @override
  String get coachingDescEquilibre =>
      'MINT te guide au quotidien. Un rappel par jour, des suggestions contextuelles.';

  @override
  String get coachingDescAttentif =>
      'MINT est attentif à chaque session. Suggestions fréquentes et mémoire riche.';

  @override
  String get coachingDescProactif =>
      'MINT t\'accompagne activement. Rappels à chaque visite, mémoire complète.';

  @override
  String coachingEngagementStats(Object engaged, Object total) {
    return '$engaged interactions sur $total suggestions';
  }

  @override
  String get landingHiddenAmount => 'Montant masqué';

  @override
  String get landingHiddenSubtitle => 'Créez un compte pour voir vos chiffres';

  @override
  String get friBarTitle => 'Résilience financière';

  @override
  String get friBarLiquidity => 'Liquidité';

  @override
  String get friBarFlexibility => 'Flexibilité';

  @override
  String get friBarResilience => 'Résilience';

  @override
  String get friBarStability => 'Stabilité';

  @override
  String get deuxViesTitle => 'Vos deux vies';

  @override
  String deuxViesGap(String amount, String name) {
    return 'Écart de $amount/mois en faveur de $name';
  }

  @override
  String deuxViesLever(String lever, String impact) {
    return '$lever comblerait $impact de l\'écart';
  }

  @override
  String get deuxViesDisclaimer =>
      'Outil éducatif. Ne constitue pas un conseil financier (LSFin).';

  @override
  String get expertTierScreenTitle => 'Consulter un·e spécialiste';

  @override
  String get expertTierFinancialPlanner => 'Planificateur·rice financier·ère';

  @override
  String get expertTierFinancialPlannerDesc =>
      'Retraite, prévoyance, décaissement, stratégie patrimoniale globale';

  @override
  String get expertTierTaxSpecialist => 'Fiscaliste';

  @override
  String get expertTierTaxSpecialistDesc =>
      'Optimisation fiscale, rachat LPP, déclaration, planification inter-cantonale';

  @override
  String get expertTierNotary => 'Notaire';

  @override
  String get expertTierNotaryDesc =>
      'Succession, testament, donation, régime matrimonial, pacte successoral';

  @override
  String get expertTierPrice => '129 CHF / session';

  @override
  String get expertTierSelectCta => 'Préparer mon dossier';

  @override
  String get expertTierDossierPreviewTitle => 'Aperçu de ton dossier';

  @override
  String get expertTierDossierGenerating => 'Préparation du dossier…';

  @override
  String get expertTierDossierReady => 'Dossier prêt';

  @override
  String get expertTierRequestCta => 'Demander un rendez-vous';

  @override
  String get expertTierComingSoonTitle => 'Bientôt disponible';

  @override
  String get expertTierComingSoon =>
      'La prise de rendez-vous arrive prochainement. Ton dossier est prêt — tu pourras le transmettre dès l’ouverture du service.';

  @override
  String expertTierCompleteness(String percent) {
    return 'Profil complet à $percent %';
  }

  @override
  String get expertTierEstimated => 'Estimé';

  @override
  String get expertTierMissingDataTitle => 'Données à compléter';

  @override
  String get expertTierDisclaimerBanner =>
      'MINT prépare le dossier, le·la spécialiste donne le conseil';

  @override
  String get expertTierBack => 'Choisir un autre spécialiste';

  @override
  String get expertTierOk => 'Compris';

  @override
  String get docCardTitle => 'Document pré-rempli';

  @override
  String get docCardFiscalDeclaration => 'Déclaration fiscale';

  @override
  String get docCardPensionFundLetter => 'Courrier caisse de pension';

  @override
  String get docCardLppBuybackRequest => 'Demande de rachat LPP';

  @override
  String get docCardDisclaimer => 'Vérifie chaque champ. MINT ne soumet rien.';

  @override
  String get docCardViewDocument => 'Consulter le document';

  @override
  String get docCardValidationFailed => 'La validation du document a échoué.';

  @override
  String get docCardGenerating => 'Génération du document…';

  @override
  String docCardFieldCount(int count) {
    return '$count champs pré-remplis';
  }

  @override
  String get docCardReadOnly => 'Lecture seule — à compléter manuellement';

  @override
  String get sourceBadgeEstimated => 'Estimé';

  @override
  String get sourceBadgeDeclared => 'Déclaré';

  @override
  String get sourceBadgeCertified => 'Certifié';

  @override
  String get monteCarloTitle => 'Tes chances de vivre confortablement';

  @override
  String monteCarloSubtitle(int count) {
    return '$count scénarios simulés';
  }

  @override
  String get monteCarloHeroPhrase =>
      'de chances que ton capital tienne jusqu’à 90 ans';

  @override
  String get monteCarloLegendWideBand => 'Fourchette large';

  @override
  String get monteCarloLegendProbableBand => 'Fourchette probable';

  @override
  String get monteCarloLegendMedian => 'Scénario central';

  @override
  String get monteCarloLegendCurrentIncome => 'Ce que tu gagnes aujourd’hui';

  @override
  String monteCarloMedianAtAge(int age) {
    return 'Scénario central à $age ans';
  }

  @override
  String get monteCarloProbableRange => 'Fourchette probable';

  @override
  String get monteCarloSuccessLabel =>
      'Probabilité que ton\ncapital tienne jusqu’à 90 ans';

  @override
  String get monteCarloDisclaimer =>
      'Les rendements passés ne présagent pas les rendements futurs. Simulation à titre pédagogique (LSFin).';

  @override
  String get dossierIdentiteSection => 'Identité';

  @override
  String get dossierDocumentsSection => 'Documents';

  @override
  String get dossierCoupleSection => 'Couple';

  @override
  String get dossierPreferencesSection => 'Préférences';

  @override
  String dossierUpdatedAgo(int days) {
    return 'Mis à jour il y a $days jours';
  }

  @override
  String dossierUpdatedOn(String date) {
    return 'Mis à jour le $date';
  }

  @override
  String get dossierUpdatedToday => 'Mis à jour aujourd’hui';

  @override
  String get dossierUpdatedYesterday => 'Mis à jour hier';

  @override
  String get exploreHubOtherTopics => 'Autres thématiques';

  @override
  String get bankImportSummaryHeader => 'RÉSUMÉ';

  @override
  String get bankImportTransactionsHeader => 'TRANSACTIONS';

  @override
  String bankImportMoreTransactions(int count) {
    return '... et $count autres transactions';
  }

  @override
  String get bankImportGenericError =>
      'Une erreur est survenue lors de l’analyse du relevé.';

  @override
  String get helpResourcesAppBarTitle => 'AIDE EN CAS DE DETTE';

  @override
  String get helpResourcesIntroTitle => 'Vous n’êtes pas seul';

  @override
  String get helpResourcesIntroBody =>
      'En Suisse, de nombreux services professionnels offrent un accompagnement gratuit et confidentiel pour les personnes confrontées à des difficultés financières. Demander de l’aide est un acte de courage, pas un signe de faiblesse.';

  @override
  String get helpResourcesIntroNote =>
      'Tous les liens ci-dessous mènent vers des sites externes. MINT ne transmet aucune donnée à ces services.';

  @override
  String get helpResourcesDettesName => 'Dettes Conseils Suisse';

  @override
  String get helpResourcesDettesDesc =>
      'Fédération faîtière des services de conseil en dettes en Suisse. Conseil gratuit, confidentiel et professionnel. Plus de 30 services membres dans toute la Suisse.';

  @override
  String get helpResourcesCaritasName => 'Caritas — Conseil en dettes';

  @override
  String get helpResourcesCaritasDesc =>
      'Service d’aide de Caritas Suisse pour les personnes en situation d’endettement. Aide au désendettement, négociation avec les créanciers, accompagnement budgétaire personnalisé.';

  @override
  String get helpResourcesFreeLabel => 'GRATUIT';

  @override
  String get helpResourcesCantonalHeader => 'SERVICE CANTONAL';

  @override
  String get helpResourcesCantonLabel => 'Votre canton';

  @override
  String get helpResourcesNoService =>
      'Aucun service cantonal référencé pour ce canton. Contactez Dettes Conseils Suisse pour être orienté.';

  @override
  String get helpResourcesPrivacyTitle => 'Protection des données (nLPD)';

  @override
  String get helpResourcesPrivacyBody =>
      'MINT ne transmet aucune donnée personnelle aux services référencés ci-dessus. Les liens externes ouvrent votre navigateur. Votre utilisation de cet écran reste strictement confidentielle et n’est ni enregistrée ni partagée.';

  @override
  String get helpResourcesDisclaimer =>
      'MINT fournit ces liens à titre informatif et pédagogique. Ces services sont indépendants de MINT. MINT ne fournit pas de conseil juridique ou financier. En cas de difficulté financière, contactez directement les services spécialisés.';

  @override
  String get successionUrgenceAction1 =>
      'Déclarer le décès à l’état civil dans les 2 jours';

  @override
  String get successionUrgenceAction2 =>
      'Informer l’employeur et les assurances (LAMal, LPP)';

  @override
  String get successionUrgenceAction3 =>
      'Bloquer les comptes bancaires conjoints si nécessaire';

  @override
  String get successionUrgenceAction4 =>
      'Contacter le notaire si la personne avait un testament';

  @override
  String get successionDemarchesAction1 =>
      'Demander les rentes de survivants AVS (LAVS art. 23)';

  @override
  String get successionDemarchesAction2 =>
      'Contacter la caisse LPP pour le capital décès';

  @override
  String get successionDemarchesAction3 =>
      'Résilier les abonnements et contrats au nom du défunt';

  @override
  String get successionDemarchesAction4 =>
      'Faire l’inventaire des avoirs et dettes';

  @override
  String get successionDemarchesAction5 =>
      'Demander les certificats d’héritiers au notaire';

  @override
  String get successionLegaleAction1 =>
      'Ouvrir la procédure de succession avec le notaire';

  @override
  String get successionLegaleAction2 =>
      'Partager les biens selon le testament ou la loi (CC art. 537)';

  @override
  String get successionLegaleAction3 =>
      'Déposer la déclaration fiscale pour l’année du décès';

  @override
  String get successionLegaleAction4 =>
      'Mettre à jour les bénéficiaires de vos propres contrats';

  @override
  String get disabilityGapAct1Label => 'ACTE 1 · Employeur';

  @override
  String get disabilityGapAct1Detail =>
      '80 % de ton salaire versé par ton employeur';

  @override
  String get disabilityGapAct1Duration => 'Semaines 1-26';

  @override
  String get disabilityGapAct2LabelIjm => 'ACTE 2 · IJM (assurance maladie)';

  @override
  String get disabilityGapAct2LabelNoIjm => 'ACTE 2 · Pas d’IJM';

  @override
  String get disabilityGapAct2SubIjm =>
      'Assurance collective — 80% pendant 720 jours max';

  @override
  String get disabilityGapAct2SubNoIjm =>
      'Sans IJM, tu passes directement à l’AI après l’employeur';

  @override
  String get disabilityGapAct2Duration => 'Jusqu’à 24 mois';

  @override
  String get disabilityGapAct2DetailIjm => '80% du salaire assuré';

  @override
  String get disabilityGapAct2DetailNoIjm =>
      'Aucune couverture — délai AI en cours';

  @override
  String get disabilityGapAct3Label => 'ACTE 3 · AI + LPP (définitif)';

  @override
  String get disabilityGapAct3Duration => 'Après 24 mois';

  @override
  String disabilityGapAct3Detail(
      String aiAmount, String lppAmount, String totalAmount) {
    return 'AI $aiAmount + LPP $lppAmount = $totalAmount CHF/mois';
  }

  @override
  String get disabilityGapIjmCoverage =>
      '80% pendant 720 jours — assurance collective';

  @override
  String get disabilityGapNoIjmCoverage =>
      'Aucune IJM souscrite — risque maximal';

  @override
  String disabilityGapAiDetail(String amount) {
    return 'Max $amount CHF/mois — délai ~14 mois';
  }

  @override
  String get disabilityGapLppCovered =>
      'Rente invalidité ≈ 40% salaire coordonné (LPP art. 23)';

  @override
  String get disabilityGapLppNotCovered =>
      'Salaire sous le seuil LPP — pas de couverture 2e pilier';

  @override
  String get disabilityGapSavingsLabel => 'Réserve d’urgence';

  @override
  String disabilityGapSavingsDetail(String months) {
    return '$months mois de charges couverts';
  }

  @override
  String get disabilityGapApgLabel => 'APG / IJM (perte de gain)';

  @override
  String get disabilityGapAiLabel => 'AI (assurance invalidité)';

  @override
  String get disabilityGapLppLabel => 'LPP invalidité (2e pilier)';

  @override
  String get disabilityGapSources =>
      '• LAI art. 28-29 (rente AI)\n• LPP art. 23-26 (invalidité 2e pilier)\n• CO art. 324a (maintien salaire employeur)\n• LPGA art. 19 (délai de carence)';

  @override
  String disabilityGapAgeLabel(int age) {
    return '$age ans';
  }

  @override
  String get documentDetailExplanationObligatoire =>
      'Montant accumulé dans la part obligatoire LPP';

  @override
  String get documentDetailExplanationSurobligatoire =>
      'Part au-delà du minimum légal';

  @override
  String get documentDetailExplanationTotal =>
      'Total de ton capital de vieillesse';

  @override
  String get documentDetailExplanationSalaireAssure =>
      'Salaire sur lequel les cotisations sont calculées';

  @override
  String get documentDetailExplanationSalaireAvs =>
      'Salaire déterminant pour l’AVS';

  @override
  String get documentDetailExplanationDeduction =>
      'Montant déduit pour coordonner avec l’AVS';

  @override
  String get documentDetailExplanationTauxOblig => 'Légal minimum : 6.8%';

  @override
  String get documentDetailExplanationTauxSurob =>
      'Fixé par ta caisse de pension';

  @override
  String get documentDetailExplanationTauxEnv => 'Taux moyen pondéré';

  @override
  String get documentDetailExplanationInvalidite =>
      'Rente en cas d’incapacité de travail';

  @override
  String get documentDetailExplanationDeces =>
      'Montant versé aux bénéficiaires en cas de décès';

  @override
  String get documentDetailExplanationConjoint =>
      'Rente versée au conjoint survivant';

  @override
  String get documentDetailExplanationEnfant => 'Rente versée par enfant';

  @override
  String get documentDetailExplanationRachat =>
      'Montant pouvant être racheté pour optimiser ta prévoyance';

  @override
  String get documentDetailExplanationEmploye => 'Ta contribution annuelle';

  @override
  String get documentDetailExplanationEmployeur =>
      'Contribution de ton employeur';

  @override
  String get disabilitySelfEmployedAlertLabel => '🚨  ALERTE INDÉPENDANT';

  @override
  String get disabilitySelfEmployedTitle => 'Ton filet n’existe pas';

  @override
  String get disabilitySelfEmployedAppBarTitle => 'Invalidité — Indépendant·e';

  @override
  String get disabilitySelfEmployedRevenueTitle => 'Ton revenu mensuel net';

  @override
  String get disabilitySelfEmployedRevenueHint =>
      'Ajuste pour voir l’impact sur ta situation réelle';

  @override
  String get disabilitySelfEmployedRevenueLabel => 'Revenu net/mois';

  @override
  String get disabilitySelfEmployedInsuranceQuestion =>
      'Tu as déjà une assurance perte de gain ?';

  @override
  String get disabilitySelfEmployedYes => 'Oui';

  @override
  String get disabilitySelfEmployedNo => 'Non / Je ne sais pas';

  @override
  String get disabilitySelfEmployedApgTip =>
      'Une APG individuelle dès CHF 45/mois peut couvrir 80% de ton revenu pendant 720 jours. C’est le filet le plus efficace pour un·e indépendant·e.';

  @override
  String get disabilitySelfEmployedDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil en assurance. Un·e courtier·ère indépendant·e peut comparer les offres APG de différents assureurs selon ton activité et ton revenu réel.';

  @override
  String get disabilitySelfEmployedSources =>
      '• LAMal art. 67-77 (assurance maladie perte de gain)\n• CO art. 324a (obligation employeur)\n• LAI art. 28 (rente AI)\n• LAVS art. 2 al. 3 (cotisation depuis l’étranger)';

  @override
  String get confidenceDashboardLevelExcellent => 'Excellente';

  @override
  String get confidenceDashboardLevelGood => 'Bonne';

  @override
  String get confidenceDashboardLevelFair => 'Correcte';

  @override
  String get confidenceDashboardLevelImprove => 'À améliorer';

  @override
  String get confidenceDashboardLevelInsufficient => 'Insuffisante';

  @override
  String get confidenceDashboardBreakdownTitle => 'Détail par axe';

  @override
  String get confidenceDashboardFeaturesTitle => 'Fonctionnalités débloquées';

  @override
  String confidenceDashboardRequired(String percent) {
    return '$percent % requis';
  }

  @override
  String get confidenceDashboardEnrichTitle => 'Améliore ta précision';

  @override
  String get confidenceDashboardSourcesTitle => 'Sources';

  @override
  String get cockpitDetailEmptyState =>
      'Complète ton profil pour accéder au cockpit détaillé.';

  @override
  String get cockpitDetailEnrichProfile => 'Enrichir mon profil';

  @override
  String get cockpitDetailDisclaimer =>
      'Outil éducatif simplifié. Ne constitue pas un conseil financier (LSFin). Sources : LAVS art. 21-29, LPP art. 14, OPP3 art. 7.';

  @override
  String get toolBudgetSnapshotHint => 'Voici un aperçu de ton budget actuel.';

  @override
  String get toolScoreGaugeHint => 'Voici ton score de confiance financière.';

  @override
  String get coachFactCardTitle => 'Le savais-tu ?';

  @override
  String firstJobPrimePerMonth(String amount) {
    return '$amount/mois';
  }

  @override
  String firstJobCoutMaxPerYear(String amount) {
    return 'Max $amount/an';
  }

  @override
  String get jobChangeChecklistSemantics =>
      'Checklist nouveau job libre passage LPP actions urgentes';

  @override
  String get jobChangeChecklistTitle => 'Checklist changement de job';

  @override
  String get jobChangeChecklistSubtitle =>
      'Tu as 30 jours pour vérifier que ton LPP a été transféré.';

  @override
  String jobChangeChecklistProgress(int completed, int total) {
    return '$completed / $total actions complétées';
  }

  @override
  String get jobChangeChecklistAlertTitle =>
      'Demande TOUJOURS le certificat LPP avant de signer';

  @override
  String get jobChangeChecklistAlertBody =>
      'Sans transfert du libre passage dans les délais, ton capital LPP peut finir à la Fondation supplétive à 0.05 %.';

  @override
  String get jobChangeChecklistDisclaimer =>
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. Source : LPP art. 3 (libre passage), OLP art. 1-3.';

  @override
  String get circleLabelEmergencyFund => 'Fonds d\'urgence';

  @override
  String get circleLabelDettes => 'Dettes';

  @override
  String get circleLabelRevenu => 'Revenu';

  @override
  String get circleLabelAssurancesObligatoires => 'Assurances obligatoires';

  @override
  String get circleLabelTroisaOptimisation => '3a - Optimisation';

  @override
  String get circleLabelTroisaVersement => '3a - Versement';

  @override
  String get circleLabelLppRachat => 'LPP - Rachat';

  @override
  String get circleLabelAvs => 'AVS';

  @override
  String get circleLabelInvestissements => 'Investissements';

  @override
  String get circleLabelPatrimoineImmobilier => 'Patrimoine immobilier';

  @override
  String get circleNameProtection => 'Protection & Sécurité';

  @override
  String get circleNamePrevoyance => 'Prévoyance Fiscale';

  @override
  String get circleNameCroissance => 'Croissance';

  @override
  String get circleNameOptimisation => 'Optimisation & Transmission';

  @override
  String get nudgeSalaryDayTitle => 'Jour de salaire !';

  @override
  String get nudgeSalaryDayMessage =>
      'As-tu pensé à ton virement 3a ce mois-ci ? Chaque mois compte pour ta prévoyance.';

  @override
  String get nudgeSalaryDayAction => 'Voir mon 3a';

  @override
  String get nudgeTaxDeadlineMessage =>
      'Vérifie la date limite de déclaration fiscale dans ton canton. As-tu pensé à vérifier tes déductions 3a et LPP ?';

  @override
  String get nudgeTaxDeadlineAction => 'Simuler mes impôts';

  @override
  String get nudgeThreeADeadlineTitle => 'Dernière ligne droite pour ton 3a';

  @override
  String get nudgeThreeADeadlineMessageLastDay =>
      'C\'est le dernier jour pour verser sur ton 3a !';

  @override
  String get nudgeThreeADeadlineAction => 'Calculer mon économie';

  @override
  String get nudgeBirthdayDashboardAction => 'Voir mon tableau de bord';

  @override
  String get nudgeLppBonifStartTitle => 'Début des cotisations LPP';

  @override
  String get nudgeLppBonifChangeTitle => 'Changement de tranche LPP';

  @override
  String get nudgeLppBonifAction => 'Explorer le rachat';

  @override
  String get nudgeWeeklyCheckInTitle => 'Ça fait un moment !';

  @override
  String get nudgeWeeklyCheckInMessage =>
      'Ta situation financière évolue chaque semaine. Prends 2 minutes pour vérifier ton tableau de bord.';

  @override
  String get nudgeWeeklyCheckInAction => 'Voir mon Pulse';

  @override
  String get nudgeStreakRiskTitle => 'Ta série est en danger !';

  @override
  String get nudgeStreakRiskAction => 'Continuer ma série';

  @override
  String get nudgeGoalApproachingTitle => 'Ton objectif approche';

  @override
  String get nudgeGoalApproachingAction => 'En parler au coach';

  @override
  String get nudgeFhsDroppedTitle => 'Ton score santé a baissé';

  @override
  String get nudgeFhsDroppedAction => 'Comprendre la baisse';

  @override
  String get ragErrorInvalidKey => 'La clé API est invalide ou expirée.';

  @override
  String get ragErrorRateLimit =>
      'Limite de requêtes atteinte. Réessaie dans quelques instants.';

  @override
  String get ragErrorBadRequest => 'Requête invalide.';

  @override
  String get ragErrorServiceUnavailable =>
      'Service temporairement indisponible. Réessaie plus tard.';

  @override
  String get ragErrorStatus =>
      'Impossible de vérifier le statut du système RAG.';

  @override
  String get ragErrorVisionBadRequest => 'Requête vision invalide.';

  @override
  String get ragErrorImageTooLarge =>
      'L\'image dépasse la taille limite de 20 MB.';

  @override
  String get ragErrorRateLimitShort => 'Limite de requêtes atteinte.';

  @override
  String get paywallTitle => 'Débloque MINT Coach';

  @override
  String get paywallSubtitle => 'Ton coach financier personnel';

  @override
  String get paywallTrialBadge => 'Essai gratuit 14 jours';

  @override
  String paywallSubscriptionActivated(String tier) {
    return 'Abonnement $tier activé avec succès.';
  }

  @override
  String get paywallTrialActivated =>
      'Essai gratuit activé ! Profite de MINT Coach pendant 14 jours.';

  @override
  String get paywallRestoreButton => 'Restaurer un achat';

  @override
  String get paywallRestoreSuccess => 'Abonnement restauré avec succès !';

  @override
  String get paywallRestoreNoPurchase => 'Aucun achat précédent trouvé.';

  @override
  String get paywallDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil financier. LSFin. Tu peux annuler à tout moment depuis les réglages de ton compte.';

  @override
  String get paywallClose => 'Fermer';

  @override
  String paywallSelectTier(String name) {
    return 'Sélectionner $name';
  }

  @override
  String paywallChooseTier(String tier) {
    return 'Choisir $tier';
  }

  @override
  String get paywallStartTrial => 'Commencer l\'essai gratuit';

  @override
  String get paywallPricePerMonth => '/mois';

  @override
  String get paywallFeatureTop => 'Top';

  @override
  String get arbitrageOptionFullRente => '100 % Rente';

  @override
  String get arbitrageOptionFullCapital => '100 % Capital';

  @override
  String get arbitrageOptionMixed => 'Mixte (oblig. rente + surob. capital)';

  @override
  String get arbitrageOptionAmortIndirect => 'Amortissement indirect';

  @override
  String get arbitrageOptionInvestLibre => 'Investissement libre';

  @override
  String get tornadoLabelRendementCapital => 'Ce que ton capital rapporte';

  @override
  String get tornadoLabelTauxRetrait => 'Retrait annuel du capital';

  @override
  String get tornadoLabelConversionOblig => 'Conversion LPP obligatoire';

  @override
  String get tornadoLabelConversionSurob => 'Conversion LPP suroblig.';

  @override
  String get tornadoLabelRendementMarche => 'Rendement de tes placements';

  @override
  String get tornadoLabelTauxMarginal => 'Ton taux d\'imposition';

  @override
  String get tornadoLabelRendement3a => 'Rendement de ton 3e pilier';

  @override
  String get tornadoLabelRendementLpp => 'Rendement de ta caisse LPP';

  @override
  String get tornadoLabelTauxHypothecaire => 'Taux hypothécaire';

  @override
  String get tornadoLabelAppreciationImmo => 'Appréciation immo';

  @override
  String get tornadoLabelLoyerMensuel => 'Loyer mensuel';

  @override
  String get tornadoLabelTauxImpotCapital => 'Taux impôt capital';

  @override
  String get tornadoLabelAgeRetraite => 'Âge de retraite';

  @override
  String get tornadoLabelCapitalTotal => 'Capital total';

  @override
  String get tornadoLabelAnneesAvantRetraite => 'Années avant retraite';

  @override
  String get tornadoLabelBas => 'Bas';

  @override
  String get tornadoLabelHaut => 'Haut';

  @override
  String get educationalLearnMoreStressCheck =>
      'Ton stress financier, en clair';

  @override
  String get educationalLearnMoreLpp => 'Comprendre le 2e pilier (LPP)';

  @override
  String get educationalLearnMoreTroisA => 'Le 3e pilier en détail';

  @override
  String get educationalLearnMoreMortgage => 'Types d\'hypothèques en Suisse';

  @override
  String get educationalLearnMoreCredit => 'Le crédit à la consommation';

  @override
  String get educationalLearnMoreLeasing => 'Leasing vs achat';

  @override
  String get educationalLearnMoreEmergency => 'Pourquoi un fonds d\'urgence ?';

  @override
  String get educationalLearnMoreCivilStatus =>
      'État civil et finances en Suisse';

  @override
  String get educationalLearnMoreEmployment =>
      'Statut professionnel et prévoyance';

  @override
  String get educationalLearnMoreHousing => 'Locataire ou propriétaire ?';

  @override
  String get educationalLearnMoreCanton => 'Fiscalité cantonale en Suisse';

  @override
  String get educationalLearnMoreLppBuyback =>
      'Le rachat LPP, comment ça marche ?';

  @override
  String get educationalLearnMoreTroisaCount => 'Stratégie multi-comptes 3a';

  @override
  String get educationalLearnMoreInvestments =>
      'Placements et fiscalité suisse';

  @override
  String get educationalLearnMoreRealEstate => 'Financer un achat immobilier';

  @override
  String get capMissingPieceHeadline => 'Il manque une pièce';

  @override
  String capMissingPieceWhyNow(String label) {
    return '$label — sans cette donnée, ta projection reste floue.';
  }

  @override
  String capMissingPieceExpectedImpact(String impact) {
    return '+$impact pts de confiance';
  }

  @override
  String capMissingPieceConfidenceLabel(String score) {
    return 'confiance $score %';
  }

  @override
  String get capDebtHeadline => 'Ta dette pèse';

  @override
  String get capDebtWhyNow =>
      'Rembourser le taux le plus élevé d’abord libère de la marge chaque mois.';

  @override
  String get capDebtCtaLabel => 'Voir mon plan';

  @override
  String get capDebtExpectedImpact => 'marge à retrouver';

  @override
  String get capIndepNoLppHeadline => 'Ton 2e pilier : CHF 0';

  @override
  String get capIndepNoLppWhyNow =>
      'Sans LPP, ta retraite = AVS seule. Un filet volontaire change la trajectoire.';

  @override
  String get capIndepNoLppCtaLabel => 'Construire mon filet';

  @override
  String get capIndepNoLppExpectedImpact => 'retraite renforcée';

  @override
  String get capDisabilityGapHeadline => 'Ton filet invalidité : AI seule';

  @override
  String get capDisabilityGapWhyNow =>
      'Sans LPP, ton filet invalidité se limite à l’AI. L’écart peut surprendre.';

  @override
  String get capDisabilityGapCtaLabel => 'Voir l’écart';

  @override
  String get capDisabilityGapExpectedImpact => 'comprendre le gap ~70 %';

  @override
  String get cap3aHeadline => 'Cette année compte encore';

  @override
  String get cap3aWhyNow =>
      'Un versement 3a peut encore alléger tes impôts et renforcer ta retraite.';

  @override
  String get cap3aCtaLabel => 'Simuler mon 3a';

  @override
  String get capLppBuybackHeadline => 'Rachat LPP disponible';

  @override
  String capLppBuybackWhyNow(String amount) {
    return 'Tu peux racheter jusqu’à $amount et déduire de tes impôts.';
  }

  @override
  String get capLppBuybackCtaLabel => 'Simuler un rachat';

  @override
  String get capLppBuybackExpectedImpact => 'déduction fiscale';

  @override
  String get capBudgetDeficitHeadline => 'Ta marge à retrouver';

  @override
  String get capBudgetDeficitWhyNow =>
      'Ton budget serre. Ajuster une enveloppe peut redonner de l’air.';

  @override
  String get capBudgetDeficitCtaLabel => 'Ajuster mon budget';

  @override
  String get capBudgetDeficitExpectedImpact => 'marge mensuelle';

  @override
  String get capReplacementRateHeadline => 'Ta retraite pince encore';

  @override
  String capReplacementRateWhyNow(String rate) {
    return '$rate % de taux de remplacement. Un rachat ou un 3a change la trajectoire.';
  }

  @override
  String get capReplacementRateCtaLabel => 'Explorer mes scénarios';

  @override
  String get capReplacementRateExpectedImpact => '+4 à +7 pts';

  @override
  String get capCoverageCheckSeniorHeadline =>
      'Invalidité après 50 ans : un angle mort ?';

  @override
  String get capCoverageCheckHeadline => 'Ta couverture mérite un check';

  @override
  String get capCoverageCheckSeniorWhyNow =>
      'Après 50 ans, l’écart entre revenu et rentes AI + LPP peut dépasser 40 %. Ton IJM couvre-t-elle le reste ?';

  @override
  String get capCoverageCheckWhyNow =>
      'IJM, AI, LPP invalidité — vérifie que ton filet tient.';

  @override
  String get capCoverageCheckCtaLabel => 'Vérifier';

  @override
  String get capChomageHeadline => 'Sécuriser les 90 prochains jours';

  @override
  String get capChomageWhyNow =>
      'En chômage, trois urgences à poser : tes droits AC, l’impact sur ta LPP et ton budget à ajuster.';

  @override
  String get capChomageCtaLabel => 'Voir mes droits';

  @override
  String get capChomageExpectedImpact => 'stabilisation immédiate';

  @override
  String get capDivorceUrgencyHeadline => 'Divorce : clarifier ce qui change';

  @override
  String get capDivorceUrgencyWhyNow =>
      'Partage LPP, pension alimentaire, logement — les impacts financiers méritent un point clair.';

  @override
  String get capDivorceUrgencyCtaLabel => 'Simuler l’impact';

  @override
  String get capDivorceUrgencyExpectedImpact => 'clarification LPP + impôts';

  @override
  String get capLeMarriageHeadline => 'Mariage en vue';

  @override
  String get capLeMarriageWhyNow =>
      'Impôts, AVS, LPP, succession — tout change.';

  @override
  String get capLeMarriageCtaLabel => 'Voir l’impact';

  @override
  String get capLeDivorceHeadline => 'Divorce en cours';

  @override
  String get capLeDivorceWhyNow => 'Partage LPP, pension, impôts — anticipe.';

  @override
  String get capLeDivorceCtaLabel => 'Simuler';

  @override
  String get capLeBirthHeadline => 'Naissance prévue';

  @override
  String get capLeBirthWhyNow =>
      'Allocations, déductions, budget — prépare-toi.';

  @override
  String get capLeBirthCtaLabel => 'Voir l’impact';

  @override
  String get capLeHousingPurchaseHeadline => 'Achat immobilier';

  @override
  String get capLeHousingPurchaseWhyNow =>
      'EPL, 3a, hypothèque — tout se joue maintenant.';

  @override
  String get capLeHousingPurchaseCtaLabel => 'Simuler ma capacité';

  @override
  String get capLeJobLossHeadline => 'Perte d’emploi';

  @override
  String get capLeJobLossWhyNow => 'Chômage, LPP, budget — les 3 urgences.';

  @override
  String get capLeJobLossCtaLabel => 'Voir mes droits';

  @override
  String get capLeSelfEmploymentHeadline => 'Passage à l’indépendance';

  @override
  String get capLeSelfEmploymentWhyNow =>
      'LPP volontaire, 3a max, IJM — ton filet à reconstruire.';

  @override
  String get capLeSelfEmploymentCtaLabel => 'Vérifier ma couverture';

  @override
  String get capLeRetirementHeadline => 'Retraite à l’horizon';

  @override
  String get capLeRetirementWhyNow =>
      'Capital ou rente, décaissement, timing — c’est le moment.';

  @override
  String get capLeRetirementCtaLabel => 'Explorer mes options';

  @override
  String get capLeConcubinageHeadline => 'Vie commune';

  @override
  String get capLeConcubinageWhyNow =>
      'Pas de cap AVS 150 %, pas de partage LPP automatique — anticipe.';

  @override
  String get capLeConcubinageCtaLabel => 'Voir les différences';

  @override
  String get capLeDeathOfRelativeHeadline => 'Perte d’un proche';

  @override
  String get capLeDeathOfRelativeWhyNow =>
      'Succession, rentes de survivant, délais — ce qui est urgent.';

  @override
  String get capLeDeathOfRelativeCtaLabel => 'Voir les démarches';

  @override
  String get capLeNewJobHeadline => 'Nouveau poste';

  @override
  String get capLeNewJobWhyNow =>
      'LPP, libre passage, 3a — trois choses à vérifier.';

  @override
  String get capLeNewJobCtaLabel => 'Comparer';

  @override
  String get capLeHousingSaleHeadline => 'Vente immobilière';

  @override
  String get capLeHousingSaleWhyNow =>
      'Plus-value, remboursement EPL, réinvestissement — planifie.';

  @override
  String get capLeHousingSaleCtaLabel => 'Voir l’impact';

  @override
  String get capLeInheritanceHeadline => 'Héritage reçu';

  @override
  String get capLeInheritanceWhyNow =>
      'Impôts, intégration au patrimoine, rachat LPP — arbitre.';

  @override
  String get capLeInheritanceCtaLabel => 'Voir mes options';

  @override
  String get capLeDonationHeadline => 'Donation envisagée';

  @override
  String get capLeDonationWhyNow =>
      'Avancement d’hoirie, fiscalité, rapport — anticipe.';

  @override
  String get capLeDonationCtaLabel => 'Voir l’impact';

  @override
  String get capLeDisabilityHeadline => 'Risque invalidité';

  @override
  String get capLeDisabilityWhyNow =>
      'AI, LPP invalidité, IJM — vérifie ton filet.';

  @override
  String get capLeDisabilityCtaLabel => 'Vérifier ma couverture';

  @override
  String get capLeCantonMoveHeadline => 'Déménagement cantonal';

  @override
  String get capLeCantonMoveWhyNow =>
      'Impôts, LAMal, charges — l’impact peut surprendre.';

  @override
  String get capLeCantonMoveCtaLabel => 'Comparer les cantons';

  @override
  String get capLeCountryMoveHeadline => 'Départ de Suisse';

  @override
  String get capLeCountryMoveWhyNow =>
      'Libre passage, AVS, 3a — ce qui te suit, ce qui reste.';

  @override
  String get capLeCountryMoveCtaLabel => 'Voir les conséquences';

  @override
  String get capLeDebtCrisisHeadline => 'Situation de dette';

  @override
  String get capLeDebtCrisisWhyNow =>
      'Prioriser, restructurer, protéger l’essentiel — par étapes.';

  @override
  String get capLeDebtCrisisCtaLabel => 'Voir mon plan';

  @override
  String get capCouple3aHeadline => 'À deux, un levier de plus';

  @override
  String get capCouple3aWhyNow =>
      'Votre ménage peut déduire 2 × 7’258 CHF en cotisant chacun au 3a. Le compte de votre conjoint·e n’est pas encore renseigné.';

  @override
  String get capCouple3aCtaLabel => 'Simuler le 3a couple';

  @override
  String get capCouple3aExpectedImpact => 'jusqu’à 14’516 CHF de déductions';

  @override
  String get capCoupleLppBuybackHeadline => 'Rachat LPP : le levier conjoint';

  @override
  String capCoupleLppBuybackWhyNow(String amount) {
    return 'Votre conjoint·e dispose d’un rachat possible de $amount. Prioriser le TMI le plus élevé maximise la déduction.';
  }

  @override
  String get capCoupleLppBuybackCtaLabel => 'Comparer les rachats';

  @override
  String get capCoupleLppBuybackExpectedImpact => 'optimisation fiscale ménage';

  @override
  String get capCoupleAvsCapHeadline => 'AVS couple : le plafond 150 %';

  @override
  String get capCoupleAvsCapWhyNow =>
      'Marié·es, vos rentes AVS cumulées sont plafonnées à 150 % de la rente maximale (LAVS art. 35). L’écart peut atteindre ~10’000 CHF/an.';

  @override
  String get capCoupleAvsCapCtaLabel => 'Voir l’impact AVS';

  @override
  String get capCoupleAvsCapExpectedImpact => 'comprendre le delta ~10k/an';

  @override
  String get capHonestyDebtHeadline => 'Ta situation mérite un regard expert';

  @override
  String get capHonestyDebtWhyNow =>
      'Les leviers classiques ne suffisent pas ici. Un·e spécialiste en désendettement peut t’aider à construire un plan réaliste.';

  @override
  String get capHonestryCrossBorderHeadline => 'Faisons le point ensemble';

  @override
  String get capHonestryCrossBorderWhyNow =>
      'À ton horizon, les leviers 2e pilier sont limités. Un·e spécialiste frontalier peut identifier des pistes que MINT ne couvre pas encore.';

  @override
  String get capHonestyNoLppHeadline => 'Ton socle est là';

  @override
  String get capHonestyNoLppWhyNow =>
      'Les leviers classiques ne changent pas beaucoup la donne ici. Un·e spécialiste peut t’aider à voir plus loin.';

  @override
  String get capHonestyCtaLabel => 'Parler au coach';

  @override
  String get capHonestyExpectedImpact => 'clarification';

  @override
  String capAcquiredAvsWithRente(String rente, String years) {
    return 'AVS : ~$rente CHF/mois ($years ans cotisés)';
  }

  @override
  String capAcquiredAvsYearsOnly(String years) {
    return 'AVS : $years années cotisées';
  }

  @override
  String get capAcquiredAvsInProgress => 'AVS : droits en cours';

  @override
  String capAcquiredLpp(String amount) {
    return 'LPP : $amount acquis';
  }

  @override
  String capAcquired3a(String amount) {
    return '3a : $amount épargnés';
  }

  @override
  String get capFallbackHeadline => 'Complète ton profil';

  @override
  String get capFallbackWhyNow =>
      'Plus MINT te connaît, plus les leviers sont précis.';

  @override
  String get capFallbackCtaLabel => 'Enrichir';

  @override
  String get pulseIndepLppTitle => 'CHF 0';

  @override
  String get pulseIndepLppSubtitle => 'C’est ton 2e pilier aujourd’hui.';

  @override
  String get pulseIndepLppDetail =>
      'Sans LPP, ta retraite = AVS seule : ~CHF 1’934/mois.';

  @override
  String get pulseIndepLppCta => 'Construire mon filet';

  @override
  String get pulseDebtSubtitle => 'de dettes à rembourser.';

  @override
  String get pulseDebtCta => 'Voir mon plan';

  @override
  String get pulseComprSalaireSubtitle =>
      'disparaissent de ton salaire avant même d’arriver.';

  @override
  String get pulseComprSalaireDetail =>
      'AVS, LPP, AC, impôts — découvre où va chaque franc.';

  @override
  String get pulseComprSalaireCta => 'Comprendre ma fiche';

  @override
  String get pulseComprSystemeTitle => '3 piliers';

  @override
  String get pulseComprSystemeSubtitle => 'Le système suisse en 1 minute.';

  @override
  String get pulseComprSystemeDetail =>
      'AVS (État) + LPP (employeur) + 3a (toi) = ta retraite.';

  @override
  String get pulseComprSystemeCta => 'Découvrir';

  @override
  String get pulseComprSituationTitle => 'Ta visibilité financière';

  @override
  String get pulseComprSituationSubtitle =>
      'Que sais-tu vraiment de ta situation ?';

  @override
  String get pulseComprSituationDetail =>
      'Complète ton profil pour affiner ton score.';

  @override
  String get pulseComprSituationCta => 'Voir mon score';

  @override
  String get pulseProtRetraiteCapRenteTitle => 'Capital ou Rente ?';

  @override
  String get pulseProtRetraiteCapRenteSubtitle => 'Le choix qui change tout.';

  @override
  String get pulseProtRetraiteCapRenteDetail =>
      'Compare les deux options avec tes chiffres réels.';

  @override
  String get pulseProtRetraiteCapRenteCta => 'Comparer';

  @override
  String get pulseProtRetraiteSubtitle => 'conservé à la retraite.';

  @override
  String get pulseProtRetraiteDetail =>
      'Médiane suisse : 60 %. Où te situes-tu ?';

  @override
  String get pulseProtRetraiteCta => 'Voir ma projection';

  @override
  String get pulseProtFamilleSubtitle => 'Votre retraite à deux.';

  @override
  String get pulseProtFamilleDetail =>
      'Anticipe le creux quand un seul est retraité.';

  @override
  String get pulseProtFamilleCta => 'Voir la timeline';

  @override
  String get pulseProtUrgenceDebtSubtitle => 'à rembourser.';

  @override
  String get pulseProtUrgenceDebtDetail =>
      'Commence par le taux le plus élevé.';

  @override
  String get pulseProtUrgenceDebtCta => 'Mon plan de remboursement';

  @override
  String get pulseProtUrgenceTitle => 'Ton filet de sécurité';

  @override
  String get pulseProtUrgenceSubtitle =>
      'Que se passe-t-il si tu ne peux plus travailler ?';

  @override
  String get pulseProtUrgenceDetail =>
      'IJM, AI, LPP invalidité — vérifie ta couverture.';

  @override
  String get pulseProtUrgenceCta => 'Vérifier';

  @override
  String get pulseOptFiscalSubtitle => 'laissés au fisc chaque année.';

  @override
  String get pulseOptFiscalDetail =>
      '3a + rachat LPP = tes leviers les plus puissants.';

  @override
  String get pulseOptFiscalCta => 'Récupérer';

  @override
  String get pulseOptPatrimoineSubtitle => 'Ton patrimoine total.';

  @override
  String get pulseOptPatrimoineDetail =>
      'Épargne + LPP + 3a + investissements.';

  @override
  String get pulseOptPatrimoineCtaLabel => 'Détail';

  @override
  String get pulseOptCapRenteTitle => 'Capital ou Rente ?';

  @override
  String get pulseOptCapRenteSubtitle =>
      'La différence peut dépasser CHF 200’000.';

  @override
  String get pulseOptCapRenteDetail =>
      'Taxé une fois (capital) vs chaque année (rente).';

  @override
  String get pulseOptCapRenteCta => 'Comparer';

  @override
  String get pulseNavExpatGapsSubtitle =>
      'de cotisations manquent dans ton AVS.';

  @override
  String get pulseNavExpatGapsDetail =>
      'Chaque année manquante = -2.3 % de rente à vie.';

  @override
  String get pulseNavExpatGapsCta => 'Analyser mes lacunes';

  @override
  String get pulseNavExpatTitle => 'Nouveau en Suisse ?';

  @override
  String get pulseNavExpatSubtitle =>
      'Tes droits, tes lacunes, tes pièges à éviter.';

  @override
  String get pulseNavExpatDetail =>
      'AVS, LPP, 3a — tout ce qui compte dès ton arrivée.';

  @override
  String get pulseNavExpatCta => 'Découvrir';

  @override
  String get pulseNavAchatTitle => 'Acheter un bien';

  @override
  String get pulseNavAchatSubtitle => 'Calcule ta capacité d’achat.';

  @override
  String get pulseNavAchatDetail =>
      'Ton 3a et ton LPP = ta principale mise de fonds.';

  @override
  String get pulseNavAchatCta => 'Simuler';

  @override
  String get pulseNavAchatCapSubtitle => 'Le bien que tu pourrais viser.';

  @override
  String get pulseNavAchatCapCta => 'Simuler mon achat';

  @override
  String get pulseNavIndependantTitle => 'Indépendant·e ?';

  @override
  String get pulseNavIndependantSubtitle => 'Sans employeur, ton filet = toi.';

  @override
  String get pulseNavIndependantDetail =>
      'LPP volontaire, 3a max 36’288/an, IJM obligatoire.';

  @override
  String get pulseNavIndependantCta => 'Vérifier ma couverture';

  @override
  String get pulseNavEvenementTitle => 'Un changement de vie ?';

  @override
  String get pulseNavEvenementSubtitle =>
      'Chaque événement a un impact financier.';

  @override
  String get pulseNavEvenementDetail =>
      'Mariage, naissance, divorce, héritage, déménagement...';

  @override
  String get pulseNavEvenementCta => 'Explorer';

  @override
  String get reengagementTitleNewYear => 'Nouveaux plafonds 3a';

  @override
  String get reengagementTitleTaxPrep => 'Déclaration fiscale';

  @override
  String get reengagementTitleTaxDeadline => 'Deadline fiscale';

  @override
  String get reengagementTitleThreeA => 'Deadline 3a';

  @override
  String get reengagementTitleThreeAFinal => 'Dernier mois 3a';

  @override
  String get reengagementTitleQuarterlyFri => 'Score de solidité';

  @override
  String get assurancesAlerteDelai =>
      'Rappel : modification de franchise possible avant le 30 novembre de chaque année pour l’année suivante.';

  @override
  String get assurancesDisclaimerLamal =>
      'Cette analyse est indicative. Les primes varient selon l’assureur, la région et le modèle d’assurance. Consultez ta caisse maladie pour des chiffres exacts. Source : LAMal art. 62-64, OAMal.';

  @override
  String get assurancesDisclaimerCoverage =>
      'Cette analyse est indicative et ne constitue pas un conseil en assurance personnalisé. Les primes varient selon l’assureur et ton profil. Consulte un·e spécialiste en assurances pour une évaluation complète.';

  @override
  String get recommendationsDisclaimer =>
      'Suggestions pédagogiques basées sur ton profil — outil éducatif qui ne constitue pas un conseil financier personnalisé au sens de la LSFin. Consultez un·e spécialiste pour une analyse adaptée à ta situation.';

  @override
  String get recommendationsTitleEmergencyFund =>
      'Constituer un fonds d’urgence';

  @override
  String get recommendationsTitlePillar3a => 'Optimiser avec le 3a';

  @override
  String get recommendationsTitleLppBuyback => 'Simuler un rachat LPP';

  @override
  String get recommendationsTitleCompoundInterest => 'Le pouvoir du temps';

  @override
  String get recommendationsTitleStartDiagnostic => 'Commence ton diagnostic';

  @override
  String get cantonalBenchmarkDisclaimer =>
      'Ces données sont des ordres de grandeur issus de statistiques fédérales anonymisées (OFS). Elles ne constituent pas un conseil financier. Aucune donnée personnelle n’est comparée à d’autres utilisateurs. Outil éducatif : ne constitue pas un conseil au sens de la LSFin.';

  @override
  String get scenarioLabelPrudent => 'Scénario prudent';

  @override
  String get scenarioLabelReference => 'Scénario de référence';

  @override
  String get scenarioLabelFavorable => 'Scénario favorable';

  @override
  String get scenarioDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil financier au sens de la LSFin. Les projections reposent sur des hypothèses de rendement et ne présagent pas des résultats futurs. Consulte un·e spécialiste pour un plan personnalisé.';

  @override
  String get bayesianDisclaimer =>
      'Estimations bayésiennes basées sur les statistiques suisses (OFS/BFS). Ces valeurs sont des approximations pédagogiques, pas des certitudes. Ne constitue pas un conseil financier au sens de la LSFin.';

  @override
  String get consentLabelByok => 'Personnalisation IA';

  @override
  String get consentLabelSnapshot => 'Historique de progression';

  @override
  String get consentLabelNotifications => 'Rappels personnalisés';

  @override
  String get consentDashboardDisclaimer =>
      'Tes données t’appartiennent. Chaque paramètre est révocable à tout moment (nLPD art. 6).';

  @override
  String get wizardValidationRequired => 'Cette question est obligatoire';

  @override
  String get wizardAnswerNotProvided => 'Non renseigné';

  @override
  String get arbitrageTitleRenteVsCapital => 'Rente vs Capital';

  @override
  String get arbitrageMissingLpp =>
      'Ajoute ton avoir LPP pour voir cette comparaison';

  @override
  String get arbitrageTitleCalendrierRetraits => 'Calendrier de retraits';

  @override
  String get arbitrageMissingLppAnd3a =>
      'Ajoute ton avoir LPP et 3a pour voir le calendrier';

  @override
  String get arbitrageTitleRachatVsMarche => 'Rachat LPP vs Marché';

  @override
  String get arbitrageMissingLppCertificat =>
      'Scanne ton certificat LPP pour connaître ta lacune de rachat';

  @override
  String get reportTitleBilanFlash => 'Ton Bilan Flash';

  @override
  String get reportLabelSanteFinanciere => 'Santé Financière';

  @override
  String get retirementProjectionDisclaimer =>
      'Projection éducative basée sur les barèmes AVS/LPP 2025. Ne constitue pas un conseil financier ou en prévoyance. Les montants sont des estimations qui peuvent varier selon l’évolution légale et ta situation personnelle. Consulte un·e spécialiste pour un plan personnalisé. LSFin.';

  @override
  String get retirementIncomeLabelPillar3a => '3e pilier';

  @override
  String get retirementIncomeLabelPatrimoine => 'Patrimoine libre';

  @override
  String get retirementPhaseLabelBothRetired => 'Les deux à la retraite';

  @override
  String get retirementPhaseLabelRetraite => 'Retraite';

  @override
  String get forecasterDisclaimer =>
      'Projections éducatives basées sur des hypothèses de rendement. Ne constitue pas un conseil financier. Les rendements passés ne présagent pas des rendements futurs. Consulte un·e spécialiste pour un plan personnalisé. LSFin.';

  @override
  String get forecasterEtSiDisclaimer =>
      'Simulation « Et si... » à titre éducatif uniquement. Hypothèses de rendement ajustées manuellement. Ne constitue pas un conseil financier (LSFin). Les rendements passés ne présagent pas des rendements futurs.';

  @override
  String get lppRachatDisclaimerEchelonne =>
      'Simulation pédagogique basée sur les barèmes cantonaux estimés. Le rachat LPP est soumis à acceptation par la caisse de pension. La déduction annuelle est plafonnée au revenu imposable. Blocage EPL de 3 ans après chaque rachat (LPP art. 79b al. 3). Consulte ta caisse de pension et un·e spécialiste en prévoyance avant toute décision.';

  @override
  String get lppLibrePassageDisclaimer =>
      'Ces informations sont pédagogiques et ne constituent pas un conseil juridique ou financier personnalisé. Les règles dépendent de ta caisse de pension et de ta situation. Base légale : LFLP, OLP. Consultez un ou une spécialiste en prévoyance professionnelle.';

  @override
  String get lppEplDisclaimer =>
      'Simulation pédagogique à titre indicatif. Le montant retirable exact dépend du règlement de ta caisse de pension et de ton avoir à 50 ans. L’impôt varie selon le canton et la situation personnelle. Base légale : art. 30c LPP, OEPL. Consulte ta caisse de pension et un ou une spécialiste avant toute décision.';

  @override
  String get lppChecklistTitleDecompte => 'Demander un décompte de sortie';

  @override
  String get lppChecklistDescDecompte =>
      'Exige un décompte détaillé de ta caisse de pension avec la répartition obligatoire / surobligatoire.';

  @override
  String get lppChecklistTitleTransfert30j =>
      'Transférer ton avoir dans les 30 jours';

  @override
  String get lppChecklistDescTransfert30j =>
      'L’avoir doit être transféré à la nouvelle caisse de pension. Communiquez les coordonnées de la nouvelle caisse à l’ancienne.';

  @override
  String get lppChecklistAlertTransfertTitle =>
      'Délai de transfert bientôt échu';

  @override
  String get lppChecklistAlertTransfertMsg =>
      'Le transfert de ton avoir doit intervenir dans les 30 jours. Contacte ton ancienne caisse de pension rapidement.';

  @override
  String get lppChecklistTitleOuvrirLP => 'Ouvrir un compte de libre passage';

  @override
  String get lppChecklistDescOuvrirLP =>
      'Sans nouvel employeur, ton avoir doit être placé sur un ou deux comptes de libre passage (max. 2 selon la loi).';

  @override
  String get lppChecklistTitleChoisirLP =>
      'Choisir entre compte bancaire et police de libre passage';

  @override
  String get lppChecklistDescChoisirLP =>
      'Le compte bancaire offre plus de flexibilité. La police d’assurance peut inclure une couverture risque.';

  @override
  String get lppChecklistTitleVerifierDestination =>
      'Vérifier les règles de retrait selon le pays de destination';

  @override
  String get lppChecklistDescVerifierDestination =>
      'UE/AELE : seule la part surobligatoire peut être retirée en espèces. La part obligatoire reste en Suisse. Hors UE/AELE : retrait total possible.';

  @override
  String get lppChecklistTitleAnnoncerDepart =>
      'Annoncer ton départ à la caisse de pension';

  @override
  String get lppChecklistDescAnnoncerDepart =>
      'Informe ta caisse dans les 30 jours suivant ton départ.';

  @override
  String get lppChecklistAlertTransfert6mTitle =>
      'Transfert à effectuer dans les 6 mois';

  @override
  String get lppChecklistAlertTransfert6mMsg =>
      'Après un départ de Suisse, tu disposes de 6 mois pour transférer ton avoir ou ouvrir un compte de libre passage.';

  @override
  String get lppChecklistTitleChomage => 'Vérifier tes droits au chômage';

  @override
  String get lppChecklistDescChomage =>
      'En cas de chômage, ta prévoyance professionnelle continue via la fondation institution supplétive (Fondation LPP).';

  @override
  String get lppChecklistTitleAvoirs => 'Rechercher des avoirs oubliés';

  @override
  String get lppChecklistDescAvoirs =>
      'Utilisez la Centrale du 2e pilier (sfbvg.ch) pour rechercher d’éventuels avoirs de libre passage oubliés.';

  @override
  String get lppChecklistTitleCouverture =>
      'Vérifier la couverture risque transitoire';

  @override
  String get lppChecklistDescCouverture =>
      'Pendant la période de libre passage, la couverture décès et invalidité peut être réduite. Vérifie tes contrats.';

  @override
  String get pillar3aStaggeredDisclaimer =>
      'Simulation pédagogique à titre indicatif. L’impôt sur le retrait en capital dépend du canton, de la commune, de la situation personnelle et du montant total retiré dans l’année fiscale. Les taux utilisés sont des moyennes cantonales simplifiées. Base légale : OPP3, LIFD art. 38. Consultez un ou une spécialiste en prévoyance avant toute décision.';

  @override
  String get pillar3aRealReturnDisclaimer =>
      'Simulation pédagogique basée sur des hypothèses de rendement constant. Les rendements passés ne préjugent pas des rendements futurs. Les frais et rendements varient selon le prestataire. L’économie fiscale dépend de ton taux marginal réel. Base légale : OPP3, LIFD art. 33 al. 1 let. e. Consultez un ou une spécialiste avant toute décision.';

  @override
  String get pillar3aProviderDisclaimer =>
      'Rendements passés ne préjugent pas des rendements futurs. Les frais et rendements moyens sont basés sur des données historiques simplifiées à titre pédagogique. Le choix d’un prestataire 3a dépend de ta situation personnelle, de ton profil de risque et de ton horizon de placement. MINT n’est pas un intermédiaire financier et ne fournit aucun conseil en placement. Consultez un ou une spécialiste.';

  @override
  String get reportDisclaimerBase1 =>
      'Outil éducatif — ne constitue pas un conseil financier au sens de la LSFin.';

  @override
  String get reportDisclaimerBase2 =>
      'Les montants sont des estimations basées sur les données déclarées.';

  @override
  String get reportDisclaimerBase3 =>
      'Les performances passées ne préjugent pas des performances futures.';

  @override
  String get reportDisclaimerFiscal =>
      'L’estimation fiscale est approximative et ne remplace pas une déclaration d’impôts.';

  @override
  String get reportDisclaimerRetraite =>
      'La projection retraite est indicative et dépend de l’évolution législative (réformes AVS/LPP).';

  @override
  String get reportDisclaimerRachatLpp =>
      'Le rachat LPP est soumis à un blocage de 3 ans pour les retraits EPL (LPP art. 79b al. 3).';

  @override
  String get reportActionTitle3aFirst => 'Ouvre ton premier 3a';

  @override
  String get reportActionDesc3aFirst =>
      'Déduis jusqu’à CHF 7’258/an de ton revenu imposable. Économie immédiate.';

  @override
  String get reportActionTitle3aSecond => 'Ouvre un 2e compte 3a fintech';

  @override
  String get reportActionDesc3aSecond =>
      'Optimise ta fiscalité au retrait et diversifie tes placements.';

  @override
  String get reportActionTitleAvsCheck => 'Vérifie ton compte AVS';

  @override
  String get reportActionDescAvsCheck =>
      'Évite de perdre jusqu’à 38’000 CHF de rente à vie.';

  @override
  String get reportActionTitleDette => 'Rembourse tes dettes de consommation';

  @override
  String get reportActionDescDette =>
      'C’est le placement le plus rentable : tu économises 6-10 % par an sur les intérêts.';

  @override
  String get reportActionTitleUrgence => 'Constitue ton fonds d’urgence';

  @override
  String get reportActionDescUrgence =>
      'Vise 3 mois de charges sur un compte épargne séparé.';

  @override
  String get reportRoadmapPhaseImmediat => 'Immédiat';

  @override
  String get reportRoadmapTimeframeImmediat => 'Ce mois';

  @override
  String get reportRoadmapPhaseCourtTerme => 'Court Terme';

  @override
  String get reportRoadmapTimeframeCourtTerme => '3-6 mois';

  @override
  String get visibilityNarrativeHigh =>
      'Tu as une vision claire de ta situation. Continue à maintenir tes données à jour.';

  @override
  String visibilityNarrativeMediumHigh(String axisLabel) {
    return 'Bonne visibilité ! Affine ta $axisLabel pour aller plus loin.';
  }

  @override
  String visibilityNarrativeMedium(String axisLabel) {
    return 'Tu commences à y voir plus clair. Concentre-toi sur ta $axisLabel.';
  }

  @override
  String visibilityNarrativeLow(String hint) {
    return 'Chaque information compte. Commence par $hint.';
  }

  @override
  String get visibilityAxisLabelLiquidite => 'Liquidité';

  @override
  String get visibilityAxisLabelFiscalite => 'Fiscalité';

  @override
  String get visibilityAxisLabelRetraite => 'Retraite';

  @override
  String get visibilityAxisLabelSecurite => 'Sécurité';

  @override
  String get visibilityHintAddSalaire => 'Ajoute ton salaire pour commencer';

  @override
  String get visibilityHintAddEpargne =>
      'Renseigne ton épargne et investissements';

  @override
  String get visibilityHintLiquiditeComplete =>
      'Tes données de liquidité sont complètes';

  @override
  String get visibilityHintAddAgeCanton =>
      'Indique ton âge et canton de résidence';

  @override
  String get visibilityHintScanFiscal => 'Scanne ta déclaration fiscale';

  @override
  String get visibilityHintFiscaliteComplete =>
      'Tes données fiscales sont complètes';

  @override
  String get visibilityHintAddLpp => 'Ajoute ton certificat LPP';

  @override
  String get visibilityHintCommandeAvs => 'Commande ton extrait AVS';

  @override
  String get visibilityHintAdd3a => 'Renseigne tes comptes 3a';

  @override
  String get visibilityHintRetraiteComplete =>
      'Tes données retraite sont complètes';

  @override
  String get visibilityHintAddFamille => 'Indique ta situation familiale';

  @override
  String get visibilityHintAddStatutPro => 'Complète ton statut professionnel';

  @override
  String get visibilityHintSecuriteComplete =>
      'Tes données de sécurité sont complètes';

  @override
  String get exploreHubRetraiteIntro =>
      'Chaque année qui passe change tes options. Voici où tu en es.';

  @override
  String get exploreHubFamilleIntro =>
      'Mariage, naissance, séparation : chaque étape a un impact financier.';

  @override
  String get exploreHubTravailIntro =>
      'Ton statut professionnel détermine tes droits. Vérifie-les.';

  @override
  String get exploreHubLogementIntro =>
      'Acheter, louer, déménager : les chiffres avant la décision.';

  @override
  String get exploreHubFiscaliteIntro =>
      'Chaque franc déduit est un franc gagné. Trouve tes leviers.';

  @override
  String get exploreHubPatrimoineIntro =>
      'Ce que tu transmets mérite autant d’attention que ce que tu gagnes.';

  @override
  String get exploreHubSanteIntro =>
      'Ta couverture te protège — ou te coûte trop. Vérifie.';

  @override
  String get exploreTalkToMint => 'En parler avec MINT';

  @override
  String get dossierSettingsTitle => 'Réglages';

  @override
  String get dossierEnrichmentHint => 'Pour améliorer la précision :';

  @override
  String get pulseBudgetATitle => 'Aujourd’hui';

  @override
  String get pulseBudgetBTitle => 'À la retraite';

  @override
  String get pulseBudgetRevenu => 'Revenu';

  @override
  String get pulseBudgetCharges => 'Charges';

  @override
  String get pulseBudgetLibre => 'Libre';

  @override
  String get pulseBudgetRetirementNet => 'Net retraite';

  @override
  String get pulseBudgetGap => 'Écart';

  @override
  String get sim3aTaxRateChipsLabel => 'Taux marginal d’imposition';

  @override
  String get sim3aReturnChipsLabel => 'Rendement espéré';

  @override
  String get sim3aYearsAutoLabel => 'Années jusqu’à la retraite';

  @override
  String get sim3aContributionFieldLabel => 'Cotisation annuelle';

  @override
  String get sim3aProfilePreFilled => 'Prérempli depuis ton profil';

  @override
  String sim3aProfileEstimatedRate(String rate, String canton) {
    return 'Ton taux marginal estimé : $rate % ($canton)';
  }

  @override
  String sim3aYearsReadOnly(int years) {
    return '$years ans (calculé depuis ton âge)';
  }

  @override
  String get renteVsCapitalRetirementAgeChips => 'Âge de départ à la retraite';

  @override
  String get renteVsCapitalLifeExpectancyChips => 'Espérance de vie';

  @override
  String get budgetEnvelopeFieldHint => 'Montant en CHF';

  @override
  String get budgetEnvelopeFieldFuture => 'Épargne future (CHF/mois)';

  @override
  String get budgetEnvelopeFieldVariables => 'Dépenses variables (CHF/mois)';

  @override
  String get retroactive3aYearsChipsLabel => 'Années à rattraper';

  @override
  String get lightningMenuTitle => 'Que veux-tu explorer ?';

  @override
  String get lightningMenuSubtitle => 'MINT calcule, tu décides.';

  @override
  String get lightningMenuRetirementTitle => 'Mon aperçu retraite';

  @override
  String get lightningMenuRetirementSubtitle =>
      'Combien tu garderas à la retraite';

  @override
  String get lightningMenuRetirementAction => 'Combien à la retraite ?';

  @override
  String get lightningMenuBudgetTitle => 'Mon budget';

  @override
  String get lightningMenuBudgetSubtitle => 'Où part ton argent ce mois';

  @override
  String get lightningMenuBudgetAction => 'Mon budget ce mois';

  @override
  String get lightningMenuRenteCapitalTitle => 'Rente ou capital ?';

  @override
  String get lightningMenuRenteCapitalSubtitle => 'Comparer les deux scénarios';

  @override
  String get lightningMenuRenteCapitalAction => 'Rente ou capital ?';

  @override
  String get lightningMenuScoreTitle => 'Mon score fitness';

  @override
  String get lightningMenuScoreSubtitle =>
      'Ta santé financière en un coup d’œil';

  @override
  String get lightningMenuScoreAction => 'Mon score financier';

  @override
  String get lightningMenuCoupleTitle => 'Notre situation à deux';

  @override
  String get lightningMenuCoupleSubtitle =>
      'Prévoyance et patrimoine en couple';

  @override
  String get lightningMenuCoupleAction => 'Notre prévoyance couple';

  @override
  String get lightningMenuDebtTitle => 'Sortir de la dette';

  @override
  String get lightningMenuDebtSubtitle => 'Un plan pour réduire tes charges';

  @override
  String get lightningMenuDebtAction => 'Comment réduire ma dette ?';

  @override
  String get lightningMenuIndependantTitle => 'Mon filet indépendant';

  @override
  String get lightningMenuIndependantSubtitle =>
      'Couverture et protection en solo';

  @override
  String get lightningMenuIndependantAction => 'Ma couverture indépendant';

  @override
  String get lightningMenuRetirementPrepTitle => 'Préparer ma retraite';

  @override
  String get lightningMenuRetirementPrepSubtitle =>
      'Les dernières années comptent double';

  @override
  String get lightningMenuRetirementPrepAction => 'Mon plan retraite';

  @override
  String get lightningMenuPayslipTitle => 'Comprendre ma fiche de salaire';

  @override
  String get lightningMenuPayslipSubtitle =>
      'Salaire brut, net, déductions : tout s’éclaire';

  @override
  String get lightningMenuPayslipAction => 'Explique-moi ma fiche de salaire';

  @override
  String get lightningMenuThreePillarsTitle => 'C’est quoi les 3 piliers ?';

  @override
  String get lightningMenuThreePillarsSubtitle =>
      'Le système suisse en 2 minutes';

  @override
  String get lightningMenuThreePillarsAction =>
      'C’est quoi les 3 piliers suisses ?';

  @override
  String get lightningMenuScanDocTitle => 'Scanner un document';

  @override
  String get lightningMenuScanDocSubtitle =>
      'Certificat LPP, fiche de salaire, impôts';

  @override
  String get lightningMenuFirstBudgetTitle => 'Mon premier budget';

  @override
  String get lightningMenuFirstBudgetSubtitle =>
      'Savoir où va ton argent chaque mois';

  @override
  String get lightningMenuFirstBudgetAction => 'Aide-moi à faire mon budget';

  @override
  String get lightningMenuTaxReliefTitle => 'Où alléger mes impôts';

  @override
  String get lightningMenuTaxReliefSubtitle => 'Déductions et leviers fiscaux';

  @override
  String get lightningMenuTaxReliefAction => 'Comment payer moins d’impôts ?';

  @override
  String get lightningMenuCompleteProfileTitle => 'Compléter mon profil';

  @override
  String get lightningMenuCompleteProfileSubtitle =>
      'Plus tu précises, plus MINT est juste';

  @override
  String get lightningMenuLppBuybackTitle => 'Racheter du LPP';

  @override
  String get lightningMenuLppBuybackSubtitle =>
      'Un levier fiscal souvent sous-estimé';

  @override
  String get lightningMenuLppBuybackAction =>
      'Un rachat LPP, ça vaut le coup ?';

  @override
  String get lightningMenuLivingBudgetTitle => 'Mon budget vivant';

  @override
  String get lightningMenuLivingBudgetSubtitle =>
      'Ton équilibre ce mois, mis à jour';

  @override
  String get lightningMenuLivingBudgetAction => 'Où j’en suis ?';

  @override
  String get budgetSnapshotTitle => 'Ton budget vivant';

  @override
  String get budgetSnapshotPresentLabel => 'Libre aujourd’hui';

  @override
  String get budgetSnapshotRetirementLabel => 'Libre retraite';

  @override
  String get budgetSnapshotGapLabel => 'Écart';

  @override
  String get budgetSnapshotConfidenceLabel => 'Fiabilité';

  @override
  String get budgetSnapshotConfidenceLow => 'Ajoute des données pour affiner.';

  @override
  String get budgetSnapshotConfidenceOk => 'Estimation crédible.';

  @override
  String get budgetSnapshotLeverLabel => 'Levier';

  @override
  String get budgetSnapshotFreeLabel => 'Ton libre mensuel';

  @override
  String get onboardingSmartTitle =>
      'Découvre ta situation retraite en 30 secondes';

  @override
  String get onboardingSmartSubtitle =>
      'Quelques infos suffisent pour un premier aperçu personnalisé.';

  @override
  String get onboardingSmartFirstNameLabel => 'Comment on t’appelle ?';

  @override
  String get onboardingSmartFirstNameHint => 'Ton prénom (optionnel)';

  @override
  String get onboardingSmartAgeDirectInput => 'Saisie directe';

  @override
  String get onboardingSmartSeeResult => 'Voir mon résultat';

  @override
  String get onboardingSmartDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil financier (LSFin). Les estimations sont basées sur les barèmes 2025 et peuvent varier.';

  @override
  String get onboardingSmartAgePickerHint => 'Choisis ton âge';

  @override
  String get onboardingSmartCountryOrigin => 'Ton pays d’origine';

  @override
  String get onboardingSmartCantonTitle => 'Choisis ton canton';

  @override
  String get onboardingSmartCantonNotFound => 'Aucun canton trouvé';

  @override
  String get onboardingSmartSalaryLabel => 'Ton salaire brut annuel';

  @override
  String get onboardingSmartAgeLabel => 'Ton âge';

  @override
  String get onboardingSmartEmploymentLabel => 'Ta situation professionnelle';

  @override
  String get onboardingSmartNationalityLabel => 'Ta nationalité';

  @override
  String get onboardingSmartCantonLabel => 'Ton canton';

  @override
  String get onboardingAgeInvalid => 'Âge entre 18 et 75 requis';

  @override
  String get onboardingSmartCantonSearch => 'Rechercher (ex : VD, Vaud)';

  @override
  String get onboardingSmartSalaryPerYear => 'CHF/an';

  @override
  String get greetingMorning => 'matin';

  @override
  String get greetingAfternoon => 'après-midi';

  @override
  String get greetingEvening => 'soir';

  @override
  String get authShowPassword => 'Afficher le mot de passe';

  @override
  String get authHidePassword => 'Masquer le mot de passe';

  @override
  String get exploreHubRetraiteIntro55plus =>
      'La retraite approche : chaque décision compte double. Voici où tu en es.';

  @override
  String get exploreHubRetraiteIntro40plus =>
      'Chaque année qui passe change tes options. Voici où tu en es.';

  @override
  String get exploreHubRetraiteIntroYoung =>
      'C’est loin, mais c’est maintenant que ça se joue. Voici pourquoi.';

  @override
  String get exploreHubTravailIntro55plus =>
      'Fin de carrière, retraite anticipée, transition : tes droits changent.';

  @override
  String get exploreHubTravailIntro40plus =>
      'Ton statut professionnel détermine tes droits. Vérifie-les.';

  @override
  String get exploreHubTravailIntroYoung =>
      'Premier emploi, indépendant, frontalier : chaque statut a ses règles.';

  @override
  String get exploreHubLogementIntro55plus =>
      'Rester, vendre, transmettre : les chiffres avant la décision.';

  @override
  String get exploreHubLogementIntro40plus =>
      'Acheter, louer, déménager : les chiffres avant la décision.';

  @override
  String get exploreHubLogementIntroYoung =>
      'Première acquisition ou location : comprendre les règles du jeu.';

  @override
  String get archetypeSwissNative => 'Résident·e suisse';

  @override
  String get archetypeExpatEu => 'Expat EU/AELE';

  @override
  String get archetypeExpatNonEu => 'Expat hors EU';

  @override
  String get archetypeExpatUs => 'Résident·e US (FATCA)';

  @override
  String get archetypeIndependentWithLpp => 'Indépendant·e avec LPP';

  @override
  String get archetypeIndependentNoLpp => 'Indépendant·e sans LPP';

  @override
  String get archetypeCrossBorder => 'Frontalier·ère';

  @override
  String get archetypeReturningSwiss => 'Suisse de retour';

  @override
  String get employmentSalarie => 'Salarié·e';

  @override
  String get employmentIndependant => 'Indépendant·e';

  @override
  String get employmentSansEmploi => 'Sans emploi';

  @override
  String get employmentRetraite => 'Retraité·e';

  @override
  String get nationalitySuisse => 'Suisse';

  @override
  String get nationalityEuAele => 'EU/AELE';

  @override
  String get nationalityAutre => 'Autre';

  @override
  String get stepStressTitle => 'Qu’est-ce qui te préoccupe le plus ?';

  @override
  String get stepStressSubtitle =>
      'Choisis un thème — on personnalise ton expérience.';

  @override
  String get stepStressRetirement => 'Ma retraite';

  @override
  String get stepStressRetirementSub => 'Vais-je avoir assez pour vivre ?';

  @override
  String get stepStressTaxes => 'Mes impôts';

  @override
  String get stepStressTaxesSub => 'Est-ce que je paie trop ?';

  @override
  String get stepStressBudget => 'Mon budget';

  @override
  String get stepStressBudgetSub => 'Où passe mon argent ?';

  @override
  String get stepStressWealth => 'Mon patrimoine';

  @override
  String get stepStressWealthSub => 'Comment le faire grandir ?';

  @override
  String get stepStressCouple => 'En couple';

  @override
  String get stepStressCoupleSub => 'Optimiser à deux';

  @override
  String get stepStressCurious => 'Juste curieux';

  @override
  String get stepStressCuriousSub => 'Je veux comprendre ma situation';

  @override
  String get stepStressDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil financier (LSFin).';

  @override
  String get stepNextTitle => 'Ton premier bilan est prêt';

  @override
  String stepNextConfidence(int pct) {
    return 'Précision actuelle : $pct %. Plus tu complètes ton profil, plus les projections seront fiables.';
  }

  @override
  String get stepNextEnrich => 'Affiner mon profil';

  @override
  String get stepNextDashboard => 'Voir mon dashboard';

  @override
  String get stepNextCheckin => 'Faire mon premier check-in';

  @override
  String get stepNextDisclaimer =>
      'Outil éducatif simplifié. Ne constitue pas un conseil financier (LSFin). Sources : LAVS art. 34, LPP art. 14-16, OPP3 art. 7.';

  @override
  String get stepTopActionsTitle => 'Tes 3 actions prioritaires';

  @override
  String get stepTopActionsSubtitle =>
      'Basées sur ta situation, voici par où commencer.';

  @override
  String get stepTopActionsEmpty =>
      'Complète ton profil pour recevoir des actions personnalisées.';

  @override
  String get stepTopActionsContinue => 'Continuer';

  @override
  String get stepTopActionsBack => 'Retour';

  @override
  String stepTopActionsImpact(String amount) {
    return 'Impact estimé : $amount';
  }

  @override
  String get stepTopActionsDisclaimer =>
      'Suggestions éducatives. Ne constitue pas un conseil financier (LSFin). Consulte un·e spécialiste pour un plan personnalisé.';

  @override
  String stepChocConfidenceInfo(int count) {
    return 'Estimation basée sur $count informations. Plus tu précises, plus c’est fiable.';
  }

  @override
  String stepChocConfidenceLabel(int pct) {
    return 'Précision : $pct %';
  }

  @override
  String get stepChocLiteracyTitle => 'Pour personnaliser tes conseils';

  @override
  String get stepChocLiteracySubtitle =>
      '3 questions rapides — aucune bonne ou mauvaise réponse.';

  @override
  String get stepChocLiteracyLpp => 'Je connais le montant de mon avoir LPP';

  @override
  String get stepChocLiteracyConversion =>
      'Je sais ce qu’est le taux de conversion';

  @override
  String get stepChocLiteracy3a => 'J’ai déjà versé sur un compte 3a';

  @override
  String get stepChocYes => 'Oui';

  @override
  String get stepChocNo => 'Non';

  @override
  String get stepChocAction => 'Qu’est-ce que je peux faire ?';

  @override
  String get stepChocEnrich => 'Affiner mon profil';

  @override
  String get stepChocDashboard => 'Voir mon dashboard';

  @override
  String get stepChocDisclaimer =>
      'Outil éducatif simplifié. Ne constitue pas un conseil financier (LSFin). Sources : LAVS art. 34, LPP art. 14-16, OPP3 art. 7.';

  @override
  String get stepJitTitle => 'Comprendre en 30 secondes';

  @override
  String get stepJitSi => 'SI';

  @override
  String get stepJitAlors => 'ALORS';

  @override
  String get stepJitAction => 'Que puis-je faire ?';

  @override
  String get stepJitBack => 'Retour';

  @override
  String get stepJitDisclaimer =>
      'Outil éducatif simplifié. Ne constitue pas un conseil financier (LSFin).';

  @override
  String get stepJitLiquidityCond =>
      'ton épargne de sécurité couvre moins de 2 mois de charges';

  @override
  String get stepJitLiquidityCons =>
      'un imprévu (perte d’emploi, réparation urgente) peut te mettre en difficulté financière rapidement.';

  @override
  String get stepJitLiquidityInsight =>
      'Les experts recommandent 3 à 6 mois de charges fixes en réserve. Même 100 CHF/mois sur un compte épargne fait une différence significative sur 12 mois.';

  @override
  String get stepJitLiquiditySource => 'Recommandation Budget-conseil Suisse';

  @override
  String get stepJitRetirementCond =>
      'ton taux de remplacement à la retraite est inférieur à 60 %';

  @override
  String get stepJitRetirementCons =>
      'ton niveau de vie pourrait baisser significativement le jour où tu arrêtes de travailler.';

  @override
  String get stepJitRetirementInsight =>
      'En Suisse, l’AVS et la LPP couvrent en moyenne 60 % du dernier salaire. Le 3e pilier et l’épargne libre comblent le reste. Plus tu commences tôt, moins l’effort mensuel est important.';

  @override
  String get stepJitRetirementSource => 'LAVS art. 34 / LPP art. 14';

  @override
  String get stepJitTax3aCond =>
      'tu ne verses pas le maximum dans ton 3e pilier chaque année';

  @override
  String get stepJitTax3aCons =>
      'tu passes à côté d’une économie fiscale et d’un capital retraite supplémentaire.';

  @override
  String get stepJitTax3aInsight =>
      'Chaque franc versé en 3a est déductible du revenu imposable. Sur 20 ans, la différence entre verser 0 et le plafond (7’258 CHF) peut représenter plus de 200’000 CHF.';

  @override
  String get stepJitTax3aSource => 'OPP3 art. 7 / LIFD art. 33';

  @override
  String get stepJitIncomeCond =>
      'ta projection de revenu à la retraite est estimée';

  @override
  String get stepJitIncomeCons =>
      'connaître ce montant te permet de planifier et d’ajuster ta stratégie de prévoyance dès maintenant.';

  @override
  String get stepJitIncomeInsight =>
      'Le système suisse à 3 piliers (AVS + LPP + 3a) couvre en moyenne 60 % du dernier salaire. Chaque pilier a ses règles et ses leviers d’optimisation spécifiques.';

  @override
  String get stepJitIncomeSource => 'LAVS art. 34 / LPP art. 14 / OPP3 art. 7';

  @override
  String get stepJitDefaultCond =>
      'tu n’as pas encore un plan financier structuré';

  @override
  String get stepJitDefaultCons =>
      'tu risques de passer à côté d’opportunités d’optimisation fiscale et de prévoyance.';

  @override
  String get stepJitDefaultInsight =>
      'Un bilan financier annuel permet d’identifier les leviers les plus impactants : 3a, rachat LPP, franchise LAMal, amortissement indirect.';

  @override
  String get stepJitDefaultSource => 'Recommandation éducative MINT';

  @override
  String get stepOcrTitle => 'Enrichis ton profil en 30 secondes';

  @override
  String get stepOcrSkip => 'Continuer sans document';

  @override
  String get stepOcrIntro =>
      'Scanne un ou plusieurs documents pour que MINT calcule ta situation avec plus de précision.';

  @override
  String get stepOcrLppTitle => 'Ta lettre de retraite LPP';

  @override
  String get stepOcrLppSubtitle =>
      'Avoir, taux de conversion, lacune de rachat';

  @override
  String get stepOcrLppBoost => '+27 pts de précision';

  @override
  String get stepOcrAvsTitle => 'Ton extrait AVS';

  @override
  String get stepOcrAvsSubtitle => 'Années de cotisation, lacunes, RAMD';

  @override
  String get stepOcrAvsBoost => '+22 pts de précision';

  @override
  String get stepOcrTaxTitle => 'Ta déclaration fiscale';

  @override
  String get stepOcrTaxSubtitle => 'Revenu imposable, fortune, taux marginal';

  @override
  String get stepOcrTaxBoost => '+17 pts de précision';

  @override
  String get stepOcr3aTitle => 'Ton compte 3a';

  @override
  String get stepOcr3aSubtitle => 'Solde, versements cumulés, rendement';

  @override
  String get stepOcr3aBoost => '+7 pts de précision';

  @override
  String get stepOcrScanned => 'Scanné';

  @override
  String stepOcrContinueWith(int count, String plural) {
    return 'Continuer ($count document$plural scanné$plural)';
  }

  @override
  String get stepOcrContinueWithout => 'Continuer sans document';

  @override
  String get stepOcrDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil financier (LSFin). Documents traités sur ton appareil, aucune donnée envoyée (LPD art. 6).';

  @override
  String get stepOcrLpdBanner =>
      'Tes documents sont traités sur ton appareil. Rien n’est envoyé sur Internet.';

  @override
  String get stepOcrLpdTitle => 'Traitement privé sur ton appareil';

  @override
  String get stepOcrLpdBody =>
      'Ce document est analysé directement sur ton téléphone.\nAucune donnée n’est envoyée sur Internet.\nLes informations extraites sont supprimées après traitement.';

  @override
  String get stepOcrLpdLegal =>
      'Base légale : LPD art. 6 — minimisation des données.';

  @override
  String get stepOcrLpdScan => 'Scanner ce document';

  @override
  String get stepOcrLpdCancel => 'Annuler';

  @override
  String stepOcrSnackSuccess(int count, String plural) {
    return '$count champ$plural extrait$plural avec succès';
  }

  @override
  String get stepOcrSnackEmpty =>
      'Document traité — aucun champ reconnu automatiquement';

  @override
  String stepOcrSnackError(String error) {
    return 'Erreur lors du traitement : $error';
  }

  @override
  String get stepOcrSnackWebOnly =>
      'Scan d’image non disponible sur web. Utilise l’app mobile ou importe un fichier .txt.';

  @override
  String stepQuestionsAgeYears(int age) {
    return '$age ans';
  }

  @override
  String get stepQuestionsCountryUs => 'États-Unis';

  @override
  String get stepQuestionsCountryGb => 'Royaume-Uni';

  @override
  String get stepQuestionsCountryCa => 'Canada';

  @override
  String get stepQuestionsCountryIn => 'Inde';

  @override
  String get stepQuestionsCountryCn => 'Chine';

  @override
  String get stepQuestionsCountryBr => 'Brésil';

  @override
  String get stepQuestionsCountryAu => 'Australie';

  @override
  String get stepQuestionsCountryJp => 'Japon';

  @override
  String get householdAcceptCodeHint => 'CODE';

  @override
  String get friInsufficientData => 'Complète ton profil pour voir ton score';

  @override
  String projectionUncertaintyBand(String low, String high) {
    return 'CHF $low — $high / mois';
  }

  @override
  String get portfolioAppBarTitle => 'Mon patrimoine';

  @override
  String get portfolioValeurTotaleNette => 'Valeur totale nette';

  @override
  String get portfolioRepartitionEnveloppe => 'Répartition par enveloppe';

  @override
  String get portfolioLibrePlacement => 'Libre (Compte Placement)';

  @override
  String get portfolioLiePilier3a => 'Lié (Pilier 3a)';

  @override
  String get portfolioReserveFondsUrgence => 'Réservé (Fonds d\'urgence)';

  @override
  String get portfolioSafeModeLocked => 'Priorité au désendettement';

  @override
  String get portfolioSafeModeBody =>
      'Les conseils d\'allocation sont désactivés en mode protection. Ta priorité est de réduire tes dettes avant de rééquilibrer ton patrimoine.';

  @override
  String get byokShowKey => 'Afficher la clé';

  @override
  String get byokHideKey => 'Masquer la clé';

  @override
  String get themeDetailEssentiel60s => 'L\'essentiel en 60 secondes';

  @override
  String get themeDetailTesteConnaissances => 'Teste tes connaissances';

  @override
  String get themeDetailSavaisTu => 'Le savais-tu ?';

  @override
  String get themeDetailSourcesLegales => 'Sources légales';

  @override
  String get themeDetailRappel => 'Rappel';

  @override
  String get themeDetailBienVu => 'Bien vu !';

  @override
  String get themeDetailPasToutAFait => 'Pas tout à fait...';

  @override
  String get emergencyFundTitle => 'Ton filet de sécurité';

  @override
  String get emergencyFundSubtitle => 'Calcule ton fonds d\'urgence idéal';

  @override
  String get emergencyFundDisclaimer =>
      'L\'objectif de 3-6 mois est une recommandation générale. Ta situation personnelle peut nécessiter un montant différent.';

  @override
  String get emergencyFundHyp1 =>
      'Charges fixes = loyer + assurances + abonnements + crédits';

  @override
  String get emergencyFundHyp2 =>
      'Objectif recommandé : 3 mois (minimum) à 6 mois (confort)';

  @override
  String get emergencyFundHyp3 =>
      'Placement suggéré : compte épargne accessible, non investi';

  @override
  String get emergencyFundChargesLabel => 'Tes charges fixes mensuelles';

  @override
  String get emergencyFundChargesDesc =>
      'Loyer + assurances + abonnements + crédits';

  @override
  String get emergencyFundObjectifLabel => 'Objectif en mois de sécurité';

  @override
  String emergencyFundMoisUnit(int count) {
    return '$count mois';
  }

  @override
  String get emergencyFundMinimum => 'Minimum';

  @override
  String get emergencyFundConfort => 'Confort';

  @override
  String get emergencyFundObjectifTitle => 'Ton objectif de fonds d\'urgence';

  @override
  String get emergencyFundProgression => 'Ta progression';

  @override
  String emergencyFundManque(String amount) {
    return 'Il te manque $amount';
  }

  @override
  String get emergencyFundAtteint => 'Objectif atteint !';

  @override
  String get emergencyFundExplication =>
      'Ce fonds te protège des imprévus (perte d\'emploi, maladie, réparations) sans toucher à tes investissements.';

  @override
  String get lifeEventSuggestionsHeader => 'Et ensuite ?';

  @override
  String get lifeEventSuggestionsSubheader => 'Modules adaptés à ton profil';

  @override
  String get lifeEventSuggestionsSimuler => 'Simuler';

  @override
  String get lifeEventSugMariage => 'Mariage';

  @override
  String get lifeEventSugMariageReason =>
      'Découvre l\'impact fiscal et sur la prévoyance';

  @override
  String get lifeEventSugConcubinage => 'Concubinage';

  @override
  String get lifeEventSugConcubinageReason =>
      'Attention : aucune protection légale automatique';

  @override
  String get lifeEventSugNaissance => 'Naissance';

  @override
  String get lifeEventSugNaissanceReason =>
      'Simule l\'impact financier d\'un enfant';

  @override
  String get lifeEventSugSuccession => 'Planification successorale';

  @override
  String get lifeEventSugSuccessionReason =>
      'Réserves héréditaires et quotité disponible (CC art. 470)';

  @override
  String get lifeEventSugDonation => 'Donation entre vifs';

  @override
  String get lifeEventSugDonationReason =>
      'Anticipe ta succession et optimise la fiscalité';

  @override
  String get lifeEventSugPremierEmploi => 'Premier emploi';

  @override
  String get lifeEventSugPremierEmploiReason =>
      'Pose les bases : AVS, LPP, 3a et budget';

  @override
  String get lifeEventSugChangementEmploi => 'Changement d\'emploi';

  @override
  String get lifeEventSugChangementEmploiReason =>
      'Compare ton LPP avant de signer un nouveau contrat';

  @override
  String get lifeEventSugOutilsIndependant => 'Outils indépendant';

  @override
  String get lifeEventSugOutilsIndependantReason =>
      'AVS, LPP volontaire, 3a élargi et dividende vs salaire';

  @override
  String get lifeEventSugRetraite => 'Planification retraite';

  @override
  String get lifeEventSugRetraiteReason =>
      'Rente vs capital, échelonnement 3a, lacune AVS';

  @override
  String get lifeEventSugAchatImmo => 'Achat immobilier';

  @override
  String get lifeEventSugAchatImmoReason =>
      'Simule ta capacité d\'emprunt et l\'apport EPL';

  @override
  String get lifeEventSugDemenagement => 'Déménagement cantonal';

  @override
  String get lifeEventSugDemenagementReason =>
      'Ton canton est parmi les plus imposés — compare les 26';

  @override
  String get lifeEventSugInvalidite => 'Invalidité';

  @override
  String get lifeEventSugInvaliditeReason =>
      'Vérifie ta couverture AI + LPP en cas d\'accident';

  @override
  String get indepProtAvs => 'Double ta cotisation';

  @override
  String get indepProtLpp => 'Disparaît — choix volontaire';

  @override
  String get indepProtLaa => 'Disparaît — accident hors travail';

  @override
  String get indepProtIjm => 'Disparaît — maladie 0 CHF';

  @override
  String get indepProtApg => 'Disparaît — congé parental';

  @override
  String get indepLppProInvalidite => 'Couverture invalidité incluse';

  @override
  String get indepLppProDeductible => 'Cotisations déductibles';

  @override
  String get indepLppProRente => 'Rente prévue à la retraite';

  @override
  String get indepLppConCotisations => 'Cotisations obligatoires élevées';

  @override
  String get indepLppConFlexible => 'Moins flexible';

  @override
  String get indepGrand3aSub => '20% du revenu net, max CHF 36\'288/an';

  @override
  String get indepGrand3aProFlexibilite => 'Flexibilité totale';

  @override
  String get indepGrand3aProDeduction => 'Déduction fiscale maximale';

  @override
  String get indepGrand3aProCapital => 'Capital disponible à 60 ans';

  @override
  String get indepGrand3aConInvalidite => 'Pas de couverture invalidité';

  @override
  String get indepGrand3aConRente => 'Pas de rente prévue';

  @override
  String get indepLayerImpots => 'Impôts (estimation)';

  @override
  String get indepLayerChargesSociales => 'Charges sociales AVS/AI';

  @override
  String get indepLayerFraisPro => 'Frais professionnels';

  @override
  String get indepLayerJoursNonFact => 'Jours non facturables';

  @override
  String get indepFiscal3a => 'Pilier 3a grand versement';

  @override
  String get indepFiscal3aNote =>
      'Max 20% du revenu net, plafonné à CHF 36\'288/an sans LPP';

  @override
  String get indepFiscalFraisPro => 'Frais professionnels effectifs';

  @override
  String get indepFiscalFraisProNote =>
      'Loyer bureau, matériel, formation — déductibles au réel';

  @override
  String get indepFiscalPrimesLpp => 'Primes assurance maladie (LPP vol.)';

  @override
  String get indepChargeAvs => 'AVS / AI / APG';

  @override
  String get indepChargeLpp => 'LPP (2e pilier)';

  @override
  String get indepChargeLppNote => 'Facultatif pour indépendant (LPP art. 4)';

  @override
  String get indepChargeAc => 'Chômage (AC)';

  @override
  String get indepChargeAcNote => 'Pas d\'AC pour indépendant (LACI art. 2)';

  @override
  String get indepChargePro => 'Cotisations pro (IJM/LAA)';

  @override
  String get indepChargeProNote => 'À charge entière de l\'indépendant';

  @override
  String get indepPlanInscriptionAvs => 'Inscription caisse AVS indépendants';

  @override
  String get indepPlanInscriptionAvsConseq =>
      'Amendes rétroactives si délai dépassé';

  @override
  String get indepPlanLaa => 'Assurance accidents LAA (si pas LPP)';

  @override
  String get indepPlanLaaConseq => 'Pas de couverture accident professionnel';

  @override
  String get indepPlanOuvrir3a =>
      'Ouvrir compte 3a (déduction jusqu\'à CHF 36\'288)';

  @override
  String get indepPlanIjm => 'Évaluer IJM (indemnité journalière maladie)';

  @override
  String get indepPlanIjmConseq => 'Perte de revenus dès J+3 en cas de maladie';

  @override
  String get indepPlanFraisPro =>
      'Frais professionnels déductibles — tenir registre';

  @override
  String get indepPlanAcomptes =>
      'Acomptes impôts cantonaux — éviter les intérêts';

  @override
  String get donationTypeEspeces => 'Espèces / Liquidités';

  @override
  String get donationTypeImmobilier => 'Immobilier';

  @override
  String get donationTypeTitres => 'Titres / Valeurs mobilières';

  @override
  String get donationRegimeParticipation => 'Participation aux acquêts';

  @override
  String get donationRegimeCommunaute => 'Communauté de biens';

  @override
  String get donationRegimeSeparation => 'Séparation de biens';

  @override
  String donationReserveBarLabel(String pct) {
    return 'Réserve $pct%';
  }

  @override
  String donationDisponibleBarLabel(String pct) {
    return 'Disponible $pct%';
  }

  @override
  String get donationDisclaimerFallback =>
      'Cet outil éducatif fournit des estimations indicatives et ne constitue pas un conseil juridique, fiscal ou notarial personnalisé au sens de la LSFin. Consulte un·e spécialiste (notaire) pour ta situation.';
}
