# Audit Fix Log — Onboarding / Budget / Security (2026-02-20)

## Scope
Corrections issues remontées sur 8 captures (LPP, check-in, budget, login, onboarding, safe-mode).

## Findings & Fixes

### F-01 (CRIT) — API login fail sur build mobile (localhost)
- Symptom: `ClientException ... localhost:8888` sur écran création compte.
- Root cause: `ApiService.baseUrl` fallback hardcodé `http://localhost:8888/api/v1` même hors dev.
- Fix:
  - fallback dynamique:
    - release: `https://api.mint.ch/api/v1`
    - debug: `http://localhost:8888/api/v1`
  - `API_BASE_URL` via `--dart-define` garde la priorité.
- Files:
  - `apps/mobile/lib/services/api_service.dart`
  - `apps/mobile/test/services/api_service_test.dart`

### F-02 (CRIT) — Sur-estimation possible économie fiscale rachat LPP en bloc
- Symptom: montant d’économie perçu irréaliste sur gros rachat.
- Root cause: simulation autorisait une déduction implicite au-delà du revenu imposable.
- Fix:
  - cap strict `deduction <= income`
  - courbe de taux effectif rendue plus décroissante par tranche.
- Files:
  - `apps/mobile/lib/services/lpp_deep_service.dart`
  - `apps/mobile/test/services/lpp_deep_service_test.dart`

### F-03 (MAJEUR) — Check-in affiche parfois `Capital projeté +CHF 0` malgré versements
- Symptom: carte d’impact à `+CHF 0` alors que versements > 0.
- Root cause: delta basé uniquement sur projection avant/après pouvant rester nul si plan inchangé.
- Fix:
  - ajout d’un fallback d’impact “1 mois de versements projeté à l’objectif” par catégorie d’actif.
- Files:
  - `apps/mobile/lib/services/forecaster_service.dart`
  - `apps/mobile/lib/screens/coach/coach_checkin_screen.dart`

### F-04 (MAJEUR) — Budget incomplet (impôts/LAMal/fixes absents)
- Symptom: “disponible” surévalué car charges fixes majeures non prises en compte.
- Root cause: modèle budget initial limité à revenu/logement/dettes.
- Fix:
  - extension modèle budget: `taxProvision`, `healthInsurance`, `otherFixedCosts`
  - calcul `available` corrigé partout
  - affichage détaillé dans écran budget + carte budget rapport
  - estimation impôts mensuels + estimation LAMal si non renseigné
- Files:
  - `apps/mobile/lib/domain/budget/budget_inputs.dart`
  - `apps/mobile/lib/domain/budget/budget_service.dart`
  - `apps/mobile/lib/screens/budget/budget_screen.dart`
  - `apps/mobile/lib/widgets/report/budget_waterfall.dart`
  - `apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart`
  - `apps/mobile/test/domain/budget_service_test.dart`

### F-05 (MOYEN) — Message safe-mode trop opaque (“Pourquoi bloqué ?”)
- Symptom: cartes grisées sans explication actionnable.
- Fix:
  - `SafeModeGate` enrichi: raisons explicites (liste), bottom-sheet explicatif, CTA direct vers plan de désendettement.
  - calcul `hasDebt` harmonisé via `WizardService.isSafeModeActive`.
- Files:
  - `apps/mobile/lib/widgets/common/safe_mode_gate.dart`
  - `apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart`

### F-06 (MOYEN) — Aha Step 2 onboarding ambigu (“1000 pour 100000”)
- Symptom: confusion entre impôt total, écart vs moyenne CH et points de taux.
- Fix:
  - ajout d’indicateurs explicites dans la carte:
    - taux marginal estimé
    - impôt indicatif sur CHF 100k
    - écart vs moyenne CH (CHF)
- Files:
  - `apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart`

### F-07 (MOYEN) — Transition des cercles onboarding peu parlante / timing
- Symptom: écran transition trop passif et texte dense.
- Fix:
  - auto-advance (~2.6s) + conservation du bouton manuel
  - libellés simplifiés
  - progression “Cercle 1/3, 2/3, 3/3” affichée explicitement.
- Files:
  - `apps/mobile/lib/widgets/circle_transition_widget.dart`
  - `apps/mobile/lib/screens/advisor/advisor_wizard_screen_v2.dart`

