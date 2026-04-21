# System Prompt Debias Audit — 2026-04-18

Fichier audité : `services/backend/app/services/coach/claude_coach_service.py`
Scope : toute mention de `retraite / retirement / LPP / 3a / pilier / rente / EPL / AVS / prevoyance`.

## Summary

- **KEEP** : 23 mentions (LPP/3a/AVS comme outils fiscaux ou références légales neutres)
- **KEEP-CONTEXTUAL** : 11 mentions (retraite dans contexte life-event ciblé : `retirement`, `partner`, `divorce`)
- **RESTRUCTURE** : 7 mentions (framing "ta retraite" comme destination universelle)
- **REMOVE** : 2 mentions (phase de cycle de vie qui présuppose proximité retraite)

Ratio 40/11/7/2 — le prompt est **majoritairement sain** (LPP/3a sont traités en outils fiscaux). Le biais est concentré dans (a) `_LIFECYCLE_AWARENESS`, (b) `_FOUR_LAYER_ENGINE` qui a un exemple canonique "ta retraite", (c) `_COUPLE_DISSYMETRIQUE` qui liste la retraite comme trigger couple, (d) deux phrases dans `_BASE_SYSTEM_PROMPT` qui par exemple frament "retraite anticipée" comme point de repère.

---

## Par bloc

### Bloc `_TOOL_ROUTING_RULES` lignes 75-124

L.87, 90 : exemples `save_fact` sur LPP/3a/avoirLpp/pillar3aBalance → **KEEP** (enregistrement factuel, zéro framing retraite).

L.107 : `"For complex decisions (rente vs capital, job comparison, housing)"` → **KEEP**. `rente vs capital` est un arbitrage fiscal concret, valable à tout âge (EPL, départ Suisse, etc.), pas un framing retraite.

L.113 : `'/rente-vs-capital'` route name → **KEEP** (string technique de route, pas exposé user).

---

### Bloc `_LIFECYCLE_AWARENESS` lignes 131-163

**L.141** — KEEP : `"Ton 3a : zéro. L'État te remercie."` → parfait. 3a comme outil fiscal, phase `demarrage` (18-25). Le 3a à 22 ans N'EST PAS du framing retraite, c'est la déduction fiscale immédiate. Julien a dit explicitement : légitime.

**L.148** (phase `consolidation` 45-55) : `"reassuring, every number with context"` → KEEP (aucune mention retraite).

**L.149** (phase `transition` 55-60) → **RESTRUCTURE**. Le nom `transition` est neutre mais implicite = transition vers retraite. Cette phase reste acceptable car (a) c'est une directive de **ton**, pas de contenu, (b) 55-60 est une tranche d'âge où la fiscalité retraite devient un sujet concret. GARDER LE NOM, mais s'assurer que le coach ne présume pas du sujet.
- Texte actuel : `"For 'transition' (55-60): calm, one option at a time, no pressure, no artificial urgency. Each decision is considered."`
- Texte proposé : `"For 'transition' (55-60): calm, one option at a time. Decisions in this window often have long horizons (career change, property, early withdrawal eligibility). Never assume retirement is the topic — ask."`

**L.150-151** (phase `retraite` 60+) → **KEEP-CONTEXTUAL**. Phase nommée `retraite` = flag interne qui ne se déclenche QUE si la donnée utilisateur le confirme (âge 60+). Légitime, c'est une phase réelle, pas une projection universelle. Le ton sérénité / montants mensuels est correct.

**L.152-153** (phase `transmission` 65+) → **KEEP-CONTEXTUAL**. Même logique : succession est un sujet réel à 65+, pas une projection universelle.

**Bloc entier — observation doctrine** :
La liste des 7 phases `demarrage / construction / acceleration / consolidation / transition / retraite / transmission` est **correcte sur le papier** (ADR archetype-driven) mais dangereuse en pratique : elle structure la conversation selon l'AXE TEMPS PERSONNEL / retraite-vers-transmission. Or MINT couvre 18 life events, dont seuls 3 (retirement, deathOfRelative, inheritance) relèvent de cet axe.

→ **Recommandation doctrine (voir §Long-Terme)** : la notion de `lifecycle_phase` doit être **sortie du system prompt** et remplacée par la liste `active_life_events` (events déclenchés, pas phase théorique). Refonte hors-scope audit, **ADR ProduitCoach nécessaire**.

