# Verdict suisse — findings Sonnet AVS Expat et dette AVS transverse

Date de vérification : 2026-07-14
Rôle : `mint-swiss-brain`
Scope : adjudication documentaire de `P2-1`, `P2-4` et `P1-3`; aucune
modification de code, aucun nouvel audit Claude, aucun verdict G1 global.

## Verdict exécutif

| Sévérité | Verdict |
|---|---|
| P0 | **0 dans cette adjudication documentaire** |
| P1 | **1 confirmé et élargi, blocker G1** — plusieurs surfaces mobile et un endpoint backend live transforment des années déclarées, observées ou simplement passées à l'étranger en effet personnel sur la rente; ticket `G1-AVS-03` ajouté en `ticket_only`. |
| P2-1 | **Partiellement fondé, motif à corriger** — une durée complète de 43 ans subsiste pour les femmes nées avant 1964, pas seulement avant 1961; mais `4 / 43` n'est pas pour autant une réduction personnelle de rente. |
| P2-4 | **Fondé** — une UI ne peut pas écrire `44` indépendamment du dénominateur renvoyé par son calcul. Le contrat le plus sûr pour ce flow est toutefois de ne plus afficher de pourcentage. |

`G1` reste incomplet et `G2/G3` restent interdits.

## 1. Adjudication du dénominateur 44

### 1.1 Ce que disent les sources officielles

1. L'art. 29ter LAVS définit la durée complète par comparaison avec la **classe
   d'âge**; il ne fixe pas un nombre universel dans le profil d'une personne.
2. Les Directives concernant les rentes, état au 1er janvier 2026, ch. 5073 à
   5076, imposent de comparer les années entières de la personne avec celles de
   sa classe d'âge puis d'appliquer l'échelonnement de l'art. 52 RAVS.
3. L'ordinogramme de calcul OFAS distingue explicitement :
   - hommes : `44` années;
   - femmes avec année de naissance `< 1964` : `43` années;
   - femmes avec année de naissance `>= 1964` : `44` années.
4. Une durée complète de 43 ans donne néanmoins une **rente entière de
   l'échelle 44**. Le mémento 3.08 l'illustre avec une femme née en 1960.
5. Le Centre d'information AVS/AI résume simultanément la durée complète de
   43 ans pour les femmes concernées et le repère général de `1/44` par année
   manquante. Il ne faut donc pas confondre « durée complète de la classe
   d'âge » et « numéro/facteur de l'échelle de rente ».

### 1.2 Correction exacte du finding Sonnet

Le finding a raison de refuser un dénominateur de **durée personnelle** fixé à
44 pour tout le monde. Il est incomplet sur le seuil : les femmes nées en 1961,
1962 et 1963 ont elles aussi `43` années entières dans l'ordinogramme OFAS, de
sorte que la bonne coupure est `< 1964`.

En revanche, la proposition implicite `4 / 43 = 9,30 %` ne calcule pas une
réduction personnelle de rente. La caisse :

- détermine les périodes effectivement prises en compte ou comblées;
- compare la durée retenue avec la classe d'âge;
- choisit l'échelle selon l'art. 52 RAVS;
- calcule ensuite le montant avec le revenu annuel moyen déterminant et les
  bonifications reconnues.

Un extrait CI rend des périodes visibles; il ne fournit pas à lui seul ce
résultat officiel. `4 / 44` et `4 / 43` sont donc tous deux insuffisants pour
annoncer une réduction de la rente de cette personne.

### 1.3 Conséquence sur `rawContributionDurationGapPercent`

Le nom actuel exprime une proportion de **durée de cotisation**, alors que la
clé globale `avs.full_contribution_years = 44` ne représente pas la durée
complète de chaque classe d'âge. Le calcul peut servir au mieux de repère
éducatif général de l'échelle 44; il ne doit pas être présenté comme la part de
la durée complète propre à l'utilisateur.

Le produit n'a aucun intérêt à collecter une donnée sensible ou à complexifier
ce flow uniquement pour afficher un pourcentage de faible valeur. La solution
la plus lucide est de conserver le nombre CI à examiner et de retirer le
pourcentage de l'UI Expat.

## 2. Contrat UI sûr exact

### 2.1 Contrat recommandé — count-only

Le résultat Expat affichable contient seulement :

```text
ciObservedMissingContributionYears: int?
```

Il ne contient ni pourcentage, ni échelle, ni perte en CHF. Une valeur absente
reste `null`; un zéro n'est affichable que si sa provenance CI/certificate est
valide.

**Titre français :**

> Années à examiner d'après l'extrait CI : {years}

**Corps français :**

> Ce nombre ne détermine ni ta durée complète de cotisation, ni l'échelle, ni
> une réduction de ta rente. La caisse vérifie les périodes qui peuvent être
> prises en compte, puis fixe l'échelle et le montant officiels. Le montant
> dépend aussi du revenu annuel moyen déterminant et des bonifications
> reconnues.

L'état sans CI conserve l'état « à vérifier » et les deux chemins officiels
vers l'extrait CI et la caisse. Les années de résidence à l'étranger restent un
fait de scénario distinct; elles ne deviennent jamais automatiquement des
lacunes AVS.

