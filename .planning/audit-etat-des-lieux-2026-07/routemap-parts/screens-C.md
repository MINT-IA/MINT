# Routemap — Segment C (seg_ac, 32 fichiers)

Extraction mécanique 2026-07-23. Router de référence : `apps/mobile/lib/app.dart` (toutes les classes écran ci-dessous y sont référencées — lignes citées par écran).

## FirstJobScreen (`apps/mobile/lib/screens/first_job_screen.dart`)
- boutons/actions:
  - [semanticsBackButton (IconButton arrow_back) → safePop(context)]
  - [firstJobSalaryTitle (slider salaire 2000-15000) → setState + FirstJobService.analyzeSalary]
  - [unemploymentAgeSliderTitle (slider âge 18-30) → setState + recalcul]
  - [canton (DropdownButton 26 cantons) → setState + recalcul]
  - [firstJobActivityRate (MintPremiumSlider 10-100%) → setState + recalcul]
  - [firstJobChecklistHeader items (GestureDetector) → setState local (toggle _checkedItems)]
  - [firstJobScenarioBoosted/median… (chips scénario) → setState _salaire + recalcul]
  - [pop de l'écran → ScreenCompletionTracker.markCompletedWithReturn('first_job', …) (contexte séquence via GoRouter.extra)]
- champs: aucun TextEditingController — inputs: _salaire (slider), _age (slider), _canton (dropdown), _tauxActivite (slider)
- nav sortantes: aucune
- orphelin/façade: NON (route câblée app.dart:1287, service FirstJobService branché)

## FiscalComparatorScreen (`apps/mobile/lib/screens/fiscal_comparator_screen.dart`)
- boutons/actions:
  - [semanticsBackButton → safePop(context)]
  - [TabBar 3 onglets (Mon impôt / 26 cantons / Déménager) → TabController]
  - [fiscalGrossAnnualIncome (MintPremiumSlider 30k-500k) → setState + FiscalService.estimateTax/compareAllCantons/simulateMove + WealthTaxService.estimateWealthTax/estimateChurchTax]
  - [fiscalCanton (DropdownButton) → setState + recalcul (reset commune)]
  - [commune (dropdown si CommuneData.isLoaded) → setState + recalcul]
  - [fiscalSingle / fiscalMarried (SegmentedButton) → setState + recalcul]
  - [fiscalChildren (IconButton +/- 0-5) → setState + recalcul]
  - [fiscalChurchMember (Switch) → setState + recalcul]
  - [fiscalCurrentCanton / fiscalDestinationCanton (dropdowns onglet Déménager) → setState + FiscalService.simulateMove]
  - [fiscalChecklist1..6 (GestureDetector) → setState local (toggle _moveChecked)]
- champs: _fortuneController (TextField numérique CHF, fiscalNetWealth)
- nav sortantes: aucune
- orphelin/façade: NON (route câblée app.dart:1175; prefill séquence _montantRetrait via GoRouter.extra)

## FrontalierScreen (`apps/mobile/lib/screens/frontalier_screen.dart`)
- boutons/actions:
  - [semanticsBackButton → safePop(context)]
  - [TabBar 3 onglets (Impôts / 90 jours / Charges) → TabController]
  - [canton (DropdownButton) → ExpatService.calculateSourceTax]
  - [frontalierSalaireBrut (MintAmountField 3000-25000) → setState + recalcul]
  - [frontalierCelibataire / frontalierMarie (toggle 2 segments GestureDetector) → setState + recalcul]
  - [frontalierEnfantsCharge (stepper +/- 0-5) → setState + recalcul]
  - [frontalierJoursBureau (MintPickerTile 0-250) → ExpatService.simulate90DayRule]
  - [frontalierJoursHomeOffice (MintPickerTile 0-250) → recalcul 90 jours]
  - [frontalierSalaireBrut onglet Charges (MintAmountField) → ExpatService.compareSocialCharges]
  - [frontalierPaysResidence (chips pays France/…) → setState + recalcul charges]
- champs: aucun TextEditingController — inputs: _taxSalary, _taxMaritalStatus, _taxChildren, _bureauDays, _homeOfficeDays, _chargesSalary, _chargesCountry
- nav sortantes: aucune
- orphelin/façade: NON (route câblée app.dart:1585)

## GenderGapScreen (`apps/mobile/lib/screens/gender_gap_screen.dart`)
- boutons/actions:
  - [IconButton arrow_back → safePop(context)]
  - [taux d'activité (MintPremiumSlider 10-100%) → setState + GenderGapService.analyse]
- champs: aucun (autres paramètres — revenu, âge, avoir LPP — affichés en lecture seule, pré-remplis depuis CoachProfileProvider)
- nav sortantes: aucune
- orphelin/façade: NON (route câblée app.dart:1580)

## AcceptInvitationScreen (`apps/mobile/lib/screens/household/accept_invitation_screen.dart`)
- boutons/actions:
  - [acceptInvitationJoin (FilledButton) → HouseholdProvider.acceptInvitation(code) puis setState _accepted (désactivé si household.isLoading)]
  - [acceptInvitationVoirMenage (FilledButton, écran succès) → context.go('/couple')]
  - [tap fond → FocusScope.unfocus]
- champs: _codeController (TextField code 6 caractères, pré-rempli via deep link initialCode)
- nav sortantes: context.go('/couple')
- orphelin/façade: NON (route câblée app.dart:1468, code passé en query param)

## HouseholdScreen (`apps/mobile/lib/screens/household/household_screen.dart`)
- boutons/actions:
  - [householdDiscoverCouplePlus (FilledButton) → SubscriptionProvider.upgrade(couplePlus)]
  - [householdLogin (FilledButton) → context.push('/auth/login')]
  - [householdRetry (OutlinedButton) → HouseholdProvider.clearError + loadHousehold]
  - [householdInvitePartner (FilledButton.icon) → setState _showInviteForm=true]
  - [householdSendInvitation (FilledButton) → HouseholdProvider.invitePartner(email) (désactivé si isLoading)]
  - [householdRemoveTooltip (IconButton) → _confirmRevoke → ouvre AlertDialog (householdCancel/householdRemove) → HouseholdProvider.revokeMember]
  - [householdCopy (OutlinedButton.icon) → Clipboard.setData + SnackBar]
  - [householdShare (OutlinedButton.icon) → Clipboard.setData(householdShareMessage) + SnackBar]
  - [householdHaveCode (OutlinedButton.icon) → context.push('/household/accept')]
- champs: _emailController (TextField email partenaire)
- nav sortantes: context.push('/auth/login') ; context.push('/household/accept')
- orphelin/façade: NON (route câblée app.dart:1453)

## HousingSaleScreen (`apps/mobile/lib/screens/housing_sale_screen.dart`)
- boutons/actions:
  - [housingSaleCalculer (FilledButton.icon) → HousingSaleService.calculate + setState _result]
  - [housingSalePrixAchat / housingSalePrixVente / housingSaleInvestissements / housingSaleFraisAcquisition / housingSaleHypotheque / housingSaleEplLpp / housingSaleEpl3a / housingSalePrixNouveauBien (MintAmountField) → setState local]
  - [housingSaleAnneeAchat (MintPickerTile 1980-2025) → setState local]
  - [housingSaleCanton (DropdownButton) → setState local]
  - [housingSaleResidencePrincipale / housingSaleProjetRemploi (Switch) → setState local]
  - [checklist items (InkWell) → setState local (toggle _checklistState)]
- champs: aucun TextEditingController — 8 amount fields + 1 picker + 1 dropdown + 2 switches (état local)
- nav sortantes: aucune
- orphelin/façade: NON (route câblée app.dart:1590; AppBar avec back implicite)

## IndependantScreen (`apps/mobile/lib/screens/independant_screen.dart`)
- boutons/actions:
  - [semanticsBackButton → safePop(context)]
  - [independantRevenueTitle (MintPremiumSlider 20k-200k) → setState + IndependantService.analyse]
  - [independantToggleLpp / independantToggleIjm / independantToggleLaa / independantToggle3a (Switch) → setState + recalcul]
- champs: aucun (âge/canton pré-remplis depuis CoachProfileProvider, pas de sélecteur UI)
- nav sortantes: aucune
- orphelin/façade: NON (route câblée app.dart:1304)

## AvsCotisationsScreen (`apps/mobile/lib/screens/independants/avs_cotisations_screen.dart`)
- boutons/actions:
  - [avsCotisationsRevenuLabel (MintPremiumSlider 0-250k) → setState + IndependantsService.calculateAvsCotisations]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (route câblée app.dart:1309; prefill depuis CoachProfileProvider)

## DividendeVsSalaireScreen (`apps/mobile/lib/screens/independants/dividende_vs_salaire_screen.dart`)
- boutons/actions:
  - [semanticsBackButton → safePop(context)]
  - [dividendeBeneficeTotal (MintAmountField 0-500k) → setState + IndependantsService.calculateDividendeVsSalaire]
  - [dividendePartSalaire (MintPremiumSlider 0-100%) → setState + recalcul]
  - [dividendeTauxMarginal (MintPremiumSlider 10-45%) → setState + recalcul]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (route câblée app.dart:1324)

## IjmScreen (`apps/mobile/lib/screens/independants/ijm_screen.dart`)
- boutons/actions:
  - [ijmRevenuMensuel (slider 0-20000) → setState + IndependantsService.calculateIjm]
  - [ijmTonAge (slider 18-65) → setState + recalcul]
  - [chips délai de carence 30/60/90 j (GestureDetector) → setState _delaiCarence + recalcul]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (route câblée app.dart:1314; prefill profil)

## LppVolontaireScreen (`apps/mobile/lib/screens/independants/lpp_volontaire_screen.dart`)
- boutons/actions:
  - [semanticsBackButton → safePop(context)]
  - [lppVolontaireRevenuLabel (MintAmountField 0-250k) → setState + IndependantsService.calculateLppVolontaire]
  - [lppVolontaireTonAge (MintPickerTile 25-65) → setState + recalcul]
  - [lppVolontaireTauxMarginal (MintPremiumSlider 10-45%) → setState + recalcul]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (route câblée app.dart:1329)

## Pillar3aIndepScreen (`apps/mobile/lib/screens/independants/pillar_3a_indep_screen.dart`)
- boutons/actions:
  - [semanticsBackButton → safePop(context)]
  - [semantics3aLppToggle (Switch affilié LPP) → setState + IndependantsService.calculate3aIndependant]
  - [pillar3aIndepRevenuLabel (MintAmountField 0-300k) → setState + recalcul]
  - [pillar3aIndepTauxLabel (MintPremiumSlider 10-45%) → setState + recalcul]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (route câblée app.dart:1319)

## JobComparisonScreen (`apps/mobile/lib/screens/job_comparison_screen.dart`)
- boutons/actions:
  - [jobCompareButton (FilledButton.icon) → JobComparisonService.compare + setState _result + scroll vers résultats]
  - [Age (MintPickerTile 25-64) → setState local]
  - [jobCompareReduce / jobCompareShowDetails (InkWell) → setState toggle section (poste actuel / nouveau poste)]
  - [jobCompareSalaryLabel / jobCompareRetirementAssets / jobCompareDeathCapital / jobCompareMaxBuyback (MintAmountField ×2 postes) → setState local]
  - [part employeur (chips 50/60/70%) → setState local]
  - [jobCompareConversionRate / jobCompareDisabilityCoverage (MintPremiumSlider ×2 postes) → setState local]
  - [jobCompareIjm (Switch ×2 postes) → setState local]
  - [checklist items (InkWell) → setState local]
- champs: aucun TextEditingController — ~16 inputs (2 jeux de 8 par poste, état local, poste actuel seedé depuis CoachProfile)
- nav sortantes: aucune
- orphelin/façade: NON (route câblée app.dart:1297)

## LamalFranchiseScreen (`apps/mobile/lib/screens/lamal_franchise_screen.dart`)
- boutons/actions:
  - [semanticsBackButton → safePop(context)]
  - [lamalFranchiseToggleAdulte / lamalFranchiseToggleEnfant (GestureDetector 2 segments) → setState _isChild + LamalFranchiseService.analyzeAllFranchises]
  - [lamalFranchisePrimeSliderLabel (MintAmountField 200-600) → setState + recalcul]
  - [lamalFranchiseDepensesSliderLabel (MintAmountField 0-10000) → setState + recalcul]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (route câblée app.dart:1366; initState → ReportPersistenceService.markSimulatorExplored('lamal'))

## LandingScreen (`apps/mobile/lib/screens/landing_screen.dart`)
- boutons/actions:
  - [wordmark « MINT » (GestureDetector onLongPress, affordance cachée D-12) → context.go('/auth/login')]
  - [landingV2CtaSober (FilledButton) → context.go('/start')]
  - [landingV2LoginLink (GestureDetector) → context.go('/auth/login')]
  - [landingV3AnonymousHomeLink (GestureDetector) → context.go('/start')]
- champs: aucun
- nav sortantes: context.go('/start') ×2 ; context.go('/auth/login') ×2
- orphelin/façade: NON (route câblée app.dart:509 + fallback auth app.dart:685)

## EplScreen (`apps/mobile/lib/screens/lpp_deep/epl_screen.dart`)
- boutons/actions:
  - [safePop (IconButton) → safePop(context)]
  - [eplLabelAvoirTotal (slider 0-800k) → setState + EplSimulator.simulate]
  - [eplLabelAge (slider 25-65) → setState + recalcul]
  - [eplLabelMontantSouhaite (slider 20k-500k) → setState + _writeBackResult (write-back séquence)]
  - [eplLabelCanton (DropdownButton) → setState + recalcul]
  - [eplLabelRachatsRecents (Switch) → setState (reset années si off)]
  - [eplLabelAnneesSDepuisRachat (slider 0-5, conditionnel) → setState]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (route câblée app.dart:1047; contexte séquence runId/stepId via GoRouter.extra)

## LibrePassageScreen (`apps/mobile/lib/screens/lpp_deep/libre_passage_screen.dart`)
- boutons/actions:
  - [safePop (IconButton) → safePop(context)]
  - [librePassageChipChangementEmploi / DepartSuisse / CessationActivite (ChoiceChips) → setState _statut + LibrePassageAdvisor.analyze]
  - [librePassageLabelAge (MintPremiumSlider 18-65) → setState]
  - [librePassageLabelAvoir (MintPremiumSlider 0-500k) → setState]
  - [librePassageLabelNouvelEmployeur (Switch) → setState]
  - [librePassageCentrale2eTitle (InkWell) → launchUrl(https://www.sfbvg.ch) externe]
- champs: aucun
- nav sortantes: aucune (lien externe url_launcher uniquement)
- orphelin/façade: NON (route câblée app.dart:1127). Remarque : les LppTransferOption du LppRescueWidget ont labels/descriptions FR hardcodés (violation i18n, pas un bouton mort)
 
## RachatEchelonneScreen (`apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart`)
- boutons/actions:
  - [rachatEchelonneAvoirActuel (slider) → _onInputChanged + RachatEchelonneSimulator.compare]
  - [rachatEchelonneRachatMax (slider) → recalcul]
  - [canton (DropdownButton) → recalcul (TaxEstimatorService.estimateMarginalTaxRate)]
  - [rachatEchelonneRevenuImposable (slider 50k-300k) → recalcul]
  - [chips état civil single/married (GestureDetector) → recalcul]
  - [info taux marginal (InkWell) → _showTauxMarginalInfo → ouvre showModalBottomSheet (rachatEchelonneTauxMarginalTitle/Body)]
  - [rachatEchelonneAjuster (TextButton.icon) → setState _manualTauxOverride=true]
  - [taux manuel (MintCompactSlider 10-45%) → recalcul]
  - [rachatEchelonneAuto (TextButton) → setState _manualTauxOverride=false + recalcul]
  - [rachatEchelonneHorizon (slider 1-25 ans) → recalcul]
- champs: aucun TextEditingController — inputs: _avoirActuel, _rachatMax, _revenu, _horizon, _canton, _civilStatus, _manualTaux
- nav sortantes: aucune
- orphelin/façade: NON (route câblée app.dart:1027; ReportPersistenceService.markSimulatorExplored('lpp_deep')). Remarque : _cantonNames FR hardcodés (i18n)

## MariageScreen (`apps/mobile/lib/screens/mariage_screen.dart`)
- boutons/actions:
  - [safePop (IconButton) → safePop(context)]
  - [TabBar 4 onglets (Impôts / Régime / Protection / Checklist) → TabController]
  - [mariageRevenu1 / mariageRevenu2 (MintAmountField 0-300k) → setState + FamilyService.compareFiscalMariage]
  - [canton (DropdownButton) → recalcul]
  - [mariageEnfants (stepper +/- 0-5) → recalcul]
  - [cartes régime matrimonial participation/séparation/communauté (GestureDetector) → setState _selectedRegime]
  - [mariagePatrimoine1 / mariagePatrimoine2 (MintAmountField 0-1M) → setState (pie chart)]
  - [mariageLppRenteLabel (MintAmountField 0-8000) → setState]
  - [checklist items (GestureDetector ×2 : expand + check) → setState local]
- champs: aucun TextEditingController — inputs: _revenu1, _revenu2 (hypothèse D9), _canton, _nbEnfants, _patrimoine1, _patrimoine2, _renteLpp
- nav sortantes: aucune
- orphelin/façade: NON (route câblée app.dart:1265; prefill CoachProfileProvider)

## MonArgentScreen (`apps/mobile/lib/screens/mon_argent/mon_argent_screen.dart`)
- boutons/actions:
  - [person_outline (IconButton AppBar) → MintShell.openDrawer(context)]
  - [_MonArgentSectionSelector (SegmentedButton 5 sections today/month/wealth/pension/future) → setState _section]
  - [onBudgetTap → context.push('/budget')]
  - [onBudgetRetry → _loadBudget (BudgetProvider.hydrateFromProfileState)]
  - [onBudgetSetup → context.push('/budget/setup')]
  - [onPatrimoineTap → context.push('/profile/bilan')]
  - [onPatrimoineScan → context.push('/scan')]
  - [onPatrimoineAmountTap(topic) → context.go('/coach/chat?topic=$topic')]
  - [coach whisper (GestureDetector) → context.go('/coach/chat?topic=budget')]
  - [monArgentEnrichCta (GestureDetector) → context.push('/scan')]
  - [pull-to-refresh → _loadBudget]
- champs: aucun
- nav sortantes: context.push('/budget') ; context.push('/budget/setup') ; context.push('/profile/bilan') ; context.push('/scan') ×2 ; context.go('/coach/chat?topic=…') ×2
- orphelin/façade: NON (route câblée app.dart:699, initialSection en query param)

## AffordabilityScreen (`apps/mobile/lib/screens/mortgage/affordability_screen.dart`)
- boutons/actions:
  - [canton (DropdownButton) → setState + _writeBackResult (write-back séquence)]
  - [affordabilityGrossIncome (MintAmountField+badge prefill 50k-300k) → setState + _writeBackResult]
  - [affordabilityTargetPrice (MintAmountField 200k-3M) → setState]
  - [affordabilityAvailableSavings (MintAmountField 0-500k) → setState]
  - [affordabilityAdvancedParams (GestureDetector) → setState toggle disclosure 3a/LPP]
  - [affordabilityPillar3a / affordabilityPillarLpp (MintAmountField, conditionnels) → setState]
  - [affordabilityRelatedSimulate → context.push('/mortgage/amortization')]
  - [affordabilityRelatedCompare → context.push('/mortgage/saron-vs-fixed')]
  - [affordabilityRelatedCalculate → context.push('/mortgage/imputed-rental')]
  - [affordabilityRelatedSimulate (EPL) → context.push('/mortgage/epl-combined')]
- champs: aucun TextEditingController — 5 amount fields + 1 dropdown (prefill CoachProfile: revenu ménage, LPP, épargne, canton)
- nav sortantes: context.push('/mortgage/amortization') ; context.push('/mortgage/saron-vs-fixed') ; context.push('/mortgage/imputed-rental') ; context.push('/mortgage/epl-combined')
- orphelin/façade: NON (route câblée app.dart:1183; ReportPersistenceService.markSimulatorExplored('mortgage'))

## AmortizationScreen (`apps/mobile/lib/screens/mortgage/amortization_screen.dart`)
- boutons/actions:
  - [amortizationMortgageAmount (slider 200k-2M) → setState + AmortizationCalculator.compare (getter)]
  - [amortizationInterestRate (slider 1-5%) → setState]
  - [amortizationDuration (slider 5-30 ans) → setState]
  - [amortizationMarginalRate (slider 15-45%) → setState]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (route câblée app.dart:1196; prefill mortgageBalance profil)

## EplCombinedScreen (`apps/mobile/lib/screens/mortgage/epl_combined_screen.dart`)
- boutons/actions:
  - [canton (DropdownButton) → setState + EplCombinedCalculator.calculate (getter)]
  - [eplCombinedTargetPrice (slider 200k-3M) → setState]
  - [eplCombinedCashSavings (slider 0-500k) → setState]
  - [eplCombinedAvoir3a (slider 0-300k) → setState]
  - [eplCombinedAvoirLpp (slider 0-500k) → setState]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (route câblée app.dart:1201; prefill épargne/3a/LPP profil)

## ImputedRentalScreen (`apps/mobile/lib/screens/mortgage/imputed_rental_screen.dart`)
- boutons/actions:
  - [canton (DropdownButton) → setState + ImputedRentalCalculator.calculate (getter)]
  - [imputedRentalPropertyValue (slider 200k-3M) → setState]
  - [imputedRentalAnnualInterest (slider 0-80k) → setState]
  - [imputedRentalEffectiveMaintenance (slider 0-30k) → setState]
  - [imputedRentalOldProperty (Switch bien ancien/récent) → setState]
  - [imputedRentalMarginalRate (slider 15-45%) → setState]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (route câblée app.dart:1206; taux marginal estimé via RetirementTaxCalculator.estimateMarginalRate depuis profil)

## SaronVsFixedScreen (`apps/mobile/lib/screens/mortgage/saron_vs_fixed_screen.dart`)
- boutons/actions:
  - [saronVsFixedMortgageAmount (slider 200k-2M) → setState + SaronVsFixedCalculator.compare (getter)]
  - [saronVsFixedDuration (DropdownButton 5/7/10/15 ans) → setState]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (route câblée app.dart:1211; prefill mortgageBalance profil)

## NaissanceScreen (`apps/mobile/lib/screens/naissance_screen.dart`)
- boutons/actions:
  - [safePop (IconButton) → safePop(context)]
  - [TabBar 4 onglets (Congé / Allocations / Impact / Checklist) → TabController]
  - [naissanceMother / naissanceFather (SegmentedButton) → setState + FamilyService.simulateCongeParental]
  - [naissanceMonthlySalary (MintAmountField 2000-15000) → recalcul congé]
  - [canton allocations (DropdownButton) → FamilyService.estimateAllocations + getAllocationsRanking]
  - [naissanceNbEnfants (stepper +/- 1-5, onglets Allocations et Impact) → recalcul / setState]
  - [naissanceRevenuAnnuel (MintAmountField 30k-200k) → setState]
  - [naissanceFraisGarde (MintAmountField 0-3000) → setState]
  - [checklist items (GestureDetector ×2 : expand + check) → setState local]
- champs: aucun TextEditingController — inputs: _isMother, _salaireMensuel, _cantonAlloc, _nbEnfantsAlloc, _revenuImpact, _nbEnfantsImpact, _fraisGarde
- nav sortantes: aucune
- orphelin/façade: NON (route câblée app.dart:1270; prefill profil)

## DataBlockEnrichmentScreen (`apps/mobile/lib/screens/onboarding/data_block_enrichment_screen.dart`)
- boutons/actions:
  - [arrow_back (IconButton) → safePop(context, fallbackRoute: MintNav.onboardingFallbackRoute)]
  - [_CoachModeToggle chip « coach » → context.go('/coach/chat?topic=<blockType>') (désactivé si SlmProvider.isEngineAvailable == false) ; chip « formulaire » → setState _showCoachMode=false]
  - [meta.ctaLabel (FilledButton, blocs ≠ situation) → context.push(_enrichmentRoute(type)) — mapping : revenu→'/coach/chat', lpp→'/scan', avs→'/document-scan/avs-guide', 3a→'/pilier-3a', patrimoine→'/profile/bilan', fiscalite→'/fiscal', objectifRetraite→'/retraite', compositionMenage→'/couple', défaut→'/profile/bilan' ; fallback safePop si null]
  - [dataBlockSituationSaveCta (FilledButton, bloc situation) → _saveSituation → CoachProfileProvider.mergeAnswers + ReportPersistenceService]
- champs:
  - _birthYearController (TextField année de naissance)
  - _cantonController (TextField canton)
  - _netIncomeController (TextField revenu net, numérique)
  - _cashController (TextField liquidités, numérique)
  - _debtPaymentController (TextField mensualité dette, numérique)
- nav sortantes: context.go('/coach/chat?topic=…') ; context.push vers '/coach/chat' | '/scan' | '/document-scan/avs-guide' | '/pilier-3a' | '/profile/bilan' | '/fiscal' | '/retraite' | '/couple'
- orphelin/façade: NON (route câblée app.dart:1829, blockType en param; CrossValidationService branché)

## OnboardingDiscreteAdjustControl (`apps/mobile/lib/screens/onboarding/mvp_wedge/discrete_adjust_control.dart`)
- (helper, pas un écran) — contrôle +/- réutilisable (onDecrement/onIncrement fournis par le parent, boutons désactivés via `enabled`)

## DossierStrip (`apps/mobile/lib/screens/onboarding/mvp_wedge/dossier_strip.dart`)
- (helper, pas un écran) — bande « Ton dossier » lisant OnboardingProvider.dossier, aucune action utilisateur

## OnboardingProvider (`apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_provider.dart`)
- (helper, pas un écran) — ChangeNotifier de la machine à étapes MVP wedge (advance/setIntent/setCanton/…, flush vers CoachProfile)

## OnboardingShellScreen (`apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart`)
- boutons/actions:
  - [diagnosticOnboardingEntryCta (_PrimaryButton, step entry) → provider.advance()]
  - [_IntentCard ×4 (retraite/achat/impots/explorer) → provider.setIntent + advance]
  - [_Mint2AxisCard (variante feature flag) → provider.setAxisV2 ; axe lppRenteCapital → persistMint2AxisHandoff + AuthProvider.enableLocalMode + context.go('/retraite/rente-vs-capital')]
  - [mint2FirstExperienceLppLabel (_PrimaryButton conditionnel) → même chemin _openLiveAxis]
  - [UsTaxPersonScreen onAnswered → si US tax person : context.go('/waitlist', extra: WaitlistArgs(archetype:'expat_us')) sinon provider.advance()]
  - [nationalitySuisse/EuAele/Autre (OnboardingChoiceButton ×3) → provider.setNationality + advance]
  - [MintSceneStatutEmploi onAnswered → setEmploymentStatus + advance]
  - [MintSceneEtatCivil onAnswered → setCivilStatus + advance]
  - [MintSceneLacunesAvs onAnswered → setAvsLacunes + advance]
  - [date de naissance (OutlinedButton) → _pickDate (date picker) ; « Continuer » (_PrimaryButton) → setDateOfBirth + advance (désactivé tant que null)]
  - [grille cantons 26 (InkWell) → setCanton + advance]
  - [revenu : OnboardingDiscreteAdjustControl +/- (pas 500) → setState ; « Continuer » → setNetMonthlyRange + advance ; « Je sais le chiffre exact » (TextButton) → setState _exactMode=true ; « Continuer » exact → setNetMonthlyExact + advance (désactivé si invalide) ; « Revenir à la fourchette » (TextButton) → setState _exactMode=false]
  - [« Voir » (_PrimaryButton, step insight) → provider.advance()]
  - [« Continuer » (step scene) → provider.advance()]
  - [diagnosticOnboardingTerminalContinueAction → _sealAndGo(deeper:true) → completeAndFlushToProfile puis router.go(route par intent : retraite→'/retraite/rente-vs-capital', achat→'/hypotheque', impots→'/pilier-3a', explorer→'/explore')]
  - [diagnosticOnboardingTerminalCreateAccountAction → _sealAndGo → router.go('/auth/register')]
  - [diagnosticOnboardingTerminalResetAction → provider.resetDiagnostic()]
  - [diagnosticOnboardingTerminalExitAction → _sealAndGo → router.go('/home')]
  - [onboardingSealRetry (SnackBarAction en cas d'échec seal) → retry _sealAndGo]
- champs: _exactController (TextField revenu net mensuel exact, numérique, _RevenueStep)
- nav sortantes: context.go('/waitlist') ; context.go('/retraite/rente-vs-capital') ; router.go('/retraite/rente-vs-capital' | '/hypotheque' | '/pilier-3a' | '/explore' | '/auth/register' | '/home')
- orphelin/façade: NON (route câblée app.dart:525). Remarque : plusieurs libellés hardcodés FR ('Continuer', 'Voir', 'Quelle est ta date de naissance ?', 'Où tu vis ?', 'Je sais le chiffre exact', phrases bifurcation) — violation i18n, mais boutons vivants

---

**Bilan segment C** : 29 écrans + 3 helpers (mvp_wedge). 0 orphelin de route (29/29 câblés dans `app.dart`), 0 bouton mort (`onPressed: null` uniquement en désactivation conditionnelle légitime : loading/sealing/validation). Signaux annexes (hors périmètre orphelin) : i18n hardcodée dans onboarding_shell_screen, libre_passage_screen (LppTransferOption), rachat_echelonne_screen (_cantonNames).