## Validation run
- A exécuter après merge local:
  - `flutter analyze`
  - `flutter test test/services/api_service_test.dart`
  - `flutter test test/services/lpp_deep_service_test.dart`
  - `flutter test test/domain/budget_service_test.dart`

### F-08 (MAJEUR) — Mini-onboarding non adaptatif au foyer
- Symptom: préremplissage fiscal/LAMal basé sur célibataire par défaut, sans prise en compte couple/famille.
- Root cause: absence de variable `household` dans le mini-onboarding et persistance partielle insuffisante.
- Fix:
  - ajout choix foyer dans l’étape revenu/statut: `single`, `couple`, `family`
  - persistance mini-onboarding: `q_household_type`
  - inférences cohérentes pour calculs précoces: `q_civil_status`, `q_children`
  - préremplissage impôts/LAMal désormais dépendant du foyer + âge réel si disponible
  - segmentation cohortes onboarding enrichie avec `house_*`
- Files:
  - `apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart`

### F-09 (MOYEN) — Onboarding encore chargé (Step 4 + Aha + debug quality)
- Symptom: Step 4 perçu comme trop dense, Aha Step 2 encore ambigu sur unités, panel debug trop global.
- Fix:
  - Step 4: simplification cognitive avec rappel de priorité active (1 choix clair avant activation dashboard).
  - Aha Step 2: chips reformulés avec unités explicites (`%`, `CHF/an`, `pts`) pour éviter confusion “par 100k”.
  - Debug metrics: ajout d’un bloc “Qualité par step” (conversions S1→S2→S3→S4→Done + temps moyen par step).
- Files:
  - `apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart`

### F-10 (MOYEN) — Faible perception de progression immédiate
- Symptom: onboarding jugé “flou”, peu de feedback entre les steps.
- Fix:
  - micro-feedback de validation ajouté en fin des steps 1, 2, 3 quand la donnée minimale est prête.
  - carte “Ce que MINT a compris” ajoutée en step 4 avant activation dashboard (priorité, profil, base fiscale, revenu, charges fixes captées).
  - i18n: nouvelles clés dédiées ajoutées (FR/EN/DE/IT/ES/PT).
- Files:
  - `apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart`
  - `apps/mobile/lib/l10n/app_fr.arb`
  - `apps/mobile/lib/l10n/app_en.arb`
  - `apps/mobile/lib/l10n/app_de.arb`
  - `apps/mobile/lib/l10n/app_it.arb`
  - `apps/mobile/lib/l10n/app_es.arb`
  - `apps/mobile/lib/l10n/app_pt.arb`

### F-11 (MAJEUR) — Reprise fragile si app fermée en cours de saisie
- Symptom: une partie des infos pouvait être perdue si l’app était tuée avant transition d’étape.
- Fix:
  - autosave debounced sur interactions clés (stress, année, canton, revenu, statut, foyer, coûts fixes, objectif).
  - persistance draft explicite (`mini_draft_*`) pour champs incomplets.
  - hydratation reprend maintenant les valeurs draft si les valeurs finales ne sont pas encore valides.
- Files:
  - `apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart`

### F-12 (STRUCTURE) — Début refonte monolithe onboarding (Phase 0/1/2)
- Symptom: `advisor_onboarding_screen.dart` (3396 lignes) mélange UI, persistence, analytics, calculs, métriques.
- Fix (incrémental, sans régression produit):
  - Phase 0: création `OnboardingProvider` (état, validations, snapshot, autosave, completion, preview, Aha).
  - Phase 1: création `OnboardingConstants` et remplacement des magic numbers critiques dans l'écran existant.
  - Phase 2: création d'un UI kit onboarding (`MintSelectableCard`, `MintQuickPickChips`, `MintChfInputField`, `OnboardingInsightCard`, `OnboardingStepHeader`, `OnboardingContinueButton`).
  - Phase 3 (préparation): création des 4 widgets de step (`stress`, `essentials`, `income`, `goal`) + helper analytics + metrics panel extrait.
  - App bootstrap: enregistrement de `OnboardingProvider` dans `MultiProvider`.
- Tests ajoutés:
  - `test/providers/onboarding_provider_test.dart`
  - `test/widgets/onboarding_widgets_test.dart`
  - `test/screens/onboarding_steps_test.dart`