---

### Bloc `_CHECK_IN_PROTOCOL` lignes 165-190

L.183 : `"Parfait, 500 CHF sur le 3a et 200 CHF en épargne libre"` → **KEEP**. 3a comme destination d'épargne fiscale concrète. Zéro framing retraite.

---

### Bloc `_FOUR_LAYER_ENGINE` lignes 192-204

**L.197** : `"Ton employeur verse 7% de ton salaire assure au 2e pilier"` → **KEEP**. Fait LPP neutre.

**L.198** : `"Ca veut dire qu'environ 560 CHF par mois sont mis de cote pour ta retraite"` → **RESTRUCTURE**. "ta retraite" présume que l'épargne LPP = retraite uniquement. Or LPP sert aussi EPL, départ Suisse, invalidité.
- Texte actuel : `"Ca veut dire qu'environ 560 CHF par mois sont mis de cote pour ta retraite"`
- Texte proposé : `"Ca veut dire qu'environ 560 CHF par mois sont bloqués sur ton compte prévoyance — débloquables à la retraite, à l'achat d'un logement, ou en cas de départ de Suisse"`

**L.199** : `"A 22 ans, c'est le moment ideal pour commencer a optimiser -- chaque annee compte double"` → **RESTRUCTURE**. "optimiser" est banned term (absolu). "compte double" suggère retraite-centric. Reformuler en gain fiscal immédiat.
- Texte actuel : `"A 22 ans, c'est le moment ideal pour commencer a optimiser -- chaque annee compte double"`
- Texte proposé : `"A 22 ans, verser sur un 3a te fait economiser env. 1'400 CHF d'impot cette annee (canton moyen). C'est du cash immediat, pas une promesse lointaine."`

**L.200** : `"Demande a ton employeur : est-ce un plan LPP legal ou surobligatoire ?"` → **KEEP**. Question à poser, 100% légitime.

---

### Bloc `_FIRST_JOB_CONTEXT` lignes 206-216

L.209-214 : liste AVS/LPP/3a/assurances/budget pour `firstJob` → **KEEP**. Tout est fiscal/contractuel concret. Les 3a/LPP sont ici outils fiscaux et protection sociale, pas framing retraite. Le `firstJob` est l'événement qui déclenche légitimement cette checklist. OK.

---

### Bloc `_LIFE_EVENT_CATALOG` lignes 223-259

L.231-258 : catalogue 18 life events avec spécificités suisses. Contient :
- L.232 : `divorce -> partage LPP` → **KEEP-CONTEXTUAL** (déclenché si divorce)
- L.234 : `concubinage -> aucune protection LPP de survie` → **KEEP-CONTEXTUAL**
- L.235 : `deathOfRelative -> rente de veuf/veuve AVS` → **KEEP-CONTEXTUAL**
- L.238 : `firstJob -> seuil LPP 22'680 CHF` → **KEEP**
- L.240 : `selfEmployment -> 3a porte a 20%` → **KEEP**
- L.241 : `jobLoss -> maintien LPP compte libre-passage` → **KEEP**
- L.242 : `retirement -> AVS 65/64, rente vs capital LIFD art.38` → **KEEP-CONTEXTUAL**
- L.245 : `housingPurchase -> EPL LPP art.79b` → **KEEP**
- L.251 : `disability -> AI 1er pilier + LPP art.23-26` → **KEEP-CONTEXTUAL**
- L.258 : `debtCrisis -> desactiver optimisation 3a` → **KEEP**

Bloc entier : **parfait**. C'est EXACTEMENT la bonne structure anti-retirement-bias. Un event-by-event enum sans hiérarchie retraite. Modèle à suivre pour le reste.

---

### Bloc `_ARCHETYPE_CATALOG` lignes 261-277

L.270-275 : archétypes avec impacts LPP/3a (FATCA, rachat, frontalier) → **KEEP**. Règles fiscales, pas framing retraite.

---

### Bloc `_SAFE_MODE_PROTOCOL` lignes 279-308

L.286, 291-292 : `"JAMAIS d'optimisation 3a, rachat LPP"` / `"comment optimiser mon 3a"` → **KEEP**. Contexte = interdiction explicite. Traitement correct de 3a/LPP comme outils fiscaux qu'on désactive en Safe Mode.

