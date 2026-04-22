# Storyboard onboarding MINT — final locked (2026-04-22)

Panel final de 5 experts — Motion designer fintech (M), Product strategist (P), Info designer (I), Trailer editor (T), Design philosopher (D). 7 décisions tranchées. À coder tel quel.

---

## Décision A — Intents

**Tranché : 4 intents, dans cet ordre : « Ma retraite » · « Acheter un lieu » · « Mes impôts » · « Je regarde ». Format : quatre cartes pleine largeur empilées, 72px de haut, fond `porcelaine`, eyebrow `corailDiscret` (1 mot : RETRAITE / ACHAT / IMPOTS / EXPLORER) + phrase Fraunces 17pt dessous.**

Débat : T voulait 6 intents pour couvrir dettes + couple. D a tranché contre : « 6 cartes = menu déroulant déguisé, MINT n'est pas un portail ». P a verrouillé à 4 en sacrifiant « dettes » (repliable dans retraite+choix) et « choix à faire » (trop abstrait pour T2 — le user ne se dit pas « j'ai un choix à faire », il se dit « je dois choisir entre X et Y »). I a imposé l'ordre de charge émotionnelle : retraite (le plus lourd) → achat (le plus désiré) → impôts (le plus pragmatique) → regarder (la porte de sortie dignifiée). « Je regarde » remplace « lurk » : c'est un intent légitime, pas un aveu. M perd sur le format card vs chip : cartes 72px permettent la phrase Fraunces, chips tueraient le registre éditorial.

Copy exacte des cartes :
1. **RETRAITE** / *« Ce que je toucherai, vraiment. »*
2. **ACHAT** / *« Ce que je peux viser. »*
3. **IMPOTS** / *« Ce que je paie de trop. »*
4. **EXPLORER** / *« Je regarde d'abord. »*

---

## Décision B — Flow commun

**Tranché : âge → canton → revenu net mensuel. Ordre justifié par charge cognitive croissante + chronologie narrative (qui tu es → où tu vis → ce qui tombe).**

Les 3 data sont collectées **quel que soit l'intent** — même « Explorer » les demande (sinon pas de miroir possible). I a verrouillé : ces 3 axes suffisent pour 80% des scènes N2 du catalogue financial_core. P a défendu d'ajouter l'état civil en T4 pour le couple mais D a tranché : couple est un *fait anthropologique* (cf `project_vision_post_audit_2026_04_12`) qui se détecte *dans la conversation*, pas dans un formulaire. Reporté post-T6.

---

## Décision C — Storyboards complets

### Storyboard 1 : Intent « Ma retraite »

| Tour | MINT dit | User fait | Dossier gagne |
|---|---|---|---|
| 1 | « Il est temps que tu saches. » [Ouvrir] | Tap Ouvrir | — |
| 2 | « Qu'est-ce qui t'amène ? » + 4 cartes intents | Tap RETRAITE | **Intent : retraite** |
| 3 | « Quel âge tu as ? » + picker 18–75 | Scroll picker | **Age** |
| 4 | « Où tu vis ? » + liste 26 cantons | Tap canton | **Canton** |
| 5 | « Combien te tombe net par mois ? » + slider 500 CHF | Drag slider | **Revenu net mensuel (fourchette, conf:medium)** |
| 6 | N1 inline : « 63% — c'est ce que tu gardes » (ratio train de vie vs revenu) | Lit, scrolle | **Ratio train de vie (estimé)** |
| 7 | « Tiens, voilà le trou. » + **Scène N2 MintSceneRenteTrouee** | Drag slider espérance de vie | **Age espérance, gap rente estimé** |
| 8 | « On peut le creuser quand tu veux. Je garde tout. » + [Creuser] [Plus tard] | Tap Creuser → canvas N3 ; Plus tard → T9 | **Intention : canvas ouvert / differé** |
| 9 | « Laisse-moi un mail. Je te retrouve demain. » + TextField mail + [Recevoir le lien] | Tape mail ; tap bouton | **Email + magic_link envoyé** |

**Scène N2 finale (T7) — MintSceneRenteTrouee :**
- Calculateur : `financial_core/avs_calculator.computeMonthlyRente` + `financial_core/lpp_calculator.estimateRenteFromSalary` (proxy depuis revenu net → brut via ×1.17)
- Sliders : 1 slider horizontal `age_vie` (70–100, step 1, défaut 85)
- Chiffre héros : **intervalle** `CHF X'XXX - Y'YYY / mois` où X = (AVS+LPP) scénario bas (rendement 1.5%), Y = scénario haut (rendement 3.5%), formule : `(avs_rente + lpp_rente_estimee) × facteur_conf_medium ±8%`
- Phrase de recul Fraunces 17pt : *« À ton âge et ton revenu, c'est ce qui arriverait si tu ne bouges rien. »*
- Eyebrow : « SCENE · ta retraite projetée »
- CTA noir : **[Creuser]**

