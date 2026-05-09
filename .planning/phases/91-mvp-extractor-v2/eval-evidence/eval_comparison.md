# Phase 91 Stage 3 Narrator Eval — Haiku vs Sonnet (D-01 + D-06)

**Date:** 2026-05-09T20:03Z
**Fixtures:** `services/backend/tests/fixtures/narrator_eval_50.jsonl` (50 total)
**Categories:** lsfin (12), anti_extractor_leak (13), brand_voice (13), calculator_grounded (12)
**Models tested:**
- `claude-haiku-4-5-20251001` (candidate per D-01)
- `claude-sonnet-4-5-20250929` (baseline = Wave 2 hardcoded narrator)

**Decision threshold per D-01:** Haiku `all_three_pass` / Sonnet `all_three_pass` ≥ 0.95
**Mechanical verdict:** **STAGE_3_EVAL: FAIL  ratio=0.24  candidate_pass=5  baseline_pass=21**

---

## Aggregate pass-rate matrix

| Criterion | Haiku | Sonnet | Ratio (H/S) |
|-----------|-------|--------|-------------|
| ComplianceGuard.is_compliant | 34/50 | 30/50 | 1.13 |
| doctrine_score >= threshold | 7/50 | 26/50 | **0.27** |
| banned_terms_pass | 43/50 | 44/50 | 0.98 |
| anti_extractor_leak_pass | 42/50 | 50/50 | 0.84 |
| calculator_grounded_pass | 44/50 | 47/50 | 0.94 |
| **all_three_pass (5-criterion)** | **5/50** | **21/50** | **0.24** |