### 2.2 Variante seulement si MINT conserve un repère général

La variante acceptable n'est pas une « proportion de ta durée complète », mais
un repère général de l'échelle AVS. Elle exige un type unique :

```text
AvsGeneralScaleReference {
  observedYears: int
  scaleDenominator: int
  referencePercent: double
  legalAsOf: date
}
```

Règles non négociables :

- `scaleDenominator` provient d'une clé réglementaire dédiée au dénominateur de
  l'échelle, pas de `avs.full_contribution_years`;
- le widget reçoit et affiche `{scaleDenominator}` depuis le **même objet** que
  `{referencePercent}`;
- aucune ARB ne contient `44` en dur;
- le texte dit « repère général de l'échelle AVS », jamais « ta durée complète »
  ou « ta réduction »;
- le type n'entre pas dans un score et ne produit aucun CHF;
- la date juridique est visible ou traçable.

**Corps français de repli :**

> Repère général de l'échelle AVS : {years} × 1/{scaleDenominator}, soit
> {percent} %. Ce repère ne détermine ni ta durée complète de cotisation, ni
> ton échelle, ni une réduction de ta rente. Seule la caisse fixe le résultat
> officiel.

Le contrat recommandé reste le contrat count-only : il apporte autant d'action
utile avec moins de risque d'interprétation.

## 3. P1 confirmé — effets AVS fabriqués hors décision de caisse

### 3.1 API et helpers

- `services/backend/app/services/expat/expat_service.py::estimate_avs_gap`
  calcule une rente mensuelle, une réduction mensuelle et une réduction annuelle
  à partir de `years_abroad` et `years_in_ch`. Il suppose notamment la rente
  maximale et ignore le RAMD, les bonifications, les mois retenus, les
  mécanismes de comblement, la classe d'âge et l'échelle officielle.
- `POST /api/v1/expat/avs-gap` expose ces montants dans un schéma public live.
- `AvsCalculator.reductionPercentageFromGap(gap)` transforme un nombre d'années
  en réduction personnelle sans contrat de provenance ou d'échelle.
- `AvsCalculator.monthlyLossFromGap(gap)` est encore plus dangereux : il
  applique le gap à la rente maximale et produit un montant CHF sans RAMD.

Ces contrats sont des **P1** : ils peuvent modifier la compréhension, le score,
le rapport ou une décision utilisateur à partir d'entrées insuffisantes.

### 3.2 Callers et copies trouvés dans la production

Inventaire minimum confirmé par `rg` :

- `apps/mobile/lib/services/circle_scoring_service.dart` — `rente -X%` et
  classement `good/warning` à partir des années CI;
- `apps/mobile/lib/data/financial_explanations.dart` — effet définitif, `-2.3%`
  à vie, montant de couple obsolète et rachat formulé comme général;
- `apps/mobile/lib/data/wizard_questions_v2.dart` — `Chaque année manquante =
  -2.3 % de rente à vie`;
- `apps/mobile/lib/data/education_content.dart` — `2.3%` comme premier
  éclairage et réduction à vie;
- `apps/mobile/lib/screens/expat_screen.dart` — `10 ans = -23% à vie`;
- `apps/mobile/lib/services/coach/local_fallback_service.dart` et
  `coach_narrative_service.dart` — injection du `1/44` dans des sorties/prompt
  sans rappeler la décision de caisse;
- `apps/mobile/lib/services/financial_report_service.dart` et
  `app_fr.arb` — promesse d'éviter jusqu'à CHF 38'000 de rente à vie;
- `apps/mobile/lib/widgets/visualizations/pension_completeness_ring.dart` —
  dénominateur 44, rente maximale et réduction mensuelle par défaut; aucun
  consommateur de production trouvé, donc façade à supprimer ou quarantainer;
- `services/backend/app/services/precision/precision_service.py` — promesse
  d'une rente « au franc près » après collecte des seules années;
- `services/backend/app/services/rag/faq_service.py` — prix de rachat et
  avantage CHF/mois dérivés localement sans décision de caisse.

Un disclaimer ne corrige pas une formule qui produit le mauvais type de vérité.

## 4. Nouveau ticket G1 déterministe

Ticket ajouté : `G1-AVS-03 — avs_unofficial_gap_effect_quarantine_test`.

Statut : **`ticket_only`**. Aucun test RED n'a été créé ou exécuté dans cette
mission documentaire; aucune preuve RED n'est revendiquée.

### Fixture RED à implémenter

Le gate cross-stack doit :

1. envoyer au backend des combinaisons de `years_abroad`/`years_in_ch` sans
   RAMD, mois crédités, classe d'âge, compensation ni échelle officielle, puis
   refuser toute rente ou réduction CHF calculée;
2. parcourir les sources de production mobile/backend et échouer si un nombre
   déclaré/CI alimente `rente -X%`, `-2.3% à vie`, `1/44` personnalisé, perte
   CHF ou score `good/warning`;
