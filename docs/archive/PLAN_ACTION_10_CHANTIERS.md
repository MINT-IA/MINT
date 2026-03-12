# Plan d'Action — 10 Chantiers pour faire de MINT la Référence Suisse

**Date** : 8 février 2026
**Auteur** : Expert Finance & Behavioral Finance CH
**Horizon** : 12–18 mois
**Architecture cible** : Flutter + FastAPI + RAG/LLM embarqué (Docling + Vector Store)

---

## ARCHITECTURE RAG — VUE D'ENSEMBLE

### Pourquoi un LLM en RAG pour MINT?

Le moteur actuel (`rules_engine.py`) est déterministe et limité à ~7 templates de goals. La réalité suisse comporte **des milliers de combinaisons** (26 cantons × ~2'200 communes × statuts civils × statuts professionnels × situations LPP × âges). Coder chaque règle en dur est intenable à l'échelle.

Le RAG permet de :
- **Ingérer** le corpus juridique et fiscal suisse (lois, ordonnances, barèmes, circulaires FINMA)
- **Retriever** les passages pertinents pour le profil exact de l'utilisateur
- **Générer** des réponses personnalisées, sourcées, et vérifiables
- **Mettre à jour** facilement (re-ingestion annuelle quand les lois changent)

### Architecture Cible

```
┌─────────────────────────────────────────────────────────────┐
│                      FLUTTER APP                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────┐  │
│  │  Wizard   │  │Simulators│  │ Timeline │  │  Report   │  │
│  └─────┬────┘  └─────┬────┘  └─────┬────┘  └─────┬─────┘  │
│        └──────────────┴──────────────┴──────────────┘       │
│                           │ HTTP/REST                       │
└───────────────────────────┼─────────────────────────────────┘
                            │
┌───────────────────────────┼─────────────────────────────────┐
│                     FASTAPI BACKEND                         │
│                           │                                 │
│  ┌────────────────────────┼────────────────────────────┐    │
│  │              ORCHESTRATEUR RAG                       │    │
│  │                                                      │    │
│  │  1. Profile Context  ──→  2. Query Builder           │    │
│  │                               │                      │    │
│  │  3. Retrieval ←── Vector Store (Qdrant/ChromaDB)     │    │
│  │       │                   ▲                          │    │
│  │       │            Embeddings (multilingual-e5)      │    │
│  │       ▼                   ▲                          │    │
│  │  4. LLM (Claude API / Mistral local)                 │    │
│  │       │                                              │    │
│  │  5. Guardrails ──→ Compliance Filter                 │    │
│  │       │                                              │    │
│  │  6. Structured Response (JSON)                       │    │
│  └───────┼──────────────────────────────────────────────┘    │
│          │                                                   │
│  ┌───────┼──────────────────────────────────────────────┐    │
│  │   RULES ENGINE (existant, conservé)                  │    │
│  │   Calculs déterministes : intérêts composés,         │    │
│  │   plafonds 3a, taux conversion, barèmes fiscaux      │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐    │
│  │   PIPELINE DOCLING (ingestion documents)             │    │
│  │                                                      │    │
│  │   PDF/DOCX ──→ Docling ──→ Markdown structuré       │    │
│  │                               │                      │    │
│  │                          Chunking sémantique         │    │
│  │                               │                      │    │
│  │                          Embedding + Indexation       │    │
│  │                               │                      │    │
│  │                          Vector Store                 │    │
│  └──────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

### Principes architecturaux non négociables

| Principe | Raison | Implémentation |
|----------|--------|----------------|
| **LLM = rédaction, pas calcul** | Les LLM hallucinent sur les chiffres | Le rules_engine reste la source de vérité pour tout calcul. Le LLM rédige les explications et contextualise |
| **RAG = sourçage, pas invention** | Chaque affirmation juridique/fiscale doit être traçable | Chaque réponse LLM inclut les `source_chunks` avec référence (loi, article, année) |
| **Privacy by design** | LPD + données financières sensibles | Embeddings locaux (multilingual-e5-large). Option LLM local (Mistral/Llama) ou Claude API avec zero-retention |
| **Guardrails compliance** | Même règles que le rules_engine actuel | Post-processing filter : pas de "garanti", pas de produit spécifique, disclaimers injectés automatiquement |
| **Déterminisme vérifiable** | Un même profil = mêmes calculs | Les calculs (impôts, rentes, plafonds) passent TOUJOURS par le rules_engine, jamais par le LLM |

---

## PHASE 0 — FONDATION RAG (Semaines 1–6)

### Objectif
Mettre en place l'infrastructure RAG et le pipeline d'ingestion documentaire avant d'attaquer les chantiers métier.

### 0.1 Pipeline Docling — Ingestion du corpus suisse

**Durée** : 3 semaines

**Dépendances Python à ajouter** :
```toml
# pyproject.toml — nouvelles dépendances
[project.optional-dependencies]
rag = [
    "docling>=2.0.0",              # IBM — parsing PDF/DOCX → structured
    "docling-core>=2.0.0",         # Core models
    "qdrant-client>=1.7.0",        # Vector store (self-hosted)
    "sentence-transformers>=3.0",   # Embeddings locaux
    "anthropic>=0.40.0",           # Claude API (LLM)
    "tiktoken>=0.7.0",            # Token counting
    "langchain-text-splitters>=0.2.0",  # Chunking sémantique
]
```

**Corpus à ingérer (priorité 1)** :

| Document | Source | Format | Priorité |
|----------|--------|--------|----------|
| LIFD (Loi impôt fédéral direct) | fedlex.admin.ch | PDF | P0 |
| LHID (Loi harmonisation impôts directs) | fedlex.admin.ch | PDF | P0 |
| LPP (Loi prévoyance professionnelle) | fedlex.admin.ch | PDF | P0 |
| OPP2 (Ordonnance LPP) | fedlex.admin.ch | PDF | P0 |
| OPP3 (Ordonnance 3e pilier) | fedlex.admin.ch | PDF | P0 |
| LAVS + RAVS (AVS loi + règlement) | fedlex.admin.ch | PDF | P0 |
| LAI (Loi assurance-invalidité) | fedlex.admin.ch | PDF | P1 |
| LAMal + OAMal | fedlex.admin.ch | PDF | P1 |
| CC art. 457-640 (Successions) | fedlex.admin.ch | PDF | P1 |
| CC art. 111-158 (Divorce) | fedlex.admin.ch | PDF | P1 |
| Barèmes ESTV (26 cantons) | estv.admin.ch | XLSX (déjà dans docs/taxe_rates/) | P0 |
| Circulaires FINMA (règles de conduite) | finma.ch | PDF | P2 |
| Barèmes prestations complémentaires | bsv.admin.ch | PDF | P2 |

**Tâches** :

```
0.1.1  Créer services/rag/ avec structure :
       services/rag/
       ├── __init__.py
       ├── pipeline/
       │   ├── ingest.py          # Orchestrateur ingestion
       │   ├── docling_parser.py  # Wrapper Docling
       │   ├── chunker.py         # Chunking sémantique (par article de loi)
       │   └── embedder.py        # Embedding multilingual-e5-large
       ├── retrieval/
       │   ├── retriever.py       # Query → chunks pertinents
       │   └── reranker.py        # Re-ranking par pertinence
       ├── generation/
       │   ├── llm_client.py      # Abstraction LLM (Claude / Mistral)
       │   ├── prompt_templates.py # Prompts métier suisse
       │   └── guardrails.py      # Filtre compliance post-génération
       ├── corpus/
       │   ├── federal/           # Lois fédérales (PDF)
       │   ├── cantonal/          # Lois cantonales
       │   ├── bareme/            # Barèmes fiscaux (XLSX)
       │   └── manifest.yaml      # Inventaire versionné du corpus
       └── tests/

0.1.2  Script d'ingestion automatisé :
       - Téléchargement fedlex.admin.ch (API REST disponible)
       - Parsing Docling avec OCR si nécessaire
       - Chunking par article/alinéa (pas par taille fixe)
       - Embedding + indexation Qdrant
       - Validation : chaque chunk porte metadata (loi, article, alinéa, date_version)

0.1.3  Tests d'ingestion :
       - test_parse_lifd.py : vérifier extraction correcte art. 33 LIFD (déductions)
       - test_parse_lpp.py : vérifier extraction art. 79b LPP (rachat)
       - test_chunk_quality.py : vérifier que les chunks sont sémantiquement cohérents
```

**Stratégie de chunking spécifique au droit suisse** :
```
Niveau 1 : Loi (ex: LPP)
  └── Niveau 2 : Titre/Chapitre (ex: "Titre 4 : Prestations")
        └── Niveau 3 : Article (ex: "Art. 79b Rachat")
              └── Niveau 4 : Alinéa (ex: "1. L'institution de prévoyance...")
```
Chaque chunk = 1 article complet avec ses alinéas. Metadata : `{loi, article, titre, date_version, langue}`.

### 0.2 Orchestrateur RAG + Guardrails

**Durée** : 2 semaines

**Tâches** :

```
0.2.1  Créer l'orchestrateur RAG (services/rag/orchestrator.py) :

       Input  : UserProfile + Question/Context
       Step 1 : Construire la query enrichie du profil
                (canton, âge, statut civil, statut pro, LPP oui/non)
       Step 2 : Retrieval — top-k chunks pertinents (k=8)
       Step 3 : Re-ranking — filtrer par pertinence + fraîcheur
       Step 4 : Construire le prompt LLM avec :
                - System prompt compliance MINT (existant dans AGENT_SYSTEM_PROMPT.md)
                - Chunks retrived avec sources
                - Profil utilisateur (anonymisé)
                - Instruction de format (JSON structuré)
       Step 5 : Appel LLM
       Step 6 : Guardrails post-génération :
                - Pas de "garanti", "assuré", "certain"
                - Pas d'ISIN, ticker, produit spécifique
                - Présence de disclaimers
                - Vérification des chiffres vs rules_engine
                - Sources citées
       Output : StructuredResponse (JSON) avec source_refs[]

0.2.2  Endpoint FastAPI :
       POST /api/v1/rag/query
       Body: { profile_id, context, question }
       Response: { answer, sources[], confidence, disclaimers[] }

0.2.3  Tests :
       - test_guardrails.py : injection de réponses non-conformes → vérifier le filtre
       - test_retrieval_accuracy.py : questions connues → vérifier les chunks retournés
       - test_no_hallucination.py : questions hors corpus → vérifier "je ne sais pas"
```

### 0.3 Décision LLM : API vs Local

**Option A — Claude API (Anthropic)** :
- Avantage : Qualité de raisonnement supérieure, multilingue natif (FR/DE/IT/EN)
- Risque : Données envoyées à l'extérieur (mitigé par zero-retention policy Anthropic)
- Coût : ~0.003–0.015 USD par requête (selon modèle)
- Recommandation : **Meilleur choix pour le MVP RAG**

**Option B — Mistral/Llama local** :
- Avantage : 100% privacy, pas de coût par requête
- Risque : Qualité inférieure sur le raisonnement fiscal suisse, besoin GPU
- Coût : Infrastructure GPU (Mac M4 Pro = suffisant pour Mistral 7B)
- Recommandation : **Phase 2, pour les utilisateurs enterprise/B2B**

**Décision recommandée** : Commencer avec Claude API + abstraction dans `llm_client.py` pour switcher plus tard.

---

## PHASE 1 — CHANTIERS QUICK-WIN (Semaines 4–12)

> Les chantiers 1, 3 et 7 peuvent démarrer en parallèle de la fin de Phase 0.

---

### CHANTIER 1 — Modèle fiscal réel (26 cantons + communes)

**Priorité** : CRITIQUE
**Durée** : 4 semaines
**Dépend de** : Phase 0 (partiellement — les barèmes XLSX sont déjà dans le projet)

#### Problème actuel
3 buckets (Low/Medium/High) avec coefficient unique. Marge d'erreur : 30-50%.

#### Solution cible
Modèle hybride : **rules_engine (calcul déterministe)** + **RAG (contextualisation et edge cases)**.

#### Tâches

```
1.1  Exploiter les fichiers ESTV existants (docs/taxe_rates/estv_scales*.xlsx)
     - Parser les 26 barèmes cantonaux avec Docling ou openpyxl
     - Créer un module : services/backend/app/services/tax_engine.py
     - Structures : CantonalTaxScale, CommunalMultiplier, ChurchTaxRate

1.2  Intégrer l'API ESTV (déjà utilisée dans tools/fetch_tax_data.py)
     - Automatiser le fetch annuel des barèmes
     - Stocker en JSON versionné dans corpus/bareme/

1.3  Nouveau modèle de calcul (rules_engine étendu) :

     tax_federal = compute_federal_tax(revenu_imposable, bareme_federal)
     tax_cantonal = compute_cantonal_tax(revenu_imposable, bareme_cantonal[canton])
     tax_communal = tax_cantonal * multiplicateur_commune[commune]
     tax_eglise = tax_cantonal * taux_eglise[canton] (si applicable)
     tax_fortune = compute_wealth_tax(fortune_nette, bareme_fortune[canton])

     Impot_total = tax_federal + tax_cantonal + tax_communal + tax_eglise + tax_fortune

1.4  Données communales :
     - Source : OFS (Office fédéral de la statistique) — liste des communes avec multiplicateurs
     - ~2'200 communes. Stocker dans un fichier JSON indexé par NPA (code postal)
     - Fallback : si commune inconnue → moyenne cantonale

1.5  Nouveaux champs Profile (SOT.md + OpenAPI) :
     - commune: string (NPA ou nom)
     - isChurchMember: boolean
     - wealthEstimate: double (pour impôt fortune)
     - taxAtSource: boolean (permis B/L)
     - propertyValue: double (pour valeur locative)

1.6  Simulateur "Miroir Fiscal" amélioré :
     - Input : Canton, Commune, Revenu, Statut civil, Enfants, Fortune, Eglise
     - Output : Décomposition visuelle (fédéral / cantonal / communal / église / fortune)
     - Comparaison : "Si tu habitais à [commune voisine], tu paierais X de moins"

1.7  RAG enrichissement :
     - Le LLM contextualise : "Dans le canton de VD, la déduction pour frais de garde
       est de max 7'100 CHF par enfant (art. X LICD). Tu pourrais déduire..."
     - Sources : LIFD art. 33, lois cantonales respectives

1.8  Tests :
     - test_tax_federal.py : cas de référence ESTV (publiés annuellement)
     - test_tax_cantonal.py : vérification croisée avec calculateur en ligne ESTV
     - test_tax_commune.py : spot checks sur 10 communes (ZH, GE, BS, BE, LU...)
     - test_valeur_locative.py : estimation vs réalité pour 3 profils types
```

#### Livrables
- [ ] Tax engine avec 26 barèmes cantonaux réels
- [ ] Base communale (~2'200 communes)
- [ ] Impôt sur la fortune
- [ ] Impôt ecclésiastique
- [ ] Simulateur miroir fiscal v2
- [ ] 20+ tests de calcul fiscal

---

### CHANTIER 2 — Module Divorce

**Priorité** : HAUTE
**Durée** : 4 semaines
**Dépend de** : Phase 0 (RAG pour contextualisation juridique)

#### Pourquoi c'est critique
~16'000 divorces/an en Suisse. Impact financier massif et mal compris. Aucun outil gratuit ne simule l'impact global.

#### Corpus RAG à ingérer
```
- CC art. 111–158 (Divorce)
- CC art. 120–125 (Effets du divorce — entretien, logement)
- CC art. 122–124e (Partage prévoyance professionnelle)
- LAVS art. 29sexies (Splitting des revenus AVS)
- LPP art. 22–22c (Partage LPP en cas de divorce)
- LIFD art. 33 al. 1 let. c (Déduction pension alimentaire)
- LIFD art. 23 let. f (Imposition pension alimentaire reçue)
- Jurisprudence TF clé : ATF 5A_907/2018 (calcul entretien)
```

#### Tâches

```
2.1  Nouveau parcours événement de vie : "Séparation / Divorce"
     - Écran S1 : Situation actuelle (marié depuis, enfants, régime matrimonial)
     - Écran S2 : Patrimoine commun (immobilier, LPP, 3a, épargne, dettes)
     - Écran S3 : Revenus des deux conjoints
     - Écran S4 : Résultat simulé

2.2  Simulateur d'impact financier (rules_engine étendu) :

     A. Partage LPP :
        - Calcul : (LPP_accumulé_pendant_mariage_conjoint_1 + conjoint_2) / 2
        - Alerte si proche de la retraite (>58 ans) : règles spéciales
        - Source : CC art. 123

     B. Splitting AVS :
        - Revenus inscrits pendant le mariage sont partagés 50/50
        - Impact sur la rente future AVS de chaque conjoint
        - Source : LAVS art. 29sexies

     C. Sort du 3e pilier :
        - 3a : fait partie du régime matrimonial (acquêts par défaut)
        - Si participation aux acquêts : 50% de l'augmentation pendant mariage
        - Source : CC art. 197ss

     D. Impact fiscal :
        - Avant : taxation commune (marié) → barème splitting fédéral
        - Après : 2x taxation individuelle (célibataire)
        - Pension alimentaire : déductible (payeur) / imposable (receveur)
        - Simulation comparée avant/après

     E. Impact logement :
        - Attribution du logement familial
        - Reprise hypothèque : capacité financière suffisante?
        - Valeur locative maintenue pour celui qui garde le bien

2.3  Contenu éducatif RAG :
     - "Qu'est-ce que le régime de la participation aux acquêts?"
     - "Comment fonctionne le partage LPP?"
     - "Quels sont mes droits concernant le logement familial?"
     - Le LLM répond en citant les articles du CC pertinents

2.4  Checklist d'actions "Si... alors..." :
     1. "Si tu es en procédure → demande ton certificat LPP pour connaître le montant accumulé pendant le mariage"
     2. "Si tu paies une pension alimentaire → note-la dans ta déclaration (déduction)"
     3. "Si tu gardes le logement → vérifie que ton revenu seul couvre les charges hypothécaires (règle du 1/3)"
     4. "Si tu n'as pas de contrat de mariage → le régime par défaut est la participation aux acquêts"

2.5  Pont vers professionnels :
     - Lien vers médiation familiale (par canton)
     - Lien vers aide juridique gratuite (seuil de revenu)
     - Disclaimer : "MINT ne remplace pas un avocat spécialisé en droit de la famille"

2.6  Tests :
     - test_lpp_split.py : 5 scénarios (mariage court, long, un seul revenu, etc.)
     - test_avs_splitting.py : calcul de l'impact sur la rente
     - test_tax_impact_divorce.py : avant/après pour 3 profils types
```

#### Livrables
- [ ] Parcours wizard "Divorce" (4 écrans)
- [ ] Simulateur partage LPP
- [ ] Simulateur impact fiscal avant/après
- [ ] Contenu éducatif RAG (CC art. 111-158)
- [ ] Checklist actions
- [ ] 15+ tests

---

### CHANTIER 3 — Module Invalidité / Incapacité de gain

**Priorité** : HAUTE
**Durée** : 3 semaines
**Dépend de** : Phase 0

#### Hook viral potentiel
"Découvre ce que tu toucherais si tu ne pouvais plus travailler demain" — visualisation du gap = choc cognitif → action.

#### Corpus RAG
```
- LAI (Loi assurance-invalidité) — conditions d'octroi, degrés d'invalidité
- LPP art. 23-26 (Prestations d'invalidité LPP)
- LAVS art. 43-44 (Rente AVS anticipée)
- CO art. 324a-324b (Obligation de l'employeur en cas de maladie)
- Échelles bernoise/zurichoise/bâloise (durée couverture employeur)
```

#### Tâches

```
3.1  Simulateur "Mon filet de sécurité" (rules_engine) :

     Phase 1 (0-3 mois) : Salaire maintenu par l'employeur
       → Durée selon ancienneté + échelle cantonale (Berne/Zurich/Bâle)
       → Alerte si pas d'IJM collective

     Phase 2 (3-24 mois) : IJM (indemnités journalières maladie)
       → Si IJM collective : 80% du salaire pendant 720 jours
       → Si pas d'IJM : RIEN (sauf aide sociale)
       → ALERTE CRITIQUE pour indépendants sans IJM

     Phase 3 (après 24 mois) : Rente AI
       → Quart de rente (40-49% invalidité) : max 613 CHF/mois
       → Demi-rente (50-59%) : max 1'225 CHF/mois
       → Trois-quarts de rente (60-69%) : max 1'838 CHF/mois
       → Rente entière (70%+) : max 2'450 CHF/mois
       → + Rente LPP invalidité (selon certificat)

     Visualisation :
     ┌──────────────────────────────────────────────────┐
     │ Revenu actuel :          ████████████ 8'000 CHF  │
     │ Phase 1 (employeur) :    ████████████ 8'000 CHF  │
     │ Phase 2 (IJM) :          █████████░░░ 6'400 CHF  │
     │ Phase 3 (AI+LPP) :       ████░░░░░░░ 3'200 CHF  │
     │                                                   │
     │ ⚠️  GAP MENSUEL :                    4'800 CHF   │
     └──────────────────────────────────────────────────┘

3.2  Alertes par statut professionnel :
     - Salarié avec IJM collective → "Tu es couvert, vérifie les conditions"
     - Salarié sans IJM → "Attention : après X semaines, plus rien"
     - Indépendant → "ALERTE : aucune couverture obligatoire. Action urgente."
     - Temps partiel → "Ta couverture LPP est réduite (déduction coordination)"

3.3  Contenu éducatif RAG :
     - "Quelle est la différence entre IJM et AI?"
     - "Est-ce que mon employeur est obligé de m'assurer?"
     - "Combien de temps suis-je couvert par mon employeur?" (avec échelle applicable)

3.4  Actions "Si... alors..." :
     1. "Si tu es indépendant sans IJM → souscris une assurance perte de gain (priorité absolue)"
     2. "Si tu es salarié → demande à ton RH si tu as une IJM collective et quel est le délai d'attente"
     3. "Si ton gap est > 2'000 CHF/mois → considère une assurance invalidité complémentaire"

3.5  Tests :
     - test_disability_gap.py : calcul du gap pour 5 profils
     - test_employer_coverage.py : durée selon échelle bernoise/zurichoise
     - test_ai_rente.py : montants selon degré d'invalidité
```

#### Livrables
- [ ] Simulateur gap invalidité
- [ ] Visualisation "filet de sécurité" (barres)
- [ ] Alertes par statut professionnel
- [ ] Contenu RAG (LAI, CO 324a, LPP 23-26)
- [ ] 12+ tests

---

### CHANTIER 4 — LPP approfondi ("Comprendre mon 2e pilier")

**Priorité** : HAUTE
**Durée** : 4 semaines
**Dépend de** : Phase 0, Chantier 1 (partiellement)

#### Tâches

```
4.1  Module "Lire mon certificat LPP" :
     - Saisie guidée des données clés du certificat de prévoyance :
       • Avoir de vieillesse obligatoire
       • Avoir de vieillesse surobligatoire
       • Salaire assuré + déduction de coordination
       • Taux de conversion (obligatoire vs enveloppe)
       • Prestations de risque (décès, invalidité)
       • Rachat maximum possible
     - Docling : possibilité future d'upload PDF du certificat → extraction automatique

4.2  Simulateur "Rente vs Capital" (rules_engine) :
     - Rente viagère : avoir × taux de conversion
       → Obligatoire : 6.8% (mais en discussion politique)
       → Surobligatoire : typiquement 4.5–5.5% (variable par caisse)
     - Capital : montant unique, placement libre
       → Simulation avec rendement prudent/central/optimiste
       → Fiscalité : impôt unique sur le capital (taux réduit, varie par canton)
     - Comparaison : point de break-even (âge à partir duquel la rente > capital placé)
     - Avertissement : "Le taux de conversion de 6.8% ne s'applique qu'à la part obligatoire.
       Votre caisse applique probablement un taux inférieur sur le surobligatoire."

4.3  Simulateur rachat LPP échelonné :
     - Calcul du rachat maximum (selon certificat)
     - Économie fiscale par année de rachat (taux marginal × montant)
     - Échelonnement optimal sur 3-5 ans (ne pas tout racheter la même année)
     - Contrainte : pas de retrait EPL dans les 3 ans après un rachat (LPP art. 79b al. 3)
     - Interaction avec le 3a : stratégie combinée rachat LPP + versement 3a

4.4  Module libre passage :
     - Alerte : "As-tu changé d'employeur? Tes avoirs de libre passage sont-ils transférés?"
     - Lien : Centrale du 2e pilier (https://www.sfbvg.ch/) pour retrouver des avoirs oubliés
     - Choix : fondation de libre passage (compte vs titres)

4.5  Retrait EPL (Encouragement propriété logement) :
     - Conditions : achat résidence principale uniquement
     - Montant : max avoir LPP (ou min 20'000 CHF) jusqu'à 50 ans,
       puis restrictions
     - Impact : réduction prestations décès/invalidité (ATTENTION)
     - Remboursement obligatoire en cas de vente
     - Interaction avec rachat : blocage 3 ans

4.6  Alerte déduction de coordination :
     - Si temps partiel < 80% → "Ta déduction de coordination de 25'725 CHF
       n'est pas proratisée par toutes les caisses. Vérifie avec ton employeur."
     - Impact chiffré : différence de rente sur 20/30 ans
     - Ciblage : femmes, temps partiels (gender gap prévoyance)

4.7  Contenu RAG :
     - LPP complète + OPP2
     - "Qu'est-ce que le taux de conversion et pourquoi baisse-t-il?"
     - "Puis-je racheter des années manquantes?"
     - "Que se passe-t-il si je quitte la Suisse?"

4.8  Tests :
     - test_rente_vs_capital.py : break-even pour 5 profils
     - test_rachat_fiscal.py : économie par tranche
     - test_epl_impact.py : réduction prestations risque
     - test_coordination_parttime.py : impact temps partiel
```

#### Livrables
- [ ] Saisie guidée certificat LPP (9 champs)
- [ ] Simulateur rente vs capital
- [ ] Simulateur rachat échelonné
- [ ] Module libre passage
- [ ] Alertes déduction de coordination / temps partiel
- [ ] 15+ tests

---

### CHANTIER 5 — Décès & Succession (nouveau droit 2023)

**Priorité** : MOYENNE-HAUTE
**Durée** : 3 semaines
**Dépend de** : Phase 0

#### Corpus RAG
```
- CC art. 457–640 (Droit des successions)
- Nouveau droit successoral (en vigueur 01.01.2023) :
  → Réserve descendants : 1/2 (au lieu de 3/4)
  → Suppression réserve des parents
  → Quotité disponible élargie
- OPP3 art. 2 (Clause bénéficiaire 3a)
- Lois cantonales sur impôts de succession (26 régimes différents)
```

#### Tâches

```
5.1  Simulateur successoral :
     - Input : Fortune totale, bénéficiaires (conjoint, enfants, concubin, autres)
     - Calcul : Répartition légale vs répartition avec testament
     - Nouveau droit 2023 : montrer la quotité disponible élargie
     - Fiscalité : impôt successoral par canton et par degré de parenté
       → Conjoint/descendants : 0% dans la majorité des cantons
       → Concubin : 20-50% selon canton
       → Fratrie : 5-25% selon canton

5.2  Checklist "Protection de mes proches" :
     □ Testament rédigé (ou mis à jour post-2023)?
     □ Clause bénéficiaire 3a vérifiée? (ordre OPP3 ≠ ordre successoral!)
     □ Concubin annoncé à la caisse de pension?
     □ Assurance décès couvrant le solde hypothécaire?
     □ Mandat pour cause d'inaptitude rédigé?
     □ Directives anticipées du patient?

5.3  Alerte clause bénéficiaire 3a :
     - Ordre légal OPP3 art. 2 : 1) Conjoint/partenaire, 2) Descendants,
       3) Parents, 4) Fratrie, 5) Autres héritiers
     - PIÈGE : Le concubin NON enregistré n'est PAS dans l'ordre légal
       → Action : "Demande un formulaire de clause bénéficiaire à ta banque 3a"

