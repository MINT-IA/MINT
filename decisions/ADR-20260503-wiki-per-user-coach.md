# ADR-20260503-wiki-per-user-coach

> Statut : **Proposed** (panel synthesis, awaiting Julien sign-off + post-Phase-54 timing)
> Auteur : Claude (Product Leader, MINT) — synthèse panel 6 experts
> Date : 2026-05-03

## Contexte

Pivot 2026-04-12 = « lucidité, pas protection ». Le coach actuel est `CoachContext` (objet stateless reconstruit à chaque tour) — opaque pour l'utilisateur, sans mémoire compoundante. Cleo, Plum, Revolut AIR : tous stockent la mémoire utilisateur en embeddings opaques. Yuh, neon, Tomorrow.one : aucune personnalisation IA réelle.

Karpathy publie en avril 2026 le pattern « LLM Wiki » (gist 442a6bf) : 3 layers `raw/` + `wiki/` + `schema` (markdown only, no vector DB). Adopté par Anthropic comme idiomatique pour Claude 4.7 (filesystem-as-memory).

Question : MINT doit-il adopter un **LLM Wiki par utilisateur** comme architecture canonique du coach V3 (post-TestFlight) ?

## Décision

**OUI — Hybrid Wiki-Schema-Spine + Letta-style memory blocks + structured projection.** Confiance 8/10. Convergence du panel (6 experts, WebSearch obligatoire chacun) sur YES *avec garde-fous*. Ship-able en V3 si et seulement si trois conditions sont remplies en même release :
1. SCHEMA.md de production avec 5 prohibitions LSFin hard-codées + lint server-side
2. Audit-trail per-mutation (mutation_id, inputs_hash, calculator_version, llm_model_id, prompt_template_version, hypotheses_json, prior_version_hash) retenu 10 ans
3. Bouton « Demander une revue humaine » sur chaque page projection (revDPA art. 21 + EU AI Act art. 86 enforcement août 2026)

### Architecture canonique V3

```
user_data/<user_id>/
├── raw/                     # Append-only, immutable. Bank statements, LPP certs, salary slips, OCR'd receipts. Never edited.
├── wiki/
│   ├── index.md             # Master catalog (one-line summaries, fits in single context)
│   ├── log.md               # Append-only chronological mutations (## [2026-05-03 14:32] ingest|UBS-statement-Q1)
│   ├── profile.md           # Detected archetype (swiss_native | expat_us FATCA | cross_border | independent_no_lpp | ...)
│   ├── life-events/         # Les 18 events equally weighted (rule #3 enforced PAR LA STRUCTURE, pas par discipline)
│   │   ├── housing.md
│   │   ├── family.md
│   │   ├── tax.md
│   │   ├── career.md
│   │   ├── debt.md
│   │   └── ... (13 autres)
│   ├── accounts/            # Une page par compte/police
│   ├── projections/         # Résultats financial_core/ + EnhancedConfidence + scénarios Bas/Moyen/Haut
│   ├── decisions/           # Historique user (« 2026-03-12 — rachat LPP envisagé puis reporté, raison X »)
│   └── memory_blocks.md     # Letta-style: current goal, last decision, open questions (prompt-resident, < 1K tokens)
└── schema.md                # Per-user constitution: archetype, banned-terms, voice tone, current focus
```