3. vérifier `null`, `0`, `2`, `4` et `9` années CI sans décision officielle;
   seul le nombre « à examiner » peut varier, tandis que l'effet, le CHF et le
   score de préparation restent inconnus;
4. couvrir une femme née en 1960, une femme née en 1964 et un homme né en 1964;
   aucun profil ne reçoit un effet personnel dérivé du seul nombre d'années;
5. autoriser uniquement une explication générale explicitement non personnelle,
   sourcée et datée; si elle affiche un dénominateur, le même objet typé fournit
   le dénominateur et le pourcentage;
6. supprimer/quarantainer `PensionCompletenessRing` s'il reste sans caller, et
   empêcher une nouvelle façade sans câblage;
7. si le schéma API change, synchroniser `SOT.md` et `tools/openapi/`.

### Commande RED puis GREEN canonique

```bash
(cd services/backend && python3 -m pytest tests/test_avs_unofficial_gap_effect_quarantine.py -q) && \
(cd apps/mobile && flutter test test/services/financial_core/avs_unofficial_gap_effect_quarantine_test.dart --reporter expanded)
```

La même commande devient GREEN après correction; aucune autre commande ne peut
promouvoir le ticket.

## 5. Sources officielles vérifiées

- [Fedlex — LAVS, notamment art. 29ter](https://www.fedlex.admin.ch/eli/cc/63/837_843_843/fr)
  — durée complète comparée à la classe d'âge.
- [Fedlex — RAVS, notamment art. 52](https://www.fedlex.admin.ch/eli/cc/1947/1183_1183_1183/fr)
  — échelonnement des rentes partielles selon le rapport à la classe d'âge.
- [OFAS — Directives concernant les rentes, état au 1er janvier 2026](https://sozialversicherungen.admin.ch/fr/d/6857/download)
  — ch. 5073 à 5076, décision par classe d'âge et échelle.
- [OFAS — Ordinogramme AVS-AI, facteurs de rentes partielles et échelle](https://sozialversicherungen.admin.ch/fr/d/18438/download?version=2)
  — `43` pour les femmes nées avant 1964, `44` pour les femmes nées dès 1964
  et pour les hommes; échelle finale de 1 à 44.
- [Centre d'information AVS/AI — Durée de cotisations](https://www.ahv-iv.ch/fr/Assurances-sociales/Glossaire/term/beitragsdauer)
  — distinction entre 43/44 années complètes et repère général de `1/44`.
- [Centre d'information AVS/AI — Mémento 3.08, état au 1er janvier 2026](https://www.ahv-iv.ch/p/3.08.f)
  — exemple officiel d'une femme née en 1960 : 43 années complètes et rente
  entière de l'échelle 44.
- [OFAS — Lacunes d'assurance et de cotisations, 3 juin 2025](https://www.bsv.admin.ch/fr/lacunes-dassurance-et-de-cotisations-dans-lavs)
  — mécanismes de comblement et détermination finale par la caisse.

## 6. Fichiers lus et vérifications

### Contrats et gouvernance lus

- `.claude/agents/mint-swiss-brain.md`
- `.claude/skills/mint-swiss-compliance/SKILL.md`
- `.claude/skills/mint-operating-gates/SKILL.md`
- `CLAUDE.md`, `rules.md`, `LEGAL_RELEASE_CHECK.md`, `PRIVACY.md`
- `docs/MINT_AGENT_WORKFLOW.md`, `docs/AGENTS/swiss-brain.md`
- `docs/codex/DATA_LEDGER.md`, `docs/codex/DATA_QUEST.md`,
  `docs/codex/SCREEN_CONTRACTS.md`
- `.planning/ACTIVE_CONTEXT.md`
- `.planning/goals/G1-ledger-reality-baseline-2026-07-12.md`
- `.planning/goals/G1-blocking-gate-tickets.md`
- audit Sonnet et `SWISS_SCALE_WORDING_VERDICT.md` du dossier de preuve.

`AGENT_SYSTEM_PROMPT.md`, nommé par l'ancien skill, n'existe pas dans ce
checkout; `rules.md` et les contrats checked-in restent la vérité opératoire.

### Checks exécutés

- `python3 tools/checks/mint_os_doctor.py --repo-only` — PASS.
- `rg` des helpers, endpoints, prompts, ARB source keys et copies AVS — inventaire
  élargi ci-dessus.
- `python3 -m pytest tools/checks/tests/test_g1_p0_ledger_dead_keys.py::test_every_matrix_ticket_has_an_executable_blocking_contract -q`
  — PASS (`1 passed`), avec parité exacte registre/evidence.
- `python3 -m json.tool .planning/runtime-evidence/phase-37/ticket-evidence.json`
  et `git diff --check` — PASS.

## Conclusion de gate

- `P2-1` ne justifie pas `4/43` comme perte personnelle; il justifie la fin du
  faux dénominateur universel de durée.
- `P2-4` interdit le `44` ARB indépendant du calcul; le contrat count-only le
  ferme sans ajouter de donnée de profil.
- `P1-3` est une dette cross-stack plus large que deux helpers. Le ticket
  `G1-AVS-03` bloque G2 jusqu'à preuve RED puis GREEN et synchronisation API.