### F-13 (CRITIQUE) — Création de compte: fuite d’erreurs techniques + mode local peu explicite
- Symptom: écran d’inscription affichait des exceptions brutes (`SocketException`, host lookup), générant une UX anxiogène et incompréhensible.
- Root cause: propagation directe de `Exception.toString()` jusqu’à l’UI.
- Fix:
  - normalisation des erreurs API (`ApiException`) côté mobile.
  - mapping d’erreurs auth vers messages utilisateurs non-techniques dans `AuthProvider`.
  - ajout CTA explicite `Continuer en mode local` dans l’écran d’inscription.
  - positionnement copy aligné local-first (“compte optionnel”).
- Files:
  - `apps/mobile/lib/services/api_service.dart`
  - `apps/mobile/lib/providers/auth_provider.dart`
  - `apps/mobile/lib/screens/auth/register_screen.dart`
  - `apps/mobile/test/screens/auth_screens_smoke_test.dart`

### F-14 (CRITIQUE) — Conformité effacement compte + migration locale vers cloud
- Symptom: absence d’endpoint de suppression de compte (risque nLPD/App Store), absence de voie explicite de claim local→cloud.
- Fix backend:
  - endpoint `DELETE /api/v1/auth/account`:
    - suppression utilisateur et données liées (profils/sessions),
    - anonymisation des événements analytics (`user_id -> null`).
  - endpoint `POST /api/v1/sync/claim-local-data`:
    - import one-shot des snapshots locaux (wizard, mini-onboarding, budget, check-ins),
    - upsert idempotent sur profil cloud utilisateur.
  - schémas `DeleteAccountResponse`, `ClaimLocalDataRequest/Response`.
- Files:
  - `services/backend/app/api/v1/endpoints/auth.py`
  - `services/backend/app/api/v1/endpoints/sync.py`
  - `services/backend/app/api/v1/router.py`
  - `services/backend/app/schemas/auth.py`
  - `services/backend/app/schemas/sync.py`
  - `services/backend/tests/test_auth.py`

### F-15 (CRITIQUE) — Billing réel fondation (Stripe-first + entitlement backend)
- Symptom: abonnement 100% mock côté mobile, aucune source de vérité backend.
- Fix backend:
  - nouvelles tables billing:
    - `subscriptions`
    - `entitlements`
    - `billing_transactions`
    - `billing_webhook_events`
  - endpoint entitlements authentifié:
    - `GET /api/v1/billing/entitlements`
  - checkout Stripe:
    - `POST /api/v1/billing/checkout/stripe`
  - webhook Stripe:
    - `POST /api/v1/billing/webhooks/stripe` (signature vérifiée si secret configuré)
  - portail Stripe:
    - `POST /api/v1/billing/portal/stripe`
  - endpoint debug interne:
    - `POST /api/v1/billing/debug/activate` pour activer un abonnement sans store (dev/staging)
- Fix mobile:
  - `SubscriptionService` lit désormais `GET /billing/entitlements` et applique les features serveur.
  - `SubscriptionProvider` déclenche un refresh backend à l’initialisation.
  - fallback mock conservé pour résilience hors connexion/dev.
- Files:
  - `services/backend/app/models/billing.py`
  - `services/backend/app/services/billing_service.py`
  - `services/backend/app/api/v1/endpoints/billing.py`
  - `services/backend/app/schemas/billing.py`
  - `services/backend/app/api/v1/router.py`
  - `services/backend/app/core/config.py`
  - `services/backend/tests/test_billing.py`
  - `apps/mobile/lib/services/subscription_service.dart`
  - `apps/mobile/lib/providers/subscription_provider.dart`
  - `apps/mobile/test/services/subscription_service_test.dart`

### F-16 (MAJEUR) — P2.2 StoreKit2 iOS foundation branchée backend
- Symptom: paywall mobile utilisait un flow mock (trial local) sans achat iOS natif.
- Fix mobile:
  - ajout de `in_app_purchase` dans `pubspec.yaml`.
  - service iOS dédié (`IosIapService`) :
    - query produit StoreKit2
    - achat non-consumable
    - restauration achats
    - synchronisation serveur via `POST /billing/apple/verify`.
  - `SubscriptionService.upgradeTo()`:
    - sur iOS: tentative achat natif + refresh entitlements backend.
    - fallback mock conservé hors iOS/dev.
  - `CoachPaywallSheet`:
    - CTA primaire dynamique iOS (achat) vs non-iOS (essai).
- Fix backend:
  - endpoint `POST /api/v1/billing/apple/verify`:
    - active/actualise l’abonnement `source=apple`
    - met à jour entitlements serveur
    - stocke transaction de preuve.
