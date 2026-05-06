# MINT — Walk humain bout-en-bout

**Date :** 2026-05-06 19:37 Europe/Zurich
**Walker :** Claude (via xcrun simctl + idb sur iPhone 17 Pro sim, iOS 26.2)
**Build :** flutter --debug, dart-defines minimaux : `API_BASE_URL=https://mint-staging.up.railway.app/api/v1` + `MINT_DISABLE_BETA_MODAL=true`. **AUCUN** `MINT_E2E_*` flag, **AUCUN** `MINT_LLM_CACHE_MODE`. Sim erased fresh.
**Backend :** Railway staging réel, Anthropic Claude Sonnet appelé à chaque turn.
**Méthode :** je tape comme un humain, je note plat ce que je vois, screenshots dans `.planning/phases/A-USER-WALKTHROUGH/screenshots/`.

---

## Étape 01 — Cold launch : ✅ PASS

J'ouvre l'app. Landing s'affiche en ~1s.
- Wordmark `MINT` en haut à gauche
- Hero italique « *Voir clair, décider seul.* »
- CTA noir bas-page : « Parle à Mint »
- Lien : « J'ai déjà un compte »
- Footer LSFin : « Outil éducatif. Ne constitue pas un conseil financier au sens de la LSFin. »

Beta modal absent grâce à `MINT_DISABLE_BETA_MODAL=true`. Visuellement propre. ✅

---

## Étape 02 — Tap CTA → Anonymous chat opener : ✅ PASS

Tap « Parle à Mint ». Navigation immédiate vers l'écran chat anonyme.
- Back arrow ←
- Bulle coach (gauche) : « Salut. Dis-moi ce qui te trotte en tête côté finances en ce moment — un projet, une question, un truc flou. »
- 3 chips suggestions : « J'ai un projet d'achat », « Je change de boulot », « Je... » (3e tronqué hors viewport)
- Footer : « Information générale, pas un conseil financier personnalisé. »
- Input : « Écris ce qui te trotte en tête... » + send paper-plane

Tone juste, pas trop chaud, pas trop froid. ✅

---

## Étape 03 — Turn 1 : ✅ PASS avec 🚨 BUG #1

**Je tape :** « J'ai 35 ans, je suis salarie en Suisse, j'aimerais comprendre mon 3e pilier »
**LLM répond en ~10s** (Claude Sonnet via Railway staging) :

> « À 35 ans, ton 3e pilier contient déjà probablement une asymétrie invisible : chaque franc versé aujourd'hui pèse plus lourd que celui versé à 50 ans, car il capitalise 2 fois plus longtemps. Pourtant, la plupart des gens ne le saturent qu'après 40 ans, quand ils « ont plus de moyens ».
>
> La seconde couche : tu paies l'impôt maintenant sur ton salaire, mais le 3e pilier te permet de déduire environ **7'000 francs par an (3a)**, soit une économie fiscale immédiate de **1'500 à 2'500 francs selon ton canton et ton taux marginal**. C'est l'un des rares leviers où l'État suisse te rend de l'argent directement.
>
> Tu connais ton taux d'imposition marginal actuel ?
>
> _Outil éducatif simplifié. Ne constitue pas un conseil financier (LSFin). Consulte un·e spécialiste pour une analyse personnalisée._ »

### 🚨 BUG #1 — LLM hallucine la constante 3a

Le LLM dit **« 7'000 francs par an »**. La constante OPP3 art. 7 (2026) = **7'258 CHF** (`apps/mobile/lib/constants/social_insurance.dart:351 → pilier3aPlafondAvecLpp = 7258.0`).

Le LLM arrondit à un nombre rond mémorisé (probablement de son training set < 2026). **Le system prompt n'injecte PAS la constante via la lib financial_core / RegulatoryRegistry**.

**Sévérité :** P1. Une réponse erronée sur le plafond 3a est exactement le genre de chiffre qui finit en screenshot Twitter avec « MINT donne le mauvais chiffre LSFin-grade ».