### Storyboard 2 : Intent « Acheter un lieu »

| Tour | MINT dit | User fait | Dossier gagne |
|---|---|---|---|
| 1 | « Il est temps que tu saches. » [Ouvrir] | Tap Ouvrir | — |
| 2 | « Qu'est-ce qui t'amène ? » + 4 cartes intents | Tap ACHAT | **Intent : achat** |
| 3 | « Quel âge tu as ? » + picker | Scroll | **Age** |
| 4 | « Où tu veux vivre ? » + liste 26 cantons | Tap canton | **Canton cible** |
| 5 | « Combien te tombe net par mois ? » + slider 500 CHF | Drag | **Revenu net mensuel (conf:medium)** |
| 6 | N1 inline : « Ta capacité d'emprunt tient sur 3 chiffres. » + mini-liste (apport · taux · charge max 33%) | Lit | **Compréhension capacité (tag)** |
| 7 | « Ce que tu peux viser. » + **Scène N2 MintSceneCapaciteAchat** | Drag slider apport | **Apport envisagé, prix cible estimé** |
| 8 | « On chiffrera les frais notaire et l'IFD quand tu veux. » + [Creuser] [Plus tard] | Tap choix | **Intention** |
| 9 | « Laisse-moi un mail. Je te retrouve demain. » + TextField + [Recevoir le lien] | Tape mail | **Email + magic_link** |

**Scène N2 finale (T7) — MintSceneCapaciteAchat :**
- Calculateur : `financial_core/housing_cost_calculator.computeBorrowingCapacity` + `financial_core/tax_calculator.estimateCantonalLoad` (revenu brut dérivé ×1.17)
- Sliders : 1 slider `apport_chf` (50k → 500k, step 10k, défaut 20% du revenu annuel brut × 4)
- Chiffre héros : **intervalle** `CHF X'XX'XXX - Y'XX'XXX` (prix d'achat visable), formule : `capacity = (net_annual × 3.33 charge_max + apport) ; fourchette ±12% liée à la conf:medium du revenu`
- Phrase de recul : *« C'est ta marge réelle, avant l'émotion de la visite. »*
- Eyebrow : « SCENE · ce que tu peux viser »
- CTA noir : **[Creuser]**

### Storyboard 3 : Intent « Mes impôts »

| Tour | MINT dit | User fait | Dossier gagne |
|---|---|---|---|
| 1 | « Il est temps que tu saches. » [Ouvrir] | Tap Ouvrir | — |
| 2 | « Qu'est-ce qui t'amène ? » + 4 cartes intents | Tap IMPOTS | **Intent : fiscal** |
| 3 | « Quel âge tu as ? » + picker | Scroll | **Age** |
| 4 | « Où tu es taxé ? » + liste 26 cantons | Tap canton | **Canton fiscal** |
| 5 | « Combien te tombe net par mois ? » + slider | Drag | **Revenu net mensuel (conf:medium)** |
| 6 | N1 inline : « Ton 3a n'est pas une faveur. C'est le levier le plus direct. » | Lit | **Compréhension 3a (tag)** |
| 7 | « Voilà ce que tu laisses sur la table. » + **Scène N2 MintScene3aLevier** | Drag slider versement 3a annuel | **Versement 3a envisagé, éco fiscale estimée** |
| 8 | « Je peux chiffrer un rachat LPP aussi, quand tu veux. » + [Creuser] [Plus tard] | Tap choix | **Intention** |
| 9 | « Laisse-moi un mail. Je te retrouve demain. » + TextField + [Recevoir le lien] | Tape mail | **Email + magic_link** |

**Scène N2 finale (T7) — MintScene3aLevier :**
- Calculateur : `financial_core/tax_calculator.computeMarginalRate` + `financial_core/tax_calculator.compute3aDeductionSavings` (revenu brut dérivé ×1.17)
- Sliders : 1 slider `versement_3a_annuel` (0 → 7'258 CHF plafond salarié 2026, step 258, défaut 3'000)
- Chiffre héros : **intervalle** `CHF X'XXX - Y'XXX` (économie fiscale annuelle), formule : `versement × taux_marginal ; fourchette liée à conf:medium canton+revenu ±6%`
- Phrase de recul : *« Ce montant retombe sur ton compte chaque année, si tu le fais. »*
- Eyebrow : « SCENE · ton levier direct »
- CTA noir : **[Creuser]**

*(Intent « Explorer » réutilise le flow retraite avec une seule différence : le chiffre héros T7 est étiqueté « moyenne suisse de ta tranche » tant que l'engagement personnel n'est pas donné. Hors panel final, tagué post-MVP.)*

---

## Décision D — Login rituel

**Tranché : option (d) — au tour 9, après la scène N2 du T7 et la bifurcation T8. Le mail n'est JAMAIS demandé avant qu'un chiffre héros personnalisé ait été vu.**

Débat : P voulait (b) après 1 scène N2 — M a refusé : interrompre juste après le chiffre héros casse le moment. D a tranché sur le rituel : le mail scelle le dossier, il vient quand la valeur est déjà livrée. T a renforcé : en langage de trailer, c'est le *fade-to-black avec générique*, pas l'entr'acte. Copy MINT T9 : *« Laisse-moi un mail. Je te retrouve demain. »* (8 mots, registre calme, zéro urgence, zéro frais d'acquisition).