- Files:
  - `apps/mobile/pubspec.yaml`
  - `apps/mobile/lib/services/ios_iap_service.dart`
  - `apps/mobile/lib/services/subscription_service.dart`
  - `apps/mobile/lib/widgets/coach/coach_paywall_sheet.dart`
  - `apps/mobile/lib/providers/subscription_provider.dart`
  - `apps/mobile/lib/services/api_service.dart`
  - `services/backend/app/api/v1/endpoints/billing.py`
  - `services/backend/app/services/billing_service.py`
  - `services/backend/app/schemas/billing.py`
  - `services/backend/app/core/config.py`
  - `services/backend/tests/test_billing.py`

### F-17 (MAJEUR) — Webhook Apple robuste + journal d’audit sécurité
- Symptom:
  - webhook Apple retournait `400 Malformed Apple signed payload` sur payload JSON non-JWS.
  - absence de journal d’audit persistant pour actions sensibles auth/billing.
- Fix backend:
  - validation JWS Apple durcie:
    - ne tente le décodage JWT que si format compact JWT valide (`header.payload.signature`),
    - ignore proprement les payloads non-JWS (cas webhook simplifié),
    - conserve le rejet sur mismatch réel produit/transaction.
  - webhook Apple:
    - n’envoie plus `json.dumps(data)` comme signed payload,
    - utilise `data.signed_payload` seulement si présent.
  - ajout modèle d’audit `audit_events` + helper `log_audit_event(...)`.
  - instrumentation auth:
    - `auth.register`, `auth.login` (success/failed), `auth.refresh` (success/failed), `auth.account_delete`.
  - instrumentation billing:
    - `billing.apple_verify`, `billing.apple_webhook`.
- Files:
  - `services/backend/app/services/billing_service.py`
  - `services/backend/app/models/audit_event.py`
  - `services/backend/app/services/audit_service.py`
  - `services/backend/app/api/v1/endpoints/auth.py`
  - `services/backend/app/api/v1/endpoints/billing.py`
  - `services/backend/app/models/__init__.py`
  - `services/backend/tests/conftest.py`

### F-18 (MAJEUR) — Auth P1: anti-bruteforce + reset mot de passe
- Symptom:
  - login exposé aux tentatives répétées sans backoff/lockout applicatif.
  - aucun flow natif de reset mot de passe côté API.
- Fix backend:
  - nouveaux modèles:
    - `login_security_states` (failed attempts, next allowed, lockout)
    - `password_reset_tokens` (single-use, expiry, hash token)
  - service sécurité auth:
    - backoff progressif dès 5 échecs (`1s, 2s, 4s, 8s`)
    - lockout à 10 échecs (`15 min`)
    - reset compteur après login réussi
  - endpoints:
    - `POST /api/v1/auth/password-reset/request` (réponse anti-enumération)
    - `POST /api/v1/auth/password-reset/confirm` (token one-shot)
  - instrumentation audit:
    - `auth.password_reset_request`
    - `auth.password_reset_confirm`
- Tests:
  - flow reset complet (request -> confirm -> login nouveau mdp)
  - token reset à usage unique
  - blocage login après échecs répétés (HTTP 429)
- Files:
  - `services/backend/app/models/auth_security.py`
  - `services/backend/app/services/auth_security_service.py`
  - `services/backend/app/schemas/auth.py`
  - `services/backend/app/api/v1/endpoints/auth.py`
  - `services/backend/app/models/__init__.py`
  - `services/backend/tests/conftest.py`
  - `services/backend/tests/test_auth.py`

### F-19 (MOYEN) — Mobile reset password branché sur API
- Symptom: aucun parcours utilisateur pour consommer les nouveaux endpoints reset password.
- Fix mobile:
  - API client:
    - `requestPasswordReset(email)`
    - `confirmPasswordReset(token, newPassword)`
  - `AuthProvider`:
    - méthodes dédiées reset + mapping erreur utilisateur
  - nouveau screen:
    - `/auth/forgot-password` avec flow guidé request -> token -> nouveau mot de passe
  - login:
    - lien explicite `Mot de passe oublié ?`
- Tests:
  - smoke auth: lien forgot password + rendu écran forgot password