**Fix probable :** dans `services/backend/app/services/coach/anonymous_chat_prompt.py` (ou équivalent), injecter au system prompt :
```
SWISS_CONSTANTS_2026:
- pilier_3a_max_avec_lpp_chf: 7258
- pilier_3a_max_sans_lpp_chf: 36288
- ...
```
Et instruire le LLM : « Toujours citer ces valeurs littérales si la conversation concerne ces piliers, jamais les arrondir ni les paraphraser. »

---

## Étape 04 — Turn 2 : ⚠️ MIXTE — réponse cohérente mais 3 bugs

**Je tape :** « Mon taux marginal je sais pas exactement, dans le canton de Vaud avec 95k brut »

### 🚨 BUG #2 — iOS autocorrect mange le prompt

**Ce qui est arrivé en bulle :** « Mon **faux** marginal **he said** pas exactement, dans **lie** canton de Vaud **ave** 95k brut »

L'autocorrect iOS a transformé `taux→faux`, `je→he said`, `le→lie`, `avec→ave`. **Pas un bug MINT mais un bug UX réel** que vivra chaque utilisateur français qui tape vite.

**Sévérité :** P2. Mitigation possible :
- Le TextField devrait `autocorrect: false` côté Flutter, OU
- Une langue `keyboardType: TextInputType.text` avec `textCapitalization: TextCapitalization.none` et un IME français bien configuré.

### Réponse Claude (cohérente malgré le prompt cassé) :

> « Avec 95k brut à Vaud, ton taux marginal effectif tournait probablement autour de **35-38%** l'année dernière (Confédération + Canton + Commune). Ce qui surprend : chaque franc supplémentaire que tu gagnerais ne serait pas taxé à ce taux, mais au suivant la progression.
>
> Concrètement, si tu négocais 5k de plus, tu en garderais environ **3100-3250 nets** — moins que la moitié perdue, contrairement à ce qu'on imagine souvent à ce palier.
>
> Ce qui t'intéresse : **optimiser** ce qui reste, ou d'abord comprendre où partent précisément ces 35-38% ? »

### 🚨 BUG #3 — banned-term « optimiser »

Le LLM emploie **« optimiser »** dans la dernière phrase. « optimiser » est borderline avec « optimal » dans la blacklist LSFin (CLAUDE.md règle 1 : « optimal » est explicitement banni).

**Sévérité :** P2. La blacklist actuelle ne couvre que la racine `optimal*` exacte ; il faut élargir à `optimis*`. Mon regex L2 hardening (julien_swiss_test.dart) a justement `(?!isation|iser|isant|isé)` qui exclut « optimiser » par design car il est jugé légitime — **erreur de jugement**. À corriger : LSFin lit la racine sémantique, pas la flexion morphologique. Il faut bannir TOUT `optim*` sauf `optimum` quand cité comme constante mathématique.

### 🚨 BUG #4 — CARTE ÉCLAIRAGE NE REND PAS AU TURN 2