5.4  Contenu RAG :
     - "Quelles sont les nouvelles réserves héréditaires depuis 2023?"
     - "Est-ce que mon concubin héritera automatiquement?"
     - "Quelle est la fiscalité successorale dans mon canton?"

5.5  Modèles de lettres (générateur existant étendu) :
     - Template testament olographe simple
     - Template demande de clause bénéficiaire 3a
     - Template annonce concubin à la caisse de pension
     - Footer obligatoire : "Modèle à titre indicatif. Consultez un notaire."

5.6  Tests :
     - test_succession_legal.py : répartition légale (3 cas familiaux)
     - test_succession_testament.py : avec quotité disponible
     - test_succession_tax.py : fiscalité 5 cantons × 3 degrés parenté
     - test_3a_beneficiary.py : ordre OPP3 vs testament
```

#### Livrables
- [ ] Simulateur successoral (répartition + fiscalité)
- [ ] Checklist interactive "Protection proches"
- [ ] Alerte clause bénéficiaire 3a
- [ ] 3 templates de lettres
- [ ] 12+ tests

---

## PHASE 2 — CHANTIERS DE PROFONDEUR (Semaines 10–20)

---

### CHANTIER 6 — Segments sociologiques (gender gap, frontaliers, indépendants)

**Priorité** : HAUTE (différenciation marché)
**Durée** : 5 semaines
**Dépend de** : Chantiers 1, 3, 4

#### Tâches

```
6.1  Gender Gap Prévoyance :
     - Nouveau champ : taux d'activité (%)
     - Calcul automatique : impact déduction coordination sur rente LPP
     - Alerte : "En travaillant à 60%, ta lacune de prévoyance estimée
       sur 30 ans est de CHF XXX'XXX par rapport à un 100%"
     - Recommandations ciblées :
       → Rachat LPP volontaire (si possible)
       → 3a maximisé
       → Discussion avec employeur sur caisse de pension (proratisation coordination)
     - Statistique contextuelle : "En Suisse, les femmes touchent en moyenne
       37% de rente de moins que les hommes (OFS 2024)"