**Plus une projection structurée Postgres** (table `user_facts`) qui mirror les chiffres consommés par `financial_core/` — wiki canonique pour le narratif, projection canonique pour les maths. Le wiki *cite* le calculateur via templating déterministe ; il ne le restate jamais (élimine le risque de drift narratif vs. calcul, rule #4).

### Pourquoi cette architecture (synthèse panel)

| Dimension | Verdict | Argument court |
|---|---|---|
| LLM Knowledge Architecture | YES 8/10 | Wiki = sweet spot pour Claude 4.7 (filesystem-as-memory natif). Pure-Karpathy insuffisant pour finance régulée → bolter Letta + projection structurée. |
| Privacy nLPD/FINMA | YELLOW→GREEN | Format markdown vs JSON irrelevant légalement. Risque réel : **Anthropic prompt cache = sub-processeur US non déclaré** → signer ZDR addendum + Railway EU + audit log. < 1 semaine de travail pour passer en GREEN. |
| Competitor moat | YES — moat catégoriel | Memory layer = table-stakes (Cleo l'a). Le moat est la **lisibilité** : wiki user-readable + editable + exportable = catégorie de un sous nLPD/RGPD 2026. Cleo peut copier en 6 mois → ship le triplet (editable + provenance + export) comme **brand promise**, pas feature. |
| UX coach proactivity | YES strictly better | « Diff-style review notifications » + « Weekly Wiki Digest » = trust-loop qui compounde au-delà de week 1. Anti-pattern : ne **jamais** afficher les 18 events en grid. Bottom-sheet provenance par message coach. |
| DevOps cost | Viable 10K + 100K MAU | $0.40-0.85/user/mois sur Sonnet 4.6 + cache 1h-TTL + Haiku-first router + batch API nightly. **Comparable à RAG en coût, plus simple en ops** à <10 turns/user/jour. |
| FINMA/LSFin compliance | YELLOW-GREEN | Wiki *meilleur* que chat éphémère pour défensibilité. Risque : drift cumulative (18 events × 12 projections = plan financier personnalisé = Anlageberatung). Cap hard sur cross-references prompt + audit annuel external counsel. |

### Insight non-obvi

**La vraie valeur du wiki n'est pas le retrieve — c'est le write step comme événement de coaching.** Chaque compaction nocturne du wiki est une opportunité de proactive insight (« tu mentionnes ta fille à l'université 3 fois ce trimestre, on modélise un 3a split? »). On inverse la flèche habituelle « chat → memory » en « memory-maintenance → chat ». C'est ce qui rend le proactive-coaching économique (cron nightly batch API à -50%) plutôt que cher (tour-par-tour realtime).

## Alternatives considérées

| Option | Pourquoi rejetée |
|---|---|
| **Pure RAG (status quo + vector DB)** | Re-extrait à chaque tour, 0 compounding, opaque user, perd le moat lucidité. Cleo/Plum y sont déjà. |
| **GraphRAG** | Surcoût ops massif sans gain user-visible. Adapté > 100k entités/user, pas le profil MINT. |
| **MemGPT / Letta pur (memory blocks only)** | Excellent pour write-arbitration mais 0 audit-trail markdown → fail le test FINMA défensibilité. Garde-le comme couche, pas comme spine. |
| **Pure Karpathy LLM Wiki** | Pattern PKM single-user, pas multi-user régulé. Sans Letta blocks → pas de write-arbitration ; sans projection structurée → drift narratif vs. calcul. |
| **Defer à V4** | Cleo Memory devient table-stakes Q3 2026. Pas adopter en V3 = perdre le headline « première app argent qui te laisse lire et réécrire ce que l'IA pense de toi ». |

## Conséquences

### Positives
- Moat lucidité matérialisé (wiki user-readable = première fintech à le faire en EU/CH)
- Compounding accuracy mois après mois → battre Cleo sur la dimension qui importe en 2027
- Audit-trail défensible FINMA / LSFin / RGPD / nLPD by design
- Architecture alignée avec idiomes Claude 4.7 (filesystem memory) → moins de friction technique
- Ingest pipeline pluggable bank/LPP API quand elles arrivent (pas de re-architecture)
- Coût économique à scale ($0.40-0.85/user/mois)

### Négatives / Risques
- **Wiki rot à 5+ ans d'historique** (Karpathy lui-même cap à ~400k mots) → eviction/summarisation cron nécessaire dès day 1, pas « plus tard »
- **PII surface area explose** → encryption at rest per-user-key obligatoire avant production
- **Prompt cache = sub-processeur Anthropic US non déclaré** → signer ZDR addendum + privacy policy update obligatoire avant ship
- **Drift cumulative narratif vs. calculs** → contract dur : wiki cite, ne restate jamais
- **Personnalisation cumulative = Anlageberatung implicite** → cap cross-références wiki en prompt + audit external counsel quarterly
- **Coût LLM 5-8K$/mois à 10K MAU** → bien dans budget mais demande Haiku-first router + batch API discipline

### Conditions de ship V3 (gates obligatoires)

1. SCHEMA.md production avec prohibitions LSFin (no product reco, no allocation, no single-point projection, no suitability claim, no superlatif/banned-terms)
2. Lint server-side `check_banned_terms()` + `accent_lint_fr.py` sur **chaque page wiki avant injection coach**
3. Audit log (`wiki_revisions` table Postgres + diff append-only) chaque mutation
4. Anthropic ZDR addendum signé
5. Migration Railway EU pour users CH
6. Bouton « Demander revue humaine » sur chaque page projection
7. Eviction/summarisation cron en place dès la première release V3
8. UX onboarding 5-screens ≤ 90s vers premier moment lucidité (1 doc upload, pas tous)
9. Weekly Wiki Digest (dim 18:00, 3 cards max) shippé en même temps que le wiki, pas après

## Plan de migration

### Phase A — Pre-V3 (poursuit Phase 54 + closes en parallèle)
- Sign Anthropic ZDR addendum (Julien, 2 jours)
- Migrate Railway → EU region pour users CH (DevOps, 3 jours)
- Open ADR companion `ADR-20260510-anthropic-zdr-and-eu-region.md` documentant la décision

### Phase B — V3 Foundations (Milestone V3 « Wiki-Native Coach »)
1. **Schéma + storage** : Postgres `user_wiki_files` (user_id, path, content, version, updated_at, updated_by) + `wiki_revisions` (audit append-only) + R2 mirror pour `raw/`. Per-user advisory lock pour write-arbitration.
2. **Ingest worker** : Celery/RQ background queue. Realtime ingest = blocked. PDF→OCR→Haiku-summarise→wiki/. Batch API nightly recompile.
3. **SCHEMA.md generator** : par archetype + banned-terms + voice tone (FR primary).
4. **Coach turn** : Sonnet 4.6 + cache 1h-TTL, wiki context préfixe stable, Haiku-first router pour triage.
5. **Audit log + observability** : Datadog/Grafana cache-hit-rate alert <50% + Sentry sur lint failures.
6. **Mobile UX** :
   - « Mon profil MINT » tab (top: 3 events most recent, 15 collapsed)
   - Bottom-sheet « Why this nudge? » provenance par message
   - Diff-style review notifications (Granola pattern)
   - Weekly Wiki Digest (dim 18:00, 3 cards max)
7. **Onboarding 5-screens** : 1 phrase → 4-tile picker → 1 doc upload → live wiki gen ~12s → first earned nudge.

### Phase C — V3 Compliance Gate
- External counsel review (MME ou Lenz & Staehelin) du SCHEMA.md + audit log + drift-cap
- Penetration test de l'isolation per-user (RLS Postgres + per-user-key encryption)
- nLPD audit interne (right-to-deletion: `delete_user(uid)` wipe wiki + cache + Anthropic + R2 + backups en < 30j)

### Hors scope V3 (V4 candidates)
- Bank API ingest auto (en attente Open Banking CH maturité)
- LPP API ingest auto (en attente connecteurs)
- Multi-language wiki (FR-only V3, traduction à la requête)
- Cryptographic notarization (OpenTimestamps) — overkill, hash chain Postgres suffit
- Voice ingest (notes vocales → wiki)

## Annexe — KV-cache stability (impératif coût, ajouté 2026-05-03 post Manus lessons)

L'estimation cost panel ($0.40-0.85/user/mois) suppose **60-70% de cache hit rate**. Sans discipline KV-cache, on tombe à <20% et le coût × 5. Conditions hard d'architecture coach V3 :

1. **Préfixe stable** du system prompt : aucun timestamp à la seconde, aucun token random, aucune signature variable. Le SCHEMA.md per-user en début de prompt est l'ancre du cache.
2. **Append-only** : chaque tour ajoute un message, ne jamais éditer rétroactivement les tours précédents (cache invalidation immédiate).
3. **Sérialisation déterministe** : Python `json.dumps(..., sort_keys=True)` côté backend ; Dart custom encoder côté mobile pour l'historique chat envoyé.
4. **Tools : mask, don't remove** — pour gating un outil dans une session (ex : `delete_account` désactivé en mode anonyme), masquer via state machine sur logits, pas retirer la définition.
5. **Cache TTL 1h** explicit via `cache_control: {type: 'ephemeral', ttl: '1h'}` sur le wiki context. Sessions mobile bursty (open, 2-3 turns, background) saturent le 5-min TTL par défaut.
6. **Monitoring obligatoire** : log `cache_creation_input_tokens` + `cache_read_input_tokens` à Datadog/Grafana. Alerte hit-rate < 50% → drift de prefix silencieux.

## Annexe — Context lifecycle management (Patrick Debois thesis, ajouté 2026-05-03)

Patrick Debois (Tessl, ex-DevOps coiner) à QCon London 2026 : « le context mérite la même infra que le code ». Application V3 :

| Pratique code | Équivalent context V3 |
|---|---|
| Version control (`git`) | `wiki_revisions` Postgres table append-only ; per-user wiki dans bare git repo backup R2 |
| Code review | Diff-style review notification user (« MINT a appris ceci, confirme/corrige ») = review humain ; OR external counsel quarterly review du SCHEMA.md = review process |
| Tests | Lint server-side `check_banned_terms()` + `accent_lint_fr` + nouveau `wiki_schema_lint.py` qui valide structure de chaque page wiki AVANT injection coach |
| CI/CD | Pipeline ingest = compile-time validation : page wiki rejetée si fail lint, audit-trail si pass |
| Production monitoring | Sentry sur lint failures + Grafana sur cache hit rate + alerte si user wiki dépasse 400K mots (Karpathy ceiling) |

**Action concrète à intégrer V3 :** ajouter un service `wiki_lifecycle` qui implémente ces 5 piliers dès le MVP. Sans ça, le wiki devient une bombe à retardement compliance + coût + qualité.

## Liens

- Karpathy LLM Wiki gist : https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
- Plaban Nayak « Beyond RAG » : https://levelup.gitconnected.com/beyond-rag-how-andrej-karpathys-llm-wiki-pattern-builds-knowledge-that-actually-compounds-31a08528665e
- Letta agent memory : https://www.letta.com/blog/agent-memory
- Cleo Memory architecture : https://web.meetcleo.com/blog/memory-as-a-step-toward-more-human-ai
- FINMA Guidance 08/2024 AI : https://www.finma.ch/en/news/2024/12/20241218-mm-finma-am-08-24/
- VISCHER nLPD comparison : https://www.vischer.com/en/knowledge/blog/new-swiss-dpa-comparison-with-the-gdpr-39049/
- Anthropic prompt caching 2026 : https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- EU AI Act art. 86 : https://artificialintelligenceact.eu/article/86/
- LLM Wiki v2 lessons (Rohit G.) : https://gist.github.com/rohitg00/2067ab416f7bbe447c1977edaaa681e2
- Hidden Flaw in Karpathy LLM Wiki (Anand) : https://foundanand.medium.com/the-hidden-flaw-in-karpathys-llm-wiki-e3a86a94b459

## Panel signataires (résumés stockés dans `.planning/decisions/2026-05-03-wiki-panel-raw/`)

1. LLM Knowledge Architecture expert — HYBRID 8/10
2. Swiss Privacy nLPD/FINMA expert — YELLOW→GREEN avec ZDR + EU
3. Competitor analyst — YES moat catégoriel si triplet user-visible
4. UX coach proactivity expert — YES, strictement meilleur que CoachContext
5. DevOps & LLM cost expert — Viable 10K et 100K MAU
6. FINMA/LSFin compliance expert — YELLOW-GREEN avec garde-fous