Per [services/backend/app/api/v1/endpoints/anonymous_chat.py:287](services/backend/app/api/v1/endpoints/anonymous_chat.py#L287) :

```python
eclairage: Optional[EclairagePayload] = None
if new_count >= 2 and not anon_session.eclairage_delivered:
    eclairage = build_default_fiscal_margin_3a_eclairage()
    anon_session.eclairage_delivered = True
```

→ Au turn 2, la carte hardcoded « Marge fiscale 3a non utilisée » DEVRAIT s'émettre.

**Constaté à l'écran :** AUCUNE carte. Juste la bulle texte. **C'est exactement le « mur » que Julien a décrit.**

**Hypothèses :**
- (a) `new_count` ne s'incrémente pas correctement entre turn 1 et turn 2
- (b) `anon_session.eclairage_delivered` était déjà true (mais session fresh erase, peu probable)
- (c) Le payload est renvoyé mais le mobile parse mal et drop
- (d) Le backend exception silencieusement avant l'append

**Sévérité :** P0. C'est LA différenciation produit (la SEULE) entre MINT et Claude.com chat — et elle ne rend pas en prod. Vérification urgente : tail Railway staging logs sur `/anonymous/chat` pour ce session id, voir si `eclairage` est dans la response.

---

## Étape 05 — Turn 3 + auth gate : ✅ MIXTE — gate render mais 🚨 BUG #5

**Je tape :** « Comprendre ou partent les 35 pourcent »
**LLM répond** sur un sujet COMPLÈTEMENT DIFFÉRENT :

> « Ah, les fameux **35% de prélèvement anticipé sur les dividendes suisses**. **Voilà ce qu'on oublie souvent** : cet impôt n'est pas une perte si tu déclares tes revenus. C'est un système de traçabilité — la Confédération prélève d'abord, puis te rembourse intégralement si tu es en règle fiscalement. Le vrai piège, c'est pour ceux qui oublient de déclarer : là, les 35% deviennent définitifs.
>
> **Traduction concrète** : sur 1000 CHF de dividendes, tu reçois 650... »

(Réponse coupée par modal d'auth gate qui s'est superposée.)

### 🚨 BUG #5 — Hallucination de sujet

J'avais demandé « où partent les 35% [du taux marginal] » dans le contexte direct du turn 2 (taux marginal Vaud 35-38%). Le LLM a confondu avec **l'impôt anticipé fédéral sur dividendes** (= 35% Verrechnungssteuer, totalement différent — c'est un impôt sur le rendement de capital qui est remboursé si déclaré, pas du tout le taux marginal sur revenu).

**Cause probable :** ambiguïté du « 35% » dans l'écosystème fiscal suisse + manque de contexte de turn dans le system prompt + pas de mémoire conversationnelle structurée injectée.

**Sévérité :** P1. Réponse techniquement correcte sur le sujet qu'IL a choisi, mais SUR LE MAUVAIS SUJET. Un user qui voulait comprendre son taux marginal apprend l'impôt anticipé sur dividendes — friction massive.

**Fix probable :** dans le system prompt, injecter explicitement les turns précédents avec un labeling « Le user vient de demander X au turn N », et un disambiguation gate « Si « X% » mentionné, vérifier le contexte des turns précédents avant d'interpréter ».

### Auth gate ✅ propre :

- Icône bulle de chat
- Texte : « Je peux garder tout ça en mémoire pour toi — il te suffit de créer un compte. »
- CTA primary noir : « Créer un compte »
- CTA secondary outlined : « J'ai déjà un compte »
- Lien text : « Plus tard »

Bonne UX. ✅

---

## Étape 06 — Tap « Créer un compte » → Register : ✅ écran propre, 🚨 BUG #6 + #7

L'écran register s'affiche :
- Title : « Créer ton compte »
- Sub : « Crée un compte chiffré. La synchronisation cloud est désactivée par défaut ; tu peux l'activer depuis Réglages › Confidentialité. »
- 3 bullets : Projections AVS/LPP / Coach personnalisé / Sauvegarde cloud
- Champs : Adresse e-mail / Prénom (compteur 0/50) / Date de naissance / Mot de passe

### 🚨 BUG #6 — Inputs Flutter ne reçoivent pas keystroke external

J'ai tap les inputs via `idb ui tap`, j'ai envoyé du texte via `idb ui text` ET via `osascript -e 'tell application "System Events" to keystroke ...'`. **Aucun caractère ne rentre dans les inputs.**

Cause probable : les TextField Flutter sur iOS sim gèrent leur propre IME. Sans focus keyboard hardware actif côté sim, les events keystroke extérieurs ne routent pas.

**Sévérité :** P2 pour le test infra (E2E auto impossible sur les screens form-heavy sans intervention manuelle). PAS un bug user-facing. Mais ça veut dire que **TOUS les écrans avec form (register, login, onboarding profile, document picker prompt, etc.) ne peuvent PAS être walker-tested automatiquement** sans soit (a) un patch keyboard sim soit (b) un input via clipboard paste piloté par accessibility.

**Fix probable :** activer Connect Hardware Keyboard sur le sim ET utiliser `osascript keystroke` avec System Events ayant la permission Accessibility. OU passer au Maestro `inputText` qui gère ça nativement (Maestro est explicitement conçu pour ce cas).

### 🚨 BUG #7 — Register screen sans back button

Je tap en haut-gauche (zone normalement back arrow). **Rien ne se passe.** L'user est piégé sur l'écran register sans porte de sortie pour revenir au chat anonyme.

**Sévérité :** P1 UX. Un user hésitant qui a juste voulu « tester pour voir » se retrouve forcé vers l'inscription sans option de retour. Ça casse la promesse « Plus tard » du gate.

**Fix probable :** ajouter un AppBar avec leading IconButton(Icons.arrow_back) qui pop la route. 1 ligne dans le widget tree de l'écran register.

---

## Étapes 07-08 — PDF upload + Scénarios : NON TESTÉES

Bloqué par BUG #6 (impossible de remplir les champs register sans keystroke manuel sur le sim). Pour valider la suite (onboarding, premier insight, PDF upload, scénarios), Julien doit ouvrir le sim et taper à la main.

---

## Bilan — 7 bugs en 8 minutes de walk réel

| # | Sévérité | Bug | Effort fix |
|---|---|---|---|
| 4 | **P0** | Carte éclairage hardcoded ne rend pas au turn 2 — la SEULE feature différenciante MINT vs Claude.com | 1-2h debug Railway logs + fix counter ou parse |
| 7 | **P1** | Register screen sans back button — user piégé | 1 ligne Flutter (AppBar leading) |
| 1 | **P1** | LLM hallucine `7'000` au lieu de `7'258` (constante 3a non injectée system prompt) | 30 min : ajouter SWISS_CONSTANTS bloc au system prompt |
| 5 | **P1** | LLM hallucine sujet « 35% » (taux marginal → prélèvement anticipé dividendes) | 1-2h : disambiguation rules dans system prompt |
| 3 | **P2** | Banned-term « optimiser » slip-through (regex `optim*` trop permissif) | 30 min : étendre lexique |
| 2 | **P2** | iOS autocorrect FR mange les prompts financiers | 1h : `autocorrect: false` sur le TextField chat + tester sur un vrai iPhone |
| 6 | **P2** | E2E test infra : inputs Flutter ne reçoivent pas keystroke external | 1-2h : Maestro inputText OU patch sim keyboard |

## Top 3 à fixer demain matin (Julien priorité)

1. **BUG #4 — Éclairage card au turn 2** : ouvrir Railway logs `/anonymous/chat`, tail la dernière session anonyme, voir si `eclairage` est dans le payload réponse. Si oui : bug parsing mobile. Si non : bug counter ou exception backend silencieuse.
2. **BUG #7 — Back button register** : 5 minutes, déblocage UX critique.
3. **BUG #1 — Plafond 3a 7'258 dans system prompt** : 30 min, injecter les constantes Swiss dans le system prompt anonymous_chat. Ça résout aussi la moitié des hallucinations futures sur AVS rente max, LPP coordination, etc.

## Ce qui MARCHE et ne doit pas bouger

- ✅ Build pipeline Flutter → install sim → launch
- ✅ Landing screen typographie + LSFin disclaimer
- ✅ Navigation landing → chat anonyme
- ✅ Opener bubble + chips + input UX
- ✅ Appel Anthropic via Railway staging (~10s p95)
- ✅ Disclaimer LSFin embedded en italique fin de réponse
- ✅ Auth gate UI au turn 3
- ✅ Register screen visual

## Ce qui n'a PAS été testé tonight

- Onboarding post-register (BUG #6 blocant)
- Document/PDF upload + extraction LPP CPE
- Scénarios projection retraite
- Allocation annuelle
- Arbitrage 3a vs LPP rachat
- Frontalier / expat flows
- Login flow (« J'ai déjà un compte »)
- Locale switching FR / DE / EN
- Long-press wordmark MINT → /auth/login (D-12 hidden affordance, jamais walké)

Tout ça reste à walker manuellement par Julien sur son iPhone (TestFlight Internal) cette semaine, par le lean discipline du Solo Founder Veteran panel.

---

**Source :** Phase A-USER-WALKTHROUGH, screenshots `.planning/phases/A-USER-WALKTHROUGH/screenshots/01-cold-launch.png` à `11-back-from-register.png`.