6.2  Parcours Frontaliers :
     - Détection : question wizard "Résides-tu en Suisse?" + "Permis?"
     - Règles spécifiques :
       → Pas de 3a (sauf exception : quasi-résident GE sous conditions)
       → Imposition à la source (pas de déclaration ordinaire sauf quasi-résident)
       → LPP : libre passage au départ, transfert limité si UE
       → AVS : coordination EU/AELE (totalisation des périodes)
     - RAG : accords bilatéraux CH-UE, conventions de double imposition
     - Alertes par pays frontalier (FR, DE, IT, AT, LI) : régimes différents

6.3  Parcours Indépendants :
     - Détection : employmentStatus == 'self_employed'
     - Alertes prioritaires :
       → Pas de LPP obligatoire → recommander affiliation volontaire
       → Pas de couverture IJM → URGENCE (lien vers assureurs)
       → 3a grand : plafond 36'288 CHF (20% du revenu net)
       → AVS : cotisations en tant qu'indépendant (barème dégressif)
       → Pas de LAA obligatoire → souscrire assurance accident
     - Simulateur : "Coût de ma protection complète"
       (AVS + IJM + accident + 3a = combien par mois?)

6.4  Parcours Permis B/C/L :
     - Permis B : retrait 3a/LPP possible au départ définitif
     - Impôt à la source : rectification possible si > 120k CHF (ou quasi-résident)
     - Permis C : mêmes droits que Suisses
     - Permis L : restrictions LPP (libre passage si < 12 mois)

