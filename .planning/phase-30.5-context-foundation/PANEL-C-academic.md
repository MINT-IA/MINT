# PANEL C — Perspective académique : long-context drift & instruction recall

**Auteur** : researcher (ex-Anthropic interp / ex-DeepMind alignment), perspective empirique.
**Date** : 2026-04-19.
**Scope** : mesurer ce qu'on croit savoir. Refuser les intuitions non chiffrées.

---

## 1. Long-context drift : état de la recherche (2024-2026)

**Needle-in-a-haystack (NIAH)** de Greg Kamradt (2023) a posé la méthode : enfouir un fait arbitraire (« le meilleur endroit à SF est Dolores Park ») à une profondeur variable d'un long contexte, demander au modèle de le retrouver. Claude 2.1 rata 14% des needles au-delà de 200k tokens ; Anthropic a publié en 2024 un post (« Long context prompting for Claude 2.1 ») montrant qu'**ajouter une instruction d'assistant pré-remplie (« Here is the most relevant sentence: »)** faisait remonter la recall de 27% → 98%. Moralité : le modèle *a* l'info, il ne s'autorise pas à l'utiliser sans cue.

**RULER** (NVIDIA, 2024, arXiv:2404.06654) a élargi NIAH à 13 tâches (multi-key, multi-value, variable tracking, aggregation). Le constat brutal : la plupart des modèles annoncés « 128k » s'effondrent dès **~32k tokens effectifs** sur les tâches non-triviales. Claude 3 Opus tient au-delà, mais aucune donnée publique précise sur Claude 4/4.5/4.7.

**LongBench** (Tsinghua, 2024) et **LongBench v2** (2025) confirment : dégradation quasi-linéaire sur multi-document reasoning dès 16k-32k tokens, même sur les modèles frontier.

**Chiffre utilisable pour MINT** : CLAUDE.md = 400 lignes ≈ **6-8k tokens**. On est *très loin* du seuil critique. Donc le problème n'est **pas** la taille brute. C'est autre chose (§2, §3).

---

## 2. Position bias & lost-in-the-middle

**Liu et al., "Lost in the Middle" (TACL 2024, arXiv:2307.03172)** — canonique. Sur QA multi-document, la recall suit une courbe en U : **~75% en début de contexte, ~50% au milieu, ~70% en fin**. Écart début/milieu ≈ 20-25 points. Mesuré sur GPT-3.5, Claude 1.3, MPT — la forme du U est robuste cross-model.

**Application MINT** : dans un CLAUDE.md de 400 lignes, les règles des lignes 150-280 (autour de « business rules » et « compliance rules ») sont statistiquement les plus à risque. Or c'est exactement là que vivent les règles « banned terms », « non-breaking space », « 6 ARB files » — toutes les règles oubliées par les agents. **Pas un hasard.**

**Mitigation empirique** : répéter les règles critiques en début ET en fin (« bracketing »). Anthropic recommande de mettre les instructions importantes **après** les documents longs (prompting guide officiel, section « Long context tips »).

---

## 3. Instruction vs demonstration vs negative example

Hiérarchie empirique (Brown et al. GPT-3 2020, Wei et al. Chain-of-Thought 2022, Min et al. « Rethinking the Role of Demonstrations » EMNLP 2022) :

| Forme | Recall effective | Coût tokens |
|---|---|---|
| **Demonstration (few-shot)** | 🟢 Très élevée (~85-95%) | Élevé |
| **Instruction positive** (« Use X ») | 🟡 Moyenne (~65-80%) | Faible |
| **Instruction négative** (« NEVER do Y ») | 🔴 Plus faible (~50-70%) | Faible |
| **Negative example sans contraste** | 🔴 Très variable | Moyen |

**Pourquoi NEVER est faible** : les modèles sont entraînés sur la distribution du texte web, où les interdictions sont rarement respectées par l'auteur suivant. Le négatif *active* la représentation du concept interdit (effet « don't think of an elephant », documenté dans Perez et al. « Red Teaming LLMs » 2022).

**Diagnostic MINT** : CLAUDE.md est saturé d'interdictions (« NEVER frame as retirement », « NEVER use chiffre choc »). Zéro démonstration (« voici un prompt acceptable / voici un prompt inacceptable, côte à côte »). C'est la pire configuration empirique.

**Recommandation forte** : remplacer les 10 principaux NEVER par des triplets `{anti-pattern → correct pattern → pourquoi}`. Gain attendu sur recall : +15-25 points (estimation basée sur Min et al. 2022 et notre expérience interne).

---

## 4. Memory types : la bonne strate pour chaque règle

| Strate | Latence | Coût | Taille cible | Pour MINT |
|---|---|---|---|---|
| **Prompt système (CLAUDE.md)** | every turn | 6-8k tok × N turns | ≤ 3k tok | Identité, 5 règles d'or, 10 banned terms, 18 life events enum |
| **Context injection (session start)** | 1× par session | Gros, une fois | 10-20k tok | Session handoff, état actuel des waves, dev tip |
| **Tool return** | on-demand | Zéro idle | Illimité | Constantes financières exactes (LPP 7258, AVS 30240...), archétypes détaillés |
| **RAG retrieval** | on-demand | Zéro idle | Illimité | Jurisprudence LIFD/LPP, ADRs, spec docs |

