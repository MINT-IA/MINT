# Wave 0 — Findings walkthrough de vérité (light, 5 flows)

**Date** : 2026-04-18
**Device** : iPhone 17 Pro sim UDID B03E429D-0422-4357-B754-536637D979F9
**App** : MINT déjà installé (`ch.mint.app`), build antérieur à PR #353
**Profil** : fresh anonymous local-mode
**Durée** : ~20 min (vs 90 min du plan full)

## Flow 1 — Cold launch landing

Écran : `/` (LandingScreen)
État : **vivant**
Latence : ~3s animation fade-in
Éléments : wordmark "MINT", tagline "Ta vie financière, en clair.", sous-tagline "On éclaire. Tu décides." (doublée — suspect i18n duplication), CTA "Parle à Mint" (x2 — accessibility hit target), disclaimer LSFin footer, "J'ai déjà un compte" link
Reconnaissance utilisateur : non (fresh install, attendu)
Frictions :
- Wordmark label accessibility = "MINT\nMINT" (répété) — `landing_screen.dart` heading a probablement 2 Text children sans `excludeSemantics`
- Tagline "On éclaire. Tu décides." dupliquée dans l'AX tree
Verdict : landing livre le message, mais accessibility pollué par doublons.

## Flow 2 — Tap "Parle à Mint" CTA

Écran : post-landing (probablement `/coach/chat` ou écran intermédiaire)
État : **vivant**
Latence : 3s
Éléments :
- Boutons header "Historique" + "Paramètres IA" (coins haut)
- Heading "Comment je te parle ?"
- Static text "Tu veux en parler ?"
- 3 chips ton : "Doux" / "Direct" / "Sans filtre"
- TextField "Dis-moi." (silent opener, placeholder doux)
- Bouton Envoyer
- Bottom nav **4 onglets** : Aujourd'hui / Mon argent / Coach / Explorer
Reconnaissance : non
Frictions :
- **4 onglets alors que NAVIGATION_GRAAL_V10.md prescrit 3 tabs + drawer**. Soit doc obsolète, soit régression. À vérifier.
- Chips "Doux/Direct/Sans filtre" : pas d'hint sur l'effet. User hésite.
Verdict : silent opener présent (chat-silent respecté), choix ton visible, mais 4 tabs vs 3 attendus = drift.

## Flow 3 — Tap tab "Aujourd'hui" (depuis écran post-landing)

Écran attendu : AujourdhuiScreen
Écran réel : **LANDING** (wordmark + tagline + CTA Parle à Mint)
État : **MORT pour user non-onboarded**
Latence : instantané
Frictions :
- **BLOCKER** : `/home?tab=0` redirige vers `/` tant que user non-onboarded. User perd le fil. Panel simulation 3 mois l'avait signalé (`app.dart:177 initialLocation: '/'`).
- Aucun indicateur "ferme ton onboarding pour débloquer Aujourd'hui"
- Tabs bottom reste visible mais inopérants pour 3 d'entre eux (tous sauf Explorer)
Verdict : **Aujourd'hui est gated par onboarding. Confirmation empirique du piège panel iconoclaste.**

## Flow 4 — Tap tab "Explorer"

