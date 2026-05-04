# Storyboard onboarding MVP wedge — décisions LOCKED (2026-04-22)

**But de ce doc :** survivre à la compaction de contexte. Toutes les décisions tranchées à ce stade pour que le panel final + le code n'aient pas à re-demander.

## Doctrine locked (ne pas rediscuter)

- **Doctrine valeur continue** (pas d'aha forcé) — Panel 1 + 2 (2026-04-21). Ref : `ONBOARDING-DOCTRINE-V2.md`.
- **MINT retient tout** — la mémoire longue EST la valeur produit. Ref mémoire : `feedback_mint_retains_everything.md`. Pas de « je ne note rien ».
- **Pas de défensive dans la promise** — zéro « je ne X pas ». Julien rejette les négations.
- **Grammaire Chat Vivant 3 niveaux** — `.planning/handoffs/chat-vivant-2026-04-19/01-vision.md` (insight inline N1 / scène projetée N2 / canvas plein écran N3).
- **Dossier strip** — bande qui se densifie ligne par ligne, visible dès le tour 2.
- **Registre voix** — Chloé / Aesop / Wise / Arc / Linear / Things 3. Direct, intime, jamais familier, zéro emoji, zéro « ! ».
- **Anti-jargon** — aucun mot LSFin banni (garanti / optimal / meilleur / certain / assuré / sans risque / parfait). Jargon suisse (LPP, 3a, AVS) défini inline en ≤ 12 mots ou reformulé.

## Décisions copy LOCKED

### Landing CTA
- **« Parle à Mint »** → route vers `/onb` quand `FeatureFlags.enableMvpWedgeOnboarding = true` (défaut true)

### Opener tour 1 — LOCKED
- Titre : **« Il est temps que tu saches. »**
- CTA : **[Ouvrir]**
- Justification panel 2 (2026-04-22) : registre manifeste responsabilisant, esprit « own your financial life », 6 mots secs, kinky au sens de révélation intime.
- Cf `OPENER-PHRASES-PANEL2.md` (gagnant : phrase #2 « Il est temps que tu saches »).

### Tour 5 — Revenus — LOCKED
- Question : **« Combien te tombe net par mois ? »**
- Input primaire : slider par tranches de **500 CHF** (sélecteur rapide `3k · 3.5k · 4k · … · 15k+`)
- Option secondaire : lien micro *« Je sais le chiffre exact »* → TextField numérique
- Hint ligne 2 : *« On remontera au brut pour les calculs. Tu préciseras au scan de ta fiche ou ton certificat LPP. »*
- **Pas de champ brut** au tour 5 (trop abstrait pour l'user).
- Stockage : `net_monthly_range` (fourchette) ou `net_monthly` (exact) + `confidence: medium` (estimate) ou `high` (exact).
- Conversion côté calculateur : `brut ≈ net × 1.17` (moyenne AVS 5.3 + LPP ~7.5 + LAA/IJM ~1-3 pour salarié suisse 34 ans).
- Upgrade de confidence : scan fiche de salaire ou certificat LPP → `high` / `very_high`.

### Dossier strip (bande qui se densifie)
- Ancrée en bas, visible dès tour 2.
- Chaque tour ajoute une ligne signée (label · valeur).
- Ordre chrono des tours (pas alpha).
- Déjà codée dans `onboarding_shell_screen.dart` + `dossier_strip.dart` (PR #378). À adapter à la nouvelle chronologie.

## Décisions narratives LOCKED

### Principe chronologique
**Règle dure** : à chaque tour, MINT ne montre que ce que l'user lui a donné **jusqu'à ce tour**. Pas avant. Zéro chiffre héros personnalisé avant que les 3-4 data nécessaires soient collectées. Pas de teaser supposant des données non-collectées (erreur corrigée après panel 3).

### Flow principal (intent retraite) — squelette pré-panel
| Tour | MINT dit | User | Dossier gagne |
|---|---|---|---|
| 1 | « Il est temps que tu saches. » [Ouvrir] | Tap | — |
| 2 | « Qu'est-ce qui t'amène ? » + **3-4 intents** | Tap 1 intent | **Intent** |
| 3 | « Pour t'en parler j'ai besoin de ton âge. » | Saisit âge | **Âge** |
| 4 | « Où tu habites ? » | Tap canton | **Canton** |
| 5 | « Combien te tombe net par mois ? » | Slider / saisie | **Revenu net mensuel** (confidence:medium) |
| 6 | **Premier chiffre héros avec intervalle** + scène N2 | Interagit avec slider scène | Scène archivée si canvas fermé (N3) |

### Intents au tour 2 (à finaliser par panel)
Candidates (pas encore tranchés) :
- « Ma retraite »
- « Acheter (appart / maison) »
- « Mes impôts »
- « Mes dettes »
- « J'ai un doute sur un choix » (fourre-tout)
- « Je regarde pour voir »

Le panel final tranche : combien d'intents (3 ou 4), lesquels, ordre d'affichage.

### Explorer tab — LOCKED (panel 3)
- Caché au démarrage (3 tabs : Aujourd'hui / Mon argent / Coach).
- Apparaît après la **1ère fermeture d'un canvas N3** (pas N2, pas 3 scènes).
- Rituel coach : *« Je range ce que tu viens de voir dans Explorer. »*
- Slide-in 400ms + haptic light iOS + pastille 24h.
- Contenu : archive chrono inverse des canvases fermés, tap = restore state (sliders + hypothèses exactes).
- Réfs : Arc Archive + Things Logbook.

## Décisions techniques LOCKED

### Route
- `/onb` (ScopedGoRoute scope:public) déjà wired.

### Feature flag
- `FeatureFlags.enableMvpWedgeOnboarding = true` (défaut).

### Provider d'état
- `OnboardingProvider extends ChangeNotifier` (existe déjà dans PR #378).
- À étendre pour : intent, revenu fourchette, confidence par champ.

### Tests anti-façade
- Widget test `integration_test` style qui simule tap + enter text + vérifie dossier.
- Exigé 3/3 green avant merge.

### Build iOS sim
- Workaround Tahoe : `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" -derivedDataPath ios/build CODE_SIGNING_ALLOWED=NO`.
- **NE PAS** `flutter clean` ni `rm -rf ios/build` (détruit le cache Tahoe-toléré — cf mémoire `feedback_ios_build_macos_tahoe.md`).

### Calculateurs utilisés
- `financial_core/avs_calculator.dart` — computeMonthlyRente
- `financial_core/lpp_calculator.dart` — convertCapitalToRente (taux 6.8% oblig, 5.4% suroblig)
- `financial_core/pillar_3a_calculator.dart` — rendement + cumulé
- `financial_core/retirement_tax_calculator.dart` — impôt sur retrait
- **Tout nouveau calcul doit passer par `financial_core/`**. Règle #3 CLAUDE.md.

## PRs en cours (état au 2026-04-22)

- [#378](https://github.com/MINT-IA/MINT/pull/378) — MVP wedge v1 (7 écrans) — base dev — **sera dépassé par storyboard v2 après panel final**
- [#379](https://github.com/MINT-IA/MINT/pull/379) — Copy polish (opener promise + chips grammaire) — base dev
- [#377](https://github.com/MINT-IA/MINT/pull/377) — Hotfix create_all + migration magic_link_tokens — mergé main

## Ce qui reste à trancher (pour le panel final)

1. **Combien d'intents au tour 2** — 3 ou 4 ?
2. **Lesquels** parmi : retraite / achat / impôts / dettes / choix / lurk ?
3. **Ordre de collecte data tours 3-5** — âge → canton → revenu (proposé) vs autre ?
4. **Intent → data path** — chaque intent demande-t-il les mêmes data ou différentes ? (ex: intent « achat » a-t-il besoin de l'âge ou pas ?)
5. **Moment de l'apparition scène N2** — tour 6 (après 4 data) ou plus tôt si intent le permet ?
6. **Login rituel** — où ? (après scène N1 satisfaite ? après 1 canvas N3 fermé ? jamais en onboarding ?)
7. **3 flow complets à écrire** (retraite / achat / fiscalité) tour par tour avec calculateur cible et premier chiffre héros.

Le panel final tranche ces 7 points et produit le storyboard exécutable.
