# AUDIT 04 — Charge cognitive & calibration System 1 / System 2

> Auditeur : cognitive scientist ex-Stanford D.School + ex-Nudge Unit UK
> Date : 2026-04-19 — commit `f35ec8ff` (dev tip), branche `feature/wave-c-scan-handoff-coach`
> Méthode : lecture des 7 flows principaux + croisement MINT_IDENTITY §5 + VOICE_SYSTEM §2 + anti-shame doctrine.

---

## 1. Verdict global

**MINT est globalement mal calibré : System 1 là où il faut System 2, System 2 là où il faut System 1.**

Les deux entrées (landing + anonymous intent) sont **correctement S1** (un mot, 6 pills, texte libre — zéro friction). Mais dès que l'user entre dans le coach ou un simulateur, la courbe s'inverse brutalement :

- Le **coach chat ouvre sur un chiffre brut** (`coach_chat_screen.dart:434-447` — silent opener = "Avoir LPP 70'377 CHF") sans narrative, forçant une interprétation S2 alors que le user est en exploration S1.
- Les **simulateurs de décision irréversible** (rachat LPP 1143 lignes, EPL 800 lignes, rente vs capital 2'096 lignes) sont **des murs de sliders** qui se recalculent en live et **écrivent dans le profil sans confirmation** (`rachat_echelonne_screen.dart:236-294` : chaque drag de slider → `_onInputChanged` → `_writeBackResult` → écriture date `dateRachats` qui déclenche le blocage EPL 3 ans ATF 142 II 399 — **décision juridique irréversible en mouvement de pouce, zéro guard**).
- L'**Aujourd'hui screen** ouvre sur 3 tension cards + Cap banner + timeline dans une même vue (`aujourdhui_screen.dart:156-200`) — **lecture S2 forcée au cold-start**.

**MINT respecte le toilet test (§MINT_IDENTITY L56-61) sur les surfaces d'entrée, puis l'oublie dès que l'enjeu monte.**

---

## 2. Cinq flows où MINT force System 2 quand il faut System 1

### F1 — Coach chat : silent opener = chiffre nu
`coach_chat_screen.dart:508-580` (`_computeKeyNumber`) + `:419-447` (`_addInitialGreeting`).
L'user arrive en curiosité exploratoire. MINT lui plante un chiffre ("70'377 CHF — Avoir LPP") sans narrative couche 2/3/4 (MINT_IDENTITY L68-96). Le cerveau doit inférer seul : "bon/mauvais ? comparé à quoi ?". C'est le contraire de la promesse "éclairer les implications" — c'est un chiffre orphelin. **Fix** : ajouter couche 2 en une phrase ("C'est ce que ta caisse te montre aujourd'hui. On regarde ce que ça veut dire ?").

### F2 — Aujourd'hui : 3 tensions + Cap + timeline, ouverture froide
`aujourdhui_screen.dart:156-220`. Au cold-start post-scan, l'user reçoit simultanément : CapDuJourBanner + 3 TensionCardWidget + CleoLoopIndicator + timeline de mois. **4 loci d'attention concurrents**, chacun exigeant un S2. Norman (Design of Everyday Things p.89) : "more than 1 decision per screen = paralysis". **Fix** : progressive disclosure — Cap unique d'abord, tensions dépliables à la demande.

### F3 — Anonymous pill → chat vide
`anonymous_intent_screen.dart:90-93` (`_navigateWithPrompt`). L'user tappe "J'évite d'y penser" (S1, pulsionnel). Il arrive sur `/anonymous/chat?intent=...` → le coach **doit** répondre avec du contenu chaud. Si le LLM est froid ou BYOK absent, silence. **Le geste S1 tombe dans un vide S2**. **Fix** : pré-charger un opener local pour chaque pill (6 réponses ARB, zéro réseau).

### F4 — Extraction review : 8+ fields éditables en une vue
`extraction_review_screen.dart:101-104` (`.._fields.map` — pas de chunking). LPP certificate = 8-12 fields avec confidence badges ET seuils différents (0.80/0.90/0.95 — `:42-57`). L'user vient de scanner en 10 sec (S1), et doit maintenant **auditer 10 chiffres**. Kahneman : charge S2 max ≈ 4 items. **Fix** : afficher d'abord uniquement les fields < seuil (review focalisée), le reste en accordion "Tout vérifier".

### F5 — Onboarding intent → chat → silent opener du chiffre
`coach_chat_screen.dart:337-344` (topic=='onboarding' → envoie "Salut, je viens de créer mon compte"). Puis silent opener impose un chiffre. **Trois transitions S2 en 30 secondes** sur un user fresh. Violation directe MINT_IDENTITY L40 ("prise immédiate"). **Fix** : onboarding → opener en mots, pas en chiffres, puis chiffre à la 3e interaction.

---

## 3. Trois flows où MINT donne System 1 quand il faut ralentir

### S1→S2-A — Rachat LPP échelonné : slider = décision juridique
`rachat_echelonne_screen.dart:236-294`. Chaque déplacement de slider → `_writeBackResult` → `dateRachats` ajouté + SnackBar "Profil mis à jour" — **zéro confirmation**. ATF 142 II 399 + LPP art. 79b al. 3 : la date de rachat **bloque tout EPL pendant 3 ans**. L'user a tapé sans intention. **C'est la définition de System 1 où il faut System 2.** **Fix critique** : séparer "simulation" (live, no-write) et "enregistrer un rachat réel" (bouton explicite + dialog 3 sec).

### S1→S2-B — EPL combined : bouton "Continuer" unique sur retrait 2e pilier
`epl_combined_screen.dart` (800 lignes) : flow slider → résultat → CTA unique. Le retrait EPL = taxe LIFD art. 38 **immédiate** + avoir LPP amputé à vie + blocage. Pas de pre-mortem ("tu es sûr ? voici ce que ça te coûte") avant la suite. **Fix** : ajouter un écran "Et si tu te trompais ?" — 3 points factuels (montant taxé, rente LPP réduite, non-réversible sauf revente) avant toute action.

### S1→S2-C — Voice intensity chip "Brut" en tap unique
`coach_chat_screen.dart:624-663` + `:665-710`. L'user peut passer de "Tranquille" (niveau 1) à "Brut" (niveau 5) en un tap. Niveau 5 = ton cash, tutoiement direct sur ton argent. Le setting **persiste** (`_saveCashLevel`). **Fix** : pour les sauts de +2 niveaux, interstitiel "tu veux qu'on te parle plus sec dès maintenant ?" + preview d'une phrase.

---

## 4. Anti-shame doctrine : copies / flows qui activent la honte-défense

MINT_IDENTITY §Principe 2 L33-34 : "Mint ne donne jamais l'impression que l'utilisateur est en retard". Violations :

1. **`coachSilentOpenerFitnessScore: "Score de santé financière"`** (`app_fr.arb:10267`) : un score /100 en ouverture = comparaison implicite à "100". Même si aucun benchmark social, le chiffre seul active la honte ("j'ai que 47"). **Fix** : "Voici ta photo du jour" sans dénominateur.
2. **`coachSilentOpenerReplacementRate: "Taux de remplacement projeté"`** (`app_fr.arb:10266` consommé `coach_chat_screen.dart:549-562`) : un taux < 60% plante une anxiété retraite avant toute conversation. Violation §16 anti-pattern CLAUDE.md ("Frame MINT as retirement app"). **Fix** : neutraliser en "Ce que tu gardes en vivant de tes revenus prévus" + disclaimer hypothèse.
3. **`tensionEmptyWelcome: "Commence par parler au coach."`** (`app_fr.arb:11341`) : impératif ("Commence") = injonction parentale. **Fix** : "Quand tu veux, on commence." ou question ouverte.
4. **`intensityAdjustedUp` / intensité "Brut"** : le libellé suggère que "tranquille" est moins bien. Hiérarchie implicite = shame-trigger pour qui choisit le doux. **Fix** : renommer en types ("Posé / Direct / Tranchant") sans escalier numérique.
5. **Onboarding "Salut, je viens de creer mon compte. Par ou je commence ?"** (`coach_chat_screen.dart:342`) : injecté comme message user **à la place de l'user** = le coach répond comme si l'user l'avait demandé, créant une faille (l'user lit sa propre voix parler à sa place). Détail mais rompt la confiance S1.