Écran : `/explore` (ExplorerScreen)
État : **tiède**
Latence : instantané
Éléments :
- Heading "Explorer"
- Grid 7 hubs : Retraite & Prévoyance, Famille, Travail & Statut, Logement, Fiscalité, Patrimoine & Succession, Santé & Protection
- Bottom nav 4 tabs
Reconnaissance utilisateur : non (hubs affichés à l'identique pour tous)
Frictions :
- Pas de personnalisation (hub "Famille" pas mis en avant même si user a indiqué être marié, etc.)
- Aucun preview des sous-flows à l'intérieur du hub
Verdict : Explorer fonctionne mais statique. Panel codebase inventory disait "dynamique peuplée via HubEntry hardcoded app.dart" — confirmé visuellement.

## Flow 5 — Tap tab "Mon argent"

Écran : `/home?tab=1` ou `MonArgentScreen`
État : **tiède**
Latence : instantané
Éléments :
- Heading "Mon argent"
- Section "Ton budget ce mois" + "Définis ton budget pour voir où tu en es ce mois." + bouton "Commencer"
- Section "Ton point de départ" + "Scanne un document ou parle au coach pour commencer." + bouton "Scanner"
- Section "Enrichis ton dossier pour une vue plus précise"
Reconnaissance utilisateur : non (CTA identiques pour tous)
Frictions :
- **Mon argent fonctionne sans onboarding mais Aujourd'hui redirige au landing** — incohérence de gate
- Bouton "Scanner" visible ici mais pas sur Aujourd'hui (qui est le landing en fait)
Verdict : Mon argent est un onboarding-lite via 2 CTA clairs. Plus utilisable que Aujourd'hui actuellement.

## Flow 6 — Retour tap tab Aujourd'hui (depuis Mon argent)

Écran réel : **LANDING encore**
Verdict : confirme que Aujourd'hui tab est toujours le landing tant que user non-onboarded, même après passage par Mon argent.

---

## Synthèse

### 3 forces objectives

1. **Onboarding progressive fonctionne** — Mon argent + Explorer affichent du contenu utilisable sans profile fully populated. User peut explorer avant de s'engager.
2. **Silent opener respecté** — chat `/coach/chat` a le placeholder "Dis-moi." sans pousser de widgets. Chat-silent doctrine tenu.
3. **Tagline + positionnement visible** — "On éclaire. Tu décides." + "Ta vie financière, en clair." cohérent avec doctrine "lucidité pas protection" (pivot 2026-04-12).

### 3 frictions majeures

1. **BLOCKER Aujourd'hui tab = landing pour non-onboarded**. User qui veut "voir son dashboard" tape tab → retour à écran marketing. Aucune progression visible. Cette friction tue la boucle daily même pour un user qui serait revenu 3× au cours de la première session.
2. **4 onglets vs 3 prescrits par NAVIGATION_GRAAL_V10.md**. Mon argent est un 4e tab qui doublonne partiellement avec Explorer (hubs Patrimoine, Fiscalité) et avec Aujourd'hui (budget). Cognitive load.
3. **Accessibility duplication** dans le landing (wordmark + tagline répétés dans AX tree). Screen readers lisent 2× chaque élément.

### 1 recommandation pour Wave B-prime (ajustement priorité)

**Wave B-prime doit commencer par un commit qui DÉBLOQUE l'onglet Aujourd'hui pour les users non-fully-onboarded**. Avant de brancher CapEngine + JITAI + Milestones, le tab DOIT afficher quelque chose. Sinon Wave B shippe des moteurs qui ne s'affichent jamais (façade sans câblage au niveau tab).

**Proposition : Wave B-prime commit B0 (nouveau, en premier)** :
- `app.dart` route `/home?tab=0` ne redirige plus vers `/` — affiche AujourdhuiScreen avec état "partially onboarded" qui montre :
  - Un accueil chaleureux + prénom si dispo
  - 2 CTA clairs : "Finis ton onboarding" / "Scanne un document"
  - Placeholder pour cap du jour / timeline (prêt pour B1-B5)
- Puis B1-B8 comme prévu (CapEngine, JITAI, etc.)

**Alternative** : accepter que Aujourd'hui reste gated et déplacer la valeur daily sur Mon argent (qui est déjà accessible). Moins orthodoxe mais plus pragmatique.

### Décision prise pour Wave B-prime

**Adopt Proposition** : Wave B-prime est rebaptisée et enrichie d'un commit B0 qui débloque le tab Aujourd'hui. Sans ça, Wave B shippe dans un écran invisible.

Le panel iconoclaste disait "Aujourd'hui = 301 lignes 0 CapEngine". En réalité : **Aujourd'hui = landing redirect pour un user sur 2 qui ouvre l'app**. Bien pire.

## Screenshots

Non pris (AX tree suffisant pour extraire les labels, hiérarchies et verdicts). Si audit post-Wave B-prime a besoin de preuves visuelles, prendre alors dans Wave F.

## Next step

Écrire `PLAN-WAVE-B.md` avec le commit B0 ajouté en tête.