---

### Bloc `_PLAN_AWARENESS` lignes 310-321

L.315 : `"Tu en es à l'étape 3 — vérifions ton avoir LPP."` → **KEEP**. Exemple de référence au plan en cours. LPP = patrimoine, pas projection retraite.

---

### Bloc `_IMPLEMENTATION_INTENTION` lignes 323-333

L.329 : `where_text="Sur ton app bancaire 3a"` → **KEEP**. Exemple commitment card sur versement 3a, outil fiscal.

---

### Bloc `_PRE_MORTEM_PROTOCOL` lignes 335-347

L.338-340 : décisions irréversibles listées :
- `"EPL (retrait anticipé 2e pilier pour achat immobilier)"` → **KEEP** (housing, pas retraite)
- `"Retrait en capital du 2e pilier (vs rente)"` → **KEEP-CONTEXTUAL** (sujet retraite ou départ Suisse)
- `"Clôture du 3e pilier"` → **KEEP**

Liste saine — couvre des décisions irréversibles sur plusieurs life events, pas une seule focalisation retraite.

---

### Bloc `_PROVENANCE_TRACKING` lignes 349-358

L.351, 355 : `"3a, LPP, assurance, hypotheque, placement"` / `"le 3a que ton banquier t'a propose chez UBS"` → **KEEP**. Produits financiers suisses, neutre.

---

### Bloc `_COUPLE_DISSYMETRIQUE` lignes 373-393

**L.377** → **RESTRUCTURE**. Liste la retraite comme premier trigger couple, ce qui renforce le biais que "couple = pensée retraite".
- Texte actuel : `"Quand le sujet touche la retraite, les impots, l'hypotheque, ou le patrimoine :"`
- Texte proposé : `"Quand le sujet touche les impots, l'hypotheque, le patrimoine, une decision famille (mariage, enfant, separation) ou la prevoyance long terme :"`

**L.383** → **RESTRUCTURE**. `"Age (impact horizon retraite)"` présume le couple pense retraite. Or l'âge conjoint impacte aussi assurance vie, hypothèque, fiscalité progressive, allocations.
- Texte actuel : `"- Age (impact horizon retraite)"`
- Texte proposé : `"- Age (impact projections long terme, horizon hypotheque, fiscalite progressive)"`

**L.384** → **KEEP-CONTEXTUAL**. `"Avoir LPP estime (impact rente couple)"` — rente couple est un fait fiscal concret (cap AVS 150% marié LAVS art.35, splitting), pas une projection retraite universelle. Légitime dans le contexte "données partenaire".

**L.385** → **KEEP**. `"Capital 3a estime (impact fiscal retrait)"` — fiscal, pas retraite.

---

### Bloc `_BASE_SYSTEM_PROMPT` lignes 411-560

**L.433** : `"3a bancaire vs titres, ETF passif vs gestion active"` → **KEEP**. Catégories fiscales.

**L.489** : `"Rachat LPP = 30k d'économie d'impôt immédiate. Mais 3 ans de blocage EPL."` → **KEEP**. Exemple PARFAIT. LPP = outil fiscal, EPL = contrainte concrète. Zéro framing retraite.

**L.490** : `"180k LPP + 45k 3a + 80k cash = 305k. Ça, c'est ton vrai patrimoine."` → **KEEP**. Patrimoine actuel, pas projection retraite.

**L.516** : `"LPP 180k Swisscanto, 3a 45k, épargne 80k, lacune rachat 120k"` → **KEEP**.

**L.520** : `"préfère ne pas tout bloquer en LPP"` → **KEEP**.

**L.534-535** : `"95k à 34 ans à Lausanne, c'est une base solide pour poser 3a et rachat LPP. Tu veux qu'on regarde ton 3a en premier ?"` → **KEEP**. 3a + rachat LPP présentés comme **optimisation fiscale immédiate** pour une personne de 34 ans. Parfait exemple du framing correct.

**L.546** (AVS) → **KEEP**. Faits légaux.

**L.547** (LPP) → **KEEP**. Faits légaux + contrainte EPL explicite (non-retraite).

**L.548** (3a) → **KEEP**. Mention "retraite anticipée (5 ans avant)" est factuelle (condition de retrait légale), pas un framing universel.

**L.549** (Divorce) → **KEEP-CONTEXTUAL**.

