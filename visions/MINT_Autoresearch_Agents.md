# MINT — Autoresearch Agents

> **⚠️ LEGACY NOTE (2026-04-05):** Uses "chiffre choc" (legacy term → "premier éclairage", see `docs/MINT_IDENTITY.md`).

## Recherche Autonome Continue pour un Coach Financier AI Suisse

**Date** : Mars 2026
**Inspiré de** : [karpathy/autoresearch](https://github.com/karpathy/autoresearch)
**Principe** : Un agent AI tourne en boucle autonome — hypothèse → recherche → évaluation → itération — sans intervention humaine, chaque nuit ou chaque semaine.

---

## PHILOSOPHIE

Karpathy a conçu autoresearch pour optimiser un modèle ML en boucle (modifier → entraîner 5 min → mesurer → garder/rejeter). Pour Mint, on adapte ce pattern à **10 domaines de recherche** critiques. Chaque agent a :

- Un **program.md** (agenda de recherche)
- Un **asset modifiable** (le fichier/dataset qu'il enrichit)
- Une **métrique scalaire** (un chiffre unique qui détermine le progrès)
- Un **cycle time-boxé** (durée fixe par itération)
- Un **log persistant** (mémoire des itérations via JSONL/git)

Le rôle humain passe de "faire la recherche" à "définir la direction de recherche". L'agent exécute.

---

## ARCHITECTURE GLOBALE

```
mint-autoresearch/
├── agents/
│   ├── 01-swiss-regulation-watch/
│   │   ├── program.md          # Agenda de recherche
│   │   ├── knowledge_base.json # Asset modifiable (base de connaissances)
│   │   ├── evaluate.py         # Fonction d'évaluation (immutable)
│   │   ├── results.tsv         # Historique des itérations
│   │   └── autoresearch.jsonl  # Log append-only
│   ├── 02-competitor-intelligence/
│   ├── 03-pension-rates-tracker/
│   ├── 04-tax-optimization-lab/
│   ├── 05-ai-coaching-research/
│   ├── 06-content-generator/
│   ├── 07-ux-pattern-hunter/
│   ├── 08-financial-literacy-lab/
│   ├── 09-compliance-sentinel/
│   └── 10-market-timing-radar/
├── orchestrator.py             # Lance les agents selon le schedule
├── dashboard.md                # Synthèse auto-générée
└── config.yaml                 # Configuration globale
```

---

## AGENT 1 : Swiss Regulation Watch
### "Le veilleur réglementaire"

**Objectif** : Scanner en continu les changements réglementaires suisses affectant les 3 piliers, la fiscalité et le conseil financier. Mettre à jour la knowledge base de Mint automatiquement.

**Fréquence** : Toutes les nuits (1h de cycle)

```markdown
# program.md — Swiss Regulation Watch

## Research Goal
Identifier tout changement réglementaire suisse impactant les utilisateurs de Mint.
Enrichir la knowledge_base.json avec des fiches structurées (règle, date, impact, action Mint).
Métrique cible : regulation_coverage_score (% des réglementations en vigueur correctement documentées)

## Sources à scanner
- admin.ch (Conseil fédéral, messages, ordonnances)
- finma.ch (circulaires, communications)
- bsv.admin.ch (Office fédéral des assurances sociales — AVS/AI/LPP)
- estv.admin.ch (Administration fédérale des contributions)
- parlament.ch (motions, interpellations en cours liées aux piliers)
- vfrv.ch (Association suisse des fonds de placement)
- asip.ch (Association suisse des institutions de prévoyance)
- swissbanking.ch (directives ASB)
- Flux RSS et newsletters des 26 administrations cantonales

## Par itération
1. Scanner les sources pour tout nouveau document depuis la dernière itération
2. Classifier : [AVS | LPP | 3a | Fiscal | LSFin | FINMA | Autre]
3. Évaluer l'impact sur Mint : [Critique | Important | Mineur | Aucun]
4. Si impact ≥ Important : créer une fiche structurée dans knowledge_base.json
5. Si impact = Critique : générer une alerte dans alerts.json
6. Mettre à jour regulation_coverage_score

## Métrique
regulation_coverage_score = (réglementations documentées ÷ réglementations en vigueur connues) × 100
Cible : > 95%

## Contraintes
- Ne jamais supprimer une fiche existante (append-only)
- Toujours inclure la source officielle (URL)
- Horodater chaque fiche (date de détection, date d'entrée en vigueur)
- Distinguer : en vigueur / voté / en consultation / en discussion

## Output format (knowledge_base.json entry)
{
  "id": "REG-2026-042",
  "category": "LPP",
  "title": "Modification du taux de conversion minimal",
  "summary": "...",
  "effective_date": "2027-01-01",
  "status": "voted",
  "impact_mint": "critical",
  "action_required": "Mettre à jour LppCalculator + contenu éducatif",
  "source_url": "https://...",
  "detected_at": "2026-03-17T02:30:00Z"
}

## NEVER STOP
```

**Valeur pour Mint** : La base de connaissances RAG est toujours à jour. Les calculateurs sont alertés dès qu'un paramètre change. Mint est toujours le premier à informer ses utilisateurs.

---

## AGENT 2 : Competitor Intelligence
### "L'espion stratégique"

**Objectif** : Tracker toutes les apps fintech/prévoyance suisses et internationales, leurs updates, nouvelles features, pricing, et reviews.

**Fréquence** : Hebdomadaire (2h de cycle)

```markdown
# program.md — Competitor Intelligence

## Research Goal
Maintenir une intelligence concurrentielle exhaustive et actionnable.
Métrique : competitive_insight_freshness (âge moyen des fiches concurrentes, en jours)
Cible : < 14 jours

## Concurrents à tracker

### Suisse (primaire)
- Selma Finance, True Wealth, Descartes Finance, Viac, Finpension, frankly (ZKB)
- Neon, Yuh, Alpian, FlowBank successors
- VermögensZentrum (VZ), Comparis (prévoyance), AHV-Rechner
- Swiss Life MyLife, Baloise, Mobilière (apps de prévoyance)

### International (benchmark)
- Cleo, Monarch Money, Origin, Albert, Copilot Money, Plum, Emma
- bunq, Revolut (AI features), N26, Chime
- Betterment, Wealthfront, Empower, SoFi

## Par itération
1. Scanner App Store / Play Store pour updates des apps listées
2. Vérifier les changelogs (release notes)
3. Scraper les blogs/press releases des concurrents
4. Analyser les reviews récentes (App Store, Trustpilot)
5. Détecter tout nouveau entrant sur le marché suisse
6. Classifier les changements : [New Feature | Pricing | Partnership | Funding | Exit]
7. Évaluer la menace pour Mint : [Haute | Moyenne | Faible]
8. Si menace ≥ Moyenne : créer une fiche dans competitors.json

## Output format
{
  "competitor": "Finpension",
  "event_type": "new_feature",
  "title": "Lancement du simulateur de rachat 3a rétroactif",
  "description": "...",
  "threat_level": "high",
  "mint_response": "Accélérer notre 3a rétroactif simulator (Sprint S48)",
  "source": "https://...",
  "detected_at": "2026-03-17"
}

## NEVER STOP
```

**Valeur pour Mint** : Jamais surpris par un move concurrent. Le product backlog est informé en continu par l'intelligence compétitive.

---

## AGENT 3 : Pension Rates Tracker
### "Le gardien des chiffres"

**Objectif** : Maintenir à jour TOUS les paramètres financiers utilisés par les calculateurs Mint (taux LPP, barèmes AVS, limites 3a, taux d'imposition, etc.).

**Fréquence** : Quotidienne (30 min de cycle)

```markdown
# program.md — Pension Rates Tracker

## Research Goal
Garantir que chaque paramètre financier dans financial_core/ est à jour et correct.
Métrique : parameter_accuracy_score = (paramètres corrects ÷ paramètres total) × 100
Cible : 100% (tolérance 0)

## Paramètres à tracker

### AVS (1er pilier)
- Rente maximale/minimale (individuelle, couple)
- Plafond de cotisation (employé, indépendant)
- Cotisation minimale
- Facteurs de réduction/bonification par année
- 13e rente AVS (nouveau 2026) : montant, date de versement

### LPP (2e pilier)
- Déduction de coordination
- Seuil d'entrée
- Salaire assuré max
- Taux de conversion minimum obligatoire (6.8%)
- Taux de conversion surobligatoire médian (tracker par caisse)
- Bonifications de vieillesse par tranche d'âge (25-34, 35-44, 45-54, 55-65)

### 3e pilier (3a)
- Limite annuelle (salarié, indépendant)
- 3a rétroactif : modalités, limites, années rattrapables (nouveau 2026)

### Fiscal
- Barèmes fédéraux (par état civil)
- Barèmes cantonaux (26 cantons, communes principales)
- Déductions forfaitaires (frais professionnels, assurances, etc.)
- Valeur locative (paramètres cantonaux)

### Taux de référence
- Taux directeur BNS
- Taux hypothécaire de référence
- Inflation CPI Suisse
- Rendements historiques (obligations CH, actions CH, mixte)

## Par itération
1. Vérifier chaque paramètre contre sa source officielle
2. Comparer avec la valeur dans financial_core/
3. Si écart détecté : créer une alerte CRITIQUE dans alerts.json
4. Générer un diff (ancienne valeur → nouvelle valeur) pour review humaine
5. Recalculer parameter_accuracy_score

## Contraintes
- NE JAMAIS modifier financial_core/ automatiquement (review humaine obligatoire)
- Toujours inclure la source officielle + date de vérification
- Historiser chaque changement de paramètre (pour les simulations rétroactives)

## NEVER STOP
```

**Valeur pour Mint** : Les calculateurs ne donnent JAMAIS de chiffre faux. La crédibilité de Mint repose sur l'exactitude des chiffres — cet agent la garantit.

---

## AGENT 4 : Tax Optimization Lab
### "Le laboratoire fiscal"

**Objectif** : Découvrir et documenter des stratégies d'optimisation fiscale légales pour chaque canton suisse, par profil type.

**Fréquence** : Hebdomadaire (3h de cycle)

```markdown
# program.md — Tax Optimization Lab

## Research Goal
Identifier, valider et documenter les stratégies d'optimisation fiscale par canton × profil.
Métrique : strategies_per_archetype = nombre moyen de stratégies documentées par archétype Mint
Cible : > 15 stratégies / archétype

## Archétypes Mint (8 profils)
- Young Professional (22-28, célibataire, salarié)
- Young Couple (25-35, DINKs ou premier enfant)
- Family Builder (30-45, famille, propriétaire ou locataire)
- Career Peak (40-55, hauts revenus, patrimoine croissant)
- Pre-Retiree (55-65, optimisation pré-retraite)
- Early Retiree (60-65, retraite anticipée)
- Retiree (65-80, optimisation revenu retraite)
- Senior (75-99, succession, simplification)

## Stratégies à explorer par itération
1. Scanner les publications fiscales cantonales (26 cantons)
2. Identifier des stratégies spécifiques au canton (ex: déduction rachat LPP à Genève vs Zurich)
3. Simuler l'impact avec les barèmes actuels (calcul automatisé)
4. Valider la légalité (cross-référence avec les circulaires AFC + pratiques cantonales)
5. Classifier par archétype et phase de vie
6. Calculer l'économie annuelle typique (fourchette min-max)
7. Rédiger une fiche "Si... alors..." (format Mint JIT card)

## Output format (strategies.json entry)
{
  "id": "TAX-VD-2026-007",
  "canton": "VD",
  "archetype": ["Pre-Retiree", "Career Peak"],
  "title": "Rachat LPP échelonné sur 3 ans avant retraite",
  "description": "...",
  "annual_savings_chf": {"min": 3200, "max": 12800},
  "conditions": "Revenu imposable > 120K, potentiel de rachat > 0",
  "legal_basis": "LIFD art. 33 al. 1 let. d",
  "confidence": "high",
  "jit_card_text": "Si tu prévois de prendre ta retraite dans 3-5 ans et que tu as un potentiel de rachat LPP, alors un rachat échelonné pourrait te faire économiser entre 3'200 et 12'800 CHF par an."
}

## Contraintes
- Toujours mentionner la base légale
- Toujours donner des fourchettes, jamais des montants absolus
- Disclaimer si la stratégie est "agressive" (zone grise)
- Ne jamais recommander de l'évasion fiscale

## NEVER STOP
```

**Valeur pour Mint** : L'AI de Mint dispose d'un catalogue exhaustif de stratégies fiscales, validées par canton et par profil. Les JIT cards deviennent ultra-pertinentes.

---

## AGENT 5 : AI Coaching Research
### "Le chercheur académique"

**Objectif** : Scanner en continu la littérature académique sur le coaching AI, la behavioral finance, les JITAI, la gamification en finance, et la confiance dans les AI advisors.

**Fréquence** : Hebdomadaire (2h de cycle)

```markdown
# program.md — AI Coaching Research

## Research Goal
Maintenir une veille académique exhaustive pour informer les décisions produit de Mint.
Métrique : research_relevance_score = (papers avec implications actionnables ÷ papers analysés) × qualité moyenne
Cible : > 20 papers actionnables / trimestre

## Thèmes à scanner
1. AI financial coaching / robo-advisory
2. Conversational AI for financial literacy
3. Trust in AI advisors (XAI, transparency)
4. Just-in-Time Adaptive Interventions (JITAI)
5. Gamification in personal finance
6. Behavioral nudges in fintech
7. Progressive profiling / onboarding UX
8. Lifecycle financial planning with AI
9. Financial wellness and stress reduction
10. Swiss pension system digitalization
11. Voice UI for financial services
12. Explainable AI in financial services
13. AI coaching effectiveness (meta-analyses)
14. Age-adaptive AI interfaces (22-99 span)

## Sources
- Google Scholar (alertes par thème)
- arXiv (cs.AI, cs.HC, q-fin)
- SSRN (Financial Economics)
- PubMed/PMC (JITAI, behavioral interventions)
- ACM Digital Library (HCI, UX)
- Frontiers (Psychology, AI)
- Journal of Financial Planning
- Financial Analysts Journal (CFA)

## Par itération
1. Scanner les nouvelles publications (depuis dernière itération)
2. Filtrer par pertinence pour Mint (score 0-10)
3. Si pertinence ≥ 7 : créer fiche détaillée
4. Extraire les implications pratiques pour le produit
5. Identifier les métriques citées (effect sizes, p-values)
6. Classifier par thème et par feature Mint concernée
7. Mettre à jour le research_summary.md

## Output format
{
  "paper_id": "ACAD-2026-089",
  "title": "Dynamic Nudging in Financial Apps: A 12-Month RCT",
  "authors": "Smith et al.",
  "venue": "Journal of Financial Planning, 2026",
  "relevance_score": 9,
  "key_finding": "Nudges adaptatifs augmentent l'épargne de 18% vs nudges statiques",
  "effect_size": "d=0.42, p<0.001",
  "implication_mint": "Migrer les JIT cards vers des nudges adaptatifs basés sur le comportement passé",
  "features_impacted": ["jit_engine", "notification_system"],
  "url": "https://doi.org/..."
}

## NEVER STOP
```

**Valeur pour Mint** : Chaque décision produit est evidence-based. Les nouvelles features sont justifiées par la recherche, pas par l'intuition.

---

## AGENT 6 : Content Generator
### "Le rédacteur infatigable"

**Objectif** : Générer automatiquement du contenu éducatif (articles, micro-leçons, JIT cards) basé sur l'actualité financière suisse et les connaissances de la knowledge base.

**Fréquence** : Quotidienne (1h de cycle)

```markdown
# program.md — Content Generator

## Research Goal
Produire du contenu éducatif pertinent, factuel et engageant pour les utilisateurs Mint.
Métrique : content_pipeline_depth = nombre d'articles prêts à publier dans la queue
Cible : > 30 articles en attente (4 semaines d'avance)

## Types de contenu
1. **Micro-leçons** (300-500 mots) : Un concept expliqué simplement
   Ex: "Qu'est-ce que le taux de conversion LPP et pourquoi il baisse ?"
2. **JIT Cards** (50-100 mots) : Actions contextuelles "Si... alors..."
   Ex: "Si tu changes de canton cette année, alors vérifie l'impact sur tes impôts"
3. **Chiffres chocs** (1 phrase) : Faits saisissants pour le hook
   Ex: "Un Vaudois de 30 ans qui cotise 7'056 CHF/an en 3a économise ~2'100 CHF d'impôts"
4. **Simulateur narratif** (500-800 mots) : Scénario concret avec chiffres
   Ex: "Julie, 42 ans, rachat LPP de 50K : voici l'impact réel sur sa retraite"
5. **Actualité décryptée** (400-600 mots) : News suisse traduite en impact perso
   Ex: "La 13e rente AVS arrive en décembre : combien pour toi ?"

## Triggers de génération
- Nouvel article de Swiss Regulation Watch (Agent 1) → Actualité décryptée
- Nouveau paramètre modifié (Agent 3) → Chiffre choc + micro-leçon
- Nouvelle stratégie fiscale (Agent 4) → JIT Card + simulateur narratif
- Événement calendaire (fin d'année, deadline fiscal, etc.) → Contenu saisonnier

## Par itération
1. Vérifier les nouveaux inputs des autres agents
2. Identifier les sujets à couvrir (gap analysis vs content_library.json)
3. Générer le contenu en respectant le tone of voice Mint (éducatif, bienveillant, non prescriptif)
4. Fact-checker chaque chiffre contre la knowledge_base.json (Agent 1 + 3)
5. Classifier par archétype cible, phase de vie, et thème
6. Ajouter à la content queue avec statut "draft" (review humaine avant publication)

## Contraintes
- JAMAIS de conseil spécifique ("achète ce produit")
- Toujours des fourchettes, pas des montants absolus
- Tone : "grand frère bienveillant" — pas de jargon non expliqué
- Chaque contenu doit passer un fact-check automatisé
- Statut "draft" obligatoire — publication uniquement après validation humaine

## NEVER STOP
```

**Valeur pour Mint** : Le pipeline de contenu ne s'arrête jamais. L'app a toujours du contenu frais, factuel, et pertinent.

---

## AGENT 7 : UX Pattern Hunter
### "Le chasseur d'expériences"

**Objectif** : Tracker les évolutions UX/UI des meilleures apps AI (toutes catégories) pour alimenter le design Mint.

**Fréquence** : Bi-hebdomadaire (2h de cycle)

```markdown
# program.md — UX Pattern Hunter

## Research Goal
Identifier et documenter les patterns UX/UI émergents dans les apps AI de référence.
Métrique : patterns_documented = nombre de patterns UX actionnables dans la bibliothèque
Cible : > 100 patterns documentés (cross-domaine)

## Apps à surveiller
### Finance : Cleo, Monarch Money, bunq, Revolut, Albert, Copilot Money
### Sport/Santé : Fitbod, WHOOP, Oura, Noom, Freeletics, Peloton
### Education : Duolingo, Khan Academy
### Productivité : Notion AI, Reclaim.ai, Arc browser
### Wellness : Calm, Headspace, Wysa
### General AI : ChatGPT app, Claude app, Perplexity

## Catégories de patterns
1. Onboarding (progressive disclosure, time-to-value, first impression)
2. Conversational UI (chat bubbles, suggestion chips, voice interface)
3. Data visualization (scores, graphs, progress bars, fan charts)
4. Gamification (streaks, badges, leaderboards, challenges)
5. Notification design (timing, tone, actionability, dismiss patterns)
6. Trust signals (badges, explanations, transparency indicators)
7. Personalization indicators (how the AI shows it "knows" you)
8. Accessibility (senior-friendly, dyslexia, colorblind modes)
9. Empty states (first-use experience, zero-data states)
10. Error handling (graceful degradation, uncertainty communication)

## Par itération
1. Scanner les updates récentes des apps cibles (App Store + blogs + dribbble/behance)
2. Identifier les nouveaux patterns UX
3. Capturer des screenshots/descriptions détaillées
4. Analyser : pourquoi ce pattern fonctionne (psychologie, UX research)
5. Proposer une adaptation pour Mint (contexte financier suisse)
6. Classifier par catégorie et par feature Mint

## Output format
{
  "pattern_id": "UX-2026-043",
  "source_app": "WHOOP",
  "category": "data_visualization",
  "title": "Daily Recovery Score with color gradient",
  "description": "Score 0-100 affiché en grand, couleur verte→rouge, avec explication en 1 ligne",
  "why_it_works": "Score unique = raison de revenir chaque jour. Couleur = compréhension immédiate",
  "mint_adaptation": "Financial Health Score quotidien avec gradient vert→orange→rouge",
  "priority": "high",
  "screenshot_url": "..."
}

## NEVER STOP
```

**Valeur pour Mint** : Le design évolue en permanence vers les meilleures pratiques mondiales, pas seulement fintech.

---

## AGENT 8 : Financial Literacy Lab
### "Le professeur de nuit"

**Objectif** : Tester et optimiser l'efficacité du contenu éducatif de Mint en simulant différentes approches pédagogiques.

**Fréquence** : Hebdomadaire (2h de cycle)

```markdown
# program.md — Financial Literacy Lab

## Research Goal
Optimiser la clarté et l'impact du contenu éducatif de Mint.
Métrique : readability_score = combinaison (Flesch-Kincaid FR adaptation + concept_coverage + actionability_score)
Cible : readability > 70 (sur 100) pour chaque contenu

## Par itération
1. Prendre un concept financier du curriculum Mint (ex: "taux de conversion LPP")
2. Générer 5 variantes explicatives différentes :
   a. Analogie du quotidien ("C'est comme un taux de change entre ton capital et ta rente")
   b. Chiffres concrets ("100K de capital = 6'800 CHF/an de rente à 6.8%")
   c. Storytelling ("Marc, 62 ans, découvre que son taux réel est 5.2%, pas 6.8%")
   d. Visual/infographie (description textuelle d'un visuel à créer)
   e. Q&A format ("Pourquoi mon taux de conversion est-il inférieur à 6.8% ?")
3. Évaluer chaque variante sur : simplicité, exactitude, actionabilité
4. Identifier la meilleure approche par concept ET par archétype
5. Tester la compréhension avec des questions de contrôle simulées
6. Documenter les "recettes" qui marchent

## Concepts à couvrir (curriculum Mint)
- AVS : cotisations, rente, lacunes, 13e rente, splitting
- LPP : taux de conversion, surobligatoire, rachat, libre passage
- 3a : plafond, rétroactif, imposition échelonnée, choix prestataire
- Fiscal : taux marginal, déductions, valeur locative, impôt à la source
- Budget : reste à vivre, endettement, leasing, crédit consommation
- Immobilier : hypothèque, amortissement, retrait 2e pilier
- Succession : réserves héréditaires, testament, donation
- Assurances : LAMal, franchise, risque

## NEVER STOP
```

**Valeur pour Mint** : Le contenu éducatif est scientifiquement optimisé pour la compréhension, pas écrit "au feeling".

---

## AGENT 9 : Compliance Sentinel
### "Le gardien légal"

**Objectif** : Vérifier en continu que les outputs de Mint (textes, recommandations, disclaimers) restent conformes à la réglementation suisse.

**Fréquence** : Hebdomadaire (1h de cycle)

```markdown
# program.md — Compliance Sentinel

## Research Goal
Garantir la conformité continue de tous les contenus et fonctionnalités de Mint.
Métrique : compliance_score = (contenus conformes ÷ contenus total vérifiés) × 100
Cible : 100% (zéro tolérance)

## Cadre réglementaire
- LSFin (Loi sur les services financiers) : Mint ne fournit PAS de conseil en placement
- LEFin (Loi sur les établissements financiers) : Mint n'est PAS un gestionnaire de fortune
- LPD/nLPD (Loi sur la protection des données) : consentement, droit d'accès, portabilité
- FINMA : circulaires sur la communication financière
- LSFin art. 3-9 : Obligation de loyauté, d'information, d'adéquation
- CO art. 398 : Responsabilité du mandataire (Mint n'est PAS mandataire)

## Vérifications par itération
1. Scanner tous les nouveaux contenus générés (Agent 6 outputs)
2. Vérifier les disclaimers sur chaque écran de simulation
3. Détecter les formulations qui pourraient constituer un "conseil en placement"
   - Mots interdits : "je recommande", "vous devriez investir dans", "le meilleur produit"
   - Mots autorisés : "une option possible", "voici les scénarios", "consultez un conseiller"
4. Vérifier que chaque projection affiche ses hypothèses et limites
5. Contrôler les bandeaux compliance (SafeMode triggers, SoA formatting)
6. Vérifier la conformité RGPD/nLPD des flows de données

## Output format (alerts)
{
  "alert_id": "COMP-2026-012",
  "severity": "critical",
  "type": "regulatory_risk",
  "location": "content_queue/article-lpp-rachat-042.json",
  "issue": "La phrase 'nous recommandons de racheter votre LPP' constitue un conseil en placement",
  "fix_suggestion": "Remplacer par 'le rachat LPP est une option à explorer avec un conseiller'",
  "regulation": "LSFin art. 3",
  "detected_at": "2026-03-17"
}

## NEVER STOP
```

**Valeur pour Mint** : Zéro risque réglementaire. Chaque contenu publié est pré-vérifié pour la conformité suisse.

---

## AGENT 10 : Market Timing Radar
### "Le radar des opportunités"

**Objectif** : Détecter les fenêtres d'opportunité conjoncturelles pour les utilisateurs Mint (moments optimaux pour agir).

**Fréquence** : Quotidienne (45 min de cycle)

```markdown
# program.md — Market Timing Radar

## Research Goal
Identifier les moments conjoncturels où une action financière devient particulièrement avantageuse.
Métrique : actionable_signals_detected = nombre de signaux actionnables / mois
Cible : 5-15 signaux / mois (qualité > quantité)

## Signaux à détecter

### Taux d'intérêt
- Changement du taux directeur BNS → impact hypothèques, épargne, obligations
- Mouvement du taux hypothécaire de référence → occasion de renégocier
- Spread 3a (taux 3a compte vs 3a titres) → orientation produit

### Marché immobilier
- Indices des prix immobiliers (Wüest Partner, IAZI) → impact valeur locative
- Taux de vacance par région → contexte pour acheteurs

### Fiscalité
- Deadlines approchantes (déclaration, versement 3a, demande ruling)
- Fin d'année fiscale → dernière chance pour optimisations
- Changements de barèmes annoncés pour N+1

### Prévoyance
- Date de versement 13e rente AVS (nouveau)
- Dates limites de rachat LPP (avant retraite)
- Ouverture des comptes 3a rétroactifs (nouveau 2026)

### Conjoncture
- Inflation CH (impact pouvoir d'achat, indexation rentes)
- Chômage CH (impact Safe Mode, contenu adaptatif)
- PIB CH (contexte macro pour les projections)

## Par itération
1. Scanner les données conjoncturelles depuis les sources officielles
2. Comparer avec les seuils d'alerte définis
3. Si seuil franchi : créer un signal dans signals.json
4. Rédiger le contexte utilisateur ("Pourquoi c'est important pour toi")
5. Proposer une JIT card adaptée au signal
6. Classifier par archétype impacté

## Output format
{
  "signal_id": "MKT-2026-028",
  "type": "interest_rate",
  "title": "BNS baisse le taux directeur à 0.75%",
  "impact": "Les hypothèques variables deviennent plus attractives",
  "archetypes_impacted": ["Family Builder", "Career Peak"],
  "jit_card": "Si tu as une hypothèque à taux fixe qui expire dans les 12 prochains mois, alors c'est le moment d'évaluer tes options de renouvellement",
  "urgency": "medium",
  "window": "3-6 mois",
  "detected_at": "2026-03-17"
}

## NEVER STOP
```

**Valeur pour Mint** : L'app intervient au BON moment avec le BON conseil. C'est le "Just-in-Time" poussé à l'extrême — informé par la conjoncture réelle.

---

## ORCHESTRATION

### Schedule recommandé

| Agent | Fréquence | Durée | Créneau optimal |
|-------|-----------|-------|----------------|
| 1. Swiss Regulation Watch | Quotidien | 1h | 02:00-03:00 |
| 2. Competitor Intelligence | Hebdo (lundi) | 2h | 01:00-03:00 |
| 3. Pension Rates Tracker | Quotidien | 30 min | 03:00-03:30 |
| 4. Tax Optimization Lab | Hebdo (mercredi) | 3h | 00:00-03:00 |
| 5. AI Coaching Research | Hebdo (vendredi) | 2h | 01:00-03:00 |
| 6. Content Generator | Quotidien | 1h | 04:00-05:00 (après agents 1+3) |
| 7. UX Pattern Hunter | Bi-hebdo | 2h | 01:00-03:00 |
| 8. Financial Literacy Lab | Hebdo (jeudi) | 2h | 01:00-03:00 |
| 9. Compliance Sentinel | Hebdo (samedi) | 1h | 02:00-03:00 |
| 10. Market Timing Radar | Quotidien | 45 min | 06:00-06:45 |

### Dépendances entre agents

```
Agent 1 (Regulation) ──→ Agent 6 (Content) ──→ Agent 9 (Compliance)
Agent 3 (Rates)      ──→ Agent 6 (Content)
Agent 4 (Tax)        ──→ Agent 6 (Content)
Agent 10 (Market)    ──→ Agent 6 (Content)
Agent 5 (Research)   ──→ Agent 7 (UX)
                     ──→ Agent 8 (Literacy)
```

Les agents 1, 3, 4, 10 alimentent l'agent 6 (Content Generator).
L'agent 9 (Compliance) valide les outputs de l'agent 6.
L'agent 5 (Research) informe les agents 7 et 8.

### Dashboard auto-généré

Chaque matin à 07:00, un script de synthèse génère `dashboard.md` :

```
# MINT Autoresearch Dashboard — 2026-03-17

## Alertes critiques (dernières 24h)
- ⚠️ [COMP-2026-012] Article LPP contient formulation non conforme → Fix requis
- 🔴 [REG-2026-042] Nouvelle circulaire FINMA sur les outils éducatifs → Review requis

## Métriques
- Regulation Coverage: 97.2% (cible: 95%) ✅
- Parameter Accuracy: 100% ✅
- Compliance Score: 99.4% (1 fix en cours) ⚠️
- Content Pipeline: 34 articles en queue ✅
- Competitive Freshness: 8 jours ✅

## Nouveautés
- 3 nouvelles stratégies fiscales (Agent 4) : VD, GE, ZH
- 2 papers pertinents (Agent 5) : JITAI + gamification
- 1 nouveau pattern UX (Agent 7) : Cleo voice onboarding
- 4 signaux marché (Agent 10) : taux BNS, deadline 3a, inflation
```

---

## COÛT ESTIMÉ

| Composant | Coût mensuel estimé |
|-----------|-------------------|
| API LLM (Claude/GPT-4o) | ~$200-400/mois (selon volume de tokens) |
| Web scraping (proxies, APIs) | ~$50-100/mois |
| Stockage (JSONL, vector store) | ~$20/mois |
| Compute (orchestrateur) | ~$30-50/mois |
| **Total** | **~$300-570/mois** |

Pour un système de veille stratégique qui tourne 24/7, c'est un investissement dérisoire comparé à un analyste humain (~8'000-12'000 CHF/mois).

---

## PROCHAINES ÉTAPES

1. **Sprint 1** : Implémenter Agent 3 (Pension Rates Tracker) — le plus critique, le plus simple
2. **Sprint 2** : Implémenter Agent 1 (Swiss Regulation Watch) + Agent 9 (Compliance Sentinel)
3. **Sprint 3** : Implémenter Agent 6 (Content Generator) — dépend de 1 et 3
4. **Sprint 4** : Implémenter Agent 10 (Market Timing Radar) — alimente les JIT cards
5. **Sprint 5** : Agents 2, 4, 5, 7, 8 — enrichissement progressif

---

*Ce document est la spécification des 10 agents autoresearch de Mint. Chaque agent peut être implémenté indépendamment, mais leur valeur maximale émerge de leur orchestration collective.*