- Files:
  - `apps/mobile/lib/services/api_service.dart`
  - `apps/mobile/lib/providers/auth_provider.dart`
  - `apps/mobile/lib/screens/auth/forgot_password_screen.dart`
  - `apps/mobile/lib/screens/auth/login_screen.dart`
  - `apps/mobile/lib/app.dart`
  - `apps/mobile/test/screens/auth_screens_smoke_test.dart`

### F-20 (MAJEUR) — Vérification e-mail end-to-end (backend + mobile)
- Symptom:
  - absence de vérification e-mail exploitable de bout en bout.
  - impossibilité d’imposer un login “verified only” de manière contrôlée.
- Fix backend:
  - modèle user enrichi: `email_verified`
  - tokens one-shot de vérification e-mail (`email_verification_tokens`)
  - endpoints:
    - `POST /api/v1/auth/email-verification/request`
    - `POST /api/v1/auth/email-verification/confirm`
  - blocage login configurable via flag `AUTH_REQUIRE_EMAIL_VERIFICATION=1` (HTTP 403 si non vérifié)
  - `TokenResponse` et `/auth/me` incluent `email_verified`
  - audit events:
    - `auth.email_verification_request`
    - `auth.email_verification_confirm`
- Fix mobile:
  - nouvel écran `VerifyEmailScreen` + route `/auth/verify-email`
  - lien dédié depuis login: `Vérifier mon e-mail`
  - API/provider branchés pour request/confirm
- Tests:
  - backend auth: demande + confirmation + login, blocage login si flag activé
  - mobile smoke auth: lien verify e-mail + rendu écran verify e-mail
- Files:
  - `services/backend/app/models/user.py`
  - `services/backend/app/models/auth_security.py`
  - `services/backend/app/services/auth_security_service.py`
  - `services/backend/app/schemas/auth.py`
  - `services/backend/app/api/v1/endpoints/auth.py`
  - `services/backend/app/models/__init__.py`
  - `services/backend/tests/conftest.py`
  - `services/backend/tests/test_auth.py`
  - `apps/mobile/lib/services/api_service.dart`
  - `apps/mobile/lib/providers/auth_provider.dart`
  - `apps/mobile/lib/screens/auth/verify_email_screen.dart`
  - `apps/mobile/lib/screens/auth/login_screen.dart`
  - `apps/mobile/lib/app.dart`
  - `apps/mobile/test/screens/auth_screens_smoke_test.dart`

### F-21 (MOYEN) — Envoi e-mail transactionnel SMTP (prod wiring)
- Symptom:
  - request/confirm reset + vérification e-mail ne déclenchaient aucun envoi réel.
- Fix backend:
  - nouveau `EmailService` SMTP avec garde-fous:
    - `EMAIL_SEND_ENABLED=false` par défaut
    - fallback propre (`False`) si SMTP non configuré
    - timeout + gestion d’erreurs non bloquante
  - templates transactionnels:
    - e-mail de vérification
    - e-mail de reset password
  - branché dans auth endpoints:
    - register (envoi vérification)
    - email verification request (resend)
    - password reset request
  - statut envoi tracé en audit (`details.email_sent`)
- Config ops:
  - ajout variables dans `services/backend/.env.example`:
    - `EMAIL_SEND_ENABLED`, `EMAIL_FROM`, `SMTP_*`, `FRONTEND_BASE_URL`
    - `AUTH_REQUIRE_EMAIL_VERIFICATION`
- Tests:
  - `test_email_service.py` (disabled/smtp-missing safety)
- Files:
  - `services/backend/app/services/email_service.py`
  - `services/backend/app/api/v1/endpoints/auth.py`
  - `services/backend/app/core/config.py`
  - `services/backend/tests/test_email_service.py`
  - `services/backend/.env.example`

### F-22 (MAJEUR) — Ops auth/billing: observability + purge unverified
- Symptom:
  - pas de vue admin simple sur la santé auth/billing.
  - pas de mécanisme de purge des comptes non vérifiés anciens.
- Fix backend:
  - service admin:
    - snapshot agrégé auth/billing (`users`, `verification`, `lockout`, `tokens`, `subscriptions`)
    - purge des comptes non vérifiés avec `dry_run` et `older_than_days`
  - endpoints admin protégés (`@mint.ch`):
    - `GET /api/v1/auth/admin/observability`
    - `POST /api/v1/auth/admin/purge-unverified`
  - garde admin centralisé + audit event `auth.admin_purge_unverified`
  - config:
    - `AUTH_UNVERIFIED_PURGE_DAYS` ajoutée
  - correction logique:
    - prise en charge explicite `older_than_days=0`