6.5  Adaptation linguistique des comportements :
     - Metadata profil : langue/région (Romandie, Deutschschweiz, Ticino)
     - Ajustement ton : plus direct en DE, plus explicatif en FR
     - Exemples locaux : caisses de pension régionales, organismes cantonaux

6.6  Tests :
     - test_gender_gap.py : calcul lacune pour 60%/80%/100%
     - test_frontalier.py : règles par pays frontalier
     - test_independant.py : cotisations et couvertures
     - test_permis.py : droits par type de permis
```

#### Livrables
- [ ] Module gender gap prévoyance avec alertes
- [ ] Parcours frontalier (5 pays)
- [ ] Parcours indépendant
- [ ] Parcours permis B/C/L
- [ ] 15+ tests

---

### CHANTIER 7 — Assurances complètes

**Priorité** : MOYENNE
**Durée** : 3 semaines
**Dépend de** : Chantier 3

#### Tâches

```
7.1  Optimiseur franchise LAMal :
     - Input : dépenses santé annuelles estimées (fourchette)
     - Calcul : franchise 300 vs 500 vs 1'000 vs 1'500 vs 2'000 vs 2'500
     - Formule : Prime_annuelle + Franchise + Quote-part (10%, max 700 CHF)
     - Point de break-even par franchise
     - Alerte : "Rappel : changement possible chaque année avant le 30 novembre"
     - RAG : LAMal art. 62-64 (franchises et quotes-parts)

7.2  Check-up couverture assurance :
     - Checklist interactive :
       □ RC privée (recommandée, ~100 CHF/an)
       □ Ménage (obligatoire dans certains cantons)
       □ Protection juridique (utile si locataire ou salarié)
       □ Assurance voyage (si voyages fréquents)
       □ Assurance décès (si hypothèque ou famille)
       □ IJM individuelle (si pas de collective employeur)
       □ LAA privée (si indépendant)
     - Pour chaque : estimation de coût + niveau d'urgence (Critique/Utile/Optionnel)

7.3  Anti-Leasing amélioré (existant → enrichir) :
     - Intégrer le coût d'assurance casco dans le calcul total
     - Comparaison : leasing vs crédit vs achat cash vs occasion
     - RAG : LCD (Loi crédit à la consommation), taux max légal

7.4  Tests :
     - test_lamal_franchise.py : break-even pour 5 niveaux de dépenses santé
     - test_coverage_checklist.py : recommandations par profil
```

---

### CHANTIER 8 — Multilinguisme (DE prioritaire)

**Priorité** : HAUTE (accès marché)
**Durée** : 5 semaines (continu)
**Dépend de** : Tous les chantiers de contenu

#### Tâches

```
8.1  Architecture i18n Flutter :
     - Intl package déjà dans pubspec.yaml → activer les ARB files
     - Structure : lib/l10n/app_fr.arb, app_de.arb, app_it.arb, app_en.arb
     - Extraction de toutes les strings hardcodées (audit)