---

## 5. Cinq nudges / micro-gestures qui manquent

1. **Rachat LPP / EPL — délai de réflexion 3 sec** : tap sur "Enregistrer ce rachat" → overlay semi-transparent avec countdown 3 sec + texte "Décision irréversible pendant 3 ans. Continuer ?" (pattern Thaler *active choice + cooling-off*). Empêche les décisions pouce-réflexe. Applicable : `rachat_echelonne_screen.dart`, `epl_screen.dart`, `epl_combined_screen.dart`.

2. **Coach silent opener — phrase couche 2 obligatoire avant chiffre** : la règle `MINT_IDENTITY L68-96` (4 couches) doit se traduire en contrat. Impossible d'afficher un nombre en ouverture sans une ligne "ce que ça veut dire". Hook dans `_computeKeyNumber` → retourner `({number, headline, implication})` avec `implication` requis.

3. **Scan → extraction review — chunk de 3 fields max** : montrer d'abord les 1-3 fields à faible confidence (S2 ciblé), puis "Les 7 autres sont OK. Voir quand même ?" (progressive disclosure Norman). Rendra le gate à 30 sec au lieu de 2 min.

4. **Pill tap sur anonymous intent — opener local préloadé** : pour chaque pill ARB (`anonymousIntentPill1..6`), une réponse-coach statique de 2 phrases stockée en ARB, délivrée avant tout appel réseau. Le geste S1 reste fluide même si LLM down. Fichier à créer : `lib/services/coach/anonymous_local_openers.dart`.