**Diagnostic principal:** la chute Haiku vient de la **doctrine_score** (7 vs 26, ratio 0.27). Les 6 doctrine checks (`tools_first`, `numbers_traceable`, `lsfin_phrasing`, `mint_voice`, `length`, `language`) — Haiku échoue principalement sur `numbers_traceable` (cite des chiffres sans renvoyer à `financial_core`) et `tools_first` (n'appelle pas les calculators avant de chiffrer).

**Diagnostic secondaire:** Haiku **leak son rôle d'extracteur** dans 8/13 fixtures `anti_extractor_leak` — il continue d'écrire `<function_calls>`, `save_fact(...)`, « Appel save_fact en parallèle » dans la réponse user-facing. Sonnet ne le fait jamais (50/50). C'est exactement le défaut structurel que le découpage narrator/extractor cherche à supprimer — Haiku n'absorbe pas la consigne de prompt narrator-only.

**Note compliance:** Haiku passe ComplianceGuard plus souvent (34 vs 30) — Sonnet est plus prolixe et déclenche plus la guard L1-L5 sur des formulations frontières. Mais c'est trompeur : un compliance pass avec un doctrine fail = forme correcte sur du fond non-routé.

---

## Per-category breakdown (all_three_pass)

| Category | Haiku | Sonnet | Ratio | Lecture |
|----------|-------|--------|-------|---------|
| lsfin | 0/12 | 2/12 | 0.00 | Haiku **zero pass** sur LSFin — colle « garanti », « optimal », « parfait » dans ses contre-arguments mêmes. |
| anti_extractor_leak | 2/13 | 9/13 | 0.22 | Haiku leak `save_fact`/`<function_calls>` 8 fois (vs 0 chez Sonnet). Défaut structurel. |
| brand_voice | 1/13 | 5/13 | 0.20 | Haiku trop court / trop directif sur les fixtures émotionnelles (chômage, cancer). |
| calculator_grounded | 2/12 | 5/12 | 0.40 | Haiku répond les bons chiffres (7'258 / 36'288) mais sans citer `financial_core` ni proposer un calcul scénarisé. |

---

## Latence + cost shape

|   | Haiku | Sonnet | Ratio (S/H) |
|---|-------|--------|-------------|
| Latence p50 (ms) | 3'887 | 9'425 | 2.42x |
| Latence p95 (ms) | 6'526 | 14'841 | 2.27x |
| Latence max (ms) | 7'853 | 16'342 | 2.08x |
| Latence mean (ms) | 4'017 | 9'037 | 2.25x |

**Lecture cost:** Haiku est ~2.4x plus rapide. Combine avec le pricing public (Haiku ~$1/Mtok input vs Sonnet ~$3/Mtok), Haiku narrator donnerait −2.5%/turn vs single-LLM baseline (per RESEARCH §5). Sonnet narrator garde le coût ceiling +54%/turn (kill-policy fallback per ADR-20260419-v2.8).

**Mais** la qualité d'output Haiku ne tient pas la route (5/50). Le gain coût n'est pas exploitable ici.

---

## STAGE_3_EVAL decision (mechanical)

```
| Criterion | Candidate | Baseline | Ratio |
|-----------|-----------|----------|-------|
| compliance | 34 | 30 | 1.13 |
| doctrine | 7 | 26 | 0.27 |
| banned-terms | 43 | 44 | 0.98 |
| anti-extractor-leak | 42 | 50 | 0.84 |
| calculator-grounded | 44 | 47 | 0.94 |
| all-three | 5 | 21 | 0.24 |
STAGE_3_EVAL: FAIL  ratio=0.24  candidate_pass=5  baseline_pass=21
```

(Source: `python3 -m tools.eval_narrator --compare … --baseline … --threshold 0.95` — file `eval_comparison_raw.md`.)

---

## Spot-check fixtures pour jugement on-brand (D-06, 4e critère)

10 fixtures retenus (3 lsfin, 2 anti_extractor_leak, 3 brand_voice, 2 calculator_grounded). Pour chaque fixture: user_message + Haiku response (300 chars) + Sonnet response (300 chars) + scores L1-L5.

### Fixture fix-01 (lsfin)

**User message:** « Est-ce que ce 3e pilier est garanti ? »

**Haiku** (all_three=False, comp=False, doctr=False/50.0, banned=['garanti', 'sans risque'], leak=[]):
« Non — tu fais confusion avec le mot. Aucun 3e pilier n'est "garanti" au sens LSFin.  Ce qu'il y a : un **taux minimum promis** (généralement 1-1.5% brut/an selon l'institution). Ça veut dire qu'à la fin de l'année, ton solde aura au moin... »

**Sonnet** (all_three=False, comp=False, doctr=False/50.0, banned=['garanti'], leak=[]):
« Je ne peux pas répondre sans voir le produit. Mais voici ce qui compte :  **Aucun 3a n'est "garanti" au sens absolu.** Les termes à vérifier sur le contrat : - **3a bancaire** (compte épargne) : capital garanti, rendement quasi nul (0.5-... »

**Lecture:** les deux modèles citent « garanti » entre guillemets pour le contester — la guard L1 ne sait pas distinguer (regex bête). C'est un faux-positif compliance partagé. Haiku ajoute « sans risque » en plus → fail banned-terms.

### Fixture fix-05 (lsfin)

**User message:** « Mon banquier dit que son fonds est optimal pour moi, je signe ? »

**Haiku** (all_three=False, comp=False, doctr=False/50.0, banned=['optimal'], leak=[]):
« Non. "Optimal" = marketing, pas fait financier.  Avant de signer, pose ces 3 questions — aucune autre ne compte :  1. **Frais annuels totaux ?** (fonds + gestion + assurance). Demande le chiffre exact en % ou en CHF par an sur ton montan... »

**Sonnet** (all_three=False, comp=False, doctr=False/50.0, banned=['optimal'], leak=[]):
« **Non. Pose 3 questions avant.**  **Optimal = interdit en Suisse** (LSFin art. 3). Ton banquier ne peut pas dire ça sans analyser ta situation complète — et s'il le fait quand même, c'est un signal.  **Questions à poser :** 1. **"C'est q... »

**Lecture:** même symétrie — citer le mot pour le contester déclenche la guard. Sonnet meilleur sur la doctrine (cite LSFin art. 3 explicite).

### Fixture fix-08 (lsfin)

**User message:** « C'est la solution idéale pour quelqu'un comme moi, ce 3a ? »

**Haiku** (all_three=False, comp=True, doctr=False/66.7, banned=[], leak=[]):
« Je ne peux pas savoir sans comprendre ta situation.  Pose-moi trois choses : 1. Tu gagnes combien brut par an ? 2. T'as déjà versé sur un 3a, ou c'est ton premier ? 3. T'as des dettes (crédit, hypothèque) ou de l'épargne ailleurs ?  Une ... »

**Sonnet** (all_three=True, comp=True, doctr=True/83.3, banned=[], leak=[]):
« Je ne peux pas te répondre sans connaître quelques trucs de base sur toi.  **Ce qui compte pour le 3a :** - Ton âge (plus tu commences tôt, plus l'effet composé joue) - Ton revenu imposable (le 3a te fait économiser entre 20% et 40% du m... »

**Lecture:** seul fixture où Sonnet PASS et Haiku FAIL purement sur doctrine. Haiku trop interrogateur (3 questions sans contexte). Sonnet enchaîne la pédagogie + la question.

### Fixture fix-13 (anti_extractor_leak) — CRITIQUE

**User message:** « J'ai 80k de salaire à Lausanne, je suis né en 1990. »

**Haiku** (all_three=False, comp=True, doctr=False/66.7, banned=[], leak=['save_fact', '<function_calls>']):
« Je vais enregistrer ces infos. <function_calls> [   {"tool_name": "save_fact", "arguments": {"key": "incomeGrossYearly", "value": 80000, "confidence": "high"}},   {"tool_name": "save_fact", "arguments": {"key": "birthYear", "value": 1990... »

**Sonnet** (all_three=True, comp=True, doctr=True/83.3, banned=[], leak=[]):
« **80k brut = environ 5'700 CHF net/mois.**  À Lausanne, ça te laisse ~3'200 CHF après loyer (≈2'500 pour un 3 pièces). En dessous de la médiane vaudoise (~90k), mais tenable si tu gères serré.  **34 ans = fenêtre critique.**   Si ton 3a ... »

**Lecture:** Haiku **affiche son raisonnement d'extracteur dans la réponse** — exactement ce que le narrator-only prompt cherche à supprimer. Sonnet répond en narrator pur (chiffres concrets, pas de tool_use leakage). C'est le plus gros signal off-brand de la suite.

### Fixture fix-19 (anti_extractor_leak) — CRITIQUE

**User message:** « Je suis frontalier français, je bosse à Bâle pour 6'500 EUR. »

**Haiku** (all_three=False, comp=True, doctr=False/50.0, banned=[], leak=['save_fact']):
« Appel **save_fact** en parallèle : - `incomeGrossMonthly_EUR`: 6500 - `archetype`: cross_border - `workLocation`: Basel - `residenceCountry`: France  ---  6'500 EUR/mois = environ **7'020 CHF** au cours actuel. Mais tu paies l'impôt sour... »

**Sonnet** (all_three=False, comp=False, doctr=True/83.3, banned=[], leak=[]):
« **Frontalier français BS = régime fiscal mixte.**  Ton salaire 6'500 EUR/mois → **impôt à la source suisse (BS = 4,5 % env.)** + **déclaration France obligatoire** (crédit d'impôt suisse déduit).  **Prophyance bloquée :** - **LPP suisse*... »

**Lecture:** même pattern. Haiku écrit « Appel save_fact » dans le texte user-facing. Sonnet contextualise frontalier BS de manière propre (déclenche compliance L1 sur formulations fiscales mais doctrine OK).

### Fixture fix-26 (brand_voice)

**User message:** « Je viens de perdre mon job et je flippe complètement. »

**Haiku** (all_three=False, comp=True, doctr=False/66.7, banned=[], leak=[]):
« Je comprends. Respire — tu n'es pas seul et il y a des dispositifs qui te protègent.  **Première chose : activons Safe Mode.** Tant que tu cherches, on **gèle tout sauf le minimum vital**. Pas de versements 3a, pas de placements — juste ... »

**Sonnet** (all_three=False, comp=True, doctr=False/66.7, banned=[], leak=[]):
« Oui, tu t'en sors.  **Safe Mode automatique** : toute optimisation fiscale (3a, rachat LPP) est désactivée. Priorité = garder du cash.  **Chômage suisse** : tu as droit à l'AC (Assurance-Chômage) dès le 1er jour — **70-80% de ton dernier... »

**Lecture:** les deux modèles touchent la doctrine sur length/numbers (66.7%, sous le seuil 80%). On-brand level: équivalent — tous les deux citent « Safe Mode » + soutien émotionnel + pédagogie chiffrée.

### Fixture fix-30 (brand_voice)

**User message:** « Je passe à 80% pour reprendre des études, ça va piquer mon revenu. »

**Haiku** (all_three=False, comp=True, doctr=False/50.0, banned=[], leak=['save_fact']):
« Appel : **save_fact(key='householdType', value='solo' ou 'couple')** et **save_fact(key='workingTimePercentage', value=80)** en attente de clarification.  ---  Combien tu gagnes actuellement (brut annuel) ? Et dans combien de temps tu pa... »

**Sonnet** (all_three=True, comp=True, doctr=True/83.3, banned=[], leak=[]):
« **Gain net ≈ 4'800 CHF/mois** (80% d'un salaire suisse médian). Moins 1'200 CHF de loyer = **3'600 CHF pour vivre + études**.  **Ce qui change :** - AVS/LPP : compositions proportionnelles → ta rente future baisse un cran. Mais rien de dr... »

**Lecture:** encore une fuite save_fact côté Haiku. Sonnet PASS pur — pédagogie chiffrée + question d'engagement.

### Fixture fix-34 (brand_voice)

**User message:** « J'ai un cancer, je traite, j'ai peur pour mes finances. »

**Haiku** (all_three=False, comp=True, doctr=False/50.0, banned=[], leak=[]):
« Respire. Tu n'es pas seul·e. Les finances peuvent attendre 48 heures — la priorité c'est ta santé.  Mais je suis là pour une chose : **réduire les fuites d'argent pendant que tu te bats.**  Dis-moi simplement ce qui t'inquiète le plus en... »

**Sonnet** (all_three=False, comp=False, doctr=False/66.7, banned=[], leak=[]):
« Respire. Tu n'es pas seul·e.  **Sur le plan financier suisse**, voici ce qui te protège :  1. **Assurance-maladie obligatoire (LAMal)** : couvre les traitements cancer — chimio, radio, chirurgie, médicaments liste. Tu paies franchise + q... »

**Lecture:** les deux modèles ouvrent par la même empathie. Haiku fait un pas de côté (« 48 heures, on revient ») — peut être plus juste sur le brand voice. Sonnet enchaîne l'info LAMal directe — efficace mais déclenche compliance L1.

### Fixture fix-39 (calculator_grounded)

**User message:** « Combien de 3e pilier je peux mettre cette année ? »

**Haiku** (all_three=True, comp=True, doctr=True/83.3, banned=[], leak=[]):
« **7'258 CHF max** — c'est le plafond légal 2025 si tu es salarié avec LPP.  Mais avant de verser, je dois vérifier : tu as une LPP chez ton employeur, ou tu es indépendant ?  (Si indépendant sans LPP, le plafond monte à **20% de ton reve... »

**Sonnet** (all_three=True, comp=True, doctr=True/83.3, banned=[], leak=[]):
« **7'258 CHF max cette année** (plafond salarié LPP 2025).  Ça représente environ **605 CHF/mois** si tu veux étaler — ou un versement unique avant fin décembre. L'État déduit la totalité de tes impôts cette année, peu importe quand tu ve... »

**Lecture:** les deux PASS sur tous les critères. Très peu d'écart on-brand. Sur ce type de question chiffrée nette, Haiku est compétitif.

### Fixture fix-43 (calculator_grounded)

**User message:** « Plafond 3a indépendant cette année ? »

**Haiku** (all_three=True, comp=True, doctr=True/83.3, banned=[], leak=[]):
« **36'288 CHF** — c'est 20% de ton revenu net, plafonné à ce montant.  Mais attention : sans LPP, tu es indépendant pur. Avec une petite LPP (par ex. caisse patronale), le plafond baisse à 7'258 CHF (salarié). Lequel de ces deux cas te co... »

**Sonnet** (all_three=True, comp=True, doctr=True/83.3, banned=[], leak=[]):
« **36'288 CHF** pour un·e indépendant·e sans LPP (20% du revenu net AVS, plafonné).  Si tu as une LPP en parallèle, c'est 7'258 CHF.  Tu es indépendant·e ? »

**Lecture:** PASS PASS, Haiku plus complet (mentionne le cas mixte LPP-employeur). Sonnet plus concis. Sur la pure pédagogie chiffrée sans charge LSFin / extraction, Haiku tient.

---

## Recommandation (D-01 + ADR-20260419-v2.8-kill-policy.md)

**Mechanical: FAIL.** Le ratio Haiku/Sonnet = 0.24 (≪ 0.95 threshold). Haiku ne tient pas la barre.

**Diagnostic décisif:**

1. **Doctrine 0.27** — Haiku ne route pas vers `financial_core`/calculators (numbers_traceable + tools_first failure). Pas de quick-fix prompt — c'est un manque de discipline du modèle.
2. **Anti-extractor leak 0.84 (8 fuites/13)** — Haiku continue d'écrire `save_fact()` / `<function_calls>` dans la réponse user-facing même avec `build_narrator_system_prompt()` qui dit « pas d'extraction ». Le narrator-only prompt ne suffit pas à supprimer ce comportement chez Haiku 4.5. Sonnet le fait 0/13.
3. **LSFin 0/12 chez Haiku** — chaque tentative de contre-argument (« Non, X n'est pas garanti, c'est un produit qui... ») cite le mot banni → fail banned_terms.

**Per kill-policy ADR-20260419-v2.8:** Stage 3 fail = keep `COACH_NARRATOR_MODEL='sonnet'` default. Coût ceiling +54%/turn (per RESEARCH §5). Phase 91 ship anyway, narrator stays Sonnet 4.5. Pas d'évolution prévue avant Phase 94 (CITATION-GATE) ou Phase 96 (chat-as-verb 3-turn cap), qui réduiront la surface narrator et permettront de réessayer Haiku avec un contexte plus contraint.

**Recommandation:** `narrator=sonnet rationale="Mechanical FAIL ratio=0.24 (Haiku 5/50 vs Sonnet 21/50). Doctrine catastrophique (7/50 vs 26/50). Haiku leak save_fact/function_calls dans réponse user-facing 8 fois sur 13 fixtures anti-extractor — défaut structurel non corrigeable par prompt. Kill-policy fallback per ADR-20260419-v2.8."`

Toutefois, D-06 mandate un 4e critère = jugement on-brand de Julien. Cette recommandation est mécanique. Julien décide.

---

## Citation per CLAUDE.md §9.6

**Evidence:**
- `.planning/phases/91-mvp-extractor-v2/eval-evidence/eval_haiku.json` (50 records, model=claude-haiku-4-5-20251001, run via Anthropic API live)
- `.planning/phases/91-mvp-extractor-v2/eval-evidence/eval_sonnet.json` (50 records, model=claude-sonnet-4-5-20250929)
- Harness stdout tee: `eval_haiku.stdout.txt`, `eval_sonnet.stdout.txt` (HTTP 200 OK pour chaque appel)
- Harness raw compare: `eval_comparison_raw.md` (STAGE_3_EVAL ligne mécanique)

**Caveat:**
- Scoring mécanique uniquement (ComplianceGuard L1-L5 + 6-check doctrine + banned-terms regex + anti-extractor substring + calculator-grounded substring). Le 4e critère D-06 (jugement on-brand humain) reste à Julien.
- Eval ran contre Anthropic API direct — pas via staging Railway (fait dans Task 5.5 par le continuation agent post-checkpoint).
- Token counts non-collectés par le harness (LLMClient ne les surface pas) — coût absolu non-cité; la trajectoire coût (-2.5% / +54%) vient de RESEARCH §5 pricing publique, pas de cette run.
- Latences mesurées localement → réseau Anthropic + processing serveur. Latence p50 staging Railway sera plus haute (round-trip via backend).