8.2  Traduction du corpus éducatif :
     - Tous les inserts éducatifs (education/inserts/*.md) → DE + EN
     - Wizard questions → DE + EN
     - Report templates → DE + EN
     - Disclaimer légaux → DE + EN (vérification juridique par langue)

8.3  RAG multilingue :
     - Le corpus juridique existe en FR + DE + IT sur fedlex.admin.ch
     - Ingérer les 3 versions linguistiques
     - Embedding multilingual-e5-large gère nativement FR/DE/IT/EN
     - Le LLM répond dans la langue de l'utilisateur

8.4  Terminologie financière suisse :
     - Glossaire FR ↔ DE ↔ IT ↔ EN des termes clés :
       → 3e pilier / 3. Säule / 3° pilastro / Pillar 3a
       → Caisse de pension / Pensionskasse / Cassa pensioni / Pension fund
       → Rachat / Einkauf / Riscatto / Buyback
       → Libre passage / Freizügigkeit / Libero passaggio / Vested benefits
     - Stocker dans un fichier de référence partagé (corpus/glossary.yaml)

8.5  Tests :
     - test_i18n_completeness.py : toutes les clés présentes dans toutes les langues
     - test_rag_multilingual.py : même question en FR/DE → mêmes chunks de loi (juste langue différente)
```

---

## PHASE 3 — CHANTIERS DE CRÉDIBILITÉ (Semaines 16–28)

---

### CHANTIER 9 — Partenariats institutionnels & distribution

**Priorité** : STRATÉGIQUE
**Durée** : En continu (12+ mois)

#### Tâches

```
9.1  Partenariats académiques :
     - ZHAW (Winterthur) : Institut für Banking und Finance
       → Validation du modèle fiscal et des simulateurs
       → Co-publication d'une étude sur la littératie financière des 22-35 ans
     - HEC Lausanne : Chaire de finance
       → Validation du modèle comportemental (nudges, JIT education)
     - FHNW (Fachhochschule Nordwestschweiz) : Institut für Finanzmanagement
       → Validation version alémanique
     - Deliverable : Label "Modèles validés par [Haute École]"

9.2  Partenariats associatifs :
     - FRC (Fédération romande des consommateurs) :
       → Co-branding sur le simulateur fiscal
       → Distribution via leur newsletter (300k+ contacts)
     - Acsi (Associazione consumatrici e consumatori della Svizzera italiana)
     - SKS (Stiftung für Konsumentenschutz) — équivalent alémanique
     - Pro Senectute : pour le segment 50-65 (retraite)
     - Caritas : intégration dans le Safe Mode (déjà esquissé)

9.3  Partenariats employeurs (B2B) :
     - MINT comme "financial wellness benefit" offert par l'employeur
     - Modèle : licence annuelle par employé (5-15 CHF/employé/an)
     - Pitch : "Réduisez le stress financier de vos collaborateurs, augmentez la rétention"
     - Cibles : grandes PME suisses (50-500 employés), secteur public, paraétatique
     - Version white-label possible pour caisses de pension

9.4  Partenariats caisses de pension :
     - Intégration API : certificat LPP digitalisé → import direct dans MINT
     - Valeur pour la caisse : engagement des affiliés, réduction des appels support
     - Cibles : Swisscanto, Tellco, Profond, CPEG, CIA, etc.

9.5  Relations régulateur :
     - Consultation proactive avec la FINMA sur le statut "outil éducatif"
     - Adhésion à un OAR (Organisme d'autorégulation) si nécessaire
     - Documentation du modèle de compliance pour audit externe
```

---

### CHANTIER 10 — Diversification revenus & validation

**Priorité** : STRATÉGIQUE
**Durée** : En continu

#### Tâches

```
10.1  Diversification monétisation :

      A. B2B Employeurs (voir 9.3)
         - Revenus récurrents, prévisibles
         - Objectif : 30% des revenus à 24 mois

      B. B2B Caisses de pension (voir 9.4)
         - White-label ou intégration API
         - Revenus récurrents

      C. Monétisation RAG premium :
         - Free : 3 questions RAG/mois + simulateurs basiques
         - Pro : Questions illimitées + simulations avancées + export PDF
         - Prix : 4.90 CHF/mois (plus accessible que 9.90 CHF)
         - Justification : le coût LLM est réel (~0.01 CHF/requête)

      D. Réduire dépendance affiliation 3a :
         - Diversifier : assurances, hypothèques, caisses de pension
         - Objectif : aucune source > 40% des revenus

10.2  Validation scientifique :

      A. A/B testing comportemental :
         - Mesurer : taux d'action après JIT education vs sans
         - Mesurer : impact du Safe Mode sur le comportement dette
         - Mesurer : précision perçue vs précision réelle des estimations

      B. Étude utilisateur (n=200+) :
         - Recrutement via universités partenaires
         - Protocole : pré-test (littératie financière) → usage MINT 3 mois → post-test
         - Publication : "Impact d'un outil JIT sur la littératie financière des jeunes actifs suisses"

      C. Audit externe annuel :
         - Exactitude des calculs fiscaux (vs ESTV officiel)
         - Conformité des disclaimers et du wording
         - Revue du modèle RAG (hallucinations, sourcing)

10.3  Métriques de référence (évolution de la North Star) :

      | Métrique | Actuelle | Cible 12 mois | Cible 24 mois |
      |----------|----------|---------------|---------------|
      | Users actifs | 0 | 2'000 | 10'000 |
      | Action Conversion (14j) | N/A | 25% | 40% |
      | Précision fiscale | ±30-50% | ±5-10% | ±2-5% |
      | Couverture cantonale | 8/26 | 26/26 | 26/26 + communes |
      | Langues | FR | FR + DE | FR + DE + IT + EN |
      | NPS | N/A | 40+ | 60+ |
      | Revenus mensuels | 0 | 5'000 CHF | 25'000 CHF |
```

---

## PLANNING GLOBAL

```
Semaines    1    2    3    4    5    6    7    8    9   10   11   12
            ├────────────────────┤
            │  PHASE 0 — RAG    │
            │  Foundation       │
            │  (Docling +       │
            │  Vector Store +   │
            │  Guardrails)      │
            ├────────────────────┤
                           ├─────────────────────────────────────┤
                           │  CHANTIER 1 — Modèle fiscal réel   │
                           ├─────────────────────────────────────┤
                                ├────────────────────────────────┤
                                │  CHANTIER 3 — Invalidité       │
                                ├────────────────────────────────┤
                                     ├──────────────────────────────────┤
                                     │  CHANTIER 2 — Divorce            │
                                     ├──────────────────────────────────┤

Semaines   10   11   12   13   14   15   16   17   18   19   20
            ├─────────────────────────────────────┤
            │  CHANTIER 4 — LPP approfondi       │
            ├─────────────────────────────────────┤
                 ├──────────────────────────────┤
                 │  CHANTIER 5 — Succession     │
                 ├──────────────────────────────┤
                      ├──────────────────────────────────────────┤
                      │  CHANTIER 6 — Segments sociologiques    │
                      ├──────────────────────────────────────────┤
                           ├──────────────────────────────┤
                           │  CHANTIER 7 — Assurances     │
                           ├──────────────────────────────┤

Semaines   16   17   18   19   20   21   22   23   24   25   26   27   28
            ├──────────────────────────────────────────────────────────────┤
            │  CHANTIER 8 — Multilinguisme DE (continu)                  │
            ├──────────────────────────────────────────────────────────────┤
            ├──────────────────────────────────────────────────────────────┤
            │  CHANTIER 9 — Partenariats (continu)                       │
            ├──────────────────────────────────────────────────────────────┤
            ├──────────────────────────────────────────────────────────────┤
            │  CHANTIER 10 — Diversification & Validation (continu)      │
            ├──────────────────────────────────────────────────────────────┤
```

---

## BUDGET ESTIMATIF (INFRASTRUCTURE)

| Poste | Mensuel | Annuel | Notes |
|-------|---------|--------|-------|
| Claude API (LLM) | 150–500 CHF | 1'800–6'000 CHF | ~2'000 requêtes/jour au pic |
| Qdrant Cloud (Vector Store) | 50–150 CHF | 600–1'800 CHF | Ou self-hosted (gratuit) |
| Hébergement backend | 50–200 CHF | 600–2'400 CHF | Railway / Fly.io / Infomaniak |
| GPU (si LLM local futur) | 200–500 CHF | 2'400–6'000 CHF | Mac Studio M4 Ultra ou cloud |
| Docling processing | ~0 CHF | ~0 CHF | Open-source, tourne localement |
| **TOTAL** | **250–850 CHF** | **3'000–10'200 CHF** | Scalable selon usage |

---

## RISQUES ET MITIGATIONS

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| Hallucination LLM sur un calcul fiscal | Haute | Critique | LLM ne calcule JAMAIS. Rules_engine calcule, LLM rédige. Post-processing vérifie |
| Changement législatif non capté | Moyenne | Haute | Re-ingestion annuelle du corpus. Alerte sur les dates de version des lois |
| FINMA requalifie MINT en "conseil financier" | Faible | Critique | Consultation proactive FINMA. SoA compliance. Pas de produit spécifique |
| Coût LLM API explose avec la croissance | Moyenne | Moyenne | Abstraction LLM → switch vers Mistral local si besoin. Cache des réponses fréquentes |
| Privacy breach (données profil + LLM externe) | Faible | Critique | Zero-retention API. Anonymisation avant envoi. Option LLM local pour B2B |
| Marché DE non réceptif (culture différente) | Moyenne | Moyenne | Partenariat avec institution alémanique dès Phase 2. Beta testeurs DE dès semaine 16 |

---

## CRITÈRES DE SUCCÈS ("Definition of Done" pour la Référence)

MINT sera considéré comme **référence suisse** quand :

- [ ] Précision fiscale < ±5% vs calculateur officiel ESTV (26 cantons)
- [ ] 4 langues opérationnelles (FR, DE, IT, EN)
- [ ] Validation académique publiée (1+ étude peer-reviewed ou rapport HES)
- [ ] Partenariat avec 1+ association de consommateurs (FRC, SKS, Acsi)
- [ ] Couverture : fiscalité + prévoyance 3 piliers + divorce + invalidité + succession
- [ ] 10'000+ utilisateurs actifs mensuels
- [ ] NPS > 50
- [ ] 0 hallucination LLM **impactante non corrigée dans les 48h** sur 12 mois (monitoring continu)
- [ ] Mentionné dans la presse spécialisée (Bilan, Handelszeitung, NZZ, Le Temps)
- [ ] 1+ employeur utilisant MINT comme benefit (validation B2B)
```

---

## REVUE CRITIQUE & DÉCISIONS (8 février 2026)

> Revue par l'équipe fondatrice. Ce qui suit **remplace** le planning original et les décisions LLM.

### PROBLÈMES STRUCTURELS IDENTIFIÉS

| # | Problème | Impact | Décision |
|---|----------|--------|----------|
| P1 | **Plan calibré pour 5-8 personnes, réalité = 1 personne + agents AI** | Gantt irréaliste, parallélisation impossible | Sérialiser. Max 1-2 chantiers actifs. |
| P2 | **Phase 0 (RAG) bloque 7/10 chantiers et prend 3+ mois seul** | Rien ne sort pendant 3 mois | RAG repoussé en Phase 2. Démarrer par rules_engine déterministe. |
| P3 | **Pas de MVP par chantier — tout livré "à la fin"** | Pas de feedback utilisateur avant des mois | MVP-1 semaine par chantier (80% de la valeur). |
| P4 | **26 cantons + 2'200 communes dès le départ** | Gouffre de complexité, données hétérogènes | 6 cantons MVP (ZH, BE, VD, GE, LU, BS) = 60% population. |
| P5 | **Budget infra sous-estimé x3-5** | Pas de marge, pas de monitoring, pas de CI/CD | Revoir le budget avec coûts réels. |
| P6 | **Pricing 4.90 CHF/mois trop bas** | 500 payants × 4.90 = 2'450 CHF < infra | BYOK model (l'user paie ses tokens) OU 9.90 CHF. |
| P7 | **"0 hallucination sur 12 mois" irréaliste** | Critère jamais atteint nulle part | Reformulé : "0 hallucination impactante non corrigée dans les 48h". |
| P8 | **Chantiers manquants** : Auth, Analytics, CI/CD, App Store, CGU/LPD | Pas de rétention, pas de mesure, pas de distribution | Ajoutés au planning révisé. |
| P9 | **Risque FINMA sous-évalué** | RAG + profil = conseil personnalisé ≈ conseil financier | Consultation juridique AVANT le RAG (2-5k CHF). |
| P10 | **Dépendances circulaires entre chantiers** | Deadlock si Phase 0 retarde | Chantier 1 (fiscal) et 3 (invalidité) sont standalone. |

### DÉCISION LLM — BYOK (Bring Your Own Key)

**Décision** : Abandon du modèle "MINT paie l'API LLM". Passage au modèle **BYOK**.

**Architecture 3 tiers** :

| Tier | Accès | LLM | Coût pour MINT |
|------|-------|-----|----------------|
| **Free** | Rules engine + simulateurs + contenu éducatif statique | Aucun | 0 CHF |
| **BYOK** | L'utilisateur branche sa clé Claude/OpenAI/Mistral. MINT orchestre le RAG. | Claude API / OpenAI / Mistral via clé user | 0 CHF (coût porté par l'user) |
| **Local (v2)** | Ollama / LM Studio pour les privacy-first | Llama 3 / Mistral local | 0 CHF |

**Justification** :
- Élimine le risque budgétaire LLM (pas de coût variable pour MINT)
- Modèle prouvé par Cursor, Continue, Cline (vibe coding ecosystem)
- L'user choisit son modèle et son budget
- Privacy : si l'user branche Ollama local, 0 donnée externe
- Permet de lancer le Free tier sans LLM du tout (déjà puissant avec rules_engine)

**Rejet du LLM local en v1** :
- Llama 3 8B / Mistral 7B : qualité insuffisante pour le raisonnement fiscal suisse trilingue
- Mistral Nemo 12B : potentiellement viable mais nécessite GPU + tuning
- Réservé pour la v2 quand le RAG est rodé et les prompts optimisés

### PLANNING RÉVISÉ (réaliste pour 1 personne + agent team)

```
Sprint   Durée   Chantier                          Teammates           État
─────────────────────────────────────────────────────────────────────────────
S0       FAIT    Chantier 1 MVP — Fiscal 6 cantons  swiss-brain+py+dart ✅ FAIT
S1       FAIT    Chantier 4 MVP — Rente vs Capital  swiss-brain → py    ✅ FAIT
S2       FAIT    Chantier 3 — Invalidité / Gap      swiss-brain → py    ✅ FAIT
S3       FAIT    Auth + persistence backend          python-agent        ✅ FAIT
S4       FAIT    Analytics + Onboarding + auth fix   dart + py           ✅ FAIT
S5       FAIT    Chantier 8 — Multilinguisme DE      dart + swiss-brain  ✅ FAIT
S6       EN COURS RAG Phase 0 (allégée, BYOK)        rag-backend + rag-flutter  🔄
S7       2 sem   Docling Phase 1 — Upload certificat LPP     py + dart  Backlog
S8       2 sem   Docling Phase 2 — Relevés bancaires CSV/PDF  py + dart  Backlog
S9       2 sem   Événements de vie — Changement d'emploi (LPP compare)  py + dart  Backlog
S10      3 sem   Chantiers 2+5 — Divorce + Succession  swiss-brain + py Backlog
S11      2 sem   Coaching proactif (notifications push)  dart + py      Backlog
S12      3 sem   Chantier 6 — Segments (gender gap, frontaliers, indépendants)  Backlog
S13+     TBD     Open Banking API (bLink/SFTI) — Après consultation FINMA  Backlog
─────────────────────────────────────────────────────────────────────────────
```

**Principe** : Un produit utilisable sort à chaque sprint. Pas de "big bang" à la fin.

### CHANTIER 11 — Document Intelligence (Docling)

**Priorité** : HAUTE (différenciation clé)
**Sprints** : S7–S8
**Dépend de** : S6 (RAG Phase 0)

#### Pourquoi c'est un game-changer
Aujourd'hui, l'utilisateur saisit manuellement ses données (sliders, champs). Avec Docling,
il uploade son certificat LPP ou sa fiche de salaire → MINT extrait automatiquement les
données et passe de "estimation générique" à "projection basée sur TES vrais chiffres".

#### Phase 1 — Certificat LPP (Sprint S7)

```
7.1  Pipeline Docling backend :
     services/backend/app/services/docling/
     ├── __init__.py
     ├── parser.py            # Wrapper Docling (PDF → structured JSON)
     ├── extractors/
     │   ├── lpp_certificate.py   # Extraction certificat LPP
     │   ├── salary_slip.py       # Extraction fiche de salaire
     │   └── tax_declaration.py   # Extraction déclaration fiscale (futur)
     ├── templates/
     │   └── lpp_fields.yaml      # Champs à extraire (avoir oblig, suroblig, etc.)
     └── tests/

7.2  Champs extraits du certificat LPP :
     - Avoir de vieillesse obligatoire (CHF)
     - Avoir de vieillesse surobligatoire (CHF)
     - Salaire assuré + déduction de coordination
     - Taux de conversion (obligatoire / enveloppe)
     - Prestations de risque (décès, invalidité)
     - Rachat maximum possible (CHF)
     - Nom de la caisse de pension

7.3  Endpoint FastAPI :
     POST /api/v1/documents/upload
     Body: multipart/form-data (PDF file)
     Response: {
       "document_type": "lpp_certificate",
       "extracted_fields": { ... },
       "confidence": 0.92,
       "raw_text": "...",
       "indexed_in_rag": true
     }

7.4  Flutter UI :
     - Écran "Mes documents" accessible depuis le profil
     - Upload via caméra (scan) ou sélecteur de fichiers
     - Preview du document + champs extraits (éditable par l'user)
     - Bouton "Confirmer et mettre à jour mon profil"
     - Auto-fill des simulateurs (Rente vs Capital, Rachat LPP)

7.5  Indexation RAG :
     - Le document parsé est indexé dans le vector store personnel
     - L'user peut demander : "Quel est mon potentiel de rachat?"
     - Le RAG retrouve l'info dans SON certificat

7.6  Privacy :
     - Document traité côté backend (ou on-device via WASM futur)
     - Jamais envoyé à un tiers sauf le LLM BYOK de l'user
     - Option "supprimer mes documents" dans les paramètres
     - Chiffrement at-rest

7.7  Tests :
     - test_lpp_parser.py : extraction sur 3 certificats types (Swisscanto, CPEG, Profond)
     - test_salary_parser.py : extraction fiche de salaire standard
     - test_document_upload.py : endpoint multipart upload
     - test_rag_personal.py : question sur document uploadé → réponse correcte
```

#### Phase 2 — Relevés bancaires CSV/PDF (Sprint S8)

```
8.1  Parsers par banque :
     - UBS : format CSV spécifique (;-separated, encoding ISO-8859-1)
     - PostFinance : format CSV + PDF relevé mensuel
     - Raiffeisen : format CSV
     - Credit Suisse/UBS : format unifié post-fusion
     - Neon / Yuh / Yapeal : CSV standard ou API directe (plus tard)

8.2  Catégorisation automatique des transactions :
     - Règles déterministes : loyer (>1000 CHF récurrent), prime LAMal (mensuel ~300-500)
     - Mots-clés suisses : Migros, Coop, CFF, Swisscom, Billag → catégories
     - Fallback : catégorie "Divers" modifiable par l'user

8.3  Intégration Budget :
     - Les transactions importées alimentent le module Budget automatiquement
     - Fini la saisie manuelle → "Importe ton relevé, on fait le reste"
     - Comparaison mois par mois → tendances

8.4  Tests :
     - test_ubs_csv.py : parsing relevé UBS réel (anonymisé)
     - test_categorization.py : 50 transactions → catégories correctes
     - test_budget_integration.py : import → budget auto-rempli
```

### CHANTIER 13 — Événements de vie : Changement d'emploi

**Priorité** : HAUTE (impact financier massif et sous-estimé)
**Sprint** : S9
**Dépend de** : S6 (RAG), S7 (Docling — pour comparaison automatique de certificats)

#### Pourquoi c'est critique
Les Suisses changent d'emploi en moyenne 5-7 fois dans leur carrière. À chaque fois,
ils comparent le salaire brut et oubient le plan LPP — qui peut valoir 10-30% du salaire
en valeur réelle. Un "meilleur" salaire avec un plan LPP inférieur peut coûter des
centaines de milliers de francs sur une carrière.

#### Le "salaire invisible" : ce que les gens ne voient pas

```
Éléments souvent ignorés lors d'un changement d'emploi :

1. Part employeur LPP (50% vs 65% = énorme différence)
2. Salaire assuré (minimum LPP vs salaire complet)
3. Taux de conversion surobligatoire (4.5% vs 5.8% = -25% de rente)
4. Déduction de coordination (fixe 25'725 vs proportionnelle)
5. Couverture risque (invalidité : minimum vs 80% du salaire)
6. Potentiel de rachat (dépend du plan)
7. Stratégie de placement de la caisse (impact rendement)
8. IJM collective incluse ou non
```

#### Tâches

```
13.1  Simulateur "Comparer deux emplois" (rules_engine) :
      Input :
      - Emploi actuel : salaire brut, données certificat LPP
      - Emploi envisagé : salaire brut, données nouveau plan LPP

      Output — Comparaison visuelle sur 7 axes :
      ┌──────────────────────────────────────────────┐
      │              Actuel     Nouveau     Δ        │
      │ Salaire net   6'800     7'200      +400 ✅  │
      │ Cotis. LPP    -500      -312       +188 ✅  │
      │ Capital retr. 450k      280k       -170k ❌ │
      │ Rente/mois    2'383     1'483      -900 ❌  │
      │ Couv. décès   340k      180k       -160k ❌ │
      │ Couv. inval.  6'400     3'200      -3200 ❌ │
      │ Rachat max    150k      40k        -110k ❌ │
      └──────────────────────────────────────────────┘

      Verdict : "Le Job A vaut CHF 10'800/an de plus en rente viagère,
      soit CHF 900/mois À VIE après la retraite."

13.2  Intégration Docling (si S7 fait) :
      - "Uploade ton certificat LPP actuel"
      - "Uploade le règlement ou certificat du nouvel employeur"
      - Extraction automatique → comparaison instantanée
      - Si pas de certificat du nouvel employeur : saisie manuelle guidée

13.3  Checklist "Avant de signer" :
      □ Demander le règlement de la caisse de pension
      □ Vérifier le taux de conversion surobligatoire
      □ Comparer la part employeur (50%? 60%? 65%?)
      □ Vérifier la déduction de coordination (fixe vs proportionnelle)
      □ Demander si IJM collective incluse
      □ Vérifier le délai de carence pour le rachat
      □ Calculer l'impact sur les prestations de risque
      □ Vérifier le libre passage : transfert en 30 jours max

13.4  Alertes ciblées :
      - Si perte LPP > gain salarial : "⚠ Ce changement te coûte CHF X/an en rente"
      - Si pas d'IJM dans le nouveau poste : "⚠ Tu perds ta couverture maladie"
      - Si temps partiel → temps plein : "✅ Ta couverture LPP va s'améliorer"
      - Si salarié → indépendant : "⚠ CRITIQUE — tu perds TOUTE couverture obligatoire"

13.5  Contenu éducatif RAG :
      - "Qu'est-ce que la déduction de coordination et pourquoi c'est important?"
      - "Comment lire un règlement de caisse de pension?"
      - "Que se passe-t-il avec mon libre passage quand je change d'emploi?"
      - "Puis-je garder mon ancien plan LPP?"

13.6  Pont avec Chantier 4 (LPP approfondi) :
      - Le simulateur utilise les mêmes modèles que Rente vs Capital
      - Les données du certificat uploadé (Docling) alimentent les deux simulateurs
      - Lien vers le simulateur de rachat : "Avec le nouveau plan, ton potentiel
        de rachat change — voici l'impact fiscal"

13.7  Tests :
      - test_job_compare.py : 5 scénarios (hausse salaire/baisse LPP, inverse, etc.)
      - test_lpp_plan_impact.py : impact 25 ans pour 3 profils types
      - test_checklist_alerts.py : alertes déclenchées selon les cas
      - test_independent_transition.py : salarié → indépendant (perte couverture)
```

#### Livrables
- [ ] Simulateur comparaison 2 emplois (7 axes)
- [ ] Intégration Docling (upload 2 certificats)
- [ ] Checklist interactive "Avant de signer"
- [ ] Alertes ciblées par type de transition
- [ ] Contenu éducatif (5 articles RAG)
- [ ] 12+ tests

---

### CHANTIER 14 — Open Banking & Coaching Proactif (Vision S13+)

**Priorité** : STRATÉGIQUE (long terme)
**Dépend de** : Consultation juridique FINMA + Docling opérationnel

#### Vision
MINT connecté aux comptes bancaires en temps réel pour du coaching proactif :
- "Tu as 2'300 CHF inutilisés ce mois → proposition 3a automatique"
- "Tes charges fixes ont augmenté de 15% — nouveau leasing?"
- "Impôts dans 45 jours — provision estimée : 8'200 CHF"

#### Pré-requis réglementaires
- Consultation FINMA : statut "outil éducatif" vs "service financier"
- Compliance nLPD (nouvelle Loi Protection Données suisse)
- Consentement explicite de l'utilisateur (opt-in granulaire)

#### Architecture cible
```
┌─────────────────────────────────────────────┐
│              FLUTTER APP                      │
│  ┌──────────┐  ┌──────────┐  ┌────────────┐ │
│  │ Dashboard │  │ Alerts   │  │ Documents  │ │
│  │ Live      │  │ Proactif │  │ Mes docs   │ │
│  └─────┬────┘  └─────┬────┘  └─────┬──────┘ │
│        └──────────────┴──────────────┘        │
│                    │ API                       │
└────────────────────┼──────────────────────────┘
                     │
┌────────────────────┼──────────────────────────┐
│              FASTAPI BACKEND                   │
│                    │                           │
│  ┌─────────────────┼───────────────────────┐  │
│  │          ORCHESTRATEUR MINT              │  │
│  │                                          │  │
│  │  RAG (BYOK LLM)                          │  │
│  │  Rules Engine (calculs déterministes)     │  │
│  │  Docling (parsing documents)              │  │
│  │  Event Engine (détection patterns)        │  │
│  │  Notification Engine (push proactif)      │  │
│  └──────────────────────────────────────────┘  │
│                                                │
│  ┌──────────────────────────────────────────┐  │
│  │  BANK CONNECTOR (Phase S12+)             │  │
│  │                                          │  │
│  │  bLink (SIX) / APIs directes             │  │
│  │  Read-only : soldes + transactions       │  │
│  │  Multi-bank aggregation                  │  │
│  └──────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
```

#### Phases
```
Phase 1 (S8)    : Import CSV/PDF via Docling → budget automatique
Phase 2 (S10)   : Push notifications proactives (basées sur profil + docs)
Phase 3 (S12+)  : API read-only bLink/SFTI (soldes + transactions live)
Phase 4 (S15+)  : Actions automatisées (virement 3a, alertes épargne)
                  → Nécessite licence FINMA probable
```

### BUDGET RÉVISÉ (réaliste)

| Poste | Mensuel | Notes |
|-------|---------|-------|
| Claude Code (dev agents) | 100–200 USD | Dream team multi-agents, Opus pour l'archi |
| Hébergement backend (Railway/Fly.io) | 0–50 CHF | Free tier suffisant MVP |
| LLM pour users | **0 CHF** | BYOK — l'user paie ses propres tokens |
| Vector Store (ChromaDB) | 0 CHF | Local, persisté sur disque |
| Docling processing | 0 CHF | Open-source, tourne localement |
| Consultation juridique FINMA | 2'000–5'000 CHF (one-shot) | AVANT Open Banking (S12) |
| **TOTAL mensuel** | **100–250 USD** | Scalable, pas de coût variable par user |

### RISQUES RÉVISÉS

| Risque | Probabilité | Mitigation |
|--------|-------------|------------|
| Hallucination LLM (calcul fiscal) | Haute | LLM interdit de calcul. Rules_engine seul. |
| FINMA requalification | **MOYENNE** (pas faible) | BYOK réduit le risque. Consultation AVANT Open Banking (S12). |
| Budget tokens Pro épuisé | Moyenne | Dream team parallélisée. Haiku pour le trivial. |
| Données fiscales BS/GE incorrectes | Confirmé | ±30% sur BS/GE. Disclaimer obligatoire. Fix dans sprint S1. |
| Docling parsing incorrect | Moyenne | Extraction vérifiable par l'user (preview + édition). Jamais d'auto-action sans confirmation. |
| Privacy documents uploadés | Faible | Traitement local. Chiffrement at-rest. Option suppression. Jamais de stockage tiers sans consentement. |
| Open Banking régulation | Haute | Phase S12+ = APRÈS validation juridique. CSV/PDF import d'abord (aucune régulation). |

---

## REVUE STRATÉGIQUE — 9 février 2026 (post S0-S15)

> Audit complet après 15 sprints livrés. Identification des 8 gaps thématiques critiques
> et cartographie exhaustive des 18 événements de vie.

### ÉTAT D'AVANCEMENT POST S0-S15

```
Sprint   Chantier                                    État     Commit
────────────────────────────────────────────────────────────────────
S0       Fiscal MVP (6 cantons)                      ✅ FAIT
S1       Rente vs Capital LPP                        ✅ FAIT
S2       Invalidité / Gap                            ✅ FAIT
S3       Auth + persistence backend                  ✅ FAIT
S4       Analytics + Onboarding                      ✅ FAIT
S5       Multilinguisme DE                           ✅ FAIT
S6       RAG Phase 0 (BYOK)                          ✅ FAIT
S7       Docling Phase 1 (certificat LPP)            ✅ FAIT
S8       Docling Phase 2 (relevés bancaires)         ✅ FAIT
S9       Événement : Changement emploi               ✅ FAIT  6e37675
S10      Divorce + Succession                        ✅ FAIT
S11      Coaching proactif                           ✅ FAIT
S12      Segments sociologiques                      ✅ FAIT
S13      LAMal + Franchise                           ✅ FAIT
S14      Open Banking (bLink)                        ✅ FAIT  49c64be
S15      LPP Deep (rachat, libre passage, EPL)       ✅ FAIT  8259894
────────────────────────────────────────────────────────────────────
```

### MATRICE DES GAPS THÉMATIQUES

| # | Thème | Couverture | Gap principal | Impact CHF |
|---|-------|-----------|---------------|-----------|
| G1 | **3a Deep** | 70% | Retrait fiscal, multi-comptes, assurance vs banque | 50-200k |
| G2 | **Hypothèque** | 5% | Capacité d'achat, SARON, valeur locative, EPL | 100-500k |
| G3 | **Indépendants** | 30% | Cotisations AVS, IJM, dividende vs salaire | 30-100k/an |
| G4 | **Chômage** | 0% | Indemnités LACI, délai cadre, impact LPP/3a | 20-80k |
| G5 | **Impôts avancés** | 50% | Frais effectifs, déductions oubliées, valeur locative | 5-25k/an |
| G6 | **Prévention dette** | 25% | Caritas, ratio surendettement, remboursement | Prévention faillite |
| G7 | **AVS avancé** | 40% | Anticipation, ajournement, rente survivant | 20-80k cumulé |
| G8 | **Mariage / Couple** | 15% | Bonus/pénalité fiscal, optimisation couple | 5-20k/an |

### 18 ÉVÉNEMENTS DE VIE — LISTE DÉFINITIVE

> Réf. complète : docs/ROADMAP_EVENEMENTS_VIE.md

```
FAMILLE (5)         PROFESSIONNEL (5)    PATRIMOINE (3)
─────────────       ──────────────────   ──────────────
marriage            firstJob             housingPurchase
divorce        ✅   newJob          ✅   housingSale
birth               selfEmployment       inheritance    ✅
concubinage         jobLoss
deathOfRelative ✅  retirement

SANTÉ (1)           MOBILITÉ (2)         CRISE (2)
──────────          ────────────         ──────────
disability     ✅   cantonMove           debtCrisis
                    countryMove          donation
```

✅ = simulateur complet (L4). Reste = L0-L2 seulement.

**Couverture actuelle** : 5/18 événements à L4 (28%)
**Cible 6 mois** : 12/18 à L3-L4 (67%)
**Cible 12 mois** : 16/18 à L3-L4 (89%)

### PLANNING RÉVISÉ S16-S22

```
Sprint   Durée   Thème                                  Événements couverts
─────────────────────────────────────────────────────────────────────────────
S16      2 sem   3a Deep + Prévention dette              debtCrisis (L4)
                 • Multi-comptes, retrait fiscal 3a
                 • Fintech comparator (Frankly ajouté)
                 • Assurance vs banque (warning jeunes)
                 • Caritas/Dettes Conseils + ratio dette
                 • Remboursement boule de neige/avalanche

S17      2 sem   Hypothèque + Achat immobilier           housingPurchase (L4)
                 • Capacité d'achat (règle 1/3 + 20%)
                 • EPL multi-sources (3a + LPP)
                 • SARON vs taux fixe
                 • Valeur locative + déductions proprio
                 • Amortissement direct vs indirect

S18      2 sem   Indépendants complet                    selfEmployment (L4)
                 • Cotisations AVS/AI/APG (barème réel)
                 • IJM perte de gain
                 • 3a grand (36'288 CHF)
                 • Dividende vs salaire (SA/Sàrl)
                 • LPP volontaire

S19      2 sem   Chômage + Premier emploi                jobLoss (L4), firstJob (L4)
                 • Indemnités LACI (70/80%, durée)
                 • Impact LPP/3a pendant chômage
                 • Onboarding "Premier emploi"
                 • Comprendre sa fiche de salaire

S20      2 sem   Impôts avancés + Déménagement           cantonMove (L4)
                 • Frais effectifs vs forfaitaires
                 • Top 10 déductions oubliées
                 • Simulateur déménagement fiscal
                 • Checklist "avant le 31 décembre"

S21      2 sem   AVS avancé + Retraite                   retirement (L4)
                 • Anticipation AVS (-6.8%/an)
                 • Ajournement AVS (+5.2-31.5%)
                 • Stratégie retrait 3a → LPP → AVS
                 • Rente de survivant

S22      2 sem   Mariage / Couple + Naissance             marriage (L4), birth (L4)
                 • Bonus vs pénalité fiscale
                 • Concubinage : zéro droit
                 • Allocations familiales par canton
                 • Impact temps partiel sur retraite
─────────────────────────────────────────────────────────────────────────────
```

**Post S22** : countryMove (L3), housingSale (L3), donation (L2), concubinage (L3)

### CRITÈRE DE SUCCÈS RÉVISÉ

MINT sera "le meilleur système de guidance financière suisse" quand :

- [ ] 16/18 événements de vie à L3+ (simulateur)
- [ ] 8/8 gaps thématiques couverts
- [ ] Précision fiscale < ±10% (6 cantons principaux)
- [ ] 3 langues (FR, DE, EN) — IT en L2
- [ ] 0 recommandation d'investissement quand dette détectée (Safe Mode)
- [ ] Chaque écran cite sa base légale (LPP art. X, LIFD art. Y)
- [ ] Chaque calcul a un disclaimer conforme
- [ ] Tests : 90%+ coverage sur rules_engine
- [ ] Liens vers aide professionnelle (Caritas, notaire, ORP) pour chaque situation de crise