5. **Aujourd'hui — focus mode cold-start** : au premier chargement du mois, afficher **uniquement** le Cap du jour plein écran (geste S1 unique : lire + tap). Les TensionCards apparaissent au scroll. Pattern Apple Weather / Things 3. `aujourdhui_screen.dart:156-220` à refactorer en 2 states : `CapFullscreen` → `TimelineFull` sur swipe.

---

## 6. Refonte de la courbe cognitive cold-start → first insight

**État actuel** (mesuré) : 6 gestes S1 + 4 transitions S2 en ~90 sec → user saturé avant premier insight utile.

**Cible** (Kahneman-compatible) : **pic S1 unique au démarrage, 1 seule décision S2 avant le premier insight, S2 ciblé ensuite**.

```
Landing (1 mot, 1 CTA)                    → S1 ✓ [4 sec]
  ↓
Anonymous intent (6 pills + texte libre)  → S1 pur [8 sec]
  ↓ [pill tap]
Anonymous chat — opener local préchargé   → S1 [user lit, zéro demande]
  ↓ [user tape 1 réponse]
Coach remonte profil partiel              → transition S1→S2 douce
  ↓
PREMIER INSIGHT (couche 1+2, UN chiffre + UNE phrase implication)  → S2 ciblé, 1 item
  ↓
Question ouverte "tu veux qu'on creuse ?" → user choisit le rythme
  ↓ [user opt-in]
Scan optionnel / simulateur / fact-entry  → S2 choisi, pas imposé
```

**Quatre règles de design cognitif à ajouter à `VOICE_SYSTEM.md` §2** :

1. **Rule of One** : un écran = un chiffre maximum en cold-start.
2. **Couche 2 obligatoire** : aucun nombre affiché sans sa phrase d'implication (enforcé par contrat type).
3. **S2-gate sur irréversible** : toute écriture profil qui déclenche une règle juridique (dateRachats, EPL, retrait 3a) passe par un dialog 3 sec + libellé de l'implication.
4. **Progressive disclosure par défaut** : plus de 3 items simultanés → accordion. Applicable à tension cards, extraction review, simulateurs.

---

## Fichiers cités

- `apps/mobile/lib/screens/landing_screen.dart:85-210`
- `apps/mobile/lib/screens/anonymous/anonymous_intent_screen.dart:66-93, 177-213`
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart:337-344, 419-447, 508-580, 624-710`
- `apps/mobile/lib/screens/aujourdhui/aujourdhui_screen.dart:156-220`
- `apps/mobile/lib/screens/lpp_deep/rachat_echelonne_screen.dart:236-294, 722-730` (ex-1143 l total)
- `apps/mobile/lib/screens/lpp_deep/epl_screen.dart` (800 l)
- `apps/mobile/lib/screens/mortgage/epl_combined_screen.dart`
- `apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart` (2'096 l)
- `apps/mobile/lib/screens/document_scan/extraction_review_screen.dart:42-57, 101-104`
- `apps/mobile/lib/l10n/app_fr.arb:10266-10280, 11196-11225, 11341-11346`
- `docs/MINT_IDENTITY.md` L33-34, L40, L56-61, L68-96
- `docs/VOICE_SYSTEM.md` §2 axes

---

**Mot de la fin** : MINT promet "éclairer pour que tu décides". Aujourd'hui, MINT **affiche des chiffres pour que tu interprètes**, et **laisse glisser des décisions juridiques pendant que tu explores**. Les deux dérives sont symétriques. Corriger l'une sans l'autre = garder le déséquilibre.
