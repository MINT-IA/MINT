# AGENTS — Swiss compliance & finance brain (MINT)

> Loaded on-demand pour compliance review, Swiss law references, archetype decisions, constants lookup.
> Ce fichier owns la FULL banned terms list, la table archetype, les key constants 2025/2026, les compliance rules.
> Tier 2 (project-specific). Tier 1 = `rules.md`. Compagnon : `.claude/skills/mint-swiss-compliance/SKILL.md`.

> **Pivot 2026-04-12 — lucidité, pas protection.** MINT = outil de lucidité (paix financière, contrôle, compréhension, zéro effort). PAS « protection-first » anxiogène. Voir MEMORY.md §VISION — LUCIDITE, PAS PROTECTION + `project_vision_post_audit_2026_04_12.md`. Compliance guardrails inchangés, messaging hiérarchie à revoir avec `MINT_IDENTITY.md` reconciliation (deferred v2.9+).

## 1. Banned terms (LSFin — full list)

User-facing text NE DOIT PAS contenir :

| Forbidden | Remplacement |
|-----------|-------------|
| garanti | possible, envisageable |
| optimal | adapté, pertinent |
| meilleur | favorable, avantageux |
| parfait (absolu) | adapté, pertinent |
| assuré | peut permettre |
| certain | probable, vraisemblable |
| sans risque | — (jamais utilisable) |
| conseiller | spécialiste (inclusif) |
| conseil financier | information éducative |
| recommandation personnalisée | piste de réflexion |
| vous devriez | vous pourriez envisager |
| « top X% des Suisses » | — (BANNED, no social comparison — compare only to user's own past) |
| « rendement garanti », « certain rapportera » | scénarios (Bas/Moyen/Haut) |

Backend `ComplianceGuard` scanne LLM output avant delivery à user. Phase 30.6 expose comme `check_banned_terms(text)` MCP tool.

## 2. Mandatory Disclaimers

Chaque simulator/calculation doit inclure :
```
« Les résultats présentés sont des estimations à titre indicatif,
basées sur les données fournies et la législation en vigueur.
Ils ne constituent pas un conseil financier personnalisé.
Consultez un·e spécialiste pour votre situation spécifique. »
```

## 3. Key constants 2025/2026

**Pillar 3a** : Salarié LPP : **7'258 CHF/an** | Indépendant sans LPP : **20% revenu net, max 36'288 CHF/an**.

**LPP** : Seuil d'accès **22'680** (art. 7) | Coordination **26'460** (art. 8) | Min coordonné **3'780** | Conversion **6.8%** (art. 14) | Bonif. : 7% (25-34), 10% (35-44), 15% (45-54), 18% (55-65) | EPL min **20'000** (OPP2 art. 5) | EPL blocage **3 ans** (art. 79b al. 3).

**AVS** : Taux total **10.60%** (5.30 + 5.30) | Rente max **30'240 CHF/an** | Cotisation min indép. **530 CHF/an** | AVS couple (marié, cap 150%) **3'780 CHF/mois** (LAVS art. 35).

**Mortgage** (FINMA/ASB) : Taux théorique **5%** | Amortissement **1%/an** | Frais **1%/an** | Charges max **1/3 revenu brut** | Fonds propres **20%** (max 10% du 2e pilier).

**Capital withdrawal tax** (progressive) :
`0-100k : ×1.00 | 100-200k : ×1.15 | 200-500k : ×1.30 | 500k-1M : ×1.50 | 1M+ : ×1.70`.

## 4. 8 Financial Archetypes

> **ADR** : `decisions/ADR-20260223-archetype-driven-retirement.md` (legacy name — applies to ALL projections, not just retirement).

Every projection MUST account for archetype. NEVER assume « Swiss native salarié ».
Archetypes affect ALL domains : tax, housing, 3a, LPP, family — pas juste retirement.

| Archetype | Detection | Key difference |
|-----------|-----------|----------------|
| `swiss_native` | CH + arrivé < 22 | Modèle par défaut |
| `expat_eu` | EU + arrivé > 20 | Totalisation périodes EU |
| `expat_non_eu` | Hors EU + arrivé > 20 | Pas de convention |
| `expat_us` | US citizen/green card | FATCA, PFIC, double taxation |
| `independent_with_lpp` | Indép. + LPP déclarée | Rachat possible |
| `independent_no_lpp` | Indép. + pas de LPP | 3a max 36'288 |
| `cross_border` | Permis G / frontalier | Impôt source |
| `returning_swiss` | CH + séjour étranger | Rachat avantageux |

## 5. 18 Life Events (definitive enum)

```
Famille:       marriage, divorce, birth, concubinage, deathOfRelative
Professionnel: firstJob, newJob, selfEmployment, jobLoss, retirement
Patrimoine:    housingPurchase, housingSale, inheritance, donation
Santé:         disability
Mobilité:      cantonMove, countryMove
Crise:         debtCrisis
```

## 6. Confidence Score (mandatory on ALL projections)

`EnhancedConfidence` (0-100%) — **4-axis** : completeness × accuracy × freshness × understanding (geometric mean).

- `enrichmentPrompts` — actions to improve accuracy (axis-specific).
- Uncertainty band (min/max) quand confidence < 70%.
- Data sources : estimated(0.25), userInput(0.60), crossValidated(0.70), certificate(0.95), openBanking(1.00).
- Understanding axis : financial literacy engagement (beginner/intermediate/advanced + coach session bonus).

## 7. Key Tax Rules (CRITICAL)

- **Rente LPP** = revenu imposable annuel (LIFD art. 22).
- **Capital retiré (2e/3a pilier)** = taxé séparément au retrait (LIFD art. 38) — applies à ANY age (EPL, retirement, departure).
- **SWR withdrawals** = consommation de patrimoine, PAS un revenu imposable.
- **NEVER double-tax** : retrait tax + income tax on SWR.
- **EPL (propriété)** = retrait anticipé du 2e pilier pour achat immobilier — taxé comme capital (LIFD art. 38), même logique.
- **3a retrait** = taxé comme capital, même barème progressif — pertinent dès le premier emploi.

## 8. Compliance interdictions absolues

1. **Read-Only** : no virements, paiements, bank account modifications.
2. **No-Advice** : no specific product recommendations (no ISINs, no tickers). Asset classes only.
3. **No-Promise** : no guaranteed returns. Scenarios (Bas/Moyen/Haut) + disclaimers.
4. **No-Ranking** : arbitrage options side-by-side, jamais ranked.
5. **No-Social-Comparison** : compare only to user's own past.
6. **No-LLM-Without-Guard** : all LLM output passes through `ComplianceGuard` avant user.
7. **Privacy** : never log identifiable data (IBAN, names, SSN, employer).

## 9. Required in every calculator/service output

- `disclaimer` — « outil éducatif », « ne constitue pas un conseil », « LSFin ».
- `sources` — legal references (LPP art. X, LIFD art. Y).
- `premier_eclairage` — first personalized insight (number, blind spot, implication, or question to ask). Remplace le legacy `chiffre_choc`.
- `alertes` — warnings quand thresholds crossed.

## 10. Swiss Law References

- **LPP (2e pilier)** : art. 7 (seuil d'accès), art. 8 (coord.), art. 14 (conversion 6.8%), art. 19-21 (survivant), art. 79b (rachat/EPL).
- **LAVS (1er pilier)** : art. 21 (âge référence), art. 29sexies (splitting divorce), art. 35 (cap couple 150%).
- **LIFD (impôt fédéral)** : art. 22 (rentes = revenu), art. 33 (déductions 3a/LPP), art. 38 (capital prévoyance tarif réduit 1/5).
- **LHID** : harmonisation fiscale cantonale.
- **OPP2** : art. 1 (déduction coordination), art. 5 (EPL min 20'000).
- **OPP3** : art. 2 (clause bénéficiaire), art. 7 (plafonds 3a).
- **LAMal** : assurance maladie.
- **LAI** : invalidité, 4 degrés (1/4 rente 40-49%, 1/2 50-59%, 3/4 60-69%, entière 70%+).
- **CO** : art. 324a (obligation employeur maladie, échelles BE/ZH/BS).
- **CC** : civil.
- **FINMA circulars** : compliance circulaires.

## 11. Language & Voice

- **Full spec** : `docs/VOICE_SYSTEM.md` — pillars, tone by context, audience adaptations, 50 avant/après.
- User-facing text en français (informel « tu »), inclusif (« un·e spécialiste »).
- Educational tone, jamais prescriptive. Conditional language (« pourrait », « envisager »).
- Non-breaking space (`\u00a0`) avant `!`, `?`, `:`, `;`, `%`.
- Voice : calme, précis, fin, rassurant, net. Jamais générique, jamais infantilisant.
- Adapt par context (discovery/stress/victory), mastery level, product moment — PAS par âge.

## 12. Golden test couple : Julien + Lauren

> Source of truth : `test/golden/` (xlsx + PDF certificats + JPEG).
> Couple teste MULTIPLE life events, pas juste retirement : housing (EPL), tax optimization (3a), couple dynamics (married caps), archetype differences (swiss_native vs expat_us/FATCA).

| | Julien | Lauren |
|--|--------|--------|
| Né le | 12.01.1977 | 23.06.1982 |
| Âge (03.2026) | **49** | **43** |
| Salaire brut | **122'207 CHF/an** | **67'000 CHF/an** |
| Canton | **VS** (Sion) | **VS** (Crans-Montana) |
| Nationalité | CH | US (FATCA) |
| Archetype | swiss_native | expat_us |
| Caisse LPP | **CPE** (rémun. 5%) | **HOTELA** |
| Salaire assuré LPP | **91'967 CHF** (CPE Plan Maxi) | standard coordonné |
| Bonif. vieillesse caisse | **24%** (CPE Plan Maxi, part vieillesse) | standard légal |
| Avoir LPP | **70'377 CHF** | **19'620 CHF** |
| Rachat max LPP | **539'414 CHF** | **52'949 CHF** |
| LPP projeté 65 | 677'847 (rente ~33'892/an) | ~153'000 |
| 3a capital | 32'000 | 14'000 |
| AVS couple (marié, cap 150%) | **3'780 CHF/mois** (LAVS art. 35) | — |
| Taux remplacement | **65.5%** (~8'505 vs 12'978 net/mois) | — |

**Multi-domain test coverage** (pas juste retirement) :
- **Tax** : capital withdrawal tax, income tax estimation, FATCA implications (Lauren).
- **Housing** : EPL eligibility (min 20'000), mortgage capacity (règle 1/3 avec revenu combiné).
- **3a** : annual max (7'258 salarié LPP), retrait anticipé scenarios.
- **Couple** : married AVS cap 150%, splitting, concubinage comparison.
- **Archetype** : swiss_native vs expat_us — projections et risques différents.

> Note : le taux 65.5% utilise le revenu net combiné du couple.
> Le code peut produire un résultat différent selon la projection LPP utilisée (formule légale standard vs certificat CPE Plan Maxi).

## 13. Safe Mode

Si le profil user indique toxic debt (consumer credit, leasing excessif) :
- DISABLE all optimization recommendations.
- PRIORITIZE debt reduction.
- Flag : « Situation de surendettement potentiel — les optimisations fiscales et de prévoyance sont désactivées tant que la dette n'est pas maîtrisée. »

## 14. Spec Format (pour python-agent)

```
## SPEC : [Nom du calcul]

### Source juridique
- Loi : [LPP/LIFD/LAVS] art. XX al. Y
- Date version : [année]

### Formule
variable = expression
- Hypothèse 1 : ...
- Hypothèse 2 : ...

### Cas de test (valeurs exactes)

| Profil | Input | Output attendu |
|--------|-------|----------------|
| Marc, ZH, célibataire | avoir=500k, taux=6.8% | rente=34'000/an |
| Sophie, VD, mariée | avoir=250k, taux=5.0% | rente=12'500/an |

### Texte éducatif (conforme)
« Le taux de conversion de 6.8% s'applique à la part obligatoire
de votre avoir LPP (LPP art. 14 al. 2). Ce taux peut être
inférieur pour la part surobligatoire, selon votre caisse de pension. »

### Disclaimer
[Disclaimer standard]
```

## 15. Reference docs

- `rules.md` — tier 1, fintech-grade principles.
- `LEGAL_RELEASE_CHECK.md` — pre-release compliance gate.
- `docs/MINT_IDENTITY.md` — mission, 5 principes, 4-layer engine.
- `.claude/skills/mint-swiss-compliance/SKILL.md` — skill opérationnel (spec format, chantiers).
- `visions/vision_compliance.md` — LSFin, FINMA, nLPD framework.