---

## Décision E — Teasers dans le flow

**Tranché : aucun teaser avant T6. Un seul N1 inline par flow (à T6, entre les data collectées et la scène N2 de T7). Aucun teaser entre T2 et T5 (phase de collecte pure, sinon on viole le principe chronologique).**

Débat : I voulait intercaler un mini-insight après T4 (« Genève taxe autrement »). Refusé : sans revenu connu, l'insight est générique ou faux. D a tranché : la densité narrative monte *après* la dernière data, pas pendant. Le N1 de T6 sert de pont (la tête se prépare à recevoir la scène N2). La scène N2 de T7 reste le seul pic visuel du flow.

Formes retenues :
- T2 : 4 cartes intents (pas un teaser — c'est un choix)
- T6 : 1 carte N1 `MintInlineInsightCard` (fond `porcelaine`, ton neutre)
- T7 : 1 scène N2 pleine largeur
- T8 : pas de teaser, bifurcation textuelle pure
- T9 : pas de teaser, rituel mail

---

## Décision F — Animation du dossier strip

**Tranché :**
- **Apparition d'une ligne :** fade-in + slide-up 12px en **240 ms** `Curves.easeOutCubic`, avec un léger décalage 60 ms entre label et valeur (le label arrive d'abord, la valeur compte ensuite).
- **Count-up du chiffre :** 420 ms `Curves.easeOutQuart`, de 0 vers la valeur finale (ou de l'ancienne vers la nouvelle si update). Format suisse avec apostrophe : `3'750`. Pour les fourchettes, count-up sur la borne basse puis la borne haute séquentiellement (60 ms décalage).
- **Tokens :**
  - Fond strip : `MintColors.craie` avec border-top 0.5px `MintColors.border`
  - Label (eyebrow majuscules, 10.5pt, letter-spacing 1.2) : `MintColors.corailDiscret`
  - Valeur (Montserrat 15pt, weight 500) : `MintColors.textPrimary`
  - Gap ligne-ligne : 10px vertical
  - Hauteur strip : auto (grow), cap à 40% screen height avec scroll interne passé ce seuil
  - Padding strip : 16h × 14v
- **Quand strip update :** haptic `HapticFeedback.selectionClick` iOS + Android equivalent, au moment du settle de la valeur (pas au départ de l'anim).

Débat : M voulait 320 ms — jugé trop langoureux par T (« MINT n'est pas méditatif, il est net »). 240 ms est le compromis : perceptible sans alourdir. Count-up 420 ms parce que deux chiffres séquentiels (fourchette) doivent rester sous 1s total.

---

## Décision G — Format chiffre héros intervalle

**Tranché : format `CHF 3'750 – 4'050 / mois` (tiret demi-cadratin, pas trait d'union, espaces fines autour).**

Exemple concret scène retraite T7 : **« CHF 3'750 – 4'050 / mois »** en Montserrat 44pt (`displayHero`), avec une eyebrow au-dessus en Fraunces 14pt italique : *« scénario milieu, rendement 1,5 à 3,5 % »*.

Débat : I a tranché contre le « ≈ CHF 3'900 » (perd l'honnêteté de la fourchette, re-crée une fausse précision). D a refusé « entre 3'750 et 4'050 » (trop verbeux, l'œil ne peut pas capter le chiffre en 300 ms). Le tiret demi-cadratin fait standard éditorial (NYT Upshot, Bloomberg). M confirme lisibilité en Montserrat grande taille. Apostrophe suisse obligatoire (jamais virgule ni point).

---

## Dissidences résiduelles

- **M** maintient que 320 ms serait plus élégant sur le count-up — accepté de céder parce que 420 ms reste sous seuil cognitif.
- **P** regrette l'absence d'intent « Dettes » — réintégré post-MVP si signal user (planning tag).

---

## Checklist exécution pour le dev

- [ ] Créer enum `OnboardingIntent { retraite, achat, impots, explorer }` dans `apps/mobile/lib/models/onboarding_intent.dart`
- [ ] Étendre `OnboardingProvider` (PR #378) : champs `intent`, `ageYears`, `canton`, `netMonthlyRange: (int, int)?`, `netMonthlyExact: int?`, `confidenceByField: Map<String, MintConfidenceLevel>`
- [ ] Écrans à créer/adapter :
  - `OnboardingIntentsScreen` (T2) — 4 cartes `OnboardingIntentCard`
  - `OnboardingAgeScreen` (T3) — picker 18–75
  - `OnboardingCantonScreen` (T4) — liste 26 cantons recherchable
  - `OnboardingRevenueScreen` (T5) — slider 500 CHF + lien exact + hint
  - `OnboardingInsightScreen` (T6) — `MintInlineInsightCard` variable par intent
  - `OnboardingSceneScreen` (T7) — route vers scène N2 spécifique
  - `OnboardingBifurcationScreen` (T8) — 2 CTA [Creuser] [Plus tard]
  - `OnboardingMagicLinkScreen` (T9) — TextField mail + bouton
- [ ] Scènes N2 à créer :
  - `MintSceneRenteTrouee` (retraite)
  - `MintSceneCapaciteAchat` (achat)
  - `MintScene3aLevier` (impôts)
- [ ] Widgets à créer/adapter :
  - `OnboardingIntentCard` (eyebrow + Fraunces phrase)
  - `DossierStrip` (PR #378) — ajouter animation 240/420 ms, haptics, format suisse
  - `MintInlineInsightCard` déjà specifié en `03-components.md`
- [ ] Calculateurs appelés (tous existants — ne PAS en créer de nouveaux) :
  - `avs_calculator.computeMonthlyRente`
  - `lpp_calculator.estimateRenteFromSalary`
  - `housing_cost_calculator.computeBorrowingCapacity`
  - `tax_calculator.computeMarginalRate`
  - `tax_calculator.compute3aDeductionSavings`
  - `tax_calculator.estimateCantonalLoad`
- [ ] Conversion net→brut : utilitaire `IncomeConverter.netToGrossAnnual(netMonthly, isSalaried: true)` avec facteur 1.17 (salarié) / 1.10 (indépendant), flag `confidence: medium`
- [ ] Tests :
  - Widget test `integration_test/onboarding_full_flow_retraite_test.dart` (T1→T9 tap-by-tap + dossier strip vérifié)
  - Idem `_flow_achat_test.dart`, `_flow_impots_test.dart`
  - Unit test `onboarding_provider_test.dart` : set intent + merge data
  - Unit test `income_converter_test.dart` (net→brut, conf tracking)
  - Unit test `scene_rente_trouee_test.dart`, `scene_capacite_achat_test.dart`, `scene_3a_levier_test.dart` — golden contre Julien (34, Vaud, 7600 net) + Lauren
  - Exigence : 3/3 integration tests green avant merge
- [ ] ARB keys 6 langues (fr/en/de/es/it/pt) :
  - `onbOpenerTitle`, `onbOpenerCta`
  - `onbIntentsQuestion`, `onbIntentRetraiteEyebrow`, `onbIntentRetraitePhrase`, `onbIntentAchatEyebrow`, `onbIntentAchatPhrase`, `onbIntentImpotsEyebrow`, `onbIntentImpotsPhrase`, `onbIntentExplorerEyebrow`, `onbIntentExplorerPhrase`
  - `onbAgeQuestion`, `onbCantonQuestion`, `onbRevenueQuestion`, `onbRevenueHint`, `onbRevenueExactLink`
  - `onbInsightRetraite`, `onbInsightAchat`, `onbInsightImpots`
  - `onbSceneRenteEyebrow`, `onbSceneRenteRecul`, `onbSceneAchatEyebrow`, `onbSceneAchatRecul`, `onbScene3aEyebrow`, `onbScene3aRecul`
  - `onbBifurcationRetraite`, `onbBifurcationAchat`, `onbBifurcationImpots`, `onbCtaCreuser`, `onbCtaPlusTard`
  - `onbMagicLinkPrompt`, `onbMagicLinkCta`
  - Run `flutter gen-l10n` après édition des 6 ARB
- [ ] Accents FR mandatory sur toutes les strings (lint `tools/checks/accent_lint_fr.py`)
- [ ] Zéro terme LSFin banni (lint existant)
- [ ] Build iOS simulator via workaround Tahoe (xcodebuild, pas flutter clean)

---

STORYBOARD-FINAL-LOCKED prêt, 4 intents: retraite · achat · impots · explorer, 9 tours/intent, dev estimate: 6 jours.
