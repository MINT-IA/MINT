# Route Map — Segment B (seg_ab, 32 fichiers)

Extraction mécanique 2026-07-23. Routage vérifié contre `apps/mobile/lib/app.dart` (GoRouter unique). Toutes les classes écran ci-dessous sont référencées 1x dans `app.dart` SAUF `DocumentStreamResultScreen` (0 référence).

## RetirementDashboardScreen (`apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart`)
- boutons/actions:
  - [narrative card `dashboardCockpitCta` → context.push('/retraite')]
  - [OutlinedButton `dashboardMyData` (key projection_review_cta) → context.push('/profile/bilan')]
  - [FilledButton `commonRetry` (key projection_retry_cta) → _retryProjection() (recalcul local setState)]
  - [IconButton edit_note (AppBar, tooltip `dashboardMyData`) → context.push('/profile/bilan')]
  - [items sheet enrichissement → Navigator.pop + context.push('/data-block/${p.category}')]
  - [FilledButton `dashboardOnboardingCta` (key state_c_start_cta) → context.go('/onb')]
  - [carte éducative `dashboardEducationTitle` → context.push('/education/hub')]
  - [section CTA `dashboardCockpitCta` → context.push('/retraite')]
  - [section CTA `dashboardRenteVsCapitalCta` → context.push('/retraite/rente-vs-capital')]
  - [section CTA `dashboardRachatLppCta` → context.push('/rachat-lpp')]
  - [lien `dataOriginModify` → context.push('/profile')]
  - [lien `disclaimerLearnMore` → ouvre bottom sheet disclaimer complet]
  - [hero `onConfidenceTap` → ouvre sheet enrichissement (_showEnrichmentSheet)]
  - [_UrgentBanner → context.push(item.deeplink) (dynamique)]
  - [_ActionCard → context.push(card.deeplink!) si deeplink non null, sinon onTap null]
  - [_DataEnrichmentCard → context.push('/data-block/${prompt.category}')]
- champs: aucun
- nav sortantes: /retraite · /profile/bilan · /data-block/${category} (dynamique) · /onb (go) · /education/hub · /retraite/rente-vs-capital · /rachat-lpp · /profile · deeplinks dynamiques (TemporalItem.deeplink, CuratedCard.deeplink)
- orphelin/façade: NON

## SuccessionPatrimoineScreen (`apps/mobile/lib/screens/coach/succession_patrimoine_screen.dart`)
- boutons/actions: aucun (écran éducatif statique ; widgets internes TestamentInvisibleWidget / AvancementHoirieWidget / DeathUrgencyGuideWidget / EduSpecialistCta sans nav dans ce fichier)
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON

## ConcubinageScreen (`apps/mobile/lib/screens/concubinage_screen.dart`)
- boutons/actions:
  - [back arrow AppBar → safePop(context)]
  - [3 tabs `concubinageTabComparateur`/`concubinageTabProtection`/`concubinageTabChecklist` → TabController local]
  - [MintAmountField `concubinageRevenu1` → setState + _recalculate() (FamilyService.compareMariageVsConcubinage)]
  - [MintAmountField `concubinageRevenu2` → idem]
  - [MintAmountField `concubinagePatrimoineTotal` → idem]
  - [Dropdown `concubinageCanton` → setState + _recalculate()]
  - [MintAmountField `concubinageProtectionLppSlider` → setState local]
  - [items checklist (tap ligne) → toggle _expandedItems setState local]
  - [checkbox checklist → toggle _checkedItems setState local + HapticFeedback]
- champs:
  - [_revenu1 (MintAmountField, double)]
  - [_revenu2 (MintAmountField, double)]
  - [_patrimoine (MintAmountField, double)]
  - [_canton (DropdownButton<String>)]
  - [_renteLpp (MintAmountField, double)]
- nav sortantes: aucune
- orphelin/façade: NON