- Tests:
  - accès admin refusé hors `@mint.ch`
  - observability admin OK
  - purge dry-run puis purge réelle, avec conservation des comptes vérifiés
- Files:
  - `services/backend/app/services/auth_admin_service.py`
  - `services/backend/app/api/v1/endpoints/auth.py`
  - `services/backend/app/schemas/auth.py`
  - `services/backend/app/core/config.py`
  - `services/backend/.env.example`
  - `services/backend/tests/test_auth.py`

### F-23 (MOYEN) — Auto-purge optionnelle au startup
- Symptom:
  - purge unverified disponible seulement via endpoint manuel.
- Fix backend:
  - ajout d’un hook de purge optionnel au startup FastAPI:
    - activable via `AUTH_AUTO_PURGE_ON_STARTUP=1`
    - utilise `AUTH_UNVERIFIED_PURGE_DAYS`
    - non bloquant (warning en cas d’échec)
  - désactivé par défaut pour éviter toute suppression non intentionnelle.
- Files:
  - `services/backend/app/main.py`
  - `services/backend/app/core/config.py`
  - `services/backend/.env.example`

### F-24 (MAJEUR) — Export CSV cohortes auth/billing (admin)
- Symptom:
  - absence d’export exploitable pour analyser les cohortes auth/billing hors app.
- Fix backend:
  - nouvel endpoint admin protégé (`@mint.ch`):
    - `GET /api/v1/auth/admin/cohorts/export.csv`
  - paramètres:
    - `days` (1..365, défaut 30)
    - `start_date`, `end_date` (optionnels, format ISO)
  - export CSV journalier avec colonnes:
    - `date`
    - `users_registered`
    - `users_verified`
    - `login_success`
    - `login_failed`
    - `login_blocked`
    - `password_reset_requests`
    - `email_verification_requests`
    - `subscriptions_started`
    - `billing_webhooks_received`
  - header `Content-Disposition` pour téléchargement direct.
- Tests:
  - accès refusé non-admin
  - export admin renvoie CSV valide + en-tête attendu
- Files:
  - `services/backend/app/services/auth_admin_service.py`
  - `services/backend/app/api/v1/endpoints/auth.py`
  - `services/backend/tests/test_auth.py`

### F-25 (MAJEUR) — Score “qualité onboarding” temps réel (admin)
- Symptom:
  - absence d’un score onboarding temps réel côté admin/debug.
- Fix backend:
  - nouvel endpoint admin protégé (`@mint.ch`):
    - `GET /api/v1/auth/admin/onboarding-quality?days=30`
  - calcul basé sur events analytics existants:
    - `onboarding_started`
    - `onboarding_step_completed`
    - `onboarding_step_duration`
    - `onboarding_completed`
  - métriques renvoyées:
    - sessions started/completed
    - completion rate
    - conversion step1→2, step2→3, step3→4
    - avg completion seconds
    - avg step duration seconds
    - `quality_score` (0..100) pondéré completion/flow/vitesse
- Tests:
  - accès non-admin refusé
  - réponse admin valide avec données injectées
- Files:
  - `services/backend/app/services/auth_admin_service.py`
  - `services/backend/app/schemas/auth.py`
  - `services/backend/app/api/v1/endpoints/auth.py`
  - `services/backend/tests/test_auth.py`

### F-26 (MAJEUR) — Qualité onboarding par cohorte (A/B + plateforme)
- Symptom:
  - score onboarding global utile mais insuffisant pour piloter les variantes A/B.
- Fix backend:
  - nouvel endpoint admin protégé (`@mint.ch`):
    - `GET /api/v1/auth/admin/onboarding-quality/cohorts?days=30`
  - breakdown par cohorte:
    - `variant` (depuis event_data)
    - `platform` (ios/android/etc.)
  - métriques par cohorte:
    - sessions started/completed
    - completion rate
    - avg completion seconds
    - avg step duration seconds
    - quality score (0..100)
- Tests:
  - réponse cohorte avec jeux d’événements multi-variants et plateformes
- Files:
  - `services/backend/app/services/auth_admin_service.py`
  - `services/backend/app/schemas/auth.py`
  - `services/backend/app/api/v1/endpoints/auth.py`
  - `services/backend/tests/test_auth.py`
