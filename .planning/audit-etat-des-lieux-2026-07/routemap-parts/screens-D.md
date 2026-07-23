# Routemap — Segment D (seg_ad, 30 fichiers)

Extraction mécanique 2026-07-23. Câblage route vérifié contre `apps/mobile/lib/app.dart` (SHA base 8d059e502).

## MintScene3aLevier (`apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart`)
- boutons/actions:
  - [onboardingAdjustDecreaseStep (OnboardingDiscreteAdjustControl −CHF 250) → setState local `_versement` + HapticFeedback]
  - [onboardingAdjustIncreaseStep (+CHF 250) → setState local `_versement` + HapticFeedback]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON — scène embarquée (pas de route propre), instanciée par `onboarding_shell_screen.dart:1317` (intent IMPOTS). Note: eyebrow/copy FR hardcodés (non-ARB).

## MintSceneCapaciteAchat (`apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart`)
- boutons/actions:
  - [onboardingAdjustDecreaseStep (−CHF 10'000 apport) → setState local `_apport` + HapticFeedback]
  - [onboardingAdjustIncreaseStep (+CHF 10'000 apport) → setState local `_apport` + HapticFeedback]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON — scène embarquée, instanciée par `onboarding_shell_screen.dart:1313` (intent ACHAT). Copy FR hardcodée (non-ARB).

## MintSceneEtatCivil (`apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_etat_civil.dart`)
- boutons/actions:
  - [onboardingCivilCelibataire → CoachProfileProvider.mergeAnswers({q_civil_status:'celibataire'}) puis callback onAnswered]
  - [onboardingCivilMarie → mergeAnswers({q_civil_status:'marie'}) + onAnswered]
  - [onboardingCivilConcubinage → mergeAnswers({q_civil_status:'concubinage'}) + onAnswered]
  - [onboardingCivilDivorce → mergeAnswers({q_civil_status:'divorce'}) + onAnswered]
  - [onboardingCivilVeuf → mergeAnswers({q_civil_status:'veuf'}) + onAnswered]
- champs: aucun
- nav sortantes: aucune (avancement délégué à l'orchestrateur via onAnswered)
- orphelin/façade: NON — scène embarquée, instanciée par `onboarding_shell_screen.dart:281`.

## MintSceneLacunesAvs (`apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_lacunes_avs.dart`)
- boutons/actions:
  - [onboardingAvsNoGaps → mergeAnswers({q_avs_lacunes_status:'no_gaps'}) + onAnswered]
  - [onboardingAvsLivedAbroad → setState sous-étape numérique (années à l'étranger)]
  - [onboardingAvsArrivedLate → setState sous-étape numérique (année d'arrivée)]
  - [onboardingAvsUnknown → mergeAnswers({q_avs_lacunes_status:'unknown'}) + onAnswered]
  - [onboardingAvsContinue (FilledButton, disabled si nombre invalide) → mergeAnswers(status + q_avs_arrival_year|q_avs_years_abroad) + onAnswered]
- champs:
  - [_numberController (TextField numérique — année 1950..courante ou années 1..60)]
- nav sortantes: aucune
- orphelin/façade: NON — scène embarquée, instanciée par `onboarding_shell_screen.dart:296`.

## MintSceneRenteTrouee (`apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart`)
- boutons/actions:
  - [onboardingAdjustDecreaseStep (−1 an espérance de vie) → setState local `_ageEsperance` + HapticFeedback]
  - [onboardingAdjustIncreaseStep (+1 an) → setState local `_ageEsperance` + HapticFeedback]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON — scène embarquée, instanciée par `onboarding_shell_screen.dart:1304` (intent RETRAITE). Appelle AvsCalculator/LppCalculator (financial_core L1). Copy FR hardcodée (non-ARB).

## MintSceneStatutEmploi (`apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_statut_emploi.dart`)
- boutons/actions:
  - [onboardingEmploymentSalarie → mergeAnswers({q_employment_status:'salarie'}) + onAnswered]
  - [onboardingEmploymentIndependant → mergeAnswers({q_employment_status:'independant'}) + onAnswered]
  - [onboardingEmploymentSansActivite → mergeAnswers({q_employment_status:'sans_activite'}) + onAnswered]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON — scène embarquée, instanciée par `onboarding_shell_screen.dart:266`.

## UsTaxPersonScreen (`apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/us_tax_person_screen.dart`)
- boutons/actions:
  - [waitlistUsTaxPersonYes → mergeAnswers({q_us_tax_person:true}) + ProfileMigrationService.clearReOnboardingFlag() + onAnswered(true)]
  - [waitlistUsTaxPersonNo → mergeAnswers({q_us_tax_person:false}) + clearReOnboardingFlag() + onAnswered(false)]
  - [icône info (us-tax-person-info) → ouvre AlertDialog FATCA (waitlistUsTaxPersonTooltip)]
  - [OK (MaterialLocalizations.okButtonLabel) → Navigator.pop(dialog)]
- champs: aucun
- nav sortantes: aucune (le routage vers /waitlist est fait par l'orchestrateur, pas ici)
- orphelin/façade: NON — embarqué via wrapper dans `onboarding_shell_screen.dart:155`.

## OnboardingChoiceButton (`apps/mobile/lib/screens/onboarding/mvp_wedge/widgets/onboarding_choice_button.dart`)
(helper, pas un écran)

## ConsentScreen (`apps/mobile/lib/screens/open_banking/consent_screen.dart`)
- boutons/actions:
  - [flèche retour → safePop(context) OU annule le flow nouveau consentement (setState) si flow ouvert]
  - [openBankingConsentRevoke → _revokeConsent : setState local (mock, aucune persistance)]
  - [openBankingAddConsent → _startNewConsentFlow (setState, wizard 3 étapes)]
  - [option banque (InkWell, consentSelectedBankLabel) → setState sélection + étape 1]
  - [checkbox consentScopeAccountsDesc → setState `_scopeAccounts`]
  - [checkbox consentScopeBalancesDesc → setState `_scopeBalances`]
  - [checkbox consentScopeTransactionsDesc → setState `_scopeTransactions`]
  - [openBankingBack → setState étape précédente]
  - [openBankingNext (disabled si aucun scope coché) → setState étape 2]
  - [openBankingConfirm → ajoute BankingConsent mock en mémoire (setState) + ferme le flow]
  - [consentAnnuler → _cancelNewConsentFlow (setState)]
- champs: aucun (checkboxes uniquement)
- nav sortantes: aucune
- orphelin/façade: NON (route `/open-banking/consents`, app.dart:1850) — MAIS écran 100% démo : données `OpenBankingService.getMockConsents()`, création/révocation = setState mémoire seulement, derrière bannière FINMA gate (façade assumée S14).

## OpenBankingHubScreen (`apps/mobile/lib/screens/open_banking/open_banking_hub_screen.dart`)
- boutons/actions:
  - [flèche retour → safePop(context)]
  - [openBankingHubViewTransactions (quick link) → context.push('/open-banking/transactions')]
  - [openBankingHubManageConsents (quick link) → context.push('/open-banking/consents')]
  - [openBankingHubAddBankLabel → BOUTON MORT volontaire : Opacity 0.5 + Tooltip openBankingAddBankDisabled, aucun onTap]
- champs: aucun
- nav sortantes:
  - context.push('/open-banking/transactions')
  - context.push('/open-banking/consents')
- orphelin/façade: NON (route `/open-banking`, app.dart:1838) — MAIS données 100% mock (getMockAccounts/getMonthlySummary) + bouton « ajouter une banque » désactivé (FINMA gate, façade assumée).

## TransactionListScreen (`apps/mobile/lib/screens/open_banking/transaction_list_screen.dart`)
- boutons/actions:
  - [flèche retour → safePop(context)]
  - [chip transactionListThisMonth → setState `_selectedPeriod` — SANS EFFET : `_filteredTransactions` ne lit jamais `_selectedPeriod`]
  - [chip transactionListLastMonth → setState `_selectedPeriod` — même défaut, filtre décoratif]
  - [chips catégories (openBankingCategoryAll…Divers, 13) → setState `_selectedCategory` (filtre effectif)]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (route `/open-banking/transactions`, app.dart:1844) — MAIS façade partielle : sélecteur de période sans effet sur les données + transactions 100% mock.

## ProviderComparatorScreen (`apps/mobile/lib/screens/pillar_3a_deep/provider_comparator_screen.dart`)
- boutons/actions:
  - [flèche retour → safePop(context)]
  - [segment providerComparatorProfilPrudent → setState `_profilRisque`]
  - [segment providerComparatorProfilEquilibre → setState `_profilRisque`]
  - [segment providerComparatorProfilDynamique → setState `_profilRisque`]
- champs:
  - [providerComparatorLabelAge (MintPremiumSlider 18-60)]
  - [providerComparatorLabelVersement (slider 1000-plafond 3a)]
  - [providerComparatorLabelDuree (slider 5-45 ans)]
- nav sortantes: aucune
- orphelin/façade: NON (route `/3a-deep/comparator`, app.dart:1155). Résultats gated SafeModeGate si dettes.

## RealReturnScreen (`apps/mobile/lib/screens/pillar_3a_deep/real_return_screen.dart`)
- boutons/actions:
  - [PopScope onPopInvoked → ScreenCompletionTracker.markCompletedWithReturn('real_return_3a', completed|abandoned) si contexte séquence]
- champs:
  - [realReturnAnnualPayment (slider 1000-plafond)]
  - [realReturnMarginalRate (slider 0-50%)]
  - [realReturnGrossReturn (slider 1-8%)]
  - [realReturnMgmtFees (slider 0-2%)]
  - [realReturnDuration (slider 5-40 ans)]
- nav sortantes: aucune (lit GoRouterState.extra runId/stepId en entrée)
- orphelin/façade: NON (route `/3a-deep/real-return`, app.dart:1160). Prefill via CoachProfileProvider + RetirementTaxCalculator.

## Retroactive3aScreen (`apps/mobile/lib/screens/pillar_3a_deep/retroactive_3a_screen.dart`)
- boutons/actions:
  - [flèche retour → safePop(context)]
  - [retroactive3aEmptyCta (empty state) → context.go('/coach/chat')]
  - [ChoiceChips années de rattrapage (1..min(10, année-2025)) → setState + _writeBackResult (CoachProfileProvider.updateProfile + SnackBar profileUpdatedSnackbar)]
  - [DropdownButton taux marginal (10-50%) → setState + _writeBackResult]
  - [Switch retroactive3aAffilieLpp → setState `_hasLpp`]
  - [tuile retroactive3aOuvrirCompte → MORTE : chevron_right affiché, aucun onTap]
  - [tuile retroactive3aPrepDocuments → MORTE : aucun onTap]
  - [tuile retroactive3aConsulterSpecialiste → MORTE : aucun onTap]
- champs: aucun (chips/dropdown/switch)
- nav sortantes:
  - context.go('/coach/chat')
- orphelin/façade: NON (route `/3a-retroactif`, app.dart:1167) — MAIS façade partielle : les 3 « action cards » (prochaines étapes) affichent un chevron cliquable-en-apparence sans aucun handler.

## StaggeredWithdrawalScreen (`apps/mobile/lib/screens/pillar_3a_deep/staggered_withdrawal_screen.dart`)
- boutons/actions:
  - [staggeredWithdrawalEmptyCta (empty state) → context.go('/coach/chat')]
  - [DropdownButton staggered3aCanton → setState + _emitScreenReturn (ScreenCompletionTracker)]
  - [PopScope → markCompletedWithReturn('staggered_withdrawal', completed avec stepOutputs.gain_echelonnement | abandoned)]
- champs:
  - [staggered3aAvoirTotal (slider 0-1'000'000)]
  - [staggered3aNbComptes (slider 1-5)]
  - [staggered3aRevenuImposable (slider 30'000-300'000)]
  - [staggered3aAgeDebut (slider 59-70)]
  - [staggered3aAgeFin (slider dynamique début-70)]
- nav sortantes:
  - context.go('/coach/chat')
- orphelin/façade: NON (route `/3a-deep/staggered-withdrawal`, app.dart:1165).

## FinancialSummaryScreen (`apps/mobile/lib/screens/profile/financial_summary_screen.dart`)
- boutons/actions:
  - [flèche retour → safePop(context)]
  - [financialSummaryStartDiagnostic (empty state) → context.go('/onb')]
  - [financialSummaryStartDiagnostic (incomplete state) → context.go('/onb')]
  - [onEdit tiroir « Ce que tu as » (drawerCeQueTuAs) → ouvre bottom sheet _showEditSheet (patrimoine)]
  - [onEdit tiroir « Ce que tu dois » (drawerCeQueTuDois) → ouvre bottom sheet (dettes)]
  - [onEdit tiroir « Ce que tu auras » (drawerCeQueTuAuras) → ouvre bottom sheet (prévoyance)]
  - [financialSummaryDossierCorrectionCta → ouvre bottom sheet correction dossier (11 champs)]
  - [EnrichmentCta (si champs manquants) → context.push('/scan')]
  - [HeroGapCard.onScanTap (si champs manquants) → context.push('/scan')]
  - [rangée sync (settingsPrivacyCloudSyncTitle) → context.push('/settings/confidentialite')]
  - [financialSummaryRestartDiagnostic → purge stores (ReportPersistenceService, SmartOnboardingDraftService, ConversationStore, CoachMemoryService, CapMemoryStore, PrecomputedInsightsService, CoachProfileProvider.clear) puis router.go('/onb') ; SnackBar financialSummaryRestartDiagnosticError si échec]
  - [financialSummaryEnregistrer (sheet) → await CoachProfileProvider.updateInline(...) puis ctx.pop()]
- champs (bottom sheets, TextEditingController dynamiques par clé):
  - [salaireBrutMensuel (numérique)]
  - [loyer (numérique)]
  - [assuranceMaladie (numérique)]
  - [epargneLiquide (numérique)]
  - [investissements (numérique)]
  - [avoirLppTotal (numérique)]
  - [nombre3a (numérique)]
  - [totalEpargne3a (numérique)]
  - [hypotheque (numérique)]
  - [creditConsommation (numérique)]
  - [leasing (numérique)]
  - [autresDettes (numérique)]
  - [rachatLppMensuel (numérique)]
- nav sortantes:
  - context.go('/onb') (×2 états + restart)
  - context.push('/scan') (×2)
  - context.push('/settings/confidentialite')
- orphelin/façade: NON (route `/profile/bilan`, app.dart:1562 ; redirect `/profile` → `/profile/bilan`).

## PrivacyCenterScreen (`apps/mobile/lib/screens/profile/privacy_center_screen.dart`)
- boutons/actions:
  - [consentRevoke (par receipt actif) → dialog confirmation → ConsentService.revoke(receiptId) + refresh]
  - [consentCancel (dialog) → Navigator.pop(false)]
  - [consentRevoke (dialog confirm) → Navigator.pop(true)]
  - [profileDeleteCloudAccount (ListTile, si loggé) → dialog → AuthProvider.deleteAccount() → context.go('/') si OK, SnackBar profileDeleteAccountError sinon]
  - [pull-to-refresh → ConsentService.list(force:true)]
- champs: aucun
- nav sortantes:
  - context.go('/')
- orphelin/façade: NON (route `/profile/privacy`, app.dart:1571 ; entrée UI via tuile de PrivacyControlScreen — l'orphelinat historique T05-F48 a été corrigé).

## PrivacyControlScreen (`apps/mobile/lib/screens/profile/privacy_control_screen.dart`)
- boutons/actions:
  - [icône delete AppBar (privacyControlProfileDataResetCta, conditionnelle) → dialog reset → CoachProfileProvider.clearAll()]
  - [tuile privacyControlConsentCenterTitle → context.push('/profile/privacy')]
  - [privacyControlDeleteCancel (état erreur, retry) → BiographyProvider.loadFacts()]
  - [FactCard.onEdit → ouvre bottom sheet FactEditSheet → provider.updateFactValue]
  - [FactCard.onDelete → dialog → provider.hardDeleteFact]
  - [privacyControlProfileDataResetCta (OutlinedButton fallback profil) → dialog → clearAll()]
  - [privacyControlDeleteCancel / privacyControlDeleteConfirm / privacyControlProfileDataResetConfirm (dialogs) → pop ± action]
  - [pull-to-refresh → loadFacts()]
- champs: aucun (édition déléguée à FactEditSheet)
- nav sortantes:
  - context.push('/profile/privacy')
- orphelin/façade: NON (route `/profile/privacy-control`, app.dart:1566).

## ConfidentialiteSettingsScreen (`apps/mobile/lib/screens/settings/confidentialite_settings_screen.dart`)
- boutons/actions:
  - [flèche retour → Navigator.pop si canPop, sinon context.go('/profile/bilan')]
  - [rangée InkWell (settingsPrivacyCloudSyncTitle) → AuthProvider.toggleCloudSync(!on) + HapticFeedback]
  - [Switch → AuthProvider.toggleCloudSync(value)]
- champs: aucun
- nav sortantes:
  - context.go('/profile/bilan') (fallback back)
- orphelin/façade: NON (route `/settings/confidentialite`, app.dart:1683).

## LangueSettingsScreen (`apps/mobile/lib/screens/settings/langue_settings_screen.dart`)
- boutons/actions:
  - [tuile par locale (6 : fr/en/de/es/it/pt, MintLocales.nameOf) → LocaleProvider.setLocale + SnackBar langueScreenChanged]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (route `/settings/langue`, app.dart:1678).

## Simulator3aScreen (`apps/mobile/lib/screens/simulator_3a_screen.dart`)
- boutons/actions:
  - [sim3aFatcaGateAction (si FATCA bloqué) → context.push('/coach?intent=fatca_3a_alternatives')]
  - [ChoiceChips taux marginal (10/20/25/30/35/40%) → setState + _calculate + _writeBackResult (updateProfile + SnackBar)]
  - [ChoiceChips rendement (1/3/5/7%) → setState + _calculate]
  - [sim3aCtaCompare → context.push('/3a-deep/comparator')]
  - [sim3aCtaCalculate → context.push('/3a-deep/real-return')]
  - [sim3aCtaPlan → context.push('/3a-deep/staggered-withdrawal')]
  - [PopScope → markCompletedWithReturn('simulator_3a', completed avec stepOutputs | abandoned) si séquence]
- champs:
  - [_contributionCtrl (TextField numérique, versement annuel CHF, clampé au plafond)]
- nav sortantes:
  - context.push('/coach?intent=fatca_3a_alternatives')
  - context.push('/3a-deep/comparator')
  - context.push('/3a-deep/real-return')
  - context.push('/3a-deep/staggered-withdrawal')
- orphelin/façade: NON (route `/pilier-3a`, app.dart:1142 + hôte drawer chat `chat_drawer_host.dart:116`).

## SimulatorCompoundScreen (`apps/mobile/lib/screens/simulator_compound_screen.dart`)
- boutons/actions:
  - [ExpansionTile compoundTauxRendement → déplie le slider rendement]
- champs:
  - [compoundCapitalDepart (slider 0-100'000)]
  - [compoundEpargneMensuelle (slider 0-5'000)]
  - [compoundHorizonTemps (slider 1-40 ans)]
  - [compoundTauxRendement (slider 0-12%)]
- nav sortantes: aucune
- orphelin/façade: NON (route `/simulator/compound`, app.dart:1627).

## SimulatorLeasingScreen (`apps/mobile/lib/screens/simulator_leasing_screen.dart`)
- boutons/actions: aucun bouton — recalcul continu via sliders
- champs:
  - [leasingMensualitePrevue (slider 100-1'500)]
  - [leasingDuree (slider 12-60 mois)]
  - [leasingRendementAlternatif (slider 1-10%)]
- nav sortantes: aucune
- orphelin/façade: NON (route `/simulator/leasing`, app.dart:1632).

## SlmSettingsScreen (`apps/mobile/lib/screens/slm_settings_screen.dart`)
- boutons/actions:
  - [options tier (slmChooseModel, SlmTierConfig.allTiers) → SlmProvider.selectTier (disabled pendant download)]
  - [slmCancelDownload → SlmProvider.cancelDownload]
  - [slmDownloadButton / slmRetryDownload → dialog confirmation → SlmProvider.downloadModel ; SnackBar slmDownloadFailedSnack + action commonRetry si échec ; disabled → slmDownloadUnavailable]
  - [slmCancel / slmDownload (dialog download) → Navigator.pop(false/true)]
  - [slmDeleteModelButton → dialog → SlmProvider.deleteModel]
  - [slmCancel / slmDelete (dialog delete) → Navigator.pop(false/true)]
  - [slmInitEngine → SlmProvider.initializeEngine ; SnackBar slmInitError si échec]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (route `/profile/slm`, app.dart:1558).

## TimelineScreen (`apps/mobile/lib/screens/timeline_screen.dart`)
- boutons/actions:
  - [quick action timelineQuickCheckupTitle → context.push('/coach/chat')]
  - [quick action timelineQuickBudgetTitle → context.push('/budget')]
  - [quick action timelineQuickPilier3aTitle → context.push('/pilier-3a')]
  - [quick action timelineQuickFiscaliteTitle → context.push('/fiscal')]
  - [event timelineEventMariageTitle → context.push('/mariage')]
  - [event timelineEventConcubinageTitle → context.push('/concubinage')]
  - [event timelineEventNaissanceTitle → context.push('/naissance')]
  - [event timelineEventDivorceTitle → context.push('/divorce')]
  - [event timelineEventSuccessionTitle → context.push('/succession')]
  - [event timelineEventPremierEmploiTitle → context.push('/first-job')]
  - [event timelineEventChangementEmploiTitle → context.push('/simulator/job-comparison')]
  - [event timelineEventIndependantTitle → context.push('/segments/independant')]
  - [event timelineEventPerteEmploiTitle → context.push('/unemployment')]
  - [event timelineEventRetraiteTitle → context.push('/retraite')]
  - [event timelineEventAchatImmoTitle → context.push('/hypotheque')]
  - [event timelineEventVenteImmoTitle → context.push('/life-event/housing-sale')]
  - [event timelineEventHeritageTitle → context.push('/succession')]
  - [event timelineEventDonationTitle → context.push('/life-event/donation')]
  - [event timelineEventInvaliditeTitle → context.push('/invalidite')]
  - [event timelineEventDemenagementTitle → context.push('/fiscal')]
  - [event timelineEventExpatriationTitle → context.push('/expatriation')]
  - [event timelineEventSurendettementTitle → context.push('/check/debt')]
- champs: aucun
- nav sortantes: /coach/chat, /budget, /pilier-3a, /fiscal (×2 : quick action + déménagement), /mariage, /concubinage, /naissance, /divorce, /succession (×2 : succession + héritage), /first-job, /simulator/job-comparison, /segments/independant, /unemployment, /retraite, /hypotheque, /life-event/housing-sale, /life-event/donation, /invalidite, /expatriation, /check/debt — toutes en context.push
- orphelin/façade: NON (route `/timeline`, app.dart:1742).

## UnemploymentScreen (`apps/mobile/lib/screens/unemployment_screen.dart`)
- boutons/actions:
  - [flèche retour → safePop(context)]
  - [Switch unemploymentChildrenToggle → setState `_hasChildren` + _calculate]
  - [Switch unemploymentDisabilityToggle → setState `_hasDisability` + _calculate]
  - [checklist 6 items (unemploymentCheckItem1..6) → setState toggle coché/décoché (état local uniquement)]
- champs:
  - [unemploymentGainSliderTitle (MintAmountField 0-12'350)]
  - [unemploymentAgeSliderTitle (MintPickerTile 18-65)]
  - [unemploymentContribTitle (MintPickerTile 0-24 mois)]
- nav sortantes: aucune
- orphelin/façade: NON (route `/unemployment`, app.dart:1282).

## WaitlistArgs (`apps/mobile/lib/screens/waitlist/waitlist_args.dart`)
(helper, pas un écran — classe d'arguments GoRouterState.extra pour /waitlist)

## WaitlistScreen (`apps/mobile/lib/screens/waitlist/waitlist_screen.dart`)
- boutons/actions: aucun en propre — dispatcher d'état WaitlistProvider : success → WaitlistSuccess ; initial/submitting/error → WaitlistForm
- champs: aucun (délégués à WaitlistForm)
- nav sortantes: aucune (déléguées aux sous-widgets)
- orphelin/façade: NON (route `/waitlist`, app.dart:577-587, hard gate archétype 01.5).

## WaitlistForm (`apps/mobile/lib/screens/waitlist/widgets/waitlist_form.dart`)
- boutons/actions:
  - [waitlistCorrectProfileCta (OutlinedButton, conditionnel) → callback onCorrectProfile (fourni par le registrar de route)]
  - [checkbox waitlistConsentCheckbox → setState `_consentGiven` (opt-in explicite, jamais pré-coché)]
  - [waitlistCta (FilledButton, disabled tant que email invalide OU consentement absent OU submitting) → WaitlistProvider.submit(email, archetype, locale, source, consentGiven)]
- champs:
  - [_emailController (MintTextField waitlistEmailLabel, type email, regex validée)]
- nav sortantes: aucune
- orphelin/façade: NON — corps de WaitlistScreen (états initial/submitting/error).

## WaitlistSuccess (`apps/mobile/lib/screens/waitlist/widgets/waitlist_success.dart`)
- boutons/actions:
  - [waitlistSuccessCta → context.go('/')]
- champs: aucun
- nav sortantes:
  - context.go('/')
- orphelin/façade: NON — corps de WaitlistScreen (état success). Annonce a11y via SemanticsService au montage.

---

## Synthèse segment D
- 30 fichiers traités : 28 écrans/scènes/corps d'écran documentés + 2 helpers (`onboarding_choice_button.dart`, `waitlist_args.dart`).
- 0 orphelin de route (tous les écrans routés sont enregistrés dans `app.dart` ; les 7 scènes onboarding sont câblées via `onboarding_shell_screen.dart`).
- 4 façades partielles :
  1. `OpenBankingHubScreen` — bouton « ajouter une banque » mort (volontaire, FINMA gate) + données 100% mock.
  2. `ConsentScreen` — consentements Open Banking 100% mock, aucune persistance (démo assumée).
  3. `TransactionListScreen` — chips période « ce mois / mois dernier » setState sans aucun effet sur les données + transactions mock.
  4. `Retroactive3aScreen` — 3 « action cards » (ouvrir compte / préparer documents / consulter spécialiste) avec chevron mais sans onTap.