## ConfidenceDashboardScreen (`apps/mobile/lib/screens/confidence/confidence_dashboard_screen.dart`)
- boutons/actions:
  - [back arrow AppBar → safePop(context)]
  - [cartes enrichment prompts (top 3, label = prompt.action) → onTap VIDE — commentaire « Navigation will be wired per method in a future sprint »]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: OUI (partiel) — écran câblé à une route dans app.dart, MAIS les 3 cartes d'enrichissement (section 4) ont un `onTap: () {}` mort avec TODO explicite (`confidence_dashboard_screen.dart:349-351`)

## ConsumerCreditSimulatorScreen (`apps/mobile/lib/screens/consumer_credit_screen.dart`)
- boutons/actions:
  - [slider `creditMontantEmprunter` → _calculate() setState local]
  - [slider `creditDureeRemboursement` → idem]
  - [slider `creditTauxAnnuel` → idem (warning si ≥ 10%)]
  - [DebtToolsNav(currentRoute: '/simulator/credit') → nav croisée dettes (widget commun)]
  - [AppBar actions: const [] — export PDF masqué, « stub not yet implemented » (commentaire ligne 83)]
- champs: aucun (sliders uniquement)
- nav sortantes: aucune (dans ce fichier ; DebtToolsNav est un widget externe)
- orphelin/façade: NON (l'export PDF est masqué, pas un bouton mort visible)

## CoverageCheckScreen (`apps/mobile/lib/screens/coverage_check_screen.dart`)
- boutons/actions:
  - [back arrow AppBar → safePop(context)]
  - [chips statut `coverageCheckSalarie`/`coverageCheckIndependant`/`coverageCheckSansEmploi` → setState + _compute() (CoverageCheckService.evaluateCoverage)]
  - [switch `coverageCheckHypotheque` → _compute()]
  - [switch `coverageCheckPersonnesCharge` → _compute()]
  - [switch `coverageCheckLocataire` → _compute()]
  - [switch `coverageCheckVoyages` → _compute()]
  - [7 switches couverture `coverageCheckIjm`/`coverageCheckLaa`/`coverageCheckRcPrivee`/`coverageCheckMenage`/`coverageCheckProtJuridique`/`coverageCheckVoyage`/`coverageCheckDeces` → _compute()]
- champs: aucun (toggles/chips uniquement)
- nav sortantes: aucune
- orphelin/façade: NON

## DebtRatioScreen (`apps/mobile/lib/screens/debt_prevention/debt_ratio_screen.dart`)
- boutons/actions:
  - [steppers -/+ `debtRatioRevenuNet` / `debtRatioChargesDette` / `debtRatioLoyer` / `debtRatioAutresCharges` → setState local]
  - [tap valeur → ouvre bottom sheet _showValueEditor (saisie clavier)]
  - [FilledButton `debtRatioValidate` (sheet) → applique valeur + Navigator.pop]
  - [toggle `debtRatioRefineLabel` → setState _showDetails]
  - [toggle `debtRatioSeul`/`debtRatioEnCouple` → setState local]
  - [pills `debtRatioEnfants` (0-4+) → setState local]
  - [CTA `debtRatioCtaRouge`/`debtRatioCtaOrange` → context.push('/debt/repayment')]
  - [lien `debtRatioDetteConseilNom` → launchUrl https://www.dettes.ch]
  - [lien `debtRatioCaritasNom` → launchUrl https://www.caritas.ch/dettes]
  - [DebtToolsNav(currentRoute: '/debt/ratio')]
- champs:
  - [controller (TextEditingController dans _showValueEditor, TextField numérique)]
- nav sortantes: /debt/repayment
- orphelin/façade: NON (émet aussi ScreenReturn completed/abandoned sur route /debt/ratio)

## HelpResourcesScreen (`apps/mobile/lib/screens/debt_prevention/help_resources_screen.dart`)
- boutons/actions:
  - [OutlinedButton `helpResourceSiteWeb` (x2 : Dettes Conseils, Caritas) → launchUrl externe]
  - [FilledButton téléphone (0800 40 40 40 / 0800 708 708) → launchUrl tel:]
  - [Dropdown `helpResourcesCantonLabel` → setState _canton]
  - [carte ressource cantonale → launchUrl cantonalResource.url]
  - [DebtToolsNav(currentRoute: '/debt/help')]
- champs: aucun
- nav sortantes: aucune (liens externes uniquement)
- orphelin/façade: NON

## RepaymentScreen (`apps/mobile/lib/screens/debt_prevention/repayment_screen.dart`)
- boutons/actions:
  - [back arrow AppBar → safePop(context)]
  - [IconButton add_circle (tooltip `repaymentAddDebtTooltip`) → _addDebt() setState]
  - [bouton croix (semantics `semanticsRepaymentDeleteDebt`) → supprime dette setState]
  - [champs inline `repaymentFieldAmount`/`repaymentFieldRate`/`repaymentFieldInstallment` → ouvre bottom sheet _showValueEditor]
  - [FilledButton `repaymentValidate` (sheet) → applique + Navigator.pop]
  - [carte budget (semantics `semanticsRepaymentBudget`) → ouvre _showValueEditor budget]
  - [DebtToolsNav(currentRoute: '/debt/repayment')]
- champs:
  - [TextFormField nom de dette (inline, hint `repaymentDebtNameHint`)]
  - [controller (TextEditingController dans _showValueEditor, TextField numérique)]
- nav sortantes: aucune (ScreenReturn émis sur route /debt/repayment)
- orphelin/façade: NON

## DebtRiskCheckScreen (`apps/mobile/lib/screens/debt_risk_check_screen.dart`)
- boutons/actions:
  - [6x2 boutons choix `debtCheckYes`/`debtCheckNo` (questionnaire) → setState local]
  - [FilledButton `debtCheckAnalyzeButton` → _calculateScore() (calculateDebtRiskScore) ; désactivé (null) tant que 6 réponses incomplètes]
  - [FilledButton.icon `debtCheckValidateButton` → safePop(context)]
  - [OutlinedButton `debtCheckRedoButton` → setState _showResults=false]
  - [OutlinedButton `debtCheckGamblingSupportCta` → launchUrl https://www.sos-jeu.ch/]
  - [DebtToolsNav(currentRoute: '/check/debt')]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (onPressed null = état désactivé volontaire, pas mort)

## DebugBudgetBootstrapScreen (`apps/mobile/lib/screens/debug/debug_budget_bootstrap_screen.dart`)
- boutons/actions:
  - [aucun bouton — au build: persiste BudgetInputs via BudgetLocalStore().saveInputs puis affiche label E2E `e2e_budget_fixture_applied` ou rend BudgetScreen(inputs) si renderBudget]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (écran fixture E2E/debug, câblé via app.dart)

## DebugMint2AccountClaimScreen (`apps/mobile/lib/screens/debug/debug_mint2_account_claim_screen.dart`)
- boutons/actions:
  - [aucun bouton — au build: exécute _run() (AccountHandoffService.saveChoice/prepareLocalDataForAccount, AuthService.saveToken, SharedPreferences) et affiche statuts E2E `e2e_mint2_axis_claim_*`]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (écran fixture E2E/debug, no-op en release — kReleaseMode → 'unavailable')

## DebugProfileBootstrapScreen (`apps/mobile/lib/screens/debug/debug_profile_bootstrap_screen.dart`)
- boutons/actions:
  - [aucun bouton — au build: DebugProfileBootstrapService.persistFixture + AuthProvider.enableLocalMode(), affiche label E2E `e2e_profile_fixture_applied`]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (écran fixture E2E/debug, câblé via app.dart)

## DecesProcheScreen (`apps/mobile/lib/screens/deces_proche_screen.dart`)
- boutons/actions:
  - [SegmentedButton `decesProcheLienConjoint`/`decesProcheLienParent`/`decesProcheLienEnfant` → setState _lienParente]
  - [MintPremiumSlider `decesProcheFortune` → setState local]
  - [Dropdown `decesProcheCanton` (10 cantons hardcodés) → setState local]
  - [SwitchListTile `decesProchTestament` → setState _testamentExiste]
- champs: aucun (sliders/dropdown/switch)
- nav sortantes: aucune
- orphelin/façade: NON

## DemenagementCantonalScreen (`apps/mobile/lib/screens/demenagement_cantonal_screen.dart`)
- boutons/actions:
  - [Dropdown `demenagementCantonDepart` → setState local]
  - [Dropdown `demenagementCantonArrivee` → setState local]
  - [MintPremiumSlider `demenagementRevenu` → setState local]
  - [SegmentedButton `demenagementCelibataire`/`demenagementMarie` → setState local]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (nota: la « checklist déménagement » est purement décorative — icônes check_box_outline_blank statiques sans onTap, non cochables)

## DisabilityGapScreen (`apps/mobile/lib/screens/disability/disability_gap_screen.dart`)
- boutons/actions:
  - [slider `disabilityGrossMonthly` → setState + _emitScreenReturn()]
  - [slider `disabilityYourAge` → idem]
  - [slider `disabilityAvailableSavings` → idem]
  - [Switch `disabilityHasIjm` → idem]
  - [OutlinedButton `disabilityCtaEvaluate` → context.push('/disability/insurance')]
  - [OutlinedButton `disabilityCtaAnalyze` → context.push('/disability/self-employed')]
- champs: aucun (sliders/switch)
- nav sortantes: /disability/insurance · /disability/self-employed
- orphelin/façade: NON

## DisabilityInsuranceScreen (`apps/mobile/lib/screens/disability/disability_insurance_screen.dart`)
- boutons/actions:
  - [slider `disabilityInsGrossSalary` → setState local]
  - [slider `disabilityInsSavings` → setState local]
  - [toggle `disabilityInsIjmEmployer` → setState local]
  - [toggle `disabilityInsPrivateLossInsurance` → setState local]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (nota: labels scorecard hardcodés FR — 'IJM / Perte de gain', 'AI fédérale', etc., lignes 60-115, hors i18n)

## DisabilitySelfEmployedScreen (`apps/mobile/lib/screens/disability/disability_self_employed_screen.dart`)
- boutons/actions:
  - [slider `disabilitySelfEmployedRevenueLabel` → setState local]
  - [chips `disabilitySelfEmployedYes`/`disabilitySelfEmployedNo` (assurance perte de gain) → setState _hasPerteDegain]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON

## DivorceSimulatorScreen (`apps/mobile/lib/screens/divorce_simulator_screen.dart`)
- boutons/actions:
  - [MintPickerTile `divorceDureeMariage` → setState local]
  - [MintPickerTile `divorceNbEnfants` → setState local]
  - [chips régime `divorceParticipationDefault`/`divorceCommunaute`/`divorceSeparation` → setState _regime]
  - [MintAmountField `divorceConjoint1Revenu` / `divorceConjoint2Revenu` → setState local]
  - [MintAmountField `divorceLppConjoint1` / `divorceAvoirAuMariage1` / `divorceLppConjoint2` / `divorceAvoirAuMariage2` / `divorce3aConjoint1` / `divorce3aConjoint2` → setState local]
  - [MintAmountField `divorceFortune` / `divorceDettes` → setState local]
  - [FilledButton.icon `divorceSimuler` → _simulate() (DivorceService.simulate) + scroll vers résultats]
  - [items checklist → toggle _checklistState setState local]
  - [2 ExpansionTile éducatifs `divorceEduParticipationTitle`/`divorceEduLppTitle` → expand local]
- champs: aucun (MintAmountField/pickers, pas de TextEditingController direct)
- nav sortantes: aucune
- orphelin/façade: NON

## DocumentDetailScreen (`apps/mobile/lib/screens/document_detail_screen.dart`)
- boutons/actions:
  - [back arrow AppBar → safePop(context)]
  - [FilledButton `documentsConfirmButton` → SnackBar `documentDetailProfileUpdated` + safePop(context)]
  - [TextButton.icon `documentsDeleteButton` → dialog _confirmDelete → docProvider.deleteDocument(documentId) + safePop]
  - [dialog: TextButton `documentDetailCancelButton` / FilledButton `documentsDeleteButton` → Navigator.pop(bool)]
- champs: aucun
- nav sortantes: aucune (pops uniquement)
- orphelin/façade: NON (nota: contenu affiché seulement si `docProvider.lastUploadResult.id == documentId`, sinon placeholder `documentsEmpty` — le détail d'un document historique n'est pas rechargeable)

## AvsGuideScreen (`apps/mobile/lib/screens/document_scan/avs_guide_screen.dart`)
- boutons/actions:
  - [back arrow AppBar → safePop(context)]
  - [FilledButton.icon `avsGuideOpenAhvButton` → launchUrl https://www.ahv-iv.ch (SnackBar erreur sinon)]
  - [OutlinedButton.icon `avsGuideScanButton` → context.push('/scan', extra: DocumentType.avsExtract)]
  - [FilledButton.icon `avsGuideTestButton` (kDebugMode only) → parse sample AVS + context.push('/scan/review', extra: result)]
- champs: aucun
- nav sortantes: /scan (extra DocumentType.avsExtract) · /scan/review (extra ExtractionResult, debug)
- orphelin/façade: NON

## DocumentImpactScreen (`apps/mobile/lib/screens/document_scan/document_impact_screen.dart`)
- boutons/actions:
  - [FilledButton.icon `docImpactReturnDashboard` → ScreenCompletionTracker.markCompletedWithReturn('/scan/impact') + context.go('/coach/chat')]
  - [OutlinedButton.icon `scanInsightCta` (si delta > 5) → context.go('/coach/chat')]
  - [au build: DocumentService.fetchPremierEclairage (backend) + CoachMemoryService.saveEvent (persistance scan)]
- champs: aucun
- nav sortantes: /coach/chat (go, x2)
- orphelin/façade: NON

## DocumentScanScreen (`apps/mobile/lib/screens/document_scan/document_scan_screen.dart`)
- boutons/actions:
  - [back arrow AppBar → safePop(context)]
  - [ChoiceChips type de document (4 types supportés) → setState _selectedType]
  - [FilledButton `documentScanTakePhoto` (web: `documentScanImportFile`) → ConsentService gate → NativeDocumentScanner.scan → _processImageFile → context.push('/scan/review', extra: visionResult)]
  - [OutlinedButton `docScanFromGallery` → ConsentService gate → FilePicker → image/pdf/txt pipeline → context.push('/scan/review', extra: result)]
  - [TextButton `docScanPasteOcrText` → bottom sheet saisie OCR manuelle → _processOcrText → context.push('/scan/review', extra: result)]
  - [OutlinedButton `docScanUseExample` (kDebugMode only) → parse texte exemple → /scan/review]
  - [sheet OCR: OutlinedButton `documentScanCancel` / FilledButton `documentScanAnalyze` → ctx.pop(bool)]
  - [sheet PDF fallback: FilledButton `documentScanTakePhoto` / OutlinedButton `documentScanPasteOcr`]
  - [sheet PDF auth requise: FilledButton `documentScanCreateAccount` → context.go('/auth/register') ; OutlinedButton `documentScanTakePhoto`]
  - [sheet récupération OCR: FilledButton `docScanVisionAnalyze` (si BYOK vision) → _processImageViaVision → /scan/review ; OutlinedButton `documentScanRetakePhoto` ; OutlinedButton `documentScanPasteOcr`]
- champs:
  - [controller (TextEditingController, TextField multiligne saisie OCR, hint `docScanOcrPasteHint`)]
- nav sortantes: /scan/review (push, x5 chemins avec extra ExtractionResult) · /auth/register (go)
- orphelin/façade: NON

## DocumentStreamResultScreen (`apps/mobile/lib/screens/document_scan/document_stream_result_screen.dart`)
- boutons/actions:
  - [IconButton close AppBar → safePop(context)]
  - [DocumentResultView onConfirm → safePop (persistance non câblée — commentaire « downstream screens will wire persistence »)]
  - [DocumentResultView onRetry → safePop]
  - [DocumentResultView onCommitmentAccepted → CommitmentService().acceptCommitment]
- champs: aucun
- nav sortantes: /scan/stream-result (via helper pushDocumentStreamResult — route CIBLE, pas sortante)
- orphelin/façade: OUI — classe référencée nulle part dans lib/ ni test/ (0 usage) ; la route '/scan/stream-result' visée par le helper `pushDocumentStreamResult` n'est PAS enregistrée dans app.dart ; helper jamais appelé ; titre 'Lecture du document' hardcodé FR ; onConfirm ne persiste rien (TODO Phase 29)

## ExtractionReviewScreen (`apps/mobile/lib/screens/document_scan/extraction_review_screen.dart`)
- boutons/actions:
  - [back arrow AppBar → safePop(context)]
  - [IconButton edit (tooltip `extractionReviewEditTooltip`) par champ → dialog édition valeur]
  - [dialog: TextButton `extractionReviewCancel` → ctx.pop() ; FilledButton `extractionReviewValidate` → maj champ setState + ctx.pop()]
  - [dialog couple `extractionWhoseDocument`: TextButton `extractionDocMine` / FilledButton `extractionDocPartner` → Navigator.pop(bool)]
  - [FilledButton.icon `docReviewConfirm` → _onConfirmAll: coachProvider.updateFrom*Extraction + biographyProvider.addFact + DocumentService.sendScanConfirmation (3 retries) + context.push('/scan/impact', extra: {result, previousConfidence})]
- champs:
  - [controller (TextEditingController dialog édition, TextField numérique `extractionReviewNewValue`)]
- nav sortantes: /scan/impact (push avec extra)
- orphelin/façade: NON

## DocumentsScreen (`apps/mobile/lib/screens/documents_screen.dart`)
- boutons/actions:
  - [back arrow AppBar → safePop(context)]
  - [IconButton info_outline → dialog info (vaultPrivacy)]
  - [FloatingActionButton `vaultUploadButton` → _showUploadTypeSheet (paywall si limite free 2 docs)]
  - [cartes catégories (grid 6 types) → _pickAndUpload(type) (FilePicker pdf → DocumentProvider.uploadDocument)]
  - [items sheet upload (6 catégories + `vaultCategoryOther`) → Navigator.pop + _pickAndUpload]
  - [item document (liste) → context.push('/documents/${doc.id}')]
  - [Dismissible swipe → dialog confirm → docProvider.deleteDocument]
  - [IconButton delete par item → idem]
  - [dialog delete: TextButton `vaultCancelButton` / FilledButton `vaultDeleteButton` → Navigator.pop(bool)]
  - [FilledButton `documentsConfirmButton` (résultat upload) → context.push('/documents/${result.id}')]
  - [FilledButton `vaultPremiumCta` (upsell) → safePop + CoachPaywallSheet.show(context)]
  - [MintEmptyState CTA `vaultUploadButton` → _showUploadTypeSheet]
  - [carte `bankImportTitle` → context.push('/bank-import')]
  - [IconButton close (carte erreur) → docProvider.clearError()]
- champs: aucun
- nav sortantes: /documents/${doc.id} (dynamique, x2) · /bank-import
- orphelin/façade: NON

## DonationScreen (`apps/mobile/lib/screens/donation_screen.dart`)
- boutons/actions:
  - [MintAmountField `donationMontantLabel` → setState local]
  - [chips lien de parenté (6 : conjoint/descendant/parent/fratrie/concubin/tiers) → setState local]
  - [Dropdown `donationCanton` → setState local]
  - [chips type donation (espèces/immobilier/titres — labels hardcodés FR) → setState local]
  - [MintAmountField `donationValeurImmobiliere` (si immobilier) → setState local]
  - [Switch `donationAvancementHoirie` → setState local]
  - [MintPickerTile `donationAgeLabel` / `donationNbEnfants` → setState local]
  - [MintAmountField `donationFortuneTotale` → setState local]
  - [chips régime matrimonial (3 — labels hardcodés FR) → setState local]
  - [FilledButton.icon `donationCalculer` → _simulate() (DonationService.calculate) + scroll résultats]
  - [items checklist → toggle setState local]
  - [3 ExpansionTile éducatifs → expand local]
- champs: aucun (MintAmountField/pickers)
- nav sortantes: aucune
- orphelin/façade: NON (nota: `_typesDonationLabels`, `_regimesLabels` et le disclaimer fallback sont des chaînes FR hardcodées, hors i18n — lignes 73-77, 88-92, 1000-1003)

## ComprendreHubScreen (`apps/mobile/lib/screens/education/comprendre_hub_screen.dart`)
- boutons/actions:
  - [BackButton AppBar → pop]
  - [cartes thèmes (EducationData.themes, label theme.title) → context.push('/education/theme/${theme.id}')]
- champs: aucun
- nav sortantes: /education/theme/${theme.id} (dynamique)
- orphelin/façade: NON

## ThemeDetailScreen (`apps/mobile/lib/screens/education/theme_detail_screen.dart`)
- boutons/actions:
  - [back arrow AppBar → safePop(context)]
  - [options quiz (A-D) → setState _selectedQuizAnswer/_quizAnswered (onTap null après réponse = désactivation volontaire)]
  - [ExpansionTile `themeDetailSourcesLegales` → expand local]
  - [FilledButton CTA `theme.actionLabel` (+ durée) → context.push(theme.route) (route dynamique du thème)]
  - [FilledButton fallback (thème sans contenu riche) → context.push(theme.route)]
- champs: aucun
- nav sortantes: theme.route (dynamique, x2 — dépend d'EducationalTheme)
- orphelin/façade: NON

## ExpatScreen (`apps/mobile/lib/screens/expat_screen.dart`)
- boutons/actions:
  - [back arrow AppBar → safePop(context)]
  - [3 tabs `expatTabForfait`/`expatTabDeparture`/`expatTabAvs` → TabController local]
  - [Dropdown `expatCanton` (cantons forfait éligibles) → _recalculateForfait()]
  - [MintAmountField `expatLivingExpenses` / `expatActualIncome` → _recalculateForfait()]
  - [TopCantonWidget onChildrenChanged → setState (si marié, sinon null = masqué volontairement)]
  - [date picker `expatDepartureDate` → showDatePicker + _recalculateDepart()]
  - [Dropdown `expatCurrentCanton` → _recalculateDepart()]
  - [MintAmountField `expatPillar3aBalance` / `expatLppBalance` → _recalculateDepart()]
  - [items checklist départ → toggle _completedChecklist setState local]
  - [MintPickerTile `expatYearsInSwitzerland` / `expatYearsAbroad` → _recalculateAvs()]
- champs: aucun (amount fields/pickers/date picker)
- nav sortantes: aucune
- orphelin/façade: NON (nota: nombreuses chaînes FR hardcodées dans ExpatDeadline/ExpatRight — labels, actions, impacts, lignes 661-755, hors i18n)

## ExploreHubScreen (`apps/mobile/lib/screens/explore/explore_hub_screen.dart`)
- boutons/actions:
  - [back arrow AppBar → MintNav.back(context)]
  - [ListTile par entrée (entry.label, données injectées par le routeur) → context.push(entry.route)]
- champs: aucun
- nav sortantes: entry.route (dynamique — 7 hubs instanciés dans app.dart)
- orphelin/façade: NON (écran générique paramétré, 7 instanciations dans app.dart)

## ExplorerScreen (`apps/mobile/lib/screens/explore/explorer_screen.dart`)
- boutons/actions:
  - [IconButton person_outline (identifier `ouvrir-profil-drawer`, label `semanticsOpenProfile`) → MintShell.openDrawer(context)]
  - [_HubCard `hubRetraite` → context.push('/explore/retraite')]
  - [_HubCard `hubFamille` → context.push('/explore/famille')]
  - [_HubCard `hubTravail` → context.push('/explore/travail')]
  - [_HubCard `hubLogement` → context.push('/explore/logement')]
  - [_HubCard `hubFiscalite` → context.push('/explore/fiscalite')]
  - [_HubCard `hubPatrimoine` → context.push('/explore/patrimoine')]
  - [_HubCard `hubSante` → context.push('/explore/sante')]
- champs: aucun
- nav sortantes: /explore/retraite · /explore/famille · /explore/travail · /explore/logement · /explore/fiscalite · /explore/patrimoine · /explore/sante
- orphelin/façade: NON (nota: titre AppBar 'Explorer' hardcodé, hors i18n — ligne 18)