**L.551** → **RESTRUCTURE**. Bloc "Retraite" dans CONNAISSANCES SUISSES est acceptable en contenu mais le format liste-générale présente la retraite au MÊME niveau que AVS/LPP/3a/divorce, renforçant l'idée qu'elle est un sujet par défaut.
- Texte actuel : `"- Retraite : inscription AVS 3-4 mois avant. Anticipation possible dès 63 ans (-6.8%/an). Ajournement +31.5% si 5 ans de report."`
- Texte proposé : `"- Retraite (life event 'retirement' uniquement) : inscription AVS 3-4 mois avant le depart. Anticipation dès 63 ans (-6.8%/an). Ajournement +31.5% si 5 ans de report. Ne discute ces chiffres QUE si l'utilisateur ouvre le sujet ou que son profil indique phase 'retraite' ou 'transition'."`

**L.552** → **KEEP**. `"Rente vs Capital : rente = revenu imposable annuel. Capital = taxé une fois au retrait (barème séparé)"`. Fiscal pur, applicable à tout retrait (EPL, départ, retraite).

**L.553** → **KEEP**. Barème retrait capital. Fiscal pur. "Retrait échelonné = optimisation fiscale" est un levier à tout âge.

**L.548 (fin), L.551, L.553 — observation globale CONNAISSANCES SUISSES** :
Le bloc contient 8 bullets. 5/8 sont structurés comme faits fiscaux/contractuels (bons). 3/8 (AVS projection rente, Retraite inscription, Rente vs Capital SWR) parlent uniquement du moment retraite. Le ratio 5/8 acceptable tant que le coach n'a pas licence de les ressortir spontanément. **Ajouter une ligne d'en-tête directive** :

- Texte proposé ligne 545 (avant "CONNAISSANCES SUISSES...") :
  ```
  CONNAISSANCES SUISSES (n'utilise ces faits QUE si la conversation l'amène —
  ne les aborde JAMAIS de toi-même au premier message, même si l'utilisateur
  vient d'ouvrir MINT. Ils sont des outils, pas un menu à dérouler) :
  ```

---

## Récap RESTRUCTURE (7 modifications applicables)

| Ligne | Avant | Après |
|-------|-------|-------|
| 149 | `calm, one option at a time, no pressure, no artificial urgency. Each decision is considered.` | `calm, one option at a time. Decisions in this window often have long horizons (career change, property, early withdrawal eligibility). Never assume retirement is the topic — ask.` |
| 198 | `mis de cote pour ta retraite` | `bloqués sur ton compte prévoyance — débloquables à la retraite, à l'achat d'un logement, ou en cas de départ de Suisse` |
| 199 | `A 22 ans, c'est le moment ideal pour commencer a optimiser -- chaque annee compte double` | `A 22 ans, verser sur un 3a te fait economiser env. 1'400 CHF d'impot cette annee (canton moyen). C'est du cash immediat, pas une promesse lointaine.` |
| 377 | `Quand le sujet touche la retraite, les impots, l'hypotheque, ou le patrimoine :` | `Quand le sujet touche les impots, l'hypotheque, le patrimoine, une decision famille (mariage, enfant, separation) ou la prevoyance long terme :` |
| 383 | `- Age (impact horizon retraite)` | `- Age (impact projections long terme, horizon hypotheque, fiscalite progressive)` |
| 545 (ajout header) | `CONNAISSANCES SUISSES (utilise ces faits quand pertinent) :` | `CONNAISSANCES SUISSES (n'utilise ces faits QUE si la conversation l'amène — ne les aborde JAMAIS de toi-même, ils sont des outils, pas un menu à dérouler) :` |
| 551 | `- Retraite : inscription AVS 3-4 mois avant. Anticipation possible dès 63 ans (-6.8%/an). Ajournement +31.5% si 5 ans de report.` | `- Retraite (life event 'retirement' uniquement) : inscription AVS 3-4 mois avant le depart. Anticipation dès 63 ans (-6.8%/an). Ajournement +31.5% si 5 ans de report. Ne discute ces chiffres QUE si l'utilisateur ouvre le sujet ou que son profil indique phase 'retraite' ou 'transition'.` |

## Récap REMOVE (2 éléments)