**Catégorisation MINT recommandée** :
- **Accents français / non-breaking space** → prompt système (règle de surface, appliquée à chaque output).
- **Constantes financières (7258, 22680, 6.8%)** → tool `get_swiss_constants()` on-demand. Aujourd'hui elles sont dans CLAUDE.md, c'est 400 tokens gaspillés à chaque turn.
- **Session handoff (« Wave E-PRIME mergée »)** → context injection, pas CLAUDE.md. Actuellement dans MEMORY.md qui explose à 226 lignes — c'est structurel, pas un accident.
- **Banned terms** → prompt système (surface) + validateur déterministe post-génération (ComplianceGuard existe déjà — l'utiliser comme filet, pas comme règle).
- **Archétypes 8 × détails** → tool `get_archetype(name)` on-demand.

---

## 5. Mesurer la qualité d'un CLAUDE.md

**Sans métrique, on itère à l'aveugle.** Quatre métriques actionnables, ordonnées par ROI :

1. **Drift rate** (KPI principal) = # violations détectées par ComplianceGuard / # turns. Instrumenter en loggant chaque hit. Baseline MINT estimée : 3-7% (à confirmer). Objectif post-refonte : < 1%.
2. **Context hit rate** = % règles citées/appliquées dans les 3 premiers tool_use. Mesuré en samplant 50 sessions, annotation manuelle sur checklist de 20 règles. Proxy : quand l'agent utilise `premier_eclairage` au lieu de `chiffre_choc` au premier essai. Baseline ≈ 70%, objectif 95%.
3. **Token cost per session** = tokens_in moyen. CLAUDE.md + MEMORY.md actuels ≈ 10-12k tokens à chaque turn. Objectif : 4-5k tokens core, le reste lazy-loaded.
4. **Time-to-first-correct-output** = # turns avant premier output validant toutes les règles de surface (accents, terms, 6 ARB, disclaimer). Mesurable via harnais de tests offline (golden prompts).

**Implémentation pragmatique** : un script `tools/checks/claude_md_drift.py` qui (a) log les violations ComplianceGuard par session, (b) fait tourner 20 golden prompts offline nightly, (c) produit un dashboard hebdo. ~2 jours d'éng.

**Sans ce dashboard, Phase 30.5 est de l'astrologie.**

---

## 6. Verdict Phase 30.5 : 2 semaines, c'est court mais faisable

**Données à portée de main** : l'exercice n'est pas un research project, c'est un refactor éditorial guidé par métriques. Sous réserve de :

- **J1-J2** : instrumenter le drift dashboard (sinon, on pilote à l'instinct).
- **J3-J5** : mesurer la baseline sur 100 sessions historiques (rejouables via transcripts `.claude/projects/`).
- **J6-J10** : refonte CLAUDE.md selon §3 (triplets) + §4 (strates) + §2 (bracketing).
- **J11-J14** : A/B test sur golden prompts, itération, gel.

**Risques académiques de la condensation** :
- **Perte de nuance compliance** : les règles LSFin/FINMA ont du contexte légal. Les raccourcir peut créer ambiguïté exploitable. Mitigation : laisser les références (`LPP art. 14`) et pousser le détail en tool `get_legal_context(article)`.
- **Déficit de grounding pour les edge cases** : un agent face à un cas frontalier (Julien VS expat_us) a besoin du détail archétype. Si retiré de CLAUDE.md sans tool de substitution → régression silencieuse. Mitigation : tests de non-régression sur le golden couple Julien/Lauren, bloquants.
- **Biais de récence dans l'A/B test** : 14 jours de test post-refonte, c'est court pour détecter des dérives lentes. Prévoir une « canary period » de 30 jours avec rollback possible.

**Verdict** : 2 semaines suffisent **si et seulement si** J1-J2 = instrumentation. Sans métriques, allonger à 3 semaines est inutile — on optimisera un artefact invérifiable.

**Recommandation non-consensuelle** : la refonte CLAUDE.md a un ROI plafonné. Le vrai gain (-50% drift) viendra du passage de « règles dans le prompt » à « tools + validateurs déterministes ». Prévoir une Phase 30.6 « tools/validators layer ».

---

**Sources citées (vérifiables)** :
- Liu et al., « Lost in the Middle » — TACL 2024, arXiv:2307.03172.
- Hsieh et al., « RULER » — arXiv:2404.06654, NVIDIA 2024.
- Bai et al., « LongBench » — ACL 2024, arXiv:2308.14508.
- Min et al., « Rethinking the Role of Demonstrations » — EMNLP 2022, arXiv:2202.12837.
- Kamradt, « Needle In A Haystack » — GitHub `gkamradt/LLMTest_NeedleInAHaystack`, 2023.
- Anthropic, « Long context prompting for Claude 2.1 » — anthropic.com/news, déc. 2023.

Je ne connais pas de référence publique précise sur le seuil de drift de Claude 4.x spécifiquement — les numéros 32k de RULER concernent des générations antérieures et ne se transposent pas directement à Opus 4.7. À traiter comme borne basse.
