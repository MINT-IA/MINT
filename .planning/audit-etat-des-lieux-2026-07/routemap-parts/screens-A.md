# Route-map extraction — segment A (seg_aa, 32 fichiers)

Extraction mécanique (lecture intégrale de chaque fichier, SHA base 8d059e502). Routeur canonique : `apps/mobile/lib/app.dart` (GoRouter). « orphelin/façade » = classe non montée sur une route ET non montée indirectement par un autre écran.

## AboutScreen (`apps/mobile/lib/screens/about_screen.dart`)
- boutons/actions:
  - [aboutScreenCgu → launchUrl externe https://mint.swiss/cgu]
  - [aboutScreenPrivacy → launchUrl externe https://mint.swiss/privacy]
  - [aboutScreenDisclaimer → launchUrl externe https://mint.swiss/disclaimer]
  - [aboutScreenMentionsLegales → launchUrl externe https://mint.swiss/mentions-legales]
- champs: aucun
- nav sortantes: aucune (URLs externes uniquement)
- orphelin/façade: NON (monté sur `/about`, app.dart:1688)

## AdminGate (`apps/mobile/lib/screens/admin/admin_gate.dart`)
- (helper, pas un écran) — gate compile-time `ENABLE_ADMIN` + `FeatureFlags.isAdmin` pour les routes `/admin/*`.

## AdminShell (`apps/mobile/lib/screens/admin/admin_shell.dart`)
- (helper, pas un écran autonome) — scaffold wrapper dev-only (AppBar « MINT Admin ») entourant les enfants `/admin/*` dans app.dart; aucun bouton, aucun champ, aucune nav.

## MintDebugSpineScreen (`apps/mobile/lib/screens/admin/mint_debug_spine_screen.dart`)
- boutons/actions:
  - ['Reset profile stores' (hardcodé EN, dev-only) → appel service MintDebugSpineService.resetProfileStores + setState]
  - ['Refresh snapshot' (hardcodé EN) → appel service MintDebugSpineService.loadSnapshot + setState]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (monté sur `/admin/debug-spine` via AdminShell, app.dart:1709; gated ENABLE_ADMIN)

## MintDebugToolsGate (`apps/mobile/lib/screens/admin/mint_debug_tools_gate.dart`)
- (helper, pas un écran) — gate compile-time `ENABLE_DEBUG_TOOLS` + AdminGate + !kReleaseMode.

## RoutesRegistryScreen (`apps/mobile/lib/screens/admin/routes_registry_screen.dart`)
- boutons/actions:
  - [ExpansionTile par RouteOwner → expand/collapse local (setState implicite)]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (monté sur `/admin/routes` via AdminShell, app.dart:1699; gated ENABLE_ADMIN)

## AdminAnalyticsScreen (`apps/mobile/lib/screens/admin_analytics_screen.dart`)
- boutons/actions:
  - [ChoiceChip '7j'/'14j'/'30j'/'90j' → setState _days + appel service ApiService.get('/analytics/summary', '/analytics/funnel')]
  - [IconButton refresh (Semantics 'Rafraîchir' hardcodé) → _load (appels API idem)]
  - [adminAnalyticsRetry → _load]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (monté sur `/profile/admin-analytics`, app.dart:1546)

## AdminObservabilityScreen (`apps/mobile/lib/screens/admin_observability_screen.dart`)
- boutons/actions:
  - [SegmentedButton '7j'/'30j'/'90j' → setState _days + appels ApiService.getAdminObservability / getAdminOnboardingQuality / getAdminOnboardingQualityCohorts]
  - [adminObsExportCsv → appel service ApiService.exportAdminCohortsCsv + copie Clipboard + SnackBar]
  - [commonRetry → _load]
  - [RefreshIndicator pull → _load]
- champs: aucun
- nav sortantes: aucune
- orphelin/façade: NON (monté sur `/profile/admin-observability`, app.dart:1540)

## FinancialReportScreenV2 (`apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart`)
- boutons/actions:
  - [semanticsBackButton → context.pop() si canPop, sinon context.go('/mon-argent')]
  - [reportSharePdfSemantics (icône share) → appel service PdfService.generateFinancialReportPdf]
  - [financialReportEmptyCta (état vide) → context.go('/coach/chat')]
  - [reportCommencer (action prioritaire) → context.push(route par ActionCategory: '/budget' | '/pilier-3a' | '/rachat-lpp' | '/retraite' | '/fiscal' | '/assurances/lamal' | '/tools')]
- champs: aucun
- nav sortantes: context.go('/mon-argent'), context.go('/coach/chat'), context.push('/budget'), context.push('/pilier-3a'), context.push('/rachat-lpp'), context.push('/retraite'), context.push('/fiscal'), context.push('/assurances/lamal'), context.push('/tools')
- orphelin/façade: NON (monté sur `/rapport`, app.dart:1480 — 2 constructions selon `extra`)

## AnonymousChatScreen (`apps/mobile/lib/screens/anonymous/anonymous_chat_screen.dart`)
- boutons/actions:
  - [anonymousChatBack (flèche retour) → context.go('/')]
  - [anonymousChatNewConversation (clé 'anonymous_chat_new_conversation') → reset conversation locale (ConversationStore.clearCurrentNamespace + setState)]
  - [anonymousChatChip1/Chip2/Chip3 → pré-remplit _inputController (pas d'auto-send)]
  - [IconButton send → appel service CoachChatApiService.sendAnonymousMessage]
  - [anonymousChatCreateAccount (clé 'anon-chat-register-cta') → ouvre sheet AuthGateBottomSheet (redirectPath '/coach/chat?conversationId=…')]
- champs:
  - [_inputController (TextField texte, max 500 chars, clé 'anon-chat-input')]
- nav sortantes: context.go('/')
- orphelin/façade: OUI — la classe n'est plus référencée dans aucun code de production (`grep AnonymousChatScreen lib/` = 0 hit hors fichier lui-même) ; le test `test/navigation/anonymous_chat_route_retirement_test.dart` affirme explicitement que `/anonymous/chat` ne rend plus AnonymousChatScreen. Écran vivant uniquement dans les tests widget.

## AllocationAnnuelleScreen (`apps/mobile/lib/screens/arbitrage/allocation_annuelle_screen.dart`)
- boutons/actions:
  - [allocAnnuelleComparer → _recalculate (appel service ArbitrageEngine.compareAllocationAnnuelle, local)]
  - [MintPremiumSlider allocAnnuelleTauxMarginal → setState + recalcul]
  - [MintPremiumSlider allocAnnuelleAnneesRetraite → setState + recalcul]
  - [Switch allocAnnuelle3aMaxed → recalcul]
  - [Switch allocAnnuelleRachatLpp → recalcul (affiche champ rachat)]
  - [Switch allocAnnuelleProprietaire → recalcul]
  - [HypothesisEditorWidget (rendement_marche/lpp/3a) → recalcul]
  - [ExpansionTile allocAnnuelleHypotheses → expand/collapse local]
- champs:
  - [_montantCtrl (num, montant annuel disponible)]
  - [_potentielRachatCtrl (num, potentiel rachat LPP)]
- nav sortantes: aucune
- orphelin/façade: NON (monté sur `/arbitrage/allocation-annuelle`, app.dart:1647)

## ArbitrageBilanScreen (`apps/mobile/lib/screens/arbitrage/arbitrage_bilan_screen.dart`)
- boutons/actions:
  - [reportCommencer (état profil vide) → context.go('/coach/chat')]
  - [_ProtectionItemCard tap → context.push(protection.route) — route dynamique fournie par ArbitrageSummaryService]
  - [_ArbitrageItemCard tap → context.push(item.route) — route dynamique (rente_vs_capital, calendrier_retraits, rachat_vs_marche, allocation_annuelle, location_vs_propriete)]
  - [_LockedItemCard tap → context.push(locked.enrichmentRoute) — route dynamique d'enrichissement]
- champs: aucun
- nav sortantes: context.go('/coach/chat') + context.push(routes dynamiques issues de ArbitrageSummaryService.compute — pas de littéraux dans ce fichier)
- orphelin/façade: NON (monté sur `/arbitrage/bilan`, app.dart:1642)

## LocationVsProprieteScreen (`apps/mobile/lib/screens/arbitrage/location_vs_propriete_screen.dart`)
- boutons/actions:
  - [locationComparer → HapticFeedback + _recalculate (appel service ArbitrageEngine.compareLocationVsPropriete, local)]
  - [DropdownButton canton → recalcul]
  - [Switch locationMarie → recalcul]
  - [HypothesisEditorWidget (rendement_marche/appreciation_immo/taux_hypo/horizon) → recalcul]
  - [ExpansionTile locationHypotheses → expand/collapse local]
- champs:
  - [_capitalCtrl (num, capital disponible)]
  - [_loyerCtrl (num, loyer mensuel)]
  - [_prixBienCtrl (num, prix du bien)]
- nav sortantes: aucune
- orphelin/façade: NON (monté sur `/arbitrage/location-vs-propriete`, app.dart:1652)

## RenteVsCapitalScreen (`apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart`)
- boutons/actions:
  - [SegmentedButton renteVsCapitalEstimateMode / renteVsCapitalCertificateMode → setState _inputMode + _userRecalculate]
  - [ChoiceChips âge retraite (58…70) → _ageRetraiteSlider + recalcul]
  - [ChoiceChips espérance de vie renteVsCapitalAgeYears (75…100) → setState _lifeExpectancy + recalcul]
  - [_introPuce renteVsCapitalRenteLabel / renteVsCapitalCapitalLabel / renteVsCapitalMixteLabel → ouvre sheet showModalBottomSheet (explication du terme)]
  - [DropdownButton renteVsCapitalCanton → recalcul]
  - [Switch renteVsCapitalMarried → recalcul]
  - [Switch renteVsCapitalEplLabel → recalcul (affiche champ EPL)]
  - [HypothesisEditorWidget (rendement/swr/inflation) → recalcul]
  - [ExpansionTile renteVsCapitalAdvancedParameters / renteVsCapitalTornadoToggle / renteVsCapitalHypothesesTitle → expand/collapse local]
  - [recalcul → appel service ApiService.compareRenteVsCapital (backend), fallback ArbitrageEngine.compareRenteVsCapital (local) + write-back profil CoachProfileProvider.updateProfile]
- champs:
  - [_ageCtrl (num, âge)]
  - [_salaryCtrl (num, salaire brut annuel)]
  - [_lppTotalCtrl (num, avoir LPP total)]
  - [_capitalObligCtrl (num, capital obligatoire)]
  - [_capitalSurobCtrl (num, capital surobligatoire)]
  - [_renteCtrl (num, rente annuelle proposée)]
  - [_tcObligCtrl (num %, taux conversion oblig.)]
  - [_tcSurobCtrl (num %, taux conversion surob.)]
  - [_rachatAnnuelCtrl (num, rachat annuel)]
  - [_rachatMaxCtrl (num, plafond rachat — lecture seule logique)]
  - [_eplAmountCtrl (num, montant EPL)]
- nav sortantes: aucune (émet des ScreenReturn route '/retraite/rente-vs-capital' via ScreenCompletionTracker, sans navigation)
- orphelin/façade: NON (monté sur `/retraite/rente-vs-capital`, app.dart:991)

## AujourdhuiScreen (`apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart`)
- boutons/actions:
  - [FinancialPlanCard onRecalculate → context.go('/coach/chat')]
  - [ConfidenceScoreCard onEnrichmentTap → context.go('/coach/chat')]
  - [carte état vide (tensionEmptyWelcome) tap → context.go('/coach/chat')]
  - [MonthHeaderWidget onToggle → setState collapse/expand mois]
  - [timelineLoadMore → appel provider TimelineProvider.loadMore]
- champs: aucun
- nav sortantes: context.go('/coach/chat') (×3)
- orphelin/façade: NON (monté comme branche home du shell, app.dart:684)

## auth_platform.dart (`apps/mobile/lib/screens/auth/auth_platform.dart`)
- (helper, pas un écran) — getter `canShowAppleSignIn` (iOS non-web).

## auth_redirect.dart (`apps/mobile/lib/screens/auth/auth_redirect.dart`)
- (helper, pas un écran) — fonctions `resolvePostAuthRedirect` / `resolvePostAuthDestination` (fallback '/home', force '/onb' sans identité dossier) / `authRouteWithRedirect`; consommé par login/register/verify-email.

## ForgotPasswordScreen (`apps/mobile/lib/screens/auth/forgot_password_screen.dart`)
- boutons/actions:
  - [authForgotSendLink → appel service AuthProvider.requestPasswordReset + SnackBar]
  - [IconButton visibility mot de passe (authShowPassword/authHidePassword) ×2 → setState local]
  - [authForgotSubmitNewPassword → appel service AuthProvider.confirmPasswordReset → context.go('/auth/login')]
- champs:
  - [_emailController (email)]
  - [_tokenController (token reset)]
  - [_passwordController (password)]
  - [_confirmPasswordController (password)]
- nav sortantes: context.go('/auth/login')
- orphelin/façade: NON (monté sur `/auth/forgot-password`, app.dart:538)

## LoginScreen (`apps/mobile/lib/screens/auth/login_screen.dart`)
- boutons/actions:
  - [authSendLink (magic link) → appel service AuthProvider.sendMagicLink + countdown 30s]
  - [authResend → AuthProvider.sendMagicLink]
  - [authAppleSignIn (SignInWithAppleButton) → AppleSignInService.signIn + AuthProvider.completeAppleSignIn → _navigatePostAuth]
  - [authPasswordFallback → setState toggle formulaire mot de passe]
  - [IconButton visibility (authShowPassword/authHidePassword) → setState local]
  - [authLogin → appel service AuthProvider.login → _navigatePostAuth]
  - [authContinueLocal → AuthProvider.enableLocalMode → context.go(redirect ?? '/home')]
  - [authForgotPasswordLink → context.go('/auth/forgot-password')]
  - [authVerifyEmailLink → context.go('/auth/verify-email')]
  - [authRegister → context.go('/auth/register')]
  - [authBack → context.go('/')]
- champs:
  - [_emailController (email)]
  - [_passwordController (password)]
- nav sortantes: context.go('/home'), context.go('/auth/forgot-password'), context.go('/auth/verify-email'), context.go('/auth/register'), context.go('/'), + dynamiques via _navigatePostAuth: context.go(redirect) | context.go(resolvePostAuthDestination → '/coach/chat' | '/onb' | '/home')
- orphelin/façade: NON (monté sur `/auth/login`, app.dart:528)

## RegisterScreen (`apps/mobile/lib/screens/auth/register_screen.dart`)
- boutons/actions:
  - [AppBar back (semanticsBack) → Navigator.pop si canPop, sinon context.go('/auth/login')]
  - [authDateOfBirth (champ picker, clé 'auth_register_dob_field') → ouvre dialog showDatePicker]
  - [Checkbox authCguAccept (clé 'auth_register_accept_cgu') → setState consentement]
  - [liens authCguLink / authPrivacyPolicyText → context.push('/about')]
  - [Checkbox authConfirm18 (clé 'auth_register_confirm_18') → setState]
  - [CheckboxListTile authConsentNotifications / authConsentAnalytics → setState]
  - [IconButton visibility (authShowPassword/authHidePassword) ×2 → setState local]
  - [authCreateAccount (clé 'auth_register_create_account') → appel service AuthProvider.register + mergeAnswers + persist consents → context.go('/auth/verify-email?redirect=…') si vérification requise, sinon context.go(resolvePostAuthDestination)]
  - [authAppleSignIn → AppleSignInService.signIn(allowRecreateAfterDelete) + completeAppleSignIn → _goAfterAccountCreated]
  - [authCreateWithEmail → setState _showEmailForm]
  - [authContinueLocal → AuthProvider.enableLocalMode → context.go(redirect ?? '/home')]
  - [authLogin → context.go('/auth/login')]
  - [authBack → context.go('/')]
- champs:
  - [_emailController (email, clé 'auth_register_email_field')]
  - [_displayNameController (prénom, clé 'auth_register_first_name_field')]
  - [_passwordController (password, clé 'auth_register_password_field')]
  - [_confirmPasswordController (password, clé 'auth_register_confirm_password_field')]
  - [FormField<DateTime> date de naissance (picker, pas de controller)]
- nav sortantes: context.go('/auth/login'), context.push('/about'), context.go('/auth/verify-email' + redirect), context.go('/home'), context.go('/'), + dynamique context.go(resolvePostAuthDestination → '/onb' | '/home' | redirect)
- orphelin/façade: NON (monté sur `/auth/register`, app.dart:533)

## VerifyEmailScreen (`apps/mobile/lib/screens/auth/verify_email_screen.dart`)
- boutons/actions:
  - [authVerifySendLink → appel service AuthProvider.requestEmailVerification + SnackBar]
  - [authVerifySubmit → appel service AuthProvider.confirmEmailVerification → context.go(redirect ?? '/') si loggé, sinon context.go('/auth/login?redirect=…') ou context.go('/auth/login')]
- champs:
  - [_emailController (email)]
  - [_tokenController (token vérification)]
- nav sortantes: context.go('/'), context.go('/auth/login'), context.go('/auth/login?redirect=<…>')
- orphelin/façade: NON (monté sur `/auth/verify-email`, app.dart:543)

## BankImportScreen (`apps/mobile/lib/screens/bank_import_screen.dart`)
- boutons/actions:
  - [bankImportUploadButton → FilePicker.pickFiles (pdf/csv) + appel service DocumentService.uploadBankStatement]
  - [IconButton close erreur → setState _error = null]
  - [bankImportButton (importer dans budget) → appel provider BudgetProvider.setInputs + SnackBar succès]
- champs: aucun (import fichier, pas de TextEditingController)
- nav sortantes: aucune
- orphelin/façade: NON (monté sur `/bank-import`, app.dart:1853)

## BudgetContainerScreen (`apps/mobile/lib/screens/budget/budget_container_screen.dart`)
- boutons/actions:
  - [budgetCardEmptyAction (semanticsBudgetStartButton) → context.push('/budget/setup')]
- champs: aucun
- nav sortantes: context.push('/budget/setup')
- orphelin/façade: NON (monté sur `/budget`, app.dart:1216; délègue le rendu à BudgetScreen quand inputs présents)

## BudgetScreen (`apps/mobile/lib/screens/budget/budget_screen.dart`)
- boutons/actions:
  - [budgetEmptyCta (état netIncome<=0) → context.go('/coach/chat')]
  - [bannière qualité données budgetCompleteMyData (clé 'budget_data_quality_banner') → context.push('/profile/bilan')]
  - [ActionInsightWidget → route cap.ctaRoute (dynamique CapEngine) ou fallback '/coach/chat']
  - [toggle 'budget_calculation_detail_toggle' (affordabilityCalculationDetail) → setState expand/collapse flow map]
  - [budgetCtaEvaluate → context.push('/debt/ratio')]
  - [budgetCtaPlan → context.push('/debt/repayment')]
  - [budgetCtaDiscover → context.push('/debt/help')]
- champs:
  - [_BudgetAmountField budgetEnvelopeFieldFuture (num → BudgetProvider.updateOverride('future'))]
  - [_BudgetAmountField budgetEnvelopeFieldVariables (num → BudgetProvider.updateOverride('variables'))]
- nav sortantes: context.go('/coach/chat'), context.push('/profile/bilan'), context.push('/debt/ratio'), context.push('/debt/repayment'), context.push('/debt/help') (+ route dynamique ActionInsightWidget)
- orphelin/façade: NON (pas de route directe, mais monté indirectement par BudgetContainerScreen sur `/budget` et par debug_budget_bootstrap_screen)

## BudgetSetupScreen (`apps/mobile/lib/screens/budget/budget_setup_screen.dart`)
- boutons/actions:
  - [budgetSetupAddOthers → setState _showOptional (révèle 5 champs)]
  - [budgetSetupSave (clé 'budget_setup_save_button') → appel provider CoachProfileProvider.mergeAnswers + BudgetProvider.setInputs → Navigator.pop]
  - [budgetSetupChatFallback (clé 'budget_setup_chat_fallback') → context.go('/coach/chat?topic=budget')]
- champs:
  - [_income (num, budgetSetupIncome, requis, clé budgetIncomeField)]
  - [_housing (num, budgetSetupHousing, requis, clé budgetHousingField)]
  - [_lamal (num, budgetSetupLamal, requis, clé budgetLamalField)]
  - [_transport (num, budgetSetupTransport, clé budgetTransportField)]
  - [_telecom (num, budgetSetupTelecom, clé budgetTelecomField)]
  - [_electricity (num, budgetSetupElectricity, clé budgetElectricityField)]
  - [_medical (num, budgetSetupMedical, clé budgetMedicalField)]
  - [_other (num, budgetSetupOther, clé budgetOtherField)]
- nav sortantes: context.go('/coach/chat?topic=budget')
- orphelin/façade: NON (monté sur `/budget/setup`, app.dart:1223)

## ByokSettingsScreen (`apps/mobile/lib/screens/byok_settings_screen.dart`)
- boutons/actions:
  - [chips provider 'Claude'/'OpenAI'/'Mistral' → setState _selectedProvider]
  - [IconButton visibility clé (byokShowKey/byokHideKey) → setState local]
  - [byokGetKeyOn(label) → launchUrl externe (console.anthropic.com / platform.openai.com / console.mistral.ai)]
  - [byokTestButton → appel service ByokProvider.saveKey + ByokProvider.testKey]
  - [byokSaveButton (derrière AuthGate byokSetup) → ByokProvider.saveKey + SnackBar]
  - [byokTryNow (après test OK) → context.push('/ask-mint')]
  - [byokClearButton → ouvre dialog AlertDialog confirmation → ByokProvider.clearKey]
- champs:
  - [_apiKeyController (texte obscurci, clé API)]
- nav sortantes: context.push('/ask-mint')
- orphelin/façade: NON (monté sur `/profile/byok`, app.dart:1553)

## CantonalBenchmarkScreen (`apps/mobile/lib/screens/cantonal_benchmark_screen.dart`)
- boutons/actions:
  - [IconButton back → context.pop() si canPop, sinon context.go('/coach/chat')]
  - [Switch opt-in (semanticsBenchmarkToggle) → appel service CantonalBenchmarkService.setOptedIn + setState]
- champs: aucun
- nav sortantes: context.go('/coach/chat') (fallback back)
- orphelin/façade: NON (monté sur `/cantonal-benchmark`, app.dart:1669). Note: un texte d'erreur hardcodé FR non-ARB ('Une erreur est survenue. Réessaie plus tard.') ligne 107.

## ChatAsVerbDemoScreen (`apps/mobile/lib/screens/coach/chat_as_verb_demo_screen.dart`)
- boutons/actions:
  - [tap carte (titre/sous-titre hardcodés FR — écran démo W1) → setState toggle action bar]
  - [MintCardActionBar onExplain → ouvre sheet MintChatOverlay.show(intent 'explain')]
  - [MintCardActionBar onReassure → ouvre sheet MintChatOverlay.show(intent 'reassure')]
  - [MintCardActionBar onSimulate → context.go('/explore?simulate=tax_marge_2026' | '/explore?simulate=mortgage_monthly_cost')]
- champs: aucun
- nav sortantes: context.go('/explore?simulate=<card_id>')
- orphelin/façade: NON techniquement (monté sur `/debug/chat-as-verb`, app.dart:608) mais écran DÉMO dev-only : strings FR hardcodées (viole i18n), scaffold W1 explicitement non généralisé.

## CoachArchetypeGuard (`apps/mobile/lib/screens/coach/coach_archetype_guard.dart`)
- (helper, pas un écran) — fonction pure `evaluateCoachArchetypeGate(CoachProfile)` → verdict block/allow + slug archétype; consommé par coach_chat_screen et archetype_route_gate.

## CoachChatScreen (`apps/mobile/lib/screens/coach/coach_chat_screen.dart`)
- boutons/actions:
  - [CoachAppBar onBack → safePop(fallback MintNav.coachFallbackRouteFor(authLifecycle))]
  - [CoachAppBar onHistory → autoSave + router.push('/coach/history')]
  - [CoachAppBar onExport → appel service PdfService.generateDecisionReportPdf]
  - [CoachAppBar onSettings → context.push('/profile/byok')]
  - [CoachInputBar onSend → _sendMessage: CoachOrchestrator.streamChat (SLM) → CoachLlmService.chat (BYOK/serveur) → CoachChatApiService.sendAnonymousMessage (fallback anonyme)]
  - [CoachInputBar onLightningMenu → ouvre sheet LightningMenu (onNavigate → showChatDrawer(ChatDrawerHost) ou MintNav.open(route))]
  - [chip coachAuthGateChipRegister → context.push('/auth/register')]
  - [chip coachAuthGateChipLogin → context.push('/auth/login')]
  - [chips coachOptInAccept / coachOptInDecline → _handleOptInResponse (SharedPreferences) + messages locaux]
  - [chips suggested actions → _routeForAction: '/pilier-3a' | '/rachat-lpp' | '/retraite' | '/retraite/rente-vs-capital' | '/fiscal' | '/confidence' | '/budget' | '/hypotheque' (ouverts en drawer ChatDrawerHost ou MintNav.open), sinon renvoi comme message]
  - [opener chip coachStarterPaper → context.push('/scan')]
  - [opener chips coachStarterChoice / coachStarterCost → pré-remplit _controller + focus]
  - [opener chip coachStarterLurk → dismiss (setState)]
  - [inline input pickers (âge/salaire/canton/état civil/emploi/enfants) → CoachProfileProvider.mergeAnswers + _sendMessage]
  - [gate archétype (hard gate) → context.go('/waitlist', extra: WaitlistArgs)]
- champs:
  - [_controller (TextEditingController, saisie chat via CoachInputBar)]
- nav sortantes: router.push('/coach/history'), context.push('/profile/byok'), context.push('/auth/register'), context.push('/auth/login'), context.push('/scan'), context.go('/waitlist'), + indirectes via _routeForAction/drawer: '/pilier-3a', '/rachat-lpp', '/retraite', '/retraite/rente-vs-capital', '/fiscal', '/confidence', '/budget', '/hypotheque'
- orphelin/façade: NON (branche shell `/coach/chat`, app.dart:718)

## ConversationHistoryScreen (`apps/mobile/lib/screens/coach/conversation_history_screen.dart`)
- boutons/actions:
  - [IconButton back → safePop(context)]
  - [ConversationTile tap → context.go('/coach/chat?conversationId=<id>')]
  - [ConversationTile onDelete → appel service ConversationStore.deleteConversation + reload]
  - [FAB conversationNew → context.go('/coach/chat')]
  - [conversationStartFirst (état vide) → context.go('/coach/chat')]
  - [conversationRetry (état erreur) → _loadConversations]
- champs: aucun
- nav sortantes: context.go('/coach/chat'), context.go('/coach/chat?conversationId=<id>')
- orphelin/façade: NON (monté sur `/coach/history`, app.dart:1100)

## OptimisationDecaissementScreen (`apps/mobile/lib/screens/coach/optimisation_decaissement_screen.dart`)
- boutons/actions:
  - [aucun bouton interactif — écran 100% éducatif; EduSpecialistCta (optimDecaissementSpecialisteTitle) est purement informatif (aucun onTap/onPressed dans edu_shared_widgets.dart)]
- champs: aucun
- nav sortantes: aucune (émet un ScreenReturn route '/decaissement' via ScreenCompletionTracker au pop, sans navigation)
- orphelin/façade: NON (monté sur `/decaissement`, app.dart:1057)