Aucune suppression chirurgicale nette : les 2 seuls candidats (`_LIFECYCLE_AWARENESS` phases retraite/transmission L.150-153) sont techniquement correctes car gated par donnée utilisateur (phase déclenchée par âge réel). Garder.

En revanche, **le concept `_LIFECYCLE_AWARENESS` entier** mérite une refonte → voir section suivante.

---

## Blocs à refondre en entier

### `_LIFECYCLE_AWARENESS` (L.131-163) — refonte complète hors-scope audit, ADR ProduitCoach

Le concept "lifecycle phase" (7 phases nommées par âge/étape) est structurellement orienté axe-retraite :
- 6 des 7 phases se définissent par rapport à la préparation-retraite (`demarrage` → `transmission` est un continuum retraite-centric).
- Seul `debtCrisis`, `jobLoss`, `housingPurchase`, etc. (les 18 life events) sont des triggers user-centric qui RESPECTENT la doctrine Julien.

**Recommandation** :
- **Court terme (dans cet audit)** : appliquer les 7 RESTRUCTURE ci-dessus. Suffisant pour corriger le framing dans les exemples.
- **Moyen terme (ADR)** : remplacer `lifecycle_phase` par `active_life_events[]` dans `CoachContext`. Le coach lit la liste des events actifs (déclenchés par faits récents du user) au lieu d'une phase de cycle de vie théorique. Refonte = model change + context_injector_service.py + 8 consumers. **Hors-scope audit, nécessite ADR**.

---

## Règles doctrine long-terme (à enforce dans tout futur code/contenu coach)

### Vocabulaire banni (user-facing + system prompt)
- `"ta retraite"` (possessif présumant l'horizon retraite comme destination personnelle) → préférer `"ta prévoyance"` / `"ton epargne long terme"` / `"le moment où tu decideras de t'arreter"` / ciblé event-by-event.
- `"preparer ta retraite"` / `"financer ta retraite"` → **BANNI** en salutation, premier message, ou contexte sans event `retirement` actif.
- `"pour quand tu seras a la retraite"` → **BANNI**. Même logique : remplacer par "le jour où tu voudras lever le pied" ou contextualiser sur un événement actif.
- `"chaque annee compte double"` / `"les interets composes vont te sauver"` → **BANNI**. Framing retraite-lointaine. Préférer gain fiscal immédiat année N.

### Patterns de framing à appliquer partout
1. **LPP/3a = outils fiscaux d'abord, prévoyance ensuite.** Toute mention doit ouvrir par l'impact fiscal immédiat (économie d'impôt, EPL disponible, protection invalidité) AVANT l'angle retraite.
2. **La retraite est UN event parmi 18.** Aucun prompt, aucune UI, aucun nudge par défaut ne doit positionner la retraite comme destination. Elle s'ouvre si event `retirement` actif OU user la mentionne.
3. **AVS/LPP/3a dans `CONNAISSANCES SUISSES`** doivent rester **gated** par "quand pertinent / QUE si la conversation l'amène". Jamais déroulés en dashboard.
4. **Les phases `demarrage → transmission` ne sont PAS des sujets user-facing.** Ce sont des flags de ton (calme/direct/serein). Jamais le coach ne dit "tu es en phase consolidation". Si le code le laisse fuiter, bug.
5. **Exemples canoniques du system prompt (L.534)** : `"34 ans à Lausanne, base solide pour poser 3a et rachat LPP"` = gold standard. Chaque futur exemple doit passer ce test : **est-ce que la phrase marche à 22, 35, 48, 62 ans indifféremment ?**

### Sanity check (à ajouter dans test suite coach)
- Pour chaque réponse coach générée en test, grep `ta retraite` / `préparer la retraite` / `horizon retraite` → fail si >0 occurrences ET event `retirement` non actif.
- Test adversarial : user dit "j'ai 28 ans, premier job" → coach NE DOIT PAS mentionner "retraite" dans la réponse. Doit mentionner 3a (fiscal) et LPP (contrat employeur).

### ADR à produire
- **ADR-ProduitCoach-LifecyclePhaseDeprecation** : remplacer `lifecycle_phase` par `active_life_events[]`. Impact : `CoachContext`, `context_injector_service`, `_LIFECYCLE_AWARENESS` bloc entier, nudges engine, 8 consumers. Effort estimé 2-3 jours. Gate : décision produit Julien.
